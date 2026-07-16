import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/neu.dart';

/// Reset password — 3 state: `normal` (form) · `sukses` (email terkirim) ·
/// `error` (email nggak terdaftar). Gaya soft UI / neumorphism.
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

  bool _validasi(AppLocalizations l10n) {
    final email = _email.text.trim();
    setState(() {
      _emailError = switch (email) {
        '' => l10n.emailRequired,
        _ when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) =>
          l10n.emailInvalid,
        _ => null,
      };
    });
    return _emailError == null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validasi(l10n)) return;

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
      if (mounted) setState(() => _errorKirim = l10n.errorNoConnection);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _terkirim = sukses;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return Scaffold(
      backgroundColor: c.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _terkirim
                  ? _PanelSukses(email: _email.text.trim())
                  : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: NeuBackButton(
            onTap: _loading ? null : () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: NeuBrandBadge(icon: Icons.lock_reset_outlined)),
        const SizedBox(height: 18),
        Center(
          child: Text(
            l10n.forgotTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.forgotSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
        ),
        const SizedBox(height: 30),

        if (_errorKirim != null) ...[
          NeuErrorBanner(message: _errorKirim!),
          const SizedBox(height: 18),
        ],

        Text(
          l10n.forgotBody,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textMuted),
        ),
        const SizedBox(height: 20),

        NeuFieldLabel(l10n.emailLabel),
        NeuTextField(
          icon: Icons.mail_outline,
          controller: _email,
          hint: l10n.emailHint,
          errorText: _emailError,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 30),

        NeuButton(
          label: l10n.forgotSubmit,
          loading: _loading,
          onPressed: _submit,
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
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Center(
          child: NeuBrandBadge(icon: Icons.mark_email_read_outlined),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.forgotSuccessTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.forgotSuccessBody(email),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textMuted),
        ),
        const SizedBox(height: 34),
        NeuButton(
          label: l10n.backToLoginCaps,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
