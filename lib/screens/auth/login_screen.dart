import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/lab_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_top_controls.dart';
import 'widgets/neu.dart';

/// Layar Login — gaya soft UI / neumorphism gelap (lihat `widgets/neu.dart`).
/// Login pakai ID pegawai **atau** email, validasi lokal dulu, error dari
/// server ditampilin apa adanya, plus panel bantuan buat mode dev/mock.
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
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final loading = auth.isLoading;

    final errorLogin = switch (auth) {
      AsyncError(:final AuthException error) => error.message,
      AsyncError() => l10n.errorNoConnection,
      _ => null,
    };

    return Scaffold(
      backgroundColor: c.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthTopControls(),
                  const SizedBox(height: 20),

                  const Center(child: NeuBrandBadge()),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      LabProfile.namaSingkat,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      l10n.appTagline,
                      style: TextStyle(fontSize: 14, color: c.textMuted),
                    ),
                  ),
                  const SizedBox(height: 34),

                  if (errorLogin != null) ...[
                    NeuErrorBanner(message: errorLogin),
                    const SizedBox(height: 20),
                  ],

                  NeuFieldLabel(l10n.loginIdentifierLabel),
                  NeuTextField(
                    icon: Icons.badge_outlined,
                    controller: _identifier,
                    hint: l10n.loginIdentifierHint,
                    errorText: _identifierError,
                    enabled: !loading,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 18),

                  NeuFieldLabel(l10n.passwordLabel),
                  NeuTextField(
                    icon: Icons.lock_outline,
                    controller: _password,
                    hint: '••••••••',
                    obscure: true,
                    errorText: _passwordError,
                    enabled: !loading,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 30),

                  NeuButton(
                    label: l10n.loginSubmit,
                    loading: loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: NeuTextLink(
                      label: l10n.forgotPasswordLink,
                      onTap: loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.loginNoAccount,
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                        const SizedBox(width: 6),
                        NeuTextLink(
                          label: l10n.loginRegisterLink,
                          strong: true,
                          onTap: loading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const NeuPoweredBy(),
                  const SizedBox(height: 18),
                  const _DevHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petunjuk akun tes — **cuma muncul di build non-produksi**. Teks-nya sengaja
/// nggak di-i18n: ini alat bantu developer, bukan UI produk.
class _DevHint extends StatelessWidget {
  const _DevHint();

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProd) return const SizedBox.shrink();

    final c = NeuColors.of(context);
    final mock = AppConfig.useMock;

    return NeuInset(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mock ? 'MODE MOCK — TANPA SERVER' : 'MODE DEV — NEMBAK API ASLI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mock
                ? 'ASM-0001 (admin) · ASM-0002 (teknisi) · ASM-0003 (viewer)\n'
                      'Password: password123'
                : 'ASM-0001 (admin) · ASM-0002 (teknisi) · ASM-0003 (viewer)\n'
                      'ASM-0099 (pending, buat nyoba akun ditolak)\n'
                      'Password: rahasia123\n'
                      'Server: ${AppConfig.apiBaseUrl}',
            style: TextStyle(fontSize: 13, height: 1.4, color: c.text),
          ),
        ],
      ),
    );
  }
}
