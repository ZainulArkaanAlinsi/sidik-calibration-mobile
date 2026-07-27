import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

/// QR verifikasi sertifikat — digambar di HP, **bukan** gambar kiriman backend.
///
/// Isinya cuma URL halaman verifikasi publik (`GET /verify/{qr_token}`), yang
/// sengaja bisa dibuka **tanpa login**: yang scan itu pelanggan atau auditor,
/// bukan orang lab. Karena isinya sekadar URL, QR-nya cukup digambar dari
/// string — lebih ringan daripada nunggu backend ngirim PNG, dan tetap tajam
/// di layar resolusi berapa pun sama waktu diperbesar.
///
/// Ditaruh di layar, bukan cuma di PDF, biar pelanggan yang lagi di depan
/// teknisi bisa langsung scan dari HP-nya tanpa nunggu berkasnya dikirim.
class CertificateQr extends StatelessWidget {
  const CertificateQr({super.key, required this.token, this.url});

  /// Token verifikasi dari backend. `null` = backend belum nerbitin.
  final String? token;

  /// URL utuh kalau backend ngirimnya. Lebih disukai daripada nyusun sendiri
  /// dari [token] — domain verifikasinya milik backend, dan mobile nggak boleh
  /// ikut salah kalau domainnya ganti.
  final String? url;

  /// Yang beneran digambar jadi QR. Balikin null kalau nggak ada dua-duanya.
  String? get isi {
    final u = url?.trim();
    if (u != null && u.isNotEmpty) return u;

    final t = token?.trim();
    if (t != null && t.isNotEmpty) return t;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final data = isi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.certQrJudul.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data == null)
          // Sengaja dikasih penjelasan, bukan disembunyiin diam-diam: kalau
          // QR-nya raib tanpa keterangan, teknisi ngiranya app-nya rusak.
          Text(
            l10n.certQrBelumAda,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                // Latar putih dipaksa, nggak ngikut tema: pemindai QR baca
                // kontras gelap-di-atas-terang. Di tema gelap, QR yang ngikut
                // warna latar app jadi terang-di-atas-gelap dan banyak
                // pemindai nolak bacanya.
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: QrImageView(
                data: data,
                size: 176,
                backgroundColor: Colors.white,
                // Level M: masih kebaca walau sebagian ketutup jempol atau
                // kena pantulan layar, tanpa bikin modulnya kekecilan.
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.certQrIsi,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
