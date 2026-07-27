import 'package:flutter/material.dart';

/// Panel ganda: daftar di kiri, detail di kanan — **cuma kalau ruangnya cukup**.
///
/// Di HP (dan jendela desktop yang disempitin) ini balik jadi satu panel:
/// [master] doang, dan layar detailnya dibuka lewat `Navigator.push` seperti
/// biasa. Widget ini nggak ngatur navigasi itu — layar pemanggilnya yang
/// mutusin, karena cuma dia yang tau layar detailnya apa. Yang diatur di sini
/// murni tata letak.
///
/// Kenapa perlu: di jendela 1440px, buka detail sesi lewat push berarti
/// seluruh layar ketimpa satu halaman, lalu harus back buat balik ke daftar.
/// Buat admin yang lagi memeriksa sesi satu per satu, itu bolak-balik terus.
/// Dengan panel ganda, daftarnya tetap kelihatan dan yang berganti cuma isi
/// kanannya.
class MasterDetailPane extends StatelessWidget {
  const MasterDetailPane({
    super.key,
    required this.master,
    required this.detail,
    required this.kosong,
    this.lebarMaster = 380,
    this.ambang = 900,
  });

  /// Daftarnya. Selalu dirender, di lebar apa pun.
  ///
  /// Builder, bukan widget jadi, karena daftarnya perlu tau lagi mode apa:
  /// waktu panel ganda aktif, tap kartu mesti **mengganti isi panel kanan**;
  /// waktu satu panel, tap mesti `Navigator.push`. Cuma widget ini yang tau
  /// jawabannya, jadi dia yang ngasih tau — bukan pemanggilnya nebak sendiri
  /// lewat `MediaQuery` yang belum tentu sama hasilnya.
  final Widget Function(BuildContext context, bool panelGanda) master;

  /// Isi panel kanan. `null` = belum ada yang dipilih → [kosong] yang tampil.
  final Widget? detail;

  /// Ditampilkan di panel kanan waktu belum ada yang dipilih. Sengaja wajib,
  /// bukan opsional: panel kanan yang kosong melompong tanpa penjelasan
  /// kebaca kayak layar gagal muat.
  final Widget kosong;

  /// Lebar panel daftar. Tetap, bukan proporsional — daftar sesi isinya
  /// kartu dengan lebar nyaman yang sama di layar mana pun; yang pantas
  /// melar itu panel detailnya.
  final double lebarMaster;

  /// Ambang **lebar ruang yang tersedia**, bukan lebar jendela. Rail navigasi
  /// udah motong duluan, jadi yang diukur di sini sisa ruang buat isi layar.
  /// 900 dipilih supaya panel detail masih kebagian >= 520px — di bawah itu
  /// tabel titik ukur di detail kalibrasi mulai sesak.
  final double ambang;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ambang) return master(context, false);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: lebarMaster, child: master(context, true)),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: detail ?? kosong),
          ],
        );
      },
    );
  }
}

/// Isi panel kanan waktu belum ada yang dipilih.
class PanePlaceholder extends StatelessWidget {
  const PanePlaceholder({
    super.key,
    required this.icon,
    required this.judul,
    required this.pesan,
  });

  final IconData icon;
  final String judul;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final redup = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: redup.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: redup),
            ),
            const SizedBox(height: 4),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: redup),
            ),
          ],
        ),
      ),
    );
  }
}
