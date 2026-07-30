import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/platform_provider.dart';
import '../shell/desktop_shell.dart';
import '../shell/main_shell.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

/// Nentuin layar pertama yang dilihat user.
///
/// Waktu app dibuka, `authProvider` ngecek token tersimpan (lihat
/// `AuthController.build`). Selama itu → splash. Habis itu:
/// ada user → app; nggak ada → login.
///
/// Catatan: state `error` di sini **nggak** dipakai buat lempar user keluar —
/// error kredensial ditampilin di dalam layar Login, biar dia bisa langsung
/// coba lagi tanpa kehilangan apa yang udah diketik.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Desktop = meja kerja admin (panel), HP = alat lapangan (lima tab).
    // Lihat [pakaiPanelDesktopProvider] buat alasan kenapa ini dipatok ke
    // platform, bukan ke lebar jendela.
    final panelDesktop = ref.watch(pakaiPanelDesktopProvider);

    return switch (auth) {
      AsyncData(:final value?) => panelDesktop
          ? DesktopShell(key: ValueKey(value.id))
          : MainShell(key: ValueKey(value.id)),
      AsyncLoading() when !auth.hasValue && !auth.hasError => const SplashScreen(),
      _ => const LoginScreen(),
    };
  }
}
