import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../providers/calibration_input_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import 'calibration_input_screen.dart';
import 'ph_calibration_input_screen.dart';

/// Langkah 2: dalam satu kategori (mis. Instrumen Analitik), tampilin tiap
/// jenis alat spesifik yang punya kemampuan kalibrasi terdaftar (`GET
/// /api/categories/{kode}`, `CalibrationCapability.namaAlat` + `metode`) —
/// datanya dari lampiran akreditasi LK-285-IDN, bukan dikarang.
///
/// pH Meter dapet perlakuan khusus: dia satu-satunya jenis alat yang punya
/// form kalibrasi sendiri ([PhCalibrationInputScreen]) karena strukturnya
/// jauh lebih spesifik dari form generik (lihat komentar di layar itu).
/// Jenis alat lain semua lanjut ke [CalibrationInputScreen] generik, dengan
/// kategori udah ke-pre-fill biar teknisi nggak milih ulang.
class InstrumentPickerScreen extends ConsumerWidget {
  const InstrumentPickerScreen({super.key, required this.kategori});

  final Category kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(categoryDetailProvider(kategori.kode));
    final l10n = AppLocalizations.of(context);

    final data = detailAsync.value;

    final Widget isi;
    if (data != null) {
      final instrumen = _dedupeNamaAlat(data.kemampuan);
      isi = instrumen.isEmpty
          ? _Kosong(l10n: l10n)
          : _Isi(kategori: kategori, instrumen: instrumen);
    } else if (detailAsync.hasError) {
      isi = _Gagal(
        onCobaLagi: () => ref.invalidate(categoryDetailProvider(kategori.kode)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(kategori.nama)),
      body: isi,
    );
  }

  /// `CalibrationCapability` bisa punya beberapa baris per jenis alat (beda
  /// rentang/parameter/titik ukur — mis. pH Meter py 6 baris buat titik pH
  /// 4/7/10 generik & presisi). Buat layar pilihan, cukup 1 kartu per nama
  /// alat unik; metode-nya diambil dari baris pertama yang punya nilai.
  List<CalibrationCapability> _dedupeNamaAlat(List<CalibrationCapability> list) {
    final terlihat = <String>{};
    final hasil = <CalibrationCapability>[];
    for (final k in list) {
      if (terlihat.add(k.namaAlat)) hasil.add(k);
    }
    return hasil;
  }
}

/// Ambang jumlah alat sebelum kolom cari ditampilin — kategori kecil
/// (mis. Panjang, cuma 4 alat) nggak perlu, scroll aja udah cukup.
const _ambangCari = 6;

class _Isi extends StatefulWidget {
  const _Isi({required this.kategori, required this.instrumen});

  final Category kategori;
  final List<CalibrationCapability> instrumen;

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tampilkanCari = widget.instrumen.length > _ambangCari;
    final terfilter = _query.isEmpty
        ? widget.instrumen
        : widget.instrumen
              .where((k) => k.namaAlat.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Column(
      children: [
        if (tampilkanCari)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.calibCariInstrumenHint,
              ),
            ),
          ),
        Expanded(
          child: terfilter.isEmpty
              ? Center(child: Text(l10n.calibInstrumenTidakDitemukan))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    tampilkanCari ? 0 : AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: terfilter.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _InstrumenCard(
                    kategori: widget.kategori,
                    kemampuan: terfilter[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class _InstrumenCard extends StatelessWidget {
  const _InstrumenCard({required this.kategori, required this.kemampuan});

  final Category kategori;
  final CalibrationCapability kemampuan;

  static const _phMeter = 'pH Meter';

  /// Ikon per jenis alat — dicocokin lewat keyword nama karena
  /// `namaAlat` sumbernya teks bebas dari lampiran akreditasi (bukan enum),
  /// jadi nggak ada daftar tetap buat di-switch persis.
  IconData get _ikon {
    final n = kemampuan.namaAlat.toLowerCase();
    return switch (n) {
      _ when n.contains('ph meter') => Icons.science_outlined,
      _ when n.contains('conductivity') => Icons.bolt_outlined,
      _ when n.contains('turbidi') => Icons.blur_on_outlined,
      _ when n.contains('chlorin') => Icons.water_drop_outlined,
      _ when n.contains('viscomet') => Icons.opacity_outlined,
      _ when n.contains('refractomet') => Icons.remove_red_eye_outlined,
      _ when n.contains('do meter') => Icons.air_outlined,
      _ when n.contains('spektro') => Icons.gradient_outlined,
      _ when n.contains('autoklaf') => Icons.local_fire_department_outlined,
      _ when n.contains('thermohygro') => Icons.thermostat_outlined,
      _ when n.contains('thermo') || n.contains('termo') => Icons.device_thermostat_outlined,
      _ when n.contains('oven') || n.contains('furnace') || n.contains('bath') =>
        Icons.local_fire_department_outlined,
      _ when n.contains('inkubator') || n.contains('refrigerator') =>
        Icons.kitchen_outlined,
      _ when n.contains('timbangan') => Icons.scale_outlined,
      _ when n.contains('pipet') || n.contains('buret') || n.contains('dispensett') =>
        Icons.science_outlined,
      _ when n.contains('gelas ukur') || n.contains('labu ukur') || n.contains('picnometer') =>
        Icons.opacity_outlined,
      _ when n.contains('pressure') || n.contains('vacuum') || n.contains('manometer') =>
        Icons.speed_outlined,
      _ when n.contains('utm') || n.contains('load cell') || n.contains('proving ring') =>
        Icons.compress_outlined,
      _ when n.contains('flow') => Icons.waves_outlined,
      _ when n.contains('hydrometer') => Icons.blur_on_outlined,
      _ when n.contains('caliper') || n.contains('micrometer') || n.contains('dial') =>
        Icons.straighten_outlined,
      _ when n.contains('timer') || n.contains('stopwatch') || n.contains('tachometer') =>
        Icons.timer_outlined,
      _ when n.contains('centrifuge') => Icons.autorenew,
      _ => Icons.build_outlined,
    };
  }

  void _pilih(BuildContext context) {
    if (kemampuan.namaAlat == _phMeter) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PhCalibrationInputScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationInputScreen(kategoriAwal: kategori.kode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final metode = kemampuan.metode;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => _pilih(context),
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
                      kemampuan.namaAlat,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (metode != null && metode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.calibInstrumenMetodeLabel}: $metode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
    return Center(child: Text(l10n.calibInstrumenKosong));
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
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 140),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 100),
            ],
          ),
        ),
      ),
    );
  }
}
