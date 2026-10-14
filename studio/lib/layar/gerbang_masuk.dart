import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';

import '../inti/sesi_studio.dart';
import '../l10n/studio_l10n.dart';
import '../widget/merek_studio.dart';
import '../tema/warna_studio.dart';
import 'cangkang_studio.dart';
import 'klien_kedaluwarsa_screen.dart';
import 'masuk_screen.dart';

/// Layar pertama Studio — cermin `AuthGate` app lapangan TANPA onboarding,
/// tanpa pembaru aplikasi, tanpa cabang HP/desktop: Studio cuma punya satu
/// cangkang yang menyesuaikan diri ke ukuran.
///
/// `error` sengaja tidak melempar ke layar lain: galat kredensial tampil di
/// layar masuk, supaya yang sudah diketik tidak hilang.
///
/// Server yang menolak versi Studio ini (`426`) mengalahkan semuanya — masuk
/// maupun bekerja tidak mungkin dengan versi yang ditolak.
class GerbangMasukStudio extends ConsumerWidget {
  const GerbangMasukStudio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(klienKedaluwarsaProvider)) {
      return const KlienKedaluwarsaScreen();
    }

    final auth = ref.watch(authProvider);

    return switch (auth) {
      // Kunci per akun: ganti akun = cangkang baru, tidak ada state seksi
      // (pilihan menu, navigator konten) yang terbawa dari akun sebelumnya.
      AsyncData(:final value?) => CangkangStudio(key: ValueKey(value.id)),
      AsyncLoading() when !auth.hasValue && !auth.hasError =>
        const _LayarBuka(),
      _ => const MasukStudioScreen(),
    };
  }
}

/// Selama token tersimpan diperiksa (`AuthController.build`).
class _LayarBuka extends StatelessWidget {
  const _LayarBuka();

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Scaffold(
      backgroundColor: w.sisi,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MerekStudio(ukuranIkon: 48),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                color: w.aksen,
                backgroundColor: w.sisiAktif,
                semanticsLabel: StudioL10n.of(context).memuat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
