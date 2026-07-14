import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Validasi lokal dulu — nggak usah bolak-balik ke server cuma buat tahu
  /// field-nya kosong.
  bool _validasi() {
    setState(() {
      _emailError = _email.text.trim().isEmpty ? 'Email wajib diisi.' : null;
      _passwordError = _password.text.isEmpty ? 'Password wajib diisi.' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validasi()) return;

    await ref
        .read(authProvider.notifier)
        .login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    // Pesan error kredensial dari service. Exception teknis (timeout, dst)
    // nggak ditampilin mentah-mentah ke user.
    final errorKredensial = switch (auth) {
      AsyncError(:final AuthException error) => error.message,
      AsyncError() => 'Nggak bisa nyambung ke server. Coba lagi.',
      _ => null,
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.straighten,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'ASMO Mobile',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kalibrasi alat ukur & sertifikat digital',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (errorKredensial != null) ...[
                    _ErrorBanner(message: errorKredensial),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    hint: 'nama@perusahaan.com',
                    errorText: _emailError,
                    enabled: !auth.isLoading,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    errorText: _passwordError,
                    enabled: !auth.isLoading,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'Masuk',
                    isLoading: auth.isLoading,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const _MockHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petunjuk akun tes. HAPUS bareng `MockAuthService` begitu API asli nyambung.
class _MockHint extends StatelessWidget {
  const _MockHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mode mock — API belum nyambung', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'admin@asmo.test · teknisi@asmo.test · viewer@asmo.test\n'
            'Password: password123',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
