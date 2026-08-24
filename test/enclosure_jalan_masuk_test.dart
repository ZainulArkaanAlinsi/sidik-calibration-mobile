import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/temperatur_indikator_gerbang_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';

/// JALAN MASUK ke lembar kerja Enclosure — bagian yang bolong, persis kayak
/// yang kejadian di TITS (`tits_jalur_masuk_test.dart`).
///
/// Layar gridnya sendiri sudah jadi & teruji (`enclosure_grid_widget_test`,
/// `enclosure_grid_payload_test`), tapi nggak ada satu pun jalur di aplikasi
/// yang membukanya: kelima nama alat Enclosure belum terdaftar di
/// `_profilKhusus`, dan kategori `suhu-dan-kelembapan` cuma memulangkan TITS.
///
/// Gagalnya TANPA error, dan ke arah yang paling jelek: `profilLembarKerjaUntuk`
/// pulang `null`, lalu pemanggilnya jatuh ke `?? 'ph_meter'` — teknisi yang
/// mau mengkalibrasi Oven dapat formulir pH tiga titik 4/7/10, dan angkanya
/// tetap masuk.
void main() {
  group('nama alat → profil lembar kerja', () {
    test('kelima jenis enclosure kenal, dan kodenya BEDA-BEDA', () {
      // Bukan satu kode `enclosure`: tiap jenis punya CMC sendiri di lampiran
      // akreditasi, dan CMC itu yang jadi lantai U95 yang tercetak.
      expect(profilLembarKerjaUntuk('Oven'), 'oven');
      expect(profilLembarKerjaUntuk('Furnace'), 'furnace');
      expect(profilLembarKerjaUntuk('Bath'), 'bath');
      expect(profilLembarKerjaUntuk('Inkubator'), 'inkubator');
      expect(profilLembarKerjaUntuk('Refrigerator'), 'refrigerator');
    });

    test('ejaan Inggris "Incubator" ikut kenal', () {
      // Lampiran akreditasi nulis "Inkubator" (Indonesia), tapi badan alatnya
      // hampir selalu tercetak "Incubator".
      expect(profilLembarKerjaUntuk('Incubator'), 'inkubator');
    });

    test('nempel di tengah nama alat pelanggan tetap kena', () {
      // Yang sampai ke picker itu nama dari lampiran, tapi jalur riwayat
      // memakai nama alat PELANGGAN — dan di situ jenisnya biasanya cuma
      // sebagian dari nama panjang.
      expect(profilLembarKerjaUntuk('Memmert Universal Oven UN55'), 'oven');
      expect(profilLembarKerjaUntuk('Water Bath Memmert WNB 14'), 'bath');
      expect(profilLembarKerjaUntuk('  MUFFLE   FURNACE  '), 'furnace');
    });

    test('sebelas alat lain nggak kesenggol', () {
      expect(profilLembarKerjaUntuk('pH Meter'), 'ph_meter');
      expect(profilLembarKerjaUntuk('Autoklaf'), 'autoclave');
      expect(
        profilLembarKerjaUntuk('Temperature Indicator tanpa Sensor'),
        'tits',
      );
      expect(profilLembarKerjaUntuk('Jangka Sorong'), isNull);
      expect(profilLembarKerjaUntuk('Micrometer'), isNull);
    });

    test('lima kata kuncinya nggak nempel di nama alat lain mana pun', () async {
      // Pencocokan `profilLembarKerjaUntuk` nerima kunci yang nempel di TENGAH
      // nama, jadi kunci pendek (`bath` cuma 4 huruf) berisiko menyerempet alat
      // lain. Diadu ke seluruh nama alat yang dikenal mock — kalau nanti ada
      // alat baru yang namanya kebetulan memuat salah satunya, test ini yang
      // bunyi duluan, bukan teknisi di lapangan.
      const kunciEnclosure = {
        'oven': 'oven',
        'furnace': 'furnace',
        'bath': 'bath',
        'inkubator': 'inkubator',
        'incubator': 'inkubator',
        'refrigerator': 'refrigerator',
      };

      final layanan = MockCategoryService();
      for (final kategori in await layanan.daftar('mock-token-1')) {
        final detail = await layanan.detail('mock-token-1', kategori.kode);
        for (final k in detail.kemampuan) {
          final nama = k.namaAlat.toLowerCase();
          final kenaEnclosure = kunciEnclosure.entries
              .where((e) => nama.contains(e.key))
              .map((e) => e.value)
              .toSet();

          if (kenaEnclosure.isEmpty) continue;

          // Kalau kena, harus karena alatnya MEMANG enclosure — bukan
          // kebetulan hurufnya nempel.
          expect(
            kenaEnclosure,
            hasLength(1),
            reason: '"${k.namaAlat}" kena lebih dari satu kunci enclosure',
          );
          expect(
            profilLembarKerjaUntuk(k.namaAlat),
            kenaEnclosure.single,
            reason: '"${k.namaAlat}" bukan enclosure tapi kena kunci enclosure',
          );
        }
      }
    });
  });

  group('kategori suhu memulangkan kelima enclosure', () {
    test('kartunya ada, dan CMC-nya ikut lampiran akreditasi', () async {
      final detail =
          await MockCategoryService().detail('mock-token-1', 'suhu-dan-kelembapan');

      // Dua Temperatur Indikator disaring lewat [namaTemperaturIndikator],
      // bukan dibandingin ke satu ejaan: kategori ini punya DUA nama alat TI
      // dengan ejaan beda bahasa (lampiran akreditasi no. 1 Inggris, no. 2
      // Indonesia), dan nyebut salah satunya bikin yang lain bocor ke peta CMC
      // enclosure di bawah.
      final cmc = {
        for (final k in detail.kemampuan)
          if (!namaTemperaturIndikator(k.namaAlat))
            k.namaAlat: k.ketidakpastianTerbaik,
      };

      // Angka dari `kemampuan-kalibrasi.json` no. 6-10 di backend.
      expect(cmc, {
        'Oven': 1.5,
        'Bath': 1.2,
        'Inkubator': 1.4,
        'Furnace': 3.0,
        'Refrigerator': 1.5,
      });
    });

    test('Oven batas bawahnya teks "ambient", bukan angka nol', () async {
      final detail =
          await MockCategoryService().detail('mock-token-1', 'suhu-dan-kelembapan');

      final oven = detail.kemampuan.firstWhere((k) => k.namaAlat == 'Oven');

      // Ditulis nol, rentangnya jadi bohong: oven nggak diklaim dari 0 °C.
      expect(oven.rangeMin, isNull);
      expect(oven.rangeMax, 300);
      expect(oven.rangeNote, contains('ambient'));
    });

    test('TITS tetap ada — enclosure nambah, bukan menggusur', () async {
      final detail =
          await MockCategoryService().detail('mock-token-1', 'suhu-dan-kelembapan');

      expect(
        detail.kemampuan.any(
          (k) => k.namaAlat == 'Temperature Indicator tanpa Sensor',
        ),
        isTrue,
      );
    });
  });

  group('sesi enclosure yang dibuka lagi', () {
    Map<String, dynamic> sesi(Map<String, dynamic> equipment) => {
      'id': 12,
      'tanggal_kalibrasi': '2026-05-02',
      'status': 'draft',
      'equipment': equipment,
      'teknisi': {'nama': 'Rohman'},
    };

    test('`equipment.profil` dipakai apa adanya', () {
      final d = CalibrationDetail.fromJson(sesi({
        'id': 4,
        'nama_alat': 'Memmert UN55',
        'profil': 'oven',
      }));

      expect(d.profil, 'oven');
    });

    test('server lama tanpa `profil`: ditebak dari nama, bukan jatuh ke pH', () {
      final d = CalibrationDetail.fromJson(sesi({
        'id': 4,
        'nama_alat': 'Memmert Universal Oven UN55',
      }));

      expect(d.profil, isNull);
      // Inilah yang dulu bolong: tanpa entri di `_profilKhusus`, baris ini
      // pulang null dan pemanggilnya jatuh ke `?? 'ph_meter'`.
      expect(profilLembarKerjaUntuk(d.namaAlat), 'oven');
    });
  });
}
