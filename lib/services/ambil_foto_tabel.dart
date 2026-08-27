import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../providers/sumber_foto_provider.dart';
import '../providers/worksheet_scan_provider.dart';
import 'pembaca_halaman.dart';

/// Hasil satu jepretan "foto tabel ini".
///
/// Tiga keadaan yang beda, dan pesannya ke teknisi juga beda:
///
///  - `dibatalkan` — dia menutup kamera. Nggak ada yang perlu dikatakan.
///  - `terbaca == null` (tapi nggak dibatalkan) — berkasnya nggak bisa dibuka
///    sebagai citra. Yang benar minta jepret ulang.
///  - `terbaca` berisi — OCR-nya jalan. Daftarnya boleh KOSONG, dan itu bukan
///    kegagalan: kertas yang belum diisi memang nggak punya teks buat dibaca.
typedef HasilAmbilFoto = ({
  List<TeksTerbaca>? terbaca,
  bool dibatalkan,
  // Ukuran citra yang dibaca, buat [PetaTabelFoto.petakan] memangkas kotak sel
  // yang jatuh di luar fotonya. Kosong kalau citranya sendiri nggak kebuka.
  Size? ukuran,
});

/// Ambil satu foto tabel dari kamera/galeri lalu baca teksnya **di perangkat**.
///
/// ## Kenapa dipisah jadi fungsi sendiri
///
/// TIGA tombol memakainya dengan pemeta yang beda, dan bedanya cuma "angka ini
/// tempatnya di mana":
///
///  - `LembarKerjaTabel` — bentuk titik ukur × Repeat (13 lembar).
///  - `LembarKerjaGrid` — grid sensor Enclosure, satu tombol per blok set point.
///  - `LembarKerjaMatriks` — matriks Autoklaf, baris = besaran.
///
/// Langkah ambil-dan-bacanya identik, dan **dua angka di dalamnya punya alasan
/// yang mahal kalau ikut disalin salah**:
///
///  - `maxWidth: 4200` & `imageQuality: 100` — yang dibaca ML Kit angka
///    setinggi beberapa puluh piksel, dan tiap piksel yang dibuang di sini
///    hilang dari angka yang kebaca. Yang dibatasi UKURANNYA, bukan mutunya:
///    artefak JPEG di garis tipis itu yang bikin `4,04` kebaca `404`.
///  - `pembaca.tutup()` di `finally` — pengenal ML Kit megang sumber daya
///    native. Yang bocor nggak keliatan di satu jepretan; yang keliatan sesi
///    panjang yang makin lambat lalu mati.
///
/// Citranya ditulis ke folder sementara app, BUKAN galeri: isinya lembar kerja
/// pelanggan. DUA berkas sementara lahir per jepretan, dan dua-duanya dihapus
/// di sini:
///
///  - PNG yang ditulis buat ML Kit — dibuang [MlKitPembacaHalaman];
///  - berkas yang dipulangkan pemilih foto — dibuang di bawah, begitu bitanya
///    masuk memori.
///
/// Yang kedua sempat ketinggalan, dan janji "dihapus lagi begitu selesai
/// dibaca" di docblock ini nggak berlaku buat dia: berkasnya menumpuk satu per
/// jepretan di cache pemilih, isinya lembar kerja pelanggan, dan nggak ada
/// satu pun yang membersihkannya sepanjang sesi.
Future<HasilAmbilFoto> ambilDanBacaTabel(WidgetRef ref) async {
  final foto = await ref
      .read(sumberFotoProvider)
      .ambil(maxWidth: 4200, imageQuality: 100);

  if (foto == null) return (terbaca: null, dibatalkan: true, ukuran: null);

  final bita = await foto.readAsBytes();

  // Bitanya sudah di memori — berkasnya nggak dibutuhkan lagi, termasuk kalau
  // pembacaan di bawah gagal.
  try {
    await foto.delete();
  } catch (_) {
    // Gagal hapus bukan alasan membatalkan pembacaan: angkanya sudah di tangan
    // teknisi, dan menolak memprosesnya karena sampah yang nggak kebuang jauh
    // lebih mahal daripada sampahnya sendiri.
  }

  final citra = img.decodeImage(bita);

  if (citra == null) return (terbaca: null, dibatalkan: false, ukuran: null);

  final pembaca = ref.read(pabrikPembacaPindaiProvider).halaman();

  try {
    return (
      terbaca: await pembaca.baca(citra),
      dibatalkan: false,
      ukuran: Size(citra.width.toDouble(), citra.height.toDouble()),
    );
  } finally {
    await pembaca.tutup();
  }
}
