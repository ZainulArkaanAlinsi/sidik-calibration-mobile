import 'package:flutter/material.dart';

import '../../../core/theme/tema_beku.dart';

/// Mempertahankan tema isian LAMA (garis bawah, 14 Nov 2026) untuk
/// `NeuTextField` di login dan lupa sandi, sampai dua layar itu didesain ulang.
///
/// `NeuTextField` membuat `InputDecoration.collapsed` di dalam kotak Neu miliknya
/// sendiri, tetapi `enabledBorder`/`focusedBorder` dari `inputDecorationTheme`
/// tetap berlaku (collapsed hanya mengosongkan `border`). Dengan tema lama itu
/// cuma garis tipis di bawah teks (artefak lama, terlihat di golden `login-*`);
/// dengan isian Biru Awan (kotak radius 16, L1b) jadi kotak bulat DI DALAM kotak
/// Neu. Jadi hanya `inputDecorationTheme`-nya yang dikembalikan ke nilai lama
/// (dari [TemaBeku]); warna, huruf, dan komponen lain tetap mengikuti tema app.
///
/// Dibungkus per isian di `login_screen.dart` dan `forgot_password_screen.dart`
/// (`neu.dart` tidak disentuh: diimpor `tabel_perhitungan` yang beku). Hapus
/// bersama `NeuTextField` saat login didesain ulang (L5).
class IsianNeuLama extends StatelessWidget {
  const IsianNeuLama({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: TemaBeku.untuk(context).inputDecorationTheme,
      ),
      child: child,
    );
  }
}
