import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';
import '../calibration/category_picker_screen.dart';

/// Tugas Saya — antrean alat yang ditugaskan ke teknisi yang lagi login.
///
/// Nembak `GET /orders?teknisi_id=saya`. Sengaja pakai literal `saya`, bukan
/// ID: mobile nggak perlu tahu ID-nya sendiri, dan backend yang nerjemahin
/// dari token. Itu juga nutup celah kalau ada yang iseng ngirim ID orang lain.
///
/// **Layar ini baca doang.** Order lahir di meja depan waktu alat pelanggan
/// diterima, bukan di lapangan — backend ngunci tulis ke admin. Yang teknisi
/// lakuin di sini cuma lihat antreannya lalu mulai ngerjain.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  @override
  void initState() {
    super.initState();
    // Filter dipasang sekali di sini, bukan di provider-nya: provider yang
    // sama juga dipakai daftar order penuh buat admin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderListProvider.notifier).saring(teknisiId: 'saya');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(orderListProvider);
    final controller = ref.read(orderListProvider.notifier);

    final Widget isi = switch (async) {
      AsyncData(:final value) when value.isEmpty => _Pesan(
        ikon: Icons.inbox_outlined,
        teks: l10n.tugasKosong,
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: controller.muatUlang,
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _KartuOrder(order: value[i]),
        ),
      ),
      AsyncError() => _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: l10n.tugasLoadGagal,
        aksi: AppButton(
          label: l10n.tugasRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: controller.muatUlang,
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tugasTitle)),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.gradasiLatar(context)),
        child: isi,
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.aksi});

  final IconData ikon;
  final String teks;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              teks,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (aksi != null) ...[const SizedBox(height: AppSpacing.lg), aksi!],
          ],
        ),
      ),
    );
  }
}

class _KartuOrder extends StatelessWidget {
  const _KartuOrder({required this.order});

  final OrderKalibrasi order;

  String _tanggal(DateTime? t) =>
      t == null ? '—' : '${t.day}/${t.month}/${t.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                      Text(order.nomor, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        order.namaPelanggan,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Telat disorot duluan, sebelum status biasa — kalau janji
                // selesainya udah lewat, itu yang perlu ditangkap mata dulu.
                if (order.telat)
                  StatusBadge(
                    label: l10n.tugasTelat,
                    tone: BadgeTone.danger,
                    icon: Icons.schedule,
                  )
                else
                  StatusBadge.fromApi(order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Rincian(
                  label: l10n.tugasMasuk,
                  nilai: _tanggal(order.tanggalMasuk),
                ),
                const SizedBox(width: AppSpacing.lg),
                _Rincian(
                  label: l10n.tugasJanji,
                  nilai: _tanggal(order.tanggalJanjiSelesai),
                  sorot: order.telat,
                ),
                const Spacer(),
                Text(
                  l10n.tugasJumlahAlat(order.jumlahAlat),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: l10n.dashStartCalibration,
                icon: Icons.add_task,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoryPickerScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rincian extends StatelessWidget {
  const _Rincian({
    required this.label,
    required this.nilai,
    this.sorot = false,
  });

  final String label;
  final String nilai;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          nilai,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: sorot ? AppColors.danger : null,
            fontWeight: sorot ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}
