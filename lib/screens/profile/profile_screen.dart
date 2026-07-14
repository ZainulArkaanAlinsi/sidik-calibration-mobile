import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/user.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';
import '../design_system/design_system_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
