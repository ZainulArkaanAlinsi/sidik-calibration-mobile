import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary }

/// Tombol standar app.
///
/// Alasan dibungkus (bukan langsung pakai `FilledButton`): state **loading**.
/// Waktu submit kalibrasi ke API, tombol harus langsung nonaktif — kalau
/// nggak, teknisi yang nggak sabar bakal mencet dua kali dan datanya dobel.
/// Dengan `isLoading`, `onPressed` otomatis diabaikan.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Ikon di kanan label — mis. panah "→" di tombol SIGN IN (desain Titanium).
  final IconData? trailingIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Lagi loading = nggak bisa dipencet, titik.
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _Content(label: label, icon: icon, trailingIcon: trailingIcon);

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
    };
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.label, this.icon, this.trailingIcon});

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    if (icon == null && trailingIcon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: AppSpacing.sm)],
        // Flexible, bukan Text polos: `mainAxisSize.min` bikin Row minta lebar
        // sesuai isinya, dan label panjang di tombol yang lebarnya dibatesin
        // (setengah layar, atau layar HP 390px) langsung overflow — error
        // merah, bukan teks kepotong. Udah kejadian dua kali di form pH.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}
