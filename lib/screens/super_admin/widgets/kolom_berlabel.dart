import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../../../widgets/app_text_field.dart';

/// [AppTextField] + label semantik untuk pembaca layar.
///
/// `AppTextField` menggambar labelnya sebagai `Text` terpisah di atas kotak,
/// bukan `labelText`, jadi kotak isiannya sendiri tidak punya nama untuk
/// TalkBack. Pembungkus `Semantics` ini menempelkan nama itu ke node kotaknya
/// tanpa mengubah tampilan sedikit pun.
class KolomBerlabel extends StatelessWidget {
  const KolomBerlabel({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.enabled = true,
    this.onSubmitted,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: AppTextField(
        label: label,
        controller: controller,
        errorText: errorText,
        helperText: helperText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        isPassword: isPassword,
        enabled: enabled,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
      ),
    );
  }
}
