import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';

/// Chip saring Biru Awan (`ELEMEN.md`, REVISI 16 Nov 2026): kotak 44 bersudut
/// 12 + bulatan jumlah 32; satu pilihan saring dengan jumlah hasilnya di
/// bulatan di ujung.
///
/// - Terpilih: biru muda + tepi biru 2 dp + kata navy (bukan blok navy penuh;
///   biru muda sendirian cuma 1,1:1 di atas putih, jadi tepi membawa pilihan).
///   Belum terpilih: putih bertepi kontrol.
/// - [jumlah] opsional; warna bulatannya dari [isiJumlah] (kuning untuk
///   "perlu dicek", koral untuk "ada FAIL", netral untuk sisanya). Jumlah SELALU
///   angka tertulis, tidak hanya warna.
/// - Gambarnya 44, area sentuhnya >= 48 (bidang transparan di atas dan bawah
///   ikut menanggapi ketukan).
/// - [onTap] `null` = mati. Label lebih dari 220 dp dipotong titik-titik.
/// - Pembaca layar menerima "label, jumlah" dan status terpilih.
///
/// Satu chip saja; barisnya (geser mendatar, jarak 8) disusun pemanggil.
class ChipSaring extends StatelessWidget {
  const ChipSaring({
    super.key,
    required this.label,
    required this.terpilih,
    required this.onTap,
    this.jumlah,
    this.isiJumlah = IsiBiruAwan.netral,
  });

  final String label;
  final bool terpilih;

  /// `null` = mati.
  final VoidCallback? onTap;
  final int? jumlah;
  final IsiBiruAwan isiJumlah;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final aktif = onTap != null;

    final (Color isi, Color tinta, Color tepi) = !aktif
        ? (m.kertas, w.tintaTombolMati, m.kertasTepi)
        : terpilih
        ? (m.biruTipis, m.tinta, m.biru)
        : (m.kertas, m.tinta, m.garisTegas);
    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukBiruAwan.saringan),
      side: BorderSide(
        color: tepi,
        width: aktif && terpilih ? AppUkuran.garisTebal : AppUkuran.garis,
      ),
    );

    final kiri = AppSpacing.md;
    final kanan = jumlah == null ? AppSpacing.md : JarakBiruAwan.sisipan;

    final pil = Material(
      color: isi,
      shape: bentuk,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: bentuk,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UkuranBiruAwan.chip),
          child: Padding(
            padding: EdgeInsets.only(left: kiri, right: kanan),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppUkuran.labelChipMaks,
                    ),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HurufBiruAwan.labelKecil.copyWith(color: tinta),
                    ),
                  ),
                ),
                if (jumlah != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _Jumlah(jumlah: jumlah!, isi: isiJumlah, w: w),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: aktif,
      selected: terpilih,
      label: jumlah == null ? label : l10n.biruAwanChipJumlah(label, jumlah!),
      onTap: onTap,
      excludeSemantics: true,
      child: TekanSkala(
        aktif: aktif,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppUkuran.sasaranSentuh,
            ),
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1,
              heightFactor: 1,
              child: pil,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulatan jumlah di ujung chip: tinggi minimum 32, melebar untuk angka panjang.
class _Jumlah extends StatelessWidget {
  const _Jumlah({required this.jumlah, required this.isi, required this.w});

  final int jumlah;
  final IsiBiruAwan isi;
  final WarnaBiruAwan w;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: UkuranKomponenBiruAwan.jumlahChip,
        minHeight: UkuranKomponenBiruAwan.jumlahChip,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: w.isi(isi),
          borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: JarakBiruAwan.sisipan,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              '$jumlah',
              style: HurufBiruAwan.labelKecil.copyWith(color: w.tinta(isi)),
            ),
          ),
        ),
      ),
    );
  }
}
