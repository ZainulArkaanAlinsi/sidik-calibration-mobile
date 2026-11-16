import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/services/identifikasi_lembar.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/widgets/pilih_jenis_lembar_sheet.dart';

/// Lembar pilihan jenis yang menerima hasil pengenal BERLAPIS. Yang diuji:
/// pilih-awal mengikuti keputusan pengenal (bukan jumlah kandidat), dua
/// kandidat dekat tampil sebagai pilihan teratas tanpa pilih-awal, dan menu
/// manual SELALU ada. Teks masukan buatan tangan (tanpa data pelanggan).
void main() {
  final data =
      jsonDecode(
            File('test/assets/jenis-lembar-fixture.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final dikenal = <FormulirDikenal>[
    for (final d in data['dikenal'] as List<dynamic>)
      (
        templateId: (d as Map<String, dynamic>)['template_id'] as String,
        kodeDokumen: d['kode_dokumen'] as String,
        judul: d['judul'] as String,
      ),
  ];

  HasilJenisLembar? petunjuk(String teks) =>
      identifikasiLembar(teks, dikenal: dikenal);

  FormulirDikenal? hasilPop;

  Future<void> buka(WidgetTester tester, HasilJenisLembar? p) async {
    hasilPop = null;
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                hasilPop = await tampilkanPilihJenisLembar(
                  ctx,
                  petunjuk: p,
                  dikenal: dikenal,
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  final tombolManual = find.byKey(PilihJenisLembarSheet.kunciPilihManual);
  final tombolPakai = find.byKey(PilihJenisLembarSheet.kunciPakai);
  final baris = PilihJenisLembarSheet.kunciBaris;

  FilledButton pakai(WidgetTester t) => t.widget<FilledButton>(tombolPakai);
  bool terpilih(WidgetTester t, String id) =>
      t.widget<ListTile>(find.byKey(baris(id))).selected;

  const judulRusak =
      'PT. SIDIK Calibration Worksh\n'
      'et - UVIVIS Spectrophotometer LK-285-IDN\n';

  testWidgets('kode rusak + judul tergores sepakat: dipilih-awal, ditandai '
      'samar, tidak mengaku "terbaca bersih"', (t) async {
    final p = petunjuk('${judulRusak}Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI')!;
    await buka(t, p);

    expect(find.byKey(baris('spectrophotometer')), findsOneWidget);
    expect(terpilih(t, 'spectrophotometer'), isTrue);
    expect(pakai(t).onPressed, isNotNull);
    expect(find.textContaining('agak samar'), findsOneWidget);
    expect(find.textContaining('Kode formulir terbaca'), findsNothing);
    expect(tombolManual, findsOneWidget);

    await t.ensureVisible(tombolPakai);
    await t.tap(tombolPakai);
    await t.pumpAndSettle();

    expect(hasilPop?.templateId, 'spectrophotometer');
  });

  testWidgets('pilih-awal berlapis tidak mengunci: teknisi bisa menggantinya '
      'lewat daftar manual', (t) async {
    await buka(t, petunjuk('Revise : 5 SIDIK-FM-CAL-O511'));
    expect(terpilih(t, 'spectrophotometer'), isTrue);

    await t.ensureVisible(tombolManual);
    await t.tap(tombolManual);
    await t.pumpAndSettle();
    final lain = find.byKey(baris('turbidimeter'));
    await t.ensureVisible(lain);
    await t.tap(lain);
    await t.pumpAndSettle();
    await t.ensureVisible(tombolPakai);
    await t.tap(tombolPakai);
    await t.pumpAndSettle();

    expect(hasilPop?.templateId, 'turbidimeter');
  });

  testWidgets('kode benar, judul salah: kedua jenis tampil di atas, TIDAK ada '
      'yang dipilihkan', (t) async {
    final p = petunjuk(
      'PT. SIDIK Calibration Worksheet - Turbidimeter LK-285-IDN\n'
      'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509',
    )!;
    await buka(t, p);

    expect(find.byKey(baris('ph_meter')), findsOneWidget);
    expect(find.byKey(baris('turbidimeter')), findsOneWidget);
    expect(terpilih(t, 'ph_meter'), isFalse);
    expect(terpilih(t, 'turbidimeter'), isFalse);
    expect(pakai(t).onPressed, isNull);
    expect(find.textContaining('berbeda'), findsOneWidget);
    expect(tombolManual, findsOneWidget);
  });

  testWidgets('bacaan lemah: usulan teratas tampil, belum dipilihkan', (
    t,
  ) async {
    final p = petunjuk('Revise : 5 SIDIK-FM-CAL-OSII')!;
    expect(p.alasan, AlasanPetunjuk.lemah);
    await buka(t, p);

    expect(find.byKey(baris('spectrophotometer')), findsOneWidget);
    expect(terpilih(t, 'spectrophotometer'), isFalse);
    expect(pakai(t).onPressed, isNull);
    expect(find.textContaining('samar'), findsOneWidget);
  });

  testWidgets('dua kandidat dekat: keduanya jadi pilihan teratas, belum '
      'dipilihkan', (t) async {
    const duaKode = <FormulirDikenal>[
      (
        templateId: 'alat_a',
        kodeDokumen: 'SIDIK-FM-CAL-0561_Rev.1',
        judul: 'Calibration Worksheet - Alat A',
      ),
      (
        templateId: 'alat_b',
        kodeDokumen: 'SIDIK-FM-CAL-0562_Rev.1',
        judul: 'Calibration Worksheet - Alat B',
      ),
    ];
    final p = identifikasiLembar(
      'Revise : 1 SIDIK-FM-CAL-056',
      dikenal: duaKode,
    )!;
    expect(p.kandidat, hasLength(2));

    hasilPop = null;
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(
          body: PilihJenisLembarSheet(petunjuk: p, dikenal: duaKode),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(baris('alat_a')), findsOneWidget);
    expect(find.byKey(baris('alat_b')), findsOneWidget);
    expect(terpilih(t, 'alat_a'), isFalse);
    expect(terpilih(t, 'alat_b'), isFalse);
    expect(pakai(t).onPressed, isNull);
    expect(tombolManual, findsOneWidget);
  });

  testWidgets('kode bersih tetap berperilaku seperti sebelumnya: kode unik '
      'dipilih-awal dan pesannya tidak berubah', (t) async {
    await buka(t, petunjuk('Revise : 4 SIDIK-FM-CAL-0509'));

    expect(
      find.text('Kode formulir terbaca: SIDIK-FM-CAL-0509'),
      findsOneWidget,
    );
    expect(terpilih(t, 'ph_meter'), isTrue);
    expect(find.textContaining('Usulan jenis lembar'), findsOneWidget);
  });

  testWidgets('tanpa bukti: tidak ada pilihan awal, menu manual', (t) async {
    final p = petunjuk('Nama Alat : Merk : Type :');
    expect(p, isNull);
    await buka(t, p);

    expect(pakai(t).onPressed, isNull);
    expect(find.textContaining('tidak terbaca'), findsOneWidget);
    expect(tombolManual, findsOneWidget);
  });

  testWidgets('menu manual tampil untuk setiap macam keputusan pengenal', (
    t,
  ) async {
    for (final teks in [
      'Revise : 4 SIDIK-FM-CAL-0509',
      'Revise : 5 SIDIK-FM-CAL-O511',
      '${judulRusak}Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI',
      'Revise : 5 SIDIK-FM-CAL-OSII',
      'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN',
      'Page 1 of 1 SIDIK-FM-CAL-0504',
      'Page 1 of 1 SIDIK-FM-CAL-0599',
      'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510',
      'PT. SIDIK Calibration Worksheet - Turbidimeter LK-285-IDN\n'
          'Page 1 of 1 SIDIK-FM-CAL-0509',
    ]) {
      await buka(t, petunjuk(teks));
      expect(tombolManual, findsOneWidget, reason: teks);

      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
    }
  });
}
