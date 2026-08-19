// `characters` dipakai lewat re-export Flutter, bukan dependency langsung —
// motong `nama[0]` mentah bakal misahin pasangan surrogate jadi separuh huruf.
import 'package:flutter/widgets.dart';

/// Huruf awal nama buat avatar — dipakai waktu user belum pasang foto.
///
/// Ditaruh di satu tempat karena dua layar sama-sama butuh (panel samping
/// desktop & kartu profil), dan dua salinan aturan "potong huruf depan" cepat
/// atau lambat beda. Kartu profil sempat motongnya sendiri lewat
/// `nama.characters.first` — itu nglempar `StateError` buat nama kosong,
/// sementara panel desktop di app yang sama nampilin `?` dengan tenang.
///
/// Nama kosong BUKAN kasus teoretis: `nama` datang apa adanya dari backend
/// (`User.fromJson`), dan yang jadi korban justru layar profil — satu-satunya
/// tempat orang buka buat mbenerin datanya.
///
/// Balikin maksimal [maks] huruf ('Raihan Nazhiif' → 'RN'), atau [kalauKosong]
/// kalau namanya nggak nyisain huruf sama sekali.
///
/// [maks] ada karena dua layarnya emang beda tampilan, bukan karena belum
/// diseragamkan: panel desktop nulis dua huruf di lingkaran kecil, kartu profil
/// nulis SATU huruf besar di avatar gede. Yang disatukan aturan "nama kosong
/// nggak boleh bikin crash", bukan jumlah hurufnya.
String inisialNama(String nama, {int maks = 2, String kalauKosong = '?'}) {
  final inisial = nama
      .trim()
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .take(maks)
      .map((k) => k.characters.first.toUpperCase())
      .join();

  return inisial.isEmpty ? kalauKosong : inisial;
}
