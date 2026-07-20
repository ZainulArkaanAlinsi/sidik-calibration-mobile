import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import 'app_button.dart';
import 'glass_surface.dart';

/// Tiga keadaan hasil kirim: lagi jalan, berhasil, gagal.
enum HasilKirim { proses, berhasil, gagal }

/// Sheet hasil pengiriman — gantinya SnackBar buat aksi yang **berat dan
/// nggak bisa dibatalin**, misal kirim sesi kalibrasi buat approval.
///
/// SnackBar itu pas buat kabar sepele: nongol sebentar, ilang sendiri, nggak
/// minta apa-apa. Kirim data kalibrasi bukan kabar sepele — teknisi baru aja
/// ngisi 60 angka, dan dia perlu kepastian yang jelas apakah kekirim atau
/// nggak, plus jalan keluar kalau gagal. Makanya hasilnya nongol sebagai
/// permukaan sendiri yang nunggu ditutup, bukan lewat begitu aja.
///
/// Blur kaca di sini aman dipakai: sheet-nya kecil, diam, dan cuma muncul
/// sesekali — beda dengan kartu di dalam daftar yang di-scroll (lihat catatan
/// di [GlassSurface]).
class ResultSheet extends StatelessWidget {
  const ResultSheet({
    super.key,
    required this.status,
    required this.judul,
    this.pesan,
    this.labelAksi,
    this.onAksi,
  });

  final HasilKirim status;
  final String judul;
  final String? pesan;

  /// Tombol utama di kanan. Kalau null, cuma tombol tutup yang dirender.
  final String? labelAksi;
  final VoidCallback? onAksi;

  /// Nampilin sheet dan nunggu sampai ditutup.
  ///
  /// Waktu [status] masih `proses`, sheet-nya nggak bisa ditutup dengan
  /// nge-tap di luar atau tombol back — biar teknisi nggak ninggalin layar
  /// pas request-nya lagi di tengah jalan dan jadi nggak tahu hasilnya.
  static Future<void> tampilkan(
    BuildContext context, {
    required HasilKirim status,
    required String judul,
    String? pesan,
    String? labelAksi,
    VoidCallback? onAksi,
  }) {
    final berjalan = status == HasilKirim.proses;

    return showModalBottomSheet<void>(
      context: context,
      isDismissible: !berjalan,
      enableDrag: !berjalan,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: !berjalan,
        child: ResultSheet(
          status: status,
          judul: judul,
          pesan: pesan,
          labelAksi: labelAksi,
          onAksi: onAksi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: GlassSurface(
        radius: 32,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gagang seret — penanda visual kalau ini permukaan yang bisa
            // ditarik turun. Waktu proses, sheet-nya emang nggak bisa ditarik,
            // tapi gagangnya tetap dirender biar bentuknya nggak loncat pas
            // status berubah jadi berhasil/gagal.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.28,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _Lencana(status: status),
            const SizedBox(height: AppSpacing.md),

            Text(
              judul,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (pesan != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                pesan!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (status != HasilKirim.proses) ...[
              const SizedBox(height: AppSpacing.lg),
              // Berhasil = satu tombol penuh. Nggak ada keputusan yang perlu
              // diambil, jadi jangan disodorin pilihan — cukup satu jalan
              // keluar yang gampang dituju jempol.
              //
              // Gagal = dua tombol, karena di situ baru ada keputusan: nyerah
              // dulu, atau ulangi. "Coba lagi" ditaruh kanan sebagai aksi utama.
              if (labelAksi == null)
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.sheetTutup,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: l10n.sheetTutup,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: labelAksi!,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onAksi?.call();
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bentuk segel bergerigi — lingkaran yang tepinya bergelombang, kayak stempel
/// atau lencana verifikasi.
///
/// Digambar dari persamaan polar `r(θ) = R + a·cos(n·θ)`, disampling rapat
/// lalu disambung jadi satu path. Cara ini dipilih daripada nyusun busur
/// satu-satu: gelombangnya mulus dengan sendirinya, dan jumlah geriginya
/// tinggal ganti satu angka.
class _SegelPainter extends CustomPainter {
  const _SegelPainter({required this.warna, required this.gerigi});

  final Color warna;
  final int gerigi;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);
    final jariUtama = size.width / 2 * 0.86;
    final tinggiGerigi = size.width / 2 * 0.14;

    final path = Path();
    const langkah = 180; // cukup rapat biar tepinya nggak kelihatan bersegi
    for (var i = 0; i <= langkah; i++) {
      final sudut = 2 * math.pi * i / langkah;
      final jari = jariUtama + tinggiGerigi * math.cos(gerigi * sudut);
      final titik = Offset(
        pusat.dx + jari * math.cos(sudut),
        pusat.dy + jari * math.sin(sudut),
      );
      i == 0
          ? path.moveTo(titik.dx, titik.dy)
          : path.lineTo(titik.dx, titik.dy);
    }
    path.close();

    canvas.drawShadow(path, warna.withValues(alpha: 0.6), 10, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(warna, Colors.white, 0.26)!, warna],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _SegelPainter old) =>
      old.warna != warna || old.gerigi != gerigi;
}

/// Lencana segel di puncak sheet — elemen pertama yang ditangkap mata, jadi
/// statusnya harus kebaca sebelum teksnya sempat dibaca.
///
/// Animasinya dua lapis dan sengaja nggak barengan: segelnya masuk dulu sambil
/// mantul (`elasticOut`), centangnya nyusul belakangan. Kalau dua-duanya masuk
/// bareng, mantulnya kebaca kayak gambar yang goyang; dipisah, kebacanya
/// "stempel ditekan, baru tandanya muncul".
class _Lencana extends StatefulWidget {
  const _Lencana({required this.status});

  final HasilKirim status;

  @override
  State<_Lencana> createState() => _LencanaState();
}

class _LencanaState extends State<_Lencana>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  late final Animation<double> _segel = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.72, curve: Curves.elasticOut),
  );

  late final Animation<double> _tanda = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.42, 1, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) = switch (widget.status) {
      HasilKirim.proses => (AppColors.info, null),
      HasilKirim.berhasil => (AppColors.success, Icons.check_rounded),
      HasilKirim.gagal => (AppColors.warning, Icons.priority_high_rounded),
    };

    // Waktu proses, segelnya diam — animasi mantul di keadaan "lagi jalan"
    // ngasih kesan selesai, padahal belum. Yang muter cuma spinner-nya.
    final berjalan = widget.status == HasilKirim.proses;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: berjalan ? const AlwaysStoppedAnimation(1.0) : _segel,
            child: CustomPaint(
              size: const Size.square(84),
              painter: _SegelPainter(warna: warna, gerigi: 10),
            ),
          ),
          if (ikon == null)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            ScaleTransition(
              scale: _tanda,
              child: Icon(ikon, color: Colors.white, size: 40),
            ),
        ],
      ),
    );
  }
}
