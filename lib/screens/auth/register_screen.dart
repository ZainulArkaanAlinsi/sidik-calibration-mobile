import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
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

  bool _validasi() {
    final email = _email.text.trim();

    setState(() {
      _namaError = _nama.text.trim().isEmpty ? 'Nama wajib diisi.' : null;
      _employeeIdError = _employeeId.text.trim().isEmpty
          ? 'ID pegawai wajib diisi.'
          : null;
      _departemenError = _departemenTerpilih == null
          ? 'Pilih departemen dulu.'
          : null;
      _emailError = switch (email) {
        '' => 'Email wajib diisi.',
        // Cukup cek bentuk dasarnya — validasi beneran tetap di backend.
        _ when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) =>
          'Format email nggak valid.',
        _ => null,
      };
      _passwordError = switch (_password.text) {
        '' => 'Password wajib diisi.',
        final p when p.length < 8 => 'Password minimal 8 karakter.',
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
    if (!_validasi()) return;

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
        setState(() => _errorKirim = 'Nggak bisa nyambung ke server. Coba lagi.');
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.mark_email_read_outlined,
          size: 40,
          color: Theme.of(dialogContext).colorScheme.secondary,
        ),
        title: const Text('Pendaftaran terkirim'),
        content: const Text(
          'Akun kamu masih menunggu persetujuan admin. Kamu belum bisa masuk '
          'sampai admin nyetujuin dan nentuin role kamu.\n\n'
          'Hubungi admin kalau kelamaan nggak ada kabar.',
        ),
        actions: [
          AppButton(
            label: 'MENGERTI',
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
                  const AuthBrandHeader(
                    title: 'Daftar Akun',
                    subtitle: 'Buat profil teknisi kamu',
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
                            label: 'Nama Lengkap',
                            controller: _nama,
                            hint: 'mis. Andi Pratama',
                            prefixIcon: Icons.person_outline,
                            errorText: _namaError,
                            enabled: !_loading,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: 'ID Pegawai',
                            controller: _employeeId,
                            hint: 'ASM-0000',
                            prefixIcon: Icons.badge_outlined,
                            errorText: _employeeIdError,
                            enabled: !_loading,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          _DepartemenField(
                            value: _departemenTerpilih,
                            options: _departemen,
                            errorText: _departemenError,
                            enabled: !_loading,
                            onChanged: (v) =>
                                setState(() => _departemenTerpilih = v),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: 'Email',
                            controller: _email,
                            hint: 'nama@pt-sidik.com',
                            prefixIcon: Icons.mail_outline,
                            errorText: _emailError,
                            enabled: !_loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            label: 'Password',
                            controller: _password,
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            errorText: _passwordError,
                            helperText: 'Minimal 8 karakter',
                            enabled: !_loading,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          AppButton(
                            label: 'DAFTAR',
                            isLoading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Sudah punya akun?', style: theme.textTheme.bodySmall),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Masuk'),
                      ),
                    ],
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
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

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
        Text('DEPARTEMEN', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
          ),
          hint: Text('Pilih departemen', style: theme.textTheme.bodyMedium),
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
