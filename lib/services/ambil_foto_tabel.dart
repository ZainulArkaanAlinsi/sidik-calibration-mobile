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
typedef HasilAmbilFoto = ({List<TeksTerbaca>? terbaca, bool dibatalkan});

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
/// pelanggan. Dihapus lagi begitu selesai dibaca — lihat [MlKitPembacaHalaman].
Future<HasilAmbilFoto> ambilDanBacaTabel(WidgetRef ref) async {
  final foto = await ref
      .read(sumberFotoProvider)
      .ambil(maxWidth: 4200, imageQuality: 100);

  if (foto == null) return (terbaca: null, dibatalkan: true);

  final citra = img.decodeImage(await foto.readAsBytes());

  if (citra == null) return (terbaca: null, dibatalkan: false);

  final pembaca = ref.read(pabrikPembacaPindaiProvider).halaman();

  try {
    return (terbaca: await pembaca.baca(citra), dibatalkan: false);
  } finally {
    await pembaca.tutup();
  }
}
