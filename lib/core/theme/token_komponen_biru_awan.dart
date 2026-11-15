import 'package:flutter/material.dart';

import 'sidik_theme.dart';

/// Token komponen dasar Biru Awan (`lib/widgets/biru_awan/`, L3a).
///
/// Melengkapi `UkuranBiruAwan` / `BentukBiruAwan` (angka di `tokens.json`) dengan
/// angka yang tertulis di artboard (`docs/desain-ulang/referensi-html/`) tetapi
/// belum punya nama, supaya komponen tidak menulis angka mentah. Warna TIDAK
/// ada di sini: lihat `WarnaBiruAwan`.
///
/// Skala huruf Biru Awan ([HurufBiruAwan]) belum dipasang di `ThemeData`
/// (`docs/standar-kualitas-desain.md` §3 Tipografi: mengganti tema menggeser
/// semua layar yang belum didesain ulang), jadi komponen baru membawanya
/// sendiri. Berat 800 pada artboard memakai `FontWeight.w800`; Inter yang
/// dibundel berhenti di 700 (Bold), jadi 800 tampil sebagai 700 sampai font
/// ExtraBold ditambahkan (keputusan font di luar paket ini).
abstract final class HurufBiruAwan {
  static const String _inter = SidikTheme.keluarga;

  /// 20/26 · 800: judul layar anak.
  static const TextStyle judulAnak = TextStyle(
    fontFamily: _inter,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w800,
  );

  /// 17/24 · 800: judul bagian.
  static const TextStyle judulBagian = TextStyle(
    fontFamily: _inter,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w800,
  );

  /// 16/24 · 700: label tombol utama, judul baris menu.
  static const TextStyle label = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  /// 16/24 · 800: judul baris daftar dan kartu.
  static const TextStyle judulBaris = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w800,
  );

  /// 15/20 · 700: label tombol tegas, sekunder, teks, bahaya (artboard Komponen).
  static const TextStyle tombol = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
  );

  /// 14/20 · 700: label isian, label chip dan segmen.
  static const TextStyle labelKecil = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  /// 16/24 · 400: teks yang diketik di isian.
  static const TextStyle isian = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// 14/20 · 400: keterangan.
  static const TextStyle keterangan = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 12/16 · 400: catatan kecil (peran di kepala tab, tanggal).
  static const TextStyle catatan = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// 13/18 · 400: sub-judul baris, bantuan isian.
  static const TextStyle keteranganKecil = TextStyle(
    fontFamily: _inter,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// 13/18 · 600: kalimat galat di bawah isian.
  static const TextStyle galat = TextStyle(
    fontFamily: _inter,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// 12/16 · 700: stempel.
  static const TextStyle stempel = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Plex Mono 12 · 600: nomor KAL/..., serial.
  static TextStyle get nomor =>
      SidikTheme.gayaAngka(ukuran: 12, berat: FontWeight.w600);

  /// Plex Mono 16 · 400: isian berisi kode atau angka.
  static TextStyle get isianMono =>
      SidikTheme.gayaAngka(ukuran: 16, berat: FontWeight.w400);

  /// Inter 28/34 · 800: kalimat judul layar tab (`tokens.json` `huruf.judulLayar`;
  /// beranda teknisi "3 draf belum dikirim.").
  static const TextStyle judulLayar = TextStyle(
    fontFamily: _inter,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
  );

  /// Inter 24/28 · 800: judul di dalam hero langit ("Mulai dari alat yang
  /// datang hari ini", `LAYAR.md` 01).
  static const TextStyle judulHero = TextStyle(
    fontFamily: _inter,
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w800,
  );
}

/// Jarak di dalam komponen (dp). Melengkapi `AppSpacing` (4/8/16/24/32), yang
/// TIDAK diubah (beku).
abstract final class JarakBiruAwan {
  /// Antar-blok dan ikon-ke-teks: `LAYAR.md` "jarak antar-blok 12".
  static const double blok = 12;

  /// Bantalan samping isi tombol dan kotak isian.
  static const double samping = 18;

  /// Sisipan kecil: tepi dalam segmen, tepi panel menu, ujung chip berjumlah.
  static const double sisipan = 6;

  /// Antar baris judul dan sub-judul.
  static const double baris = 2;

  /// Bantalan atas-bawah isi isian (24 + 2 x 14 = 52 >= 48).
  static const double isianVertikal = 14;

  /// Bantalan samping panel baris daftar (`LAYAR.md`: panel 4/14).
  static const double panelDaftar = 14;

  /// Bantalan dalam satu baris menu (`LAYAR.md`: baris 64, padding 10).
  static const double barisMenu = 10;
}

/// Ukuran bagian dalam komponen (dp) yang belum bernama di `UkuranBiruAwan`.
abstract final class UkuranKomponenBiruAwan {
  /// Kotak isian (`ELEMEN.md` §Isian: kotak 56).
  static const double isian = 56;

  /// Segmen pil (`tokens.json` → `ukuran.segmenTitik`; `UkuranBiruAwan` belum
  /// memilikinya, `standar-kualitas-desain.md` §11 butir 14).
  static const double segmen = 56;

  /// Bulatan jumlah di chip (`ELEMEN.md`: bulatan 32).
  static const double jumlahChip = 32;

  /// Ubin ikon baris menu (bulat) dan baris daftar (persegi sudut 16).
  static const double ubinMenu = 44;
  static const double ubinBaris = 48;

  /// Ikon: stempel 14, tombol bulat 22 (28 untuk Mulai), tombol berlabel 20.
  static const double ikonStempel = 14;
  static const double ikonBulat = 22;
  static const double ikonBulatMulai = 28;
  static const double ikonTombol = 20;
  static const double ikonGalat = 16;

  /// Ikon di dalam ubin ikon.
  static const double ikonUbin = 20;

  /// Panah di ujung baris.
  static const double panah = 20;

  /// Logo PT SIDIK di kepala tab (`assets/images/logo_pt_sidik.png`).
  static const double logoLebar = 30;
  static const double logoTinggi = 42;

  /// Ruang antara tepi tombol dan cincin fokus papan ketik. Cincin digambar di
  /// LUAR isi tombol, jadi kontrasnya dihitung terhadap latar halaman, bukan
  /// terhadap isi tombol (navy di navy tidak terlihat).
  static const double jarakCincinFokus = 2;

  /// Bayangan tombol Mulai (60): 0 8 18, primer 40 %.
  static const double bayanganMulaiGeser = 8;
  static const double bayanganMulaiBlur = 18;
  static const double bayanganMulaiAlfa = 0.4;
}
