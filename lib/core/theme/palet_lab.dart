import 'package:flutter/painting.dart';

/// Palet mentah SIDIK Lab, "Biru Awan" (L1b, 15 Nov 2026). SATU-SATUNYA tempat
/// nilai warna Lab ditulis sebagai angka; `SidikMaterial`, `SidikTheme`, dan
/// `WarnaLajur` membacanya dari sini. Layar tidak menulis warna mentah (dijaga
/// `test/tema/token_only_test.dart`) dan membaca warna lewat
/// `SidikMaterial.of(context)` atau `Theme.of(context).colorScheme`.
///
/// Sumber nilainya `docs/desain-ulang/tokens.json` (nama sama dengan berkas itu).
/// Lembar kerja TIDAK memakai palet ini: ia membaca `PaletBeku` lewat `TemaBeku`
/// (`docs/desain-ulang/BEKU.md`), jadi mengubah nilai di sini tidak menggeser
/// satu piksel pun di sana.
///
/// Semua pasangan yang dipakai sudah dihitung ke WCAG 2.x dan dijaga
/// `test/tema/kontras_sidik_test.dart`: teks 4,5:1, komponen UI 3:1. Ubah satu
/// nilai di sini = jalankan tes itu lagi.
///
/// ## Dua kelompok di bawah "Biru Awan"
///
/// - **Utang desain**: nilai LAMA yang dipertahankan karena `tokens.json` belum
///   punya padanannya (status tema gelap, teks galat, pensil OCR). Dicatat di
///   `docs/standar-kualitas-desain.md`; hilang saat desain menjawabnya.
/// - **Alias sementara**: nama lama (`kobalt*`, `*Terang`) menunjuk ke token
///   baru supaya pemanggil lama tidak patah. Dihapus di PR terakhir (L13).
abstract final class PaletLab {
  // ══════════════════════════════════════════════════════════════════════
  // BIRU AWAN, TERANG (`tokens.json` → `warna.terang`)
  // ══════════════════════════════════════════════════════════════════════

  // ── Merek ───────────────────────────────────────────────────────────────
  /// Aksi utama, fokus, sel aktif. Putih di atasnya 5,10:1.
  static const Color primer = Color(0xFF1C6FC4);

  /// Teks dan ikon biru. Di atas kabut 7,18:1. Teks biru di atas kabut HARUS
  /// memakai ini, bukan [primer] (4,47:1, gagal tipis).
  static const Color primerTua = Color(0xFF0F4F94);

  /// Permukaan sorot (hero, ubin). HANYA teks navy di atasnya (6,81:1); putih
  /// DILARANG (2,26:1).
  static const Color langit = Color(0xFF5BB4F5);

  /// Stempel "Menunggu approval". Navy di atasnya 10,19:1.
  static const Color awan = Color(0xFFA9D8FB);

  /// Sel terisi, ubin terpilih, butir dock aktif, latar ikon. Navy 13,50:1.
  static const Color kabut = Color(0xFFE4F2FD);

  /// Logo PT SIDIK saja, bukan UI.
  static const Color kobaltLogo = Color(0xFF043EA1);

  // ── Netral ──────────────────────────────────────────────────────────────
  /// Latar halaman.
  static const Color latar = Color(0xFFF3F7FB);

  /// Kartu, panel, dock.
  static const Color kertas = Color(0xFFFFFFFF);

  /// Teks, tombol tegas, ubin ringkasan admin. Juga disebut "navy". 15,39:1 di
  /// atas putih.
  static const Color tinta = Color(0xFF0B2545);

  /// Keterangan. 6,71:1 di kertas, 5,89:1 di kabut.
  static const Color tinta2 = Color(0xFF4A5D78);

  /// Pemisah baris dan tepi kartu. Hiasan: tidak boleh membawa makna sendiri.
  static const Color garisHalus = Color(0xFFE8EEF5);

  /// Garis DEKORATIF (bidang tanda tangan, pemisah kartu). TIDAK dipakai untuk
  /// tepi kontrol: di atas putih cuma ±1,5:1, di bawah ambang 3:1 komponen UI.
  /// Tepi isian, tombol sekunder, sakelar, centang memakai [garisKontrol].
  static const Color garisTegas = Color(0xFFC5D5E6);

  /// Garis timeline dan hiasan sedang.
  static const Color garisDekor = Color(0xFFD6E2EE);

  /// Tepi KONTROL terang: isian, tombol sekunder, chip, sakelar, centang.
  /// Di atas putih dan [latar] masing-masing >= 3:1 (dihitung di
  /// `test/tema/kontras_sidik_test.dart`). Token TAMBAHAN keputusan L1b yang
  /// menyimpang dari `DESIGN.md` ("OutlinedButton tepi #C5D5E6"): #C5D5E6 gagal
  /// 3:1 (WCAG 1.4.11), jadi kontrol memakai warna "tepi mati" centang/radio
  /// yang sudah ada di paket desain (`ELEMEN.md` §Kontrol kecil). Sama dengan
  /// `garisTegas` tema gelap di `tokens.json`.
  static const Color garisKontrol = Color(0xFF7C8FA8);

  // ── Status: ubin dan stempel. Tinta di atasnya SELALU navy ([tinta]) ──────
  /// Lulus, disetujui. Navy 11,23:1.
  static const Color hijau = Color(0xFFBFE6C4);

  /// Perlu dicek, revisi. Navy 10,59:1.
  static const Color kuning = Color(0xFFF6D36B);

  /// Ditolak, tak terbaca. Navy 6,85:1.
  static const Color koral = Color(0xFFF2957A);

  /// Batang |kor|+U yang lewat toleransi, dan tepi isian galat. 3,36:1 di putih.
  static const Color koralBatang = Color(0xFFE0684A);

  /// Latar tipis baris/isian galat.
  static const Color kabutGagal = Color(0xFFFDE3DA);

  /// Stempel netral (draf).
  static const Color netralStempel = Color(0xFFEEF2F6);

  // ── Di atas ubin navy, dan foto ──────────────────────────────────────────
  /// Keterangan di atas ubin navy.
  static const Color navyTeks = Color(0xFFC3D6EC);
  static const Color navyGaris = Color(0xFF2A4468);

  /// Foto/kertas tulisan tangan di layar "Cek hasil pindai" (bukan warna UI).
  static const Color kertasFoto = Color(0xFFF7F4EA);

  // ══════════════════════════════════════════════════════════════════════
  // BIRU AWAN, GELAP (`tokens.json` → `warna.gelap`)
  // ══════════════════════════════════════════════════════════════════════
  /// Aksi utama gelap. Teks di atasnya [teksDiAtasPrimerGelap] (9,58:1).
  static const Color primerGelap = Color(0xFF7CC4F6);

  /// Teks/ikon biru di tema gelap.
  static const Color primerTuaGelap = Color(0xFFA9D8FB);
  static const Color langitGelap = Color(0xFF28649B);
  static const Color kabutGelap = Color(0xFF173452);
  static const Color latarGelap = Color(0xFF0B1626);
  static const Color kertasGelap = Color(0xFF13243A);
  static const Color tintaGelap = Color(0xFFE6EEF7);
  static const Color tinta2Gelap = Color(0xFFA9B9CC);
  static const Color garisHalusGelap = Color(0xFF2A4260);

  /// Tepi kontrol tema gelap (`garisTegas` gelap di `tokens.json`).
  static const Color garisTegasGelap = Color(0xFF7C8FA8);

  /// Label di atas isi [primerGelap].
  static const Color teksDiAtasPrimerGelap = Color(0xFF0B1626);

  // ══════════════════════════════════════════════════════════════════════
  // UTANG DESAIN: nilai lama, `tokens.json` belum menjawabnya
  // ══════════════════════════════════════════════════════════════════════

  // ── Teks galat (terang). Koral [koral] gagal sebagai teks di atas putih ───
  /// Teks dan ikon galat di atas kertas/latar: 7,3:1. `ELEMEN.md` §Isian menyebut
  /// #A3261A untuk kalimat galat; belum diputuskan (lihat laporan L1b).
  static const Color gagalTerang = Color(0xFFA81B33);

  // ── Status tema gelap: tinta + latar tipis ──────────────────────────────
  static const Color lulusGelap = Color(0xFF6FD3A0);
  static const Color lulusLatarGelap = Color(0xFF12301F);

  /// Beda dari milik Pelanggan (`#F2B655`, hampir sama terangnya dengan hijau
  /// gelap): jarak luminans >= 0,05 dari hijau dan merah.
  static const Color awasGelap = Color(0xFFDB9A2B);
  static const Color awasLatarGelap = Color(0xFF33260C);
  static const Color gagalGelap = Color(0xFFFF8FA0);
  static const Color gagalLatarGelap = Color(0xFF3A1720);
  static const Color tungguGelap = Color(0xFFC3CAD8);
  static const Color tungguLatarGelap = Color(0xFF262E40);

  /// Label di atas isi merah tema gelap (tombol bahaya).
  static const Color gagalDiAtasGelap = Color(0xFF24070D);

  // ── Tinta pensil (angka saran OCR, belum dipastikan manusia) ────────────
  /// Tema gelap saja. Tema terang memakai [tinta2]: nilai lama `#5F6B7E` cuma
  /// 3,7:1 di atas [kuning] (dasar sel "dari foto, perlu dicek"), di bawah 4,5:1.
  static const Color pensilGelap = Color(0xFF8E98AC);

  // ── Lain-lain ───────────────────────────────────────────────────────────
  /// Tembus pandang total: pengganti kilau/lekuk material lama.
  static const Color tembus = Color(0x00FFFFFF);

  // ── Banner peringatan data (L2, `ELEMEN.md` §Banner) ────────────────────
  /// Latar kartu peringatan data (standar segera habis, server lambat), terang.
  static const Color kuningTipis = Color(0xFFFFF4D1);

  /// Ikon segitiga peringatan di atas [kuningTipis]. Teksnya tetap [tinta].
  static const Color kuningTinta = Color(0xFF8C5C0A);

  // ══════════════════════════════════════════════════════════════════════
  // ALIAS SEMENTARA: nama lama → token Biru Awan (hapus di L13)
  // ══════════════════════════════════════════════════════════════════════
  static const Color kobalt100 = kabut;
  static const Color kobalt300 = primerGelap;
  static const Color kobalt700 = primer;
  static const Color kobalt900 = primerTua;
  static const Color kobaltDiAtas300 = teksDiAtasPrimerGelap;
  static const Color kobaltGelapTipis = kabutGelap;
  static const Color kobaltGelapTeks = primerTuaGelap;
  static const Color putih = kertas;
  static const Color latarTerang = latar;
  static const Color kertasTerang = kertas;
  static const Color tintaTerang = tinta;
  static const Color tinta2Terang = tinta2;
  static const Color garisHalusTerang = garisHalus;

  /// Arti lama "garis tegas >= 3:1" = [garisKontrol] sekarang.
  static const Color garisTegasTerang = garisKontrol;
  static const Color kertas2Terang = latar;
  static const Color latar2Terang = kabut;
  static const Color kertas2Gelap = latarGelap;
  static const Color latar2Gelap = kabutGelap;
}
