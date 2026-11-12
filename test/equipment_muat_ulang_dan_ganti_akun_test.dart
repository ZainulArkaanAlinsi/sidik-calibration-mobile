import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Dua kegagalan di `EquipmentController` yang cuma kelihatan lewat controller
/// ASLI (bukan notifier bikinan seperti `urutan_respons_pencarian_test.dart`):
///
/// 1. **Muat ulang yang gagal.** `PenjagaUrutanMuat.muatDenganPenjaga`
///    memanggil `saatTerbaru` juga waktu permintaannya gagal. Dulu isinya
///    `hasil!.lastPage` dengan `hasil` masih null → null-check melempar DARI
///    DALAM penjaga, sebelum `state` dipasang. Akibatnya cari/saring/tarik-
///    ulang di sinyal buruk tidak berujung pesan "gagal + coba lagi", tapi
///    pemuat yang berputar selamanya.
/// 2. **Halaman 2 akun lama mendarat sesudah ganti akun.** `build()` tidak
///    mendaftarkan dirinya sebagai permintaan terbaru, jadi "muat lebih
///    banyak" milik akun A yang masih di jalan lolos `masihTerbaru` dan
///    menempel ke daftar alat akun B — data lab lain di HP yang dipakai
///    gantian.
///
/// Alat bikinan di bawah memakai data bawaan `MockEquipmentService` (id 12,
/// 13, 14); yang diuji urutan datangnya, bukan isi alatnya.
class _Berhalaman extends MockEquipmentService {
  /// Halaman 2 ditahan test sampai dilepas.
  final tahanHalaman2 = Completer<EquipmentPage>();

  bool putus = false;

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int? pelangganId,
    int? jatuhTempoDalam,
    bool termasukLewat = false,
    String? urut,
    int page = 1,
  }) async {
    if (putus) throw Exception('putus');
    final semua = (await super.daftar(token)).items;

    if (page == 2) return tahanHalaman2.future;

    // Halaman 1 = satu alat saja, dan server "punya" 3 halaman.
    return EquipmentPage(items: [semua.first], currentPage: 1, lastPage: 3);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer wadah(_Berhalaman service) {
    final w = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
        equipmentServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(w.dispose);
    return w;
  }

  Future<void> login(ProviderContainer w, String id) => w
      .read(authProvider.notifier)
      .login(identifier: id, password: 'rahasia123');

  group('muat ulang yang gagal', () {
    for (final (nama, aksi)
        in <(String, Future<void> Function(EquipmentController))>[
          ('muatUlang', (c) => c.muatUlang()),
          ('cari', (c) => c.cari('jangka')),
          ('filter', (c) => c.filter(status: 'aktif')),
        ]) {
      test(
        '$nama: tidak melempar, jadi galat di state (bukan loading terus), lalu pulih',
        () async {
          final service = _Berhalaman();
          final w = wadah(service);
          await login(w, 'SDK-0001');
          final langganan = w.listen(equipmentProvider, (_, _) {});
          addTearDown(langganan.close);
          await w.read(equipmentProvider.future);
          final c = w.read(equipmentProvider.notifier);

          service.putus = true;
          // Dulu: TypeError "Null check operator" dari dalam penjaga.
          await aksi(c);

          final gagal = w.read(equipmentProvider);
          expect(gagal.isLoading, isFalse, reason: 'tertahan di loading');
          expect(gagal.hasError, isTrue);
          // Tanpa daftar, tidak ada halaman berikutnya yang bisa diminta.
          expect(c.bisaMuatLagi, isFalse);

          service.putus = false;
          await c.muatUlang();

          final pulih = w.read(equipmentProvider);
          expect(pulih.hasError, isFalse);
          expect(pulih.value!.map((e) => e.id), [12]);
          expect(c.bisaMuatLagi, isTrue);
        },
      );
    }
  });

  group('ganti akun waktu "muat lebih banyak" masih di jalan', () {
    test('halaman 2 akun A tidak menempel ke daftar akun B', () async {
      final service = _Berhalaman();
      final w = wadah(service);

      await login(w, 'SDK-0001');
      final langganan = w.listen(equipmentProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(equipmentProvider.future);

      // Akun A minta halaman 2; jawabannya ditahan.
      final pending = w.read(equipmentProvider.notifier).muatLebihBanyak();

      await w.read(authProvider.notifier).logout();
      await login(w, 'SDK-0002');
      final untukB = await w.read(equipmentProvider.future);
      expect(untukB.map((e) => e.id), [12]);

      // Halaman 2 akun A baru pulang SEKARANG, sesudah B login.
      final semua = (await MockEquipmentService().daftar('t')).items;
      service.tahanHalaman2.complete(
        EquipmentPage(items: [semua[1]], currentPage: 2, lastPage: 3),
      );
      await pending;

      expect(
        w.read(equipmentProvider).value!.map((e) => e.id),
        [12],
        reason: 'alat milik akun A (id 13) menempel ke daftar akun B',
      );
      // Metadata halaman B tetap milik B: halaman 1 dari 3.
      final c = w.read(equipmentProvider.notifier);
      expect(c.bisaMuatLagi, isTrue);
    });
  });
}
