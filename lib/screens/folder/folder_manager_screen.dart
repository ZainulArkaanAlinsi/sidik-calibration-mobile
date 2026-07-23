import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/folder.dart';
import '../../providers/folder_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notification_bell.dart';

/// Folder Manager (spesifikasi poin 3 & 7) — menggantikan "Notifikasi" di
/// navbar bawah.
///
/// **Cuma buat menelusuri.** Foldernya kebentuk sendiri di backend (`PT /
/// tahun`) tiap sertifikat terbit, jadi nggak ada tombol "buat folder" di
/// sini: nulisnya admin doang lewat panel web, dan folder `tipe: sistem`
/// ditolak backend kalau di-rename/hapus.
///
/// Dipakai dua cara: sebagai tab navbar ([folderId] null, tanpa tombol back)
/// dan sebagai halaman sendiri waktu masuk ke sub-folder (ada tombol back —
/// spesifikasi poin 5).
class FolderManagerScreen extends ConsumerWidget {
  const FolderManagerScreen({super.key, this.folderId, this.judul});

  /// Null = folder akar (daftar PT).
  final int? folderId;

  final String? judul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(judul ?? l10n.folderTitle),
        // Ikon notifikasi di atas, bukan di navbar bawah (poin 4).
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: folderId == null
          ? const _Akar()
          : _IsiFolder(folderId: folderId!),
    );
  }
}

/// Daftar PT di tingkat paling atas.
class _Akar extends ConsumerWidget {
  const _Akar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(folderListProvider(null));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(folderListProvider(null)),
      child: switch (async) {
        AsyncData(:final value) => value.isEmpty
            ? const _Kosong()
            : _DaftarFolder(folder: value),
        AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(folderListProvider(null)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Sub-folder + file di dalam satu folder.
class _IsiFolder extends ConsumerWidget {
  const _IsiFolder({required this.folderId});

  final int folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(folderDetailProvider(folderId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(folderDetailProvider(folderId)),
      child: switch (async) {
        AsyncData(:final value) =>
          value.subFolder.isEmpty && value.file.isEmpty
              ? _Kosong(pesan: l10n.folderIsiKosong)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final f in value.subFolder) ...[
                      _KartuFolder(folder: f),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final f in value.file) ...[
                      _KartuFile(file: f),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(folderDetailProvider(folderId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DaftarFolder extends StatelessWidget {
  const _DaftarFolder({required this.folder});

  final List<Folder> folder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: folder.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _KartuFolder(folder: folder[i]),
    );
  }
}

class _KartuFolder extends StatelessWidget {
  const _KartuFolder({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final rincian = [
      if (folder.jumlahFolder != null && folder.jumlahFolder! > 0)
        l10n.folderJumlahFolder(folder.jumlahFolder!),
      if (folder.jumlahFile != null && folder.jumlahFile! > 0)
        l10n.folderJumlahFile(folder.jumlahFile!),
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(
          folder.folderSistem ? Icons.folder_special_outlined : Icons.folder_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(folder.nama, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          rincian.isEmpty ? l10n.folderIsiKosong : rincian,
          style: theme.textTheme.labelSmall,
        ),
        // Folder sistem nggak punya tombol rename/hapus — backend nolaknya,
        // jadi jangan ditawarin. Sisanya cuma bisa diurus admin di panel web.
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  FolderManagerScreen(folderId: folder.id, judul: folder.nama),
            ),
          );
        },
      ),
    );
  }
}

class _KartuFile extends StatelessWidget {
  const _KartuFile({required this.file});

  final FolderFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final rincian = [
      if (file.ukuranTerbaca != null) file.ukuranTerbaca!,
      if (file.diunggahOleh != null) file.diunggahOleh!,
    ].join(' · ');

    // Sertifikat yang PDF-nya masih digenerate belum bisa diunduh — kasih tau,
    // jangan kasih tombol yang bakal balik 404.
    final belumSiap = file.dariSertifikat && !file.sertifikatSiapDiunduh;

    return Card(
      child: ListTile(
        leading: Icon(
          file.dariSertifikat
              ? Icons.workspace_premium_outlined
              : Icons.insert_drive_file_outlined,
          color: belumSiap
              ? theme.colorScheme.outline
              : theme.colorScheme.secondary,
        ),
        title: Text(file.nama, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          belumSiap ? l10n.folderSertifikatBelumSiap : rincian,
          style: theme.textTheme.labelSmall?.copyWith(
            color: belumSiap ? theme.colorScheme.error : null,
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({this.pesan});

  final String? pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.folder_open_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan ?? l10n.folderEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (pesan == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.folderEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
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
          l10n.folderLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.folderRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
