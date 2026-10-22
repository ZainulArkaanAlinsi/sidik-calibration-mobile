import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_tekanan.dart';

/// Baris titik sesi NONAKTIF baca-saja di SEMUA tampilan — bukan cuma tabel.
/// Kartu per baris (Timer berpasangan) dan kartu per set point Tekanan
/// (termasuk kotak set point yang diketik) memakai aturan yang sama dengan
/// `LembarKerjaState.titikBisaDiisi`, dan menampilkan alasannya.
void main() {
  Map<String, dynamic> batas({
    required String nominal,
    required List<num> bawaan,
    required int maks,
    bool pertamaWajibAktif = false,
    Map<String, int>? pengulangan,
  }) => {
    'didukung': true,
    'tabel': [
      {
        'kode': 'utama',
        'judul': 'Set point',
        'min': 1,
        'maks': maks,
        'boleh_tambah': true,
        'boleh_nonaktif': true,
        'pertama_wajib_aktif': pertamaWajibAktif,
        'nominal': nominal,
        'bawaan': bawaan,
        'fase': ['sesudah'],
        'pengulangan': pengulangan,
      },
    ],
  };

  Widget bungkus(LembarKerjaState isian, List<TabelHasil> tabel) => MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LembarKerjaKartuBaris(
          tabel: tabel,
          isian: isian,
          onBerubah: () {},
          berbintang: false,
        ),
      ),
    ),
  );

  bool aktif(WidgetTester tester, String kunci) =>
      tester.widget<TextField>(find.byKey(ValueKey(kunci))).enabled ?? true;

  group('Tekanan — kartu per set point', () {
    LembarKerjaState isianTekanan() {
      final m = contohBentukLembarKerjaPressureGauge()
        ..['batas_titik'] = batas(
          nominal: 'bebas',
          bawaan: const [],
          maks: 14,
          pertamaWajibAktif: true,
          pengulangan: {'min': 3, 'maks': 3, 'bawaan': 3},
        )
        ..['titik_sesi_bawaan'] = <Object>[];
      return LembarKerjaState(
          bentuk: LembarKerja.fromJson(m),
          clientRequestId: 'uji-kartu-tekanan',
        )
        ..alat = const EquipmentLookup(
          id: 9,
          namaAlat: 'Pressure Gauge',
          serialNumber: 'PG-1',
          kategori: 'tekanan',
          status: 'aktif',
          satuan: 'bar',
          rangeMax: 10,
        );
    }

    List<TabelHasil> tabelKartu(LembarKerjaState isian) => isian.bentuk.bagian
        .firstWhere((b) => b.kode == 'hasil')
        .tabel
        .where((t) => t.simpanKe?.startsWith('measurements[].') ?? false)
        .toList();

    testWidgets('baris nonaktif terkunci (set point, UP, DOWN) + alasan', (
      tester,
    ) async {
      final isian = isianTekanan();
      for (final n in [0, 5, 10]) {
        expect(
          isian.tambahTitikSesi(tabel: 'utama', nominal: n.toDouble()),
          isNull,
        );
      }
      final tabel = tabelKartu(isian);
      expect(tabel.length, greaterThanOrEqualTo(2));

      // Pembacaan di baris kedua (5 bar), UP dan DOWN.
      for (final t in tabel) {
        isian
                .titikUntukBaris(isian.barisTabel(t), 1, t)!
                .kotak(t.kunciTabel, t.kolom.first.kode, 0)
                .text =
            '5,01';
      }

      final id = isian.titikSesi.titikDenganNominal(5)!.id;
      expect(isian.nonaktifkanTitikSesi(id, 'manometer bocor'), isNull);

      await tester.pumpWidget(bungkus(isian, tabel));

      expect(aktif(tester, 'kartu-nominal-2'), isFalse);
      for (var k = 0; k < tabel.length; k++) {
        expect(aktif(tester, 'kartu-t$k-2-0'), isFalse, reason: 'tabel $k');
        expect(aktif(tester, 'kartu-t$k-1-0'), isTrue, reason: 'baris aktif');
      }
      expect(aktif(tester, 'kartu-nominal-1'), isTrue);
      expect(find.byKey(const ValueKey('kartu-nonaktif-2')), findsOneWidget);
      expect(find.text('nonaktif — manometer bocor'), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-nonaktif-1')), findsNothing);

      // Pembacaannya tetap ada — dibekukan, bukan dikosongkan.
      for (final t in tabel) {
        expect(
          isian
              .titikUntukBaris(isian.barisTabel(t), 1, t)!
              .kotak(t.kunciTabel, t.kolom.first.kode, 0)
              .text,
          '5,01',
        );
      }

      // Aktifkan lagi → kotaknya kebuka lagi.
      expect(isian.aktifkanTitikSesi(id), isNull);
      await tester.pumpWidget(bungkus(isian, tabel));
      expect(aktif(tester, 'kartu-nominal-2'), isTrue);
      expect(aktif(tester, 'kartu-t0-2-0'), isTrue);
      expect(find.byKey(const ValueKey('kartu-nonaktif-2')), findsNothing);
    });
  });

  group('Timer — kartu per baris (berpasangan)', () {
    LembarKerjaState isianTimer() {
      final m =
          jsonDecode(
                File(
                  'test/fixtures/lembar-kerja-timer_stopwatch.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      const nominal = [60, 300, 600, 900, 1800, 2400, 3600, 120, 180, 240];
      m['batas_titik'] = batas(
        nominal: 'saran',
        bawaan: nominal,
        maks: 10,
        pengulangan: {'min': 2, 'maks': 10, 'bawaan': 3},
      );
      m['titik_sesi_bawaan'] = [
        for (var i = 0; i < nominal.length; i++)
          {
            'id': 'profil-utama-${i + 1}',
            'tabel': 'utama',
            'nominal': nominal[i],
            'asal': 'profil',
          },
      ];
      return LembarKerjaState(
        bentuk: LembarKerja.fromJson(m),
        clientRequestId: 'uji-kartu-timer',
      );
    }

    testWidgets('kartu titik nonaktif terkunci, kartu lain tidak', (
      tester,
    ) async {
      final isian = isianTimer();
      final tabel = isian.bentuk.bagian
          .expand((b) => b.tabel)
          .where((t) => t.berpasangan)
          .toList();
      expect(tabel, hasLength(2));

      expect(
        isian.nonaktifkanTitikSesi(
          isian.titikSesi.titikDenganNominal(300)!.id,
          'tidak dipakai pelanggan',
        ),
        isNull,
      );

      await tester.pumpWidget(bungkus(isian, tabel));

      // Baris ke-2 = 300 s (urut set). Tabel standar berkolom empat.
      expect(aktif(tester, 'kartu-t0-2-0-0'), isFalse);
      expect(aktif(tester, 'kartu-t0-1-0-0'), isTrue);
      expect(find.text('nonaktif — tidak dipakai pelanggan'), findsOneWidget);
    });
  });

  test('batas bawah pengulangan tidak menghitung baris balok/keping', () {
    final m = contohBentukLembarKerjaPressureGauge()
      ..['batas_titik'] = batas(nominal: 'bebas', bawaan: const [], maks: 14)
      ..['titik_sesi_bawaan'] = [
        {'id': 'a', 'tabel': 'utama', 'nominal': 5},
      ];
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(m),
      clientRequestId: 'uji-ulang',
    );

    RawMeasurement baris(double titik, int ke, {String? peran}) =>
        RawMeasurement(
          id: ke,
          titikKe: 1,
          titikUkur: titik,
          pembacaanKe: ke,
          pembacaan: 1,
          inputSource: 'manual',
          isVerified: true,
          peranSensor: peran,
        );

    expect(
      isian.pengulanganTersimpanTerjauh([
        baris(5, 3, peran: 'mikro_pembacaan'),
        baris(5, 9, peran: 'mikro_balok'),
        baris(5, 8, peran: 'nominal'),
        baris(77, 7), // bukan titik set
      ]),
      3,
    );
  });
}
