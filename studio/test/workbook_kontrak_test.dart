import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

/// Kontrak `GET /studio/workbook*` (S1b) — JSON contoh PERSIS dari bentuk
/// kontrak di brief orkestrator 13 Okt 2026 (`02-rencana-S1b.md` + tugas
/// pembangun mobile), dikirim server HTTP loopback sungguhan supaya jalur,
/// kueri, unwrap `data`, dan tipe angka hasil `jsonDecode` ikut teruji.
void main() {
  late HttpServer server;
  late List<Uri> masuk;
  late Map<String, Object?> jawaban;
  late ApiWorkbookService layanan;

  setUp(() async {
    HttpOverrides.global = null;
    masuk = [];
    jawaban = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      masuk.add(req.uri);
      final badan = jawaban[req.uri.path.replaceFirst('/api', '')];
      req.response
        ..statusCode = badan == null ? 404 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(badan ?? {'message': 'Tidak ditemukan.'}));
      await req.response.close();
    });
    layanan = ApiWorkbookService(
      ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
    );
  });

  tearDown(() => server.close(force: true));

  group('GET /studio/workbook', () {
    test('daftar: semua kunci kontrak terbaca; kode_profil/keluarga null = '
        'belum dipetakan; kueri kode_profil & cari terkirim', () async {
      jawaban['/studio/workbook'] = {
        'data': [
          {
            'id': 7,
            'nama': 'Master Olah Data Micrometer 0-25mm',
            'kode_profil': 'micrometer',
            'keluarga': 'Dimensi',
            'sumber': 'xlsm',
            'sha256': 'ab' * 32,
            'ukuran': 412160,
            'jumlah_lembar': 8,
            'berkas_asli_tersimpan': false,
            'diimpor_pada': '2026-10-13T09:15:00+07:00',
          },
          {
            'id': 8,
            'nama': 'Master_olda_Height_Gauge_600_mm_2026',
            'kode_profil': null,
            'keluarga': null,
            'sumber': 'csv',
            'sha256': 'cd' * 32,
            'ukuran': 9830,
            'jumlah_lembar': 7,
            'berkas_asli_tersimpan': true,
            'diimpor_pada': '2026-10-13T09:12:00+07:00',
          },
        ],
      };

      final daftar = await layanan.daftar(
        'tkn',
        kodeProfil: 'micrometer',
        cari: ' gauge 0-25 ',
      );

      expect(masuk.single.queryParameters, {
        'kode_profil': 'micrometer',
        'cari': 'gauge 0-25',
      });
      final [a, b] = daftar;
      expect(a.id, 7);
      expect(a.kodeProfil, 'micrometer');
      expect(a.keluarga, 'Dimensi');
      expect(a.sumber, SumberWorkbook.xlsm);
      expect(a.sha256, 'ab' * 32);
      expect(a.ukuran, 412160);
      expect(a.jumlahLembar, 8);
      expect(a.berkasAsliTersimpan, isFalse);
      expect(a.diimporPada, DateTime.utc(2026, 10, 13, 2, 15));
      expect(a.dipetakan, isTrue);
      expect(b.sumber, SumberWorkbook.csv);
      expect(b.kodeProfil, isNull);
      expect(b.dipetakan, isFalse);
      expect(b.berkasAsliTersimpan, isTrue);
    });

    test('tanpa filter: tanpa query string', () async {
      jawaban['/studio/workbook'] = {'data': <Object>[]};
      expect(await layanan.daftar('tkn'), isEmpty);
      expect(masuk.single.hasQuery, isFalse);
    });
  });

  group('GET /studio/workbook/{id}', () {
    test('detail: meta + lembar (tersembunyi, dikecualikan, tata letak '
        'xlsm & csv kosong)', () async {
      jawaban['/studio/workbook/7'] = {
        'data': {
          'id': 7,
          'nama': 'Master Olah Data Micrometer 0-25mm',
          'kode_profil': 'micrometer',
          'keluarga': 'Dimensi',
          'sumber': 'xlsm',
          'sha256': 'ab' * 32,
          'ukuran': 412160,
          'jumlah_lembar': 3,
          'berkas_asli_tersimpan': false,
          'diimpor_pada': '2026-10-13T09:15:00+07:00',
          'lembar': [
            {
              'id': 72,
              'urutan': 2,
              'nama': 'DATABASE',
              'tersembunyi': 'veryHidden',
              'dikecualikan': true,
              'alasan_dikecualikan': 'Data pelanggan',
              'tautan_tabel': 'customers',
              'jumlah_baris': 0,
              'jumlah_kolom': 0,
              'jumlah_sel': 0,
              'jumlah_rumus': 0,
              'tata_letak': {
                'lebar_kolom': <String, Object>{},
                'tinggi_baris': <String, Object>{},
                'merge': <String>[],
                'freeze': null,
                'kolom_tersembunyi': <String>[],
                'baris_tersembunyi': <int>[],
              },
            },
            {
              'id': 71,
              'urutan': 1,
              'nama': 'PERHITUNGAN U95%',
              'tersembunyi': 'tidak',
              'dikecualikan': false,
              'alasan_dikecualikan': null,
              'tautan_tabel': null,
              'jumlah_baris': 21,
              'jumlah_kolom': 38,
              'jumlah_sel': 120,
              'jumlah_rumus': 40,
              'tata_letak': {
                'lebar_kolom': {'A': 12.5, 'AC': 9.140625},
                'tinggi_baris': {'3': 20},
                'merge': ['A1:C1', 'bukan-rentang', 'B2'],
                'freeze': 'B4',
                'kolom_tersembunyi': ['D'],
                'baris_tersembunyi': [7],
              },
            },
            {
              'id': 73,
              'urutan': 3,
              'nama': 'SERTIFIKAT',
              'tersembunyi': 'hidden',
              'dikecualikan': true,
              'alasan_dikecualikan': null,
              'tautan_tabel': 'certificates',
              'jumlah_baris': 0,
              'jumlah_kolom': 0,
              'jumlah_sel': 0,
              'jumlah_rumus': 0,
              // Sumber CSV / server lama: tata letak kosong.
              'tata_letak': <String, Object>{},
            },
          ],
        },
      };

      final d = await layanan.detail('tkn', 7);

      expect(masuk.single.path, '/api/studio/workbook/7');
      expect(d.meta.nama, 'Master Olah Data Micrometer 0-25mm');
      // Urut `urutan`, bukan urutan kiriman.
      expect(d.lembar.map((l) => l.nama), [
        'PERHITUNGAN U95%',
        'DATABASE',
        'SERTIFIKAT',
      ]);

      final [u95, db, sert] = d.lembar;
      expect(u95.tersembunyi, KetersembunyianLembar.tidak);
      expect(u95.dikecualikan, isFalse);
      expect((u95.jumlahBaris, u95.jumlahKolom), (21, 38));
      expect((u95.jumlahSel, u95.jumlahRumus), (120, 40));

      final tl = u95.tataLetak;
      expect(tl.lebarKolom, {1: 12.5, 29: 9.140625});
      expect(tl.tinggiBaris, {3: 20.0});
      // Yang bukan rentang / cuma satu sel dibuang, bukan ditebak.
      expect(tl.merge, [RentangSel(1, 1, 1, 3)]);
      expect(tl.freeze, const AlamatSel(4, 2));
      expect(tl.kolomTersembunyi, {4});
      expect(tl.barisTersembunyi, {7});

      final grid = tl.keGrid();
      expect(grid.lebarKolom, {1: 87.0, 29: 64.0});
      expect(grid.tinggiBaris[3], closeTo(26.667, 0.001));
      expect((grid.barisBeku, grid.kolomBeku), (3, 1));
      expect(grid.lebar(4), 0);
      expect(grid.tinggi(7), 0);

      expect(db.dikecualikan, isTrue);
      expect(db.tersembunyi, KetersembunyianLembar.veryHidden);
      expect(db.tautanTabel, 'customers');
      expect(db.alasanDikecualikan, 'Data pelanggan');
      expect(sert.tersembunyi, KetersembunyianLembar.hidden);
      expect(sert.tautanTabel, 'certificates');
      expect(sert.alasanDikecualikan, isNull);
      expect(sert.tataLetak.merge, isEmpty);
      expect(sert.tataLetak.freeze, isNull);
      expect(sert.tataLetak.keGrid().barisBeku, 0);
    });

    test(
      '404 (lab lain / tidak ada) lewat apa adanya sebagai ApiException',
      () {
        expect(
          layanan.detail('tkn', 999),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
        );
      },
    );
  });

  group('GET /studio/workbook/{id}/lembar/{lembarId}', () {
    test('sel: a/b/k/t/n/s/r/f/g; n PERSIS tanpa pembulatan; gaya ringan; '
        'kueri baris_dari & baris_sampai', () async {
      jawaban['/studio/workbook/7/lembar/71'] = {
        'data': {
          'sel': [
            {
              'a': 'C5',
              'b': 5,
              'k': 3,
              't': 'n',
              'n': 1.4452480055555562e-07,
              's': '0.000000145',
              'r': '=AA6^2/Q6',
              'f': '0.000000000',
              'g': {
                'tebal': true,
                'miring': false,
                'isi': '#FFF2CC',
                'teks': '#C00000',
                'rata': 'center',
                'border': true,
              },
            },
            {
              'a': 'B6',
              'b': 6,
              'k': 2,
              't': 's',
              'n': null,
              's': 'Resolusi',
              'r': null,
              'f': null,
              'g': null,
            },
            {
              'a': 'D6',
              'b': 6,
              'k': 4,
              't': 'n',
              'n': 200,
              's': '200',
              'r': null,
              'f': 'General',
              'g': {
                'border': {'bawah': 'thin', 'atas': null},
              },
            },
            {'a': 'E6', 'b': 6, 'k': 5, 't': 'b', 'n': null, 's': 'TRUE'},
            {'a': 'F6', 'b': 6, 'k': 6, 't': 'e', 'n': null, 's': '#DIV/0!'},
            {'a': 'G6', 'b': 6, 'k': 7, 't': 'kosong', 'n': null, 's': ''},
            // Tanpa b/k: alamat dari `a`.
            {'a': 'H6', 't': 'f', 'n': 0.0085, 's': '0.0085', 'r': '=X7^2'},
            // Cacat: tanpa alamat sama sekali — DIHITUNG, bukan dibuang diam.
            {'t': 'n', 'n': 1, 's': '1'},
            'bukan peta',
          ],
          'baris_dari': 1,
          'baris_sampai': 200,
          'jumlah_baris': 21,
        },
      };

      final h = await layanan.sel(
        'tkn',
        workbookId: 7,
        lembarId: 71,
        barisDari: 1,
        barisSampai: 200,
      );

      expect(masuk.single.path, '/api/studio/workbook/7/lembar/71');
      expect(masuk.single.queryParameters, {
        'baris_dari': '1',
        'baris_sampai': '200',
      });
      expect((h.barisDari, h.barisSampai, h.jumlahBaris), (1, 200, 21));
      expect(h.sel, hasLength(7));
      expect(h.jumlahCacat, 2);

      final c5 = h.pada(5, 3)!;
      expect(c5.alamat.a1, 'C5');
      expect(c5.tipe, TipeSel.angka);
      // Nilai PERSIS: double yang sama bit demi bit, teks tampil terpisah.
      expect(c5.nilai, 1.4452480055555562e-07);
      expect(c5.nilai.toString(), '1.4452480055555562e-7');
      expect(c5.teks, '0.000000145');
      expect(c5.rumus, '=AA6^2/Q6');
      expect(c5.formatAngka, '0.000000000');
      expect(c5.gaya!.tebal, isTrue);
      expect(c5.gaya!.isi, const Color(0xFFFFF2CC));
      expect(c5.gaya!.teks, const Color(0xFFC00000));
      expect(c5.gaya!.garis.ada, isTrue);

      final g = c5.keGrid();
      expect(g.jenis, JenisSelGrid.angka);
      expect(g.rata, TextAlign.center);
      expect(g.rumus, '=AA6^2/Q6');

      expect(h.pada(6, 2)!.tipe, TipeSel.teks);
      expect(h.pada(6, 2)!.gaya, isNull);
      final d6 = h.pada(6, 4)!;
      expect(d6.nilai, 200);
      expect(d6.nilai, isA<int>());
      expect(d6.gaya!.garis.bawah, isTrue);
      expect(d6.gaya!.garis.atas, isFalse);
      expect(h.pada(6, 5)!.keGrid().jenis, JenisSelGrid.logika);
      expect(h.pada(6, 6)!.keGrid().jenis, JenisSelGrid.galat);
      expect(h.pada(6, 7)!.keGrid().jenis, JenisSelGrid.kosong);
      // Sel berumus (t = f) dengan hasil angka: rata seperti angka.
      final h6 = h.pada(6, 8)!;
      expect(h6.tipe, TipeSel.rumus);
      expect(h6.keGrid().jenis, JenisSelGrid.angka);
      // Sel yang tidak dikirim = kosong.
      expect(h.pada(1, 1), isNull);
    });
  });

  group('FORMAT 3 (Tahap A) — dibaca bila ada, bawaan Excel bila tidak', () {
    test('tata_letak: lebar_kolom_bawaan (karakter), tinggi_baris_bawaan '
        '(pt), garis_kisi, lebar_perkiraan', () {
      final tl = TataLetakLembar.fromJson({
        'lebar_kolom': {'B': 20.0},
        'tinggi_baris': <String, Object>{},
        'merge': <String>[],
        'lebar_kolom_bawaan': 10.7109375,
        'tinggi_baris_bawaan': 12.75,
        'garis_kisi': false,
        'lebar_perkiraan': true,
      });
      expect(tl.lebarKolomBawaan, 10.7109375);
      expect(tl.tinggiBarisBawaan, 12.75);
      expect(tl.garisKisi, isFalse);
      expect(tl.lebarPerkiraan, isTrue);
      final g = tl.keGrid();
      // floor(7·10,7109375 + 0,4921875) = 75; 12,75 pt = 17 dp.
      expect(g.lebar(1), 75);
      expect(g.lebar(2), lebarKolomExcelKeDp(20));
      expect(g.tinggi(1), 17);
      expect(g.garisKisi, isFalse);

      // Server lama / CSV: kunci tidak ada → bawaan Excel.
      final lama = TataLetakLembar.fromJson({
        'lebar_kolom': <String, Object>{},
      });
      expect(lama.garisKisi, isTrue);
      expect(lama.lebarPerkiraan, isFalse);
      expect(lama.keGrid().lebar(1), 64);
      expect(lama.keGrid().tinggi(1), 20);
      // Nilai aneh tidak mematikan kisi; 0/negatif = bawaan.
      final aneh = TataLetakLembar.fromJson({
        'garis_kisi': 'ya',
        'lebar_kolom_bawaan': 0,
        'tinggi_baris_bawaan': -1,
      });
      expect(aneh.garisKisi, isTrue);
      expect(aneh.lebarKolomBawaan, isNull);
      expect(aneh.tinggiBarisBawaan, isNull);
    });

    test('g: bungkus, vertikal, ukuran, font, gaya garis per sisi → '
        'SelGrid', () {
      final s = SelWorkbook.fromJson({
        'a': 'B4',
        't': 's',
        's': 'Nominal Gauge Block (mm)',
        'g': {
          'tebal': true,
          'bungkus': true,
          'vertikal': 'center',
          'ukuran': 14,
          'font': 'Consolas',
          'border': {
            'atas': 'thin',
            'kanan': 'medium',
            'bawah': 'double',
            'kiri': 'dashed',
          },
        },
      });
      final g = s.gaya!;
      expect(g.bungkus, isTrue);
      expect(g.vertikal, RataVertikal.tengah);
      expect(g.vertikalMentah, 'center');
      expect(g.ukuran, 14);
      expect(g.font, 'Consolas');
      expect(g.garis.jenisAtas, JenisGaris.tipis);
      expect(g.garis.jenisKanan, JenisGaris.sedang);
      expect(g.garis.jenisBawah, JenisGaris.ganda);
      expect(g.garis.jenisKiri, JenisGaris.putus);
      expect(g.kosong, isFalse);

      final grid = s.keGrid();
      expect(grid.bungkus, isTrue);
      expect(grid.vertikal, RataVertikal.tengah);
      expect(grid.ukuran, 14);
      expect(grid.font, 'Consolas');
      expect(fontMonospace(grid.font), isTrue);
      expect(grid.garis.jenisKanan, JenisGaris.sedang);

      expect(rataVertikalExcel('top'), RataVertikal.atas);
      expect(rataVertikalExcel('bottom'), RataVertikal.bawah);
      expect(rataVertikalExcel('distributed'), RataVertikal.atas);
      expect(rataVertikalExcel('aneh'), isNull);
    });

    test('t:"kosong" bergaya → sel tanpa isi yang tetap bergaris & berisi '
        'warna; tidak menghalangi luberan', () {
      final s = SelWorkbook.fromJson({
        'a': 'C9',
        't': 'kosong',
        's': '',
        'g': {
          'isi': '#FFF2CC',
          'border': {'bawah': 'thin'},
        },
      });
      final g = s.keGrid();
      expect(g.jenis, JenisSelGrid.kosong);
      expect(g.isi, const Color(0xFFFFF2CC));
      expect(g.garis.bawah, isTrue);
      expect(g.tanpaIsi, isTrue);
    });

    test(
      'halaman: selGrid dibuat sekali per sel; sel tak dikirim = kosong',
      () {
        final h = HalamanSelWorkbook.fromJson({
          'sel': [
            {'a': 'A1', 't': 's', 's': 'x'},
          ],
          'baris_dari': 1,
          'baris_sampai': 200,
          'jumlah_baris': 3,
        });
        expect(identical(h.selGrid(1, 1), h.selGrid(1, 1)), isTrue);
        expect(h.selGrid(1, 1).teks, 'x');
        expect(identical(h.selGrid(2, 2), SelGrid.kosong), isTrue);
      },
    );
  });

  group('mock = bentuk kontrak', () {
    test('MockWorkbookService: DATABASE BERISI (K-49-12) bertautan tabel, '
        'SERTIFIKAT dikecualikan (impor lama), lembar tersembunyi, kembaran '
        'CSV, CSV tanpa tata letak, halaman kedua kosong', () async {
      final mock = MockWorkbookService();
      final daftar = await mock.daftar('t');
      // K-49-13: daftar = master AKTIF saja; kembaran CSV Micrometer jadi
      // riwayat `.xlsm`-nya (dibuka lewat `…/riwayat`).
      expect(daftar.map((w) => w.sumber), [
        SumberWorkbook.xlsm,
        SumberWorkbook.csv,
      ]);
      expect(await mock.daftar('t', cari: 'height'), hasLength(1));
      expect(await mock.daftar('t', kodeProfil: 'micrometer'), hasLength(1));
      // Server sebelum K-49-13: semua workbook, kembaran CSV ikut.
      final lama = MockWorkbookService(serverLama: true);
      expect((await lama.daftar('t')).map((w) => w.sumber), [
        SumberWorkbook.xlsm,
        SumberWorkbook.csv,
        SumberWorkbook.csv,
      ]);
      expect(await lama.daftar('t', kodeProfil: 'micrometer'), hasLength(2));

      final d = await mock.detail('t', MockWorkbookService.idMicrometer);
      expect(d.lembar.map((l) => l.nama), [
        'PERHITUNGAN U95%',
        'Standar_GB',
        'DATABASE',
        'SERTIFIKAT',
      ]);
      expect(d.lembar[1].tersembunyi, KetersembunyianLembar.hidden);
      expect(d.lembar[1].tataLetak.garisKisi, isFalse);
      final database = d.lembar[2];
      expect(database.dikecualikan, isFalse);
      expect(database.tautanTabel, 'customers');
      final isiDatabase = await mock.sel(
        't',
        workbookId: MockWorkbookService.idMicrometer,
        lembarId: MockWorkbookService.idLembarDatabase,
        barisDari: 1,
        barisSampai: 200,
      );
      expect(isiDatabase.pada(1, 1)!.teks, ' COMMON DATA ');
      final sertifikat = d.lembar[3];
      expect(sertifikat.dikecualikan, isTrue);
      expect(sertifikat.tautanTabel, 'certificates');
      final isiSertifikat = await mock.sel(
        't',
        workbookId: MockWorkbookService.idMicrometer,
        lembarId: MockWorkbookService.idLembarSertifikat,
        barisDari: 1,
        barisSampai: 200,
      );
      expect(isiSertifikat.sel, isEmpty);

      // Anggota gabungan = kosong BERGAYA (garis tepi gabungan utuh).
      final u95Awal = await mock.sel(
        't',
        workbookId: MockWorkbookService.idMicrometer,
        lembarId: MockWorkbookService.idLembarU95,
        barisDari: 1,
        barisSampai: 200,
      );
      final h6 = u95Awal.pada(6, 8)!;
      expect(h6.tipe, TipeSel.kosong);
      expect(h6.gaya!.garis.kanan, isTrue);

      final csv = await mock.detail('t', MockWorkbookService.idMicrometerCsv);
      expect(csv.lembar.single.tataLetak.lebarPerkiraan, isTrue);

      // Nilai dari CSV master (`PERHITUNGAN U95%.csv` baris 6).
      final u95 = await mock.sel(
        't',
        workbookId: MockWorkbookService.idMicrometer,
        lembarId: MockWorkbookService.idLembarU95,
        barisDari: 1,
        barisSampai: 200,
      );
      expect(u95.pada(6, 20)!.nilai, 0.07332348418708248); // T6
      expect(u95.pada(6, 20)!.rumus, '=K6/N6');
      expect(u95.pada(6, 29)!.nilai, 1.4452480055555562e-07); // AC6

      final hg = await mock.detail('t', MockWorkbookService.idHeightGauge);
      expect(hg.meta.dipetakan, isFalse);
      expect(hg.lembar.single.tataLetak.lebarKolom, isEmpty);
      final halaman2 = await mock.sel(
        't',
        workbookId: MockWorkbookService.idHeightGauge,
        lembarId: MockWorkbookService.idLembarInput,
        barisDari: 201,
        barisSampai: 400,
      );
      expect(halaman2.sel, isEmpty);
      expect(halaman2.jumlahBaris, 300);

      expect(
        mock.detail('t', 999),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('MockWorkbookService(gagal: true) melempar', () {
      expect(MockWorkbookService(gagal: true).daftar('t'), throwsException);
    });
  });
}
