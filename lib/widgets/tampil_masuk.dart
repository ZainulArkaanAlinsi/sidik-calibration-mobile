import 'package:flutter/material.dart';

import '../core/motion/app_motion.dart';

/// Catatan benda mana yang animasi masuknya UDAH pernah jalan.
///
/// Dipegang `State` layarnya (`final _jejak = JejakMasuk();`) dan dioper ke
/// tiap [TampilMasuk] di daftar itu.
///
/// Ini yang bikin animasi masuk aman dipakai di `ListView.builder`. Daftar
/// yang recycle mbuang item yang keluar layar dan mbangun ulang waktu digulir
/// balik — tanpa catatan ini, animasinya jalan LAGI tiap kali, dan daftar yang
/// berkedip tiap discroll itu bikin scroll terasa berat padahal yang berat
/// cuma matanya.
class JejakMasuk {
  final Set<int> _sudah = {};

  /// `true` cuma buat pemanggil PERTAMA di indeks itu.
  bool klaim(int indeks) => _sudah.add(indeks);
}

/// Kartu/bagian yang muncul dengan meredup-naik waktu layarnya kebuka.
///
/// [indeks] bikin benda yang bersebelahan datang berurutan, bukan serempak.
/// Bedanya kecil tapi kebaca: yang serempak kelihatan kayak satu gambar yang
/// di-fade, yang berurutan kelihatan kayak layar yang lagi menyusun dirinya.
///
/// Buat daftar yang recycle (`ListView.builder` / `.separated`), operin
/// [jejak] — tanpa itu, animasinya jalan ulang tiap item digulir balik.
///
/// ## Kenapa `StatefulWidget`, bukan yang polos
///
/// Keputusan "animasi atau langsung tampil" diambil SEKALI di `initState`,
/// bukan tiap `build`. Kalau diputus di `build`, satu `setState` di tengah
/// animasi bikin widget-nya ganti bentuk dan animasinya putus di tengah jalan
/// — kartunya kelihatan nyentak. Layar di app ini rutin rebuild waktu data
/// susulan mendarat dari jaringan, jadi itu bukan kasus langka.
class TampilMasuk extends StatefulWidget {
  const TampilMasuk({
    super.key,
    required this.child,
    this.indeks = 0,
    this.jejak,
  });

  final Widget child;

  /// Urutan benda ini di kelompoknya. 0 = duluan.
  final int indeks;

  /// Catatan bersama punya layarnya. Wajib buat daftar yang recycle.
  final JejakMasuk? jejak;

  @override
  State<TampilMasuk> createState() => _TampilMasukState();
}

class _TampilMasukState extends State<TampilMasuk> {
  bool _animasi = true;

  @override
  void initState() {
    super.initState();
    // Sekali, di sini. Item yang dibangun ulang gara-gara digulir balik dapat
    // `State` baru, nanya lagi ke catatan yang sama, dan dijawab "udah".
    _animasi = widget.jejak?.klaim(widget.indeks) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    // Setelan "kurangi gerak" nyala → langsung tampil apa adanya. Bukan
    // dipercepat: buat orang yang mual sama gerak layar, gerak cepat justru
    // lebih parah daripada gerak lambat.
    if (!_animasi || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    final tunda = AppMotion.tunda(context, widget.indeks);
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
      child: widget.child,
    );
  }
}
