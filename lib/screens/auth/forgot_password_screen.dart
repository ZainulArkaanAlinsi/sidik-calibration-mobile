import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/neu.dart';

/// Reset password — alur beneran, bukan cuma layar "link terkirim":
/// 1. **email**    : masukin email terdaftar (diverifikasi ke service).
/// 2. **password** : atur password baru (langsung kepasang).
/// 3. **selesai**  : sukses → balik Login, dan login pakai password baru jalan.
///
/// Di produksi langkah verifikasi email lewat token di email; di mock (nggak
/// ada infra email) langkah itu di-skip biar fiturnya beneran kepakai.
enum _Tahap { email, password, selesai }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _passBaru = TextEditingController();
  final _passUlang = TextEditingController();

  _Tahap _tahap = _Tahap.email;

  String? _emailError;
  String? _passBaruError;
  String? _passUlangError;
  String? _errorKirim;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _passBaru.dispose();
    _passUlang.dispose();
    super.dispose();
  }

  bool _validasiEmail(AppLocalizations l10n) {
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

  bool _validasiPassword(AppLocalizations l10n) {
    setState(() {
      _passBaruError = switch (_passBaru.text) {
        '' => l10n.passwordRequired,
        final p when p.length < 8 => l10n.passwordTooShort,
        _ => null,
      };
      _passUlangError = _passUlang.text != _passBaru.text
          ? l10n.passwordMismatch
          : null;
    });
    return _passBaruError == null && _passUlangError == null;
  }

  /// Langkah 1 → 2: verifikasi email terdaftar.
  Future<void> _lanjut() async {
    final l10n = AppLocalizations.of(context);
    if (!_validasiEmail(l10n)) return;

    setState(() {
      _loading = true;
      _errorKirim = null;
    });

    var ok = false;
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(_email.text);
      ok = true;
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorKirim = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorKirim = l10n.errorNoConnection);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) _tahap = _Tahap.password;
    });
  }

  /// Langkah 2 → 3: pasang password baru beneran.
  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    if (!_validasiPassword(l10n)) return;

    setState(() {
      _loading = true;
      _errorKirim = null;
    });

    var ok = false;
    try {
      await ref.read(authProvider.notifier).resetPassword(
        email: _email.text,
        newPassword: _passBaru.text,
      );
      ok = true;
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorKirim = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorKirim = l10n.errorNoConnection);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) _tahap = _Tahap.selesai;
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
              child: switch (_tahap) {
                _Tahap.email => _stepEmail(),
                _Tahap.password => _stepPassword(),
                _Tahap.selesai => _stepSelesai(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({
    required String judul,
    required String subjudul,
    required VoidCallback? onBack,
  }) {
    final c = NeuColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: NeuBackButton(onTap: onBack),
        ),
        const SizedBox(height: 16),
        const Center(child: NeuBrandBadge()),
        const SizedBox(height: 18),
        Center(
          child: Text(
            judul,
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
            subjudul,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _stepEmail() {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          judul: l10n.forgotTitle,
          subjudul: l10n.forgotSubtitle,
          onBack: _loading ? null : () => Navigator.of(context).pop(),
        ),
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
          onSubmitted: (_) => _lanjut(),
        ),
        const SizedBox(height: 30),
        NeuButton(
          label: l10n.forgotSubmit,
          loading: _loading,
          onPressed: _lanjut,
        ),
      ],
    );
  }

  Widget _stepPassword() {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          judul: l10n.resetNewPassTitle,
          subjudul: l10n.resetNewPassSubtitle(_email.text.trim()),
          // Back di langkah ini = balik ke langkah email, bukan keluar layar.
          onBack: _loading
              ? null
              : () => setState(() {
                  _tahap = _Tahap.email;
                  _errorKirim = null;
                }),
        ),
        if (_errorKirim != null) ...[
          NeuErrorBanner(message: _errorKirim!),
          const SizedBox(height: 18),
        ],
        NeuFieldLabel(l10n.newPasswordLabel),
        NeuTextField(
          icon: Icons.lock_outline,
          controller: _passBaru,
          hint: '••••••••',
          obscure: true,
          errorText: _passBaruError,
          helperText: l10n.passwordHelper,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        NeuFieldLabel(l10n.confirmPasswordLabel),
        NeuTextField(
          icon: Icons.lock_outline,
          controller: _passUlang,
          hint: '••••••••',
          obscure: true,
          errorText: _passUlangError,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _simpan(),
        ),
        const SizedBox(height: 30),
        NeuButton(
          label: l10n.resetSubmit,
          loading: _loading,
          onPressed: _simpan,
        ),
      ],
    );
  }

  Widget _stepSelesai() {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Center(
          child: NeuBrandBadge(icon: Icons.check_circle_outline),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.resetDoneTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.resetDoneBody,
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
