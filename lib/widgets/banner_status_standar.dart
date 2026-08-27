import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../models/calibration_detail.dart';

/// Pita peringatan "ONE OR MORE STANDARD EXPIRED" di kepala sesi.
///
/// ## Kenapa ini perlu ada di HP, padahal server sudah menahan penerbitan
///
/// `status_standar` sudah dipulangkan `GET /api/calibrations/{id}` sejak
/// 25 Jul 2026 — dan sampai berkas ini ada, **nol berkas di `lib/` membacanya**.
/// Server tahu sertifikat standarnya kadaluarsa, menuliskannya di respons,
/// lalu tidak ada satu pun yang menggambarnya.
///
/// Akibatnya bukan sertifikat salah terbit — validator server tetap menahan.
/// Yang hilang WAKTU: teknisi mengerjakan lembar sampai selesai, mengirimnya,
/// lalu baru tahu ditolak karena sertifikat standar yang dipakainya lewat tiga
/// hari lalu. Satu perjalanan ke lokasi pelanggan terbuang, dan yang
/// membatalkannya sudah diketahui sejak lembarnya dibuka.
///
/// ## Kalimatnya datang dari server, dan itu disengaja
///
/// [StatusStandar.pesan] dipakai **apa adanya**, tidak diterjemahkan dan tidak
/// disusun ulang di sini. Kalimat yang sama tercetak di lembar kerja fisik,
/// dan admin mengadu layar ke kertas di mejanya. Dua kalimat yang berangkat
/// dari satu keadaan lalu berbeda karena salah satunya diedit itu justru yang
/// bikin orang berhenti percaya keduanya.
///
/// Yang DITERJEMAHKAN cuma keterangan hitungan hari di bawahnya — itu memang
/// lahir di sini, bukan kiriman server.
///
/// ## `pesan == null` → widget ini menggambar NOL piksel
///
/// Bukan pita hijau "semua aman". Semua standar berlaku itu keadaan normal,
/// dan pita berwarna yang selalu nongol berhenti dibaca — persis pola yang
/// bikin peringatan sungguhan tenggelam.
class BannerStatusStandar extends StatelessWidget {
  const BannerStatusStandar({super.key, required this.status});

  final StatusStandar? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || !s.perluBanner) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warna = s.ringkasan == StatusStandar.expired
        ? AppColors.statusBahaya(context)
        : AppColors.statusPeringatan(context);

    // Cuma yang BERMASALAH yang dirinci. Standar yang masih berlaku nggak
    // menambah keputusan apa pun di sini, dan daftar tujuh baris yang enam di
    // antaranya hijau bikin yang merah justru susah kelihatan.
    final bermasalah = s.standar
        .where((b) => b.status != StatusStandar.valid)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: warna.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            s.ringkasan == StatusStandar.expired
                ? Icons.error_outline
                : Icons.schedule,
            color: warna,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Apa adanya dari server — lihat catatan kelas.
                Text(
                  s.pesan!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: warna,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                for (final b in bermasalah) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _baris(l10n, b),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nama standar + berapa harinya, dalam kalimat yang bisa langsung
  /// ditindaklanjuti ("lewat 3 hari" / "habis 12 hari lagi").
  ///
  /// `hari_menuju_kadaluarsa` NEGATIF artinya sudah lewat. Ditulis sebagai
  /// angka positif dengan kata "lewat" — "−3 hari lagi" itu kalimat yang mesti
  /// diterjemahkan sendiri oleh yang membacanya, di layar yang justru dipakai
  /// buru-buru.
  String _baris(AppLocalizations l10n, StandarBerstatus b) {
    final nama = b.nama ?? l10n.bannerStandarTanpaNama;
    final hari = b.hariMenujuKadaluarsa;

    if (hari == null) return nama;

    return hari < 0
        ? l10n.bannerStandarLewat(nama, -hari)
        : l10n.bannerStandarSegera(nama, hari);
  }
}
