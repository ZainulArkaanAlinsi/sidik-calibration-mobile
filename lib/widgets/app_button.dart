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
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
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
        : _Content(label: label, icon: icon);

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
  const _Content({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}
