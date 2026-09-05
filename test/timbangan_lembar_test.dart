import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_massa.dart';

/// **Lembar Timbangan: dari kotak di layar sampai kunci di payload.**
///
/// ## Kenapa berkas ini ada
///
/// Lembar ke-21 ini punya bentuk yang nggak dipunyai dua puluh lembar
/// sebelumnya: TUJUH blok, dua di antaranya tabel, dan lima besaran
/// tingkat-SESI yang nggak punya `titik_ke` sama sekali. Tiap satu dari lima
/// hal di bawah pernah salah waktu dirangkai, dan **nggak satu pun
/// menghasilkan error** — layarnya penuh, tombol kirimnya jalan, dan yang
/// hilang cuma angkanya.
///
///  1. Kode field bertitik tanpa awalan `spesifikasi_alat.` dibaca HP sebagai
///     kolom TURUNAN: read-only, nggak pernah ikut payload. Tiga puluh sembilan
///     kotak lembar ini pernah begitu.
///  2. Titik di dalam `spesifikasi_alat.*` artinya BERSARANG, bukan bagian dari
///     nama kunci. Dikirim datar, `spesifikasi_alat` (kolom JSON tanpa skema)
///     menerimanya tanpa keluhan dan kalkulatornya membaca nol.
///  3. Baris Accuracy 50 kg & 100 kg BENTROK dengan Middle/Maximum Capacity
///     di tabel sebelahnya. Tanpa `offset_kunci`, empat baris berbagi dua
///     kotak isian.
///  4. Tabel Repeatability isinya BUKAN titik ukur — dia besaran satu per
///     sesi. Lewat `measurements[]`, dia jadi dua titik kalibrasi palsu.
///  5. `titik_bisa_diubah` di HP menggerakkan SATU daftar titik untuk seluruh
///     lembar. Nyala di dua tabel sekaligus, menyusun sepuluh titik Accuracy
///     ikut mengubah tabel Repeatability jadi sepuluh baris.
void main() {
  /// Alat contoh `TB-100` — persis yang dipakai bentuk mock ini (100 kg,
  /// resolusi 0,02 kg). Dipasang karena `toSubmission` butuh `equipment_id`;
  /// tanpa alat, payloadnya nggak bisa disusun sama sekali.
  LembarKerjaState buatIsian() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTimbangan()),
      clientRequestId: 'uji-timbangan',
    );

    isian.alat = const EquipmentLookup(
      id: 21,
      namaAlat: 'Timbangan Bestar TB-100',
      serialNumber: 'TB-100',
      kategori: 'massa',
      status: 'aktif',
      satuan: 'kg',
      rangeMax: 100,
      resolusi: 0.02,
    );

    return isian;
  }

  /// Tabel dengan `kode` bagian tertentu.
  TabelHasil tabelBagian(LembarKerjaState isian, String kode) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == kode).tabel.first;

  group('bentuk lembarnya sendiri', () {
    test('kebaca utuh — tujuh blok, dua tabel, nol baris hilang', () {
      final isian = buatIsian();

      expect(isian.bentuk.judul, 'KALIBRASI MASSA / TIMBANGAN');

      final kode = isian.bentuk.bagian.map((b) => b.kode).toList();
      expect(kode, contains('scale_observation'));
      expect(kode, contains('effect_of_tare'));
      expect(kode, contains('akurasi'));
      expect(kode, contains('keterulangan'));
      expect(kode, contains('eksentrisitas'));
      expect(kode, contains('histeresis'));

      // Sepuluh titik & dua kapasitas — bukan nol. Lembar yang terbuka dengan
      // nol baris itu pelajaran K18 dari TIDS.
      expect(tabelBagian(isian, 'akurasi').baris, hasLength(10));
      expect(tabelBagian(isian, 'keterulangan').baris, hasLength(2));
    });

    test(
      'semua kotak blok bisa diketik — bukan kolom turunan yang read-only',
      () {
        final isian = buatIsian();
        const blok = [
          'scale_observation',
          'effect_of_tare',
          'eksentrisitas',
          'histeresis',
        ];

        for (final kode in blok) {
          final bagian = isian.bentuk.bagian.firstWhere((b) => b.kode == kode);

          expect(bagian.field, isNotEmpty, reason: 'Blok $kode kosong.');

          for (final f in bagian.field) {
            expect(
              f.turunan,
              isFalse,
              reason:
                  'Kotak `${f.kode}` bakal read-only dan isinya nggak pernah '
                  'terkirim. Awalan `spesifikasi_alat.` yang membalikkannya.',
            );
            expect(f.spesifikasiAlat, isTrue, reason: 'Kotak `${f.kode}`.');
          }
        }
      },
    );

    test('Repeatability nggak ikut pengatur titik yang dipakai bersama', () {
      final isian = buatIsian();

      // Accuracy boleh: sepuluh titiknya memang disusun teknisi.
      expect(tabelBagian(isian, 'akurasi').titikBisaDiubah, isTrue);

      // Repeatability TIDAK. Dua-duanya nyala berarti menyusun titik Accuracy
      // ikut mengubah tabel ini jadi sepuluh baris Middle/Maximum yang nggak
      // ada di kertas mana pun — delapan belas kotak keterulangan hilang.
      expect(
        tabelBagian(isian, 'keterulangan').titikBisaDiubah,
        isFalse,
        reason:
            '`titikKustom` itu SATU daftar buat seluruh lembar. Dua tabel yang '
            'daftar titiknya beda nggak bisa dua-duanya ikut.',
      );
    });
  });

  group('kunci baris nggak bentrok antar tabel', () {
    test('Accuracy 50/100 kg dan Middle/Maximum Capacity beda kotak', () {
      final isian = buatIsian();

      final akurasi = tabelBagian(isian, 'akurasi');
      final keterulangan = tabelBagian(isian, 'keterulangan');

      final barisAkurasi = isian.barisTabel(akurasi);
      final barisKet = isian.barisTabel(keterulangan);

      // Bentroknya NYATA, bukan teoretis: alat contoh berkapasitas 100 kg,
      // jadi tangga Accuracy memuat 50 & 100, dan Middle/Maximum juga 50 & 100.
      expect(barisAkurasi[4].titikUkur, 50);
      expect(barisAkurasi[9].titikUkur, 100);
      expect(barisKet[0].titikUkur, 50);
      expect(barisKet[1].titikUkur, 100);

      final kunciAkurasi = [
        for (var i = 0; i < barisAkurasi.length; i++)
          isian.kunciBaris(barisAkurasi, i, akurasi),
      ];
      final kunciKet = [
        for (var i = 0; i < barisKet.length; i++)
          isian.kunciBaris(barisKet, i, keterulangan),
      ];

      expect(
        kunciAkurasi.toSet().intersection(kunciKet.toSet()),
        isEmpty,
        reason:
            'Dua tabel berbagi kotak isian: angka yang diketik di salah satunya '
            'muncul di kotak satunya lagi, tanpa error.',
      );
    });

    test('kotaknya beneran terpisah waktu diketik', () {
      final isian = buatIsian();

      final akurasi = tabelBagian(isian, 'akurasi');
      final keterulangan = tabelBagian(isian, 'keterulangan');

      final barisAkurasi = isian.barisTabel(akurasi);
      final barisKet = isian.barisTabel(keterulangan);

      // Titik akurasi 100 kg, pembacaan berbeban (`m`, kolom ke-2).
      isian
              .titikUntukBaris(barisAkurasi, 9, akurasi)!
              .kotak(akurasi.kunciTabel, 'pembacaan', 1)
              .text =
          '100.02';

      // Maximum Capacity, pengulangan pertama.
      final maks = isian.titikUntukBaris(barisKet, 1, keterulangan)!;

      expect(
        maks.kotak(keterulangan.kunciTabel, 'pembacaan', 0).text,
        isEmpty,
        reason: 'Angka Accuracy bocor ke tabel Repeatability.',
      );
    });
  });

  group('payload', () {
    test('blok bersarang mendarat sebagai objek, bukan kunci bertitik', () {
      final isian = buatIsian();

      isian.teks['spesifikasi_alat.eksentrisitas.beban']!.text = '20';
      isian.teks['spesifikasi_alat.eksentrisitas.baca.center']!.text = '20';
      isian.teks['spesifikasi_alat.eksentrisitas.baca.back']!.text = '20.02';
      isian.teks['spesifikasi_alat.histeresis.baca1.0']!.text = '20';
      isian.teks['spesifikasi_alat.histeresis.baca1.7']!.text = '20';
      isian
              .teks['spesifikasi_alat.scale_observation.sebelum_adjustment.z1']!
              .text =
          '0';
      isian.teks['spesifikasi_alat.resolusi']!.text = '0.02';

      final spek = isian.toSubmission(draft: true).spesifikasiAlat;

      // Kunci datar bertitik itu bentuk yang lolos validasi tanpa keluhan lalu
      // dibaca NOL oleh kalkulatornya — kegagalan paling sunyi di jalur ini.
      expect(spek.keys, isNot(contains('eksentrisitas.beban')));

      expect(spek['eksentrisitas'], isA<Map<String, dynamic>>());
      expect((spek['eksentrisitas'] as Map)['beban'], '20');
      expect(((spek['eksentrisitas'] as Map)['baca'] as Map)['center'], '20');
      expect(((spek['eksentrisitas'] as Map)['baca'] as Map)['back'], '20.02');

      // Segmen angka tetap jadi kunci teks; PHP membaca `{"0":…}` sebagai array
      // berindeks, jadi `$b[0]` di sisi sana tetap benar.
      expect(((spek['histeresis'] as Map)['baca1'] as Map)['0'], '20');
      expect(((spek['histeresis'] as Map)['baca1'] as Map)['7'], '20');

      expect(
        ((spek['scale_observation'] as Map)['sebelum_adjustment'] as Map)['z1'],
        '0',
      );

      // Kunci satu tingkat tetap datar seperti sembilan belas lembar lain.
      expect(spek['resolusi'], '0.02');
    });

    test('tabel Repeatability masuk spesifikasi_alat, bukan measurements', () {
      final isian = buatIsian();

      final keterulangan = tabelBagian(isian, 'keterulangan');
      final baris = isian.barisTabel(keterulangan);

      for (var r = 0; r < 10; r++) {
        isian
                .titikUntukBaris(baris, 0, keterulangan)!
                .kotak(keterulangan.kunciTabel, 'pembacaan', r)
                .text =
            '50.02';
        isian
                .titikUntukBaris(baris, 1, keterulangan)!
                .kotak(keterulangan.kunciTabel, 'zero', r)
                .text =
            '0';
      }

      final kiriman = isian.toSubmission(draft: true);
      final blok = kiriman.spesifikasiAlat['keterulangan'] as Map;
      final isi = (blok['baris'] as List).cast<Map<String, dynamic>>();

      expect(isi, hasLength(2));
      expect(isi[0]['titik_ukur'], 50);
      expect(isi[0]['pembacaan'], List.filled(10, 50.02));
      expect(isi[1]['titik_ukur'], 100);
      expect(isi[1]['zero'], List.filled(10, 0.0));

      // Dua kapasitas itu BUKAN titik kalibrasi. Ikut ke `measurements[]`,
      // sertifikatnya terbit dengan DUA BARIS TITIK TAMBAHAN yang nggak pernah
      // diminta siapa pun — 50 kg & 100 kg, angkanya sah, set point-nya sah,
      // dan nggak ada satu pun error yang menandainya.
      expect(
        kiriman.measurements,
        hasLength(isian.barisTabel(tabelBagian(isian, 'akurasi')).length),
        reason:
            'Jumlah titik terkirim harus sama dengan jumlah baris Accuracy. '
            'Lebih dari itu berarti baris Repeatability ikut nyelinap.',
      );

      // Dan yang 50 kg terkirim itu titik ACCURACY, bukan kapasitas: dia cuma
      // punya empat pembacaan (z, m, m', z'), bukan sepuluh pengulangan.
      final titik50 = kiriman.measurements.firstWhere((m) => m.titikUkur == 50);

      expect(titik50.pembacaan, hasLength(4));
    });

    test('kotak nominal per baris jadi daftar angka di measurements', () {
      final isian = buatIsian();

      final akurasi = tabelBagian(isian, 'akurasi');
      final baris = isian.barisTabel(akurasi);
      final titik = isian.titikUntukBaris(baris, 4, akurasi)!;

      titik.kotakBarisCtl(akurasi.kunciTabel, 'nominal').text = '20+20+10';
      titik.kotak(akurasi.kunciTabel, 'pembacaan', 1).text = '50.02';

      final kiriman = isian.toSubmission(draft: true);
      final baris50 = kiriman.measurements
          .firstWhere((m) => m.titikUkur == 50)
          .toJson();

      expect(baris50['nominal'], [20.0, 20.0, 10.0]);

      // Empat pembacaannya lewat deret generik — urutannya z, m, m', z',
      // dipatok `pengulangan_arah` di bentuknya. Server yang menamai.
      expect((baris50['pembacaan'] as List)[1], 50.02);
    });

    test('koma itu desimal, BUKAN pemisah keping', () {
      // `20,5+10` = dua keping (20,5 kg dan 10 kg). Dibaca sebagai pemisah,
      // dia jadi tiga keping [20, 5, 10] — jumlahnya melar 30,5 jadi 35 dan
      // slot Mass-nya geser semua, tanpa satu pun error.
      expect(pecahDaftarAngka('20,5+10'), [20.5, 10.0]);
      expect(pecahDaftarAngka('20+20+10'), [20.0, 20.0, 10.0]);
      expect(pecahDaftarAngka('20 20 10'), [20.0, 20.0, 10.0]);
      expect(pecahDaftarAngka('200;1802,5'), [200.0, 1802.5]);
      expect(pecahDaftarAngka(''), isEmpty);
      expect(pecahDaftarAngka('abc'), isEmpty);
    });
  });
}
