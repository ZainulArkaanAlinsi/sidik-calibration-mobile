import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';

class AsmoApp extends StatelessWidget {
  const AsmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIDIK Kalibrasi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Ikut setelan HP. Teknisi yang kerja di area gelap (gudang, lab)
      // biasanya udah nyalain dark mode di HP-nya.
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
