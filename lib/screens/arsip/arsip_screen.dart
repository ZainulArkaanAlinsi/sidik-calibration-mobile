import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/arsip.dart';
import '../../providers/arsip_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/skeleton.dart';
import '../history/calibration_detail_screen.dart';

/// Arsip — daftar folder perusahaan, pintu masuk ke file manager.
///
/// Isi tiap folder dibuka di [FolderScreen]. Dipisah dua layar (bukan satu
/// layar yang ganti-ganti isi) supaya tombol "back" HP jalan sebagai "naik satu
/// folder" tanpa perlu nyimpen tumpukan navigasi sendiri.
class ArsipScreen extends ConsumerStatefulWidget {
  const ArsipScreen({super.key});

  @override
  ConsumerState<ArsipScreen> createState() => _ArsipScreenState();
}

class _ArsipScreenState extends ConsumerState<ArsipScreen> {
  final _cari = TextEditingController();
  String _kataKunci = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(arsipPerusahaanProvider(_kataKunci));

    return Container(
      decoration: BoxDecoration(gradient: AppColors.gradasiLatar(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.arsipTitle)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _cari,
                decoration: InputDecoration(
                  hintText: l10n.arsipCariPerusahaan,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                // Dicari waktu selesai ngetik, bukan tiap huruf — tiap
                // perubahan bikin request baru ke server.
                onSubmitted: (v) => setState(() => _kataKunci = v),
              ),
            ),
            Expanded(
              child: switch (async) {
                AsyncData(:final value) => value.isEmpty
                    ? _Kosong(pesan: l10n.arsipPerusahaanKosong)
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(
                          arsipPerusahaanProvider(_kataKunci),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: value.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) =>
                              _KartuPerusahaan(perusahaan: value[i]),
                        ),
                      ),
                AsyncError() => _Gagal(
                    onCobaLagi: () =>
                        ref.invalidate(arsipPerusahaanProvider(_kataKunci)),
                  ),
                _ => const _Skeleton(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPerusahaan extends StatelessWidget {
  const _KartuPerusahaan({required this.perusahaan});

  final ArsipPerusahaan perusahaan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SoftRaised(
      radius: AppSpacing.radiusLg + 4,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FolderScreen(
            alamat: AlamatFolder.perusahaan(perusahaan.id),
            judul: perusahaan.nama,
          ),
        ),
      ),
      child: Row(
        children: [
          _IkonFolder(warna: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perusahaan.nama,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (perusahaan.alamat.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    perusahaan.alamat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.arsipRingkasPerusahaan(
                    perusahaan.jumlahAlat,
                    perusahaan.jumlahSertifikat,
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Isi satu folder: breadcrumb + subfolder + berkas, plus aksi nyusun.
class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.alamat, required this.judul});

  final AlamatFolder alamat;
  final String judul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(arsipIsiFolderProvider(alamat));
    final isi = async.value;

    return Container(
      decoration: BoxDecoration(gradient: AppColors.gradasiLatar(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(isi?.namaFolder ?? judul)),
        floatingActionButton: isi == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _dialogNamaFolder(
                  context,
                  ref,
                  judul: l10n.arsipFolderBaru,
                  aksiLabel: l10n.arsipBuat,
                  onSimpan: (nama) => ref
                      .read(arsipAksiProvider)
                      .bikin(parentId: isi.folderId, nama: nama),
                  pesanSukses: l10n.arsipDibuat,
                  alamat: alamat,
                ),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.arsipFolderBaru),
              ),
        body: switch (async) {
          AsyncData(:final value) => _IsiFolder(isi: value, alamat: alamat),
          AsyncError() => _Gagal(
              onCobaLagi: () => ref.invalidate(arsipIsiFolderProvider(alamat)),
            ),
          _ => const _Skeleton(),
        },
      ),
    );
  }
}

class _IsiFolder extends ConsumerWidget {
  const _IsiFolder({required this.isi, required this.alamat});

  final ArsipIsiFolder isi;
  final AlamatFolder alamat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(arsipIsiFolderProvider(alamat)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          // Ruang buat FAB biar item terakhir nggak ketutupan.
          96,
        ),
        children: [
          if (isi.breadcrumb.length > 1) ...[
            _Breadcrumb(jejak: isi.breadcrumb, sekarang: isi.folderId),
            const SizedBox(height: AppSpacing.md),
          ],

          if (isi.kosong)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: _Kosong(pesan: l10n.arsipFolderKosong),
            ),

          for (final folder in isi.subfolder) ...[
            _KartuFolder(folder: folder, alamat: alamat),
            const SizedBox(height: AppSpacing.sm),
          ],

          for (final berkas in isi.berkas) ...[
            _KartuBerkas(berkas: berkas),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Jejak akar → folder sekarang. Tiap langkah bisa ditap buat lompat balik.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.jejak, required this.sekarang});

  final List<ArsipBreadcrumb> jejak;
  final int sekarang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      radius: AppSpacing.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        // Pohon dalam bikin jejaknya lebih panjang dari layar — digeser,
        // bukan dipotong, biar teknisi tetap tahu dia lagi di mana.
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            for (var i = 0; i < jejak.length; i++) ...[
              if (i > 0)
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                // Langkah terakhir = folder yang lagi dibuka, nggak bisa ditap.
                onTap: jejak[i].id == sekarang
                    ? null
                    : () => Navigator.of(context).popUntil(
                        (route) => route.settings.name == 'folder-${jejak[i].id}' || route.isFirst,
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    jejak[i].nama,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: jejak[i].id == sekarang
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: jejak[i].id == sekarang
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KartuFolder extends ConsumerWidget {
  const _KartuFolder({required this.folder, required this.alamat});

  final ArsipFolder folder;
  final AlamatFolder alamat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SoftRaised(
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'folder-${folder.id}'),
          builder: (_) => FolderScreen(
            alamat: AlamatFolder.folder(folder.id),
            judul: folder.nama,
          ),
        ),
      ),
      child: Row(
        children: [
          _IkonFolder(
            warna: folder.isRoot
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.nama,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.arsipRingkasFolder(
                    folder.jumlahSubfolder,
                    folder.jumlahBerkas,
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Folder akar diatur sistem — menunya sengaja nggak ada, bukan ada
          // tapi ditolak 422 waktu dipencet.
          if (!folder.isRoot)
            _MenuFolder(folder: folder, alamat: alamat)
          else
            Tooltip(
              message: l10n.arsipFolderSistem,
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuFolder extends ConsumerWidget {
  const _MenuFolder({required this.folder, required this.alamat});

  final ArsipFolder folder;
  final AlamatFolder alamat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'nama', child: Text(l10n.arsipGantiNama)),
        PopupMenuItem(
          value: 'hapus',
          // Folder berisi ditolak backend — tombolnya dimatiin duluan biar
          // teknisi nggak nabrak error yang bisa dicegah.
          enabled: folder.kosong,
          child: Text(
            folder.kosong ? l10n.arsipHapus : l10n.arsipTakBisaHapus,
            style: TextStyle(
              color: folder.kosong ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
      ],
      onSelected: (pilihan) {
        if (pilihan == 'nama') {
          _dialogNamaFolder(
            context,
            ref,
            judul: l10n.arsipGantiNama,
            aksiLabel: l10n.arsipSimpan,
            nilaiAwal: folder.nama,
            onSimpan: (nama) => ref
                .read(arsipAksiProvider)
                .ubahNama(folderId: folder.id, nama: nama),
            pesanSukses: l10n.arsipDiubah,
            alamat: alamat,
          );
        } else {
          _konfirmasiHapus(context, ref, folder: folder, alamat: alamat);
        }
      },
    );
  }
}

class _KartuBerkas extends StatelessWidget {
  const _KartuBerkas({required this.berkas});

  final ArsipBerkas berkas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final terbit = berkas.nomorSertifikat != null;

    return SoftRaised(
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CalibrationDetailScreen(calibrationId: berkas.id),
        ),
      ),
      child: Row(
        children: [
          Icon(
            terbit
                ? Icons.workspace_premium_outlined
                : Icons.description_outlined,
            color: terbit ? AppColors.success : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  berkas.nomorSertifikat ?? berkas.nomorSesi ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  terbit
                      ? '${berkas.namaAlat ?? ''} · ${berkas.namaTeknisi ?? ''}'
                      : l10n.arsipBerkasTanpaSertifikat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- dialog

/// Dialog satu kolom nama, dipakai buat "folder baru" dan "ganti nama".
///
/// Pesan error sengaja diambil apa adanya dari backend (mis. "Di folder ini
/// udah ada folder dengan nama yang sama.") — dia yang paling tahu aturannya,
/// dan nulis ulang di sini cuma bikin dua versi kalimat yang bisa beda.
Future<void> _dialogNamaFolder(
  BuildContext context,
  WidgetRef ref, {
  required String judul,
  required String aksiLabel,
  required Future<String?> Function(String nama) onSimpan,
  required String pesanSukses,
  required AlamatFolder alamat,
  String? nilaiAwal,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final nama = await showDialog<String>(
    context: context,
    builder: (_) => _DialogNama(
      judul: judul,
      aksiLabel: aksiLabel,
      nilaiAwal: nilaiAwal,
    ),
  );

  if (nama == null || nama.isEmpty) return;

  final error = await onSimpan(nama);

  messenger.showSnackBar(SnackBar(content: Text(error ?? pesanSukses)));
  // Sekeluarga, bukan cuma folder yang lagi dibuka: bikin subfolder di sini
  // ngubah angka "n folder · n berkas" di kartu folder INDUK juga. Kalau cuma
  // yang ini di-invalidate, layar induk nampilin hitungan basi begitu di-back.
  if (error == null) ref.invalidate(arsipIsiFolderProvider);
}

/// Dialognya yang punya controller-nya sendiri, bukan fungsi pemanggil.
///
/// Kalau controller-nya dibikin di luar lalu di-`dispose()` persis setelah
/// `showDialog` balik, `TextField`-nya masih hidup selama animasi nutup dan
/// Flutter langsung assert (`_dependents.isEmpty`). Dengan `State`, umur
/// controller ngikut umur widget-nya — beres sendiri.
class _DialogNama extends StatefulWidget {
  const _DialogNama({
    required this.judul,
    required this.aksiLabel,
    this.nilaiAwal,
  });

  final String judul;
  final String aksiLabel;
  final String? nilaiAwal;

  @override
  State<_DialogNama> createState() => _DialogNamaState();
}

class _DialogNamaState extends State<_DialogNama> {
  late final _controller = TextEditingController(text: widget.nilaiAwal);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simpan() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.judul),
      content: AppTextField(
        label: l10n.arsipNamaFolder,
        controller: _controller,
        hint: l10n.arsipNamaFolderHint,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _simpan(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.arsipBatal),
        ),
        FilledButton(onPressed: _simpan, child: Text(widget.aksiLabel)),
      ],
    );
  }
}

Future<void> _konfirmasiHapus(
  BuildContext context,
  WidgetRef ref, {
  required ArsipFolder folder,
  required AlamatFolder alamat,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final yakin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.arsipHapusJudul),
      content: Text(l10n.arsipHapusIsi(folder.nama)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.arsipBatal),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.arsipHapus),
        ),
      ],
    ),
  );

  if (yakin != true) return;

  final error = await ref.read(arsipAksiProvider).hapus(folder.id);

  messenger.showSnackBar(SnackBar(content: Text(error ?? l10n.arsipDihapus)));
  // Sekeluarga, bukan cuma folder yang lagi dibuka: bikin subfolder di sini
  // ngubah angka "n folder · n berkas" di kartu folder INDUK juga. Kalau cuma
  // yang ini di-invalidate, layar induk nampilin hitungan basi begitu di-back.
  if (error == null) ref.invalidate(arsipIsiFolderProvider);
}

// ------------------------------------------------------------------ potongan

class _IkonFolder extends StatelessWidget {
  const _IkonFolder({required this.warna});

  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(Icons.folder_rounded, color: warna, size: 22),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pesan,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
          l10n.arsipLoadGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.arsipRetry,
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
      itemBuilder: (_, _) => const SkeletonBox(height: 76, width: double.infinity),
    );
  }
}
