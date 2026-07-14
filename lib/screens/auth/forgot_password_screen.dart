import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'widgets/auth_brand_header.dart';

/// Reset password — 3 state sesuai catatan harian 20 Jul:
/// `normal` (form) · `sukses` (email terkirim) · `error` (email nggak terdaftar).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();

  String? _emailError;
  String? _errorKirim;
  bool _loading = false;
  bool _terkirim = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _validasi() {
    final email = _email.text.trim();

    setState(() {
      _emailError = switch (email) {
        '' => 'Email wajib diisi.',
        _ when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) =>
          'Format email nggak valid.',
        _ => null,
      };
    });

    return _emailError == null;
  }

  Future<void> _submit() async {
    if (!_validasi()) return;

    setState(() {
      _loading = true;
      _errorKirim = null;
    });

    var sukses = false;
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(_email.text);
      sukses = true;
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorKirim = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorKirim = 'Nggak bisa nyambung ke server. Coba lagi.',
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _terkirim = sukses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _terkirim ? _PanelSukses(email: _email.text.trim()) : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthBrandHeader(
          title: 'Lupa Password',
          subtitle: 'Kami kirim link reset ke email kamu',
        ),
        const SizedBox(height: AppSpacing.lg),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorKirim != null) ...[
                  _ErrorBanner(message: _errorKirim!),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text(
                  'Masukin email yang kamu pakai waktu daftar. Reset password '
                  'lewat email, bukan lewat ID pegawai — biar yang bisa ganti '
                  'password cuma orang yang megang emailnya.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Email',
                  controller: _email,
                  hint: 'nama@ptasmo.com',
                  prefixIcon: Icons.mail_outline,
                  errorText: _emailError,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: 'KIRIM LINK RESET',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: 'Balik ke Login',
          variant: AppButtonVariant.secondary,
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _PanelSukses extends StatelessWidget {
  const _PanelSukses({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Link reset terkirim',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Kami udah kirim link reset password ke $email.\n\n'
          'Cek juga folder spam kalau nggak nemu. Link-nya berlaku terbatas, '
          'jadi jangan kelamaan.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'BALIK KE LOGIN',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
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
