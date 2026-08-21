import 'package:flutter/services.dart';


/// Kolom `Time` di lembar bermatriks (Autoklaf) — dijaga supaya yang keketik
/// SELALU bentuk yang diterima backend.
///
/// Backend nuntut `date_format:H:i,H:i:s` (`AutoclaveStoreRequest`,
/// `AutoclaveCalculationRequest`). Sebelum ini kotaknya nerima ketikan bebas
/// asal isinya angka & titik dua, lalu dikirim apa adanya — jadi `8:30`,
/// `0830`, dan `08.30` semuanya lolos dari layar dan baru ditolak server
/// dengan:
///
///     The waktu.0 field must match the format H:i. (and 5 more errors)
///
/// Buat teknisi yang lagi di depan autoklaf, pesan itu nggak nunjuk kolom mana
/// pun yang dia lihat di layar — `waktu.0` bukan nama yang ada di kertasnya.
///
/// Dua hal yang dikerjakan berkas ini, dan dua-duanya perlu:
///
///  1. [FormatJamLembar] — ngetik ANGKA doang, titik duanya muncul sendiri.
///     Di HP itu juga yang bikin cepat: titik dua ada di papan tombol simbol,
///     jadi tiap sel butuh dua kali pindah papan tombol. Sekarang nggak sama
///     sekali.
///  2. [normalisasiJam] — jaring pengaman waktu ngirim, buat draft lama yang
///     terlanjur kesimpen dalam bentuk bebas sebelum formatter ini ada.
/// Ubah apa pun yang keketik jadi `HH:MM:SS`, atau `null` kalau nggak bisa.
///
/// Yang diterima:
///   `2`        → `02:00:00`     (jam bulat)
///   `830`      → `08:30:00`
///   `0830`     → `08:30:00`
///   `8:30`     → `08:30:00`
///   `02:00:00` → `02:00:00`
///
/// Yang ditolak (balik `null`): jam > 23, menit/detik > 59, dan sisa yang
/// nggak kebentuk. Ditolak di layar, bukan dibiarin nyampe server.
///
/// Kosong balik `null` juga — pemanggilnya yang mbedain "kosong" (sah, kolom
/// boleh dilewat) dari "keisi tapi ngawur" (harus ditahan).
String? normalisasiJam(String mentah) {
  final angka = mentah.replaceAll(RegExp(r'[^0-9]'), '');
  if (angka.isEmpty) return null;

  // Dipotong dari KIRI: yang diketik duluan jam, dan kelebihan digit hampir
  // selalu salah pencet di ujung.
  final digit = angka.length > 6 ? angka.substring(0, 6) : angka;

  final int jam;
  final int menit;
  final int detik;

  switch (digit.length) {
    case 1:
    case 2:
      jam = int.parse(digit);
      menit = 0;
      detik = 0;
    case 3:
      // `830` = 8:30, bukan 83:0. Orang nulis jam sekali digit tanpa nol depan.
      jam = int.parse(digit.substring(0, 1));
      menit = int.parse(digit.substring(1, 3));
      detik = 0;
    case 4:
      jam = int.parse(digit.substring(0, 2));
      menit = int.parse(digit.substring(2, 4));
      detik = 0;
    case 5:
      jam = int.parse(digit.substring(0, 1));
      menit = int.parse(digit.substring(1, 3));
      detik = int.parse(digit.substring(3, 5));
    default:
      jam = int.parse(digit.substring(0, 2));
      menit = int.parse(digit.substring(2, 4));
      detik = int.parse(digit.substring(4, 6));
  }

  if (jam > 23 || menit > 59 || detik > 59) return null;

  String dua(int n) => n.toString().padLeft(2, '0');

  return '${dua(jam)}:${dua(menit)}:${dua(detik)}';
}

/// Nyisipin titik dua sambil diketik, jadi yang keluar selalu `HH:MM:SS`.
///
/// Sengaja NGGAK manggil [normalisasiJam] tiap ketukan: normalisasi ngisi nol
/// buat bagian yang belum diketik, dan itu bikin kursor lompat waktu orang baru
/// nulis digit pertama. Di sini cuma penyisipan titik dua; pembulatan bentuknya
/// dikerjakan waktu kotaknya ditinggal.
class FormatJamLembar extends TextInputFormatter {
  const FormatJamLembar();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue lama,
    TextEditingValue baru,
  ) {
    final angka = baru.text.replaceAll(RegExp(r'[^0-9]'), '');
    final digit = angka.length > 6 ? angka.substring(0, 6) : angka;

    final susun = StringBuffer();
    for (var i = 0; i < digit.length; i++) {
      if (i == 2 || i == 4) susun.write(':');
      susun.write(digit[i]);
    }

    final teks = susun.toString();

    return TextEditingValue(
      text: teks,
      // Kursor selalu di ujung. Kotaknya cuma muat 8 karakter dan diisi
      // berurutan dari kiri, jadi nggak ada alasan nyunting di tengah — dan
      // mempertahankan posisi kursor di tengah penyisipan titik dua justru
      // bikin dia meleset satu karakter tiap kali titik duanya muncul.
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}
