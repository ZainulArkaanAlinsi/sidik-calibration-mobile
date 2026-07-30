import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/rumus.dart';
import '../../providers/rumus_provider.dart';
import '../../widgets/skeleton.dart';
import 'rumus_versi_screen.dart';

/// Daftar rumus kalibrasi + versi yang lagi berlaku.
///
/// Kenapa layar ini ada: sebelumnya rumus cuma bisa disentuh lewat panel
/// Filament di server, jadi dari HP maupun laptop pertanyaan "aturan hitungnya
/// gimana" nggak punya jawaban sama sekali.
///
/// **Yang bisa diubah di sini PARAMETER & VERSINYA, bukan cara ngitungnya.**
/// Backend nolak `sumber: database` (422) karena evaluator ekspresinya belum
/// ada — jadi rumusnya sendiri tetap di kode. Itu disebut terang-terangan di
/// layar, biar admin nggak nyari-nyari kolom yang emang nggak ada.
class RumusListScreen extends ConsumerWidget {
  const RumusListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final daftar = ref.watch(daftarRumusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rumusTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(daftarRumusProvider.notifier).muatUlang(),
        child: daftar.when(
          loading: () => const _Kerangka(),
          error: (e, _) => _Gagal(
            pesan: '$e'.replaceFirst('Exception: ', ''),
            onCobaLagi: () => ref.read(daftarRumusProvider.notifier).muatUlang(),
          ),
          data: (rumus) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.rumusKetBatasan,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (rumus.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.rumusKosong,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ...rumus.map((r) => _KartuRumus(rumus: r)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuRumus extends StatelessWidget {
  const _KartuRumus({required this.rumus});

  final Rumus rumus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final aktif = rumus.versiBerlaku;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        title: Text(rumus.nama, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${rumus.kode}${rumus.besaran != null ? ' · ${rumus.besaran}' : ''}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                // Versi berlaku itu informasi paling dicari di layar ini:
                // "yang dipakai ngitung sekarang yang mana".
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    aktif != null ? Icons.check_circle : Icons.help_outline,
                    size: 16,
                    color: aktif != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  label: Text(
                    aktif != null
                        ? l10n.rumusVersiBerlaku(aktif.nomorVersi)
                        : l10n.rumusTanpaVersiBerlaku,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(l10n.rumusJumlahVersi(rumus.jumlahVersi)),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RumusVersiScreen(rumus: rumus),
          ),
        ),
      ),
    );
  }
}

class _Kerangka extends StatelessWidget {
  const _Kerangka();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: List.generate(
      3,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: SkeletonBox(height: 96),
      ),
    ),
  );
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: AppSpacing.md),
        Text(pesan, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: FilledButton(
            onPressed: onCobaLagi,
            child: Text(l10n.rumusCobaLagi),
          ),
        ),
      ],
    );
  }
}
