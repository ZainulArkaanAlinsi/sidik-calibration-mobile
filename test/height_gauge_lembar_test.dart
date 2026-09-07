import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_panjang.dart';

/// **Lembar Height Gauge: dari kotak di layar sampai kunci di payload.**
///
/// ## Kenapa berkas ini ada, padahal Micrometer sudah punya yang serupa
///
/// Keduanya kelompok Panjang dan sama-sama bertitik pra-cetak, jadi gampang
/// disangka kembar dan dianggap sudah terjaga. Tiga hal membedakannya, dan
/// ketiganya menggerakkan ANGKA:
///
///  1. **TIGA tabel ber-`tahap` sama, bukan dua.** Micrometer cuma perlu satu
///     `offset_kunci`; di sini ada dua (`evaluasi` 1000, `paralelisme` 2000)
///     dan ketiganya harus saling lepas. Satu offset yang lupa dibedakan bikin
///     dua tabel berbagi kotak isian — kelas kegagalan yang sudah menggigit
///     Thermohygrometer, Timbangan, dan Micrometer.
///  2. **`paralelisme` SELALU mm**, tidak ikut dropdown satuan alat. Dia dibaca
///     pada Dial Indicator standar, dan batasnya (<= 0,01 mm) ditulis dalam mm.
///  3. **Tidak ada lantai CMC.** Height Gauge di luar lampiran akreditasi
///     LK-285-IDN. Di Micrometer, satuan yang kelupaan dipilih masih mendarat
///     di lantai CMC — salah, tapi tertampung. Di sini tidak ada yang
///     menampung: U95 langsung terbit terlalu kecil, tanpa satu pun angka yang
///     terlihat ganjil.
void main() {
  /// Alat contoh `1610232804` — persis yang dipakai bentuk mock ini (Height
  /// Gauge Insize Digital, kapasitas 600 mm, resolusi 0,01 mm).
  LembarKerjaState buatIsian() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaHeightGauge()),
      clientRequestId: 'uji-height-gauge',
    );

    isian.alat = const EquipmentLookup(
      id: 26,
      namaAlat: 'Height Gauge',
      serialNumber: '1610232804',
      kategori: 'panjang',
      status: 'aktif',
      satuan: 'mm',
      rangeMax: 600,
      resolusi: 0.01,
    );

    return isian;
  }

  TabelHasil tabelBagian(LembarKerjaState isian, String kode) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == kode).tabel.first;

  group('bentuk lembarnya sendiri', () {
    test('kebaca utuh — tujuh blok, tiga tabel, sepuluh titik pra-cetak', () {
      final isian = buatIsian();

      expect(isian.bentuk.judul, 'Calibration Work Sheet - Height Gauge');
      expect(isian.bentuk.bagian.map((b) => b.kode).toList(), [
        'identitas_alat',
        'pemilik',
        'usage_check',
        'paralelisme',
        'evaluasi',
        'hasil',
        'penutup',
      ]);

      final hasil = tabelBagian(isian, 'hasil');

      // Kalau ini `true`, HP menggambar kotak `titik_ukur` yang bisa diketik —
      // dan angka yang diketik teknisi tetap kalah di server, tanpa error.
      expect(
        hasil.titikBisaDiubah,
        isFalse,
        reason:
            'Nominalnya dipatok Instruksi Kerja dan sama persis dengan sepuluh '
            'baris tabel Outside sertifikat Caliper Checker.',
      );

      // Kesepuluh nominal, apa adanya dari master. Loncatannya TIDAK seragam
      // (25, 50, lalu 100) — yang menentukan nominal itu tingkat step gauge
      // yang tersedia, bukan deret aritmetika.
      expect(isian.barisTabel(hasil).map((b) => b.titikUkur).toList(), [
        25.0,
        50.0,
        100.0,
        150.0,
        200.0,
        300.0,
        400.0,
        500.0,
        550.0,
        600.0,
      ]);
    });

    test('tanpa nomor lingkup akreditasi & tanpa nomor formulir', () {
      final isian = buatIsian();

      // Dua-duanya SENGAJA kosong, dan keduanya soal audit — bukan data yang
      // kebetulan belum diisi.
      //
      // `nomor_lingkup`: Height Gauge di LUAR lampiran LK-285-IDN. Empat profil
      // lain memasangnya di kop lembar; mencetaknya di sini berarti mengklaim
      // lingkup yang tidak diakreditasi.
      //
      // `kode_dokumen`: kertas lembar kerjanya belum turun dari lab. Sapuan
      // `SIDIK-FM-` di seluruh workbook master cuma menemukan satu nomor, dan
      // itu formulir SERTIFIKAT bersama.
      //
      // `nomor_lingkup` diperiksa di JSON MENTAHnya, bukan lewat model:
      // `LembarKerja` memang tidak memodelkan kunci itu sama sekali, jadi
      // assertion lewat model bakal hijau apa pun isi servernya — hijau yang
      // tidak membuktikan apa-apa.
      expect(
        contohBentukLembarKerjaHeightGauge().containsKey('nomor_lingkup'),
        isFalse,
      );
      expect(isian.bentuk.kodeDokumen, isEmpty);
    });
  });

  group('kunci baris nggak bentrok antar KETIGA tabel', () {
    test('ketiganya sekunci tapi kotaknya lepas', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final evaluasi = tabelBagian(isian, 'evaluasi');
      final paralelisme = tabelBagian(isian, 'paralelisme');

      // Bentroknya BUKAN teoretis: kunci tabel ketiganya sama persis, karena
      // `peran` null bikin `kunciTabel` jatuh ke `tahap`.
      expect(hasil.kunciTabel, 'sesudah_adjustment');
      expect(evaluasi.kunciTabel, hasil.kunciTabel);
      expect(paralelisme.kunciTabel, hasil.kunciTabel);

      // Yang memisahkannya DUA offset yang berbeda. Satu offset yang dipakai
      // bersama tidak cukup — dua tabel yang berbagi offset tetap bertabrakan.
      expect(evaluasi.offsetKunci, isNotNull);
      expect(paralelisme.offsetKunci, isNotNull);
      expect(
        paralelisme.offsetKunci,
        isNot(evaluasi.offsetKunci),
        reason:
            'Paralelisme dan Evaluasi berbagi satu offset: kotaknya menyatu, '
            'dan pembacaan dial indicator mendarat di blok yang melahirkan '
            'keterulangan seluruh sesi.',
      );

      Set<double> kunci(TabelHasil t) {
        final baris = isian.barisTabel(t);
        return {
          for (var i = 0; i < baris.length; i++) isian.kunciBaris(baris, i, t),
        };
      }

      final kHasil = kunci(hasil);
      final kEval = kunci(evaluasi);
      final kParalel = kunci(paralelisme);

      expect(kHasil.intersection(kEval), isEmpty);
      expect(kHasil.intersection(kParalel), isEmpty);
      expect(
        kEval.intersection(kParalel),
        isEmpty,
        reason:
            'Baris Evaluasi yang tertimpa bikin keterulangan lahir dari '
            'pembacaan paralelisme, dan U95 SELURUH sesi ikut salah.',
      );
    });

    test('kotaknya beneran terpisah waktu diketik', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final evaluasi = tabelBagian(isian, 'evaluasi');
      final paralelisme = tabelBagian(isian, 'paralelisme');

      isian
              .titikUntukBaris(isian.barisTabel(hasil), 0, hasil)!
              .kotak(hasil.kunciTabel, 'pembacaan', 0)
              .text =
          '24.99';

      expect(
        isian
            .titikUntukBaris(isian.barisTabel(evaluasi), 0, evaluasi)!
            .kotak(evaluasi.kunciTabel, 'pembacaan', 0)
            .text,
        isEmpty,
        reason: 'Angka tabel hasil bocor ke blok Evaluation.',
      );
      expect(
        isian
            .titikUntukBaris(isian.barisTabel(paralelisme), 0, paralelisme)!
            .kotak(paralelisme.kunciTabel, 'pembacaan', 0)
            .text,
        isEmpty,
        reason: 'Angka tabel hasil bocor ke blok Paralelisme.',
      );
    });
  });

  group('penentu angka', () {
    test('satuan & resolusi ditanyakan kalau kosong', () {
      final isian = buatIsian();
      final kosong = isian.pilihanPenentuAngkaKosong.map((f) => f.kode);

      expect(
        kosong,
        contains('spesifikasi_alat.height_gauge.satuan'),
        reason:
            'Satuan yang kosong nggak bikin titiknya masuk `belum_dihitung` — '
            'server jatuh ke mm. Sesi berskala inch yang satuannya kelupaan '
            'menghitung mulus, terbit mulus, dan salah 25,4x. Di alat ini nggak '
            'ada lantai CMC yang menutupinya.',
      );
      expect(
        kosong,
        contains('spesifikasi_alat.height_gauge.resolusi_mm'),
        reason:
            'Resolusi kosong terbaca nol dan komponen budget resolusi lenyap. '
            'Server MEMBLOKIR sesinya, tapi teknisi baru tahu sesudah menekan '
            'kirim.',
      );
    });

    test('sudah dipilih → nggak ditanya lagi', () {
      final isian = buatIsian();

      isian.teks['spesifikasi_alat.height_gauge.satuan']!.text = 'mm';
      isian.teks['spesifikasi_alat.height_gauge.resolusi_mm']!.text = '0.01';

      expect(isian.pilihanPenentuAngkaKosong, isEmpty);
    });
  });

  group('payload', () {
    test('paralelisme & Evaluation masuk spesifikasi_alat, bukan measurements', () {
      final isian = buatIsian();

      final evaluasi = tabelBagian(isian, 'evaluasi');
      final paralelisme = tabelBagian(isian, 'paralelisme');

      for (var r = 0; r < 10; r++) {
        isian
                .titikUntukBaris(isian.barisTabel(evaluasi), 0, evaluasi)!
                .kotak(evaluasi.kunciTabel, 'pembacaan', r)
                .text =
            '599.9${r % 2 == 0 ? 7 : 5}';
      }

      for (var r = 0; r < 3; r++) {
        isian
                .titikUntukBaris(isian.barisTabel(paralelisme), 0, paralelisme)!
                .kotak(paralelisme.kunciTabel, 'pembacaan', r)
                .text =
            '0.00$r';
      }

      final kiriman = isian.toSubmission(draft: true);
      final blok =
          kiriman.spesifikasiAlat['height_gauge'] as Map<String, dynamic>;

      // Bentuk yang diratakan `CalibrationRequest::bakukanBlokHeightGauge()` di
      // server. Kalau bentuknya berubah di sini, penerjemah di sana harus ikut.
      final isiEval = ((blok['pra_evaluasi'] as Map)['baris'] as List)
          .cast<Map<String, dynamic>>();
      final isiParalel = ((blok['paralelisme'] as Map)['baris'] as List)
          .cast<Map<String, dynamic>>();

      expect(isiEval, hasLength(1));
      expect(isiEval[0]['pembacaan'], hasLength(10));
      expect((isiEval[0]['pembacaan'] as List)[0], 599.97);

      expect(isiParalel, hasLength(1));
      expect(isiParalel[0]['pembacaan'], hasLength(3));
      expect((isiParalel[0]['pembacaan'] as List)[2], 0.002);

      // Dan KEDUANYA tidak ikut jadi titik kalibrasi — nominal terkecil lembar
      // ini 25,0, jadi titik ber-`titik_ukur` 1,0 cuma bisa lahir dari salah
      // satu blok sesi yang nyasar.
      expect(
        kiriman.measurements.map((m) => m.titikUkur),
        isNot(contains(1.0)),
        reason:
            'Blok tingkat-SESI jadi titik kalibrasi palsu — dan titik hantu '
            'selalu gagal hitung ulang.',
      );
    });

    test('pembacaan titik terkirim lewat jalur datar `pembacaan`', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final baris = isian.barisTabel(hasil);

      for (var r = 0; r < 3; r++) {
        isian
                .titikUntukBaris(baris, 0, hasil)!
                .kotak(hasil.kunciTabel, 'pembacaan', r)
                .text =
            '24.99';
      }

      final kiriman = isian.toSubmission(draft: true);
      final json = kiriman.measurements.map((m) => m.toJson()).toList();
      final titik1 = json.firstWhere((m) => m['titik_ukur'] == 25.0);

      expect(
        titik1['pembacaan'],
        List.filled(3, 24.99),
        reason:
            'Tabel satu-kolom ini lewat jalur DATAR, sama seperti dua puluh '
            'lima lembar lain. Sisi server yang menengok kosakata `hg_*` di '
            'sini nggak akan pernah menerima satu angka pun — nol baris '
            'tersimpan, nol hitungan, tanpa error di kedua sisi.',
      );
    });
  });
}
