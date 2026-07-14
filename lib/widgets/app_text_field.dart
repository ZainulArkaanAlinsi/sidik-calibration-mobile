import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_spacing.dart';

/// Input standar app.
///
/// Varian `.measurement()` khusus buat angka hasil ukur: keyboard angka
/// (termasuk desimal & minus, karena nilai error bisa negatif) dan filter
/// karakter, biar teknisi nggak bisa ngetik huruf di kolom yang mestinya angka.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
  });

  /// Input angka hasil ukur — dipakai di worksheet kalibrasi & form OCR review.
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
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixText: suffix,
          ),
        ),
      ],
    );
  }
}
