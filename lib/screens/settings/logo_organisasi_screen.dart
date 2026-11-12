import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/izin_provider.dart';
import '../../providers/logo_organisasi_provider.dart';
import '../../services/auth_service.dart' show AuthException;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik_loader.dart';

/// Berkas logo yang dipilih admin.
typedef BerkasLogo = ({String path, int ukuran});

/// Pemilih berkas logo. Bawaannya membuka file picker sistem; test menyuntik
/// penggantinya, karena picker butuh layar sistem yang tidak ada di test.
typedef PemilihBerkasLogo = Future<BerkasLogo?> Function();

/// Batas server (`max:2048` KB di `OrganizationController::uploadLogo`).
const _maksBytes = 2 * 1024 * 1024;

Future<BerkasLogo?> _pilihDariSistem() async {
  // Dibatasi PNG/JPG di picker, bukan cuma ngandelin tolakan server: WEBP
  // pasti ditolak (dompdf tidak bisa mencetaknya). Server tetap yang berwenang.
  final hasil = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg'],
    withData: false,
  );
  final berkas = hasil?.files.single;
  final path = berkas?.path;
  if (berkas == null || path == null) return null;

  return (path: path, ukuran: berkas.size);
}

/// Logo yang dicetak di kop sertifikat — **admin doang**.
///
/// Layar sendiri, bukan bagian dari "Data PT": layar itu tidak diubah. Logo
/// lewat `POST`/`DELETE /organization/logo` dan berbeda dari tanda tangan
/// (PNG-only, privat, ada posisi) yang punya layar sendiri.
class LogoOrganisasiScreen extends ConsumerWidget {
  const LogoOrganisasiScreen({super.key, PemilihBerkasLogo? pilihBerkas})
    : _pilihBerkas = pilihBerkas;

  final PemilihBerkasLogo? _pilihBerkas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehkah(
      NamaIzin.organisasiLogo,
      cadangan: ref.watch(authProvider).value?.role.hakAdmin ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logoOrgJudul)),
      body: boleh
          ? ReadableWidth(
              child: _Isi(pilihBerkas: _pilihBerkas ?? _pilihDariSistem),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.logoOrgHanyaAdmin,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Isi extends ConsumerStatefulWidget {
  const _Isi({required this.pilihBerkas});

  final PemilihBerkasLogo pilihBerkas;

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  bool _sibuk = false;

  Future<void> _jalankan(
    Future<void> Function() aksi, {
    required String pesanSukses,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);
    try {
      await aksi();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(pesanSukses)));
    } on TokenHilangException {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.historySessionExpired)),
        );
      }
    } on AuthException catch (e) {
      // Pesan server ditampilkan APA ADANYA (`ApiException`/`KoneksiException`
      // sudah dirancang untuk dibaca user). Untuk penolakan logo, `422`-nya
      // menyebut alasan (WEBP tak bisa dicetak, maks 2 MB); diganti "format
      // tidak didukung" malah menghilangkan alasannya.
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Galat teknis (parsing, dll.) tidak dibocorkan ke layar.
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.logoOrgGagal)));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _unggah() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final berkas = await widget.pilihBerkas();

    // File picker membuka layar sistem; widget bisa sudah dilepas waktu balik.
    if (!mounted || berkas == null) return;

    if (berkas.ukuran > _maksBytes) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.logoOrgTerlaluBesar)));
      return;
    }

    await _jalankan(
      () => ref.read(logoOrganisasiProvider.notifier).unggah(berkas.path),
      pesanSukses: l10n.logoOrgTerunggah,
    );
  }

  Future<void> _hapus() async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoOrgHapusJudul),
        content: Text(l10n.logoOrgHapusIsi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logoOrgHapus),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    await _jalankan(
      () => ref.read(logoOrganisasiProvider.notifier).hapus(),
      pesanSukses: l10n.logoOrgTerhapus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(logoOrganisasiProvider);

    final data = async.value;
    if (data == null) {
      if (async.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.logoOrgGagalMuat, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.logoOrgRetry,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      ref.read(logoOrganisasiProvider.notifier).muatUlang(),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: SidikLoader(size: 88));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: data.ada
              ? Image.network(
                  data.url!,
                  fit: BoxFit.contain,
                  semanticLabel: l10n.logoOrgJudul,
                  errorBuilder: (_, _, _) => Text(
                    l10n.logoOrgPratinjauGagal,
                    textAlign: TextAlign.center,
                  ),
                )
              : Text(
                  l10n.logoOrgBelum,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.logoOrgInfo,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: data.ada ? l10n.logoOrgGanti : l10n.logoOrgUnggah,
                icon: Icons.upload_outlined,
                isLoading: _sibuk,
                onPressed: _sibuk ? null : _unggah,
              ),
            ),
            if (data.ada) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.logoOrgHapus,
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.secondary,
                  onPressed: _sibuk ? null : _hapus,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
