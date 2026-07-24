import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
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

    return switch (auth) {
      AsyncData(:final value?) => MainShell(key: ValueKey(value.id)),
      AsyncLoading() when !auth.hasValue && !auth.hasError => const SplashScreen(),
      _ => const LoginScreen(),
    };
  }
}
