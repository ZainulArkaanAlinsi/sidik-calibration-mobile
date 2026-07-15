import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'widgets/auth_brand_header.dart';

/// Daftar akun teknisi.
///
/// Penting: daftar **nggak langsung bisa masuk**. Akunnya berstatus `pending`
/// sampai admin nyetujuin & ngasih role. Kalau siapa pun yang daftar langsung
/// aktif, orang luar bisa bikin akun terus ngintip data kalibrasi pelanggan.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Nilai departemen = data yang dikirim ke backend, jadi sengaja TIDAK
  // di-i18n (harus konsisten lintas bahasa & sesuai kontrak API).
  static const _departemen = [
    'Kalibrasi',
    'Quality Control',
    'Produksi',
    'Maintenance',
    'Manajemen',
  ];

  final _nama = TextEditingController();
  final _employeeId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _departemenTerpilih;

  String? _namaError;
  String? _employeeIdError;
  String? _departemenError;
  String? _emailError;
  String? _passwordError;

  bool _loading = false;
  String? _errorKirim;

  @override
  void dispose() {
    _nama.dispose();
    _employeeId.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validasi(AppLocalizations l10n) {
    final email = _email.text.trim();

    setState(() {
      _namaError = _nama.text.trim().isEmpty ? l10n.nameRequired : null;
      _employeeIdError = _employeeId.text.trim().isEmpty
          ? l10n.employeeIdRequired
          : null;
      _departemenError = _departemenTerpilih == null
          ? l10n.departmentRequired
          : null;
      _emailError = switch (email) {
        '' => l10n.emailRequired,
        // Cukup cek bentuk dasarnya — validasi beneran tetap di backend.
        _ when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) =>
          l10n.emailInvalid,
        _ => null,
      };
      _passwordError = switch (_password.text) {
        '' => l10n.passwordRequired,
        final p when p.length < 8 => l10n.passwordTooShort,
        _ => null,
      };
    });

    return _namaError == null &&
        _employeeIdError == null &&
        _departemenError == null &&
        _emailError == null &&
        _passwordError == null;
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
      await ref.read(authProvider.notifier).register(
        RegisterData(
          nama: _nama.text,
          employeeId: _employeeId.text,
          department: _departemenTerpilih!,
          email: _email.text,
          password: _password.text,
        ),
      );
      sukses = true;
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorKirim = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorKirim = l10n.errorNoConnection);
      }
    }

    if (!mounted) return;

    // Matiin state loading DULU, baru munculin dialog. Kalau kebalik, spinner
    // di tombol DAFTAR bakal terus muter di belakang dialog.
    setState(() => _loading = false);

    if (sukses) await _tampilkanSukses();
  }

  /// Sukses daftar bukan berarti bisa masuk — jelasin itu terang-terangan,
  /// jangan bikin orang nunggu sambil bingung kenapa login-nya ditolak.
  Future<void> _tampilkanSukses() async {
    final l10n = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.mark_email_read_outlined,
          size: 40,
          color: Theme.of(dialogContext).colorScheme.secondary,
        ),
        title: Text(l10n.registerSuccessTitle),
        content: Text(l10n.registerSuccessBody),
        actions: [
          AppButton(
            label: l10n.registerSuccessDismiss,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (mounted) Navigator.of(context).pop(); // balik ke layar Login
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthBrandHeader(
                    title: l10n.registerTitle,
                    subtitle: l10n.registerSubtitle,
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

                          AppTextField(
                            label: l10n.nameLabel,
                            controller: _nama,
                            hint: l10n.nameHint,
                            prefixIcon: Icons.person_outline,
                            errorText: _namaError,
                            enabled: !_loading,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: l10n.employeeIdLabel,
                            controller: _employeeId,
                            hint: 'ASM-0000',
                            prefixIcon: Icons.badge_outlined,
                            errorText: _employeeIdError,
                            enabled: !_loading,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          _DepartemenField(
                            label: l10n.departmentLabel,
                            hint: l10n.departmentHint,
                            value: _departemenTerpilih,
                            options: _departemen,
                            errorText: _departemenError,
                            enabled: !_loading,
                            onChanged: (v) =>
                                setState(() => _departemenTerpilih = v),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: l10n.emailLabel,
                            controller: _email,
                            hint: l10n.emailHint,
                            prefixIcon: Icons.mail_outline,
                            errorText: _emailError,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: l10n.passwordLabel,
                            controller: _password,
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            errorText: _passwordError,
                            helperText: l10n.passwordHelper,
                            enabled: !_loading,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          AppButton(
                            label: l10n.registerSubmit,
                            isLoading: _loading,
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
                          l10n.registerHaveAccount,
                          style: theme.textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(l10n.registerLoginLink),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const AuthPoweredBy(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartemenField extends StatelessWidget {
  const _DepartemenField({
    required this.label,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
          ),
          hint: Text(hint, style: theme.textTheme.bodyMedium),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
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
