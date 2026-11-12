import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/widgets/pilih_jenis_lembar_sheet.dart';

/// Tombol "Pilih jenis lembar manual" WAJIB selalu tampil, kode terdeteksi atau
/// tidak. Kode yang terdeteksi hanya mengisi usulan awal, tidak mengunci. Kode
/// ambigu (0504, 0507, 0513, 0514 ...) tidak diakali: semua profil yang cocok
/// ditampilkan, tanpa pilihan awal.
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
  final lembar = (data['lembar'] as List<dynamic>).cast<Map<String, dynamic>>();

  HasilJenisLembar? petunjukUntuk(String kode) {
    final l = lembar.firstWhere((x) => x['kode'] == kode);

    return detectWorksheetType(l['teks'] as String, dikenal: dikenal);
  }

  FormulirDikenal? hasilPop;

  Future<void> buka(WidgetTester tester, HasilJenisLembar? petunjuk) async {
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
                  petunjuk: petunjuk,
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

  FilledButton pakai(WidgetTester t) => t.widget<FilledButton>(tombolPakai);

  testWidgets(
    'tidak ada petunjuk: tombol manual tampil, tidak ada pilihan awal',
    (t) async {
      await buka(t, null);

      expect(tombolManual, findsOneWidget);
      expect(pakai(t).onPressed, isNull);
      expect(find.textContaining('tidak terbaca'), findsOneWidget);
    },
  );

  testWidgets('kode unik (0509): usulan awal pH Meter, tombol manual TETAP '
      'tampil dan tidak mengunci', (t) async {
    await buka(t, petunjukUntuk('SIDIK-FM-CAL-0509'));

    expect(
      find.text('Kode formulir terbaca: SIDIK-FM-CAL-0509'),
      findsOneWidget,
    );
    expect(tombolManual, findsOneWidget);
    expect(pakai(t).onPressed, isNotNull); // usulan awal terpilih

    // Teknisi menggantinya lewat daftar manual.
    await t.ensureVisible(tombolManual);
    await t.tap(tombolManual);
    await t.pumpAndSettle();
    final lain = find.byKey(PilihJenisLembarSheet.kunciBaris('turbidimeter'));
    await t.ensureVisible(lain);
    await t.tap(lain);
    await t.pumpAndSettle();
    await t.ensureVisible(tombolPakai);
    await t.tap(tombolPakai);
    await t.pumpAndSettle();

    expect(hasilPop?.templateId, 'turbidimeter');
  });

  for (final kode in const [
    'SIDIK-FM-CAL-0504',
    'SIDIK-FM-CAL-0507',
    'SIDIK-FM-CAL-0513',
    'SIDIK-FM-CAL-0514',
  ]) {
    testWidgets('kode ambigu $kode: semua profil cocok tampil, TANPA pilihan '
        'awal, tombol manual tampil', (t) async {
      final p = petunjukUntuk(kode)!;
      expect(p.kandidat.length, greaterThan(1));

      await buka(t, p);

      for (final k in p.kandidat) {
        expect(
          find.byKey(PilihJenisLembarSheet.kunciBaris(k.templateId)),
          findsOneWidget,
          reason: k.templateId,
        );
      }
      expect(tombolManual, findsOneWidget);
      expect(pakai(t).onPressed, isNull, reason: 'tidak memilihkan');
      expect(find.textContaining('beberapa jenis lembar'), findsOneWidget);

      // Teknisi memilih sendiri salah satu.
      final pilih = p.kandidat.last.templateId;
      final baris = find.byKey(PilihJenisLembarSheet.kunciBaris(pilih));
      await t.ensureVisible(baris);
      await t.tap(baris);
      await t.pumpAndSettle();
      await t.ensureVisible(tombolPakai);
      await t.tap(tombolPakai);
      await t.pumpAndSettle();

      expect(hasilPop?.templateId, pilih);
    });
  }

  testWidgets('kode sah tetapi tidak dikenal: daftar manual langsung terbuka, '
      'tombol manual tetap ada', (t) async {
    final p = detectWorksheetType('SIDIK-FM-CAL-0599', dikenal: dikenal);
    await buka(t, p);

    expect(tombolManual, findsOneWidget);
    expect(find.textContaining('tidak ada di daftar'), findsOneWidget);
    expect(
      find.byKey(PilihJenisLembarSheet.kunciBaris('ph_meter')),
      findsOneWidget,
    );
  });

  testWidgets('dua kode berbeda di satu halaman: petunjuk tidak dipakai, '
      'tombol manual tampil', (t) async {
    final p = detectWorksheetType(
      'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510',
      dikenal: dikenal,
    );
    await buka(t, p);

    expect(tombolManual, findsOneWidget);
    expect(pakai(t).onPressed, isNull);
    expect(find.textContaining('beberapa kode'), findsOneWidget);
  });

  testWidgets('petunjuk dari judul saja: tombol manual tampil, tidak '
      'memilihkan', (t) async {
    final p = detectWorksheetType(
      'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN',
      dikenal: dikenal,
    );
    await buka(t, p);

    expect(tombolManual, findsOneWidget);
    expect(find.textContaining('judul tercetak'), findsOneWidget);
    // Judul bukan pengenal: tidak memilih-awal walau tepat satu kandidat.
    expect(p!.kandidat, hasLength(1));
    expect(pakai(t).onPressed, isNull);
  });

  testWidgets('tombol manual tampil untuk SEMUA 41 formulir', (t) async {
    for (final l in lembar) {
      await buka(t, petunjukUntuk(l['kode'] as String));
      expect(tombolManual, findsOneWidget, reason: l['kode'] as String);

      // Tutup sheet untuk iterasi berikutnya.
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
    }
  });
}
