import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../providers/app_config_provider.dart';

/// Halaman sementara buat memastikan fondasi hari 1 beneran jalan:
/// app ke-build, Riverpod ke-wire, konfigurasi environment kebaca.
/// Diganti bottom navigation (Dashboard/Alat/Riwayat/Notifikasi/Profil)
/// di task Selasa 14 Jul.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final env = ref.watch(appEnvProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.straighten,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('ASMO Mobile', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Kalibrasi alat ukur & sertifikat digital',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Environment', value: AppConfig.envLabel),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'API base URL', value: apiBaseUrl),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'State management',
                          value: 'Riverpod (${env.name})',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
