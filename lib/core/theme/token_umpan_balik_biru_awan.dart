import 'package:flutter/material.dart';

import 'bentuk_lab.dart';
import 'palet_lab.dart';
import 'sidik_material.dart';
import 'sidik_theme.dart';

/// Token elemen umpan balik Biru Awan (L2, `docs/desain-ulang/ELEMEN.md` bagian
/// atas, artboard E2): toast, dialog, lembar bawah, banner, dan keadaan
/// (memuat, kosong, galat).
///
/// Berkas terpisah dari `token_komponen_biru_awan*.dart` supaya langkah paralel
/// tidak bertabrakan di berkas yang sama. Widget tidak menulis angka sendiri:
/// semua lewat nama di bawah.

/// Skala huruf elemen umpan balik. REVISI 16 Nov 2026: berat 600 untuk judul dan
/// aksi, 500 untuk banner (catatan di `HurufBiruAwan`).
abstract final class HurufUmpanBalikBiruAwan {
  static const String _inter = SidikTheme.keluarga;

  /// 15/20 · 600: judul toast.
  static const TextStyle judulToast = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
  );

  /// 13/18 · 600: label aksi di toast dan banner ("Lihat", "Pasang").
  static const TextStyle aksiPil = TextStyle(
    fontFamily: _inter,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// 14/20 · 600: banner tanpa koneksi.
  static const TextStyle bannerTanpaKoneksi = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// 14/20 · 600: banner pembaruan.
  static const TextStyle bannerPembaruan = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
}

/// Ukuran (dp) dan waktu elemen umpan balik.
abstract final class UkuranUmpanBalikBiruAwan {
  // ── Toast ───────────────────────────────────────────────────────────────
  /// Lebar maksimum kartu; di layar sempit lebarnya layar dikurangi 2 x 16.
  static const double toastLebarMaks = 420;
  static const double toastTinggiMin = 68;
  static const double toastRadius = BentukBiruAwan.kartu;

  /// Jarak dari status bar dan dari tepi samping layar.
  static const double toastJarakLuar = 16;

  /// Bantalan kartu: kiri 12, kanan 8 (tombol tutup membawa sisanya), atas dan
  /// bawah 12.
  static const double toastBantalanKanan = 8;
  static const double toastUbin = 40;
  static const double toastUbinRadius = BentukBiruAwan.tombol;
  static const double toastIkon = 20;
  static const double toastIkonTutup = 18;

  /// Tinggi pil aksi (gambar); area sentuhnya 48.
  static const double pilAksi = 40;
  static const double pilAksiBantalan = 14;

  /// Di bawah lebar kartu ini (atau huruf besar) aksi pindah ke bawah teks.
  static const double toastBertumpukDi = 320;

  /// Kartu tidak lebih tinggi dari bagian ini tinggi layar; isinya bergulir.
  static const double toastTinggiNisbiMaks = 0.5;

  static const Duration toastMasuk = Duration(milliseconds: 240);
  static const Duration toastKeluar = Duration(milliseconds: 160);
  static const Duration toastSukses = Duration(seconds: 4);
  static const Duration toastPeringatan = Duration(seconds: 6);

  /// Logo kabar masuk di dalam ubin putih.
  static const double logoKabar = 28;

  // ── Dialog ──────────────────────────────────────────────────────────────
  static const double dialogLebarHp = 340;
  static const double dialogLebarLebar = 420;
  static const double dialogBantalan = 24;
  static const double dialogUbin = 48;
  static const double dialogUbinRadius = BentukBiruAwan.ikonUbin;
  static const double dialogIkon = 24;
  static const double dialogCelah = 14;
  static const double dialogCelahTombol = 10;

  /// Lebar isi (di luar bantalan) di bawah ini: tombol bertumpuk.
  static const double dialogBertumpukDi = 240;

  // ── Lembar bawah ────────────────────────────────────────────────────────
  static const double peganganLebar = 44;
  static const double peganganTinggi = 5;
  static const double lembarBantalanAtas = 10;
  static const double lembarBantalanBawah = 20;

  /// Tombol tutup di kepala lembar (gambar 44, area sentuh 48).
  static const double lembarTutup = 44;

  // ── Banner ──────────────────────────────────────────────────────────────
  static const double bannerTanpaKoneksi = 48;
  static const double bannerPembaruan = 48;
  static const double bannerPeringatanMin = 56;
  static const double bannerPeringatanRadius = BentukBiruAwan.kartu;
  static const double bannerIkon = 18;
  static const double bannerCelah = 10;
  static const double bannerBantalanKiri = 16;
  static const double bannerBantalanKanan = 8;
  static const double bannerPeringatanAtasBawah = 10;

  // ── Keadaan ─────────────────────────────────────────────────────────────
  static const double keadaanMin = 200;
  static const double keadaanBantalan = 20;
  static const double keadaanIsiLebarMaks = 220;
  static const double motifKosongLebar = 240;
  static const double galatUbin = 48;
  static const double galatUbinRadius = BentukBiruAwan.ikonUbin;
  static const double galatIkon = 24;

  /// Spinner 36; muncul hanya bila menunggu lebih dari [spinnerTunda].
  static const double spinner = 36;
  static const double spinnerGaris = 4;
  static const Duration spinnerTunda = Duration(milliseconds: 400);

  /// Baris kerangka: 64, sudut 12, ubin 40/10, dua batang 12/6 (60 %) dan 10/5
  /// (40 %).
  static const double kerangkaBaris = 64;
  static const double kerangkaRadius = BentukBiruAwan.ikonUbin;
  static const double kerangkaUbin = 40;
  static const double kerangkaUbinRadius = BentukBiruAwan.tombol;
  static const double kerangkaBatang1 = 12;
  static const double kerangkaBatang1Radius = 6;
  static const double kerangkaBatang1Lebar = 0.6;
  static const double kerangkaBatang2 = 10;
  static const double kerangkaBatang2Radius = 5;
  static const double kerangkaBatang2Lebar = 0.4;

  /// Denyut kerangka 1,2 detik, antar baris bergeser 150 ms. Dibatasi
  /// [kerangkaDenyutMaks] siklus lalu diam (artboard menulis "infinite"):
  /// kerangka yang berdenyut tanpa akhir tidak bisa di-`pumpAndSettle`, dan
  /// WCAG 2.2.2 meminta gerak otomatis lebih dari 5 detik bisa dihentikan.
  static const Duration kerangkaDenyut = Duration(milliseconds: 1200);
  static const Duration kerangkaGeser = Duration(milliseconds: 150);
  static const int kerangkaDenyutMaks = 5;
  static const double kerangkaAlfaRendah = 0.45;
}

/// Warna elemen umpan balik yang belum ada di [SidikMaterial] atau
/// `WarnaBiruAwan`. Tidak menulis nilai mentah (kecuali dua token banner yang
/// tinggal di `PaletLab`); mengikuti pola `WarnaBiruAwan`.
@immutable
class WarnaUmpanBalikBiruAwan {
  const WarnaUmpanBalikBiruAwan._({
    required this.scrim,
    required this.bayangan,
    required this.kabarLatar,
    required this.kabarTeks,
    required this.kabarTeksKedua,
    required this.kabarUbin,
    required this.kabarAksiIsi,
    required this.kabarAksiTinta,
    required this.peringatanLatar,
    required this.peringatanIkon,
    required this.kerangka,
    required this.kerangkaKedua,
    required this.pegangan,
  });

  /// Latar redup di belakang dialog dan lembar bawah (navy 42 %).
  final Color scrim;

  /// Warna dasar bayangan (alfa dipasang di [bayanganToast], [bayanganDialog]).
  final Color bayangan;

  /// Kartu kabar masuk: latar, judul, isi, ubin logo, dan pil aksi. Pasangan
  /// terbalik terhadap halaman (terang: navy; gelap: kartu terang).
  final Color kabarLatar;
  final Color kabarTeks;
  final Color kabarTeksKedua;
  final Color kabarUbin;
  final Color kabarAksiIsi;
  final Color kabarAksiTinta;

  /// Banner peringatan data: latar kuning tipis dan ikon segitiga.
  final Color peringatanLatar;
  final Color peringatanIkon;

  /// Kerangka memuat: batang pertama dan kedua (lebih tipis dan terang).
  final Color kerangka;
  final Color kerangkaKedua;

  /// Pegangan lembar bawah (hiasan).
  final Color pegangan;

  /// Bayangan toast: sangat tipis (0 2 8, 10 %); revisi 16 Nov: bayangan berat
  /// diganti garis + bayangan tipis (toast melayang di atas isi, jadi tidak
  /// boleh tanpa pemisah sama sekali).
  List<BoxShadow> get bayanganToast => [
    BoxShadow(
      color: bayangan.withValues(alpha: 0.10),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  /// Bayangan dialog: sangat tipis (0 4 16, 14 %).
  List<BoxShadow> get bayanganDialog => [
    BoxShadow(
      color: bayangan.withValues(alpha: 0.14),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  factory WarnaUmpanBalikBiruAwan.dari(SidikMaterial m) {
    if (m.terang) {
      return WarnaUmpanBalikBiruAwan._(
        scrim: PaletLab.tinta.withValues(alpha: 0.42),
        bayangan: PaletLab.tinta,
        kabarLatar: m.tinta,
        kabarTeks: m.kertas,
        kabarTeksKedua: PaletLab.navyTeks,
        kabarUbin: PaletLab.kertas,
        kabarAksiIsi: m.kertas,
        kabarAksiTinta: m.tinta,
        peringatanLatar: PaletLab.kuningTipis,
        peringatanIkon: PaletLab.kuningTinta,
        kerangka: PaletLab.garisHalus,
        kerangkaKedua: PaletLab.netralStempel,
        pegangan: PaletLab.garisTegas,
      );
    }
    return WarnaUmpanBalikBiruAwan._(
      scrim: PaletLab.latarGelap.withValues(alpha: 0.72),
      bayangan: PaletLab.latarGelap,
      kabarLatar: m.tinta,
      kabarTeks: m.kertas,
      kabarTeksKedua: PaletLab.kabutGelap,
      kabarUbin: PaletLab.kertas,
      kabarAksiIsi: m.kertas,
      kabarAksiTinta: m.tinta,
      peringatanLatar: m.awasTipis,
      peringatanIkon: m.awas,
      kerangka: m.kertasTepi,
      kerangkaKedua: m.meja2,
      pegangan: PaletLab.garisTegasGelap,
    );
  }

  static WarnaUmpanBalikBiruAwan of(BuildContext context) =>
      WarnaUmpanBalikBiruAwan.dari(SidikMaterial.of(context));
}
