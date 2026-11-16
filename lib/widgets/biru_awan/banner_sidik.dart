import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'toast_sidik.dart';

/// Ragam [BannerSidik].
enum RagamBannerSidik {
  /// Bilah navy 48 sudut 12: "Tanpa koneksi. Data terakhir 08.42".
  tanpaKoneksi,

  /// Bilah biru muda 48 sudut 12 dengan tombol navy: "Versi baru tersedia" +
  /// "Pasang".
  /// Pembaruan WAJIB memakai dialog, bukan banner.
  pembaruan,

  /// Kartu krem sudut 16: standar segera habis, server lambat.
  peringatan,
}

/// Banner Biru Awan (`ELEMEN.md` §Banner). Menempel di bawah kepala layar,
/// bukan melayang: pemanggil menaruhnya di `Column` (komponen ini selebar
/// induknya dan tidak memosisikan dirinya).
///
/// - Teks dari pemanggil (l10n); komponen tidak menulis kata apa pun, juga
///   tidak mengarang waktu "data terakhir".
/// - Pembaca layar: satu simpul berlabel [teks] berupa live region (`status`),
///   ikon hiasan, [aksi] dan tombol tutup simpul tombol sendiri.
/// - [aksi] hanya untuk [RagamBannerSidik.pembaruan]; [onTutup] hanya untuk
///   [RagamBannerSidik.peringatan] (tombol tutup sasaran 48). Pil aksi
///   bergambar 40, sasaran 48, cincin fokus di luar (>= 3:1 terhadap latar banner).
/// - Teks membungkus bila panjang atau huruf diperbesar; banner ikut tumbuh.
class BannerSidik extends StatelessWidget {
  const BannerSidik.tanpaKoneksi({super.key, required this.teks})
    : ragam = RagamBannerSidik.tanpaKoneksi,
      aksi = null,
      onAksi = null,
      onTutup = null;

  const BannerSidik.pembaruan({
    super.key,
    required this.teks,
    required String this.aksi,
    required this.onAksi,
  }) : ragam = RagamBannerSidik.pembaruan,
       onTutup = null;

  const BannerSidik.peringatan({super.key, required this.teks, this.onTutup})
    : ragam = RagamBannerSidik.peringatan,
      aksi = null,
      onAksi = null;

  final RagamBannerSidik ragam;
  final String teks;
  final String? aksi;
  final VoidCallback? onAksi;
  final VoidCallback? onTutup;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final u = WarnaUmpanBalikBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);

    final (
      Color latar,
      Color tinta,
      Color ikonWarna,
      IconData ikon,
      TextStyle gaya,
      double tinggiMin,
      double radius,
    ) = switch (ragam) {
      RagamBannerSidik.tanpaKoneksi => (
        m.tinta,
        m.kertas,
        m.kertas,
        Icons.wifi_off_rounded,
        HurufUmpanBalikBiruAwan.bannerTanpaKoneksi,
        UkuranUmpanBalikBiruAwan.bannerTanpaKoneksi,
        BentukBiruAwan.saringan,
      ),
      // Pembaruan opsional: kotak biru muda (kabut) yang tenang, bukan bidang
      // langit penuh (REVISI 16 Nov 2026).
      RagamBannerSidik.pembaruan => (
        m.biruTipis,
        m.tinta,
        m.biruTinta,
        Icons.download_rounded,
        HurufUmpanBalikBiruAwan.bannerPembaruan,
        UkuranUmpanBalikBiruAwan.bannerPembaruan,
        BentukBiruAwan.saringan,
      ),
      RagamBannerSidik.peringatan => (
        u.peringatanLatar,
        m.tinta,
        u.peringatanIkon,
        Icons.warning_amber_rounded,
        HurufBiruAwan.keterangan,
        UkuranUmpanBalikBiruAwan.bannerPeringatanMin,
        UkuranUmpanBalikBiruAwan.bannerPeringatanRadius,
      ),
    };

    final peringatan = ragam == RagamBannerSidik.peringatan;
    final bantalanKanan = (aksi != null || onTutup != null)
        ? UkuranUmpanBalikBiruAwan.bannerBantalanKanan
        : UkuranUmpanBalikBiruAwan.bannerBantalanKiri;

    final Widget teksNode = Semantics(
      container: true,
      liveRegion: true,
      label: teks,
      excludeSemantics: true,
      child: Text(teks, style: gaya.copyWith(color: tinta)),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: latar,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tinggiMin),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              UkuranUmpanBalikBiruAwan.bannerBantalanKiri,
              peringatan
                  ? UkuranUmpanBalikBiruAwan.bannerPeringatanAtasBawah
                  : AppSpacing.xs,
              bantalanKanan,
              peringatan
                  ? UkuranUmpanBalikBiruAwan.bannerPeringatanAtasBawah
                  : AppSpacing.xs,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    ikon,
                    size: UkuranUmpanBalikBiruAwan.bannerIkon,
                    color: ikonWarna,
                  ),
                ),
                const SizedBox(width: UkuranUmpanBalikBiruAwan.bannerCelah),
                Expanded(child: teksNode),
                if (aksi != null)
                  PilAksiSidik(
                    label: aksi!,
                    onPressed: onAksi,
                    isi: m.tinta,
                    tinta: m.kertas,
                    cincin: m.tinta,
                  ),
                if (onTutup != null)
                  TombolTutupSidik(
                    label: l10n.biruAwanTutup,
                    onPressed: onTutup,
                    warnaIkon: m.tinta,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
