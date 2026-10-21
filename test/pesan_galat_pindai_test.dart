import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/services/ambil_foto_tabel.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/modul_pembaca_teks.dart';
import 'package:sidik_calibration/services/pesan_galat_pindai.dart';

/// Galat kamera/ML Kit di HP asli → kalimat manusia, tanpa galat mentah.
void main() {
  final l10n = AppLocalizationsId();

  group('golongkanGalatPindai', () {
    test('izin kamera ditolak (image_picker Android & iOS)', () {
      for (final kode in ['camera_access_denied', 'photo_access_denied']) {
        expect(
          golongkanGalatPindai(
            PlatformException(code: kode, message: 'The user did not allow'),
          ),
          GolonganGalatPindai.izinKameraDitolak,
        );
      }
    });

    test('kamera tidak ada / masih aktif', () {
      expect(
        golongkanGalatPindai(PlatformException(code: 'no_available_camera')),
        GolonganGalatPindai.kameraTidakAda,
      );
      expect(
        golongkanGalatPindai(PlatformException(code: 'already_active')),
        GolonganGalatPindai.kameraSibuk,
      );
    });

    test('modul teks / QR / Play Services', () {
      expect(
        golongkanGalatPindai(const ModulPembacaTeksBelumSiap()),
        GolonganGalatPindai.modulTeksDiunduh,
      );
      expect(
        golongkanGalatPindai(const ModulPembacaQrBelumSiap()),
        GolonganGalatPindai.modulQrDiunduh,
      );
      expect(
        golongkanGalatPindai(const LayananGooglePlayTidakSiap()),
        GolonganGalatPindai.tanpaPlayServices,
      );
    });

    test('koneksi/server tidur', () {
      expect(
        golongkanGalatPindai(const KoneksiException('x')),
        GolonganGalatPindai.koneksi,
      );
      expect(
        golongkanGalatPindai(const SocketException('x')),
        GolonganGalatPindai.koneksi,
      );
      expect(
        golongkanGalatPindai(TimeoutException('x')),
        GolonganGalatPindai.koneksi,
      );
    });

    test('yang tak dikenal = umum', () {
      expect(
        golongkanGalatPindai(PlatformException(code: 'X', message: 'boom')),
        GolonganGalatPindai.umum,
      );
      expect(golongkanGalatPindai(StateError('x')), GolonganGalatPindai.umum);
    });
  });

  group('deteksi galat ML Kit', () {
    test('teks pesan (jalur utama) untuk teks & barcode', () {
      for (final pesan in [
        'com.google.mlkit.common.MlKitException: Waiting for the text '
            'optional module to be downloaded. Please wait.',
        'com.google.mlkit.common.MlKitException: Waiting for the barcode '
            'module to be downloaded. Please wait.',
      ]) {
        expect(
          galatModulBelumTerunduh(
            PlatformException(code: 'BarcodeDetectorError', message: pesan),
          ),
          isTrue,
          reason: pesan,
        );
      }
    });

    test('kode UNAVAILABLE juga dikenali walau pesannya lain', () {
      expect(
        galatModulBelumTerunduh(
          PlatformException(code: 'UNAVAILABLE', message: 'not ready'),
        ),
        isTrue,
      );
    });

    test('Play Services hilang bukan modul diunduh', () {
      final e = PlatformException(
        code: 'TextRecognizerError',
        message: 'ConnectionResult{statusCode=SERVICE_MISSING}',
      );
      expect(galatModulBelumTerunduh(e), isFalse);
      expect(galatTanpaPlayServices(e), isTrue);

      final u = PlatformException(
        code: 'UNAVAILABLE',
        message: 'Google Play services is missing',
      );
      expect(galatModulBelumTerunduh(u), isFalse);
      expect(galatTanpaPlayServices(u), isTrue);
    });

    test('galat lain bukan keduanya', () {
      final e = PlatformException(code: 'X', message: 'Internal error');
      expect(galatModulBelumTerunduh(e), isFalse);
      expect(galatTanpaPlayServices(e), isFalse);
    });

    test('pembungkus menerjemahkan; galat lain apa adanya', () async {
      await expectLater(
        denganModulPembacaQr<void>(
          () async => throw PlatformException(
            code: 'BarcodeDetectorError',
            message: 'Waiting for the barcode module to be downloaded.',
          ),
        ),
        throwsA(isA<ModulPembacaQrBelumSiap>()),
      );
      await expectLater(
        denganModulPembacaQr<void>(
          () async => throw PlatformException(
            code: 'BarcodeDetectorError',
            message: 'SERVICE_VERSION_UPDATE_REQUIRED',
          ),
        ),
        throwsA(isA<LayananGooglePlayTidakSiap>()),
      );
      await expectLater(
        denganModulPembacaTeks<void>(
          () async => throw PlatformException(code: 'X', message: 'boom'),
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('pesanGalatFotoTabel', () {
    test('tidak pernah menampilkan galat mentah', () {
      final e = PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access.',
      );
      final pesan = pesanGalatFotoTabel(l10n, e);

      expect(pesan, l10n.lkGalatIzinKamera);
      expect(pesan, contains('Pengaturan'));
      expect(pesan, isNot(contains('PlatformException')));
      expect(pesan, isNot(contains('camera_access_denied')));
    });

    test('galat tak dikenal: kalimat umum foto tabel', () {
      final pesan = pesanGalatFotoTabel(
        l10n,
        PlatformException(code: 'X', message: '/data/user/0/secret.jpg'),
      );

      expect(pesan, l10n.lkFotoTabelGagalUmum);
      expect(pesan, isNot(contains('/data/')));
    });
  });
}
