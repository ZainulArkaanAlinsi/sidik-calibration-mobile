import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Aturan pemilik: tidak ada nilai yang boleh mendarat di kolom yang salah.
///
/// 1. FM-0515 (Centrifuge/Tachometer): Before dan After satu `grup`, jadi
///    `tabel_id` server unik per tahap dan HP mencocokkan `tabel_id` DAN
///    `tahap` — angka After tidak pernah masuk Before.
/// 2. Formulir bertanda `perlu_konfirmasi_lab` (asumsi posisional) tidak punya
///    pintu foto.
/// 3. Batas `aturan` per sel dicek di HP: di luar pita = merah dan kosong.
const _idSebelum = 'pembacaan_standar_sebelum_adjustment';
const _idSesudah = 'pembacaan_standar_sesudah_adjustment';

class _MesinPalsu extends JalankanPindaiAsli {
  _MesinPalsu(this.bacaan)
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  /// kunci sel → teks
  final Map<String, String> bacaan;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
  }) async => HasilBacaAsli(
    kodeTerbaca: 'SIDIK-FM-CAL-0515',
    sel: [
      for (final s in template.selAsli)
        if (bacaan[s.kunci] case final t?)
          (sel: s, bacaan: (teks: t, keyakinan: 0.97, didalamKotak: true)),
    ],
  );
}

void main() {
  late LembarKerja bentuk;
  late Map<String, dynamic> dasar;
  late File fotoSintetis;

  setUpAll(() {
    bentuk = LembarKerja.fromJson(
      jsonDecode(
            File(
              'test/fixtures/lembar-kerja-centrifuge.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    dasar =
        (jsonDecode(
                  File(
                    'test/assets/template-asli-ph_meter-0509.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final dir = Directory.systemTemp.createTempSync('foto-0515');
    fotoSintetis = File('${dir.path}/lembar.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 48)));
  });

  List<TabelHasil> tabelDari() => [for (final b in bentuk.bagian) ...b.tabel];

  TabelHasil tabel(String tahap) =>
      tabelDari().firstWhere((t) => t.tahap == tahap);

  LembarKerjaState buatState() {
    final s = LembarKerjaState(bentuk: bentuk, clientRequestId: 'uji');
    addTearDown(s.dispose);

    return s;
  }

  double titik(LembarKerjaState s, TabelHasil t, int i) =>
      s.titik[s.kunciBaris(s.barisTabel(t), i, t)]!.titikUkur;

  String teks(LembarKerjaState s, TabelHasil t, double titikUkur, int ke) => s
      .titikBarisTabel(t, titikUkur)!
      .kotak(t.kunciTabel, t.kolom.first.kode, ke)
      .text;

  SelDipakaiPindai sel(
    TabelHasil t,
    String id,
    double titikUkur,
    double nilai,
  ) => (
    tabelId: id,
    tahap: t.tahap,
    titikUkur: titikUkur,
    repeatNo: t.pengulangan.first,
    fieldId: t.kolom.first.kode,
    nilai: nilai,
    perluDicek: false,
  );

  /// Template asli 0515 untuk uji alur: tabel Before + After (id unik seperti
  /// server), sel hanya After (peta cuma memetakan After). Kotaknya dipinjam
  /// dari template pH — yang diuji penyambungan, bukan geometri.
  WorksheetTemplate templateAsli0515({
    Map<String, dynamic>? aturan,
    bool perluKonfirmasi = false,
  }) {
    final s = LembarKerjaState(bentuk: bentuk, clientRequestId: 'tmp');
    addTearDown(s.dispose);
    final sesudah = tabel('sesudah_adjustment');
    final kotak = (dasar['sel'] as Map<String, dynamic>).values
        .map((e) => (e as Map<String, dynamic>)['kotak'])
        .toList();

    final data = Map<String, dynamic>.from(dasar)
      ..['template_id'] = 'centrifuge'
      ..['kode_dokumen'] = 'SIDIK-FM-CAL-0515'
      ..['perlu_konfirmasi_lab'] = perluKonfirmasi
      ..['tabel'] = [
        for (final t in tabelDari())
          {
            'tabel_id': t.tahap == 'sebelum_adjustment'
                ? _idSebelum
                : _idSesudah,
            'tahap': t.tahap,
            'grup': t.grup,
            'judul': t.judul,
            'baris': [],
            'kolom': [],
            'pengulangan': t.pengulangan,
          },
      ]
      ..['sel'] = {
        for (var i = 0; i < 2; i++)
          '$_idSesudah|${i + 1}|1|pembacaan': {
            'kunci': '$_idSesudah|${i + 1}|1|pembacaan',
            'tabel_id': _idSesudah,
            'tahap': 'sesudah_adjustment',
            'grup': 'pembacaan_standar',
            'baris_ke': i + 1,
            'repeat_no': sesudah.pengulangan.first,
            'field_id': 'pembacaan',
            'titik_ukur': titik(s, sesudah, i),
            'standard_id': null,
            'aturan': ?aturan,
            'kotak': kotak[i],
          },
      };

    return WorksheetTemplate.fromJson({'data': data});
  }

  group('FM-0515: Before dan After tidak tertukar', () {
    test('fixture memuat dua tabel satu grup', () {
      final t = tabelDari();
      expect(t.map((e) => e.tahap), [
        'sebelum_adjustment',
        'sesudah_adjustment',
      ]);
      expect(t.map((e) => e.grup).toSet(), {'pembacaan_standar'});
    });

    test('After (id+tahap) mendarat di After; Before tetap kosong', () {
      final s = buatState();
      final before = tabel('sebelum_adjustment');
      final after = tabel('sesudah_adjustment');
      final t0 = titik(s, after, 0);

      final terisi = s.terapkanHasilPindai([sel(after, _idSesudah, t0, 1234)]);

      expect(terisi, 1);
      expect(teks(s, after, t0, 0), isNotEmpty);
      for (final t in s.titik.values) {
        for (var ke = 0; ke < t.jumlahPengulangan; ke++) {
          expect(
            t.kotak(before.kunciTabel, before.kolom.first.kode, ke).text,
            isEmpty,
            reason: 'Before harus kosong',
          );
        }
      }
    });

    test('Before (id+tahap) mendarat di Before, bukan After', () {
      final s = buatState();
      final before = tabel('sebelum_adjustment');
      final after = tabel('sesudah_adjustment');
      final t0 = titik(s, before, 0);

      expect(s.terapkanHasilPindai([sel(before, _idSebelum, t0, 77)]), 1);
      expect(teks(s, before, t0, 0), isNotEmpty);
      expect(teks(s, after, t0, 0), isEmpty);
    });

    test(
      'id lama kembar (server lama) atau id dan tahap bertabrakan: dibuang',
      () {
        final s = buatState();
        final after = tabel('sesudah_adjustment');
        final before = tabel('sebelum_adjustment');
        final t0 = titik(s, after, 0);

        // Server lama: kedua tabel berid `pembacaan_standar`.
        expect(
          s.terapkanHasilPindai([sel(after, 'pembacaan_standar', t0, 5)]),
          0,
        );
        // id After tetapi tahap Before.
        expect(
          s.terapkanHasilPindai([
            (
              tabelId: _idSesudah,
              tahap: 'sebelum_adjustment',
              titikUkur: t0,
              repeatNo: 1,
              fieldId: 'pembacaan',
              nilai: 5.0,
              perluDicek: false,
            ),
          ]),
          0,
        );
        expect(teks(s, before, t0, 0), isEmpty);
        expect(teks(s, after, t0, 0), isEmpty);
      },
    );

    test('foto lembar kerja: sel After mendarat di After saja', () {
      final s = buatState();
      final template = templateAsli0515();
      final before = tabel('sebelum_adjustment');
      final after = tabel('sesudah_adjustment');
      final t0 = titik(s, after, 0);

      expect(s.bisaMenerimaFotoAsli(template), isTrue);

      final terisi = s.terapkanHasilFotoAsli([
        (
          tabelId: _idSesudah,
          tahap: 'sesudah_adjustment',
          barisKe: 1,
          repeatNo: after.pengulangan.first,
          fieldId: 'pembacaan',
          teks: '1500',
          keyakinan: 0.9,
        ),
      ]);

      expect(terisi, 1);
      expect(teks(s, after, t0, 0), isNotEmpty);
      expect(teks(s, before, t0, 0), isEmpty);
    });
  });

  group('perlu_konfirmasi_lab', () {
    test('model: pintu foto tertutup walau mode uji dan siap pindai nyala', () {
      final data = Map<String, dynamic>.from(dasar)
        ..['mode_uji'] = true
        ..['siap_pindai'] = true
        ..['perlu_konfirmasi_lab'] = true;
      final t = WorksheetTemplate.fromJson({'data': data});

      expect(t.perluKonfirmasiLab, isTrue);
      expect(t.bolehDipindaiAsli, isFalse);
    });

    test('tanpa flag: perilaku lama (mode uji membuka pintu)', () {
      final data = Map<String, dynamic>.from(dasar)..['mode_uji'] = true;
      final t = WorksheetTemplate.fromJson({'data': data});

      expect(t.perluKonfirmasiLab, isFalse);
      expect(t.bolehDipindaiAsli, isTrue);
    });

    test('mesin menolak formulir yang menunggu konfirmasi lab', () async {
      final data = Map<String, dynamic>.from(dasar)
        ..['mode_uji'] = true
        ..['perlu_konfirmasi_lab'] = true;
      final t = WorksheetTemplate.fromJson({'data': data});

      await expectLater(
        JalankanPindaiAsli(
          halaman: MockPembacaHalaman(const []),
          pembaca: MockPembacaSel(),
        ).baca(img.Image(width: 64, height: 48), template: t),
        throwsA(
          isA<PindaiAsliGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindaiAsli.belumSiap,
          ),
        ),
      );
    });
  });

  group('batas aturan per sel di HP', () {
    const pita = {
      'tipe': 'desimal',
      'nominal': 500.0,
      'min': 400.0,
      'maks': 600.0,
      'rasio_min': 0.5,
      'rasio_maks': 2.0,
    };

    test('AturanSelAsli: rentang dan rasio seperti server', () {
      final a = AturanSelAsli.dari(pita)!;
      expect(a.lolos(500), isTrue);
      expect(a.lolos(400), isTrue);
      expect(a.lolos(601), isFalse); // di luar rentang
      expect(a.lolos(399), isFalse);

      const rasioSaja = AturanSelAsli(
        nominal: 100,
        rasioMin: 0.5,
        rasioMaks: 2.0,
      );
      expect(rasioSaja.lolos(1000), isFalse); // koma geser
      expect(rasioSaja.lolos(0), isTrue); // nol tidak dirasiokan
      expect(AturanSelAsli.dari({'tipe': 'jam'}), isNull);
      expect(AturanSelAsli.dari(null), isNull);
    });

    Future<void> jalankan(
      WidgetTester tester,
      LembarKerjaState isian,
      WorksheetTemplate template,
      Map<String, String> bacaan,
    ) async {
      final salinan = File(
        '${fotoSintetis.path}.${DateTime.now().microsecondsSinceEpoch}',
      )..writeAsBytesSync(fotoSintetis.readAsBytesSync());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sumberFotoProvider.overrideWithValue(MockSumberFoto(file: salinan)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('id'),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => pindaiFormulirAsli(
                    context: context,
                    ref: ref,
                    isian: isian,
                    template: template,
                    mesin: _MesinPalsu(bacaan),
                  ),
                  child: const Text('foto'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('foto'));
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(FilledButton).evaluate().isNotEmpty) break;
      }
    }

    testWidgets(
      'di luar pita: merah dan kosong; di dalam pita: usulan kuning',
      (tester) async {
        final isian = buatState();
        final template = templateAsli0515(aturan: pita);

        await jalankan(tester, isian, template, {
          '$_idSesudah|1|1|pembacaan': '510', // dalam pita
          '$_idSesudah|2|1|pembacaan': '5100', // koma geser: luar pita
        });

        final isi = tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller!.text)
            .toList();

        expect(isi, hasLength(2));
        expect(
          isi.where((t) => t.isEmpty),
          hasLength(1),
          reason: 'merah kosong',
        );
        expect(isi.where((t) => t == '510'), hasLength(1));
        expect(isi, isNot(contains('5100')));
      },
    );

    testWidgets('tanpa aturan di sel: angka yang sama tetap jadi usulan', (
      tester,
    ) async {
      final isian = buatState();
      final template = templateAsli0515();

      await jalankan(tester, isian, template, {
        '$_idSesudah|1|1|pembacaan': '510',
        '$_idSesudah|2|1|pembacaan': '5100',
      });

      final isi = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller!.text)
          .toList();

      expect(isi.toSet(), {'510', '5100'});
    });

    testWidgets('alur penuh: After masuk After, Before tetap kosong', (
      tester,
    ) async {
      final isian = buatState();
      final template = templateAsli0515();
      final before = tabel('sebelum_adjustment');
      final after = tabel('sesudah_adjustment');
      final t0 = titik(isian, after, 0);
      final t1 = titik(isian, after, 1);

      await jalankan(tester, isian, template, {
        '$_idSesudah|1|1|pembacaan': '1500',
        '$_idSesudah|2|1|pembacaan': '1600',
      });

      final cek = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('cek-'),
      );
      final jumlah = tester.widgetList(cek).length;
      for (var i = 0; i < jumlah; i++) {
        await tester.tap(cek.at(i));
        await tester.pump();
      }

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(teks(isian, after, t0, 0), '1500');
      expect(teks(isian, after, t1, 0), '1600');
      for (final t in [t0, t1]) {
        expect(teks(isian, before, t, 0), isEmpty);
      }
      expect(isian.adaIsianDariFoto, isTrue);
    });
  });
}
