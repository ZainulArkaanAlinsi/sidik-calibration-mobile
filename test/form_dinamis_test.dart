import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/skema_dinamis.dart';
import 'package:sidik_calibration/widgets/dinamis/form_dinamis.dart';

Map<String, dynamic> _sel(
  int r,
  int k,
  String? nilai, {
  String status = 'OK',
}) => {
  'kunci': 'bagian-0.tabel-0.sel-$r-$k',
  'baris': r,
  'kolom': k,
  'nilai': nilai,
  'sumber': 'handwriting',
  'keyakinan': status == 'OK' ? 0.96 : 0.41,
  'status': status,
};

Map<String, dynamic> _lembar({
  required String namaBagian,
  required List<String> judulKolom,
  List<Map<String, dynamic>> field = const [],
  List<List<Map<String, dynamic>>> baris = const [],
  List<String> peringatan = const [],
  int perluReview = 0,
}) => {
  'dokumen': {
    'title': 'Calibration Worksheet',
    'equipment_name': 'Conductivity Meter',
    'worksheet_code': 'SIDIK-FM-CAL-0510',
    'revision': 'Rev.5',
  },
  'bagian': [
    {
      'kunci': 'bagian-0',
      'nama': namaBagian,
      'field': field,
      'tabel': [
        {
          'kunci': 'bagian-0.tabel-0',
          'kolom': [
            for (var i = 0; i < judulKolom.length; i++)
              {'kunci': 'k$i', 'judul': judulKolom[i], 'tipe': 'number'},
          ],
          'baris': baris,
        },
      ],
    },
  ],
  'peringatan': peringatan,
  'ringkasan': {
    'jumlah_field': field.length,
    'jumlah_sel': 0,
    'perlu_review': perluReview,
  },
};

Widget _bungkus(
  SkemaDinamis skema,
  Map<String, String> nilai,
  UbahNilaiDinamis onUbah,
) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('id'),
    home: Scaffold(
      body: FormDinamis(skema: skema, nilai: nilai, onUbah: onUbah),
    ),
  );
}

void main() {
  testWidgets('form digambar dari isi dokumen — bukan dari daftar tetap', (
    t,
  ) async {
    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'Before adjustment Reading',
        judulKolom: const ['84', '1413 µS', '1.413 mS'],
        field: [
          {
            'kunci': 'bagian-0.field-0',
            'label': 'Serial Number',
            'tipe': 'text',
            'nilai': 'SN-9',
            'status': 'OK',
            'sumber': 'handwriting',
            'bisa_diisi': true,
          },
        ],
        baris: [
          [_sel(0, 0, '84,1'), _sel(0, 1, '1410'), _sel(0, 2, '1,41')],
        ],
      ),
    );

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    expect(find.text('Before adjustment Reading'), findsOneWidget);
    expect(find.text('SIDIK-FM-CAL-0510 · Rev.5'), findsOneWidget);
    // Judul kolom dari kertas, apa adanya.
    expect(find.text('84'), findsOneWidget);
    expect(find.text('1413 µS'), findsOneWidget);
    expect(find.text('1.413 mS'), findsOneWidget);
    // Nilai hasil baca sudah terisi di kotaknya.
    expect(find.text('84,1'), findsOneWidget);
    expect(find.text('SN-9'), findsOneWidget);
  });

  testWidgets('lembar dengan struktur lain menghasilkan form yang lain', (
    t,
  ) async {
    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'Effect of Tare',
        judulKolom: const ['Position', 'Standard'],
        baris: [
          [_sel(0, 0, 'Center'), _sel(0, 1, '200')],
        ],
      ),
    );

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    expect(find.text('Effect of Tare'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    // Kolom lembar sebelumnya nggak ikut kebawa.
    expect(find.text('1413 µS'), findsNothing);
  });

  testWidgets('ketikan teknisi dilaporkan lewat kunci selnya', (t) async {
    final dicatat = <String, String>{};

    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'X',
        judulKolom: const ['Reading'],
        baris: [
          [_sel(0, 0, null, status: 'REVIEW_REQUIRED')],
        ],
      ),
    );

    await t.pumpWidget(_bungkus(skema, dicatat, (k, v) => dicatat[k] = v));

    await t.enterText(find.byType(TextFormField).first, '99,5');

    expect(dicatat['bagian-0.tabel-0.sel-0-0'], '99,5');
  });

  testWidgets('tebakan berkeyakinan rendah TETAP tampil dengan angkanya', (
    t,
  ) async {
    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'X',
        judulKolom: const ['Reading'],
        field: [
          {
            'kunci': 'bagian-0.field-0',
            'label': 'Humidity',
            'tipe': 'number',
            'nilai': '5?',
            'status': 'REVIEW_REQUIRED',
            'sumber': 'handwriting',
            'keyakinan': 0.43,
            'bisa_diisi': true,
          },
        ],
        perluReview: 1,
      ),
    );

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    expect(
      find.text('5?'),
      findsOneWidget,
      reason: 'dikosongin bikin teknisi ngetik ulang dari nol',
    );
    expect(find.textContaining('Perlu diperiksa'), findsWidgets);
    expect(find.textContaining('43%'), findsOneWidget);
  });

  testWidgets('teks tercetak ditampilkan baca-saja, bukan kotak kosong', (
    t,
  ) async {
    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'X',
        judulKolom: const [],
        field: [
          {
            'kunci': 'bagian-0.field-0',
            'label': 'Standard Name',
            'tipe': 'text',
            'nilai': 'Victor 123',
            'status': 'OK',
            'sumber': 'static_document',
            'bisa_diisi': false,
          },
        ],
      ),
    );

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    expect(find.text('Victor 123'), findsOneWidget);
    expect(find.text('Tercetak'), findsOneWidget);
    // Nggak ada kotak isian buat yang tercetak.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('peringatan server ditampilkan, bukan dibuang', (t) async {
    final skema = SkemaDinamis.fromJson(
      _lembar(
        namaBagian: 'X',
        judulKolom: const [],
        peringatan: const [
          'Alat yang dipilih `pH Meter` beda dari yang terbaca di lembar `Turbidimeter`.',
        ],
      ),
    );

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    expect(find.textContaining('Turbidimeter'), findsOneWidget);
  });

  testWidgets('sel yang gagal dibaca tetap punya kotak di posisinya', (
    t,
  ) async {
    final skema = SkemaDinamis.fromJson({
      'dokumen': const {},
      'bagian': [
        {
          'kunci': 'bagian-0',
          'nama': 'X',
          'field': const [],
          'tabel': [
            {
              'kunci': 'bagian-0.tabel-0',
              'kolom': [
                {'kunci': 'k0', 'judul': 'A', 'tipe': 'number'},
                {'kunci': 'k1', 'judul': 'B', 'tipe': 'number'},
                {'kunci': 'k2', 'judul': 'C', 'tipe': 'number'},
              ],
              'baris': [
                [
                  _sel(0, 0, '1'),
                  {'bentuk': 'kacau'},
                  _sel(0, 2, '3'),
                ],
              ],
            },
          ],
        },
      ],
      'peringatan': const [],
      'ringkasan': const {},
    });

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    // Tiga kotak: yang tengah kosong tapi ADA, jadi angka ketiga nggak naik.
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tabel tanpa kolom nggak bikin seluruh form meledak', (t) async {
    // Bagian yang kelihatan bertabel tapi nggak satu selnya kebaca — dan foto
    // paling jelek justru yang paling mungkin bikin begini.
    final skema = SkemaDinamis.fromJson({
      'dokumen': const {},
      'bagian': [
        {
          'kunci': 'bagian-0',
          'nama': 'Bagian yang gagal dibaca',
          'field': [
            {
              'kunci': 'bagian-0.field-0',
              'label': 'Masih kebaca',
              'tipe': 'text',
              'nilai': 'ada',
              'status': 'OK',
              'sumber': 'handwriting',
              'bisa_diisi': true,
            },
          ],
          'tabel': [
            {'kunci': 'bagian-0.tabel-0', 'kolom': const [], 'baris': const []},
          ],
        },
      ],
      'peringatan': const [],
      'ringkasan': const {},
    });

    await t.pumpWidget(_bungkus(skema, {}, (_, __) {}));

    // `pumpWidget` NGGAK melempar waktu build gagal — errornya ditangkap
    // framework, jadi yang diperiksa `takeException`.
    expect(t.takeException(), isNull);
    // Sisa bagiannya tetap kegambar — satu tabel kosong nggak boleh
    // menjatuhkan yang lain.
    expect(find.text('Bagian yang gagal dibaca'), findsOneWidget);
    expect(find.text('ada'), findsOneWidget);
  });
}
