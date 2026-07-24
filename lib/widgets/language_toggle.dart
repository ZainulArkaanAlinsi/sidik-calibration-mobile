import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

/// Tombol ganti bahasa ID ↔ EN. Kecil & subtle — ditaruh di pojok layar auth
/// (mockup belum punya kontrol ini, tapi dwibahasa adalah requirement).
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isId = locale.languageCode == 'id';

    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
      icon: const Icon(Icons.language, size: 18),
      label: Text(isId ? 'ID' : 'EN'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
