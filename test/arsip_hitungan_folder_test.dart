import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/arsip.dart';

/// Dua hitungan di kartu folder Arsip — dan nama kuncinya yang pernah meleset.
///
/// `FolderResource` di server mengirim `jumlah_folder` & `jumlah_file` (lihat
/// contoh JSON di `docs/kontrak-api.md`). Sampai 3 Sep 2026 `ArsipFolder`
/// membaca `jumlah_subfolder` & `jumlah_berkas` — dua nama yang tidak pernah
/// dikirim siapa pun.
///
/// Kegagalannya SUNYI, dan `?? 0` yang menyunyikannya. Nggak ada exception,
/// nggak ada baris log; yang ada cuma dua akibat yang kelihatan benar:
///
///  1. Tiap folder di layar Arsip menulis "0 folder · 0 berkas", apa pun isinya.
///  2. `kosong` ikut selalu true, jadi menu **Hapus** menyala buat folder yang
///     masih ada isinya — lalu ditolak server. Persis keadaan yang komentar di
///     `ArsipFolder.kosong` bilang mau dicegah ("biar tombolnya bisa dimatiin
///     duluan").
///
/// Yang bikin ini bertahan lama: `MockArsipService` menyusun `ArsipFolder`
/// lewat konstruktor, BUKAN lewat `fromJson`. Di mode mock angkanya benar dan
/// seluruh suite hijau — cuma jalur API asli yang salah. Makanya test ini
/// sengaja berangkat dari peta JSON mentah, bukan dari mock.
void main() {
  /// Bentuknya disalin dari `docs/kontrak-api.md`, bukan dikarang.
  Map<String, dynamic> folderJson({
    int jumlahFolder = 3,
    int jumlahFile = 12,
  }) => {
    'id': 7,
    'nama': '2026',
    'tipe': 'sistem',
    'parent_id': 2,
    'jumlah_folder': jumlahFolder,
    'jumlah_file': jumlahFile,
    'dibuat_pada': '2026-09-03T04:50:00Z',
  };

  group('hitungan folder dibaca dari kunci yang benar-benar dikirim server', () {
    test('`jumlah_folder` & `jumlah_file` sampai ke model', () {
      final folder = ArsipFolder.fromJson(folderJson());

      expect(folder.jumlahSubfolder, 3);
      expect(folder.jumlahBerkas, 12);
    });

    test('folder berisi TIDAK dianggap kosong — penjaga tombol Hapus hidup', () {
      final folder = ArsipFolder.fromJson(folderJson());

      expect(
        folder.kosong,
        isFalse,
        reason: 'kosong yang selalu true bikin menu Hapus menyala buat folder '
            'yang masih ada isinya, lalu ditolak server',
      );
    });

    test('folder yang memang kosong tetap terbaca kosong', () {
      final folder = ArsipFolder.fromJson(
        folderJson(jumlahFolder: 0, jumlahFile: 0),
      );

      expect(folder.jumlahSubfolder, 0);
      expect(folder.jumlahBerkas, 0);
      expect(folder.kosong, isTrue);
    });

    // Nama lama sengaja diadu terpisah. Kalau suatu hari server mengirimnya
    // lagi, yang benar tetap kunci di kontrak — dan diam-diam menerima dua nama
    // bikin drift berikutnya nggak ketahuan lagi.
    test('nama kunci LAMA tidak lagi dibaca', () {
      final folder = ArsipFolder.fromJson({
        'id': 7,
        'nama': '2026',
        'jumlah_subfolder': 9,
        'jumlah_berkas': 9,
      });

      expect(folder.jumlahSubfolder, 0);
      expect(folder.jumlahBerkas, 0);
    });

    test('kunci yang hilang sama sekali jatuh ke nol, bukan meledak', () {
      final folder = ArsipFolder.fromJson({'id': 7, 'nama': '2026'});

      expect(folder.jumlahSubfolder, 0);
      expect(folder.jumlahBerkas, 0);
    });
  });
}
