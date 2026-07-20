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
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.sheetTutup,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (labelAksi != null) ...[
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lencana bulat di puncak sheet. Bentuknya timbul (bukan rata) biar jadi
/// titik berat visualnya — ini elemen pertama yang dilihat orang pas sheet
/// muncul, jadi statusnya harus kebaca sebelum teksnya sempat dibaca.
class _Lencana extends StatelessWidget {
  const _Lencana({required this.status});

  final HasilKirim status;

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) = switch (status) {
      HasilKirim.proses => (AppColors.info, null),
      HasilKirim.berhasil => (AppColors.success, Icons.check_rounded),
      HasilKirim.gagal => (AppColors.warning, Icons.priority_high_rounded),
    };

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(warna, Colors.white, 0.24)!,
            warna,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: warna.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ikon == null
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(ikon, color: Colors.white, size: 34),
      ),
    );
  }
}
