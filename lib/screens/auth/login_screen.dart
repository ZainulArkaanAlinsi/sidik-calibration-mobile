import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/neu.dart';

/// Layar Login — gaya soft UI / neumorphism (lihat `widgets/neu.dart`).
/// Isinya sama persis kayak sebelumnya: login pakai ID pegawai **atau** email,
/// validasi lokal dulu, error dari server ditampilin apa adanya, plus panel
/// bantuan buat mode dev/mock. Cuma kulitnya yang berubah.
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
  bool _validasi() {
    setState(() {
      _identifierError = _identifier.text.trim().isEmpty
          ? 'ID pegawai atau email wajib diisi.'
          : null;
      _passwordError = _password.text.isEmpty ? 'Password wajib diisi.' : null;
    });
    return _identifierError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validasi()) return;

    await ref
        .read(authProvider.notifier)
        .login(identifier: _identifier.text, password: _password.text);
  }

  void _bukaLupaPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
  );

  void _bukaRegister() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final auth = ref.watch(authProvider);
    final loading = auth.isLoading;

    // Cuma pesan dari AuthException yang ditampilin apa adanya. Exception
    // teknis (timeout, parsing) disembunyiin — user nggak perlu lihat itu.
    final errorLogin = switch (auth) {
      AsyncError(:final AuthException error) => error.message,
      AsyncError() => 'Nggak bisa nyambung ke server. Coba lagi.',
      _ => null,
    };

    return Scaffold(
      backgroundColor: c.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Center(child: NeuBrandBadge()),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'SIDIK',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Manajemen Kalibrasi Presisi',
                      style: TextStyle(fontSize: 14, color: c.textMuted),
                    ),
                  ),
                  const SizedBox(height: 30),

                  NeuRaised(
                    radius: 30,
                    distance: 8,
                    blur: 20,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (errorLogin != null) ...[
                          _NeuErrorBanner(message: errorLogin),
                          const SizedBox(height: 18),
                        ],

                        NeuTextField(
                          icon: Icons.person_outline,
                          controller: _identifier,
                          hint: 'ID Pegawai / Email',
                          errorText: _identifierError,
                          enabled: !loading,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                        ),
                        const SizedBox(height: 16),

                        NeuTextField(
                          icon: Icons.lock_outline,
                          controller: _password,
                          hint: 'Password',
                          obscure: true,
                          errorText: _passwordError,
                          enabled: !loading,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 26),

                        NeuButton(
                          label: 'MASUK',
                          loading: loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 18),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NeuTextLink(
                                label: 'Lupa Password?',
                                onTap: loading ? null : _bukaLupaPassword,
                              ),
                              Text(
                                '  atau  ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textMuted,
                                ),
                              ),
                              NeuTextLink(
                                label: 'Daftar',
                                strong: true,
                                onTap: loading ? null : _bukaRegister,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  const _DevHint(),
                  const SizedBox(height: 26),
                  const AuthPoweredBy(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner error login — versi soft (cekung, teks merah lembut).
class _NeuErrorBanner extends StatelessWidget {
  const _NeuErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return NeuInset(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: c.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel bantuan dev/mock — dipendem di prod. Isinya sama kayak sebelumnya,
/// cuma dikasih kulit soft.
class _DevHint extends StatelessWidget {
  const _DevHint();

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProd) return const SizedBox.shrink();

    final c = NeuColors.of(context);
    final mock = AppConfig.useMock;

    return NeuInset(
      radius: 16,
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
