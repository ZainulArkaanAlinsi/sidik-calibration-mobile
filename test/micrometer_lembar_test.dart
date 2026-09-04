import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_panjang.dart';

/// **Lembar Micrometer: dari kotak di layar sampai kunci di payload.**
///
/// ## Kenapa berkas ini ada
///
/// Lembar ke-25 ini punya satu hal yang nggak dipunyai dua puluh empat lembar
/// sebelumnya: tabel `hasil`-nya **baris-TERKUNCI**. Sebelas nominal balok
/// ukurnya sudah tercetak di kertas (`SIDIK-FM-CAL-0522.{A,B,C,D}_Rev.1`) dan
/// ditentukan Instruksi Kerja — teknisi cuma mengisi pembacaannya.
///
/// Tiap satu dari empat hal di bawah **nggak menghasilkan error** waktu salah,
/// dan tiga di antaranya kelasnya sudah pernah menggigit lembar lain:
///
///  1. **Nominal pra-cetak yang kegambar sebagai kotak isian.** Server memakai
///     nominal VARIAN, bukan yang dikirim HP — jadi angka yang diketik ulang
///     teknisi hilang tanpa jejak, dan yang tercetak di sertifikat beda dari
///     yang dia lihat di layar.
///  2. **Dua tabel ber-`tahap` sama yang berbagi kotak isian.** `hasil` dan
///     `evaluasi` dua-duanya `sesudah_adjustment` tanpa `peran`, jadi
///     `kunciTabel` keduanya sama. Kelas yang sama sudah menggigit
///     Thermohygrometer dan Timbangan.
///  3. **Baris Evaluasi yang nyasar ke `measurements`.** Dia besaran
///     tingkat-SESI; lewat `measurements[]` dia jadi titik kalibrasi palsu yang
///     selalu gagal hitung ulang.
///  4. **Bentuk blok Evaluasi yang nggak dikenali server.** HP mengirimnya
///     sebagai cerminan tabel (`{baris: [{titik_ukur, pembacaan: [...]}]}`), bukan
///     larik datar. Server meratakannya di
///     `CalibrationRequest::bakukanPraEvaluasiMicrometer()`; test ini yang
///     memastikan bentuk yang dikirim HP memang bentuk itu.
void main() {
  /// Alat contoh `ZQ-100` — persis yang dipakai bentuk mock ini (Micrometer
  /// Digital Mitutoyo IP65, kapasitas 50 mm, resolusi 0,001 mm), jadi
  /// variannya B dan nominal pra-cetaknya 25,0 … 50,0 mm.
  LembarKerjaState buatIsian() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaMicrometer()),
      clientRequestId: 'uji-micrometer',
    );

    isian.alat = const EquipmentLookup(
      id: 25,
      namaAlat: 'Micrometer Digital',
      serialNumber: 'ZQ-100',
      kategori: 'panjang',
      status: 'aktif',
      satuan: 'mm',
      rangeMax: 50,
      resolusi: 0.001,
    );

    return isian;
  }

  TabelHasil tabelBagian(LembarKerjaState isian, String kode) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == kode).tabel.first;

  group('bentuk lembarnya sendiri', () {
    test('kebaca utuh — enam blok, dua tabel, nol baris hilang', () {
      final isian = buatIsian();

      expect(
        isian.bentuk.judul,
        'Calibration Work Sheet - Micrometer (25-50 mm)',
      );

      final kode = isian.bentuk.bagian.map((b) => b.kode).toList();
      expect(kode, [
        'identitas_alat',
        'pemilik',
        'usage_check',
        'hasil',
        'evaluasi',
        'penutup',
      ]);

      // Sebelas titik & satu baris Evaluasi — bukan nol. Lembar yang terbuka
      // dengan nol baris itu pelajaran K18 dari TIDS.
      expect(tabelBagian(isian, 'hasil').baris, hasLength(11));
      expect(tabelBagian(isian, 'evaluasi').baris, hasLength(1));

      // Lima pembacaan tiap titik, sepuluh di baris Evaluasi.
      expect(tabelBagian(isian, 'hasil').pengulangan, hasLength(5));
      expect(tabelBagian(isian, 'evaluasi').pengulangan, hasLength(10));
    });

    test('nominal balok ukur SUDAH terisi dan nggak bisa diubah', () {
      final isian = buatIsian();
      final hasil = tabelBagian(isian, 'hasil');

      // Kalau ini `true`, HP menggambar kotak `titik_ukur` yang bisa diketik —
      // dan angka yang diketik teknisi tetap kalah di server, tanpa error.
      expect(
        hasil.titikBisaDiubah,
        isFalse,
        reason:
            'Nominalnya dipatok kertas per rentang; tumpukan keping yang '
            'membentuknya ditentukan Instruksi Kerja, bukan dipilih di lapangan.',
      );

      // Sebelas nominal varian B, apa adanya dari kertas. Titik 3 memang 31,0
      // dan bukan 32,9 — yang menentukan nominal itu tumpukan keping yang
      // tersedia, bukan deret aritmetika. Sudah diadu ke master: 30,99997 mm.
      expect(isian.barisTabel(hasil).map((b) => b.titikUkur).toList(), [
        25.0,
        27.5,
        31.0,
        32.7,
        35.3,
        37.9,
        40.0,
        42.6,
        45.2,
        47.8,
        50.0,
      ]);
    });

    test('baris Evaluasi nggak ikut pengatur titik yang dipakai bersama', () {
      final isian = buatIsian();

      // `titikKustom` itu SATU daftar buat seluruh lembar. Dua tabel yang
      // daftar titiknya beda nggak bisa dua-duanya ikut.
      expect(tabelBagian(isian, 'evaluasi').titikBisaDiubah, isFalse);
      expect(isian.titikBisaDiubah, isFalse);
    });
  });

  group('kunci baris nggak bentrok antar tabel', () {
    test('`hasil` dan `evaluasi` beda kotak walau tahapnya sama', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final evaluasi = tabelBagian(isian, 'evaluasi');

      // Bentroknya BUKAN teoretis: kunci tabel keduanya sama persis, karena
      // `peran` null bikin `kunciTabel` jatuh ke `tahap`.
      expect(hasil.kunciTabel, evaluasi.kunciTabel);
      expect(hasil.kunciTabel, 'sesudah_adjustment');

      // Yang memisahkannya `offset_kunci` di tabel Evaluasi.
      expect(evaluasi.offsetKunci, isNotNull);

      final barisHasil = isian.barisTabel(hasil);
      final barisEval = isian.barisTabel(evaluasi);

      final kunciHasil = [
        for (var i = 0; i < barisHasil.length; i++)
          isian.kunciBaris(barisHasil, i, hasil),
      ];
      final kunciEval = [
        for (var i = 0; i < barisEval.length; i++)
          isian.kunciBaris(barisEval, i, evaluasi),
      ];

      expect(
        kunciHasil.toSet().intersection(kunciEval.toSet()),
        isEmpty,
        reason:
            'Dua tabel berbagi kotak isian: angka yang diketik di salah satunya '
            'muncul di kotak satunya lagi, tanpa error. Di lembar ini akibatnya '
            'lebih mahal — baris Evaluasi yang tertimpa bikin pengulangan lahir '
            'dari angka titik ukur, dan U95 seluruh sesi ikut salah.',
      );
    });

    test('kotaknya beneran terpisah waktu diketik', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final evaluasi = tabelBagian(isian, 'evaluasi');

      final barisHasil = isian.barisTabel(hasil);
      final barisEval = isian.barisTabel(evaluasi);

      isian
              .titikUntukBaris(barisHasil, 0, hasil)!
              .kotak(hasil.kunciTabel, 'pembacaan', 0)
              .text =
          '25.001';

      expect(
        isian
            .titikUntukBaris(barisEval, 0, evaluasi)!
            .kotak(evaluasi.kunciTabel, 'pembacaan', 0)
            .text,
        isEmpty,
        reason: 'Angka tabel hasil bocor ke baris Evaluasi.',
      );
    });
  });

  group('satuan alat', () {
    test('dropdown satuan ditanyakan kalau kosong', () {
      final isian = buatIsian();

      // Bentuk lembar menandainya `wajib: false` — lembar setengah jadi dari
      // lapangan memang boleh dikirim. Yang menjaga teknisi bukan penahan
      // tombol, tapi PERTANYAAN sebelum kirim.
      expect(
        isian.pilihanPenentuAngkaKosong.map((f) => f.kode),
        contains('spesifikasi_alat.micrometer.satuan'),
        reason:
            'Satuan yang kosong nggak bikin titiknya masuk `belum_dihitung` — '
            'server jatuh ke mm. Jadi mikrometer inch yang satuannya kelupaan '
            'menghitung mulus, terbit mulus, dan salah 25,4×.',
      );
    });

    test('sudah dipilih → nggak ditanya lagi', () {
      final isian = buatIsian();

      isian.teks['spesifikasi_alat.micrometer.satuan']!.text = 'inch';

      expect(
        isian.pilihanPenentuAngkaKosong.map((f) => f.kode),
        isNot(contains('spesifikasi_alat.micrometer.satuan')),
      );
    });
  });

  group('payload', () {
    test('baris Evaluasi masuk spesifikasi_alat, bukan measurements', () {
      final isian = buatIsian();

      final evaluasi = tabelBagian(isian, 'evaluasi');
      final baris = isian.barisTabel(evaluasi);

      for (var r = 0; r < 10; r++) {
        isian
                .titikUntukBaris(baris, 0, evaluasi)!
                .kotak(evaluasi.kunciTabel, 'pembacaan', r)
                .text =
            '50.00${r % 2}';
      }

      final kiriman = isian.toSubmission(draft: true);

      // Bentuk yang diratakan `CalibrationRequest::bakukanPraEvaluasiMicrometer()`
      // di server. Kalau bentuknya berubah di sini, penerjemah di sana harus
      // ikut — dan yang mengunci keduanya test ini plus
      // `MicrometerSesiTest::test_baris_evaluasi_bentuk_tabel_hp_diterima_dan_dikonversi`.
      final mikro =
          kiriman.spesifikasiAlat['micrometer'] as Map<String, dynamic>;
      final blok = mikro['pra_evaluasi'] as Map;
      final isi = (blok['baris'] as List).cast<Map<String, dynamic>>();

      expect(isi, hasLength(1));
      expect(isi[0]['pembacaan'], hasLength(10));
      expect((isi[0]['pembacaan'] as List)[0], 50.0);
      expect((isi[0]['pembacaan'] as List)[1], 50.001);

      // Dan dia TIDAK ikut jadi titik kalibrasi.
      expect(
        kiriman.measurements.map((m) => m.titikUkur),
        isNot(contains(1.0)),
        reason:
            'Baris Evaluasi jadi titik kalibrasi palsu — dia besaran '
            'tingkat-SESI, bukan titik ukur.',
      );
    });

    test('pembacaan titik terkirim lewat jalur datar `pembacaan`', () {
      final isian = buatIsian();

      final hasil = tabelBagian(isian, 'hasil');
      final baris = isian.barisTabel(hasil);

      for (var r = 0; r < 5; r++) {
        isian
                .titikUntukBaris(baris, 0, hasil)!
                .kotak(hasil.kunciTabel, 'pembacaan', r)
                .text =
            '25.001';
      }

      final kiriman = isian.toSubmission(draft: true);
      final json = kiriman.measurements.map((m) => m.toJson()).toList();

      final titik1 = json.firstWhere((m) => m['titik_ukur'] == 25.0);

      expect(
        titik1['pembacaan'],
        List.filled(5, 25.001),
        reason:
            'Tabel satu-kolom ini lewat jalur DATAR, sama seperti dua puluh '
            'empat lembar lain. Server sempat menengok `mikro_pembacaan` di '
            'sini dan itu tidak pernah menerima satu angka pun: nol baris '
            'tersimpan, nol hitungan, tanpa error di kedua sisi.',
      );
    });
  });
}
