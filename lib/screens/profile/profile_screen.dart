import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';
import '../design_system/design_system_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Loading-nya disimpan lokal, bukan numpang `authProvider.isLoading`.
  /// Soalnya kalau nyabut sesi gagal, `authProvider` sengaja nggak disentuh
  /// sama sekali (user tetap login) — jadi dia nggak bisa dipakai nandain
  /// tombol ini lagi jalan apa nggak.
  bool _sedangCabutSemua = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final user = ref.watch(authProvider).value;
    final sedangLogout = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (user != null) ...[
            _Header(user: user, onEditFoto: _pilihFoto),
            const SizedBox(height: AppSpacing.lg),

            _JudulSeksi(l10n.profAccountInfo),
            _KartuInfoAkun(user: user),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Menu khusus admin. Dirender cuma kalau role-nya admin —
          // bukan di-disable, tapi memang nggak ada sama sekali buat yang lain
          // (lihat README, Prinsip Desain).
          if (user != null && user.role.isAdmin) ...[
            _JudulSeksi(l10n.profAdminMenu),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text(l10n.profUserManagement),
                    subtitle: Text(l10n.profUserManagementSub),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: false,
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.apartment_outlined),
                    title: Text(l10n.profMasterData),
                    subtitle: Text(l10n.profMasterDataSub),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.profDesignSystem),
              subtitle: Text(l10n.profDesignSystemSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignSystemScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _JudulSeksi(l10n.profAppInfo),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: Text(l10n.profEnvironment),
                  subtitle: Text(AppConfig.envLabel),
                  dense: true,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.profApiBaseUrl),
                  subtitle: Text(apiBaseUrl),
                  dense: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _JudulSeksi(l10n.profSecurity),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.phonelink_erase_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.profLogoutAll),
              subtitle: Text(l10n.profLogoutAllSub),
              trailing: _sedangCabutSemua
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _sedangCabutSemua ? null : _cabutSemuaSesi,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppButton(
              label: l10n.profLogout,
              icon: Icons.logout,
              variant: AppButtonVariant.secondary,
              isLoading: sedangLogout,
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }

  /// Sheet pilih sumber foto: galeri / kamera / hapus.
  void _pilihFoto() {
    final l10n = AppLocalizations.of(context);
    final adaFoto = ref.read(avatarPathProvider) != null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.profChangePhotoSheet,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profChooseGallery),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _ambilFoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profTakePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _ambilFoto(ImageSource.camera);
              },
            ),
            if (adaFoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(l10n.profRemovePhoto),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _hapusFoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ambilFoto(ImageSource sumber) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: sumber,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return; // user batal milih
      await ref.read(avatarPathProvider.notifier).setPath(file.path);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoUpdated)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoFailed)));
    }
  }

  Future<void> _hapusFoto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(avatarPathProvider.notifier).setPath(null);
    messenger.showSnackBar(SnackBar(content: Text(l10n.profPhotoRemoved)));
  }

  Future<void> _cabutSemuaSesi() async {
    final l10n = AppLocalizations.of(context);

    // Nggak bisa dibatalin, dan efeknya kena ke perangkat lain — jadi wajib
    // dikonfirmasi dulu.
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profLogoutAllConfirmTitle),
        content: Text(l10n.profLogoutAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profRevokeAll),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    // Diambil sebelum `await`: begitu sesinya kecabut, layar ini langsung
    // dilepas dan `context`-nya nggak kepakai lagi. `ScaffoldMessenger`-nya
    // sendiri nempel di `MaterialApp`, jadi snackbar-nya tetap kelihatan pas
    // user udah mendarat di layar Login.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sedangCabutSemua = true);

    try {
      final dicabut = await ref.read(authProvider.notifier).logoutAll();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            dicabut > 0
                ? l10n.profSessionsRevoked(dicabut)
                : l10n.profAllSessionsRevoked,
          ),
        ),
      );
    } on AuthException catch (e) {
      // Gagal = sesi di HP yang ilang MASIH HIDUP. Jangan diem-diem ngeluarin
      // user dari HP ini — dia bakal ngira udah aman. Bilang apa adanya, biar
      // dia nyoba lagi.
      if (!mounted) return;

      setState(() => _sedangCabutSemua = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profRevokeFailed(e.message))),
      );
    }
  }
}

/// Judul kecil di atas tiap seksi.
class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        teks.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Header profil: banner brand + avatar (foto dari HP / inisial) yang nongol
/// di atas banner, terus nama + email + badge role. Acuan gambar #2 (banner) &
/// #3 (avatar + info di bawahnya).
class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.onEditFoto});

  final User user;
  final VoidCallback onEditFoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fotoPath = ref.watch(avatarPathProvider);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Banner: foto (kalau ada) atau gradasi brand.
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                gradient: fotoPath == null
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.navy, AppColors.teal],
                      )
                    : null,
                image: fotoPath != null
                    ? DecorationImage(
                        image: FileImage(File(fotoPath)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
            ),
            // Avatar nongol di bibir bawah banner.
            Positioned(
              bottom: -46,
              child: _Avatar(
                fotoPath: fotoPath,
                inisial: user.nama.characters.first,
                onTap: onEditFoto,
              ),
            ),
          ],
        ),
        const SizedBox(height: 46 + AppSpacing.md),
        Text(
          user.nama,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StatusBadge(
          label: user.role.label,
          tone: user.role.isAdmin ? BadgeTone.info : BadgeTone.neutral,
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.fotoPath,
    required this.inisial,
    required this.onTap,
  });

  final String? fotoPath;
  final String inisial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cincin putih biar avatar kepisah dari banner.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.scaffoldBackgroundColor,
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: fotoPath != null
                  ? FileImage(File(fotoPath!))
                  : null,
              child: fotoPath == null
                  ? Text(
                      inisial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
          // Badge kamera.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu info akun bergaya "label kecil di atas, nilai di bawah" (acuan #3).
class _KartuInfoAkun extends StatelessWidget {
  const _KartuInfoAkun({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            _BarisInfo(
              icon: Icons.badge_outlined,
              label: l10n.employeeIdLabel,
              nilai: user.employeeId,
            ),
            const Divider(height: 1, indent: 64),
            _BarisInfo(
              icon: Icons.apartment_outlined,
              label: l10n.departmentLabel,
              nilai: user.department ?? '—',
            ),
            const Divider(height: 1, indent: 64),
            _BarisInfo(
              icon: Icons.mail_outline,
              label: l10n.emailLabel,
              nilai: user.email,
            ),
            const Divider(height: 1, indent: 64),
            _BarisInfo(
              icon: Icons.verified_user_outlined,
              label: l10n.profRoleLabel,
              nilai: user.role.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  const _BarisInfo({
    required this.icon,
    required this.label,
    required this.nilai,
  });

  final IconData icon;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nilai,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
