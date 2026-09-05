import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/skema_dinamis.dart';

void main() {
  Map<String, dynamic> selJson(
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
    'keyakinan': 0.95,
    'tingkat_keyakinan': 'HIGH',
    'status': status,
    'halaman': 1,
  };

  group('sel tabel cacat', () {
    test('diganti di tempatnya, nggak menggeser kolom sesudahnya', () {
      final tabel = TabelDinamis.fromJson({
        'kunci': 'bagian-0.tabel-0',
        'kolom': [
          {'kunci': 'k0', 'judul': 'Reading', 'tipe': 'number'},
          {'kunci': 'k1', 'judul': 'C', 'tipe': 'number'},
          {'kunci': 'k2', 'judul': 'Reading', 'tipe': 'number'},
        ],
        'baris': [
          [
            selJson(0, 0, '84,1'),
            {'bentuknya': 'kacau'}, // sel cacat di kolom 1
            selJson(0, 2, '1413'),
          ],
        ],
      });

      final baris = tabel.baris[0];

      expect(baris.length, 3);
      expect(baris[0].nilai, '84,1');
      expect(baris[1].nilai, isNull, reason: 'sel cacat jadi kosong');
      expect(baris[1].perluDilihat, isTrue);
      expect(
        baris[2].nilai,
        '1413',
        reason: 'kolom 2 TIDAK boleh bergeser ke kolom 1',
      );
      expect(baris[2].kolom, 2);
    });

    test('sel bukan-map juga diganti, bukan dibuang', () {
      final tabel = TabelDinamis.fromJson({
        'kunci': 't',
        'kolom': const [],
        'baris': [
          ['bukan map', selJson(0, 1, '9')],
        ],
      });

      expect(tabel.baris[0].length, 2);
      expect(tabel.baris[0][0].nilai, isNull);
      expect(tabel.baris[0][1].nilai, '9');
    });
  });

  group('nilai apa adanya', () {
    test('koma desimal nggak diubah jadi titik', () {
      final f = FieldDinamis.fromJson({
        'kunci': 'a',
        'label': 'Suhu',
        'tipe': 'number',
        'nilai': '25,4',
        'status': 'OK',
        'sumber': 'handwriting',
        'bisa_diisi': true,
      });

      expect(f.nilai, '25,4');
    });

    test('angka dan bool dari server jadi teks tanpa diformat ulang', () {
      final angka = FieldDinamis.fromJson({
        'kunci': 'a',
        'tipe': 'number',
        'nilai': 7.02,
        'status': 'OK',
        'sumber': 'handwriting',
        'bisa_diisi': true,
      });
      final boolean = FieldDinamis.fromJson({
        'kunci': 'b',
        'tipe': 'boolean',
        'nilai': true,
        'status': 'OK',
        'sumber': 'handwriting',
        'bisa_diisi': true,
      });

      expect(angka.nilai, '7.02');
      expect(boolean.nilai, 'true');
    });
  });

  group('bbox', () {
    test('lengkap kebaca', () {
      final f = FieldDinamis.fromJson({
        'kunci': 'a',
        'tipe': 'text',
        'status': 'OK',
        'sumber': 'handwriting',
        'bisa_diisi': true,
        'bbox': {'x': 10, 'y': 20, 'width': 100, 'height': 30},
      });

      expect(f.bbox!.x, 10);
      expect(f.bbox!.lebar, 100);
    });

    test('separuh jadi null, bukan nol', () {
      final f = FieldDinamis.fromJson({
        'kunci': 'a',
        'tipe': 'text',
        'status': 'OK',
        'sumber': 'handwriting',
        'bisa_diisi': true,
        'bbox': {'x': 10, 'y': 20},
      });

      expect(f.bbox, isNull);
    });
  });

  test('teks tercetak ditandai nggak bisa diisi', () {
    final f = FieldDinamis.fromJson({
      'kunci': 'a',
      'label': 'Standard Name',
      'tipe': 'text',
      'nilai': 'Victor 123',
      'status': 'OK',
      'sumber': 'static_document',
      'bisa_diisi': false,
    });

    expect(f.bisaDiisi, isFalse);
    expect(f.sumber, SumberNilai.statis);
  });

  test('skema utuh kebaca berikut ringkasannya', () {
    final skema = SkemaDinamis.fromJson({
      'dokumen': {
        'title': 'Calibration Worksheet - Conductivity Meter',
        'equipment_name': 'Conductivity Meter',
        'worksheet_code': 'SIDIK-FM-CAL-0510',
        'revision': 'Rev.5',
        'confidence': 0.94,
      },
      'bagian': [
        {
          'kunci': 'bagian-0',
          'nama': 'Before adjustment Reading',
          'field': [
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
          'tabel': [
            {
              'kunci': 'bagian-0.tabel-0',
              'kolom': [
                {'kunci': 'k0', 'judul': 'Reading', 'tipe': 'number'},
              ],
              'baris': [
                [selJson(0, 0, null, status: 'REVIEW_REQUIRED')],
              ],
            },
          ],
        },
      ],
      'peringatan': ['Halaman 2 buram'],
      'ringkasan': {'jumlah_field': 1, 'jumlah_sel': 1, 'perlu_review': 1},
    });

    expect(skema.dokumen.namaAlat, 'Conductivity Meter');
    expect(skema.dokumen.kodeDokumen, 'SIDIK-FM-CAL-0510');
    expect(skema.dokumen.revisi, 'Rev.5');
    expect(skema.bagian.single.nama, 'Before adjustment Reading');
    expect(skema.peringatan, ['Halaman 2 buram']);
    expect(skema.perluReview, 1);
    expect(skema.adaYangPerluDilihat, isTrue);
  });

  test('dua lembar beda struktur menghasilkan skema beda', () {
    Map<String, dynamic> lembar(String nama, List<String> judulKolom) => {
      'dokumen': const {},
      'bagian': [
        {
          'kunci': 'bagian-0',
          'nama': nama,
          'field': const [],
          'tabel': [
            {
              'kunci': 'bagian-0.tabel-0',
              'kolom': [
                for (var i = 0; i < judulKolom.length; i++)
                  {'kunci': 'k$i', 'judul': judulKolom[i], 'tipe': 'text'},
              ],
              'baris': const [],
            },
          ],
        },
      ],
      'peringatan': const [],
      'ringkasan': const {},
    };

    final a = SkemaDinamis.fromJson(lembar('Wavelength', ['X1', 'X2', 'X3']));
    final b = SkemaDinamis.fromJson(lembar('Scale', ['Position', 'Standard']));

    expect(a.bagian[0].tabel[0].kolom.length, 3);
    expect(b.bagian[0].tabel[0].kolom.length, 2);
    expect(a.bagian[0].nama, isNot(b.bagian[0].nama));
  });

  test('respons kosong/cacat nggak bikin meledak', () {
    for (final sampah in [
      <String, dynamic>{},
      {'bagian': 'bukan list'},
      {
        'bagian': [null, 5],
        'ringkasan': 'bukan map',
      },
    ]) {
      final skema = SkemaDinamis.fromJson(Map<String, dynamic>.from(sampah));

      expect(skema.bagian, isEmpty);
      expect(skema.perluReview, 0);
    }
  });
}
