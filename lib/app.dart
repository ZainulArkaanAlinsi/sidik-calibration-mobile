import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/auth/auth_gate.dart';

class SidikApp extends ConsumerWidget {
  const SidikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PT Sidik — Kalibrasi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Default ikut setelan HP; bisa di-override lewat toggle Dark Mode di
      // layar auth (teknisi yang kerja di gudang/lab sering nyalain gelap).
      themeMode: themeMode,
      // Dwibahasa ID/EN. `locale` dipaksa dari provider (default ID) supaya
      // konsisten dan nggak ketarik ke locale device.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
