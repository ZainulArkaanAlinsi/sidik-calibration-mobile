import 'package:flutter/material.dart';

import '../../core/config/lab_profile.dart';
import '../../l10n/app_localizations.dart';
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
              const NeuBrandBadge(),
              const SizedBox(height: 26),
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
              const SizedBox(height: 44),
              // Indikator kalem — cincin cekung neu dengan spinner tipis di
              // tengahnya, senada sama field & tombol di Login.
              NeuInset(
                radius: 22,
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(c.textMuted),
                  ),
                ),
              ),
              const Spacer(flex: 4),
              const NeuPoweredBy(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
