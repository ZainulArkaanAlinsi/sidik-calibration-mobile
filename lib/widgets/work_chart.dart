import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/dashboard_summary.dart';

/// Grafik pekerjaan — batang berpasangan "masuk" vs "selesai" per periode.
///
/// Digambar manual, **bukan** pakai paket charting. Yang dibutuhin di sini
/// cuma belasan batang tanpa interaksi; narik paket chart penuh buat itu
/// nambah ukuran APK dan satu dependensi lagi yang harus diurus tiap upgrade
/// Flutter — sementara yang kepakai cuma sepersekian fiturnya.
///
/// Batang berpasangan dipilih daripada garis: yang dibandingin itu **dua
/// besaran di periode yang sama** (berapa masuk vs berapa kelar). Garis lebih
/// pas buat gerakan satu besaran sepanjang waktu, dan di sini malah bikin
/// orang ngira ada hubungan sebab-akibat antar titik.
class WorkChart extends StatelessWidget {
  const WorkChart({super.key, required this.titik});

  final List<TitikTren> titik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (titik.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Kunci(warna: AppColors.info, teks: 'Masuk'),
            const SizedBox(width: AppSpacing.md),
            _Kunci(warna: AppColors.success, teks: 'Selesai'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 148,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(
              titik: titik,
              warnaMasuk: AppColors.info,
              warnaSelesai: AppColors.success,
              warnaGaris: theme.colorScheme.outlineVariant,
              gayaLabel:
                  theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _Kunci extends StatelessWidget {
  const _Kunci({required this.warna, required this.teks});

  final Color warna;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          teks,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.titik,
    required this.warnaMasuk,
    required this.warnaSelesai,
    required this.warnaGaris,
    required this.gayaLabel,
  });

  final List<TitikTren> titik;
  final Color warnaMasuk;
  final Color warnaSelesai;
  final Color warnaGaris;
  final TextStyle gayaLabel;

  static const _tinggiLabel = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final tinggiPlot = size.height - _tinggiLabel;

    // Puncak minimal 1 biar periode yang semuanya nol nggak bikin pembagian
    // nol — dan batangnya rata di dasar, bukan menjulang penuh.
    final puncak = titik
        .expand((t) => [t.masuk, t.selesai])
        .fold<int>(1, (a, b) => a > b ? a : b);

    // Garis dasar doang. Grid penuh di grafik sependek ini lebih banyak
    // ngeramein daripada ngebantu baca.
    canvas.drawLine(
      Offset(0, tinggiPlot),
      Offset(size.width, tinggiPlot),
      Paint()
        ..color = warnaGaris
        ..strokeWidth = 1,
    );

    final lebarSlot = size.width / titik.length;
    final lebarBatang = (lebarSlot * 0.28).clamp(4.0, 18.0);
    final jarak = lebarBatang * 0.35;

    for (var i = 0; i < titik.length; i++) {
      final t = titik[i];
      final tengah = lebarSlot * i + lebarSlot / 2;

      void batang(int nilai, Color warna, double geser) {
        // Batang bernilai nol tetap dikasih tinggi 2px — biar kebaca sebagai
        // "ada periodenya, isinya nol", bukan periode yang ilang.
        final tinggi = nilai == 0
            ? 2.0
            : (nilai / puncak) * (tinggiPlot - 8);
        final kiri = tengah + geser - lebarBatang / 2;

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(kiri, tinggiPlot - tinggi, lebarBatang, tinggi),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = warna,
        );
      }

      batang(t.masuk, warnaMasuk, -(lebarBatang / 2 + jarak / 2));
      batang(t.selesai, warnaSelesai, lebarBatang / 2 + jarak / 2);

      final label = _label(t.periode);
      final tp = TextPainter(
        text: TextSpan(text: label, style: gayaLabel),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: lebarSlot);
      tp.paint(canvas, Offset(tengah - tp.width / 2, tinggiPlot + 4));
    }
  }

  /// Label sumbu dari `periode` kiriman backend.
  ///
  /// Bentuknya beda tergantung satuan, dan **mingguan itu jebakan**: backend
  /// ngirim tanggal Senin (`2026-05-04`), bukan `2026-W18`. Jadi kalau
  /// ekornya main diambil, "04" kebaca sebagai bulan April padahal itu
  /// tanggal. Buat harian & mingguan dipakai `DD/MM` biar nggak ketuker.
  ///
  ///   `2026-07`      (bulanan) -> `07`
  ///   `2026-05-04`   (harian/mingguan) -> `04/05`
  static String _label(String periode) {
    final bagian = periode.split('-');
    if (bagian.length >= 3) return '${bagian[2]}/${bagian[1]}';
    if (bagian.length == 2) return bagian[1];
    return periode;
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.titik != titik || old.gayaLabel != gayaLabel;
}
