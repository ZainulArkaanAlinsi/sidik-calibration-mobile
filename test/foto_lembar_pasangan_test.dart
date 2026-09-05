import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Angka hasil foto mendarat di kotak yang KELIHATAN, juga di lembar
/// berpasangan.
///
/// ## Bug yang ditutup di sini
///
/// Kedua jalur foto mencari barisnya lewat `_titikTerdekat`, yang membaca kunci
/// peta `titik`. Di lembar BERPASANGAN kunci itu POSISI baris (0, 1, 2, …),
/// bukan titik ukurnya — dua deret memang berbagi satu baris. Angka yang datang
/// dari foto selalu titik ukur ASLI (60,0 s; 45,0 °C), jadi pencariannya nggak
/// pernah ketemu.
///
/// Yang terukur sebelum perbaikan, dengan lembar dari fixture server:
///
/// | lembar             | "FOTO TABEL INI" |
/// |--------------------|------------------|
/// | Timer/Stopwatch    | 0 sel terisi     |
/// | Thermohygrometer   | 0 sel terisi     |
/// | Thermocouple       | 0 sel terisi     |
/// | Termometer Gelas   | 0 sel terisi     |
/// | TIDS               | "1 sel terisi", kotaknya tetap kosong |
/// | Centrifuge (datar) | 1 sel terisi (kontrol — memang jalan) |
///
/// TIDS baris terakhir itu yang paling mahal: teknisi diberi tahu fotonya
/// berhasil, `input_method` sesinya jadi `ocr`, dan lembarnya tetap kosong.
void main() {
  LembarKerja bentuk(String kode) => LembarKerja.fromJson(
    jsonDecode(File('test/fixtures/lembar-kerja-$kode.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  List<TabelHasil> tabelDari(LembarKerja b) => [
    for (final bagian in b.bagian) ...bagian.tabel,
  ];

  /// Satu sel hasil foto lokal di baris [titikUkur], Repeat pertama tabelnya.
  SelTabelFoto sel(TabelHasil t, double titikUkur, String teks) => (
    titikUkur: titikUkur,
    repeatNo: t.pengulangan.first,
    fieldId: t.kolom.first.kode,
    teks: teks,
    keyakinan: null,
  );

  /// Titik ukur baris ke-[index] tabel [t] — angka yang dipakai pemeta foto.
  double titikBaris(LembarKerjaState s, TabelHasil t, int index) =>
      s.titik[s.kunciBaris(s.barisTabel(t), index, t)]!.titikUkur;

  group('tombol FOTO TABEL INI', () {
    // Kelima lembar berpasangan + satu lembar datar sebagai kontrol. Kontrolnya
    // bukan basa-basi: kalau dia ikut merah, yang rusak harness test-nya,
    // bukan lembar pasangannya.
    for (final (kode, berpasangan) in const [
      ('timer_stopwatch', true),
      ('thermohygro', true),
      ('thermocouple', true),
      ('thermometer_glass', true),
      ('tids', true),
      ('centrifuge', false),
    ]) {
      test('$kode: angkanya masuk kotak yang digambar', () {
        final b = bentuk(kode);
        final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
        addTearDown(s.dispose);

        final tabel = tabelDari(b).first;
        expect(
          tabel.berpasangan,
          berpasangan,
          reason: 'Prasyarat: bentuk $kode berubah, test ini nggak menguji '
              'apa yang dia kira.',
        );

        final titik = titikBaris(s, tabel, 0);
        final terisi = s.terapkanHasilFotoTabel(
          [sel(tabel, titik, '12,3')],
          tabel: tabel,
        );

        expect(terisi, 1);

        // Kotak yang BENERAN digambar tabel ini — `kunciTabel`, bukan `tahap`.
        final kotak = s.titik[s.kunciBaris(s.barisTabel(tabel), 0, tabel)]!
            .kotak(tabel.kunciTabel, tabel.kolom.first.kode, 0);
        expect(
          kotak.text,
          '12,3',
          reason: 'Jumlah "$terisi sel terisi" boleh benar sementara kotaknya '
              'kosong — itu persis bentuk bug TIDS-nya.',
        );
      });
    }

    test('set point kembar antar-blok mendarat di bloknya sendiri', () {
      // Thermohygrometer punya set point 50 DUA kali: 50 °C di blok suhu dan
      // 50 %RH di blok kelembapan. Pencarian se-lembar bikin angka kelembapan
      // mendarat di baris suhu — bentuknya wajar, tempatnya salah.
      final b = bentuk('thermohygro');
      final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      addTearDown(s.dispose);

      final tabel = tabelDari(b);
      final suhu = tabel.firstWhere((t) => t.grup == 'suhu_standar');
      final rh = tabel.firstWhere((t) => t.grup == 'kelembaban_standar');

      expect(
        s.barisTabel(suhu).map((r) => r.titikUkur),
        contains(50.0),
        reason: 'Prasyarat: 50 harus ada di kedua blok.',
      );
      expect(s.barisTabel(rh).map((r) => r.titikUkur), contains(50.0));

      s.terapkanHasilFotoTabel([sel(rh, 50.0, '49,8')], tabel: rh);

      final barisRh = s.titikBarisTabel(rh, 50.0)!;
      final barisSuhu = s.titikBarisTabel(suhu, 50.0)!;

      expect(barisRh.satuan, '%RH');
      expect(barisRh.kotak(rh.kunciTabel, rh.kolom.first.kode, 0).text, '49,8');
      expect(
        barisSuhu.kotak(suhu.kunciTabel, suhu.kolom.first.kode, 0).text,
        isEmpty,
        reason: 'Angka kelembapan nyasar ke blok suhu.',
      );
    });
  });

  group('pindai lewat server', () {
    // Jalur `PindaiReviewScreen`. Identitas tabel di sisi server `grup ?? tahap`
    // (`TemplateLembarKerja::tabel`); kotak isian di HP dialamati
    // `TabelHasil.kunciTabel`. Buat lembar pasangan keduanya BEDA, dan empat
    // tabel Thermohygro malah `tahap`-nya sama semua.
    SelDipakaiPindai selPindai(TabelHasil t, double titikUkur, double nilai) => (
      tabelId: t.grup ?? t.tahap,
      tahap: t.tahap,
      titikUkur: titikUkur,
      repeatNo: t.pengulangan.first,
      fieldId: t.kolom.first.kode,
      nilai: nilai,
      perluDicek: false,
    );

    test('deret standar & UUT Timer nggak saling menimpa', () {
      final b = bentuk('timer_stopwatch');
      final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      addTearDown(s.dispose);

      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final uut = tabel.firstWhere((t) => t.deretUut);
      final titik = titikBaris(s, standar, 0);

      expect(
        standar.tahap,
        uut.tahap,
        reason: 'Prasyarat: dua tabel ini memang cuma dibedakan `grup`.',
      );

      final terisi = s.terapkanHasilPindai([
        selPindai(standar, titik, 11),
        selPindai(uut, titik, 22),
      ]);

      expect(terisi, 2);

      final baris = s.titikBarisTabel(standar, titik)!;
      expect(baris.kotak(standar.kunciTabel, standar.kolom.first.kode, 0).text,
          '11');
      expect(
          baris.kotak(uut.kunciTabel, uut.kolom.first.kode, 0).text, '22');
    });

    test('nomor Repeat yang nggak mulai dari 1 mendarat di kolom yang benar', () {
      // Kelas bug yang sudah ditutup dua kali di berkas lain
      // (`grid_sensor_state.dart`, lalu `terapkanHasilFotoTabel`): `repeatNo - 1`
      // benar CUMA selama daftarnya [1, 2, 3, …]. Daftarnya datang dari server,
      // jadi lembar pertama yang Repeat-nya loncat bikin tiap angka mendarat di
      // kolom sebelah — tanpa error, dengan tabel yang penuh dan wajar.
      //
      // Belum ada lembar sungguhan yang begitu, jadi fixture-nya digeser di sini
      // — persis supaya lembar begitu nggak lahir dalam keadaan sudah rusak.
      final mentah =
          jsonDecode(
                File(
                  'test/fixtures/lembar-kerja-centrifuge.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      // Cuma bagian "Data Hasil Kalibrasi" yang punya `tabel`; empat bagian
      // lainnya isinya field identitas.
      for (final bagian in mentah['bagian'] as List<dynamic>) {
        final tabel = (bagian as Map<String, dynamic>)['tabel'];
        if (tabel is! List<dynamic>) continue;

        for (final t in tabel) {
          (t as Map<String, dynamic>)['pengulangan'] = [2, 4, 6];
        }
      }

      final b = LembarKerja.fromJson(mentah);
      final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      addTearDown(s.dispose);

      final tabel = tabelDari(b).first;
      expect(tabel.pengulangan, [2, 4, 6]);

      final titik = titikBaris(s, tabel, 0);
      final kolom = tabel.kolom.first.kode;

      // Repeat 6 = kolom KETIGA (index 2). Lewat `repeatNo - 1` dia jadi
      // index 5 — di luar jangkauan, jadi selnya dibuang diam-diam.
      final terisi = s.terapkanHasilPindai([
        (
          tabelId: tabel.grup ?? tabel.tahap,
          tahap: tabel.tahap,
          titikUkur: titik,
          repeatNo: 6,
          fieldId: kolom,
          nilai: 1234,
          perluDicek: false,
        ),
      ]);

      expect(terisi, 1);

      final baris = s.titikBarisTabel(tabel, titik)!;
      expect(baris.kotak(tabel.kunciTabel, kolom, 2).text, isNotEmpty);
      expect(baris.kotak(tabel.kunciTabel, kolom, 0).text, isEmpty);
    });

    test('respons server lama (tanpa tabel_id) tetap jalan di lembar datar', () {
      // Gerbang mundurnya: `tabel_id` kosong = balik ke perilaku lama, dan di
      // lembar satu-tahap `tahap` memang alamat kotak yang benar.
      final b = bentuk('centrifuge');
      final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      addTearDown(s.dispose);

      final tabel = tabelDari(b).first;
      final titik = titikBaris(s, tabel, 0);

      final terisi = s.terapkanHasilPindai([
        (
          tabelId: '',
          tahap: tabel.tahap,
          titikUkur: titik,
          repeatNo: tabel.pengulangan.first,
          fieldId: tabel.kolom.first.kode,
          nilai: 1234,
          perluDicek: false,
        ),
      ]);

      expect(terisi, 1);
      expect(
        s.titik[titik]!.kotak(tabel.kunciTabel, tabel.kolom.first.kode, 0).text,
        isNotEmpty,
      );
    });
  });
}
