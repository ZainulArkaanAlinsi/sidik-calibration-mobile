import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/golongan_rentang.dart';
import 'package:sidik_calibration/models/category.dart';

/// Perangkum rentang master PT Sidik buat isian otomatis form Tambah Alat.
///
/// Yang dijaga di sini SATU hal, dan taruhannya bukan kenyamanan: baris
/// kemampuan satu nama alat boleh punya SATUAN yang beda-beda, dan menggabung
/// rentangnya lintas satuan menghasilkan angka yang SALAH — bukan angka yang
/// kurang teliti. Angka itu nggak ditolak siapa pun: dia masuk ke kolom
/// `range_min`/`range_max` alat, ikut ke lembar kerja, dan ikut ke sertifikat.
void main() {
  CalibrationCapability c(
    String nama, {
    String? parameter,
    double? min,
    double? maks,
    String? satuan,
    String? catatan,
  }) => CalibrationCapability(
    namaAlat: nama,
    parameter: parameter,
    rangeMin: min,
    rangeMax: maks,
    satuan: satuan,
    rangeNote: catatan,
  );

  group('satu satuan → satu golongan, rentangnya digabung', () {
    test('Thermocouple: 3 golongan CMC nyambung jadi -20-600 °C', () {
      final g = golonganRentangDari([
        c('Thermocouple', min: -20, maks: 150, satuan: '°C'),
        c('Thermocouple', min: 150, maks: 400, satuan: '°C'),
        c('Thermocouple', min: 400, maks: 600, satuan: '°C'),
      ]);

      expect(g, hasLength(1));
      expect(g.single.min, -20);
      expect(g.single.maks, 600);
      expect(g.single.satuan, '°C');
      // Rentangnya dipecah per golongan KETIDAKPASTIAN, bukan per besaran —
      // parameternya kosong semua, jadi labelnya nggak ngaku-ngaku punya nama.
      expect(g.single.parameter, isNull);
    });

    test('Termometer Gelas: 0-100 + 100-200 jadi 0-200 °C', () {
      final g = golonganRentangDari([
        c('Termometer Gelas', min: 0, maks: 100, satuan: '°C'),
        c('Termometer Gelas', min: 100, maks: 200, satuan: '°C'),
      ]);

      expect(g.single.min, 0);
      expect(g.single.maks, 200);
    });

    test('parameter yang SAMA di semua baris ikut kebawa', () {
      final g = golonganRentangDari([
        c('X', parameter: 'Suhu', min: 0, maks: 10, satuan: '°C'),
        c('X', parameter: 'Suhu', min: 10, maks: 20, satuan: '°C'),
      ]);

      expect(g.single.parameter, 'Suhu');
    });

    test('parameter yang BEDA di satu golongan dibuang, bukan dipilih satu', () {
      // Mesin UTM golongan kN: `Tekan` DAN `Tarik`. Dua-duanya beneran kN jadi
      // rentangnya sah digabung — tapi namanya nggak boleh dipilih salah satu,
      // itu bakal jadi label yang bohong.
      final g = golonganRentangDari([
        c('Mesin UTM', parameter: 'Tekan', min: 10, maks: 88, satuan: 'kN'),
        c('Mesin UTM', parameter: 'Tarik', min: 200, maks: 3000, satuan: 'kN'),
      ]);

      expect(g.single.parameter, isNull);
      expect(g.single.min, 10);
      expect(g.single.maks, 3000);
    });
  });

  group('satuan beda → golongan TERPISAH, ini inti perangkumnya', () {
    test('Thermohygrometer: °C dan %RH nggak boleh jadi 15-90', () {
      final g = golonganRentangDari([
        c('Thermohygrometer', parameter: 'Suhu', min: 15, maks: 50, satuan: '°C'),
        c(
          'Thermohygrometer',
          parameter: 'Kelembapan',
          min: 30,
          maks: 90,
          satuan: '%RH',
        ),
      ]);

      expect(g, hasLength(2));
      expect(g[0].satuan, '°C');
      expect(g[0].parameter, 'Suhu');
      expect(g[0].min, 15);
      expect(g[0].maks, 50);
      expect(g[1].satuan, '%RH');
      expect(g[1].parameter, 'Kelembapan');
      expect(g[1].min, 30);
      expect(g[1].maks, 90);
      // Angka gabungan (15-90, satuan campur) yang mesti NGGAK pernah lahir.
      expect(g.any((x) => x.min == 15 && x.maks == 90), isFalse);
    });

    test('Autoklaf: suhu 105-121 °C lawan tekanan 0-4 bar', () {
      final g = golonganRentangDari([
        c('Autoklaf', parameter: 'Suhu', min: 105, maks: 121, satuan: '°C'),
        c('Autoklaf', parameter: 'Tekanan', min: 0, maks: 4, satuan: 'bar'),
      ]);

      expect(g, hasLength(2));
      expect(g.any((x) => x.min == 0 && x.maks == 121), isFalse);
    });

    test('urutan golongan ikut urutan server, bukan diurut ulang', () {
      // Suhu duluan di lampiran akreditasi, dan itu yang utama buat teknisi —
      // kalau diurut abjad, `%RH` yang nongol duluan.
      final g = golonganRentangDari([
        c('Thermohygrometer', parameter: 'Suhu', min: 15, maks: 50, satuan: '°C'),
        c('Thermohygrometer', parameter: 'Kelembapan', min: 30, maks: 90, satuan: '%RH'),
      ]);

      expect(g.map((x) => x.satuan).toList(), ['°C', '%RH']);
    });
  });

  group('batas yang bukan angka', () {
    test('Oven: `range_min` kosong nggak jadi nol', () {
      // Nol itu SUHU. "ambient" bukan nol — dan kalau dia dibaca nol, rentang
      // alatnya berubah jadi 0-300 °C di sertifikat.
      final g = golonganRentangDari([
        c('Oven', maks: 300, satuan: '°C', catatan: 'ambient s/d 300 °C'),
      ]);

      expect(g.single.min, isNull);
      expect(g.single.minTeks, '');
      expect(g.single.maks, 300);
      expect(g.single.catatan, 'ambient s/d 300 °C');
    });

    test('golongan tanpa angka sama sekali nggak ditawarin', () {
      // Nama alat yang ditambah teknisi sendiri: cuma punya nama.
      final g = golonganRentangDari([c('Alat Baru Teknisi')]);
      expect(g, isEmpty);
    });
  });

  group('teks buat kotak isian', () {
    test('nol di belakang dibuang: -20, bukan -20.0', () {
      final g = golonganRentangDari([
        c('Thermocouple', min: -20, maks: 600, satuan: '°C'),
      ]);

      expect(g.single.minTeks, '-20');
      expect(g.single.maksTeks, '600');
    });

    test('desimal master dipertahankan apa adanya', () {
      final g = golonganRentangDari([
        c('Refractometer', min: 1.3366, maks: 1.3999, satuan: 'n20D'),
      ]);

      expect(g.single.minTeks, '1.3366');
      expect(g.single.maksTeks, '1.3999');
    });
  });
}
