import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_spacing.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';

/// PENJAGA R1: token Biru Awan boleh berubah, TAPI tidak boleh bocor ke layar
/// "02 Pilih alat" dan lembar kerja (layar 03) (perintah pemilik, REVISI
/// 16 Nov 2026; `docs/desain-ulang/BEKU.md`).
///
/// Dua jalur kebocoran yang tidak tertangkap `BekuLembarKerja` (pembungkus
/// tema), dan dijaga di sini:
///
/// 1. NILAI BERSAMA yang dibaca area beku LANGSUNG, di luar `Theme.of`:
///    `AppSpacing.radius*` (= `BentukLab.panel/kontrol`), `SidikMaterial.sudut*`,
///    `UkuranLab`, `AppUkuran`, tiga konstanta `PaletLab` yang dibaca getter
///    `SidikMaterial.teksDiBiru/teksDiGagal`, dan `SidikTheme.gayaAngka`.
///    Semuanya dikunci dengan literal. Mengubah salah satunya = PR ini tidak
///    boleh; ubah lewat token BARU dan migrasikan layar lain saja.
/// 2. PEMAKAI: berkas area beku (daftar `BEKU.md` + dua layar 02 + widget
///    bersama yang mereka impor) TIDAK boleh membaca token/komponen yang diubah
///    R1 (`PaletLab`, `*BiruAwan`, `widgets/biru_awan/`, dock). Dipindai dari
///    sumber, jadi pemakai baru yang menyelinap ketahuan.
///
/// Bukti piksel (sebelum vs sesudah, golden macOS di CI, render Windows di
/// `rincian-r1-lab.md`) melengkapi tes ini; tes ini yang menjaga PR berikutnya.
void main() {
  group('nilai bersama yang dibaca area beku TIDAK berubah', () {
    test('BentukLab (dibaca AppSpacing, SidikMaterial, neu.dart)', () {
      expect(BentukLab.sel, 4);
      expect(BentukLab.stempel, 4);
      expect(BentukLab.panel, 8);
      expect(BentukLab.kontrol, 10);
      expect(BentukLab.utama, 16);
      expect(BentukLab.lembar, 20);
      expect(BentukLab.pil, 999);
    });

    test('AppSpacing (217 pemakaian di lembar kerja)', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
      expect(AppSpacing.radiusSm, 8);
      expect(AppSpacing.radiusMd, 10);
      expect(AppSpacing.radiusLg, 8);
    });

    test(
      'SidikMaterial: sudut permukaan (dibaca neu.dart / tabel_perhitungan)',
      () {
        expect(SidikMaterial.sudutKertas, 8);
        expect(SidikMaterial.sudutLogam, 10);
        expect(SidikMaterial.sudutKaca, 8);
      },
    );

    test('UkuranLab dan AppUkuran', () {
      expect(UkuranLab.aksiUtama, 56);
      expect(UkuranLab.aksi, 48);
      expect(UkuranLab.aksiMeja, 44);
      expect(AppUkuran.ikonSebaris, 18);
      expect(AppUkuran.ikonKeadaan, 48);
      expect(AppUkuran.sasaranSentuh, 48);
      expect(AppUkuran.garis, 1);
      expect(AppUkuran.garisTebal, 2);
      expect(AppUkuran.indikatorKecil, 24);
      expect(AppUkuran.indikatorGaris, 4);
      expect(AppUkuran.labelChipMaks, 220);
      expect(AppUkuran.ambangDuaKolom, 700);
      expect(AppUkuran.nisbiLembar, 0.8);
      expect(AppUkuran.skeletonJudul, 16);
      expect(AppUkuran.skeletonKeterangan, 12);
      expect(AppUkuran.skeletonLebarJudul, 160);
      expect(AppUkuran.skeletonLebarKeterangan, 120);
    });

    test('PaletLab: tiga konstanta yang dibaca getter SidikMaterial', () {
      // `SidikMaterial.teksDiBiru` / `teksDiGagal` membaca PaletLab, juga di
      // dalam `BekuLembarKerja` (widget bersama `SidikTombol` memakainya).
      expect(PaletLab.kertas, const Color(0xFFFFFFFF));
      expect(PaletLab.teksDiAtasPrimerGelap, const Color(0xFF0B1626));
      expect(PaletLab.gagalDiAtasGelap, const Color(0xFF24070D));
      final terang = SidikMaterial.terangDefault;
      final gelap = SidikMaterial.gelapDefault;
      expect(terang.teksDiBiru, const Color(0xFFFFFFFF));
      expect(terang.teksDiGagal, const Color(0xFFFFFFFF));
      expect(gelap.teksDiBiru, const Color(0xFF0B1626));
      expect(gelap.teksDiGagal, const Color(0xFF24070D));
    });

    test('SidikTheme.gayaAngka (dibaca lembar_kerja_screen.dart:2857)', () {
      expect(SidikTheme.keluarga, 'Inter');
      expect(SidikTheme.keluargaMono, 'IBMPlexMono');
      final g = SidikTheme.gayaAngka();
      expect(g.fontFamily, 'IBMPlexMono');
      expect(g.fontFamilyFallback, ['monospace']);
      expect(g.fontSize, 15);
      expect(g.fontWeight, FontWeight.w600);
      expect(g.letterSpacing, isNull);
      expect(g.fontFeatures, [const FontFeature.tabularFigures()]);
      final k = SidikTheme.gayaAngka(ukuran: 22, berat: FontWeight.w500);
      expect(k.fontSize, 22);
      expect(k.fontWeight, FontWeight.w500);
    });
  });

  group('pemakai: area beku tidak membaca token yang diubah R1', () {
    // Berkas beku (BEKU.md + tambahan hash) dan dua layar 02.
    const awal = <String>[
      'lib/screens/calibration/lembar_kerja_screen.dart',
      'lib/screens/calibration/lembar_kerja_state.dart',
      'lib/screens/calibration/kinerja_lembar.dart',
      'lib/screens/calibration/grid_sensor_state.dart',
      'lib/screens/calibration/titik_sesi_state.dart',
      'lib/screens/calibration/skema_dinamis_screen.dart',
      'lib/screens/calibration/temperatur_indikator_gerbang_screen.dart',
      'lib/screens/calibration/calibration_input_screen.dart',
      'lib/screens/calibration/widgets/lembar_kerja_grid.dart',
      'lib/screens/calibration/widgets/lembar_kerja_matriks.dart',
      'lib/screens/calibration/widgets/lembar_kerja_tabel.dart',
      'lib/screens/calibration/widgets/lembar_kerja_kartu_baris.dart',
      'lib/screens/calibration/widgets/keypad_angka.dart',
      'lib/screens/calibration/widgets/pengatur_titik.dart',
      'lib/screens/calibration/widgets/pengatur_titik_sesi.dart',
      'lib/screens/calibration/widgets/tanda_lompat.dart',
      'lib/screens/calibration/widgets/dropdown_gagal.dart',
      'lib/screens/calibration/cek_bacaan_kamera.dart',
      'lib/screens/calibration/verifikasi_sel_dicek.dart',
      'lib/screens/calibration/widgets/tanda_cek_sel.dart',
      'lib/screens/calibration/category_picker_screen.dart',
      'lib/screens/calibration/instrument_picker_screen.dart',
      'lib/screens/admin/widgets/tabel_perhitungan.dart',
      'lib/screens/auth/widgets/neu.dart',
    ];

    /// Token dan komponen yang R1 ubah atau yang lahir bersama R1. Pemakainya
    /// di area beku = kebocoran.
    final terlarang = <Pattern>[
      'PaletLab',
      'BentukBiruAwan',
      'UkuranBiruAwan',
      'HurufBiruAwan',
      'JarakBiruAwan',
      'UkuranKomponenBiruAwan',
      'HurufLanjutBiruAwan',
      'UkuranLanjutBiruAwan',
      'WarnaLanjutBiruAwan',
      'HurufUmpanBalikBiruAwan',
      'UkuranUmpanBalikBiruAwan',
      'WarnaUmpanBalikBiruAwan',
      'WarnaBiruAwan',
      'IsiBiruAwan',
      'widgets/biru_awan/',
      'floating_nav_bar.dart',
      'token_komponen_biru_awan',
      'token_umpan_balik_biru_awan',
      'warna_biru_awan',
      'palet_lab.dart',
    ];

    /// Impor `lib/...` dari [berkas] yang masih di dalam area yang dipindai:
    /// widget bersama (`lib/widgets/**` selain `biru_awan`) dan berkas daftar
    /// [awal]. Layar lain (navigasi keluar, mis. sertifikat) bukan area beku.
    Iterable<String> impor(String berkas) sync* {
      final isi = File(berkas).readAsStringSync();
      final re = RegExp(
        r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );
      final dir = File(berkas).parent.path.replaceAll(r'\', '/');
      for (final m in re.allMatches(isi)) {
        final p = m.group(1)!;
        String? hasil;
        if (p.startsWith('package:sidik_calibration/')) {
          hasil = 'lib/${p.substring('package:sidik_calibration/'.length)}';
        } else if (!p.startsWith('package:') && !p.startsWith('dart:')) {
          hasil = Uri.parse('$dir/').resolve(p).path;
          final i = hasil.indexOf('lib/');
          if (i >= 0) hasil = hasil.substring(i);
        }
        if (hasil == null || !File(hasil).existsSync()) continue;
        if (hasil.startsWith('lib/widgets/') || awal.contains(hasil)) {
          yield hasil;
        }
      }
    }

    final dipindai = <String>{};
    final antre = [...awal];
    while (antre.isNotEmpty) {
      final b = antre.removeLast();
      if (!dipindai.add(b)) continue;
      antre.addAll(impor(b));
    }

    test('daftar yang dipindai memuat layar 02, 03, dan widget bersamanya', () {
      expect(dipindai, containsAll(awal));
      for (final w in [
        'lib/widgets/app_button.dart',
        'lib/widgets/app_text_field.dart',
        'lib/widgets/status_badge.dart',
        'lib/widgets/skeleton.dart',
        'lib/widgets/tampil_masuk.dart',
      ]) {
        expect(dipindai, contains(w), reason: '$w harus ikut dipindai');
      }
      expect(dipindai.length, greaterThan(30));
    });

    test('tidak ada pemakai token Biru Awan di area beku', () {
      final pelanggar = <String>[];
      for (final b in dipindai) {
        final isi = File(b).readAsStringSync();
        for (final p in terlarang) {
          if (isi.contains(p)) pelanggar.add('$b memakai "$p"');
        }
      }
      expect(
        pelanggar,
        isEmpty,
        reason:
            'Area beku (lembar kerja, 02 Pilih alat) tidak boleh membaca token '
            'atau komponen Biru Awan. Pakai token BARU untuk layar lain; jangan '
            'menyentuh yang dibaca area beku (BEKU.md).',
      );
    });
  });
}
