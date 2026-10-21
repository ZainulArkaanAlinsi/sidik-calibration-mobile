import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/simulasi_model.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

/// Kontrak Tahap C (rencana `02-rencana-C-anak-timbangan.md`, repo API):
/// kunci lembar baru (`tersembunyi` bool, `gambar[]`) dengan bawaan aman
/// untuk server lama, jawaban `POST /hitung`, dan galatnya. Bentuk JSON
/// disalin dari kontrak; angka di sini SINTETIS (bukan hasil hitung).
void main() {
  Map<String, dynamic> lembar([Map<String, dynamic> tambahan = const {}]) => {
    'id': 7,
    'urutan': 1,
    'nama': 'PERHITUNGAN FC',
    'jumlah_baris': 40,
    'jumlah_kolom': 30,
    ...tambahan,
  };

  group('lembar: tersembunyi', () {
    test('bool kontrak C: true = tersembunyi, false = tampil', () {
      expect(
        LembarWorkbook.fromJson(lembar({'tersembunyi': true})).tersembunyi,
        KetersembunyianLembar.hidden,
      );
      expect(
        LembarWorkbook.fromJson(
          lembar({'tersembunyi': false}),
        ).tersembunyi.disembunyikan,
        isFalse,
      );
    });

    test('server lama: teks hidden/veryHidden/tidak tetap terbaca; kunci '
        'tidak ada = tampil (lembar tidak hilang diam-diam)', () {
      KetersembunyianLembar dari(Object? v) =>
          LembarWorkbook.fromJson(lembar({'tersembunyi': v})).tersembunyi;
      expect(dari('hidden'), KetersembunyianLembar.hidden);
      expect(dari('veryHidden'), KetersembunyianLembar.veryHidden);
      expect(dari('tidak'), KetersembunyianLembar.tidak);
      expect(
        LembarWorkbook.fromJson(lembar()).tersembunyi,
        KetersembunyianLembar.tidak,
      );
    });
  });

  group('lembar: gambar', () {
    test('kontrak: jangkar kolom huruf + baris + dx/dy, ukuran px, jenis', () {
      final l = LembarWorkbook.fromJson(
        lembar({
          'gambar': [
            {
              'id': 'img-3',
              'dari': {'kolom': 'B', 'baris': 5, 'dx': 4, 'dy': 2.5},
              'lebar': 120,
              'tinggi': 80,
              'jenis': 'png',
            },
            {
              'id': 9,
              'dari': {'kolom': 3, 'baris': 1},
              'lebar': 10,
              'tinggi': 10,
              'jenis': 'jpg',
            },
            {
              'id': 'emf-1',
              'dari': {'kolom': 'AA', 'baris': 2},
              'lebar': 50,
              'tinggi': 20,
              'jenis': 'emf',
            },
          ],
        }),
      );
      expect(l.gambar, hasLength(3));
      final g = l.gambar.first;
      expect(
        (g.id, g.kolom, g.baris, g.dx, g.dy, g.lebar, g.tinggi, g.jenis),
        ('img-3', 2, 5, 4.0, 2.5, 120.0, 80.0, JenisGambar.png),
      );
      expect(l.gambar[1].id, '9');
      expect(l.gambar[1].jenis, JenisGambar.jpeg);
      expect(l.gambar[2].kolom, 27);
      expect(l.gambar[2].jenis.bisaDigambar, isFalse);
      expect(l.gambar[2].jenisMentah, 'emf');
    });

    test('server lama tanpa kunci gambar = kosong; entri yang tidak bisa '
        'diletakkan dibuang, bukan ditebak', () {
      expect(LembarWorkbook.fromJson(lembar()).gambar, isEmpty);
      final l = LembarWorkbook.fromJson(
        lembar({
          'gambar': [
            {'id': 'a', 'lebar': 10, 'tinggi': 10, 'jenis': 'png'},
            {
              'id': 'b',
              'dari': {'kolom': 'B', 'baris': 0},
              'lebar': 10,
              'tinggi': 10,
            },
            {
              'id': 'c',
              'dari': {'kolom': 'B', 'baris': 2},
              'lebar': 0,
              'tinggi': 10,
            },
            'bukan peta',
          ],
        }),
      );
      expect(l.gambar, isEmpty);
    });
  });

  group('/hitung', () {
    test('kiriman: lembar_id + alamat A1 + isi apa adanya', () {
      expect(
        editSelKeJson((lembarId: 7, alamat: AlamatSel(5, 5), isi: '=F2*2')),
        {'lembar_id': 7, 'a': 'E5', 'isi': '=F2*2'},
      );
    });

    test('jawaban: sel per lembar (format sel GET), galat per sel, sel '
        'cacat dihitung', () {
      final h = HasilHitung.fromJson({
        'lembar': [
          {
            'lembar_id': 7,
            'sel': [
              {
                'a': 'E5',
                'b': 5,
                'k': 5,
                't': 'n',
                'n': 0.5,
                's': '0.50',
                'r': null,
                'f': '0.00',
                'g': {'tebal': true},
              },
              {'a': 'AA34', 't': 'e', 's': '#VALUE!', 'r': '=IF(A1,B1)'},
              {'t': 'n', 'n': 1},
            ],
          },
        ],
        'jumlah_dihitung': 2683,
        'durasi_ms': 11800,
        'galat': [
          {'lembar_id': 7, 'a': 'AA34', 'pesan': 'internal error'},
        ],
      });
      expect(h.sel[7], hasLength(2));
      expect(h.sel[7]!.first.teks, '0.50');
      expect(h.sel[7]!.first.gaya!.tebal, isTrue);
      expect(h.sel[7]![1].tipe, TipeSel.galat);
      expect(h.jumlahCacat, 1);
      expect(h.jumlahDihitung, 2683);
      expect(h.durasiMs, 11800);
      expect(h.galat.single, (lembarId: 7, a: 'AA34', pesan: 'internal error'));
    });

    test('galat: 409 berkas asli, 422 ditolak (pesan validasi pertama), '
        '504 terlalu lama, 429 jatah habis, 403; yang bisa diulang', () {
      GalatSimulasi g(int status, Map<String, dynamic> body) =>
          GalatSimulasi.dari(ApiException('m', status: status, body: body));
      expect(
        g(409, {'kode': 'berkas_asli_tidak_ada'}).jenis,
        JenisGalatSimulasi.berkasAsliTidakAda,
      );
      final ditolak = g(422, {
        'message': 'Data tidak valid.',
        'errors': {
          'edit.0.isi': ['Fungsi INDIRECT tidak diizinkan.'],
        },
      });
      expect(ditolak.jenis, JenisGalatSimulasi.ditolak);
      expect(ditolak.pesan, 'Fungsi INDIRECT tidak diizinkan.');
      expect(ditolak.bisaDiulang, isFalse);
      expect(g(504, {}).jenis, JenisGalatSimulasi.terlaluLama);
      expect(g(504, {}).bisaDiulang, isTrue);
      expect(g(429, {}).jenis, JenisGalatSimulasi.terlaluSering);
      expect(g(403, {}).jenis, JenisGalatSimulasi.dilarang);
      expect(g(429, {}).bisaDiulang, isTrue);
      expect(
        g(422, {
          'kode': 'edit_tidak_valid',
          'message': 'Edit tidak valid.',
        }).jenis,
        JenisGalatSimulasi.ditolak,
      );
      expect(
        GalatSimulasi.dari(const AuthException('Server nggak nyaut.')).pesan,
        'Server nggak nyaut.',
      );
    });

    test('409: `kode` yang menentukan — perlu_sandi BUKAN "tidak punya '
        'berkas asli"; 409 tanpa kode dikenal = lain (pesan server)', () {
      GalatSimulasi g(int status, Map<String, dynamic> body) =>
          GalatSimulasi.dari(ApiException('m', status: status, body: body));
      // Bentuk persis jawaban `HitungWorkbookController` (GagalHitung).
      final sandi = g(409, {
        'message':
            'Model hitung workbook bersandi belum disiapkan. Admin '
            'menjalankan: php artisan studio:siapkan-hitung <id workbook> '
            '(sandi diminta).',
        'kode': 'perlu_sandi',
      });
      expect(sandi.jenis, JenisGalatSimulasi.perluSandi);
      expect(sandi.bisaDiulang, isFalse);
      expect(sandi.status, 409);
      expect(g(409, {'kode': 'berkas_asli_tidak_ada'}).bisaDiulang, isFalse);
      final asing = g(409, {'message': 'Konflik lain.'});
      expect(asing.jenis, JenisGalatSimulasi.lain);
      expect(asing.pesan, 'Konflik lain.');
    });
  });

  group('CSV: angka mentah tulisan skrip → General dari n', () {
    // Contoh `s` dari temuan E2E (CSV diekspor skrip, bukan Excel).
    test('mentah: > 15 digit signifikan, e kecil, pangkat bukan E+NN', () {
      expect(teksAngkaMentah('0.010015000000000001'), isTrue);
      expect(teksAngkaMentah('1.5000000000001124e-05'), isTrue);
      expect(teksAngkaMentah('1.7320508075688772'), isTrue);
      expect(teksAngkaMentah('-0.07332348418708248'), isTrue);
      expect(teksAngkaMentah('1.5E-5'), isTrue);
    });

    test('sudah bentuk Excel / bukan angka → dibiarkan', () {
      for (final s in [
        '0.127',
        '1.5E-05',
        '1.23457E+11',
        '730',
        '-0.5',
        '123456789012345',
        '1,5',
        '5%',
        'Resolusi',
        '',
      ]) {
        expect(teksAngkaMentah(s), isFalse, reason: s);
      }
    });

    SelGrid selCsv(Object n, String s, {String? f}) => SelWorkbook.fromJson({
      'a': 'T6',
      't': 'n',
      'n': n,
      's': s,
      'f': f,
    }).keGrid();

    test('sel CSV t=n, f null: s mentah → general; s Excel → tidak; format '
        'eksplisit → tidak', () {
      expect(
        selCsv(0.010015000000000001, '0.010015000000000001').general,
        isTrue,
      );
      expect(
        selCsv(1.5000000000001124e-05, '1.5000000000001124e-05').general,
        isTrue,
      );
      expect(selCsv(0.127, '0.127').general, isFalse);
      expect(selCsv(1.5e-05, '1.5E-05').general, isFalse);
      expect(
        selCsv(
          0.010015000000000001,
          '0.010015000000000001',
          f: '0.000',
        ).general,
        isFalse,
      );
    });
  });
}
