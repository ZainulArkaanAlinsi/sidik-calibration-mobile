import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/usulan_ocr_awan.dart';

/// Alur usulan OCR awan (gerbang 2): hasil awan hanya USULAN, tidak pernah
/// menjadi nilai tanpa aksi teknisi pada sel itu. Respons PALSU, tanpa jaringan.
void main() {
  group('bacaAngkaUsulan: bentuk angka murni saja', () {
    const sah = <String, double>{
      '4,01': 4.01,
      '4.01': 4.01,
      '-0,5': -0.5,
      '+2': 2,
      '12': 12,
      '  7,0 ': 7,
      '0,755': 0.755,
    };

    for (final e in sah.entries) {
      test('"${e.key}" -> ${e.value}', () {
        expect(bacaAngkaUsulan(e.key), e.value);
      });
    }

    const ditolak = [
      '',
      '  ',
      'abc',
      '1e5',
      'NaN',
      'Infinity',
      '1.234,56',
      '1.234.567',
      '1,2,3',
      '4,',
      ',5',
      '4 01',
      '4,0O',
      '--1',
    ];

    for (final t in ditolak) {
      test('"$t" ditolak, tidak ditebak', () {
        expect(bacaAngkaUsulan(t), isNull);
      });
    }

    test('null -> null', () {
      expect(bacaAngkaUsulan(null), isNull);
    });

    test('tidak dibulatkan', () {
      expect(bacaAngkaUsulan('0,7549999'), 0.7549999);
    });
  });

  group('PapanUsulanAwan.dari: siapa yang boleh jadi usulan', () {
    test('kuning + teks_normal angka -> usulan, belum ada nilai', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([_sel('a|1|1|p', teksAwan: '4.01', teksNormal: '4,01')]),
      );

      expect(papan.usulan, hasLength(1));
      expect(papan.tanpaUsulan, isEmpty);

      final u = papan.usulan.single;
      expect(u.keputusan, KeputusanUsulan.menunggu);
      expect(u.perluDicek, isTrue);
      expect(u.terkonfirmasi, isFalse);
      expect(u.teksFinal, isNull);
      expect(u.nilaiFinal, isNull);
      expect(u.teksUsulan, '4,01');
      expect(u.angkaUsulan, 4.01);

      // Belum ada aksi teknisi = belum ada satu nilai pun.
      expect(papan.koreksiTerkonfirmasi, isEmpty);
      expect(papan.jumlahMenunggu, 1);
      expect(papan.adaYangMenunggu, isTrue);
    });

    test('merah dan kosong tidak pernah jadi usulan, sel tetap kosong', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([
          _sel('a|1|1|p', status: 'merah', teksAwan: 'x1', alasan: ['karakter_di_luar_whitelist']),
          _sel('a|2|1|p', status: 'kosong', teksAwan: ''),
          _sel('a|3|1|p', teksAwan: '5', teksNormal: '5'),
        ]),
      );

      expect(papan.usulan.map((u) => u.kunci), ['a|3|1|p']);
      expect(papan.tanpaUsulan.map((s) => s.kunci), ['a|1|1|p', 'a|2|1|p']);
      expect(papan.tanpaUsulan[0].sebab, AlasanTanpaUsulan.merah);
      expect(papan.tanpaUsulan[0].alasan, ['karakter_di_luar_whitelist']);
      expect(papan.tanpaUsulan[1].sebab, AlasanTanpaUsulan.kosong);

      expect(() => papan.pakai('a|1|1|p'), throwsArgumentError);
      expect(() => papan.pakai('a|2|1|p'), throwsArgumentError);
    });

    test('kuning tanpa teks_normal atau dengan bentuk aneh tidak ditebak', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([
          _sel('a|1|1|p', teksAwan: '4.01'),
          _sel('a|2|1|p', teksAwan: '1.234,5', teksNormal: '1.234,5'),
          _sel('a|3|1|p', teksAwan: '5', teksNormal: '  '),
        ]),
      );

      expect(papan.usulan, isEmpty);
      expect(
        papan.tanpaUsulan.map((s) => s.sebab),
        everyElement(AlasanTanpaUsulan.bentukTidakDikenal),
      );
      expect(papan.tanpaUsulan, hasLength(3));
    });

    test('status hijau dari server diturunkan ke kuning, tetap wajib dicek', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([_sel('a|1|1|p', status: 'hijau', teksAwan: '3', teksNormal: '3')]),
      );

      expect(papan.usulan.single.perluDicek, isTrue);
      expect(papan.koreksiTerkonfirmasi, isEmpty);
    });

    test('sel identitas (isian|, centang|) tidak pernah jadi usulan', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([
          _sel('isian|suhu_ruang', teksAwan: '23', teksNormal: '23'),
          _sel('centang|lulus', teksAwan: '1', teksNormal: '1'),
        ]),
      );

      expect(papan.usulan, isEmpty);
      expect(
        papan.tanpaUsulan.map((s) => s.sebab),
        everyElement(AlasanTanpaUsulan.selIdentitas),
      );
    });

    test('kunci kembar: yang pertama menang, satu sel satu keputusan', () {
      final papan = PapanUsulanAwan.dari(
        _hasil([
          _sel('a|1|1|p', teksAwan: '1', teksNormal: '1'),
          _sel('a|1|1|p', teksAwan: '2', teksNormal: '2'),
        ]),
      );

      expect(papan.usulan, hasLength(1));
      expect(papan.usulan.single.teksUsulan, '1');
    });

    test('dilewati dan meta.sebagian ikut terbawa', () {
      final papan = PapanUsulanAwan.dari(
        HasilOcrAwan(
          hasil: [_sel('a|1|1|p', teksAwan: '1', teksNormal: '1')],
          dilewati: const [SelDilewatiAwan(kunci: 'a|2|1|p', alasan: 'google_gagal')],
          meta: const MetaOcrAwan(sebagian: true),
        ),
      );

      expect(papan.sebagian, isTrue);
      expect(papan.dilewati.single.alasan, 'google_gagal');
    });
  });

  group('keputusan teknisi, satu sel satu aksi', () {
    PapanUsulanAwan tiga() => PapanUsulanAwan.dari(
      _hasil([
        _sel('a|1|1|p', teksAwan: '4.01', teksNormal: '4,01', dinormalkan: true),
        _sel('a|2|1|p', teksAwan: '5,02', teksNormal: '5,02'),
        _sel('a|3|1|p', teksAwan: '6', teksNormal: '6'),
      ]),
    );

    test('pakai satu sel TIDAK mengonfirmasi sel lain (tidak ada "terima semua")', () {
      final papan = tiga().pakai('a|2|1|p');

      expect(papan.cari('a|2|1|p')!.keputusan, KeputusanUsulan.dipakai);
      expect(papan.cari('a|1|1|p')!.keputusan, KeputusanUsulan.menunggu);
      expect(papan.cari('a|3|1|p')!.keputusan, KeputusanUsulan.menunggu);
      expect(papan.jumlahMenunggu, 2);

      final k = papan.koreksiTerkonfirmasi;
      expect(k.map((e) => e.kunci), ['a|2|1|p']);
      expect(k.single.nilaiFinal, 5.02);
      expect(k.single.toJson(), {'kunci': 'a|2|1|p', 'nilai_final': 5.02});
    });

    test('pakai: nilai = teks_normal apa adanya, bukan teks_awan', () {
      final u = tiga().pakai('a|1|1|p').cari('a|1|1|p')!;

      expect(u.teksFinal, '4,01');
      expect(u.nilaiFinal, 4.01);
    });

    test('papan lama tidak berubah (tidak bisa diubah diam-diam)', () {
      final awal = tiga();
      final sesudah = awal.pakai('a|1|1|p');

      expect(awal.cari('a|1|1|p')!.keputusan, KeputusanUsulan.menunggu);
      expect(awal.koreksiTerkonfirmasi, isEmpty);
      expect(sesudah.cari('a|1|1|p')!.keputusan, KeputusanUsulan.dipakai);
    });

    test('ubah: angka ketikan teknisi menggantikan usulan', () {
      final papan = tiga().ubah('a|1|1|p', '4,02');
      final u = papan.cari('a|1|1|p')!;

      expect(u.keputusan, KeputusanUsulan.diubah);
      expect(u.teksFinal, '4,02');
      expect(u.nilaiFinal, 4.02);
      expect(papan.koreksiTerkonfirmasi.single.nilaiFinal, 4.02);
    });

    test('ubah ke angka yang sama dengan usulan = dipakai', () {
      final u = tiga().ubah('a|1|1|p', '4.01').cari('a|1|1|p')!;

      expect(u.keputusan, KeputusanUsulan.dipakai);
      expect(u.nilaiFinal, 4.01);
    });

    test('ubah dengan bukan angka ditolak, tidak ada yang berubah', () {
      final papan = tiga();

      expect(() => papan.ubah('a|1|1|p', ''), throwsArgumentError);
      expect(() => papan.ubah('a|1|1|p', 'abc'), throwsArgumentError);
      expect(() => papan.ubah('a|1|1|p', '1.234,5'), throwsArgumentError);
      expect(papan.koreksiTerkonfirmasi, isEmpty);
    });

    test('tolak: tidak ada nilai, tidak masuk koreksi', () {
      final papan = tiga().tolak('a|1|1|p');
      final u = papan.cari('a|1|1|p')!;

      expect(u.keputusan, KeputusanUsulan.ditolak);
      expect(u.terkonfirmasi, isFalse);
      expect(u.nilaiFinal, isNull);
      expect(papan.koreksiTerkonfirmasi, isEmpty);
      expect(papan.jumlahMenunggu, 2);
    });

    test('kembalikan: keputusan dibatalkan, nilai hilang', () {
      final papan = tiga().pakai('a|1|1|p').kembalikan('a|1|1|p');
      final u = papan.cari('a|1|1|p')!;

      expect(u.keputusan, KeputusanUsulan.menunggu);
      expect(u.teksFinal, isNull);
      expect(u.nilaiFinal, isNull);
      expect(papan.koreksiTerkonfirmasi, isEmpty);
    });

    test('kunci yang tidak ada usulannya -> ArgumentError di semua aksi', () {
      final papan = tiga();

      expect(() => papan.pakai('x|1|1|p'), throwsArgumentError);
      expect(() => papan.ubah('x|1|1|p', '1'), throwsArgumentError);
      expect(() => papan.tolak('x|1|1|p'), throwsArgumentError);
      expect(() => papan.kembalikan('x|1|1|p'), throwsArgumentError);
    });

    test('urutan koreksi mengikuti urutan server, bukan urutan ketukan', () {
      final papan = tiga().pakai('a|3|1|p').pakai('a|1|1|p');

      expect(papan.koreksiTerkonfirmasi.map((e) => e.kunci), [
        'a|1|1|p',
        'a|3|1|p',
      ]);
    });

    test('daftar yang dibuka ke luar tidak bisa disunting', () {
      final papan = tiga();

      expect(() => papan.usulan.clear(), throwsUnsupportedError);
      expect(() => papan.tanpaUsulan.clear(), throwsUnsupportedError);
      expect(() => papan.dilewati.clear(), throwsUnsupportedError);
    });
  });

  group('dua bentuk berdampingan', () {
    test('dinormalkan -> awan dan normal keduanya tersedia', () {
      final u = PapanUsulanAwan.dari(
        _hasil([_sel('a|1|1|p', teksAwan: '4.01', teksNormal: '4,01', dinormalkan: true)]),
      ).usulan.single;

      expect(u.duaBentuk, isNotNull);
      expect(u.duaBentuk!.awan, '4.01');
      expect(u.duaBentuk!.normal, '4,01');
    });

    test('teks beda walau bendera dinormalkan hilang -> tetap dua bentuk', () {
      final u = PapanUsulanAwan.dari(
        _hasil([_sel('a|1|1|p', teksAwan: '4.01', teksNormal: '4,01')]),
      ).usulan.single;

      expect(u.duaBentuk, isNotNull);
    });

    test('teks sama -> satu bentuk saja', () {
      final u = PapanUsulanAwan.dari(
        _hasil([_sel('a|1|1|p', teksAwan: '5', teksNormal: '5')]),
      ).usulan.single;

      expect(u.duaBentuk, isNull);
    });
  });
}

HasilOcrAwan _hasil(List<SelOcrAwan> sel) => HasilOcrAwan(hasil: sel);

SelOcrAwan _sel(
  String kunci, {
  String status = 'kuning',
  String? teksAwan,
  String? teksNormal,
  bool dinormalkan = false,
  List<String> alasan = const [],
}) => SelOcrAwan.dariJson({
  'kunci': kunci,
  'status': status,
  'teks_awan': ?teksAwan,
  'teks_normal': ?teksNormal,
  'dinormalkan': dinormalkan,
  'alasan': alasan,
})!;
