// lib/core/theme/beku_lembar_kerja.dart
// Membekukan tampilan lembar kerja: semua yang di bawahnya membaca ThemeData
// beku (salinan tema 14 Nov 2026), bukan tema Biru Awan.
import 'package:flutter/material.dart';

import 'tema_beku.dart'; // TemaBeku.terang / TemaBeku.gelap (dibuat di L1)

class BekuLembarKerja extends StatelessWidget {
  const BekuLembarKerja({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: gelap ? TemaBeku.gelap : TemaBeku.terang,
      child: child,
    );
  }
}
