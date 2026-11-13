import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/services/kamera_pindai.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Pemilih sumber foto: kamera sendiri di HP HANYA bila saklar
/// `KAMERA_SENDIRI` menyala (bawaan MATI → `image_picker` lama), cadangan
/// `image_picker` bila kamera sendiri tak bisa dipakai, berkas di desktop.
/// Semua dengan layar kamera TIRUAN (`bukaLayar`) — yang diuji adalah pilihan
/// jalurnya.
void main() {
  final foto = File('${Directory.systemTemp.path}/cap-1.jpg');
  final fotoCadangan = File('${Directory.systemTemp.path}/cadangan.jpg');

  KameraAplikasiSumberFoto sumber(
    Future<HasilKamera> Function({double? rasioKertas}) bukaLayar,
    MockSumberFoto cadangan,
  ) => KameraAplikasiSumberFoto(bukaLayar: bukaLayar, cadangan: cadangan);

  test(
    'teknisi memotret: berkas kamera dipulangkan, cadangan TIDAK dipanggil',
    () async {
      final cadangan = MockSumberFoto(file: fotoCadangan);
      double? rasioDiterima;
      final s = sumber(({double? rasioKertas}) async {
        rasioDiterima = rasioKertas;

        return KameraFoto(foto);
      }, cadangan);

      final hasil = await s.ambil(
        maxWidth: 4200,
        maxHeight: 4200,
        imageQuality: 100,
        rasioKertas: 792 / 612,
      );

      expect(hasil?.path, foto.path);
      expect(rasioDiterima, closeTo(792 / 612, 1e-9));
      expect(cadangan.jumlahAmbil, 0);
    },
  );

  test(
    'teknisi menutup kamera: null (batal), BUKAN jatuh ke kamera sistem',
    () async {
      final cadangan = MockSumberFoto(file: fotoCadangan);
      final s = sumber(
        ({double? rasioKertas}) async => const KameraDibatalkan(),
        cadangan,
      );

      expect(await s.ambil(), isNull);
      expect(cadangan.jumlahAmbil, 0);
    },
  );

  for (final sebab in SebabKameraGagal.values) {
    test('kamera sendiri tak bisa dipakai ($sebab): jatuh ke jalur lama '
        'dengan argumen yang sama', () async {
      final cadangan = MockSumberFoto(file: fotoCadangan);
      final s = sumber(
        ({double? rasioKertas}) async => KameraTakBisa(sebab),
        cadangan,
      );

      final hasil = await s.ambil(
        maxWidth: 4200,
        maxHeight: 4200,
        imageQuality: 100,
        rasioKertas: 1.4,
      );

      expect(hasil?.path, fotoCadangan.path);
      expect(cadangan.jumlahAmbil, 1);
      expect(cadangan.maxWidthTerakhir, 4200);
      expect(cadangan.maxHeightTerakhir, 4200);
      expect(cadangan.kualitasTerakhir, 100);
    });
  }

  test(
    'layar kamera melempar sesuatu: tetap jatuh ke cadangan, tanpa crash',
    () async {
      final cadangan = MockSumberFoto(file: fotoCadangan);
      final s = sumber(
        ({double? rasioKertas}) async => throw StateError('navigator mati'),
        cadangan,
      );

      expect((await s.ambil())?.path, fotoCadangan.path);
      expect(cadangan.jumlahAmbil, 1);
    },
  );

  test(
    'galat cadangan (izin sistem ditolak) tetap sampai ke pemanggil',
    () async {
      // Pesan "izin kamera ditolak" yang sudah ada tetap lewat jalur lama.
      final cadangan = MockSumberFoto(
        galat: PlatformException(code: 'camera_access_denied'),
      );
      final s = sumber(
        ({double? rasioKertas}) async =>
            const KameraTakBisa(SebabKameraGagal.izinDitolak),
        cadangan,
      );

      await expectLater(
        s.ambil(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'camera_access_denied',
          ),
        ),
      );
    },
  );

  test('foto tertinggal hanya datang dari jalur lama (cadangan)', () async {
    final cadangan = MockSumberFoto(tertinggal: fotoCadangan);
    final s = sumber(
      ({double? rasioKertas}) async => const KameraDibatalkan(),
      cadangan,
    );

    expect((await s.ambilFotoTertinggal())?.path, fotoCadangan.path);
    expect(await s.ambilFotoTertinggal(), isNull, reason: 'sekali saja');
  });

  group('pilihSumberFoto + saklar KAMERA_SENDIRI', () {
    var dibuka = 0;
    Future<HasilKamera> tiruan({double? rasioKertas}) async {
      dibuka++;

      return const KameraDibatalkan();
    }

    setUp(() => dibuka = 0);

    test('HP, saklar MATI: image_picker lama; layar kamera tak terjangkau', () {
      final s = pilihSumberFoto(
        seluler: true,
        kameraSendiri: false,
        bukaLayar: tiruan,
      );

      expect(s, isA<KameraSumberFoto>());
      expect(s, isNot(isA<KameraAplikasiSumberFoto>()));
      expect(dibuka, 0);
    });

    test('HP, saklar NYALA: kamera sendiri, dengan image_picker sebagai '
        'cadangan', () {
      final s = pilihSumberFoto(
        seluler: true,
        kameraSendiri: true,
        bukaLayar: tiruan,
      );

      expect(s, isA<KameraAplikasiSumberFoto>());
      expect(
        (s as KameraAplikasiSumberFoto).cadangan,
        isA<KameraSumberFoto>(),
        reason: 'jalur lama dipertahankan sebagai cadangan',
      );
    });

    for (final saklar in [false, true]) {
      test('desktop: pemilih berkas, bukan kamera (saklar $saklar)', () {
        expect(
          pilihSumberFoto(
            seluler: false,
            kameraSendiri: saklar,
            bukaLayar: tiruan,
          ),
          isA<BerkasSumberFoto>(),
        );
      });
    }

    test(
      'saklar kKameraSendiri BAWAAN MATI di build/test biasa',
      () {
        expect(
          kKameraSendiri,
          isFalse,
          reason:
              'membalik bawaan butuh bukti di HP nyata (lihat pubspec.yaml)',
        );
      },
      skip: const String.fromEnvironment('KAMERA_SENDIRI').isNotEmpty
          ? 'dijalankan dengan --dart-define=KAMERA_SENDIRI'
          : false,
    );

    test('deklarasi bawaan di sumber tetap `defaultValue: false`', () {
      // Tes di atas bisa dikelabui --dart-define; yang ini membaca deklarasinya.
      final isi = File(
        'lib/providers/sumber_foto_provider.dart',
      ).readAsStringSync();

      expect(
        RegExp(
          r"const bool kKameraSendiri = bool\.fromEnvironment\(\s*"
          r"'KAMERA_SENDIRI',\s*defaultValue: false,?\s*\);",
        ).hasMatch(isi),
        isTrue,
        reason: 'bawaan saklar harus tetap MATI',
      );
      // Provider benar-benar meneruskan saklar ke pemilih sumber (cabang HP
      // tak bisa dijalankan di host).
      expect(isi, contains('kameraSendiri: kKameraSendiri,'));
    });
  });

  group('manifest Android (hasil merge plugin kamera)', () {
    // `required="false"` SAJA tidak menimpa `uses-feature camera.any` milik
    // plugin (penggabung AGP memakai kebijakan OR → hasil tetap true);
    // dibuktikan di harness ManifestMerger2. Yang menimpa: tools:node="replace".
    for (final (nama, jalur) in [
      ('Lab', 'android/app/src/main/AndroidManifest.xml'),
      ('Studio', 'studio/android/app/src/main/AndroidManifest.xml'),
    ]) {
      test('$nama: camera.any opsional lewat tools:node="replace", izin '
          'tak terpakai dicabut', () {
        final isi = File(jalur).readAsStringSync();

        expect(
          isi,
          contains('xmlns:tools="http://schemas.android.com/tools"'),
          reason: 'namespace tools harus terdeklarasi',
        );
        final fitur = RegExp(
          r'<uses-feature[^>]*android\.hardware\.camera\.any[^>]*/>',
        ).allMatches(isi).map((m) => m.group(0)!).toList();
        expect(fitur, hasLength(1));
        expect(fitur.single, contains('android:required="false"'));
        expect(fitur.single, contains('tools:node="replace"'));

        for (final izin in ['RECORD_AUDIO', 'WRITE_EXTERNAL_STORAGE']) {
          expect(
            RegExp(
              r'uses-permission[^>]*android\.permission\.'
              '$izin"[^>]*'
              'tools:node="remove"',
            ).hasMatch(isi),
            isTrue,
            reason: '$izin harus dicabut',
          );
        }
      });
    }
  });
}
