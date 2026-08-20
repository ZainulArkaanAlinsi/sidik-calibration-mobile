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
  Future<void> tunggu() => Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> login(ProviderContainer container) async {
    await container
        .read(authProvider.notifier)
        .login(identifier: 'SDK-0001', password: 'rahasia123');
  }

  test('sesudah login, token perangkat didaftarkan', () async {
    final container = wadah(_SumberPalsu('fcm-abc'));

    await login(container);
    container.read(pendaftaranPushSyncProvider);
    await tunggu();

    expect(layanan.didaftarkan, ['fcm-abc']);
  });

  /// Pengguna boleh nolak izin notifikasi, dan desktop memang nggak punya
  /// token push sama sekali. Dua-duanya keadaan yang sah, bukan kegagalan.
  test('tanpa token perangkat, nggak ada yang dikirim ke server', () async {
    final container = wadah(_SumberPalsu(null));

    await login(container);
    container.read(pendaftaranPushSyncProvider);
    await tunggu();

    expect(layanan.didaftarkan, isEmpty);
  });

  test('token yang dirotasi layanan push ikut didaftarkan', () async {
    final sumber = _SumberPalsu('fcm-lama');
    addTearDown(sumber.tutup);
    final container = wadah(sumber);

    await login(container);
    container.read(pendaftaranPushSyncProvider);
    await tunggu();

    sumber.rotasi('fcm-baru');
    await tunggu();

    expect(layanan.didaftarkan, ['fcm-lama', 'fcm-baru']);
  });

  test('belum login → nggak mendaftar apa pun', () async {
    final container = wadah(_SumberPalsu('fcm-abc'));

    container.read(pendaftaranPushSyncProvider);
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
