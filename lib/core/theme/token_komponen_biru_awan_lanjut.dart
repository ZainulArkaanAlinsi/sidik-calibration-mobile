import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palet_lab.dart';
import 'sidik_material.dart';
import 'sidik_theme.dart';

/// Token komponen dasar Biru Awan bagian 2 (`lib/widgets/biru_awan/`, L3b):
/// HeroLangit, UbinKpi, GrafikBatang, StepperTegak, GarisWaktu, AvatarInisial,
/// Lencana, BilahLangkah, KolomCari.
///
/// Berkas TERPISAH dari `token_komponen_biru_awan.dart` dan
/// `warna_biru_awan.dart` (L3a) supaya paket L3a tidak disentuh; isinya
/// melengkapi keduanya dan memakai pola yang sama (angka dari artboard
/// `docs/desain-ulang/referensi-html/` yang belum punya nama).
///
/// Satu penyimpangan huruf, disengaja: artboard menulis angka lencana 11,
/// sedangkan gerbang token-only melarang huruf di bawah 12. Lencana memakai
/// 12/600 ([HurufLanjutBiruAwan.lencana]).
///
/// REVISI 16 Nov 2026 (R1): tidak ada berat 700/800; judul 600, label 500, isi
/// 400. Angka sorot 32 dan angka kartu 28.
abstract final class HurufLanjutBiruAwan {
  static const String _inter = SidikTheme.keluarga;

  /// 32/36 · 600: satu angka sorot ("4 menunggu").
  static const TextStyle angkaHero = TextStyle(
    fontFamily: _inter,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
  );

  /// 28/32 · 600: angka ubin KPI.
  static const TextStyle angkaKpi = TextStyle(
    fontFamily: _inter,
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w600,
  );

  /// 13/18 · 500: label ubin KPI.
  static const TextStyle labelKpi = TextStyle(
    fontFamily: _inter,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  /// Plex Mono 12 · 600: angka di atas batang.
  static TextStyle get nilaiBatang =>
      SidikTheme.gayaAngka(ukuran: 12, berat: FontWeight.w600);

  /// 12/16 · 500: nama hari di bawah batang.
  static const TextStyle labelBatang = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// 12/16 · 600: nama hari yang disorot.
  static const TextStyle labelBatangSorot = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// 16/24 · 500: judul langkah yang sudah lewat atau belum.
  static const TextStyle judulLangkah = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
  );

  /// 16/24 · 600: judul langkah yang sedang berjalan.
  static const TextStyle judulLangkahSekarang = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// 15/21 · 400: kalimat di garis waktu.
  static const TextStyle kalimatRiwayat = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w400,
  );

  /// 15/21 · 600: pelaku di kalimat garis waktu.
  static const TextStyle pelakuRiwayat = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w600,
  );

  /// 12/16 · 400 / 500 / 600: label bilah langkah (belum / selesai / sekarang).
  static const TextStyle labelBilah = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle labelBilahSelesai = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle labelBilahSekarang = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// 12/16 · 600: angka lencana.
  static const TextStyle lencana = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Inisial avatar: 36 → 14, 48 → 16, 52 → 18, 84 → 28 (semuanya 600).
  static const TextStyle inisialKecil = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle inisialSedang = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle inisialLaci = TextStyle(
    fontFamily: _inter,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle inisialBesar = TextStyle(
    fontFamily: _inter,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
  );

  /// 14/20 · 400: teks yang diketik di kolom cari.
  static const TextStyle isianCari = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
}

/// Jarak dan ukuran bagian dalam komponen L3b (dp).
abstract final class UkuranLanjutBiruAwan {
  // ── HeroLangit ──────────────────────────────────────────────────────────
  /// Bantalan hero (`LAYAR.md`: padding 20).
  static const double heroBantalan = 20;

  /// Kanvas motif skala: 260 x 104 (`BerandaAdmin`), digeser keluar hero.
  static const double motifLebar = 260;
  static const double motifTinggi = 104;
  static const double motifGeserKiri = -40;
  static const double motifGeserBawah = -34;

  /// Putih 45 sampai 55 % di atas langit (`DESIGN.md`).
  static const double motifAlfa = 0.5;

  /// Gambar alat di sudut hero: kanan -18, bawah -14.
  static const double visualGeserKanan = -18;
  static const double visualGeserBawah = -14;

  // ── UbinKpi ─────────────────────────────────────────────────────────────
  static const double kpiTinggiMin = 112;
  static const double kpiBantalan = 16;

  // ── GrafikBatang ────────────────────────────────────────────────────────
  /// Tinggi seluruh kolom grafik (angka, batang, hari).
  static const double batangTinggi = 150;
  static const double batangRadius = 10;

  // ── StepperTegak ────────────────────────────────────────────────────────
  static const double stepperPenanda = 32;
  static const double stepperCincin = 4;
  static const double stepperTepiBelum = 2;
  static const double stepperGaris = 2;
  static const double stepperGarisMin = 28;
  static const double stepperJarak = 14;
  static const double stepperBawah = 18;
  static const double stepperAtas = 4;
  static const double ikonCentang = 18;

  // ── GarisWaktu ──────────────────────────────────────────────────────────
  static const double simpul = 12;
  static const double simpulAtas = 6;
  static const double garisWaktuGaris = 2;
  static const double garisWaktuJarak = 12;
  static const double garisWaktuBawah = 18;

  // ── AvatarInisial ───────────────────────────────────────────────────────
  static const double avatarKecil = 36;
  static const double avatarSedang = 48;
  static const double avatarLaci = 52;
  static const double avatarBesar = 84;

  // ── Lencana ─────────────────────────────────────────────────────────────
  static const double lencanaKoral = 22;
  static const double lencanaKuning = 26;
  static const double lencanaTitik = 10;
  static const double lencanaTepi = 2;
  static const double lencanaBantalan = 5;

  /// Letak lencana di tombol lonceng 48: atas 4, kanan 2.
  static const double lencanaAtas = 4;
  static const double lencanaKanan = 2;

  /// Angka di atas ini tampil "99+".
  static const int lencanaMaks = 99;

  // ── BilahLangkah ────────────────────────────────────────────────────────
  /// Sudut segmen: setengah tinggi 6 (`LAYAR.md`: radius 3).
  static const double bilahRadius = 3;

  // ── KolomCari ───────────────────────────────────────────────────────────
  static const double cariBantalanKiri = 20;
  static const double cariBantalanKanan = 4;
  static const double ikonCari = 20;
  static const double cariJarak = 10;
}

/// Warna L3b yang tidak ada di `WarnaBiruAwan` (L3a) maupun `SidikMaterial`:
/// langit untuk hero, garis dekor untuk segmen yang belum terisi. Diturunkan
/// dari [PaletLab] (terang) dan pasangan [SidikMaterial] (gelap); tanpa nilai
/// mentah. Kontras: `test/biru_awan/hero_langit_test.dart` (tinta di atas
/// langit) dan `test/biru_awan/bilah_langkah_test.dart`.
@immutable
class WarnaLanjutBiruAwan {
  const WarnaLanjutBiruAwan._({
    required this.isiHero,
    required this.tintaHero,
    required this.motifHero,
    required this.garisDekor,
  });

  /// Hero dan avatar langit: `langit` (terang) / `langitGelap`.
  final Color isiHero;

  /// Teks di atas hero: navy. Putih DILARANG di atas langit (2,26:1).
  final Color tintaHero;

  /// Warna garis motif (alfa dipasang pemakai).
  final Color motifHero;

  /// Segmen bilah langkah yang belum terisi.
  final Color garisDekor;

  factory WarnaLanjutBiruAwan.dari(SidikMaterial m) {
    if (m.terang) {
      return WarnaLanjutBiruAwan._(
        isiHero: PaletLab.langit,
        tintaHero: m.tinta,
        motifHero: m.kertas,
        garisDekor: PaletLab.garisDekor,
      );
    }
    return WarnaLanjutBiruAwan._(
      isiHero: PaletLab.langitGelap,
      tintaHero: m.tinta,
      motifHero: m.tinta,
      garisDekor: m.kertasTepi,
    );
  }

  static WarnaLanjutBiruAwan of(BuildContext context) =>
      WarnaLanjutBiruAwan.dari(SidikMaterial.of(context));
}

/// Satu garis motif skala (koordinat kanvas 300 x 120).
typedef GarisMotif = ({Offset dari, Offset ke, double tebal});

/// Geometri motif skala: busur skala dengan tik dan jarum + garis penggaris
/// bertik (`docs/desain-ulang/aset/motif_skala.svg`, viewBox 300 x 120).
///
/// Repo tidak punya `flutter_svg`, dan berkas SVG tidak terdaftar sebagai aset,
/// jadi motif digambar dari koordinat yang sama. `test/biru_awan/hero_langit_test.dart`
/// membaca SVG aslinya dan mengadu setiap garisnya ke [garis].
abstract final class MotifSkala {
  static const double lebar = 300;
  static const double tinggi = 120;

  /// Poros jarum, di sudut kanan bawah kanvas.
  static const Offset poros = Offset(300, 120);
  static const double jariPoros = 9;

  /// Busur luar (tebal 3) dan busur titik-titik dalam (tebal 1,5; 2 on 6 off).
  static const double jariBusur = 110;
  static const double jariTitik = 86;
  static const double tebalBusur = 3;
  static const double tebalBusurTitik = 1.5;
  static const double titikPanjang = 2;
  static const double titikJeda = 6;

  /// 16 tik tiap 6 derajat dari atas (0) ke kiri (90); tiap kelima besar.
  static const int jumlahTik = 16;
  static const double derajatPerTik = 6;
  static const int tikBesarSetiap = 5;
  static const double tikBesarPanjang = 16;
  static const double tikKecilPanjang = 8;
  static const double tikBesarTebal = 3;
  static const double tikKecilTebal = 2;

  /// Jarum: 74 dari poros, 48 derajat dari tegak lurus ke atas; tebal 4.
  static const double jarumPanjang = 74;
  static const double jarumDerajat = 48;
  static const double jarumTebal = 4;

  /// Penggaris di dasar: garis y 118 sepanjang 180, tik tiap 10, besar tiap 50.
  static const double penggarisY = 118;
  static const double penggarisPanjang = 180;
  static const double penggarisTebal = 2.5;
  static const double penggarisJarak = 10;
  static const int penggarisBesarSetiap = 5;
  static const double penggarisBesarPanjang = 14;
  static const double penggarisKecilPanjang = 7;
  static const double penggarisBesarTebal = 2.5;
  static const double penggarisKecilTebal = 1.6;

  /// Semua garis lurus motif (tik busur, jarum, penggaris + tiknya). Busur dan
  /// lingkaran poros digambar terpisah.
  static List<GarisMotif> garis() {
    final hasil = <GarisMotif>[];
    for (var i = 0; i < jumlahTik; i++) {
      final sudut = i * derajatPerTik * math.pi / 180;
      final besar = i % tikBesarSetiap == 0;
      final panjang = besar ? tikBesarPanjang : tikKecilPanjang;
      Offset titik(double jari) => Offset(
        poros.dx - jari * math.sin(sudut),
        poros.dy - jari * math.cos(sudut),
      );
      hasil.add((
        dari: titik(jariBusur),
        ke: titik(jariBusur - panjang),
        tebal: besar ? tikBesarTebal : tikKecilTebal,
      ));
    }
    final sudutJarum = jarumDerajat * math.pi / 180;
    hasil.add((
      dari: poros,
      ke: Offset(
        poros.dx - jarumPanjang * math.sin(sudutJarum),
        poros.dy - jarumPanjang * math.cos(sudutJarum),
      ),
      tebal: jarumTebal,
    ));
    hasil.add((
      dari: const Offset(0, penggarisY),
      ke: const Offset(penggarisPanjang, penggarisY),
      tebal: penggarisTebal,
    ));
    final jumlahTikPenggaris = (penggarisPanjang / penggarisJarak).round() + 1;
    for (var i = 0; i < jumlahTikPenggaris; i++) {
      final x = i * penggarisJarak;
      final besar = i % penggarisBesarSetiap == 0;
      hasil.add((
        dari: Offset(x, penggarisY),
        ke: Offset(
          x,
          penggarisY - (besar ? penggarisBesarPanjang : penggarisKecilPanjang),
        ),
        tebal: besar ? penggarisBesarTebal : penggarisKecilTebal,
      ));
    }
    return hasil;
  }
}
