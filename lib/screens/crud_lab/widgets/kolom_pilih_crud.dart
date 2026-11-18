import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Label kolom bergaya `AppTextField` (huruf besar di atas kotak) untuk
/// kolom yang BUKAN ketikan: pemilih PT, tanggal, teknisi. Dengan begitu satu
/// formulir tampak seragam walau isinya campuran.
class LabelKolomCrud extends StatelessWidget {
  const LabelKolomCrud({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: tema.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// Kotak yang dapat diketuk dan tampil seperti kolom isian (garis, sudut,
/// galat dari tema). Menampilkan [nilai] bila ada, kalau tidak [petunjuk].
///
/// Dibaca pembaca layar sebagai tombol dengan nama [label] + isinya.
class KotakPilihCrud extends StatelessWidget {
  const KotakPilihCrud({
    super.key,
    required this.label,
    required this.petunjuk,
    required this.saatTekan,
    this.nilai,
    this.galat,
    this.ikon = Icons.expand_more,
    this.aksiTambahan,
    this.aktif = true,
  });

  final String label;
  final String petunjuk;
  final String? nilai;
  final String? galat;
  final IconData ikon;
  final VoidCallback saatTekan;
  final bool aktif;

  /// Tombol kecil di sisi kanan kotak (mis. kosongkan tanggal).
  final Widget? aksiTambahan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final kosong = nilai == null || nilai!.isEmpty;

    final kotak = InkWell(
      onTap: aktif ? saatTekan : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          errorText: galat,
          errorMaxLines: 3,
          enabled: aktif,
          suffixIcon: ExcludeSemantics(child: Icon(ikon, size: 20)),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 24,
          ),
        ),
        child: Text(
          kosong ? petunjuk : nilai!,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: kosong
                ? tema.colorScheme.onSurfaceVariant
                : tema.colorScheme.onSurface,
          ),
        ),
      ),
    );

    final dibungkus = Semantics(
      button: true,
      enabled: aktif,
      label: kosong ? '$label, $petunjuk' : '$label, $nilai',
      excludeSemantics: true,
      onTap: aktif ? saatTekan : null,
      child: kotak,
    );
    if (aksiTambahan == null) return dibungkus;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: dibungkus),
        const SizedBox(width: AppSpacing.xs),
        aksiTambahan!,
      ],
    );
  }
}
