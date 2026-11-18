import 'package:flutter/widgets.dart';

/// Memanggil [saatDekatAkhir] saat gulir vertikal mendekati ujung daftar
/// (sisa [ambang] dp). Dipakai daftar paginasi kursor: halaman berikutnya
/// diminta sedikit SEBELUM pengguna sampai di dasar, jadi tidak ada jeda.
///
/// Pemanggil wajib kebal dipanggil berkali-kali (notifikasi gulir datang di
/// setiap frame); controller daftar kursor sudah menjaganya.
class PemicuGulir extends StatelessWidget {
  const PemicuGulir({
    super.key,
    required this.saatDekatAkhir,
    required this.child,
    this.ambang = 400,
  });

  final VoidCallback saatDekatAkhir;
  final Widget child;
  final double ambang;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Hanya gulir utama (kedalaman 0) dan vertikal.
        if (n.depth == 0 &&
            n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < ambang) {
          saatDekatAkhir();
        }
        return false;
      },
      child: child,
    );
  }
}
