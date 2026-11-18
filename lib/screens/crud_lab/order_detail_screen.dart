import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../models/order_kelola.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/order_kelola_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../super_admin/widgets/format_sa.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'aksi_order.dart';
import 'hak_crud_lab.dart';
import 'order_form_screen.dart';

/// Satu order lengkap dengan daftar alatnya, dan tombol Ubah / Hapus bagi yang
/// berizin. Hapus yang berhasil menutup layar ini (order sudah tidak ada).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(orderKelolaDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudOrderDetailJudul)),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SkeletonBox(height: 96),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(height: 72),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 72),
              ],
            ),
          ),
          error: (e, _) => PesanLayar(
            ikon: Icons.cloud_off_outlined,
            galat: true,
            teks: e is TokenHilangException
                ? l10n.historySessionExpired
                : l10n.crudOrderDetailGagal,
            aksi: AppButton(
              label: l10n.saCobaLagi,
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(orderKelolaDetailProvider(orderId)),
            ),
          ),
          data: (order) => _Isi(order: order),
        ),
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.order});

  final OrderKalibrasi order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final boleh = ref.bolehKelolaOrder;
    final masuk = tanggalDariServer(order.tanggalMasuk);
    final janji = tanggalDariServer(order.tanggalJanjiSelesai);

    Future<void> ubah() async {
      final hasil = await Navigator.of(context).push<OrderKalibrasi>(
        MaterialPageRoute<OrderKalibrasi>(
          builder: (_) => OrderFormScreen(orderId: order.id),
        ),
      );
      if (hasil != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.crudOrderBerhasilUbah)),
          );
      }
    }

    Future<void> hapus() async {
      final ok = await hapusOrderCrud(context, ref, order);
      if (ok && context.mounted) Navigator.of(context).pop();
    }

    return ReadableWidth(
      maksimum: 720,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.nomor,
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(order.namaPelanggan, style: tema.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    [
                      if (masuk != null)
                        l10n.crudOrderMasuk(tanggalSa(context, masuk)),
                      if (janji != null)
                        l10n.crudOrderJanji(tanggalSa(context, janji)),
                      if ((order.diterimaOleh ?? '').isNotEmpty)
                        l10n.crudOrderDiterima(order.diterimaOleh!),
                    ].join('\n'),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if ((order.catatan ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.crudOrderCatatan, style: tema.textTheme.labelLarge),
                    Text(order.catatan!.trim(), style: tema.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              '${l10n.crudOrderAlatJudul} (${order.items.length})',
              style: tema.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (order.items.isEmpty)
            Text(
              l10n.crudOrderAlatKosong,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _KartuItem(item: item),
              ),
          if (boleh) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              key: const Key('ubah-order'),
              label: l10n.crudAksiUbah,
              icon: Icons.edit_outlined,
              onPressed: ubah,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              key: const Key('hapus-order'),
              label: l10n.crudOrderHapusAksi,
              icon: Icons.delete_outline,
              variant: AppButtonVariant.secondary,
              onPressed: hapus,
            ),
          ],
        ],
      ),
    );
  }
}

class _KartuItem extends StatelessWidget {
  const _KartuItem({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    Widget baris(String label, String? isi) {
      if (isi == null || isi.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: redup?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: isi.trim(), style: tema.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.namaAlat,
              style: tema.textTheme.titleSmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.serialNumber.isNotEmpty)
              Text(item.serialNumber, style: redup, maxLines: 2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.sudahDitugaskan
                  ? l10n.crudOrderTeknisiNama(item.namaTeknisi ?? '-')
                  : l10n.crudOrderBelumDibagi,
              style: tema.textTheme.bodySmall,
            ),
            baris(l10n.crudOrderKondisi, item.kondisiTerima),
            baris(l10n.crudOrderKelengkapan, item.kelengkapan),
            baris(l10n.crudOrderCatatan, item.catatan),
          ],
        ),
      ),
    );
  }
}
