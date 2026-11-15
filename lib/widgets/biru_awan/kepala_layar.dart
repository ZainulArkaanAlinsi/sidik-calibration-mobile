import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'tombol_bulat.dart';

/// Kepala layar tab Biru Awan (`LAYAR.md` 01 Kalibrasi, A1 Beranda admin;
/// `POLA.md` §Kerangka layar): logo PT SIDIK 30 x 42, nama produk 16/800 dengan
/// keterangan 12 di bawahnya (peran atau akreditasi), lalu tombol bulat 48 di
/// kanan ([aksi]: lonceng putih, menu navy).
///
/// Teks dari pemanggil (l10n), mis. `judul: 'SIDIK Lab'`, `subjudul: 'Admin,
/// Master Data'`. [aksi] adalah [TombolBulat] berlabel; kepala tidak memuat
/// logika notifikasi atau menu. Tinggi minimum 48. Logo hiasan (disembunyikan
/// dari pembaca layar; namanya sudah ada di judul). [logo] mengganti gambar
/// bawaan (untuk tes atau logo organisasi).
class KepalaTab extends StatelessWidget {
  const KepalaTab({
    super.key,
    required this.judul,
    required this.subjudul,
    this.aksi = const [],
    this.logo,
  });

  final String judul;
  final String subjudul;
  final List<Widget> aksi;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: UkuranBiruAwan.tombolKembali,
      ),
      child: Row(
        children: [
          logo ??
              Image.asset(
                'assets/images/logo_pt_sidik.png',
                width: UkuranKomponenBiruAwan.logoLebar,
                height: UkuranKomponenBiruAwan.logoTinggi,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
          const SizedBox(width: JarakBiruAwan.blok),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HurufBiruAwan.judulBaris.copyWith(color: m.tinta),
                  ),
                ),
                Text(
                  subjudul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HurufBiruAwan.catatan.copyWith(color: m.tinta2),
                ),
              ],
            ),
          ),
          for (final a in aksi) ...[const SizedBox(width: AppSpacing.sm), a],
        ],
      ),
    );
  }
}

/// Kepala layar anak Biru Awan (layar yang di-push; `POLA.md` §Kerangka layar):
/// tombol kembali bulat 48 putih, judul 20/26·800, [nomor] opsional (mono 12) di
/// bawahnya, dan satu [aksi] opsional di kanan (tombol bulat 48 primer untuk
/// "tambah", atau [TombolSidik] 48; aksi pil 44 di artboard dipakai 48 karena
/// sasaran sentuh minimum).
///
/// [onKembali] bawaan `Navigator.maybePop`. Tombol kembali dibaca "Kembali"
/// (l10n). Judul ditandai sebagai kepala bagian untuk pembaca layar, dan
/// membungkus (maks. 2 baris). Layar anak tanpa dock.
class KepalaAnak extends StatelessWidget {
  const KepalaAnak({
    super.key,
    required this.judul,
    this.nomor,
    this.aksi,
    this.onKembali,
  });

  final String judul;

  /// Nomor KAL/..., serial: IBM Plex Mono.
  final String? nomor;
  final Widget? aksi;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: UkuranBiruAwan.tombolKembali,
      ),
      child: Row(
        children: [
          TombolBulat(
            ikon: Icons.arrow_back,
            label: l10n.biruAwanKembali,
            onPressed: onKembali ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: JarakBiruAwan.blok),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HurufBiruAwan.judulAnak.copyWith(color: m.tinta),
                  ),
                ),
                if (nomor != null)
                  Text(
                    nomor!,
                    style: HurufBiruAwan.nomor.copyWith(color: m.tinta2),
                  ),
              ],
            ),
          ),
          if (aksi != null) ...[const SizedBox(width: AppSpacing.sm), aksi!],
        ],
      ),
    );
  }
}
