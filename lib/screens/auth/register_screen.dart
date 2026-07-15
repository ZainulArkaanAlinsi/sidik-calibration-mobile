import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/neu.dart';

/// Daftar akun teknisi — gaya soft UI / neumorphism (lihat `widgets/neu.dart`).
///
/// Penting & nggak berubah: daftar **nggak langsung bisa masuk**. Akunnya
/// `pending` sampai admin nyetujuin & ngasih role. Kalau siapa pun yang daftar
/// langsung aktif, orang luar bisa bikin akun terus ngintip data pelanggan.
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
    final c = NeuColors.of(context);

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _NeuBackButton(
                      onTap: _loading ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: NeuBrandBadge(icon: Icons.badge_outlined)),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Daftar Akun',
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
                      'Buat profil teknisi kamu',
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
                          _NeuErrorBanner(message: _errorKirim!),
                          const SizedBox(height: 18),
                        ],

                        NeuTextField(
                          icon: Icons.person_outline,
                          controller: _nama,
                          hint: 'Nama lengkap',
                          errorText: _namaError,
                          enabled: !_loading,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        NeuTextField(
                          icon: Icons.badge_outlined,
                          controller: _employeeId,
                          hint: 'ID Pegawai (mis. ASM-0000)',
                          errorText: _employeeIdError,
                          enabled: !_loading,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        _NeuDepartemen(
                          value: _departemenTerpilih,
                          options: _departemen,
                          errorText: _departemenError,
                          enabled: !_loading,
                          onChanged: (v) =>
                              setState(() => _departemenTerpilih = v),
                        ),
                        const SizedBox(height: 16),

                        NeuTextField(
                          icon: Icons.mail_outline,
                          controller: _email,
                          hint: 'Email (nama@pt-sidik.com)',
                          errorText: _emailError,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        NeuTextField(
                          icon: Icons.lock_outline,
                          controller: _password,
                          hint: 'Password',
                          obscure: true,
                          errorText: _passwordError,
                          helperText: 'Minimal 8 karakter',
                          enabled: !_loading,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 26),

                        NeuButton(
                          label: 'DAFTAR',
                          loading: _loading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sudah punya akun?',
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                        const SizedBox(width: 4),
                        NeuTextLink(
                          label: 'Masuk',
                          strong: true,
                          onTap: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const AuthPoweredBy(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown departemen bergaya soft. Tetap membungkus
/// `DropdownButtonFormField<String>` supaya test register nggak pecah.
class _NeuDepartemen extends StatelessWidget {
  const _NeuDepartemen({
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
    final c = NeuColors.of(context);
    // Ambil dari textTheme biar bawa fontFamily Inter. `DropdownButtonFormField`
    // GANTI font-nya kalau `style`-nya nggak punya family — di HP jadi font
    // sistem (bukan Inter), di test malah jadi kotak-kotak.
    final txt = Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16);

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
                  // Bungkus Theme lokal: nolin fill, border, DAN highlight
                  // fokus/hover dari tema global (Titanium). Tanpa ini,
                  // InkWell dropdown-nya ninggalin balok abu di dalam kolom.
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      canvasColor: c.base,
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        fillColor: Colors.transparent,
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
                      style: txt?.copyWith(color: c.text),
                      decoration: const InputDecoration(),
                      hint: Text(
                        'Pilih departemen',
                        style: txt?.copyWith(color: c.textMuted),
                      ),
                      items: [
                        for (final o in options)
                          DropdownMenuItem(
                            value: o,
                            child: Text(o, style: txt?.copyWith(color: c.text)),
                          ),
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

class _NeuBackButton extends StatelessWidget {
  const _NeuBackButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuRaised(
        circle: true,
        distance: 4,
        blur: 8,
        padding: const EdgeInsets.all(11),
        child: Icon(Icons.arrow_back, size: 20, color: c.text),
      ),
    );
  }
}

/// Banner error kirim — versi soft (cekung, teks merah lembut).
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
