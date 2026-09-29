import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/calibration_input_provider.dart' show standardCrudProvider;
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../widgets/app_button.dart';
import '../../widgets/daftar_kartu_adaptif.dart';
import '../../widgets/kartu_gradien.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import 'standard_form_screen.dart';

/// Layar kelola Standar Acuan — beda sama dropdown di layar kalibrasi
/// (`standardListProvider`, read-only): ini CRUD penuh, admin doang
/// (`docs/kontrak-api.md` §4, `role:admin` di routes backend).
class StandardListScreen extends ConsumerWidget {
  const StandardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standar = ref.watch(standardCrudProvider);
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.bolehkah(
      NamaIzin.standarKelola,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    final data = standar.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? const _Kosong() : _Isi(items: data, isAdmin: isAdmin);
    } else if (standar.hasError) {
      isi = _Gagal(
        pesan: standar.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.standarLoadFailed,
        onCobaLagi: () => ref.read(standardCrudProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.standarTitle)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(standardCrudProvider.notifier).muatUlang(),
              child: isi,
            ),
          ),
          if (isAdmin)
            SafeArea(
              top: false,
              // Dibatasi lebar bacanya juga, biar tombolnya sebaris sama tepi
              // kiri kolom kartu di atasnya. Tanpa ini dia nyangkut di pojok
              // layar sementara kartunya di tengah — kebaca lepas dari
              // daftarnya.
              child: ReadableWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: AppButton(
                    label: l10n.standarAdd,
                    ringkas: DaftarKartuAdaptif.lebar(context),
                    icon: Icons.add,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StandardFormScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.items, required this.isAdmin});

  final List<Standard> items;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return DaftarKartuAdaptif(
      jumlah: items.length,
      bangun: (context, index) =>
          _StandardCard(item: items[index], isAdmin: isAdmin),
    );
  }
}

class _StandardCard extends ConsumerWidget {
  const _StandardCard({required this.item, required this.isAdmin});

  final Standard item;
  final bool isAdmin;

  Future<void> _hapus(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.standarDeleteConfirmTitle),
        content: Text(l10n.standarDeleteConfirmBody(item.nama)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.custCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.custDelete),
          ),
        ],
      ),
    );

    if (yakin != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(standardCrudProvider.notifier).hapus(item.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.standarDeleteFailed(e.toString()))),
      );
    }
  }

  /// Sisa hari sampai masa berlaku habis. Null kalau tanggalnya tidak ada.
  int? get _sisaHari {
    final sampai = item.berlakuSampai;
    if (sampai == null) return null;
    final hariIni = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(sampai).difference(hariIni).inDays;
  }

  String? _keteranganBerlaku(AppLocalizations l10n) {
    final sampai = item.berlakuSampai;
    if (sampai == null) return null;
    final sisa = _sisaHari;
    if (item.masihBerlaku && sisa != null && sisa <= 30) {
      return l10n.standarHabisHari(sisa);
    }
    return l10n.standarSampai(DateFormat('d MMM yyyy').format(sampai));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subjudul = [
      item.merk,
      item.model,
    ].where((s) => s.isNotEmpty).join(' · ');

    return KartuGradien(
      judul: item.nama,
      ikon: Icons.science_outlined,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StandardFormScreen(existing: item),
        ),
      ),
      butir: [
        // Merek/model sengaja di kolom pertama: itu yang dipakai teknisi buat
        // memastikan dia megang standar yang benar, bukan nomor sertifikatnya.
        if (subjudul.isNotEmpty) ButirKartu(utama: subjudul),
        // Ketidakpastiannya `double?`, dan kolom ini DILEWATI kalau kosong.
        //
        // Sebelum ini dia dicetak langsung ke string, jadi standar yang
        // ketidakpastiannya belum diisi menampilkan "± null g" ke muka
        // pengguna. Bug lama, bukan bawaan tata letak baru ini — tapi
        // kelihatan jelas begitu angkanya naik jadi kolom sendiri, jadi
        // sekalian dibetulkan di sini.
        if (item.ketidakpastian != null)
          ButirKartu(
            utama: '± ${item.ketidakpastian} ${item.satuanKetidakpastian}',
            keterangan: 'k=${item.faktorCakupan.toStringAsFixed(0)}',
          ),
        // Masa berlaku = informasi PALING PENTING di layar ini: standar yang
        // habis bikin sertifikat yang memakainya tidak tertelusur. Dulu cuma
        // tertulis "Berlaku" tanpa tanggal, jadi standar yang habis besok
        // terlihat sama amannya dengan yang habis tahun depan.
        ButirKartu(
          utama: item.masihBerlaku
              ? l10n.standarBerlaku
              : l10n.standarKadaluarsa,
          keterangan: _keteranganBerlaku(l10n),
          warna: !item.masihBerlaku
              ? AppColors.statusBahaya(context)
              : (_sisaHari != null && _sisaHari! <= 30
                    ? AppColors.statusPeringatan(context)
                    : null),
        ),
      ],
      aksi: [
        // Hapus TIDAK lagi berupa ikon tong sampah telanjang di tiap kartu.
        // Satu ketukan meleset di daftar dua puluhan standar = dialog hapus
        // untuk standar yang salah. Sekarang di balik menu ⋮, tetap diikuti
        // dialog konfirmasi yang sama.
        if (isAdmin)
          PopupMenuButton<String>(
            tooltip: l10n.aksiLainnya,
            icon: const Icon(Icons.more_vert),
            onSelected: (_) => _hapus(context, ref),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'hapus',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.statusBahaya(context),
                  ),
                  title: Text(l10n.custDelete),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.straighten_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.standarEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.standarEmptyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).standarRetry,
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
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 160),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
