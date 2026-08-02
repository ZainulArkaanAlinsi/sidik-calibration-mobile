import 'package:flutter/material.dart';

import '../../core/config/lab_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/sidik_loader.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/neu.dart';

/// Layar pembuka saat app ngecek token tersimpan (lihat [AuthGate]).
///
/// Sengaja senada sama layar Login: soft UI / neumorphism, latar `c.base`,
/// logo PT Sidik di badge timbul, nama brand + tagline, plus indikator loading
/// yang kalem. Biar transisi splash → login/app kerasa satu bahasa desain,
/// bukan lompat dari layar Material polos ke neumorphism.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: c.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Logo Sidik berorbit — sekaligus brand & indikator loading, jadi
              // nggak perlu logo statis + spinner terpisah.
              const SidikLoader(size: 140),
              const SizedBox(height: 30),
              Text(
                LabProfile.namaSingkat,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted),
              ),
              const Spacer(flex: 4),
              const AuthPoweredBy(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
