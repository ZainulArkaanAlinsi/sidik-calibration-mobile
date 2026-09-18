import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/izin.dart';

/// Tiap nama di [NamaIzin] beneran ada di `MatriksIzin::PETA` punya server.
///
/// ## Kegagalan yang dijaga
///
/// [Izin.bolehkah] SENGAJA jatuh ke cadangan aturan peran buat nama yang tidak
/// dikenal — supaya endpoint izin yang mati tidak mengunci semua tombol. Harga
/// dari pilihan itu: nama yang salah ketik atau basi juga jatuh ke cadangan,
/// dan cadangannya `role.isAdmin` — persis aturan hardcode yang seluruh matriks
/// peran ini ada untuk menggantikannya.
///
/// Jadi salah-nama tidak memunculkan error di sisi mana pun. Tombolnya tetap
/// jalan, cuma memakai aturan yang basi diam-diam tiap kali server mengubah
/// gerbangnya. Itu yang sudah kejadian: dari sebelas nama, LIMA tidak pernah ada
/// di peta server — `master-data.ubah`, `akun.kelola`, `sertifikat.kirim`,
/// `tanda-tangan.kelola`, `folder.tulis`.
///
/// `test/fixtures/nama_izin.json` digenerate dari server
/// (`docs/skrip/gen-nama-izin-mobile.php`), jadi daftarnya tidak bisa ikut basi
/// bareng kodenya.
void main() {
  late Set<String> izinServer;

  setUpAll(() {
    final json =
        jsonDecode(File('test/fixtures/nama_izin.json').readAsStringSync())
            as Map<String, dynamic>;
    izinServer = (json['izin'] as List).map((e) => '$e').toSet();
  });

  /// Disalin tangan dari `NamaIzin` — Dart tidak punya refleksi konstanta di
  /// `flutter test`. Menambah konstanta tanpa menambahnya ke sini bikin test
  /// `jumlahnya cocok` di bawah merah, jadi daftar ini tidak bisa ketinggalan
  /// diam-diam.
  const dipakaiMobile = <String>{
    NamaIzin.alatTambah,
    NamaIzin.alatUbah,
    NamaIzin.alatHapus,
    NamaIzin.kalibrasiBuat,
    NamaIzin.kalibrasiSetujui,
    NamaIzin.standarKelola,
    NamaIzin.penggunaKelola,
    NamaIzin.sertifikatKirim,
    NamaIzin.tandaTanganKelola,
    NamaIzin.arsipFolderKelola,
  };

  test('tiap nama izin yang ditanya mobile dikenal server', () {
    final asing = dipakaiMobile.difference(izinServer).toList()..sort();

    expect(
      asing,
      isEmpty,
      reason:
          'Nama izin ini tidak ada di MatriksIzin::PETA. Izin.bolehkah() bakal '
          'diam-diam balik ke aturan peran hardcode — tanpa error di sisi mana '
          'pun. Samakan namanya, atau tambahkan pemetaannya di server.',
    );
  });

  /// Konstanta yang ditambah tapi lupa didaftarkan di [dipakaiMobile] di atas
  /// bikin test ini merah — kalau tidak, daftar penjaganya sendiri yang basi.
  test('daftar di test ini tidak ketinggalan dari NamaIzin', () {
    const jumlahKonstanta = 10;

    expect(
      dipakaiMobile,
      hasLength(jumlahKonstanta),
      reason:
          'Ada konstanta NamaIzin yang belum masuk daftar di test ini (atau '
          'jumlahnya berubah). Tambahkan, lalu perbarui angkanya.',
    );
  });
}
