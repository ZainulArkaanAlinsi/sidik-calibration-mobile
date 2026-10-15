import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/models/enclosure_sertifikat.dart';
import 'package:sidik_calibration/widgets/enclosure_sertifikat_panel.dart';

/// Sertifikat Enclosure (Oven/Furnace/Bath/Inkubator/Refrigerator) dan
/// koreksi yang tidak dikirim server.
///
/// Bentuk `snapshot.enclosure` mengikuti kontrak
/// `docs/perintah-frontend-enclosure.md` §6 repo API (15 Okt 2026): `hasil`
/// alat ini `[]`, isinya tabel A Sebaran Suhu (per posisi termokopel) dan
/// tabel B Kinerja Enklosur. `sensor[i]` sejajar `posisi[i]`; `null` = kolom
/// kosong dan TIDAK boleh menggeser kolom lain.
Map<String, dynamic> _snapshotEnclosure({Map<String, dynamic>? timpa}) => {
  'desimal': 1,
  'satuan': '°C',
  'header': {'certificate_number': 'CAL/2026/10/0099'},
  'hasil': const <Object>[],
  'catatan': const <Object>[],
  'standar_digunakan': const <Object>[],
  'footer': const <String, Object>{},
  'enclosure': {
    'satuan': '°C',
    'desimal': 1,
    'desimal_u95': 2,
    'desimal_k': 2,
    'tanda_nol': true,
    'posisi': [
      {'posisi': 1, 'no': 3},
      {'posisi': 2, 'no': 4},
      {'posisi': 3, 'no': 5},
    ],
    'set_point': [
      {
        'titik_ke': 1,
        'set_point': 25.5,
        'indikator': 25.5,
        'sensor_acuan': 3,
        'posisi_acuan': 1,
        'sensor': [
          {
            'posisi': 1,
            'no': 3,
            'channel': null,
            'terukur': 24.60625,
            'koreksi': -0.89375,
          },
          // Termokopel no. 4 kosong di set point ini.
          null,
          {
            'posisi': 3,
            'no': 5,
            'channel': null,
            'terukur': 25.83,
            'koreksi': 0.33,
          },
        ],
        'keseragaman': 0.8,
        'kestabilan': 0.17,
        'variasi_keseluruhan': 1.3,
        'u95': 1.4,
        'faktor_cakupan_k': 1.9615165,
      },
      {
        'titik_ke': 2,
        'set_point': 50,
        'indikator': 50.2,
        'sensor_acuan': 3,
        'posisi_acuan': 1,
        'sensor': [
          {'posisi': 1, 'no': 3, 'terukur': 49.91, 'koreksi': -0.29},
          {'posisi': 2, 'no': 4, 'terukur': 50.44, 'koreksi': 0.24},
          {'posisi': 3, 'no': 5, 'terukur': 50.08, 'koreksi': -0.12},
        ],
        'keseragaman': 0.53,
        'kestabilan': 0.21,
        'variasi_keseluruhan': 0.74,
        'u95': 1.5,
        'faktor_cakupan_k': 1.9615165,
      },
    ],
  },
  ...?timpa,
};

Future<void> _pasangPanel(WidgetTester tester, EnclosureSertifikat e) async {
  tester.view.physicalSize = const Size(1800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: EnclosureSertifikatPanel(enclosure: e),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('parsing snapshot.enclosure', () {
    test('blok enclosure terbaca utuh, hasil tetap kosong', () {
      final s = CertificateSnapshot.fromJson(_snapshotEnclosure());
      final e = s.enclosure!;

      expect(s.hasil, isEmpty);
      expect(e.desimal, 1);
      expect(e.desimalU95, 2);
      expect(e.desimalK, 2);
      expect(e.tandaNol, isTrue);
      expect(e.posisi.map((p) => p.no), [3, 4, 5]);
      expect(e.setPoint, hasLength(2));

      final sp1 = e.setPoint.first;
      expect(sp1.setPoint, 25.5);
      expect(sp1.posisiAcuan, 1);
      expect(sp1.u95, 1.4);
      expect(sp1.faktorCakupanK, closeTo(1.9615165, 1e-9));
      // Presisi penuh, tidak dibulatkan waktu dibaca.
      expect(sp1.sensorDi(0)!.terukur, 24.60625);
      expect(sp1.sensorDi(0)!.koreksi, -0.89375);
    });

    test('sensor null tetap di posisinya — kolom tidak bergeser', () {
      final sp1 = CertificateSnapshot.fromJson(
        _snapshotEnclosure(),
      ).enclosure!.setPoint.first;

      expect(sp1.sensor, hasLength(3));
      expect(sp1.sensorDi(1), isNull);
      expect(sp1.sensorDi(2)!.no, 5);
      // Di luar daftar = kosong, bukan galat.
      expect(sp1.sensorDi(9), isNull);
    });

    test('sertifikat alat lain / sertifikat lama: enclosure null', () {
      final s = CertificateSnapshot.fromJson({
        'header': const <String, Object>{},
        'hasil': [
          {
            'titik_ke': 1,
            'standard_value': 4.0,
            'unit_under_test': 4.02,
            'correction': -0.02,
            'u95': 0.03,
          },
        ],
      });
      expect(s.enclosure, isNull);

      expect(
        CertificateSnapshot.fromJson({
          'enclosure': const <String, Object>{},
        }).enclosure,
        isNull,
      );
    });

    test('desimal_u95 kosong jatuh ke desimal (perilaku PDF)', () {
      final e = EnclosureSertifikat.dariJson({'desimal': 2})!;
      expect(e.desimalU95, 2);
      expect(e.desimalK, isNull);
    });
  });

  group('koreksi null', () {
    test('correction yang tidak dikirim = null, BUKAN 0', () {
      final b = BarisHasilSertifikat.fromJson({
        'titik_ke': 1,
        'standard_value': 4.0,
        'unit_under_test': 4.02,
        'u95': 0.03,
      });
      expect(b.correction, isNull);
    });

    test('correction nol tetap nol — itu hasil ukur', () {
      final b = BarisHasilSertifikat.fromJson({
        'titik_ke': 1,
        'standard_value': 4.0,
        'unit_under_test': 4.0,
        'correction': 0,
        'u95': 0.03,
      });
      expect(b.correction, 0);
    });
  });

  group('panel Enclosure', () {
    testWidgets('tabel A & B dengan desimal dari snapshot', (tester) async {
      final e = CertificateSnapshot.fromJson(_snapshotEnclosure()).enclosure!;
      await _pasangPanel(tester, e);

      expect(find.text('A) SEBARAN SUHU'), findsOneWidget);
      expect(find.text('B) KINERJA ENKLOSUR'), findsOneWidget);
      expect(find.text('Sensor No. (No. 1 Sensor Acuan)'), findsOneWidget);

      // Terukur & Koreksi 1 desimal, tanda minus dipertahankan.
      expect(find.text('24,6'), findsOneWidget);
      expect(find.text('-0,9'), findsOneWidget);
      // U95 per set point, 2 desimal (`desimal_u95`).
      expect(find.text('1,40'), findsOneWidget);
      expect(find.text('1,50'), findsOneWidget);
      // Kinerja: keseragaman / kestabilan / variasi, 1 desimal.
      expect(find.text('0,8'), findsOneWidget);
      expect(find.text('0,2'), findsWidgets);
      expect(find.text('1,3'), findsOneWidget);
      // Set point & indikator.
      expect(find.text('25,5'), findsNWidgets(3));
      expect(find.text('50,0'), findsOneWidget);
    });

    testWidgets('kolom termokopel kosong ditulis strip, bukan digeser', (
      tester,
    ) async {
      final e = CertificateSnapshot.fromJson(_snapshotEnclosure()).enclosure!;
      await _pasangPanel(tester, e);

      // Posisi 2 kosong di set point 1: Terukur & Koreksi-nya strip.
      expect(find.text('—'), findsNWidgets(2));
      // Posisi 3 tetap di kolom 3 (25,8 tidak pindah ke kolom 2).
      expect(find.text('25,8'), findsOneWidget);
    });

    testWidgets('kalimat k: 2 desimal, "=" kalau k semua set point sama', (
      tester,
    ) async {
      final e = CertificateSnapshot.fromJson(_snapshotEnclosure()).enclosure!;
      await _pasangPanel(tester, e);

      expect(
        find.text(
          'The uncertainty is taken at a confidence level 95 % and coverage '
          'factor ( k ) = 1,96',
        ),
        findsOneWidget,
      );
    });

    testWidgets('k beda di presisi cetak → "≈"; acuan bergeser disebut per '
        'set point', (tester) async {
      final json = _snapshotEnclosure();
      final enc = json['enclosure'] as Map<String, dynamic>;
      final sp = (enc['set_point'] as List).cast<Map<String, dynamic>>();
      sp[1]['faktor_cakupan_k'] = 2.05;
      sp[1]['posisi_acuan'] = 2;

      await _pasangPanel(tester, CertificateSnapshot.fromJson(json).enclosure!);

      expect(find.textContaining('( k ) ≈ 1,96'), findsOneWidget);
      expect(
        find.text('Sensor No. (Sensor Acuan per set point: No. 1 / 2)'),
        findsOneWidget,
      );
    });

    testWidgets('kolom Correction tidak pernah digambar untuk Enclosure', (
      tester,
    ) async {
      final e = CertificateSnapshot.fromJson(_snapshotEnclosure()).enclosure!;
      await _pasangPanel(tester, e);

      expect(find.text('Correction'), findsNothing);
      expect(find.textContaining('Unit Under Test'), findsNothing);
    });
  });
}
