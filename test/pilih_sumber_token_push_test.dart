import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';

class _SumberFcmPalsu implements SumberTokenPush {
  @override
  Future<String?> token() async => 'token-palsu';

  @override
  Stream<String> tokenBerubah() => const Stream<String>.empty();
}

/// Pemilihan sumber token push.
///
/// Kasus nyata (13 Nov 2026): APK uji tanpa konfigurasi Firebase membentuk
/// `FcmSumberTokenPush` setelah login, `FirebaseMessaging.instance` melempar
/// `[core/no-app]`, dan layar jatuh ke galat provider. Tanpa app Firebase
/// pendaftaran push harus dilewati, bukan melempar.
void main() {
  group('pilihSumberTokenPush', () {
    var dibuat = 0;
    SumberTokenPush buat() {
      dibuat++;

      return _SumberFcmPalsu();
    }

    setUp(() => dibuat = 0);

    test('semua syarat terpenuhi: FCM dibentuk', () {
      final s = pilihSumberTokenPush(
        useMock: false,
        didukung: true,
        firebaseSiap: true,
        buatFcm: buat,
      );

      expect(s, isA<_SumberFcmPalsu>());
      expect(dibuat, 1);
    });

    test('Firebase belum menyala: tanpa token, FCM TIDAK dibentuk', () {
      final s = pilihSumberTokenPush(
        useMock: false,
        didukung: true,
        firebaseSiap: false,
        buatFcm: buat,
      );

      expect(s, isA<TanpaTokenPush>());
      expect(dibuat, 0, reason: 'konstruktor FCM-lah yang melempar no-app');
    });

    test('mode mock: tanpa token, FCM tidak dibentuk', () {
      final s = pilihSumberTokenPush(
        useMock: true,
        didukung: true,
        firebaseSiap: true,
        buatFcm: buat,
      );

      expect(s, isA<TanpaTokenPush>());
      expect(dibuat, 0);
    });

    test('platform tak didukung (desktop/web): tanpa token', () {
      final s = pilihSumberTokenPush(
        useMock: false,
        didukung: false,
        firebaseSiap: true,
        buatFcm: buat,
      );

      expect(s, isA<TanpaTokenPush>());
      expect(dibuat, 0);
    });
  });
}
