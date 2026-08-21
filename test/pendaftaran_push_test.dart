import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pendaftaran_push.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Pendaftaran perangkat buat push — jalur yang belum nyentuh Firebase.
///
/// Push cuma nutup satu keadaan: HP dengan aplikasi ketutup total. Yang diuji
/// di sini urusan KEPEMILIKAN dan daur hidupnya, karena dua kegagalan di
/// lapisan ini sama-sama nggak ngeluarin error:
///
///  - token yang dirotasi FCM nggak didaftarkan ulang → notifikasi berhenti
///    masuk, dan dari sisi server token lamanya masih kelihatan sah;
///  - token nggak dicabut waktu logout → HP yang dipakai gantian terus nerima
///    kabar kerja orang sebelumnya di layar kuncinya.
class _SumberPalsu implements SumberTokenPush {
  _SumberPalsu(this._token);

  final String? _token;
  final _rotasi = StreamController<String>.broadcast();

  @override
  Future<String?> token() async => _token;

  @override
  Stream<String> tokenBerubah() => _rotasi.stream;

  void rotasi(String baru) => _rotasi.add(baru);

  void tutup() => _rotasi.close();
}

void main() {
  late MockPendaftaranPush layanan;

  ProviderContainer wadah(SumberTokenPush sumber) {
    layanan = MockPendaftaranPush();

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        sumberTokenPushProvider.overrideWithValue(sumber),
        pendaftaranPushServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  /// Pendaftarannya berantai: ambil token perangkat, baca token akun dari
  /// storage, baru kirim ke server. Tiap `await` itu satu putaran microtask,
  /// jadi satu `Duration.zero` nggak cukup buat nunggu ujungnya.
  ///
  /// DULU ini `Future.delayed(50ms)` mati, dan itu flaky: lulus di laptop yang
  /// nganggur, gagal di runner CI yang lagi jalanin puluhan berkas test
  /// barengan. Ketahuan 20 Agu 2026, di PR pertama yang lewat CI baru —
  /// `didaftarkan` cuma keisi `['fcm-lama']` waktu yang ditunggu dua.
  ///
  /// Jeda tetap itu taruhan sama beban mesin, dan taruhan yang kalahnya
  /// kelihatan sebagai "test yang kadang merah" — jenis kegagalan yang paling
  /// cepat bikin orang berhenti percaya sama CI-nya sendiri.
  ///
  /// Sekarang yang ditunggu KONDISI, bukan durasi: berhenti begitu jumlah
  /// pendaftarannya sampai [sampai], atau menyerah sesudah 5 detik.
  ///
  /// Tanpa [sampai] — dipakai test yang justru harus melihat NGGAK ada yang
  /// kedaftar — nunggu kondisi nggak ada gunanya: kondisinya emang nggak akan
  /// pernah tercapai, dan nahan 5 detik cuma buat membuktikan sesuatu nggak
  /// terjadi itu 5 detik yang dibayar tiap kali suite jalan. Yang dipakai jeda
  /// tetap yang pendek, dan arah salahnya aman: kalau pendaftarannya ternyata
  /// lebih lambat dari ini, yang kejadian test-nya lulus padahal harusnya
  /// gagal — dan tiga test di atas yang nunggu kondisi udah membuktikan
  /// rantainya selesai jauh di bawah 300 md.
  Future<void> tunggu({int sampai = 0}) async {
    if (sampai == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      return;
    }

    final batas = DateTime.now().add(const Duration(seconds: 5));

    while (DateTime.now().isBefore(batas)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (layanan.didaftarkan.length >= sampai) return;
    }
  }

  /// Nyalain `pendaftaranPushSyncProvider` DAN nahan dia tetap hidup.
  ///
  /// Dulu ini `container.read(...)`, dan itu sebab sebenarnya test "token yang
  /// dirotasi" jadi rapuh — bukan jedanya. `read` cuma mbaca sekali tanpa
  /// ninggalin langganan; di Riverpod 3 provider tanpa pendengar boleh dibuang,
  /// dan `ref.onDispose(langganan.cancel)` di providernya ikut mbatalin
  /// langganan `tokenBerubah()`.
  ///
  /// Aliran rotasinya `broadcast`, jadi kejadian yang dikirim waktu nggak ada
  /// pendengar HILANG — bukan diantre. Begitu providernya kebuang sebelum
  /// `rotasi()` dipanggil, `fcm-baru` nggak akan pernah nyampe, dan nunggu
  /// berapa lama pun nggak nolong: `didaftarkan` mentok di `['fcm-lama']`
  /// sampai batas 5 detiknya habis. Persis yang kejadian di CI 20 Agt 2026,
  /// sementara di laptop nganggur providernya keburu kepakai duluan.
  ///
  /// `listen` ninggalin langganan beneran, dan `container.dispose` di [wadah]
  /// yang mbersihin.
  void hidupkan(ProviderContainer container) {
    container.listen(pendaftaranPushSyncProvider, (_, _) {});
  }

  Future<void> login(ProviderContainer container) async {
    await container
        .read(authProvider.notifier)
        .login(identifier: 'SDK-0001', password: 'rahasia123');
  }

  test('sesudah login, token perangkat didaftarkan', () async {
    final container = wadah(_SumberPalsu('fcm-abc'));

    await login(container);
    hidupkan(container);
    await tunggu(sampai: 1);

    expect(layanan.didaftarkan, ['fcm-abc']);
  });

  /// Pengguna boleh nolak izin notifikasi, dan desktop memang nggak punya
  /// token push sama sekali. Dua-duanya keadaan yang sah, bukan kegagalan.
  test('tanpa token perangkat, nggak ada yang dikirim ke server', () async {
    final container = wadah(_SumberPalsu(null));

    await login(container);
    hidupkan(container);
    await tunggu();

    expect(layanan.didaftarkan, isEmpty);
  });

  test('token yang dirotasi layanan push ikut didaftarkan', () async {
    final sumber = _SumberPalsu('fcm-lama');
    addTearDown(sumber.tutup);
    final container = wadah(sumber);

    await login(container);
    hidupkan(container);
    await tunggu(sampai: 1);

    sumber.rotasi('fcm-baru');
    await tunggu(sampai: 2);

    expect(layanan.didaftarkan, ['fcm-lama', 'fcm-baru']);
  });

  test('belum login → nggak mendaftar apa pun', () async {
    final container = wadah(_SumberPalsu('fcm-abc'));

    hidupkan(container);
    await tunggu();

    expect(layanan.didaftarkan, isEmpty);
  });

  test('logout mencabut token perangkat', () async {
    final container = wadah(_SumberPalsu('fcm-abc'));

    await login(container);
    await container.read(authProvider.notifier).logout();

    expect(layanan.dicabut, ['fcm-abc']);
  });

  /// Logout NGGAK BOLEH gagal gara-gara layanan push. Orang yang nekan logout
  /// harus beneran keluar, apa pun kata server soal token perangkatnya.
  test('logout tetap tuntas walau pencabutannya meledak', () async {
    layanan = MockPendaftaranPush();

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        sumberTokenPushProvider.overrideWithValue(_SumberMeledak()),
        pendaftaranPushServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(container.dispose);

    await login(container);
    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).value, isNull);
    expect(await container.read(tokenStorageProvider).read(), isNull);
  });
}

/// Sumber yang gagal — niru izin dicabut di tengah jalan atau plugin ngambek.
class _SumberMeledak implements SumberTokenPush {
  @override
  Future<String?> token() async => throw StateError('plugin ngambek');

  @override
  Stream<String> tokenBerubah() => const Stream.empty();
}
