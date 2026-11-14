import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/l10n/app_localizations_en.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/widgets/tanda_cek_sel.dart';

/// Layar isian generik (alat tanpa profil): angka dari "Baca dari foto" ikut
/// gerbang "wajib dicek" yang sama dengan lembar kerja — dulu masuk ke kotak
/// biasa tanpa tanda dan tanpa gerbang.
///
/// Jalur foto aslinya butuh kamera, jadi yang diuji di sini model titiknya
/// (`TitikInput`, alias publik `_Titik`) dan kotak bertandanya.
void main() {
  group('TitikInput: angka kamera', () {
    TitikInput titikDariFoto() {
      final t = TitikInput()
        ..nilaiTarget.text = '50'
        ..isiPembacaan(['49,8', '50,1', '50,0'], dariKamera: true)
        ..tandaiTarget();

      return t;
    }

    test('semua kotak foto perlu dicek (target + tiap pembacaan)', () {
      final t = titikDariFoto();
      addTearDown(t.dispose);

      expect(t.jumlahPerluCek, 4);
      expect(t.pemantau(TitikInput.kunciTarget), isNotNull);
      expect(t.pemantau('2'), isNotNull);
    });

    test('ketikan tangan tidak ditandai; kotak kosong tidak dihitung', () {
      final t = TitikInput()
        ..nilaiTarget.text = '50'
        ..isiPembacaan(['49,8', ''], dariKamera: false);
      addTearDown(t.dispose);

      expect(t.jumlahPerluCek, 0);

      final foto = TitikInput()
        ..isiPembacaan(['49,8', ''], dariKamera: true)
        ..tandaiTarget();
      addTearDown(foto.dispose);

      expect(foto.jumlahPerluCek, 1, reason: 'sel kosong tetap kosong');
    });

    test('konfirmasi mengubah SATU kotak; mengubah angka = dicek', () {
      final t = titikDariFoto();
      addTearDown(t.dispose);

      t.cek.konfirmasi('0');
      expect(t.jumlahPerluCek, 3);

      t.pembacaan[1].text = '50,3';
      expect(t.jumlahPerluCek, 2);

      t.nilaiTarget.text = '55';
      expect(t.jumlahPerluCek, 1);
    });

    test('Listenable memberi tahu tombol Kirim saat status berubah', () {
      final t = titikDariFoto();
      addTearDown(t.dispose);

      var dipanggil = 0;
      t.dengarkan.addListener(() => dipanggil++);

      t.cek.konfirmasi('0');
      t.pembacaan[2].text = '51,0';

      expect(dipanggil, greaterThanOrEqualTo(2));
    });
  });

  testWidgets('kotak foto: ikon + kata "Perlu dicek" dan konfirmasi 48 dp', (
    tester,
  ) async {
    final t = TitikInput()..isiPembacaan(['49,8'], dariKamera: true);
    addTearDown(t.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KotakDenganCekInput(
            titik: t,
            kunci: '0',
            kotak: TextField(controller: t.pembacaan[0]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perlu dicek'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);

    final tombol = find.byKey(const ValueKey('cek-isian-0'));
    expect(tester.getSize(tombol).height, greaterThanOrEqualTo(48));

    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Sudah dicek'), findsOneWidget);
    expect(t.jumlahPerluCek, 0);
    expect(
      tombol,
      findsNothing,
      reason: 'tombol konfirmasi hilang sesudah dicek',
    );
  });

  test('judul sel grid disusun lewat l10n (id dan en)', () {
    const sel = SelCek(
      kunci: 'grid|0|t|0|0',
      jenis: JenisSelCek.grid,
      judul: '100',
      teks: '99,9',
      status: StatusCekSel.perluCek,
      sasaranLompat: 'cek:grid|0|t|0|0',
      peranGrid: PeranSelGrid.termokopel,
      setPoint: 1,
      urutanBaris: 2,
    );

    expect(
      judulSelCek(AppLocalizationsEn(), sel),
      'Set point 100 · Thermocouple 2',
    );
    expect(
      judulSelCek(AppLocalizationsId(), sel),
      'Set point 100 · Termokopel 2',
    );
  });
}
