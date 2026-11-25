import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Model respons `ocr-awan` dan pemetaan galatnya.
///
/// Semua masukan di sini bentuk dari kontrak (`docs/kontrak-api.md` §22A di repo
/// API), BUKAN keluaran Google sungguhan: tes ini membuktikan klien menafsirkan
/// kontrak dengan benar, bukan bahwa OCR-nya akurat (akurasi belum terukur).
void main() {
  group('HasilOcrAwan.fromJson', () {
    // Contoh respons dari `docs/perintah-frontend-ocr-sel-awan.md`, ditambah satu
    // sel merah, satu kosong, dan satu yang Google gagal membacanya.
    final json = <String, dynamic>{
      'hasil': [
        {
          'kunci': 'tabel_a|1|1|pembacaan',
          'teks_awan': '4.01',
          'keyakinan': 0.93,
          'status': 'kuning',
          'teks_normal': '4,01',
          'nilai_awan': 4.01,
          'dinormalkan': true,
          'alasan': <String>[],
        },
        {
          'kunci': 'tabel_a|2|1|pembacaan',
          'teks_awan': '4,0l',
          'keyakinan': 0.41,
          'status': 'merah',
          'teks_normal': null,
          'nilai_awan': null,
          'dinormalkan': false,
          'alasan': ['bukan_angka_murni'],
        },
        {
          'kunci': 'tabel_a|3|1|pembacaan',
          'teks_awan': '',
          'keyakinan': null,
          'status': 'kosong',
          'teks_normal': null,
          'nilai_awan': null,
          'dinormalkan': false,
          'alasan': <String>[],
        },
        {
          'kunci': 'tabel_a|4|1|pembacaan',
          'teks_awan': null,
          'keyakinan': null,
          'status': 'merah',
          'teks_normal': null,
          'nilai_awan': null,
          'dinormalkan': false,
          'alasan': ['google_gagal'],
        },
      ],
      'dilewati': [
        {'kunci': 'isian|suhu_awal', 'alasan': 'isian_tidak_dikirim'},
      ],
      'meta': {
        'sumber': 'google_vision',
        'fitur': 'DOCUMENT_TEXT_DETECTION',
        'unit': 1,
        'jumlah_dikirim': 4,
        'jumlah_panggilan': 1,
        'usulan': true,
        'sebagian': true,
        'dilewati_otomatis': {'sudah_hijau_lokal': 3, 'kosong_lokal': 1},
        'sisa_sel_scan': 76,
      },
    };

    test('semua field kontrak terbaca', () {
      final h = HasilOcrAwan.fromJson(json);

      expect(h.hasil, hasLength(4));

      final s = h.hasil.first;
      expect(s.kunci, 'tabel_a|1|1|pembacaan');
      expect(s.teksAwan, '4.01');
      expect(s.keyakinan, 0.93);
      expect(s.status, StatusSelAwan.kuning);
      expect(s.teksNormal, '4,01');
      expect(s.nilaiAwan, 4.01);
      expect(s.dinormalkan, isTrue);
      expect(s.alasan, isEmpty);

      expect(h.dilewati.single.kunci, 'isian|suhu_awal');
      expect(h.dilewati.single.alasan, 'isian_tidak_dikirim');

      expect(h.meta.sebagian, isTrue);
      expect(h.meta.usulan, isTrue);
      expect(h.meta.jumlahDikirim, 4);
      expect(h.meta.jumlahPanggilan, 1);
      expect(h.meta.sisaSelScan, 76);
      expect(h.meta.dilewatiOtomatis, {'sudah_hijau_lokal': 3, 'kosong_lokal': 1});
    });

    test('teks_awan null (Google gagal) dibedakan dari "" (tak ada tulisan)', () {
      final h = HasilOcrAwan.fromJson(json);

      expect(h.hasil[2].teksAwan, '');
      expect(h.hasil[2].status, StatusSelAwan.kosong);
      expect(h.hasil[3].teksAwan, isNull);
      expect(h.hasil[3].status, StatusSelAwan.merah);
      expect(h.hasil[3].alasan, ['google_gagal']);
    });

    test('hanya sel kuning bernilai normal yang menjadi usulan', () {
      final h = HasilOcrAwan.fromJson(json);

      expect(h.usulan.map((e) => e.kunci), ['tabel_a|1|1|pembacaan']);
      expect(h.hasil[1].adaUsulan, isFalse, reason: 'merah tidak mengisi');
      expect(h.hasil[2].adaUsulan, isFalse, reason: 'kosong tetap kosong');
      expect(h.hasil[3].adaUsulan, isFalse, reason: 'Google gagal tidak mengisi');
    });

    test('perKunci memetakan sel menurut kunci dari server', () {
      final h = HasilOcrAwan.fromJson(json);

      expect(h.perKunci['tabel_a|2|1|pembacaan']?.status, StatusSelAwan.merah);
      expect(h.perKunci['tidak|ada|1|x'], isNull);
    });

    test('respons kosong atau cacat tidak melempar', () {
      final kosong = HasilOcrAwan.fromJson(const {});
      expect(kosong.hasil, isEmpty);
      expect(kosong.dilewati, isEmpty);
      expect(kosong.meta.sebagian, isFalse);
      expect(kosong.meta.usulan, isTrue);

      final cacat = HasilOcrAwan.fromJson({
        'hasil': 'bukan list',
        'dilewati': [1, 'x', null],
        'meta': 'bukan map',
      });
      expect(cacat.hasil, isEmpty);
      expect(cacat.dilewati, isEmpty);
    });

    test('entri tanpa kunci dibuang, bukan ditebak', () {
      final h = HasilOcrAwan.fromJson({
        'hasil': [
          {'teks_awan': '1', 'status': 'kuning', 'teks_normal': '1'},
          {'kunci': '', 'status': 'kuning', 'teks_normal': '2'},
          {'kunci': 't|1|1|a', 'status': 'kuning', 'teks_normal': '3'},
        ],
      });

      expect(h.hasil.map((e) => e.kunci), ['t|1|1|a']);
    });
  });

  group('status: tidak pernah hijau', () {
    test('"hijau" dari server diturunkan ke kuning, bukan ditampilkan hijau', () {
      final s = SelOcrAwan.dariJson({
        'kunci': 't|1|1|a',
        'teks_awan': '4,01',
        'status': 'hijau',
        'teks_normal': '4,01',
      })!;

      expect(s.status, StatusSelAwan.kuning);
    });

    test('status tak dikenal atau hilang jatuh ke merah (tidak jadi usulan)', () {
      for (final nilai in <Object?>['ungu', '', 7, null]) {
        final s = SelOcrAwan.dariJson({
          'kunci': 't|1|1|a',
          'teks_awan': '4,01',
          'status': nilai,
          'teks_normal': '4,01',
        })!;

        expect(s.status, StatusSelAwan.merah, reason: 'status=$nilai');
        expect(s.adaUsulan, isFalse);
      }
    });

    test('enum tidak punya anggota hijau sama sekali', () {
      expect(StatusSelAwan.values.map((e) => e.name), [
        'kuning',
        'merah',
        'kosong',
      ]);
    });
  });

  group('dua bentuk berdampingan', () {
    SelOcrAwan sel({
      String? awan,
      String? normal,
      bool dinormalkan = false,
    }) => SelOcrAwan(
      kunci: 't|1|1|a',
      status: StatusSelAwan.kuning,
      teksAwan: awan,
      teksNormal: normal,
      dinormalkan: dinormalkan,
    );

    test('dinormalkan: true -> bentukBeda', () {
      expect(sel(awan: '4.01', normal: '4,01', dinormalkan: true).bentukBeda, isTrue);
    });

    test('teks beda walau bendera hilang -> tetap bentukBeda', () {
      expect(sel(awan: '4.01', normal: '4,01').bentukBeda, isTrue);
    });

    test('teks sama -> tidak perlu dua kolom', () {
      expect(sel(awan: '4,01', normal: '4,01').bentukBeda, isFalse);
    });

    test('tanpa teks_normal tidak ada bentuk kedua', () {
      expect(sel(awan: '4.01').bentukBeda, isFalse);
    });
  });

  group('periksaKunciOcrAwan', () {
    test('kunci sah lolos tanpa diubah, duplikat dibuang', () {
      final hasil = periksaKunciOcrAwan([
        'tabel_a|1|1|pembacaan',
        'tabel_a|2|1|pembacaan',
        'tabel_a|1|1|pembacaan',
      ]);

      expect(hasil, ['tabel_a|1|1|pembacaan', 'tabel_a|2|1|pembacaan']);
    });

    test('daftar kosong ditolak: bukan diam-diam "baca semuanya"', () {
      expect(() => periksaKunciOcrAwan(const []), throwsArgumentError);
    });

    test('kunci kosong ditolak', () {
      expect(() => periksaKunciOcrAwan(['  ']), throwsArgumentError);
    });

    test('sel identitas (isian, centang) tidak pernah diminta', () {
      expect(() => periksaKunciOcrAwan(['isian|suhu_awal']), throwsArgumentError);
      expect(() => periksaKunciOcrAwan(['centang|lulus']), throwsArgumentError);
      expect(
        () => periksaKunciOcrAwan(['tabel_a|1|1|pembacaan', 'isian|suhu_awal']),
        throwsArgumentError,
        reason: 'satu kunci identitas menolak seluruh kiriman',
      );
    });

    test('tepat $maksKunciOcrAwan boleh, lebih ditolak (tanpa dipecah otomatis)', () {
      List<String> buat(int n) => [for (var i = 1; i <= n; i++) 't|$i|1|a'];

      expect(periksaKunciOcrAwan(buat(maksKunciOcrAwan)), hasLength(maksKunciOcrAwan));
      expect(
        () => periksaKunciOcrAwan(buat(maksKunciOcrAwan + 1)),
        throwsArgumentError,
      );
    });

    test('duplikat tidak dihitung ke batas', () {
      final banyak = [for (var i = 0; i < 100; i++) 't|1|1|a'];

      expect(periksaKunciOcrAwan(banyak), ['t|1|1|a']);
    });
  });

  group('GalatOcrAwan.dariRespons', () {
    ApiException api(int status, Map<String, dynamic> body) => ApiException(
      '${body['message'] ?? 'galat'}',
      status: status,
      body: body,
    );

    Map<String, dynamic> galat(String kode) => {
      'message': 'Kalimat tetap dari server.',
      'kode': kode,
      'fallback_manual': true,
    };

    const peta = <(int, String), JenisGalatOcrAwan>{
      (503, 'fitur_dimatikan'): JenisGalatOcrAwan.fiturMati,
      (503, 'ocr_cloud_belum_aktif'): JenisGalatOcrAwan.awanBelumSiap,
      (503, 'ocr_cloud_belum_disetel'): JenisGalatOcrAwan.awanBelumSiap,
      (503, 'citra_tidak_bisa_dipotong'): JenisGalatOcrAwan.awanBelumSiap,
      (422, 'citra_tidak_tersimpan'): JenisGalatOcrAwan.citraBermasalah,
      (422, 'citra_rusak'): JenisGalatOcrAwan.citraBermasalah,
      (422, 'gambar_tidak_terbaca'): JenisGalatOcrAwan.tidakTerbaca,
      (429, 'batas_per_lembar'): JenisGalatOcrAwan.jatahHabis,
      (429, 'gagal_berulang_per_lembar'): JenisGalatOcrAwan.jatahHabis,
      (429, 'batas_sel_per_scan'): JenisGalatOcrAwan.jatahHabis,
      (502, 'ocr_cloud_gagal'): JenisGalatOcrAwan.awanGagal,
    };

    for (final e in peta.entries) {
      test('${e.key.$1} ${e.key.$2} -> ${e.value.name}, jatuh ke jalur lama', () {
        final g = GalatOcrAwan.dariRespons(api(e.key.$1, galat(e.key.$2)));

        expect(g, isNotNull);
        expect(g!.jenis, e.value);
        expect(g.status, e.key.$1);
        expect(g.kode, e.key.$2);
        expect(g.fallbackManual, isTrue);
        expect(g.pesan, 'Kalimat tetap dari server.');
        // 429 dan 502 tidak boleh diulang otomatis; berlaku untuk SEMUA jenis.
        expect(g.bolehUlangOtomatis, isFalse);
      });
    }

    test('429 tanpa kode = limiter 4 per menit, bukan jatah habis', () {
      final g = GalatOcrAwan.dariRespons(
        api(429, {'message': 'Terlalu sering.', 'fallback_manual': true}),
      )!;

      expect(g.jenis, JenisGalatOcrAwan.terlaluSering);
      expect(g.kode, isNull);
      expect(g.bolehUlangOtomatis, isFalse);
    });

    test('gagal_berulang_per_lembar: berhenti memanggil untuk lembar itu', () {
      final g = GalatOcrAwan.dariRespons(
        api(429, galat('gagal_berulang_per_lembar')),
      )!;

      expect(g.berhentiUntukLembar, isTrue);

      final lain = GalatOcrAwan.dariRespons(api(429, galat('batas_per_lembar')))!;
      expect(lain.berhentiUntukLembar, isFalse);
    });

    test('fitur_dimatikan meminta fitur_nonaktif diambil ulang', () {
      final g = GalatOcrAwan.dariRespons(api(503, galat('fitur_dimatikan')))!;

      expect(g.perluAmbilUlangFitur, isTrue);
      expect(
        GalatOcrAwan.dariRespons(api(502, galat('ocr_cloud_gagal')))!.perluAmbilUlangFitur,
        isFalse,
      );
    });

    test('kode baru yang belum dikenal tetapi fallback_manual: true -> lainnya', () {
      final g = GalatOcrAwan.dariRespons(api(503, galat('kode_masa_depan')))!;

      expect(g.jenis, JenisGalatOcrAwan.lainnya);
      expect(g.kode, 'kode_masa_depan');
      expect(g.fallbackManual, isTrue);
    });

    test('dicocokkan dari kode, bukan dari kalimat message', () {
      final g = GalatOcrAwan.dariRespons(
        api(502, {
          'message': 'kalimat apa saja, bahkan menyebut fitur_dimatikan',
          'kode': 'ocr_cloud_gagal',
          'fallback_manual': true,
        }),
      )!;

      expect(g.jenis, JenisGalatOcrAwan.awanGagal);
    });

    test('bukan galat OCR awan -> null, TIDAK disamarkan', () {
      // 422 validasi (tanpa kode): kiriman klien salah, bukan "pindai ulang".
      expect(
        GalatOcrAwan.dariRespons(
          api(422, {
            'message': 'Data tidak valid.',
            'errors': {
              'kunci': ['maks 48'],
            },
          }),
        ),
        isNull,
      );
      // Kepemilikan: hasil pindai milik lab/teknisi lain.
      expect(GalatOcrAwan.dariRespons(api(404, {'message': 'Tidak ada.'})), isNull);
      expect(GalatOcrAwan.dariRespons(api(403, {'message': 'Dilarang.'})), isNull);
      // 5xx polos (mis. proxy) tanpa kode dan tanpa fallback_manual.
      expect(GalatOcrAwan.dariRespons(api(502, const {})), isNull);
      expect(GalatOcrAwan.dariRespons(api(500, const {})), isNull);
    });

    test('kode bertipe aneh tidak melempar', () {
      expect(
        GalatOcrAwan.dariRespons(api(503, {'kode': 42, 'fallback_manual': 'ya'})),
        isNull,
      );
    });
  });
}
