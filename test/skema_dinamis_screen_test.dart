import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/skema_dokumen.dart';
import 'package:sidik_calibration/screens/calibration/skema_dinamis_screen.dart';
import 'package:sidik_calibration/services/analisis_dokumen.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Ujung rantai generik: schema yang lahir dari dokumen digambar jadi FORM.
///
/// Ini yang bikin `UNKNOWN WORKSHEET` beneran sampai ke tangan teknisi. Tanpa
/// layar ini rantainya berhenti di `SkemaDokumen` dan nggak pernah kelihatan.
void main() {
  const analisis = AnalisisDokumen();
  const pembuat = PembuatSkema();

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 12, 20),
    keyakinan: keyakinan,
  );

  SkemaDokumen skemaDari(List<TeksTerbaca> ocr, {String? judul}) {
    final d = analisis.bacaDokumen(ocr);
    return pembuat.susun(pasangan: d.pasangan, tabel: d.tabel, judul: judul);
  }

  Future<SkemaDokumen?> buka(WidgetTester tester, SkemaDokumen s) async {
    SkemaDokumen? hasil;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              hasil = await Navigator.of(context).push<SkemaDokumen>(
                MaterialPageRoute(
                  builder: (_) => SkemaDinamisScreen(skema: s),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    return hasil;
  }

  /// Lembar torque wrench — bukan lembar mana pun yang dikenal aplikasi ini.
  SkemaDokumen lembarBaru() => skemaDari(judul: 'Torque Wrench Calibration', [
    kata('Nama', 100, 100),
    kata('Alat', 160, 100),
    kata(':', 240, 100),
    kata('Tohnichi', 270, 100),
    kata('Kapasitas', 100, 140),
    kata(':', 220, 140),
    kata('200', 250, 140),
    kata('Nm', 300, 140),
    kata('No', 100, 220),
    kata('Target', 300, 220),
    kata('Hasil', 500, 220),
    kata('1', 100, 260),
    kata('50', 300, 260),
    kata('49,8', 500, 260),
  ]);

  testWidgets('form digambar dari dokumen, bukan dari daftar field', (
    tester,
  ) async {
    await buka(tester, lembarBaru());

    expect(find.text('Torque Wrench Calibration'), findsOneWidget);
    expect(find.text('Nama Alat'), findsOneWidget);
    expect(find.text('Kapasitas'), findsOneWidget);
    expect(
      find.text('Nm'),
      findsOneWidget,
      reason: 'Satuannya dari DOKUMEN. Nggak ada daftar satuan per alat di '
          'jalur ini.',
    );
  });

  testWidgets('tabelnya ikut digambar dengan kepala kolom dari kertasnya', (
    tester,
  ) async {
    await buka(tester, lembarBaru());

    for (final k in ['No', 'Target', 'Hasil']) {
      expect(find.text(k), findsOneWidget, reason: 'kepala kolom $k');
    }
  });

  testWidgets('kolom tanpa satuan disebut begitu, bukan dikasih satuan bawaan', (
    tester,
  ) async {
    await buka(tester, lembarBaru());

    expect(
      find.text('tanpa satuan'),
      findsWidgets,
      reason: 'Nebak satuan di lembar kalibrasi itu mengarang.',
    );
  });

  testWidgets('koreksi teknisi yang pulang, bukan bacaan OCR-nya', (
    tester,
  ) async {
    SkemaDokumen? hasil;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              hasil = await Navigator.of(context).push<SkemaDokumen>(
                MaterialPageRoute(
                  builder: (_) => SkemaDinamisScreen(skema: lembarBaru()),
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Tohnichi'), 'Kanon');
    await tester.pump();

    await tester.tap(find.text('SIMPAN HASIL BACAAN'));
    await tester.pumpAndSettle();

    final k = hasil!.kolom.firstWhere((x) => x.label == 'Nama Alat');

    expect(k.nilai, 'Kanon');
    expect(
      k.keyakinan,
      hasil!.kolom.first.keyakinan,
      reason: 'Keyakinan OCR aslinya dibawa apa adanya. Dinaikin gara-gara '
          'diketik ulang, jejak "mana yang dibaca mesin" hilang.',
    );
  });

  testWidgets('peringatan penganalisis ditampilkan, bukan disembunyikan', (
    tester,
  ) async {
    await buka(
      tester,
      skemaDari([
        kata('Merk', 100, 100),
        kata(':', 160, 100),
        kata('Fluke', 190, 100),
        kata('Merk', 100, 160),
        kata(':', 160, 160),
        kata('Tohnichi', 190, 160),
      ]),
    );

    expect(
      find.textContaining('Merk'),
      findsWidgets,
      reason: 'Nyembunyiin peringatan bikin teknisi mengira bacaannya utuh '
          'padahal penganalisisnya sendiri ragu.',
    );
  });

  testWidgets('foto yang nggak menghasilkan apa-apa: tombol simpan MATI', (
    tester,
  ) async {
    await buka(tester, skemaDari([kata('coret', 100, 100)]));

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'Nyimpen nol isian cuma bikin catatan kosong yang keliatan '
          'seperti pekerjaan yang sudah dilakukan.',
    );
  });

  testWidgets('nilai bervonis merah mulai KOSONG, sama seperti layar review', (
    tester,
  ) async {
    // Keyakinan rendah → merah → kotaknya dikosongkan.
    await buka(
      tester,
      skemaDari([
        kata('Suhu', 100, 100, keyakinan: 0.99),
        kata(':', 160, 100, keyakinan: 0.99),
        kata('25,4', 190, 100, keyakinan: 0.11),
      ]),
    );

    expect(
      find.widgetWithText(TextField, '25,4'),
      findsNothing,
      reason: 'Nampilin bacaan yang divonis nggak bisa dipercaya bikin '
          'teknisi cuma menyetujui apa yang udah ada.',
    );
  });

  testWidgets('tombol simpan MATI selama nilai merah masih kosong', (
    tester,
  ) async {
    await buka(
      tester,
      skemaDari([
        kata('Suhu', 100, 100, keyakinan: 0.99),
        kata(':', 160, 100, keyakinan: 0.99),
        kata('25,4', 190, 100, keyakinan: 0.11),
      ]),
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'Layar ini sendiri yang mengosongkan kotaknya. Dibiarin bisa '
          'disimpan, bacaan yang divonis nggak bisa dipercaya pulang sebagai '
          'isian KOSONG — dan yang baca nanti nggak bisa bedain itu dari kolom '
          'yang dokumennya sendiri emang nggak ngisi.',
    );
  });

  testWidgets('tombol simpan HIDUP begitu nilai merahnya diisi', (
    tester,
  ) async {
    await buka(
      tester,
      skemaDari([
        kata('Suhu', 100, 100, keyakinan: 0.99),
        kata(':', 160, 100, keyakinan: 0.99),
        kata('25,4', 190, 100, keyakinan: 0.11),
      ]),
    );

    await tester.enterText(find.byType(TextField), '25,4');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
      reason: 'Penghalangnya buat maksa teknisi MENGETIK, bukan buat bikin '
          'layarnya buntu.',
    );
  });

  testWidgets('yang kuning nggak ikut menghalangi — cukup dilihat', (
    tester,
  ) async {
    await buka(
      tester,
      skemaDari([
        kata('Merk', 100, 100, keyakinan: 0.99),
        kata(':', 160, 100, keyakinan: 0.99),
        kata('Fluke', 190, 100, keyakinan: 0.99),
      ]),
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
      reason: 'Aturannya sama persis dengan FotoReviewScreen: merah doang. '
          'Maksa ngetik ulang tiap sel yang bacaannya udah bener bikin '
          'teknisi berhenti make fiturnya.',
    );
  });

  test('vonis di jalur generik ikut aturan yang sama', () {
    final s = skemaDari([
      kata('Suhu', 100, 100, keyakinan: 0.99),
      kata(':', 160, 100, keyakinan: 0.99),
      kata('25,4', 190, 100, keyakinan: 0.99),
    ]);

    expect(
      s.kolom.single.vonis,
      VonisFoto.kuning,
      reason: 'Tulisan tangan nggak pernah hijau — termasuk di lembar yang '
          'belum dikenal, yang justru lebih perlu diperiksa.',
    );
  });
}
