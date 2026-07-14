import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../providers/app_config_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ProfileHeaderPlaceholder(),
          const SizedBox(height: 24),
          Text('Info Aplikasi', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Text(
            'Login, data user, dan menu khusus admin (Manajemen Pengguna, dst) '
            'nyusul di minggu 2. Menu admin bakal disembunyikan total dari '
            'non-admin, bukan cuma di-disable.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderPlaceholder extends StatelessWidget {
  const _ProfileHeaderPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.person_outline, color: theme.colorScheme.outline),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Belum login', style: theme.textTheme.titleMedium),
              Text(
                'Autentikasi digarap minggu 2',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
