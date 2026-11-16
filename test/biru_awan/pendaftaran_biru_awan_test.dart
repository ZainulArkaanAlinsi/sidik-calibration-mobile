// Pendaftaran komponen Biru Awan (L3a, L3b, dan elemen umpan balik L2).
//
// `tool/cek-berkas-yatim.sh` menghitung berkas yang diimpor dari `test/` sebagai
// terpakai, dan komponen ini belum dipakai layar mana pun. Tes ini menjaga agar
// sebutan "terpakai" itu sah: tiap berkas komponen harus diimpor galeri
// pengembang dan punya tes widget, README memuat semuanya, dan komponen tidak
// melanggar aturan token dan teks. Berkas komponen baru yang lupa salah satunya
// membuat tes ini merah, bukan lolos diam-diam.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _baca(String jalur) => File(jalur).readAsStringSync();

String _tanpaKomentar(String sumber) => sumber
    .split(RegExp(r'\r?\n'))
    .where((b) => !b.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final berkas = Directory('lib/widgets/biru_awan')
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/').split('/').last)
      .where((n) => n.endsWith('.dart'))
      .map((n) => n.substring(0, n.length - '.dart'.length))
      .toList();

  const harapan = {
    'tombol_sidik': ['TombolSidik'],
    'tombol_bulat': ['TombolBulat'],
    'isian_sidik': ['IsianSidik'],
    'stempel_sidik': ['StempelSidik'],
    'chip_saring': ['ChipSaring'],
    'segmen_pil': ['SegmenPil'],
    'kartu_sidik24': ['KartuSidik24'],
    'panel_baris': ['PanelBaris', 'BarisMenu64', 'BarisDaftar72'],
    'ubin_ikon': ['UbinIkon'],
    'kepala_layar': ['KepalaTab', 'KepalaAnak'],
    // L3b.
    'hero_langit': ['HeroLangit', 'PelukisMotifSkala'],
    'ubin_kpi': ['UbinKpi'],
    'grafik_batang': ['GrafikBatang', 'BatangGrafik'],
    'stepper_tegak': ['StepperTegak', 'LangkahStepper'],
    'garis_waktu': ['GarisWaktu', 'ButirGarisWaktu'],
    'avatar_inisial': ['AvatarInisial'],
    'lencana': ['Lencana', 'LoncengBerlencana'],
    'bilah_langkah': ['BilahLangkah'],
    'kolom_cari': ['KolomCari'],
    // L2 (elemen umpan balik).
    'toast_sidik': [
      'ToastSidik',
      'JenisToast',
      'TombolTutupSidik',
      'PilAksiSidik',
      'UbinUmpanBalik',
    ],
    'dialog_sidik': ['DialogSidik'],
    'lembar_bawah_sidik': ['LembarBawahSidik'],
    'banner_sidik': ['BannerSidik', 'RagamBannerSidik'],
    'keadaan_sidik': [
      'KeadaanMemuat',
      'KeadaanKosong',
      'KeadaanGalat',
      'RagamMemuat',
    ],
  };

  test(
    'berkas komponen = daftar L3a + L3b + L2 (tidak ada yang lebih, tidak ada yang kurang)',
    () {
      expect(
        berkas.toSet(),
        harapan.keys.toSet(),
        reason:
            'berkas baru wajib ditambahkan ke daftar ini, galeri, README, dan tes',
      );
    },
  );

  test('tiap kelas yang dijanjikan dideklarasikan di berkasnya', () {
    for (final e in harapan.entries) {
      final sumber = _baca('lib/widgets/biru_awan/${e.key}.dart');
      for (final nama in e.value) {
        expect(
          RegExp(
            '(?:abstract final class|final class|class|enum)\\s+$nama\\b',
          ).hasMatch(sumber),
          isTrue,
          reason: '${e.key}.dart tidak mendeklarasikan $nama',
        );
      }
    }
  });

  test(
    'galeri pengembang mengimpor SEMUA berkas komponen dan gerak bersama',
    () {
      final galeri = _baca(
        'lib/screens/pengembang/galeri_biru_awan_screen.dart',
      );
      for (final n in harapan.keys) {
        expect(
          galeri,
          contains('widgets/biru_awan/$n.dart'),
          reason: '$n tidak diimpor galeri',
        );
      }
      expect(galeri, contains('core/motion/gerak_bersama.dart'));
    },
  );

  test('tiap berkas komponen punya tes widget yang mengimpornya', () {
    final tes = Directory('test/biru_awan')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => f.readAsStringSync())
        .toList();
    for (final n in harapan.keys) {
      expect(
        tes.any((s) => s.contains('widgets/biru_awan/$n.dart')),
        isTrue,
        reason: '$n belum punya tes di test/biru_awan/',
      );
    }
    expect(
      tes.any((s) => s.contains('core/motion/gerak_bersama.dart')),
      isTrue,
    );
  });

  test('README memuat setiap komponen', () {
    final readme = _baca('lib/widgets/biru_awan/README.md');
    for (final e in harapan.entries) {
      expect(readme, contains('${e.key}.dart'), reason: e.key);
      for (final nama in e.value) {
        expect(readme, contains(nama), reason: nama);
      }
    }
  });

  group('aturan kode komponen', () {
    final semua = [
      for (final n in berkas) 'lib/widgets/biru_awan/$n.dart',
      'lib/core/theme/warna_biru_awan.dart',
      'lib/core/theme/token_komponen_biru_awan.dart',
      'lib/core/theme/token_komponen_biru_awan_lanjut.dart',
      'lib/core/motion/gerak_bersama.dart',
    ];

    test('tidak mengimpor widget beku atau komponen lama', () {
      const terlarang = [
        'widgets/app_button.dart',
        'widgets/app_text_field.dart',
        'widgets/sidik_loader.dart',
        'widgets/status_badge.dart',
        'screens/calibration/',
        'sakelar_tema.dart',
        'tema_beku.dart',
        'palet_beku.dart',
        'app_colors.dart',
      ];
      for (final jalur in semua) {
        final sumber = _tanpaKomentar(_baca(jalur));
        for (final t in terlarang) {
          expect(
            sumber.contains(t),
            isFalse,
            reason: '$jalur mengimpor $t (beku atau lama)',
          );
        }
      }
    });

    test('tanpa Colors.* selain transparent, tanpa Color(0x, tanpa hex', () {
      final pola = RegExp(r'\bColors\.(?!transparent\b)\w+');
      for (final jalur in semua) {
        final sumber = _tanpaKomentar(_baca(jalur));
        expect(pola.hasMatch(sumber), isFalse, reason: '$jalur: Colors.*');
        if (!jalur.endsWith('warna_biru_awan.dart')) {
          expect(sumber.contains('Color(0x'), isFalse, reason: jalur);
        }
        expect(RegExp(r'#[0-9A-Fa-f]{6}\b').hasMatch(sumber), isFalse);
      }
    });

    test('widget tidak menulis fontSize atau radius angka sendiri', () {
      for (final n in berkas) {
        final sumber = _tanpaKomentar(_baca('lib/widgets/biru_awan/$n.dart'));
        expect(sumber.contains('fontSize:'), isFalse, reason: '$n: fontSize');
        expect(
          RegExp(r'Radius\.circular\(\s*\d').hasMatch(sumber),
          isFalse,
          reason: '$n: radius angka',
        );
      }
    });

    test(
      'tanpa string tampilan keras: Text() hanya dari pemanggil atau l10n',
      () {
        // `Text('$jumlah')` (angka pemanggil) boleh; teks literal tidak.
        final pola = RegExp(r'''\bText\(\s*['"][^'"$]''');
        for (final n in berkas) {
          final sumber = _tanpaKomentar(_baca('lib/widgets/biru_awan/$n.dart'));
          expect(pola.hasMatch(sumber), isFalse, reason: '$n: Text literal');
        }
      },
    );

    test('tanpa label KAPITAL dan tanpa istilah terlarang', () {
      for (final jalur in semua) {
        final sumber = _tanpaKomentar(_baca(jalur)).toLowerCase();
        expect(sumber, isNot(contains('touppercase')), reason: jalur);
        expect(sumber, isNot(contains('daluwarsa')), reason: jalur);
        expect(sumber, isNot(contains('adaluarsa')), reason: jalur);
      }
    });

    test('tanpa gradien, bayangan Material, dan kaca di komponen', () {
      for (final n in berkas) {
        final sumber = _tanpaKomentar(_baca('lib/widgets/biru_awan/$n.dart'));
        for (final t in [
          'LinearGradient',
          'RadialGradient',
          'BackdropFilter',
        ]) {
          expect(sumber.contains(t), isFalse, reason: '$n: $t');
        }
        // Bayangan: hanya Mulai (60) di `tombol_bulat.dart`.
        if (n != 'tombol_bulat') {
          expect(sumber.contains('BoxShadow'), isFalse, reason: n);
        }
      }
    });
  });
}
