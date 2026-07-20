import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import 'instrument_picker_screen.dart';

/// Langkah 1 dari alur "Mulai Kalibrasi": pilih salah satu dari 10 kategori
/// besar (lampiran akreditasi LK-285-IDN) dulu, baru lanjut ke
/// [InstrumentPickerScreen] buat milih jenis alat spesifik di dalamnya.
///
/// Sebelumnya "Mulai Kalibrasi" langsung ke [CalibrationInputScreen] dengan
/// dropdown kategori generik — layar ini nggak ganti form itu, cuma nambah
/// langkah pemilihan di depannya biar makin jelas alurnya, terutama buat
/// kategori yang jenis alatnya banyak & beda-beda metode (`instrumen-analitik`
/// sendiri punya 8 jenis alat).
class CategoryPickerScreen extends ConsumerWidget {
  const CategoryPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriAsync = ref.watch(categoryListProvider);
    final l10n = AppLocalizations.of(context);

    final data = kategoriAsync.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? _Kosong(l10n: l10n) : _Isi(items: data);
    } else if (kategoriAsync.hasError) {
      isi = _Gagal(onCobaLagi: () => ref.invalidate(categoryListProvider));
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibPilihKategoriTitle)),
      body: isi,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.items});

  final List<Category> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          l10n.calibPilihKategoriSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final kategori in items) ...[
          _KategoriCard(kategori: kategori),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _KategoriCard extends ConsumerWidget {
  const _KategoriCard({required this.kategori});

  final Category kategori;

  IconData get _ikon => switch (kategori.kode) {
    'suhu-dan-kelembapan' => Icons.thermostat_outlined,
    'massa' => Icons.scale_outlined,
    'volume' => Icons.opacity_outlined,
    'tekanan' => Icons.speed_outlined,
    'gaya' => Icons.compress_outlined,
    'aliran' => Icons.waves_outlined,
    'densitas' => Icons.blur_on_outlined,
    'panjang' => Icons.straighten_outlined,
    'waktu-dan-frekuensi' => Icons.timer_outlined,
    'instrumen-analitik' => Icons.biotech_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Dipakai juga sama InstrumentPickerScreen pas kategori ini beneran
    // dibuka — Riverpod nge-cache hasilnya, jadi nampilin jumlah di sini
    // nggak nambah request pas user lanjut masuk.
    final jumlah = ref.watch(categoryDetailProvider(kategori.kode)).value?.kemampuan.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InstrumentPickerScreen(kategori: kategori),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _ikon,
                  size: 21,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kategori.nama,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (jumlah != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.calibJumlahAlat(jumlah),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(l10n.calibKategoriKosong));
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.calibLoadPilihanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.calibRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: SkeletonBox(height: 20, width: 160),
        ),
      ),
    );
  }
}
