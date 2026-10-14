import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/realtime_provider.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/data_acuan_contoh_micrometer.dart';
import 'package:sidik_calibration/services/data_acuan_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/realtime_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Lapisan data Studio Data Acuan (CR-48 M1) melawan kontrak API §15.
///
/// Yang dijaga — semuanya TIDAK menghasilkan error waktu salah:
///  1. **Kunci yang tidak dikirim ke teknisi dibaca `null`, bukan nol.** Layar
///     yang membaca "tidak dikirim" sebagai `0` menulis "0 draf" ke orang yang
///     memang tidak boleh tahu jumlahnya.
///  2. **Tipe angka tidak hilang.** Server meng-encode dengan
///     `JSON_PRESERVE_ZERO_FRACTION`; `20.0` harus tetap `double`, `200` tetap
///     `int` — isi kanonik membedakan keduanya.
///  3. **Selisih banding presisi penuh** (`0.0019999999999988916`, bukan
///     `0.002`).
///  4. **Mock membaca sel persis seperti server** — ekspektasi riwayat sel di
///     sini disalin dari `DataAcuanBacaTest` repo API.
void main() {
  Map<String, dynamic> dekode(String teks) =>
      jsonDecode(teks) as Map<String, dynamic>;

  group('parsing kontrak §15', () {
    test('daftar paket (admin): versi_aktif ringkas + hitungan', () {
      final json = dekode('''
{"data":[{"kode":"micrometer","nama":"Micrometer","skema_versi":1,"diimpor":true,
 "versi_aktif":{"id":12,"nomor":1,"status":"aktif","berlaku_mulai":"2024-01-01",
   "berlaku_sampai":null,"sha256":"ba1fa153f585"},
 "versi_terjadwal":[{"id":15,"nomor":3,"status":"terjadwal","berlaku_mulai":"2099-01-01",
   "berlaku_sampai":null,"sha256":"abc"}],
 "jumlah_draf":1}]}''');

      final paket = PaketAcuan.fromJson(
        (json['data'] as List).first as Map<String, dynamic>,
      );

      expect(paket.kode, 'micrometer');
      expect(paket.diimpor, isTrue);
      expect(paket.versiAktif?.id, 12);
      expect(paket.versiAktif?.status, StatusVersiAcuan.aktif);
      expect(paket.versiAktif?.berlakuMulai, DateTime(2024));
      expect(paket.versiAktif?.berlakuSampai, isNull);
      expect(paket.versiAktif?.sha256, 'ba1fa153f585');
      expect(paket.versiTerjadwal?.single.status, StatusVersiAcuan.terjadwal);
      expect(paket.jumlahDraf, 1);
      expect(paket.jumlahDiajukan, isNull, reason: 'cuma di detail');
      expect(paket.skema, isNull, reason: 'cuma di detail');
    });

    test(
      'daftar paket (teknisi): kunci tidak dikirim → null, BUKAN nol/kosong',
      () {
        final paket = PaketAcuan.fromJson(
          dekode('''
{"kode":"micrometer","nama":"Micrometer","skema_versi":1,"diimpor":true,
 "versi_aktif":{"id":12,"nomor":1,"status":"aktif","berlaku_mulai":"2024-01-01",
   "berlaku_sampai":null,"sha256":"ba1f"}}'''),
        );

        expect(paket.versiAktif?.nomor, 1);
        expect(paket.versiTerjadwal, isNull);
        expect(paket.jumlahDraf, isNull);
        expect(paket.jumlahDiajukan, isNull);
      },
    );

    test('profil belum diimpor: diimpor false, versi_aktif null', () {
      final paket = PaketAcuan.fromJson(
        dekode('''
{"kode":"micrometer","nama":"Micrometer","skema_versi":1,"diimpor":false,
 "versi_aktif":null,"versi_terjadwal":[],"jumlah_draf":0}'''),
      );

      expect(paket.diimpor, isFalse);
      expect(paket.versiAktif, isNull);
      expect(paket.versiTerjadwal, isEmpty);
      expect(paket.jumlahDraf, 0);
    });

    test('skema Micrometer: 8 lembar, atribut kolom, jenis & kunci', () {
      final skema = SkemaAcuan.fromJson(dekode(contohSkemaMicrometer));

      expect(skema.skemaVersi, 1);
      expect(skema.sumberJson, 'tabel-standar-micrometer.json');
      // Urutan yang sama dengan `DataAcuanBacaTest::test_detail_paket`.
      expect(skema.lembar.map((l) => l.kode), [
        'standar',
        'balok_ukur',
        'ketidakpastian_balok_tangga',
        'ketidakpastian_balok_khusus',
        'ketidakpastian_balok_lainnya',
        'pita_cmc',
        'titik_pra_cetak',
        'konstanta',
      ]);

      final balok = skema.lembar[1];
      expect(balok.jenis, JenisLembarAcuan.baris);
      expect(balok.kunci, 'nominal_mm');
      expect(balok.bolehTambahBaris, isTrue);
      final terkoreksi = balok.kolom.last;
      expect(terkoreksi.kode, 'nilai_terkoreksi_mm');
      expect(terkoreksi.tipe, 'desimal');
      expect(terkoreksi.satuan, 'mm');
      expect(terkoreksi.asal, 'Standar_GB!R10:R132');
      expect(terkoreksi.perluKonfirmasi, isFalse);

      expect(skema.lembar.first.jenis, JenisLembarAcuan.objek);
      expect(skema.lembar.first.kunci, isNull);
      expect(skema.lembar[2].jenis, JenisLembarAcuan.daftar);
      expect(skema.lembar[6].jalur, 'cmc/*/titik');

      final konstanta = skema.lembar.last.kolom;
      expect(
        konstanta
            .firstWhere((k) => k.kode == 'delta_alpha_per_c')
            .perluKonfirmasi,
        isTrue,
      );
      expect(konstanta.firstWhere((k) => k.kode == 'vi_type_b').tipe, 'bulat');
      expect(
        konstanta.firstWhere((k) => k.kode == 'wringing_um').asal,
        isNull,
        reason: 'angka telanjang di rumus master — tidak punya sel',
      );
    });

    test('berlaku tanpa versi: data null + alasan, bukan galat', () {
      final hasil = HasilBerlakuAcuan.fromJson(
        dekode(
          '{"data":null,"alasan":"Tanggal 2023-12-31 sebelum versi data '
          'pertama berlaku (2024-01-01)."}',
        ),
      );

      expect(hasil.versi, isNull);
      expect(hasil.alasan, contains('2024-01-01'));
    });

    test(
      'versi + isi: 20.0 tetap double, 200 tetap int, kunci objek berangka utuh',
      () {
        final versi = VersiAcuan.fromJson(
          (dekode(
                '''
{"data":{"id":12,"paket":"micrometer","jenis":"data","nomor":1,"status":"aktif",
 "skema_versi":1,"dasar_versi_id":null,"berlaku_mulai":"2024-01-01","berlaku_sampai":null,
 "isi_sha256":"ba1f","alasan":"Impor awal dari database/data/tabel-standar-micrometer.json",
 "rujukan":[{"jenis":"berkas_repo","nilai":"database/data/tabel-standar-micrometer.json","catatan":"ba1f"}],
 "catatan_keputusan":null,"dibuat_oleh":null,"diajukan_oleh":null,"diajukan_pada":null,
 "disahkan_oleh":null,"disahkan_pada":null,"ditolak_oleh":null,"ditolak_pada":null,
 "lock_versi":0,"created_at":"2026-10-08T10:00:00+07:00","updated_at":"2026-10-08T10:00:00+07:00",
 "isi":{"konstanta":{"suhu_acuan_c":20.0,"vi_type_b":200,"delta_alpha_per_c":1.0e-5},
        "ketidakpastian_balok_um":{"persis":{"101.6":0.26,"200":0.73},"lainnya":0.0}}}}''',
              )['data'])
              as Map<String, dynamic>,
        );

        expect(versi.paket, 'micrometer');
        expect(versi.status, StatusVersiAcuan.aktif);
        expect(versi.isiSha256, 'ba1f');
        expect(versi.rujukan.single.jenis, 'berkas_repo');
        expect(versi.disahkanOleh, isNull, reason: 'impor bukan pengesahan');
        expect(versi.lockVersi, 0);
        expect(versi.dibuatPada, isNotNull);

        final isi = versi.isi! as Map<String, dynamic>;
        final konstanta = isi['konstanta'] as Map<String, dynamic>;
        expect(konstanta['suhu_acuan_c'], isA<double>());
        expect(konstanta['suhu_acuan_c'], 20.0);
        expect(konstanta['vi_type_b'], isA<int>());
        expect(konstanta['vi_type_b'], 200);
        expect(konstanta['delta_alpha_per_c'], 1e-5);
        final lain = isi['ketidakpastian_balok_um'] as Map<String, dynamic>;
        expect(lain['lainnya'], isA<double>(), reason: '0.0 bukan 0');
        expect((lain['persis'] as Map)['200'], 0.73);
      },
    );

    test('banding: selisih presisi penuh, baris tambah/hapus, ringkasan', () {
      final banding = BandingAcuan.fromJson(
        (dekode(
              '''
{"data":{"paket":"micrometer","skema_versi":1,
 "lama":{"id":12,"nomor":1,"status":"aktif","berlaku_mulai":"2024-01-01","berlaku_sampai":null,"sha256":"a"},
 "baru":{"id":15,"nomor":2,"status":"draf","berlaku_mulai":null,"berlaku_sampai":null,"sha256":null},
 "lembar":[
  {"kode":"balok_ukur","label":"Balok ukur — nilai terkoreksi",
   "sel_berubah":[{"lembar":"balok_ukur","kunci":"19.0","kolom":"nilai_terkoreksi_mm",
     "lama":19.00011,"baru":19.00211,
     "selisih_absolut":0.0019999999999988916,"selisih_relatif":0.00010526254847992415}],
   "baris_tambah":[{"kunci":"3.0","sel":{"nominal_mm":"3.0","nilai_terkoreksi_mm":3.00007}}],
   "baris_hapus":[]},
  {"kode":"standar","label":"Identitas standar balok ukur",
   "sel_berubah":[{"lembar":"standar","kunci":"0","kolom":"seri","lama":"160006","baru":"160007"}],
   "baris_tambah":[],"baris_hapus":[]},
  {"kode":"konstanta","label":"Konstanta metode","sel_berubah":[],"baris_tambah":[],"baris_hapus":[]}],
 "ringkasan":{"lembar_berubah":2,"sel_berubah":2,"baris_tambah":1,"baris_hapus":0}}}''',
            )['data'])
            as Map<String, dynamic>,
      );

      expect(banding.paket, 'micrometer');
      expect(banding.lama?.nomor, 1);
      expect(banding.baru?.status, StatusVersiAcuan.draf);
      expect(banding.baru?.sha256, isNull);
      expect(banding.lembar, hasLength(3));
      expect(banding.lembar.last.berubah, isFalse);

      final sel = banding.lembar.first.selBerubah.single;
      expect(sel.kunci, '19.0');
      expect(sel.lama, 19.00011);
      expect(sel.baru, 19.00211);
      expect(sel.punyaSelisih, isTrue);
      // Bit-identik dengan yang dikirim server — tidak dibulatkan.
      expect(sel.selisihAbsolut, 0.0019999999999988916);
      expect(sel.selisihAbsolut, isNot(0.002));
      expect(sel.selisihRelatif, 0.00010526254847992415);

      final tambah = banding.lembar.first.barisTambah.single;
      expect(tambah.kunci, '3.0');
      expect(tambah.sel['nominal_mm'], '3.0');
      expect(tambah.sel['nilai_terkoreksi_mm'], 3.00007);

      final teks = banding.lembar[1].selBerubah.single;
      expect(teks.punyaSelisih, isFalse, reason: 'selisih cuma untuk angka');
      expect(teks.selisihAbsolut, isNull);

      expect(banding.ringkasan.lembarBerubah, 2);
      expect(banding.ringkasan.barisTambah, 1);
    });

    test('riwayat sel: kolom skema, nilai per versi, suntingan + pelaku', () {
      final riwayat = RiwayatSelAcuan.fromJson(
        (dekode(
              '''
{"data":{"paket":"micrometer","versi":{"id":15,"nomor":2,"status":"draf","berlaku_mulai":null,"berlaku_sampai":null,"sha256":null},
 "lembar":"balok_ukur","kunci":"19.0",
 "kolom":{"kode":"nilai_terkoreksi_mm","label":"Nilai terkoreksi","tipe":"desimal","satuan":"mm","asal":"Standar_GB!R10:R132","perlu_konfirmasi":false},
 "ada":true,"nilai":19.00211,
 "riwayat":[{"versi":{"id":12,"nomor":1,"status":"aktif","berlaku_mulai":"2024-01-01","berlaku_sampai":null,"sha256":"a"},"ada":true,"nilai":19.00011},
            {"versi":{"id":15,"nomor":2,"status":"draf","berlaku_mulai":null,"berlaku_sampai":null,"sha256":null},"ada":true,"nilai":19.00211}],
 "suntingan":[{"id":7,"paket_acuan_versi_id":15,"nomor_versi":2,"nilai_lama":"19.00011","nilai_baru":"19.00211",
   "sumber":"ketik","alasan":"Uji riwayat sel","user":{"id":3,"nama":"Admin Lab"},"created_at":"2026-10-08T10:00:00+07:00"}]}}''',
            )['data'])
            as Map<String, dynamic>,
      );

      expect(riwayat.ada, isTrue);
      expect(riwayat.nilai, 19.00211);
      expect(riwayat.kolom?.asal, 'Standar_GB!R10:R132');
      expect(riwayat.riwayat.map((r) => r.versi?.nomor), [1, 2]);
      expect(riwayat.riwayat.map((r) => r.nilai), [19.00011, 19.00211]);

      final s = riwayat.suntingan.single;
      expect(s.nomorVersi, 2);
      expect(s.nilaiLama, '19.00011', reason: 'apa adanya — teks dari server');
      expect(s.nilaiBaru, '19.00211');
      expect(s.sumber, 'ketik');
      expect(s.pengguna?.id, 3);
      expect(s.pengguna?.nama, 'Admin Lab');
      expect(s.dibuatPada, isNotNull);
    });

    test('toleran: status asing & objek kosong tidak meledak', () {
      final v = RingkasanVersiAcuan.fromJson(const {'status': 'baru-di-p9'});
      expect(v.status, StatusVersiAcuan.tidakDikenal);
      expect(v.kodeStatus, 'baru-di-p9', reason: 'kode mentah tetap ada');

      final p = PaketAcuan.fromJson(const {});
      expect(p.kode, '');
      expect(p.diimpor, isFalse);
      expect(p.versiAktif, isNull);

      expect(BandingAcuan.fromJson(const {}).lembar, isEmpty);
      expect(RiwayatSelAcuan.fromJson(const {}).riwayat, isEmpty);
      expect(VersiAcuan.fromJson(const {}).isi, isNull);
    });
  });

  group('MockDataAcuanService — meniru jawaban server', () {
    test(
      'daftar (admin): Micrometer v1 aktif + satu paket belum diimpor',
      () async {
        final daftar = await MockDataAcuanService().daftarPaket('t');

        expect(daftar.map((p) => p.kode), ['micrometer', 'height_gauge']);

        final m = daftar.first;
        expect(m.diimpor, isTrue);
        expect(m.versiAktif?.nomor, 1);
        expect(m.versiAktif?.berlakuMulai, DateTime(2024));
        // sha256 kanonik versi 1 yang sama dengan kontrak §15 (`ba1fa153…f585`).
        expect(m.versiAktif?.sha256, contohSha256MicrometerV1);
        expect(contohSha256MicrometerV1, startsWith('ba1fa153'));
        expect(contohSha256MicrometerV1, endsWith('f585'));
        expect(m.versiTerjadwal, isEmpty);
        expect(m.jumlahDraf, 0);

        final lain = daftar.last;
        expect(lain.diimpor, isFalse);
        expect(lain.versiAktif, isNull);
      },
    );

    test('daftar & detail (teknisi): kunci draf/terjadwal tidak ada', () async {
      final mock = MockDataAcuanService(sebagaiTeknisi: true);

      final daftar = await mock.daftarPaket('t');
      expect(daftar.first.versiTerjadwal, isNull);
      expect(daftar.first.jumlahDraf, isNull);

      final detail = await mock.paket('t', 'micrometer');
      expect(detail.jumlahDiajukan, isNull);
      expect(detail.skema?.lembar, hasLength(8));
    });

    test(
      'detail admin membawa skema & jumlah_diajukan; paket lain → 404',
      () async {
        final mock = MockDataAcuanService();

        final detail = await mock.paket('t', 'micrometer');
        expect(detail.jumlahDiajukan, 0);
        expect(detail.skema?.lembar.map((l) => l.kode), contains('pita_cmc'));

        await expectLater(
          mock.paket('t', 'height_gauge'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
        );
      },
    );

    test(
      'berlaku: sebelum versi 1 → null + alasan; sesudahnya → v1; jenis salah → 422',
      () async {
        final admin = MockDataAcuanService();

        final sebelum = await admin.berlaku(
          't',
          'micrometer',
          DateTime(2023, 12, 31),
        );
        expect(sebelum.versi, isNull);
        expect(sebelum.alasan, contains('2024-01-01'));

        final ada = await admin.berlaku(
          't',
          'micrometer',
          DateTime(2025, 5, 2),
        );
        expect(ada.versi?.nomor, 1);
        expect(ada.versi?.isi, isNull, reason: 'isi hanya di versi/{id}');
        expect(ada.alasan, isNull);

        // Tepat di berlaku_mulai (inklusif).
        expect(
          (await admin.berlaku('t', 'micrometer', DateTime(2024))).versi?.id,
          1,
        );

        final teknisi = await MockDataAcuanService(
          sebagaiTeknisi: true,
        ).berlaku('t', 'micrometer', DateTime(2023, 12, 31));
        expect(
          teknisi.alasan,
          'Tidak ada versi aktif yang berlaku pada tanggal itu.',
          reason: 'teknisi tidak boleh melihat tanggal versi',
        );

        await expectLater(
          admin.berlaku('t', 'micrometer', DateTime(2025), jenis: 'rumus'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
        );
      },
    );

    test(
      'versi 1: isi utuh, tipe angka ikut JSON, tanpa pengesah karangan',
      () async {
        final v1 = await MockDataAcuanService().versi('t', 1);

        expect(v1.isiSha256, contohSha256MicrometerV1);
        expect(v1.disahkanOleh, isNull);
        expect(v1.disahkanPada, isNull);
        expect(v1.dibuatOleh, isNull);

        final isi = v1.isi! as Map<String, dynamic>;
        expect((isi['balok_ukur'] as Map)['19.0'], 19.00011);
        expect((isi['balok_ukur'] as Map), hasLength(32));
        final konstanta = isi['konstanta'] as Map<String, dynamic>;
        expect(konstanta['suhu_acuan_c'], isA<double>());
        expect(konstanta['suhu_acuan_c'], 20.0);
        expect(konstanta['vi_type_b'], isA<int>());
        expect(konstanta['delta_alpha_per_c'], 1e-5);
        expect(isi['cmc'] as List, hasLength(4));

        await expectLater(
          MockDataAcuanService().versi('t', 99),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
        );
      },
    );

    test('banding v1↔v1: semua lembar, nol perubahan; teknisi → 404', () async {
      final b = await MockDataAcuanService().banding('t', 1, 1);

      expect(b.lembar, hasLength(8));
      expect(b.lembar.every((l) => !l.berubah), isTrue);
      expect(b.ringkasan.selBerubah, 0);

      await expectLater(
        MockDataAcuanService(sebagaiTeknisi: true).banding('t', 1, 1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    group('riwayat sel membaca sel persis seperti `SelAcuan` server', () {
      Future<RiwayatSelAcuan> sel(String lembar, String kunci, String kolom) =>
          MockDataAcuanService().riwayatSel(
            't',
            versiId: 1,
            lembar: lembar,
            kunci: kunci,
            kolom: kolom,
          );

      test('lembar baris: balok 19,0 mm', () async {
        final r = await sel('balok_ukur', '19.0', 'nilai_terkoreksi_mm');

        expect(r.ada, isTrue);
        expect(r.nilai, 19.00011);
        expect(r.kolom?.asal, 'Standar_GB!R10:R132');
        expect(r.kolom?.satuan, 'mm');
        expect(r.riwayat.single.nilai, 19.00011);
        expect(r.riwayat.single.versi?.nomor, 1);
        expect(r.suntingan, isEmpty, reason: 'versi impor tanpa suntingan');
      });

      // Tiga kasus berikut = `DataAcuanBacaTest::
      // test_riwayat_sel_kunci_khusus_dan_lembar_objek` di repo API.
      test('kunci objek berangka bulat `200`', () async {
        expect(
          (await sel('ketidakpastian_balok_khusus', '200', 'u_um')).nilai,
          0.73,
        );
      });

      test('lembar objek berkunci 0 — int tetap int', () async {
        final r = await sel('konstanta', '0', 'vi_type_b');
        expect(r.nilai, 200);
        expect(r.nilai, isA<int>());
      });

      test('tangga tanpa kunci: posisi', () async {
        expect(
          (await sel('ketidakpastian_balok_tangga', '1', 'u')).nilai,
          0.14,
        );
      });

      test('jalur `cmc/*/titik`: varian ke-2 baris ke-4 = `1:3`', () async {
        expect(
          (await sel('titik_pra_cetak', '1:3', 'nominal_cetak_mm')).nilai,
          32.7,
        );
      });

      test('daftar berkunci: pita CMC varian B', () async {
        expect((await sel('pita_cmc', 'B', 'u95_um')).nilai, 0.87);
      });

      test('kunci yang tidak ada → ada false, bukan galat', () async {
        final r = await sel('balok_ukur', '999.0', 'nilai_terkoreksi_mm');
        expect(r.ada, isFalse);
        expect(r.nilai, isNull);
      });

      test('lembar/kolom di luar skema → 404; teknisi → 404', () async {
        final tidakAda = throwsA(
          isA<ApiException>().having((e) => e.status, 'status', 404),
        );

        await expectLater(
          sel('tidak_ada', '1.0', 'nilai_terkoreksi_mm'),
          tidakAda,
        );
        await expectLater(sel('balok_ukur', '1.0', 'tidak_ada'), tidakAda);
        await expectLater(
          MockDataAcuanService(sebagaiTeknisi: true).riwayatSel(
            't',
            versiId: 1,
            lembar: 'balok_ukur',
            kunci: '19.0',
            kolom: 'nilai_terkoreksi_mm',
          ),
          tidakAda,
        );
      });
    });
  });

  group('ApiDataAcuanService — rute & bentuk', () {
    ({ApiDataAcuanService service, List<http.Request> diminta}) server(
      Map<String, dynamic> Function(http.Request r) jawab, {
      int status = 200,
    }) {
      final diminta = <http.Request>[];
      final client = MockClient((r) async {
        diminta.add(r);
        return http.Response(
          jsonEncode(jawab(r)),
          status,
          headers: {'content-type': 'application/json'},
        );
      });

      return (
        service: ApiDataAcuanService(
          ApiClient(client: client, baseUrl: 'http://uji.test/api'),
        ),
        diminta: diminta,
      );
    }

    test('berlaku: tanggal YYYY-MM-DD + jenis di query', () async {
      final s = server((_) => {'data': null, 'alasan': 'x'});

      await s.service.berlaku('t', 'micrometer', DateTime(2025, 5, 2, 23, 59));

      final url = s.diminta.single.url;
      expect(url.path, '/api/data-acuan/paket/micrometer/berlaku');
      expect(url.queryParameters, {'tanggal': '2025-05-02', 'jenis': 'data'});
      expect(s.diminta.single.headers['Authorization'], 'Bearer t');
    });

    test('riwayat sel: segmen di-encode (`1:3` tetap satu segmen)', () async {
      final s = server((_) => {'data': <String, dynamic>{}});

      await s.service.riwayatSel(
        't',
        versiId: 15,
        lembar: 'titik_pra_cetak',
        kunci: '1:3',
        kolom: 'nominal_cetak_mm',
      );

      final url = s.diminta.single.url;
      expect(url.pathSegments, [
        'api',
        'data-acuan',
        'versi',
        '15',
        'sel',
        'titik_pra_cetak',
        '1:3',
        'nominal_cetak_mm',
        'riwayat',
      ]);
    });

    test('versi dari teks JSON: 20.0 terbaca double lewat jalur API', () async {
      final diminta = <http.Request>[];
      final client = MockClient((r) async {
        diminta.add(r);
        return http.Response(
          '{"data":{"id":12,"jenis":"data","nomor":1,"status":"aktif",'
          '"isi":{"konstanta":{"suhu_acuan_c":20.0,"vi_type_b":200}}}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final v = await ApiDataAcuanService(
        ApiClient(client: client, baseUrl: 'http://uji.test/api'),
      ).versi('t', 12);

      expect(diminta.single.url.path, '/api/data-acuan/versi/12');
      final k = (v.isi! as Map)['konstanta'] as Map;
      expect(k['suhu_acuan_c'], isA<double>());
      expect(k['vi_type_b'], isA<int>());
    });

    test('404 teknisi diteruskan apa adanya (bukan ditelan)', () async {
      final s = server((_) => {'message': 'Not Found'}, status: 404);

      await expectLater(
        s.service.banding('t', 12, 15),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
      expect(s.diminta.single.url.path, '/api/data-acuan/versi/12/banding/15');
    });

    test('daftar & garis waktu', () async {
      final s = server(
        (r) => r.url.path.endsWith('/versi')
            ? {
                'data': [
                  {'id': 12, 'jenis': 'data', 'nomor': 1, 'status': 'pensiun'},
                  {'id': 15, 'jenis': 'data', 'nomor': 2, 'status': 'aktif'},
                ],
              }
            : {
                'data': [
                  {'kode': 'micrometer', 'nama': 'Micrometer', 'diimpor': true},
                ],
              },
      );

      expect((await s.service.daftarPaket('t')).single.kode, 'micrometer');
      final waktu = await s.service.garisWaktu('t', 'micrometer');
      expect(waktu.map((v) => v.status), [
        StatusVersiAcuan.pensiun,
        StatusVersiAcuan.aktif,
      ]);
      expect(s.diminta.last.url.path, '/api/data-acuan/paket/micrometer/versi');
    });
  });

  group('provider & realtime', () {
    ProviderContainer buat({
      required DataAcuanService acuan,
      required LembarKerjaService lembar,
      required MockRealtimeService rt,
    }) {
      final c = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
          dataAcuanServiceProvider.overrideWithValue(acuan),
          lembarKerjaServiceProvider.overrideWithValue(lembar),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('provider membaca layanan dengan token akun', () async {
      final c = buat(
        acuan: MockDataAcuanService(),
        lembar: MockLembarKerjaService(),
        rt: MockRealtimeService(),
      );

      final daftar = await c.read(daftarPaketAcuanProvider.future);
      expect(daftar.first.kode, 'micrometer');

      final riwayat = await c.read(
        riwayatSelAcuanProvider((
          versiId: 1,
          lembar: 'balok_ukur',
          kunci: '19.0',
          kolom: 'nilai_terkoreksi_mm',
        )).future,
      );
      expect(riwayat.nilai, 19.00011);

      final berlaku = await c.read(
        berlakuAcuanProvider((
          kode: 'micrometer',
          tanggal: DateTime(2025, 5, 2),
          jenis: 'data',
        )).future,
      );
      expect(berlaku.versi?.nomor, 1);
    });

    test('sinyal `data_acuan` & tarikan berkala menarik ulang Studio + lembar; '
        'sinyal kalibrasi tidak', () async {
      final acuan = _HitungAcuan();
      final lembar = _HitungLembar();
      final rt = MockRealtimeService();
      final c = buat(acuan: acuan, lembar: lembar, rt: rt);

      const kunci = (
        profil: 'micrometer',
        pengulangan: null,
        equipmentId: null,
      );
      c.listen(realtimeSyncProvider, (_, _) {});
      c.listen(daftarPaketAcuanProvider, (_, _) {});
      c.listen(lembarKerjaProvider(kunci), (_, _) {});

      await c.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await c.read(daftarPaketAcuanProvider.future);
      await c.read(lembarKerjaProvider(kunci).future);
      final awalAcuan = acuan.panggilan;
      final awalLembar = lembar.panggilan;

      Future<void> pancar(String jenis) async {
        rt.pancarkan(DataBerubah(jenis: jenis, aksi: 'aktif', id: 2));
        await Future<void>.delayed(Duration.zero);
        await c.read(daftarPaketAcuanProvider.future);
        await c.read(lembarKerjaProvider(kunci).future);
      }

      await pancar('kalibrasi');
      expect(
        acuan.panggilan,
        awalAcuan,
        reason: 'kalibrasi tidak mengubah acuan',
      );
      expect(lembar.panggilan, awalLembar);

      await pancar(jenisDataAcuan);
      expect(acuan.panggilan, awalAcuan + 1);
      expect(lembar.panggilan, awalLembar + 1);

      await pancar(jenisTarikBerkala);
      expect(acuan.panggilan, awalAcuan + 2);
      expect(lembar.panggilan, awalLembar + 2);
    });
  });
}

class _HitungAcuan extends MockDataAcuanService {
  int panggilan = 0;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) {
    panggilan++;
    return super.daftarPaket(token);
  }
}

class _HitungLembar extends MockLembarKerjaService {
  int panggilan = 0;

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) {
    panggilan++;
    return super.ambilBentuk(
      token,
      profil: profil,
      pengulangan: pengulangan,
      equipmentId: equipmentId,
    );
  }
}
