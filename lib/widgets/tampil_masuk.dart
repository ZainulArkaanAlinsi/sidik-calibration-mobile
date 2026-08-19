import 'package:flutter/material.dart';

import '../core/motion/app_motion.dart';

/// Kartu/bagian yang muncul dengan meredup-naik waktu layarnya kebuka.
///
/// [indeks] bikin benda yang bersebelahan datang berurutan, bukan serempak.
/// Bedanya kecil tapi kebaca: yang serempak kelihatan kayak satu gambar yang
/// di-fade, yang berurutan kelihatan kayak layar yang lagi menyusun dirinya.
///
/// ## Yang sengaja NGGAK dipakein ini
///
/// Daftar panjang yang pakai `ListView.builder`. Di situ item yang keluar
/// layar dibuang dan dibangun ulang waktu digulir balik — animasinya bakal
/// jalan LAGI tiap kali, dan daftar yang berkedip tiap discroll itu lebih
/// ganggu daripada daftar yang diam. Ini buat kartu ringkasan, bagian
/// formulir, dan daftar pendek yang seluruhnya kebangun sekaligus.
///
/// ## Kenapa nggak pakai `AnimationController`
///
/// `TweenAnimationBuilder` jalan sekali lalu ngeberesin dirinya sendiri.
/// Tundaan berurutannya diurus lewat [Interval] di dalam satu animasi — jadi
/// satu daftar 20 kartu nggak bikin 20 controller yang mesti di-dispose, dan
/// nggak ada `Timer` yang bisa kelewat dibatalin waktu layarnya keburu ditutup.
class TampilMasuk extends StatelessWidget {
  const TampilMasuk({super.key, required this.child, this.indeks = 0});

  final Widget child;

  /// Urutan benda ini di kelompoknya. 0 = duluan.
  final int indeks;

  @override
  Widget build(BuildContext context) {
    final tunda = AppMotion.tunda(context, indeks);

    // Setelan "kurangi gerak" nyala → langsung tampil apa adanya. Bukan
    // dipercepat: buat orang yang mual sama gerak layar, gerak cepat justru
    // lebih parah daripada gerak lambat.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final total = AppMotion.sedang + tunda;
    final mulai = tunda.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(mulai, 1, curve: AppMotion.masuk),
      builder: (context, t, anak) => Opacity(
        opacity: t,
        // 12 px, arah bawah ke atas. Sengaja kecil: kartu yang naik jauh
        // kebaca kayak elemen yang salah posisi terus dibetulin.
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: anak),
      ),
      child: child,
    );
  }
}
