import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Kamera buat lembar bertabel MATRIKS (Autoklaf).
///
/// ## Kenapa matriksnya butuh jangkar baris yang lain
///
/// Di lembar titik × Repeat, baris dijangkar NILAI standar yang tercetak di
/// kolom kiri. Matriks Autoklaf nggak punya itu: barisnya BESARAN yang
/// berbeda-beda (`Temp. Disk 1`, `Indikator Pressure`, `Suhu Ruang`), dan
/// `titik_ukur` kedelapannya **nol semua** di bentuk yang dikirim backend.
///
/// Dipakai apa adanya, kedelapan baris berbagi satu penanda — dan
/// [PetaTabelFoto] menolak seluruh tabel yang penanda barisnya kembar. Dengan
/// benar: angkanya memang nggak bisa dipastikan masuk baris yang mana.
///
/// Jadi tiap baris diberi penanda karangan, dan yang beneran menjangkarnya
/// TULISAN di kolom kiri. Yang dijaga berkas ini satu hal yang sudah pernah
/// kejadian (20 Agu 2026, waktu Autoklaf sempat dipaksa masuk bentuk lembar
/// pH): **bacaan manometer mendarat di kolom suhu**, tanpa satu pun error, dan
/// jalan terus sampai sertifikat.
void main() {
  const xLabel = 60.0;
  const lebarKolom = 260.0;
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 12, 22),
    keyakinan: keyakinan,
  );

  double xKolom(int k) => 420.0 + k * lebarKolom;

  /// Bentuk lembar seperti yang dikirim `AutoclaveProfile` — disusun lewat
  /// parser aslinya, bukan objek yang dirakit tangan: yang diuji di sini justru
  /// jalur yang dilewati bentuk dari server.
  Map<String, dynamic> bentukJson() => {
    'judul': 'Autoclave',
    'satuan': '°C',
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'Calibration Result',
        'field': [],
        'matriks': {
          'judul_kolom': 'Pengukuran Berulang UUT Selama Proses Sterilisasi',
          'titik_waktu': [1, 2, 3, 4, 5],
          'baris_waktu': {
            'kode': 'waktu',
            'label': 'Time',
            'tipe': 'jam',
            'kode_data': 'waktu',
            'format': 'HH:mm:ss',
          },
          'baris': [
            {
              'kode': 'disk_1',
              'label': 'Temp. Disk 1',
              'tipe': 'disk',
              'satuan': '°C',
              'kode_data': 'suhu.disk.0',
            },
            {
              'kode': 'disk_2',
              'label': 'Temp. Disk 2',
              'tipe': 'disk',
              'satuan': '°C',
              'kode_data': 'suhu.disk.1',
            },
            {
              'kode': 'indikator_suhu',
              'label': 'Indikator Suhu',
              'tipe': 'indikator_suhu',
              'satuan': '°C',
              'kode_data': 'suhu.indikator',
            },
            {
              'kode': 'indikator_pressure',
              'label': 'Indikator Pressure',
              'tipe': 'indikator_tekanan',
              'satuan': 'bar',
              'kode_data': 'tekanan.indikator',
            },
          ],
        },
      },
    ],
  };

  MatriksHasil matriks() =>
      LembarKerja.fromJson(bentukJson()).bagian.single.matriks!;

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(bentukJson()),
    clientRequestId: 'uji-foto-matriks',
  );

  /// Angka yang beda tiap sel — kalau satu baris ketuker sama tetangganya,
  /// ketahuannya dari NILAINYA. Jumlah selnya sendiri tetap pas waktu ketuker,
  /// jadi menghitung sel doang nggak pernah menangkap kegagalan ini.
  String bacaan(int baris, int kolom) => '${baris + 1}${kolom + 1}0,5';

  /// Jam di baris `Time` — sengaja bukan angka polos: dia nggak boleh dibaca
  /// sebagai pembacaan, dan barisnya nggak boleh keisi dari foto.
  String jam(int kolom) => '0${kolom + 1}:30:00';

  List<TeksTerbaca> fotoMatriks({Set<String> hilang = const {}}) {
    final m = matriks();
    final hasil = <TeksTerbaca>[
      for (var k = 0; k < m.titikWaktu.length; k++)
        kata('${m.titikWaktu[k]}', xKolom(k), yKepala),
    ];

    for (var b = 0; b < m.semuaBaris.length; b++) {
      final y = yBarisPertama + b * tinggiBaris;
      final label = m.semuaBaris[b].label;

      if (!hilang.contains(label)) {
        // Nama besaran itu DUA-TIGA kata, dan ML Kit memulangkannya per kata.
        var x = xLabel;

        for (final potong in label.split(' ')) {
          hasil.add(kata(potong, x, y));
          x += potong.length * 12 + 5;
        }
      }

      for (var k = 0; k < m.titikWaktu.length; k++) {
        hasil.add(kata(b == 0 ? jam(k) : bacaan(b - 1, k), xKolom(k), y));
      }
    }

    return hasil;
  }

  HasilPetaTabel petakan(MatriksHasil m, List<TeksTerbaca> terbaca) {
    final penanda = m.penandaBarisFoto();

    return const PetaTabelFoto().petakan(
      terbaca: terbaca,
      titikUkur: penanda.penanda,
      pengulangan: m.titikWaktu,
      fieldPerRepeat: const ['pembacaan'],
      labelTercetak: penanda.label,
    );
  }

  test('tiap besaran dijangkar TULISANNYA, bukan urutan barisnya', () {
    final m = matriks();
    final hasil = petakan(m, fotoMatriks());

    expect(
      hasil.titikKetemu.length,
      m.semuaBaris.length,
      reason: 'kelima baris (termasuk Time) wajib kejangkar',
    );
  });

  test('bacaan manometer nggak pernah mendarat di kolom suhu', () {
    final m = matriks();
    final isian = isianBaru();
    addTearDown(isian.dispose);

    final terisi = isian.terapkanHasilFotoMatriks(
      m,
      petakan(m, fotoMatriks()).sel,
    );

    expect(terisi, 20, reason: '4 besaran × 5 titik waktu — `Time` nggak ikut');

    for (var b = 0; b < m.baris.length; b++) {
      for (var k = 0; k < m.titikWaktu.length; k++) {
        expect(
          isian.kotakMatriks(m.baris[b].kodeData, m.titikWaktu[k]).text,
          bacaan(b, k),
          reason:
              '${m.baris[b].label} titik waktu ${m.titikWaktu[k]} salah isi',
        );
      }
    }
  });

  test('baris `Time` nggak pernah keisi dari foto', () {
    // Isinya jam, bukan hasil ukur. Dia tetap ikut sebagai JANGKAR supaya angka
    // yang jatuh di barisnya diklaim lalu dibuang — bukan melayang ke baris
    // `Temp. Disk 1` di bawahnya.
    final m = matriks();
    final isian = isianBaru();
    addTearDown(isian.dispose);

    isian.terapkanHasilFotoMatriks(m, petakan(m, fotoMatriks()).sel);

    for (final t in m.titikWaktu) {
      expect(isian.kotakMatriks('waktu', t).text, isEmpty);
    }
  });

  test(
    'baris yang namanya nggak kebaca nggak keisi, dan nggak nyedot tetangga',
    () {
      final m = matriks();
      final isian = isianBaru();
      addTearDown(isian.dispose);

      final hasil = petakan(
        m,
        fotoMatriks(hilang: const {'Indikator Pressure'}),
      );
      isian.terapkanHasilFotoMatriks(m, hasil.sel);

      for (final t in m.titikWaktu) {
        expect(isian.kotakMatriks('tekanan.indikator', t).text, isEmpty);
      }

      // Yang kejangkar tetap bawa angkanya sendiri.
      for (var k = 0; k < m.titikWaktu.length; k++) {
        expect(
          isian.kotakMatriks('suhu.indikator', m.titikWaktu[k]).text,
          bacaan(2, k),
        );
      }

      expect(
        hasil.angkaTakTerpetakan,
        greaterThan(0),
        reason: 'yang kebuang dilaporkan, bukan hilang diam-diam',
      );
    },
  );

  test('sel yang sudah diketik nggak ditimpa, dan sel dari foto ditandai', () {
    final m = matriks();
    final isian = isianBaru();
    addTearDown(isian.dispose);

    isian.kotakMatriks('suhu.disk.0', 3).text = '999,9';

    isian.terapkanHasilFotoMatriks(m, petakan(m, fotoMatriks()).sel);

    expect(isian.kotakMatriks('suhu.disk.0', 3).text, '999,9');
    expect(
      isian.matriksDariFoto.contains(
        LembarKerjaState.kunciMatriks('suhu.disk.0', 3),
      ),
      isFalse,
    );
    expect(
      isian.matriksDariFoto.contains(
        LembarKerjaState.kunciMatriks('suhu.disk.0', 1),
      ),
      isTrue,
    );
  });

  group('label buat contoh latih matriks', () {
    // Pengumpul data latih perlu membaca angka FINAL satu sel buat dipasangkan
    // dengan potongan citranya. Alamat sel matriks beda dari lembar bertabel:
    // barisnya BESARAN (`suhu.disk.0`), bukan titik ukur, dan penanda barisnya
    // karangan (`MatriksHasil.kunciBarisFoto`).
    //
    // Yang dijaga: pencari label dan pengisi formulir memakai penerjemahan
    // yang SAMA. Kalau berselisih, labelnya menempel di potongan sel yang
    // salah — dan di data latih, salah alamat nggak pernah kelihatan.

    test('labelnya angka yang beneran ada di sel itu', () {
      final m = matriks();
      final isian = isianBaru();
      addTearDown(isian.dispose);

      isian.terapkanHasilFotoMatriks(m, petakan(m, fotoMatriks()).sel);

      // Penanda barisnya diindeks ke `semuaBaris` — yang termasuk baris
      // `Time` — bukan ke `baris`. Salah indeks di sini bikin testnya
      // menguji baris yang bukan miliknya.
      for (var b = 0; b < m.baris.length; b++) {
        final penanda = MatriksHasil.kunciBarisFoto(
          m.semuaBaris.indexOf(m.baris[b]),
        );

        for (var k = 0; k < m.titikWaktu.length; k++) {
          expect(
            isian.labelSelMatriks(m, penanda, m.titikWaktu[k]),
            bacaan(b, k),
            reason: '${m.baris[b].label} titik waktu ${m.titikWaktu[k]}',
          );
        }
      }
    });

    test('teknisi MENGOREKSI: labelnya yang baru', () {
      // Inti fiturnya. Angka hasil foto dibetulkan teknisi, dan yang boleh
      // jadi label cuma hasil koreksinya.
      final m = matriks();
      final isian = isianBaru();
      addTearDown(isian.dispose);

      isian.terapkanHasilFotoMatriks(m, petakan(m, fotoMatriks()).sel);
      isian.kotakMatriks(m.baris[0].kodeData, m.titikWaktu[0]).text = '999,9';

      expect(
        isian.labelSelMatriks(
          m,
          MatriksHasil.kunciBarisFoto(m.semuaBaris.indexOf(m.baris[0])),
          m.titikWaktu[0],
        ),
        '999,9',
      );
    });

    test('titik waktu yang nggak ada di lembar balik null', () {
      final m = matriks();
      final isian = isianBaru();
      addTearDown(isian.dispose);

      expect(
        isian.labelSelMatriks(
          m,
          MatriksHasil.kunciBarisFoto(m.semuaBaris.indexOf(m.baris[0])),
          9999,
        ),
        isNull,
      );
    });

    test('penanda baris yang nggak ada balik null, bukan meledak', () {
      final m = matriks();
      final isian = isianBaru();
      addTearDown(isian.dispose);

      expect(isian.labelSelMatriks(m, -1, m.titikWaktu[0]), isNull);
    });
  });
}
