import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../settings/customer_list_screen.dart';
import '../settings/organization_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _sedangCabutSemua = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final user = ref.watch(authProvider).value;
    final sedangLogout = ref.watch(authProvider).isLoading;

    return Scaffold(
      // Foto hero header harus nyampe ke tepi paling atas layar (nggak ada
      // judul "Profil" mengambang di atasnya — acuan desainnya juga gitu).
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ListView(
        // Padding bawah lega biar item terakhir nggak ketutup bottom-nav
        // yang mengambang. Top sengaja 0 — header foto harus full-bleed.
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (user != null) ...[
            _Header(user: user, onEditFoto: _pilihFoto),
            const SizedBox(height: AppSpacing.lg),
          ],

          if (user != null && user.role.isAdmin) ...[
            _JudulSeksi(l10n.profAdminMenu),
            _KartuMenu(
              children: [
                _BarisMenu(
                  icon: Icons.group_outlined,
                  title: l10n.profUserManagement,
                  subtitle: l10n.profUserManagementSub,
                  enabled: false,
                ),
                const _GarisPemisah(),
                _BarisMenu(
                  icon: Icons.apartment_outlined,
                  title: l10n.profOrgData,
                  subtitle: l10n.profOrgDataSub,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrganizationScreen(),
                    ),
                  ),
                ),
                const _GarisPemisah(),
                _BarisMenu(
                  icon: Icons.people_outline,
                  title: l10n.profCustomers,
                  subtitle: l10n.profCustomersSub,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerListScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          _KartuMenu(
            children: [
              _BarisMenu(
                icon: Icons.palette_outlined,
                title: l10n.profDesignSystem,
                subtitle: l10n.profDesignSystemSub,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DesignSystemScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _JudulSeksi(l10n.profAppInfo),
          _KartuMenu(
            children: [
              _BarisMenu(
                icon: Icons.layers_outlined,
                title: l10n.profEnvironment,
                subtitle: AppConfig.envLabel,
                showChevron: false,
              ),
              const _GarisPemisah(),
              _BarisMenu(
                icon: Icons.cloud_outlined,
                title: l10n.profApiBaseUrl,
                subtitle: apiBaseUrl,
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _JudulSeksi(l10n.profSecurity),
          _KartuMenu(
            children: [
              _BarisMenu(
                icon: Icons.phonelink_erase_outlined,
                iconColor: theme.colorScheme.error,
                title: l10n.profLogoutAll,
                subtitle: l10n.profLogoutAllSub,
                trailing: _sedangCabutSemua
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _sedangCabutSemua ? null : _cabutSemuaSesi,
              ),
            ],
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
      if (file == null) return;
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
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        teks.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Header profil ala kartu acuan "Tom Chen": foto hero *full-bleed*, avatar
/// rata kiri numpuk di sambungan foto↔panel putih, nama+email rata kiri,
/// terus baris statistik 3 kolom (ID Pegawai / Departemen / Role).
class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.onEditFoto});

  static const _fotoH = 260.0;
  static const _avatar = 96.0;
  static const _overlap = _avatar / 2; // separuh nongol di foto, separuh di panel

  final User user;
  final VoidCallback onEditFoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fotoPath = ref.watch(avatarPathProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // Foto hero — nyampe tepi layar, disambung `extendBodyBehindAppBar`
            // di Scaffold biar nembus sampai di bawah status bar.
            Container(
              height: _fotoH,
              width: double.infinity,
              decoration: BoxDecoration(
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
                          Colors.black.withValues(alpha: 0.30),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
            ),
            // Panel putih nutupin bagian bawah foto, sudut atas membulat —
            // kesan "sheet" yang numpuk di atas foto.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                _overlap + AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          user.nama,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(
                        label: user.status.label,
                        tone: switch (user.status) {
                          UserStatus.aktif => BadgeTone.success,
                          UserStatus.pending => BadgeTone.warning,
                          UserStatus.nonaktif => BadgeTone.neutral,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _BarisStatistik(
                    employeeId: user.employeeId,
                    department: user.department ?? '—',
                    roleLabel: user.role.label,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Avatar numpuk pas di sambungan foto <-> panel, rata kiri.
        Positioned(
          top: _fotoH - _overlap,
          left: AppSpacing.lg,
          child: _Avatar(
            size: _avatar,
            fotoPath: fotoPath,
            inisial: user.nama.characters.first,
            onTap: onEditFoto,
          ),
        ),
      ],
    );
  }
}

/// Baris statistik 3 kolom ala acuan (Article/Views/Followers) — di sini
/// diisi data asli yang app punya, bukan angka karangan.
class _BarisStatistik extends StatelessWidget {
  const _BarisStatistik({
    required this.employeeId,
    required this.department,
    required this.roleLabel,
    required this.l10n,
  });

  final String employeeId;
  final String department;
  final String roleLabel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Statistik(label: l10n.employeeIdLabel, nilai: employeeId),
        ),
        const _PemisahVertikal(),
        Expanded(
          child: _Statistik(label: l10n.departmentLabel, nilai: department),
        ),
        const _PemisahVertikal(),
        Expanded(
          child: _Statistik(label: l10n.profRoleLabel, nilai: roleLabel),
        ),
      ],
    );
  }
}

class _Statistik extends StatelessWidget {
  const _Statistik({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          nilai,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _PemisahVertikal extends StatelessWidget {
  const _PemisahVertikal();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        width: AppSpacing.md,
        thickness: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.size,
    required this.fotoPath,
    required this.inisial,
    required this.onTap,
  });

  final double size;
  final String? fotoPath;
  final String inisial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = theme.scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cincin buat misahin avatar dari banner.
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ring,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: fotoPath != null
                    ? FileImage(File(fotoPath!))
                    : null,
                child: fotoPath == null
                    ? Text(
                        inisial,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
            // Badge kamera.
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navy,
                  border: Border.all(color: ring, width: 2.5),
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
      ),
    );
  }
}

/// Kartu putih membulat dengan bayangan halus — wadah semua baris.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KartuMenu extends StatelessWidget {
  const _KartuMenu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Kartu(child: Column(children: children));
  }
}

class _GarisPemisah extends StatelessWidget {
  const _GarisPemisah();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
    );
  }
}

/// Petak ikon lembut di kiri tiap baris.
class _IkonPetak extends StatelessWidget {
  const _IkonPetak({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 21,
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Baris menu (dengan chevron / trailing + aksi tap) ala list Image #3.
class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final redup = !enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: redup ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                _IkonPetak(icon: icon, color: iconColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
