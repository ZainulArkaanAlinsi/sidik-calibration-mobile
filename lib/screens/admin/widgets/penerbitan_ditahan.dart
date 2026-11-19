import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/penerbitan_ditahan.dart';
import '../../../widgets/status_badge.dart';
import '../../auth/widgets/neu.dart';

/// Banner di layar Perhitungan: penerbitan sertifikat jenis alat ini ditahan
/// menunggu Technical Manager (PR #280 API).
///
/// Isi (alasan, rujukan TM, varian) SEMUA dari server — app tidak memutuskan
/// jenis alat mana yang ditahan. Yang ditahan hanya penerbitan; kalimat di
/// banner menyebut bahwa lembar tetap bisa diisi dan dihitung, supaya admin
/// tidak mengira sesinya rusak.
///
/// Alasan dari server bisa ratusan karakter, jadi di banner dipotong tiga
/// baris dan dibaca lengkap lewat [tampilkanDialogPenerbitanDitahan].
class BannerPenerbitanDitahan extends StatelessWidget {
  const BannerPenerbitanDitahan({super.key, required this.penahanan});

  final PenerbitanDitahan penahanan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = NeuColors.of(context);
    final peringatan = AppColors.statusPeringatan(context);
    final alasan = penahanan.alasanTampil;
    final rujukan = penahanan.rujukanTampil;

    return NeuRaised(
      key: const ValueKey('banner-penerbitan-ditahan'),
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.pause_circle_outline, size: 22, color: peringatan),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.ditahanJudul,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.ditahanIsi,
            style: TextStyle(fontSize: 13, height: 1.4, color: c.text),
          ),
          if (penahanan.varian.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.ditahanVarian(penahanan.varian.join(', ')),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ],
          if (alasan != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              alasan,
              key: const ValueKey('alasan-ditahan'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
            ),
          ],
          if (rujukan != null) ...[
            const SizedBox(height: AppSpacing.sm),
            StatusBadge(
              label: l10n.ditahanRujukan(rujukan),
              tone: BadgeTone.warning,
              icon: Icons.assignment_late_outlined,
            ),
          ],
          if (alasan != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('baca-alasan-ditahan'),
                onPressed: () =>
                    tampilkanDialogPenerbitanDitahan(context, penahanan),
                child: Text(l10n.ditahanSelengkapnya),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog penjelasan penahanan: dipakai tombol "Baca alasan lengkap" di banner
/// DAN sebagai jawaban atas `422 profil_ditahan` (klien yang datanya basi, atau
/// server yang baru saja menahan jenis alat ini). Bukan SnackBar: alasan dari
/// server panjang dan harus bisa dibaca tuntas.
Future<void> tampilkanDialogPenerbitanDitahan(
  BuildContext context,
  PenerbitanDitahan penahanan,
) => showDialog<void>(
  context: context,
  builder: (_) => _DialogPenerbitanDitahan(penahanan: penahanan),
);

class _DialogPenerbitanDitahan extends StatelessWidget {
  const _DialogPenerbitanDitahan({required this.penahanan});

  final PenerbitanDitahan penahanan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final alasan = penahanan.alasanTampil;
    final rujukan = penahanan.rujukanTampil;

    return AlertDialog(
      key: const ValueKey('dialog-penerbitan-ditahan'),
      title: Text(l10n.ditahanDialogJudul),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ditahanDialogIsi),
            if (penahanan.varian.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.ditahanVarian(penahanan.varian.join(', ')),
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (alasan != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.ditahanDialogAlasan,
                style: tema.textTheme.labelMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Boleh dipilih/disalin: admin sering meneruskan rujukannya ke TM.
              SelectableText(alasan, key: const ValueKey('alasan-dialog')),
            ],
            if (rujukan != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.ditahanRujukan(rujukan),
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('tutup-dialog-ditahan'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ditahanDialogTutup),
        ),
      ],
    );
  }
}
