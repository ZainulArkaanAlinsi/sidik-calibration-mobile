import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/models/order.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/order_kelola_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/providers/super_admin_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';


/// Provider kelola Order: paginasi menambah (tidak menimpa), saringan, galat
/// yang pulih, dan batas antar-akun (skill `sidik-fe-scope-akun`).
List<OrderKalibrasi> _banyak(int n, {String status = 'baru'}) => [
  for (var i = 0; i < n; i++)
    OrderKalibrasi(
      id: 500 + i,
      nomor: 'ORD/2026/11/${(i + 1).toString().padLeft(4, '0')}',
      status: status,
      namaPelanggan: 'PT Nomor $i',
      pelangganId: 3,
      jumlahAlat: 1,
    ),
];

/// Halaman 2 ditahan test sampai dilepas (meniru jaringan lapangan yang lambat).
class _TahanHalaman2 extends MockOrderKelolaService {
  _TahanHalaman2() : super(awal: _banyak(5), ukuranHalaman: 2);

  final tahan = Completer<void>();
  Object? galatHalaman2;

  @override
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    if (halaman == 2) {
      await tahan.future;
      if (galatHalaman2 != null) throw galatHalaman2!;
    }
    return super.daftar(token, status: status, cari: cari, halaman: halaman);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer wadah(
    OrderKelolaService layanan, {
    PenggunaSaService? pengguna,
  }) {
    final w = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
        orderKelolaServiceProvider.overrideWithValue(layanan),
        if (pengguna != null) penggunaSaServiceProvider.overrideWithValue(pengguna),
      ],
    );
    addTearDown(w.dispose);
    return w;
  }

  Future<void> login(ProviderContainer w, String id) => w
      .read(authProvider.notifier)
      .login(identifier: id, password: 'rahasia123');

  group('daftar berpaginasi', () {
    test('halaman 1, lalu muat lebih banyak MENAMBAH sampai habis', () async {
      final layanan = MockOrderKelolaService(awal: _banyak(5), ukuranHalaman: 2);
      final w = wadah(layanan);
      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);

      final awal = await w.read(orderKelolaProvider.future);
      expect(awal.items, hasLength(2));
      expect(awal.adaLagi, isTrue);

      await w.read(orderKelolaProvider.notifier).muatLebihBanyak();
      expect(w.read(orderKelolaProvider).value!.items, hasLength(4));

      await w.read(orderKelolaProvider.notifier).muatLebihBanyak();
      final akhir = w.read(orderKelolaProvider).value!;
      expect(akhir.items, hasLength(5));
      expect(akhir.adaLagi, isFalse);
      expect(akhir.items.map((o) => o.id).toSet(), hasLength(5), reason: 'tanpa dobel');

      // Habis: panggilan lagi tidak meminta apa-apa.
      final sebelum = layanan.catatan.length;
      await w.read(orderKelolaProvider.notifier).muatLebihBanyak();
      expect(layanan.catatan.length, sebelum);
    });

    test('saring status: kembali ke halaman 1 dan membawa status ke server', () async {
      final layanan = MockOrderKelolaService(
        awal: [..._banyak(3), ..._banyak(2, status: 'selesai').map(_geser)],
        ukuranHalaman: 15,
      );
      final w = wadah(layanan);
      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);

      final ctl = w.read(orderKelolaProvider.notifier);
      await ctl.saring(ctl.filter.salin(status: 'selesai'));

      final isi = w.read(orderKelolaProvider).value!;
      expect(isi.items.every((o) => o.status == 'selesai'), isTrue);
      expect(isi.items, hasLength(2));
      expect(layanan.catatan.last, contains('status=selesai'));
      expect(ctl.filter.status, 'selesai');
    });

    test('cari memakai kata kunci, bukan menyaring di sisi aplikasi', () async {
      final layanan = MockOrderKelolaService(awal: _banyak(4), ukuranHalaman: 15);
      final w = wadah(layanan);
      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);

      final ctl = w.read(orderKelolaProvider.notifier);
      await ctl.saring(ctl.filter.salin(cari: 'Nomor 2'));

      expect(layanan.catatan.last, contains('cari=Nomor 2'));
      expect(w.read(orderKelolaProvider).value!.items.single.namaPelanggan, 'PT Nomor 2');
    });

    test('muat ulang yang gagal menjadi galat (bukan loading terus), lalu pulih', () async {
      final gagal = _GalatBisaDinyalakan(_banyak(2));
      final w = wadah(gagal);
      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);

      gagal.putus = true;
      await w.read(orderKelolaProvider.notifier).muatUlang();
      final s = w.read(orderKelolaProvider);
      expect(s.isLoading, isFalse);
      expect(s.hasError, isTrue);

      gagal.putus = false;
      await w.read(orderKelolaProvider.notifier).muatUlang();
      expect(w.read(orderKelolaProvider).value!.items, hasLength(2));
    });

    test('halaman berikutnya gagal: daftar yang sudah tampak tetap', () async {
      final layanan = _TahanHalaman2()..galatHalaman2 = const KoneksiException('putus');
      final w = wadah(layanan);
      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);

      layanan.tahan.complete();
      await w.read(orderKelolaProvider.notifier).muatLebihBanyak();

      final s = w.read(orderKelolaProvider);
      expect(s.hasError, isFalse);
      expect(s.value!.items, hasLength(2));
      expect(s.value!.adaLagi, isTrue);
    });
  });

  group('batas antar-akun (skill sidik-fe-scope-akun)', () {
    test('halaman 2 akun A tidak menempel ke daftar akun B', () async {
      final layanan = _TahanHalaman2();
      final w = wadah(layanan);

      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);

      // Akun A minta halaman 2; jawabannya ditahan.
      final pending = w.read(orderKelolaProvider.notifier).muatLebihBanyak();

      await w.read(authProvider.notifier).logout();
      await login(w, 'SDK-0002');
      final untukB = await w.read(orderKelolaProvider.future);
      expect(untukB.items, hasLength(2));

      layanan.tahan.complete();
      await pending;

      expect(
        w.read(orderKelolaProvider).value!.items,
        hasLength(2),
        reason: 'halaman 2 milik akun A menempel ke daftar akun B',
      );
    });

    test('ganti akun mengambil ulang dari server dan membuang saringan', () async {
      final layanan = MockOrderKelolaService(awal: _banyak(3), ukuranHalaman: 15);
      final w = wadah(layanan);

      await login(w, 'SDK-0001');
      final langganan = w.listen(orderKelolaProvider, (_, _) {});
      addTearDown(langganan.close);
      await w.read(orderKelolaProvider.future);
      final ctl = w.read(orderKelolaProvider.notifier);
      await ctl.saring(ctl.filter.salin(status: 'baru', cari: 'x'));
      final sebelum = layanan.catatan.where((c) => c.startsWith('daftar')).length;

      await w.read(authProvider.notifier).logout();
      await login(w, 'SDK-0002');
      await w.read(orderKelolaProvider.future);

      // Service BENAR-BENAR dipanggil lagi (bukan kebetulan datanya mirip).
      expect(
        layanan.catatan.where((c) => c.startsWith('daftar')).length,
        greaterThan(sebelum),
      );
      expect(w.read(orderKelolaProvider.notifier).filter.status, isNull);
      expect(w.read(orderKelolaProvider.notifier).filter.cari, isEmpty);
    });
  });

  group('detail dan teknisi aktif', () {
    test('detail memanggil service dan membawa items', () async {
      final layanan = MockOrderKelolaService();
      final w = wadah(layanan);
      await login(w, 'SDK-0001');
      final o = await w.read(orderKelolaDetailProvider(301).future);

      expect(o.items, hasLength(2));
      expect(layanan.catatan, contains('detail 301'));
    });

    test('teknisi aktif: hanya peran teknisi, status aktif, semua halaman', () async {
      final pengguna = MockPenggunaSaService(ukuranHalaman: 1);
      final w = wadah(MockOrderKelolaService(), pengguna: pengguna);
      await login(w, 'SDK-0001');

      final t = await w.read(teknisiAktifProvider.future);

      expect(t.map((u) => u.nama), ['Dedi Teknisi']);
      expect(
        pengguna.catatan.every((c) => c.contains('peran=teknisi') && c.contains('status=aktif')),
        isTrue,
      );
    });
  });
}

OrderKalibrasi _geser(OrderKalibrasi o) => OrderKalibrasi(
  id: o.id + 1000,
  nomor: o.nomor,
  status: o.status,
  namaPelanggan: o.namaPelanggan,
  jumlahAlat: o.jumlahAlat,
);

/// Gagal pada permintaan berikutnya bila [putus].
class _GalatBisaDinyalakan extends MockOrderKelolaService {
  _GalatBisaDinyalakan(List<OrderKalibrasi> awal) : super(awal: awal);

  bool putus = false;

  @override
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    if (putus) throw const KoneksiException('putus');
    return super.daftar(token, status: status, cari: cari, halaman: halaman);
  }
}
