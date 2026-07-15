import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/neu.dart';

/// Reset password — 3 state sesuai catatan harian 20 Jul:
/// `normal` (form) · `sukses` (email terkirim) · `error` (email nggak terdaftar).
///
/// Gaya soft UI / neumorphism, senada Login & Register (lihat `widgets/neu.dart`).
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
    final c = NeuColors.of(context);

    return Scaffold(
      backgroundColor: c.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _terkirim ? _panelSukses() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final c = NeuColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: NeuBackButton(
            onTap: _loading ? null : () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: NeuBrandBadge(icon: Icons.lock_reset_outlined)),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Lupa Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Kami kirim link reset ke email kamu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
        ),
        const SizedBox(height: 28),

        NeuRaised(
          radius: 30,
          distance: 8,
          blur: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorKirim != null) ...[
                NeuErrorBanner(message: _errorKirim!),
                const SizedBox(height: 18),
              ],

              Text(
                'Masukin email yang kamu pakai waktu daftar. Reset password '
                'lewat email, bukan lewat ID pegawai — biar yang bisa ganti '
                'password cuma orang yang megang emailnya.',
                style: TextStyle(fontSize: 13, height: 1.4, color: c.textMuted),
              ),
              const SizedBox(height: 18),

              NeuTextField(
                icon: Icons.mail_outline,
                controller: _email,
                hint: 'Email (nama@pt-sidik.com)',
                errorText: _emailError,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 26),

              NeuButton(
                label: 'KIRIM LINK RESET',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Center(
          child: NeuTextLink(
            label: 'Balik ke Login',
            strong: true,
            onTap: _loading ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _panelSukses() {
    final c = NeuColors.of(context);
    final email = _email.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: NeuBrandBadge(icon: Icons.mark_email_read_outlined),
        ),
        const SizedBox(height: 24),
        Text(
          'Link reset terkirim',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Kami udah kirim link reset password ke $email.\n\n'
          'Cek juga folder spam kalau nggak nemu. Link-nya berlaku terbatas, '
          'jadi jangan kelamaan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted),
        ),
        const SizedBox(height: 28),
        NeuButton(
          label: 'BALIK KE LOGIN',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
