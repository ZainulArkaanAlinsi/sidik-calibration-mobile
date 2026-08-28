import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/skema_dokumen.dart';
import 'package:sidik_calibration/services/peta_kolom_titik.dart';

/// Jembatan terakhir jalur generik: tabel yang dibaca dari foto jadi titik ukur
/// yang bisa dihitung backend.
///
/// Yang dijaga berkas ini satu hal di atas segalanya: **artinya datang dari
/// teknisi, bukan dari tebakan aplikasi.** Nggak ada satu pun nama kolom di
/// sini, dan begitu ada, jalur generiknya mati — yang tersisa daftar ejaan
/// kepala kolom, cuma pindah tempat.
void main() {
  const peta = PetaKolomTitik();

  TabelSkema tabel(List<String> kepala, List<List<String>> baris) =>
      (kepala: kepala, baris: baris, kotak: Rect.zero);

  /// Adu satu titik ke isinya, BUKAN lewat `==`.
  ///
  /// `TitikDariDokumen` record berisi `List`, dan `==` record ngebandingin
  /// tiap field pakai `==` juga — buat `List` itu identitas objek, bukan isi.
  /// Diadu utuh, test-nya merah walau isinya sama persis, dan yang lebih buruk:
  /// dia bisa HIJAU gara-gara dua field kebetulan nunjuk list yang sama.
  void samaDengan(
    TitikDariDokumen titik, {
    required String acuan,
    required List<String> pembacaan,
  }) {
    expect(titik.nilaiAcuan, acuan);
    expect(titik.pembacaan, pembacaan);
  }

  group('penetapan yang belum sah ditolak, dan sebabnya disebut', () {
    test('tanpa nilai acuan', () {
      expect(
        peta.periksa(const [PeranKolom.pembacaan, PeranKolom.pembacaan]),
        PetaBelumSah.tanpaNilaiAcuan,
      );
    });

    test('dua kolom acuan sekaligus', () {
      expect(
        peta.periksa(const [
          PeranKolom.nilaiAcuan,
          PeranKolom.nilaiAcuan,
          PeranKolom.pembacaan,
          PeranKolom.pembacaan,
        ]),
        PetaBelumSah.nilaiAcuanLebihDariSatu,
        reason: 'Satu titik ukur punya SATU nilai yang dituju. Dua kolom acuan '
            'artinya bentuk kertasnya beda dari yang bisa dipetakan di sini.',
      );
    });

    test('pembacaan cuma satu', () {
      expect(
        peta.periksa(const [PeranKolom.nilaiAcuan, PeranKolom.pembacaan]),
        PetaBelumSah.pembacaanKurang,
        reason: 'Type A itu sebaran antar-pengulangan. Satu angka nggak punya '
            'sebaran, dan form-nya emang bakal nolak — mendingan ketahuan di '
            'sini daripada sesudah teknisi mikir kerjaannya udah beres.',
      );
    });

    test('yang sah pulang null', () {
      expect(
        peta.periksa(const [
          PeranKolom.abaikan,
          PeranKolom.nilaiAcuan,
          PeranKolom.pembacaan,
          PeranKolom.pembacaan,
        ]),
        isNull,
      );
    });
  });

  test('LEMBAR TAK DIKENAL: tabel foto jadi titik ukur, arti dari teknisi', () {
    // Torque wrench — bukan lembar mana pun yang dikenal aplikasi ini.
    final hasil = peta.petakan(
      tabel: tabel(
        ['No', 'Target', 'Uji 1', 'Uji 2', 'Uji 3'],
        [
          ['1', '50', '49,8', '50,1', '49,9'],
          ['2', '100', '99,5', '100,2', '99,8'],
        ],
      ),
      peran: const [
        PeranKolom.abaikan, // No
        PeranKolom.nilaiAcuan, // Target
        PeranKolom.pembacaan, // Uji 1
        PeranKolom.pembacaan, // Uji 2
        PeranKolom.pembacaan, // Uji 3
      ],
    );

    expect(hasil.titik, hasLength(2));
    samaDengan(hasil.titik[0], acuan: '50', pembacaan: ['49,8', '50,1', '49,9']);
    samaDengan(hasil.titik[1], acuan: '100', pembacaan: ['99,5', '100,2', '99,8']);
    expect(hasil.barisDilewat, 0);
  });

  test('urutan kolom kertasnya bebas — yang milih penetapannya', () {
    // Pembacaan di KIRI, acuan di kanan. Nggak ada asumsi "acuan itu kolom
    // kedua" di mana pun.
    final hasil = peta.petakan(
      tabel: tabel(
        ['Baca A', 'Baca B', 'Acuan'],
        [
          ['4,01', '4,03', '4,00'],
        ],
      ),
      peran: const [
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
        PeranKolom.nilaiAcuan,
      ],
    );

    samaDengan(hasil.titik.single, acuan: '4,00', pembacaan: ['4,01', '4,03']);
  });

  test('sel pembacaan yang kosong TETAP dibawa di posisinya', () {
    final hasil = peta.petakan(
      tabel: tabel(
        ['Target', 'R1', 'R2', 'R3'],
        [
          ['50', '49,8', '', '49,9'],
        ],
      ),
      peran: const [
        PeranKolom.nilaiAcuan,
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
      ],
    );

    expect(
      hasil.titik.single.pembacaan,
      ['49,8', '', '49,9'],
      reason: 'Dibuang, pengulangan ke-3 naik jadi ke-2 dan angkanya mendarat '
          'di kolom yang salah tanpa ada yang kelihatan hilang.',
    );
  });

  test('baris tanpa nilai acuan DILEWAT, dan jumlahnya dilaporkan', () {
    final hasil = peta.petakan(
      tabel: tabel(
        ['Target', 'R1', 'R2'],
        [
          ['50', '49,8', '50,1'],
          ['', '', ''], // baris kosong di kertas yang belum diisi
          ['100', '99,5', '100,2'],
        ],
      ),
      peran: const [
        PeranKolom.nilaiAcuan,
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
      ],
    );

    expect(hasil.titik, hasLength(2));
    expect(
      hasil.barisDilewat,
      1,
      reason: 'Dibuang diam-diam, teknisi nggak punya cara tahu barisnya nggak '
          'ikut. Disebut, dia bisa mutusin itu wajar apa nggak.',
    );
  });

  test('baris yang lebih pendek dari daftar peran nggak bikin meledak', () {
    // Bentuk tabel datang dari foto, bukan dari skema tetap. Sel bolong di
    // ekor baris itu hal biasa.
    final hasil = peta.petakan(
      tabel: tabel(
        ['Target', 'R1', 'R2'],
        [
          ['50', '49,8'],
        ],
      ),
      peran: const [
        PeranKolom.nilaiAcuan,
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
      ],
    );

    samaDengan(hasil.titik.single, acuan: '50', pembacaan: ['49,8', '']);
  });

  test('penetapan belum sah → nol titik, bukan tebakan', () {
    final hasil = peta.petakan(
      tabel: tabel(
        ['A', 'B'],
        [
          ['1', '2'],
        ],
      ),
      peran: const [PeranKolom.abaikan, PeranKolom.abaikan],
    );

    expect(
      hasil.titik,
      isEmpty,
      reason: 'Nebak yang kurang di sini artinya nebak mana acuan mana '
          'pembacaan — dan ketuker itu bikin koreksi di sertifikat kebalik '
          'tandanya, dengan angka yang kelihatan wajar.',
    );
  });

  test('angkanya TIDAK dikonversi — teks kertasnya dibawa apa adanya', () {
    final hasil = peta.petakan(
      tabel: tabel(
        ['Target', 'R1', 'R2'],
        [
          ['50', '4,O1', '49,9'], // huruf O, bukan nol — salah baca OCR
        ],
      ),
      peran: const [
        PeranKolom.nilaiAcuan,
        PeranKolom.pembacaan,
        PeranKolom.pembacaan,
      ],
    );

    expect(
      hasil.titik.single.pembacaan.first,
      '4,O1',
      reason: 'Dikonversi di sini, sel yang nggak keparse hilang sebelum '
          'teknisi sempat lihat. Biar dia lihat apa yang beneran kebaca lalu '
          'membetulkan; penolakannya udah ada di form, di satu tempat.',
    );
  });
}
