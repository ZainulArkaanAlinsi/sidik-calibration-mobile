import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order.dart';
import '../../../models/order_kelola.dart';
import '../../../widgets/status_badge.dart';
import '../../super_admin/widgets/format_sa.dart';

/// Kartu satu order di daftar: nomor, status, PT, jumlah alat, dan tanggal.
/// Menu ⋮ (Ubah/Hapus) hanya muncul bila [saatUbah]/[saatHapus] diberikan,
/// yaitu bila akun berizin mengelola order.
class KartuOrder extends StatelessWidget {
  const KartuOrder({
    super.key,
    required this.order,
    required this.saatBuka,
    this.saatUbah,
    this.saatHapus,
  });

  final OrderKalibrasi order;
  final VoidCallback saatBuka;
  final VoidCallback? saatUbah;
  final VoidCallback? saatHapus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    final menu = <(String, String)>[
      if (saatUbah != null) ('ubah', l10n.crudAksiUbah),
      if (saatHapus != null) ('hapus', l10n.crudAksiHapus),
    ];
    final masuk = tanggalDariServer(order.tanggalMasuk);
    final janji = tanggalDariServer(order.tanggalJanjiSelesai);
    final nama = order.namaPelanggan.trim().isEmpty
        ? '-'
        : order.namaPelanggan.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: saatBuka,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.nomor.isEmpty ? '-' : order.nomor,
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nama,
                          style: tema.textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (menu.isNotEmpty)
                    PopupMenuButton<String>(
                      key: Key('menu-order-${order.id}'),
                      tooltip: l10n.saAksiUntuk(
                        order.nomor.isEmpty ? nama : order.nomor,
                      ),
                      icon: const Icon(Icons.more_vert),
                      onSelected: (kode) {
                        if (kode == 'ubah') saatUbah?.call();
                        if (kode == 'hapus') saatHapus?.call();
                      },
                      itemBuilder: (_) => [
                        for (final (kode, label) in menu)
                          PopupMenuItem<String>(value: kode, child: Text(label)),
                      ],
                    )
                  else
                    const SizedBox(width: AppSpacing.sm),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge.fromApi(order.status),
                    if (orderTerlambat(order))
                      StatusBadge(
                        label: l10n.crudOrderTelat,
                        tone: BadgeTone.warning,
                        icon: Icons.schedule,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  [
                    l10n.crudOrderAlat(order.jumlahAlat),
                    if (masuk != null)
                      l10n.crudOrderMasuk(tanggalSa(context, masuk)),
                    if (janji != null)
                      l10n.crudOrderJanji(tanggalSa(context, janji)),
                  ].join(' · '),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
