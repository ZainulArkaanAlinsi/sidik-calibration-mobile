import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Nomor Repeat → POSISI kolom, waktu daftarnya bukan `[1, 2, 3, …]`.
///
/// ## Bug yang ditutup berkas ini
///
/// `terapkanHasilFotoTabel` dulu memakai `index = repeatNo - 1`. Itu benar
/// cuma selama daftar pengulangannya mulai dari 1 dan berurutan — dan
/// daftarnya datang dari SERVER (`json['pengulangan']`), bukan dari sini.
///
/// Semua lembar yang ada sekarang kebetulan `[1, 2, 3, 4, 5]`, jadi salahnya
/// nggak pernah kelihatan. Yang bikin ini mahal justru itu: kelas bug ini
/// muncul pertama kali di lembar BARU yang nggak ada hubungannya dengan foto,
/// lama sesudah orang yang menulis kodenya lupa jalur ini ada.
///
/// Akibatnya sunyi total. Nggak ada error, tabelnya penuh, angkanya wajar —
/// cuma tiap angka duduk di kolom Repeat yang salah. Di lembar kalibrasi,
/// angka yang wajar tapi salah kolom jauh lebih berbahaya daripada kolom
/// kosong: yang kosong kelihatan.
///
/// Bentuk bug yang SAMA sudah pernah menggigit `grid_sensor_state.dart` dan
/// diperbaiki di sana. Yang di jalur tabel kelewat.
///
/// Fixture-nya bentuk Viscometer yang beneran dikirim backend, dengan satu
/// hal diubah: daftar pengulangannya. Itu persis yang bisa dilakukan server
/// kapan saja tanpa aplikasinya ikut diubah.
void main() {
  Map<String, dynamic> bentukJson(List<int> pengulangan) {
    final json =
        jsonDecode(
              File(
                'test/fixtures/viscometer-bentuk-hasil.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    for (final b in json['bagian'] as List<dynamic>) {
      for (final t in (b as Map<String, dynamic>)['tabel'] as List<dynamic>) {
        (t as Map<String, dynamic>)['pengulangan'] = pengulangan;
      }
    }

    return json;
  }

  ({LembarKerjaState isian, TabelHasil tabel}) siapkan(List<int> pengulangan) {
    final bentuk = LembarKerja.fromJson(bentukJson(pengulangan));

    final tabel = bentuk.bagian
        .expand((b) => b.tabel)
        .firstWhere((t) => t.tahap == 'sesudah_adjustment');

    return (
      isian: LembarKerjaState(bentuk: bentuk, clientRequestId: 'uji-repeat'),
      tabel: tabel,
    );
  }

  SelTabelFoto sel(double titikUkur, int repeatNo, String teks) => (
    titikUkur: titikUkur,
    repeatNo: repeatNo,
    fieldId: 'pembacaan',
    teks: teks,
  );

  test('pengulangan [2, 4, 6, 8, 10]: Repeat 4 mendarat di kolom KEDUA', () {
    final s = siapkan(const [2, 4, 6, 8, 10]);
    addTearDown(s.isian.dispose);

    final terisi = s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 4, '123,4')],
      tahap: s.tabel.tahap,
      pengulangan: s.tabel.pengulangan,
    );

    expect(terisi, 1, reason: 'Prasyarat: selnya memang keisi.');

    final titik = s.isian.titik[1018.0]!;

    expect(
      titik.kotak('sesudah_adjustment', 'pembacaan', 1).text,
      '123,4',
      reason: 'Repeat 4 itu kolom ke-2 (indeks 1) di daftar [2, 4, 6, 8, 10].',
    );

    expect(
      titik.kotak('sesudah_adjustment', 'pembacaan', 3).text,
      isEmpty,
      reason:
          '`repeatNo - 1` bakal menaruhnya di indeks 3 — kolom milik Repeat 8. '
          'Angkanya wajar, tabelnya penuh, dan seluruhnya salah kolom.',
    );
  });

  test('Repeat pertama daftar itu kolom PERTAMA, apa pun nomornya', () {
    final s = siapkan(const [3, 4, 5, 6, 7]);
    addTearDown(s.isian.dispose);

    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 3, '50,0')],
      tahap: s.tabel.tahap,
      pengulangan: s.tabel.pengulangan,
    );

    expect(
      s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '50,0',
      reason:
          'Repeat 3 nomor pertama di daftarnya, jadi kolomnya yang pertama.',
    );
  });

  test('Repeat yang NGGAK ada di daftar dibuang, bukan dipaksa masuk', () {
    final s = siapkan(const [2, 4, 6, 8, 10]);
    addTearDown(s.isian.dispose);

    final terisi = s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 5, '99,9')],
      tahap: s.tabel.tahap,
      pengulangan: s.tabel.pengulangan,
    );

    expect(terisi, 0, reason: 'Repeat 5 nggak punya kolom di lembar ini.');

    for (var i = 0; i < 5; i++) {
      expect(
        s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', i).text,
        isEmpty,
        reason: 'Nggak boleh nyangkut di kolom mana pun, termasuk indeks 4.',
      );
    }
  });

  test('daftar [1..5] yang biasa: perilakunya NGGAK bergeser', () {
    // Penjaga arah. Semua lembar yang ada sekarang berbentuk begini, dan
    // perbaikan ini nggak boleh mengubah satu pun di antaranya.
    final s = siapkan(const [1, 2, 3, 4, 5]);
    addTearDown(s.isian.dispose);

    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 1, '10,0'), sel(1018.0, 5, '50,0')],
      tahap: s.tabel.tahap,
      pengulangan: s.tabel.pengulangan,
    );

    final titik = s.isian.titik[1018.0]!;

    expect(titik.kotak('sesudah_adjustment', 'pembacaan', 0).text, '10,0');
    expect(titik.kotak('sesudah_adjustment', 'pembacaan', 4).text, '50,0');
  });

  group('titik yang cocoknya cuma dalam toleransi', () {
    // `terapkanHasilFotoTabel` mencari titiknya lewat `_titikTerdekat`, yang
    // menerima selisih sangat kecil (pembulatan `double` dari server, misalnya
    // 1018,0000000001). Pencari label contoh latih HARUS memakai cara yang
    // sama.
    //
    // Lewat `titik[x]` biasa, baris begitu balik kosong: angkanya masuk
    // formulir dengan benar, tapi labelnya nggak pernah ketemu — dan tiap
    // potongan sel dari baris itu dihitung "tanpa label" tanpa ada yang tahu
    // kenapa. Data latihnya menyusut diam-diam, persis di baris yang datanya
    // paling wajar.
    test('`titik[x]` MELESET, `titikCocok` ketemu', () {
      final s = siapkan(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      // Selisihnya di bawah toleransi 1e-6 relatif.
      const geser = 1018.0000000001;

      expect(
        s.isian.titik[geser],
        isNull,
        reason:
            'Prasyarat: pencarian peta biasa memang meleset buat angka ini. '
            'Kalau ini ketemu, test-nya berhenti menguji apa pun.',
      );

      expect(
        s.isian.titikCocok(geser),
        same(s.isian.titik[1018.0]),
        reason: 'Yang dipakai jalur foto ketemu, dan titiknya yang itu juga.',
      );
    });

    test('angka fotonya sendiri tetap mendarat di baris itu', () {
      // Penjaga arah: kalau `terapkanHasilFotoTabel` berhenti menerima titik
      // bertoleransi, test di atas berhenti berarti apa-apa.
      final s = siapkan(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      final terisi = s.isian.terapkanHasilFotoTabel(
        [sel(1018.0000000001, 1, '77,7')],
        tahap: s.tabel.tahap,
        pengulangan: s.tabel.pengulangan,
      );

      expect(terisi, 1);
      expect(
        s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
        '77,7',
      );
    });
  });

  group('label buat contoh latih', () {
    // Celah yang sebelumnya nggak ketutup: pencari labelnya hidup di dalam
    // layar, jadi satu-satunya cara mengujinya memompa seluruh layar. Dan
    // justru di lem inilah bug pertama muncul — pencocokan titik yang beda
    // dari yang dipakai jalur foto.
    //
    // Yang dijaga di sini bukan tombolnya, tapi janji intinya: label yang
    // menempel di potongan sel adalah angka yang AKHIRNYA ada di sel itu.

    ({LembarKerjaState isian, TabelHasil tabel}) terisi(List<int> pengulangan) {
      final s = siapkan(pengulangan);

      s.isian.terapkanHasilFotoTabel(
        [sel(1018.0, pengulangan[1], '123,4')],
        tahap: s.tabel.tahap,
        pengulangan: s.tabel.pengulangan,
      );

      return s;
    }

    test('labelnya angka yang ADA di sel itu', () {
      final s = terisi(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 1018.0,
          posisiRepeat: 1,
          fieldId: 'pembacaan',
        ),
        '123,4',
      );
    });

    test('teknisi MENGOREKSI: labelnya yang baru, bukan yang lama', () {
      // Inti seluruh fitur. Angka hasil foto dibetulkan teknisi, dan yang
      // boleh jadi label cuma hasil koreksinya.
      final s = terisi(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 1).text =
          '987,6';

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 1018.0,
          posisiRepeat: 1,
          fieldId: 'pembacaan',
        ),
        '987,6',
      );
    });

    test('titik bertoleransi tetap ketemu labelnya', () {
      // Bug yang ketemu sebelum sempat mendarat: `titik[x]` meleset di sini,
      // dan akibatnya tiap potongan dari baris ini dihitung "tanpa label".
      final s = terisi(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 1018.0000000001,
          posisiRepeat: 1,
          fieldId: 'pembacaan',
        ),
        '123,4',
      );
    });

    test('sel KOSONG balik null, bukan teks kosong yang kelihatan label', () {
      final s = siapkan(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 1018.0,
          posisiRepeat: 0,
          fieldId: 'pembacaan',
        ),
        isEmpty,
        reason:
            'Kotaknya ada tapi kosong — `PenampungContohSel` yang menolaknya '
            'sebagai label, dan itu memang tugasnya.',
      );
    });

    test('posisi di luar jangkauan balik null, bukan meledak', () {
      final s = siapkan(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 1018.0,
          posisiRepeat: 99,
          fieldId: 'pembacaan',
        ),
        isNull,
      );
    });

    test('titik yang nggak ada di lembar balik null', () {
      final s = siapkan(const [1, 2, 3, 4, 5]);
      addTearDown(s.isian.dispose);

      expect(
        s.isian.labelSelFoto(
          tahap: 'sesudah_adjustment',
          titikUkur: 12345.0,
          posisiRepeat: 0,
          fieldId: 'pembacaan',
        ),
        isNull,
      );
    });
  });
}
