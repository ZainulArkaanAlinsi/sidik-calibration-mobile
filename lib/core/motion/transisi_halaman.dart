import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Perpindahan halaman: yang lama meredup, yang baru naik sedikit sambil
/// muncul.
///
/// Bawaan Material di Android itu `ZoomPageTransitionsBuilder` — halamannya
/// diperbesar dari 80 % sambil di-clip. Efeknya ramai buat app yang isinya
/// tabel dan angka: tiap buka lembar kerja, seluruh tabel keliatan "meletus"
/// dari tengah. Yang di sini lebih tenang dan lebih murah — cuma opacity plus
/// geser 16 px, tanpa clip, tanpa transform skala.
///
/// **iOS & macOS sengaja NGGAK diganti.** Di situ transisi bawaannya nyatu
/// sama gestur geser-balik dari tepi layar; nimpa builder-nya bikin gestur itu
/// ilang, dan orang iOS bakal kehilangan cara balik yang mereka pakai tanpa
/// mikir. Satu animasi cantik nggak sebanding sama itu.
class TransisiHalus extends PageTransitionsBuilder {
  const TransisiHalus();

  @override
  Duration get transitionDuration => AppMotion.halaman;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    final isi = child ?? const SizedBox.shrink();

    // Setelan "kurangi gerak" nyala → langsung tampil, tanpa gerak sama
    // sekali. Dipeta ke `Duration.zero` di level tema nggak cukup: yang
    // dipakai `PageRoute` durasinya sendiri, jadi dicegat di sini.
    if (context != null && MediaQuery.disableAnimationsOf(context)) return isi;

    final masuk = CurvedAnimation(parent: animation, curve: AppMotion.masuk);

    return FadeTransition(
      opacity: masuk,
      child: SlideTransition(
        position: Tween<Offset>(
          // 16 px di layar 800 px tinggi ≈ 0,02. Cukup buat mata nangkep arah
          // "datang dari bawah", nggak cukup buat kebaca sebagai lompatan.
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(masuk),
        child: isi,
      ),
    );
  }
}
