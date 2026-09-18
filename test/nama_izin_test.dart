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

  /// Nilai konstanta `NamaIzin` DIBACA dari sumbernya, bukan disalin tangan.
  ///
  /// Versi pertama test ini menyalin daftarnya ke sini lalu mengadu
  /// panjangnya ke sebuah konstanta `jumlahKonstanta = 10` di berkas yang sama
  /// — dua literal yang ditulis berdampingan, nol-nya membaca `NamaIzin`. Jadi
  /// dia cuma mengukur dirinya sendiri: menambah konstanta baru yang salah
  /// ketik ke `izin.dart` TIDAK pernah membuatnya merah, padahal docblock-nya
  /// mengklaim sebaliknya. Klaim itu yang bikin lubangnya berbahaya — kontrak
  /// nama izin dianggap "dijaga dua arah" padahal satu arahnya kosong.
  ///
  /// Dart tidak punya refleksi konstanta di `flutter test`, jadi sumbernya
  /// dibaca sebagai TEKS. Itu bukan kerapian: yang dijaga di sini justru nama
  /// yang belum pernah dipakai siapa pun, dan satu-satunya tempat nama itu
  /// pasti muncul adalah berkas deklarasinya.
  Set<String> bacaNamaIzin() {
    final sumber = File('lib/models/izin.dart').readAsStringSync();
    final kelas = sumber.substring(sumber.indexOf('abstract final class NamaIzin'));
    final pola = RegExp(r"static const \w+ = '([^']+)';");

    return pola.allMatches(kelas).map((m) => m.group(1)!).toSet();
  }

  test('tiap nama izin yang ditanya mobile dikenal server', () {
    final dipakaiMobile = bacaNamaIzin();

    expect(
      dipakaiMobile,
      isNotEmpty,
      reason: 'nol konstanta kebaca dari izin.dart — polanya yang rusak, '
          'bukan kontraknya',
    );

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

  /// Dan polanya beneran menangkap — kalau `bacaNamaIzin()` suatu saat
  /// memulangkan himpunan kosong (mis. formatnya berubah), test di atas lolos
  /// dengan hampa. Angkanya sengaja TIDAK dipatok literal: yang dijaga bahwa
  /// yang kebaca sama banyaknya dengan yang beneran ditulis di berkasnya.
  test('pembacaan konstanta tidak melewatkan satu pun', () {
    final sumber = File('lib/models/izin.dart').readAsStringSync();
    final kelas = sumber.substring(sumber.indexOf('abstract final class NamaIzin'));

    final jumlahBaris = RegExp(r'^\s*static const \w+ = ', multiLine: true)
        .allMatches(kelas)
        .length;

    expect(
      bacaNamaIzin(),
      hasLength(jumlahBaris),
      reason: 'ada baris `static const` di NamaIzin yang nggak kebaca pola — '
          'nama itu nggak ikut diadu ke server',
    );
  });
}
