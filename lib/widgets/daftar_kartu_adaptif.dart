import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import 'readable_width.dart';

/// Daftar kartu yang **satu kolom di HP, dua kolom di jendela lebar**.
///
/// Dipakai buat menggantikan `ListView.separated` di layar-layar daftar. Di
/// bawah [ambang] dia benar-benar `ListView.separated` yang sama persis, jadi
/// tata letak HP nggak berubah sedikit pun — yang nambah cuma cabang buat
/// layar lebar.
///
/// ## Kenapa ada
///
/// Rangka desktop app ini (sidebar + bilah atas) sudah beda dari HP sejak
/// lama, tapi ISI layarnya belum: satu kolom kartu dibentangin ke jendela
/// 1500 dp bikin nama di kiri kepisah jauh dari tombol di kanan, dan mata
/// harus memindai bolak-balik. Bukan soal cantik-cantikan — di layar lebar,
/// isi yang nggak diatur justru lebih capek dibaca.
///
/// ## Kenapa bukan GridView
///
/// `GridView` nuntut tinggi sel yang seragam, dan kartu di layar-layar ini
/// **nggak** seragam: kartu akun pending punya empat tombol, yang nonaktif
/// cuma satu. Dipatok ke yang paling tinggi, kartu pendek nyisain lubang;
/// dipatok ke yang paling pendek, kartu panjang kepotong — itu yang kejadian
/// waktu tingginya sempat ditulis 330 (kepotong 14 px).
///
/// Jadi kolomnya dirakit tangan: kartu ganjil-genap dibagi ke dua `Column`,
/// masing-masing setinggi isinya sendiri.
///
/// ## Yang ditanggung sadar
///
/// Di cabang dua kolom, kartunya dibangun SEMUA sekaligus — nggak malas kayak
/// `ListView.builder`. Itu diterima karena daftar-daftar ini isinya data satu
/// lab (puluhan baris) yang toh sudah ada di memori dari satu panggilan API.
/// Kalau suatu hari ada daftar ratusan baris yang mau pakai ini, di sinilah
/// yang pertama harus dibalik lagi jadi malas.
class DaftarKartuAdaptif extends StatelessWidget {
  const DaftarKartuAdaptif({
    super.key,
    required this.jumlah,
    required this.bangun,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.jarak = AppSpacing.sm,
  });

  /// Ambang lebar buat pecah jadi dua kolom. Angkanya sama dengan
  /// `MasterDetailPane.ambang` — satu ambang buat satu app, bukan tiap widget
  /// punya tebakan sendiri.
  static const ambang = 900.0;

  /// Apakah jendelanya sudah masuk "layar lebar".
  ///
  /// Dipakai layar buat menyetel hal lain yang ikut berubah di situ — mis.
  /// `AppButton(ringkas: ...)` supaya tombolnya berhenti melar.
  static bool lebar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ambang;

  final int jumlah;
  final Widget Function(BuildContext context, int indeks) bangun;
  final EdgeInsetsGeometry padding;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        if (batas.maxWidth < ambang) {
          return ListView.separated(
            padding: padding,
            itemCount: jumlah,
            separatorBuilder: (_, _) => SizedBox(height: jarak),
            itemBuilder: bangun,
          );
        }

        final kiri = <Widget>[];
        final kanan = <Widget>[];
        for (var i = 0; i < jumlah; i++) {
          final kartu = Padding(
            padding: EdgeInsets.only(bottom: jarak),
            child: bangun(context, i),
          );
          (i.isEven ? kiri : kanan).add(kartu);
        }

        return ReadableWidth(
          child: SingleChildScrollView(
            // Tetap bisa ditarik walau isinya belum penuh selayar — kalau
            // nggak, tarik-buat-segarkan mati di daftar yang cuma berisi dua
            // baris.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: kiri)),
                SizedBox(width: jarak),
                Expanded(child: Column(children: kanan)),
              ],
            ),
          ),
        );
      },
    );
  }
}
