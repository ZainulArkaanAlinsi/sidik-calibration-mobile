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
    this.ringkas = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Ikon di kanan label — mis. panah "→" di tombol SIGN IN (desain Titanium).
  final IconData? trailingIcon;
  final bool isLoading;

  /// Tombol seukuran isinya, bukan melar selebar ruang yang ada.
  ///
  /// Dipilih PER LAYAR, bukan ditebak sendiri dari lebar jendela, dan itu
  /// belajar dari kesalahan: versi pertama membungkus tombolnya dengan
  /// `LayoutBuilder` biar bisa mengukur ruangnya sendiri. Itu memecahkan 15
  /// tes dengan `LayoutBuilder does not support returning intrinsic
  /// dimensions` — `LayoutBuilder` bikin widget berhenti bisa ditanya lebar
  /// intrinsiknya, dan tabel sertifikat justru nanya.
  ///
  /// Menebak dari lebar jendela saja juga salah: tombol di formulir Login yang
  /// lebarnya dipatok ~400px bakal ikut nyusut jadi seuprit di tengah
  /// formulir, padahal di situ melar itu benar. Yang tahu bedanya cuma
  /// layarnya.
  final bool ringkas;

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

    // `minimumSize: Size.fromHeight(52)` di tema itu Size(**infinity**, 52) —
    // tombolnya selalu melar selebar ruang yang ada. [ringkas] mematahkan itu.
    final gaya = ringkas
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
          )
        : null;

    final tombol = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        style: gaya,
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        style: gaya,
        onPressed: effectiveOnPressed,
        child: child,
      ),
    };

    // Dikiri-ratakan waktu ringkas: tombol seukuran isinya yang mengambang di
    // tengah ruang lebar kelihatan kayak kelepasan dari tata letaknya.
    return ringkas
        ? Align(alignment: Alignment.centerLeft, child: tombol)
        : tombol;
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.label, this.icon, this.trailingIcon});

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;

  /// HURUF BESAR semua — `text-transform: uppercase` di desain acuannya.
  ///
  /// Dikerjakan di sini, bukan di `ThemeData`: Flutter nggak punya padanan
  /// `text-transform`, satu-satunya jalan ya mengubah string-nya. Konsekuensinya
  /// nyata dan sengaja diterima — `find.text('Simpan')` di test nggak lagi
  /// ketemu, jadi test yang nunjuk tombol lewat labelnya ikut disesuaikan.
  String get _teks => label.toUpperCase();

  @override
  Widget build(BuildContext context) {
    if (icon == null && trailingIcon == null) return Text(_teks);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: AppSpacing.sm)],
        // Flexible, bukan Text polos: `mainAxisSize.min` bikin Row minta lebar
        // sesuai isinya, dan label panjang di tombol yang lebarnya dibatesin
        // (setengah layar, atau layar HP 390px) langsung overflow — error
        // merah, bukan teks kepotong. Udah kejadian dua kali di form pH.
        Flexible(
          child: Text(_teks, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}
