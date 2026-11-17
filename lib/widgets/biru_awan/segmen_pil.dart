import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Satu pilihan di [SegmenPil].
@immutable
class SegmenPilItem<T> {
  const SegmenPilItem({required this.nilai, required this.label});

  final T nilai;
  final String label;
}

/// Segmen pil Biru Awan (`Formulir.dc.html`, "Peran"): 2 sampai 3 pilihan yang
/// saling meniadakan dalam satu jalur 56 sudut 28 berlatar `latar`; yang
/// terpilih menjadi pil navy berisi teks putih.
///
/// - Pengganti `SegmentedButton` dan `TabBar` 2 sampai 3 tab. Untuk banyak
///   tab pakai `TabGaris` (L2b).
/// - Tiap segmen adalah satu sasaran sentuh 56 dp penuh (pil di dalamnya
///   lebih kecil, sisanya bidang sentuh) dan dibaca pembaca layar sebagai
///   tombol yang terpilih atau tidak, dalam satu kelompok bernama [label].
/// - [onChanged] `null` = seluruh kelompok mati. Tombol yang tidak boleh dipakai
///   peran tidak ditampilkan (bukan dimatikan): jangan masukkan ke [item].
/// - Label membungkus (maksimum 2 baris) dan jalur tumbuh bila huruf diperbesar.
class SegmenPil<T> extends StatelessWidget {
  const SegmenPil({
    super.key,
    required this.label,
    required this.item,
    required this.nilai,
    required this.onChanged,
  }) : assert(item.length >= 2, 'Segmen butuh sedikitnya dua pilihan.');

  /// Nama kelompok untuk pembaca layar ("Peran").
  final String label;
  final List<SegmenPilItem<T>> item;
  final T nilai;

  /// `null` = mati.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final aktif = onChanged != null;

    return Semantics(
      container: true,
      label: label,
      child: Material(
        color: m.meja,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBiruAwan.hero),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: UkuranKomponenBiruAwan.segmen,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in item)
                  Expanded(
                    child: _Segmen(
                      label: i.label,
                      dipilih: i.nilai == nilai,
                      aktif: aktif,
                      onTap: aktif ? () => onChanged!(i.nilai) : null,
                      m: m,
                      w: w,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmen extends StatelessWidget {
  const _Segmen({
    required this.label,
    required this.dipilih,
    required this.aktif,
    required this.onTap,
    required this.m,
    required this.w,
  });

  final String label;
  final bool dipilih;
  final bool aktif;
  final VoidCallback? onTap;
  final SidikMaterial m;
  final WarnaBiruAwan w;

  @override
  Widget build(BuildContext context) {
    final (Color isi, Color tinta) = !aktif
        ? (dipilih ? w.isiTombolMati : m.meja, w.tintaTombolMati)
        : dipilih
        ? (m.tinta, m.kertas)
        : (m.meja, m.tinta);

    return Semantics(
      button: true,
      enabled: aktif,
      selected: dipilih,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: TekanSkala(
        aktif: aktif,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // Pil lebih kecil daripada bidang sentuhnya: sisa bantalan tetap
            // menanggapi ketukan.
            padding: const EdgeInsets.symmetric(
              horizontal: JarakBiruAwan.sisipan / 2,
              vertical: JarakBiruAwan.sisipan,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isi,
                borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: HurufBiruAwan.labelKecil.copyWith(color: tinta),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
