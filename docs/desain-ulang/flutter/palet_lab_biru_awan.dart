// Nilai baru untuk lib/core/theme/palet_lab.dart (SATU-SATUNYA berkas yang
// boleh menulis Color(0x...)). Nama lama `kobalt*` DIPERTAHANKAN sementara
// sebagai alias supaya PR token tidak menyentuh layar; hapus di PR terakhir.
// Setelah tempel: flutter test test/tema (kontras_sidik_test, token_tema_lab_test).
import 'package:flutter/painting.dart';

abstract final class PaletBiruAwan {
  // ── Merek ──
  static const Color primer = Color(0xFF1C6FC4); // aksi utama, fokus. Putih di atasnya 5,10:1
  static const Color primerTua = Color(0xFF0F4F94); // teks/ikon biru di atas kabut 7,18:1
  static const Color langit = Color(0xFF5BB4F5); // permukaan sorot. HANYA teks navy (6,81:1)
  static const Color awan = Color(0xFFA9D8FB); // stempel "menunggu"
  static const Color kabut = Color(0xFFE4F2FD); // sel terisi, ubin terpilih, butir dock aktif
  static const Color kobaltLogo = Color(0xFF043EA1); // hanya logo, bukan UI

  // ── Netral terang ──
  static const Color latarTerang = Color(0xFFF3F7FB);
  static const Color kertasTerang = Color(0xFFFFFFFF);
  static const Color tintaTerang = Color(0xFF0B2545); // juga "navy" tombol tegas
  static const Color tinta2Terang = Color(0xFF4A5D78);
  static const Color garisHalusTerang = Color(0xFFE8EEF5);
  static const Color garisTegasTerang = Color(0xFFC5D5E6);
  static const Color navyTeks = Color(0xFFC3D6EC); // keterangan di atas ubin navy
  static const Color navyGaris = Color(0xFF2A4468);

  // ── Status (latar ubin/stempel; tinta selalu navy) ──
  static const Color lulus = Color(0xFFBFE6C4);
  static const Color awas = Color(0xFFF6D36B);
  static const Color gagal = Color(0xFFF2957A);
  static const Color gagalBatang = Color(0xFFE0684A); // batang |kor|+U yang lewat toleransi
  static const Color gagalLatarTipis = Color(0xFFFDE3DA);
  static const Color tunggu = awan;
  static const Color netral = Color(0xFFEEF2F6);
  // FAIL "Tidak memenuhi toleransi": stempel navy pekat + teks putih, TIDAK dilunakkan.

  // ── Gelap ──
  static const Color primerGelap = Color(0xFF7CC4F6); // teks di atasnya: latarGelap (9,58:1)
  static const Color langitGelap = Color(0xFF28649B);
  static const Color kabutGelap = Color(0xFF173452);
  static const Color latarGelap = Color(0xFF0B1626);
  static const Color kertasGelap = Color(0xFF13243A);
  static const Color tintaGelap = Color(0xFFE6EEF7);
  static const Color tinta2Gelap = Color(0xFFA9B9CC);
  static const Color garisHalusGelap = Color(0xFF2A4260);
  static const Color garisTegasGelap = Color(0xFF7C8FA8);

  // Foto/kertas tulisan tangan di layar "Cek hasil pindai" (bukan warna UI).
  static const Color kertasFoto = Color(0xFFF7F4EA);
}
