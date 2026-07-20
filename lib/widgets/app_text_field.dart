import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_spacing.dart';

/// Input standar app (gaya Titanium: label HURUF BESAR di atas field,
/// ikon di kiri, border tipis yang nebel waktu fokus).
///
/// Varian `.measurement()` khusus buat angka hasil ukur: keyboard angka
/// (termasuk desimal & minus, karena nilai error bisa negatif) + filter
/// karakter, biar teknisi nggak bisa ngetik huruf di kolom angka.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.suffix,
    this.prefixIcon,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.enabled = true,
    this.isPassword = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  /// Input angka hasil ukur — dipakai di worksheet kalibrasi & review OCR.
  factory AppTextField.measurement({
    Key? key,
    required String label,
    TextEditingController? controller,
    String? hint,
    String? errorText,
    String? satuan,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      key: key,
      label: label,
      controller: controller,
      hint: hint,
      errorText: errorText,
      suffix: satuan,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*')),
      ],
    );
  }

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final String? suffix;
  final IconData? prefixIcon;

  /// Widget di kanan label — mis. link "Lupa Password?".
  final Widget? trailing;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  /// Password: teks disembunyiin + ada tombol mata buat ngintip.
  final bool isPassword;

  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _tersembunyi = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible biar label panjang bisa turun baris, bukan overflow.
            // Kepakai waktu field disempitin (2 field sebardampingan dalam Row,
            // misal SUHU AWAL/AKHIR di form pH): label uppercase nggak muat di
            // lebar segitu. Sengaja dibiarin wrap, bukan di-ellipsis — label
            // kayak "KELEMBABAN AWAL" vs "KELEMBABAN AKHIR" beda cuma di kata
            // terakhir, jadi kalau dipotong malah nggak kebedain.
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _tersembunyi,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            helperText: widget.helperText,
            suffixText: widget.suffix,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _tersembunyi
                        ? 'Lihat password'
                        : 'Sembunyikan password',
                    icon: Icon(
                      _tersembunyi
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _tersembunyi = !_tersembunyi),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
