import 'package:flutter/material.dart';

/// Nahan isi layar biar berhenti melar di jendela lebar, lalu menengahkannya.
///
/// Di HP ini **no-op**: lebar layar selalu di bawah [maksimum], jadi
/// `ConstrainedBox`-nya nggak pernah kepakai dan tata letaknya persis kayak
/// sebelum ada widget ini. Yang kena cuma desktop.
///
/// Kenapa perlu: baris teks yang kelewat panjang bikin mata susah nemu awal
/// baris berikutnya, dan kartu yang dibentangin 1400px bikin label di kiri
/// sama angkanya di kanan kepisah jauh sampai harus dipindai bolak-balik.
/// Batas ini bukan soal cantik-cantikan — di layar lebar, isi yang nggak
/// dibatasi justru lebih capek dibaca.
///
/// **Ditaruh di dalam latar, bukan di luarnya.** Latar bergradasi Dashboard
/// tetap harus penuh selebar jendela; yang dibatasi cuma isinya. Kalau widget
/// ini dipasang membungkus `Container` latarnya, gradasinya ikut nyempit dan
/// nyisain dua pita kosong di kiri-kanan.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maksimum = 1040});

  /// Lebar maksimum isi. 1040 diambil dari isi terlebar yang ada sekarang —
  /// `StatCardRow` dua kolom plus grafik pekerjaan — dan masih nyisain napas
  /// di kiri-kanan waktu rail lagi dibentangin di layar 1440px.
  final double maksimum;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maksimum),
        child: child,
      ),
    );
  }
}
