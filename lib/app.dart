import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'screens/auth/auth_gate.dart';

class AsmoApp extends ConsumerWidget {
  const AsmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'PT Sidik — Kalibrasi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Ikut setelan HP. Teknisi yang kerja di area gelap (gudang, lab)
      // biasanya udah nyalain dark mode di HP-nya.
      themeMode: ThemeMode.system,
      // Dwibahasa ID/EN. `locale` dipaksa dari provider (default ID) supaya
      // konsisten dan nggak ketarik ke locale device.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
