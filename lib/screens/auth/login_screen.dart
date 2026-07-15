import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/lab_profile.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/language_toggle.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_brand_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Divalidasi lokal dulu — nggak usah bolak-balik ke server cuma buat tahu
  /// field-nya kosong.
  bool _validasi(AppLocalizations l10n) {
    setState(() {
      _identifierError = _identifier.text.trim().isEmpty
          ? l10n.loginIdentifierRequired
          : null;
      _passwordError = _password.text.isEmpty ? l10n.passwordRequired : null;
    });
    return _identifierError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validasi(AppLocalizations.of(context))) return;

    await ref
        .read(authProvider.notifier)
        .login(identifier: _identifier.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);

    // Cuma pesan dari AuthException yang ditampilin apa adanya. Exception
    // teknis (timeout, parsing) disembunyiin — user nggak perlu lihat itu.
    final errorLogin = switch (auth) {
      AsyncError(:final AuthException error) => error.message,
      AsyncError() => l10n.errorNoConnection,
      _ => null,
    };

    return Scaffold(
      body: Container(
        // Gradasi latar: di tema gelap jadi navy pekat mirip mockup Titanium;
        // di terang tetap lembut. Sengaja pakai gradient, bukan backdrop-blur
        // (blur mahal di HP low-end — lihat keputusan perf tim).
        decoration: BoxDecoration(gradient: _latar(theme)),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: const LanguageToggle(),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthBrandHeader(
                            title: LabProfile.namaSingkat,
                            subtitle: l10n.appTagline,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (errorLogin != null) ...[
                                    _ErrorBanner(message: errorLogin),
                                    const SizedBox(height: AppSpacing.md),
                                  ],

                                  AppTextField(
                                    label: l10n.loginIdentifierLabel,
                                    controller: _identifier,
                                    hint: l10n.loginIdentifierHint,
                                    prefixIcon: Icons.badge_outlined,
                                    errorText: _identifierError,
                                    enabled: !auth.isLoading,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),

                                  AppTextField(
                                    label: l10n.passwordLabel,
                                    controller: _password,
                                    hint: '••••••••',
                                    prefixIcon: Icons.lock_outline,
                                    isPassword: true,
                                    errorText: _passwordError,
                                    enabled: !auth.isLoading,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    // Enter di keyboard langsung submit —
                                    // teknisi nggak perlu mindahin tangan.
                                    onSubmitted: (_) => _submit(),
                                    trailing: TextButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const ForgotPasswordScreen(),
                                              ),
                                            ),
                                      child: Text(l10n.forgotPasswordLink),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  AppButton(
                                    label: l10n.loginSubmit,
                                    trailingIcon: Icons.arrow_forward,
                                    isLoading: auth.isLoading,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.loginNoAccount,
                                  style: theme.textTheme.bodySmall,
                                ),
                                TextButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        ),
                                  child: Text(l10n.loginRegisterLink),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),
                          const AuthPoweredBy(),
                          const SizedBox(height: AppSpacing.md),
                          const _DevHint(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gradasi latar per tema.
  LinearGradient _latar(ThemeData theme) {
    final scheme = theme.colorScheme;
    final gelap = theme.brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gelap
          ? const [Color(0xFF0F172A), Color(0xFF020617)]
          : [scheme.surfaceContainerLowest, scheme.surfaceContainerLow],
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
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petunjuk akun tes — **cuma muncul di build non-produksi**. Di APK yang
/// dikasih ke perusahaan, kotak ini nggak dirender sama sekali. Teks-nya
/// sengaja nggak di-i18n: ini alat bantu developer, bukan UI produk.
class _DevHint extends StatelessWidget {
  const _DevHint();

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProd) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final mock = AppConfig.useMock;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mock ? 'MODE MOCK — TANPA SERVER' : 'MODE DEV — NEMBAK API ASLI',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mock
                ? 'ASM-0001 (admin) · ASM-0002 (teknisi) · ASM-0003 (viewer)\n'
                      'Password: password123'
                : 'ASM-0001 (admin) · ASM-0002 (teknisi) · ASM-0003 (viewer)\n'
                      'ASM-0099 (pending, buat nyoba akun ditolak)\n'
                      'Password: rahasia123\n'
                      'Server: ${AppConfig.apiBaseUrl}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
