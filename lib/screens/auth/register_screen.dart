import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'widgets/neu.dart';

/// Daftar akun teknisi — gaya soft UI / neumorphism.
///
/// Penting: daftar **nggak langsung bisa masuk**. Akunnya `pending` sampai
/// admin nyetujuin & ngasih role. Kalau siapa pun yang daftar langsung aktif,
/// orang luar bisa bikin akun terus ngintip data kalibrasi pelanggan.
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
      if (mounted) setState(() => _errorKirim = l10n.errorNoConnection);
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (sukses) await _tampilkanSukses();
  }

  Future<void> _tampilkanSukses() async {
    final l10n = AppLocalizations.of(context);
    final c = NeuColors.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.base,
        icon: Icon(Icons.mark_email_read_outlined, size: 40, color: c.text),
        title: Text(
          l10n.registerSuccessTitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.text),
        ),
        content: Text(
          l10n.registerSuccessBody,
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NeuButton(
              label: l10n.registerSuccessDismiss,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    );

    if (mounted) Navigator.of(context).pop(); // balik ke layar Login
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: NeuBackButton(
                      onTap: _loading ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(child: NeuBrandBadge()),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      l10n.registerTitle,
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
                      l10n.registerSubtitle,
                      style: TextStyle(fontSize: 14, color: c.textMuted),
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (_errorKirim != null) ...[
                    NeuErrorBanner(message: _errorKirim!),
                    const SizedBox(height: 18),
                  ],

                  NeuFieldLabel(l10n.nameLabel),
                  NeuTextField(
                    icon: Icons.person_outline,
                    controller: _nama,
                    hint: l10n.nameHint,
                    errorText: _namaError,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  NeuFieldLabel(l10n.employeeIdLabel),
                  NeuTextField(
                    icon: Icons.badge_outlined,
                    controller: _employeeId,
                    hint: 'ASM-0000',
                    errorText: _employeeIdError,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  NeuFieldLabel(l10n.departmentLabel),
                  _NeuDepartemen(
                    hint: l10n.departmentHint,
                    value: _departemenTerpilih,
                    options: _departemen,
                    errorText: _departemenError,
                    enabled: !_loading,
                    onChanged: (v) => setState(() => _departemenTerpilih = v),
                  ),
                  const SizedBox(height: 16),

                  NeuFieldLabel(l10n.emailLabel),
                  NeuTextField(
                    icon: Icons.mail_outline,
                    controller: _email,
                    hint: l10n.emailHint,
                    errorText: _emailError,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  NeuFieldLabel(l10n.passwordLabel),
                  NeuTextField(
                    icon: Icons.lock_outline,
                    controller: _password,
                    hint: '••••••••',
                    obscure: true,
                    errorText: _passwordError,
                    helperText: l10n.passwordHelper,
                    enabled: !_loading,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 30),

                  NeuButton(
                    label: l10n.registerSubmit,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 22),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.registerHaveAccount,
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                        const SizedBox(width: 6),
                        NeuTextLink(
                          label: l10n.registerLoginLink,
                          strong: true,
                          onTap: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  const NeuPoweredBy(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown departemen bergaya soft (kolom cekung). Tetap membungkus
/// `DropdownButtonFormField<String>` supaya test register nggak pecah.
class _NeuDepartemen extends StatelessWidget {
  const _NeuDepartemen({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    // Ambil dari textTheme biar bawa fontFamily Inter. DropdownButtonFormField
    // GANTI font-nya kalau style-nya nggak punya family — di test jadi kotak.
    final txt = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: c.text,
      fontSize: 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.55,
          child: NeuInset(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.apartment_outlined, size: 20, color: c.textMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Theme(
                    // Nolin fill/border/highlight bawaan Material — biar bersih
                    // di dalam kolom cekung neu.
                    data: Theme.of(context).copyWith(
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      canvasColor: c.base,
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: value,
                      isExpanded: true,
                      onChanged: enabled ? onChanged : null,
                      icon: Icon(Icons.arrow_drop_down, color: c.textMuted),
                      dropdownColor: c.base,
                      style: txt,
                      decoration: const InputDecoration(),
                      hint: Text(hint, style: txt?.copyWith(color: c.textMuted)),
                      items: [
                        for (final o in options)
                          DropdownMenuItem(value: o, child: Text(o, style: txt)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 6),
            child: Text(
              errorText!,
              style: TextStyle(fontSize: 12, color: c.danger),
            ),
          ),
      ],
    );
  }
}
