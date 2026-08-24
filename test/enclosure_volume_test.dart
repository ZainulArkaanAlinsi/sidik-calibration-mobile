import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Volume enclosure dihitung dari kotak dimensi, bukan diketik.
///
/// Rumusnya niru master `SIDIK-FM-CAL-0504`: balok `P × L × T`, silinder
/// `π · r² · t`, dalam METER, tanpa satu pun faktor konversi.
///
/// ## Yang paling dijaga di sini bukan perkaliannya
///
/// Perkalian tiga angka susah salah. Yang gampang salah — dan yang sudah
/// TERBUKTI salah di masternya sendiri — adalah apa yang muncul waktu kotaknya
/// BELUM diisi.
///
/// Di master, penjaganya `IF(AND(r=0,t=0), P*L*T, "-")` dan kebalikannya. Waktu
/// SEMUA kotak kosong, dua-duanya kondisinya benar, jadi yang keluar `0` bukan
/// `"-"`. Di master Recorder itu beneran kejadian: blok dimensinya kosong total
/// tapi volumenya terbaca `0 m³`.
///
/// "Nol meter kubik" dan "belum diisi" itu dua hal yang beda. Yang satu bilang
/// alatnya nggak punya isi; yang satu bilang belum ada yang ngukur. Test ini
/// yang mastiin keduanya nggak ketuker.
void main() {
  /// Bentuk minimal: cuma blok dimensi, cukup buat `nilaiTurunan`.
  LembarKerja lembarDimensi() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-FM-CAL-0504_Rev.3',
    'judul': 'Calibration Work Sheet - Oven',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': '°C',
    'bagian': [
      {
        'kode': 'dimensi',
        'judul': 'Dimensi Alat',
        'field': [
          for (final k in const [
            'dimensi_panjang',
            'dimensi_lebar',
            'dimensi_tinggi',
            'dimensi_jari_jari',
            'dimensi_tinggi_silinder',
          ])
            {'kode': k, 'label': k, 'tipe': 'angka', 'satuan': 'm'},
          {
            'kode': 'dimensi.volume',
            'label': 'Volume',
            'tipe': 'angka',
            'sumber': 'otomatis',
            'satuan': 'm³',
          },
        ],
      },
    ],
  });

  LembarKerjaState isian() =>
      LembarKerjaState(bentuk: lembarDimensi(), clientRequestId: 'tes-volume');

  String volume(Map<String, String> diisi) {
    final s = isian();
    for (final e in diisi.entries) {
      s.teks[e.key]!.text = e.value;
    }

    return s.nilaiTurunan('dimensi.volume');
  }

  group('kosong nggak boleh menyamar jadi nol', () {
    test('semua kotak kosong → kosong, BUKAN 0', () {
      // Ini bug masternya. Kalau di sini keluar '0', lembarnya bakal bilang
      // alatnya bervolume nol padahal nggak ada yang pernah ngukur.
      expect(volume({}), '');
    });

    test('balok baru keisi separuh → kosong, bukan hasil separuh', () {
      expect(volume({'dimensi_panjang': '0,5', 'dimensi_lebar': '0,5'}), '');
    });

    test('angka nol dianggap belum diisi, bukan nilai sah', () {
      expect(
        volume({
          'dimensi_panjang': '0',
          'dimensi_lebar': '0',
          'dimensi_tinggi': '0',
        }),
        '',
      );
    });
  });

  group('balok — P × L × T', () {
    test('0,5 × 0,5 × 0,5 = 0,125 (angka master ENC_YOKOGAWA)', () {
      expect(
        volume({
          'dimensi_panjang': '0,5',
          'dimensi_lebar': '0,5',
          'dimensi_tinggi': '0,5',
        }),
        '0,125',
      );
    });

    test('titik dan koma sama-sama kebaca — teknisi ngetik dua-duanya', () {
      expect(
        volume({
          'dimensi_panjang': '1.5',
          'dimensi_lebar': '2',
          'dimensi_tinggi': '2',
        }),
        '6',
      );
    });

    test('nol di belakang dibuang: 6 bukan 6,0000', () {
      expect(
        volume({
          'dimensi_panjang': '1',
          'dimensi_lebar': '2',
          'dimensi_tinggi': '3',
        }),
        '6',
      );
    });
  });

  group('silinder — π · r² · t', () {
    test('π-nya 3,14 kayak masternya, bukan math.pi', () {
      // r=1, t=1 → 3,14 persis. Kalau dipakai math.pi hasilnya 3,1416 dan
      // angkanya beda dari yang lab hitung sendiri di kertas.
      expect(
        volume({'dimensi_jari_jari': '1', 'dimensi_tinggi_silinder': '1'}),
        '3,14',
      );
    });

    test('r=0,5 t=2 → 1,57', () {
      expect(
        volume({'dimensi_jari_jari': '0,5', 'dimensi_tinggi_silinder': '2'}),
        '1,57',
      );
    });
  });

  test('dua bentuk keisi barengan → kosong, bukan milih diam-diam', () {
    // Master milih lewat urutan guard-nya. Di sini isian yang saling
    // bertentangan nggak dijawab salah satunya: teknisi yang ngisi P/L/T DAN
    // jari-jari lagi bilang dua hal beda, dan nebak maksudnya bikin angka yang
    // keluar nggak bisa ditelusuri balik ke yang dia ketik.
    expect(
      volume({
        'dimensi_panjang': '1',
        'dimensi_lebar': '1',
        'dimensi_tinggi': '1',
        'dimensi_jari_jari': '1',
        'dimensi_tinggi_silinder': '1',
      }),
      '',
    );
  });

  test('ganti isian → volumenya ikut ganti, bukan nyangkut di angka lama', () {
    final s = isian();

    s.teks['dimensi_panjang']!.text = '1';
    s.teks['dimensi_lebar']!.text = '1';
    s.teks['dimensi_tinggi']!.text = '1';
    expect(s.nilaiTurunan('dimensi.volume'), '1');

    s.teks['dimensi_tinggi']!.text = '2';
    expect(s.nilaiTurunan('dimensi.volume'), '2');

    // Dihapus lagi → balik kosong, bukan nahan angka terakhir.
    s.teks['dimensi_tinggi']!.text = '';
    expect(s.nilaiTurunan('dimensi.volume'), '');
  });
}
