import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../providers/versi_provider.dart';

/// "Versi X siap — mulai ulang untuk memasang" di Windows.
///
/// `PembaruWindows` mengunduh rilis baru tiap jam, tapi memasangnya baru di
/// pembukaan berikutnya. Laptop lab biasanya dibiarkan terbuka berhari-hari,
/// jadi tanpa banner ini pembaruannya bisa menunggu tanpa ada yang tahu.
///
/// Tidak menggambar apa pun selama tidak ada pembaru (bukan Windows) atau
/// belum ada versi yang terunduh. Menekan "Nanti" cuma menyembunyikan banner;
/// pembaruannya tetap terpasang sendiri waktu aplikasi dibuka lagi.
///
/// Dipakai juga oleh Sidik Studio (pembarunya sendiri dititipkan ke
/// [pembaruWindowsProvider]).
class BannerPembaruanWindows extends ConsumerStatefulWidget {
  const BannerPembaruanWindows({super.key, this.keluar});

  /// Dipanggil sesudah skrip pemasang menyala — prosesnya WAJIB keluar supaya
  /// berkasnya bisa ditimpa. Disuntikkan di test; null = `exit(0)`.
  final void Function()? keluar;

  @override
  ConsumerState<BannerPembaruanWindows> createState() =>
      _BannerPembaruanWindowsState();
}

class _BannerPembaruanWindowsState
    extends ConsumerState<BannerPembaruanWindows> {
  bool _ditutup = false;
  bool _sedangMemasang = false;

  Future<void> _mulaiUlang() async {
    final pembaru = ref.read(pembaruWindowsProvider);
    if (pembaru == null) return;

    setState(() => _sedangMemasang = true);
    final menyala = await pembaru.terapkanKalauSiap();

    if (menyala) {
      (widget.keluar ?? () => exit(0))();
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMemasang = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).pembaruanWindowsGagal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pembaru = ref.watch(pembaruWindowsProvider);
    if (pembaru == null) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: pembaru.versiSiap,
      builder: (context, versi, _) {
        if (versi == null || _ditutup) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final warnaIsi = theme.colorScheme.onPrimaryContainer;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Material(
            key: const Key('banner_pembaruan_windows'),
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.system_update, size: 20, color: warnaIsi),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.pembaruanWindowsSiap(versi),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: warnaIsi,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.pembaruanWindowsKeterangan,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: warnaIsi,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const Key('banner_pembaruan_windows_mulai_ulang'),
                    onPressed: _sedangMemasang ? null : _mulaiUlang,
                    // Tema aplikasi memberi lebar minimum tak hingga
                    // (`Size.fromHeight`) — di dalam `Row` itu memecah layout.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(l10n.pembaruanWindowsMulaiUlang),
                  ),
                  if (!_sedangMemasang)
                    IconButton(
                      key: const Key('banner_pembaruan_windows_tutup'),
                      tooltip: l10n.pembaruanWindowsNanti,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _ditutup = true),
                      icon: Icon(Icons.close, size: 18, color: warnaIsi),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
