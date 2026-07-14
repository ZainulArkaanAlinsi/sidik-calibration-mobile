import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/user.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
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
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final user = ref.watch(authProvider).value;
    final sedangLogout = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (user != null) _ProfileHeader(user: user),
          const SizedBox(height: AppSpacing.lg),

          // Menu khusus admin. Dirender cuma kalau role-nya admin —
          // bukan di-disable, tapi memang nggak ada sama sekali buat yang lain
          // (lihat README, Prinsip Desain).
          if (user != null && user.role.isAdmin) ...[
            Text('Menu Admin', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: const Text('Manajemen Pengguna'),
                    subtitle: const Text('Digarap fase 3'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: false,
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.apartment_outlined),
                    title: const Text('Master Data PT & Pelanggan'),
                    subtitle: const Text('Digarap minggu 2'),
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
              title: const Text('Design System'),
              subtitle: const Text('Katalog warna, tipografi & komponen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DesignSystemScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('Info Aplikasi', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Environment'),
                  subtitle: Text(AppConfig.envLabel),
                  dense: true,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('API base URL'),
                  subtitle: Text(apiBaseUrl),
                  dense: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('Keamanan', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.phonelink_erase_outlined,
                color: theme.colorScheme.error,
              ),
              title: const Text('Keluar dari semua perangkat'),
              subtitle: const Text(
                'Buat kalau HP kamu ilang. Semua sesi dicabut — HP lain, '
                'tablet, termasuk yang ini.',
              ),
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

          AppButton(
            label: 'Keluar',
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            isLoading: sedangLogout,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  Future<void> _cabutSemuaSesi() async {
    // Nggak bisa dibatalin, dan efeknya kena ke perangkat lain — jadi wajib
    // dikonfirmasi dulu.
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari semua perangkat?'),
        content: const Text(
          'Semua sesi kamu bakal dicabut, termasuk di HP ini — kamu bakal '
          'diminta login lagi.\n\nPakai ini kalau HP kamu ilang atau dicuri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cabut semua sesi'),
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
                ? '$dicabut sesi dicabut. Login lagi ya.'
                : 'Semua sesi dicabut. Login lagi ya.',
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
        SnackBar(content: Text('Gagal nyabut sesi: ${e.message}')),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            user.nama.characters.first,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.nama, style: theme.textTheme.titleMedium),
              Text(user.email, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              StatusBadge(
                label: user.role.label,
                tone: user.role.isAdmin ? BadgeTone.info : BadgeTone.neutral,
                icon: Icons.badge_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
