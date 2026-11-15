import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/biru_awan/isian_sidik.dart';
import '../../widgets/biru_awan/tombol_bulat.dart';
import '../../widgets/biru_awan/tombol_sidik.dart';
import '../../widgets/biru_awan/ubin_ikon.dart';
import 'widgets/kerangka_masuk.dart';

/// Reset password — 3 state sesuai catatan harian 20 Jul:
/// `normal` (form) · `sukses` (email terkirim) · `error` (email nggak terdaftar).
///
/// Desain Biru Awan, kepalanya sama dengan layar Login (artboard E0): hero
/// langit + kartu putih (lihat `widgets/kerangka_masuk.dart`).
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

  void _kembali() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return _terkirim ? _panelSukses() : _form();
  }

  Widget _form() {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);

    return KerangkaMasuk(
      kiriAtas: TombolBulat(
        ikon: Icons.arrow_back,
        label: l10n.biruAwanKembali,
        onPressed: _loading ? null : _kembali,
      ),
      isiKartu: [
        Semantics(
          header: true,
          child: Text(
            l10n.forgotTitle,
            style: HurufMasuk.judulKartu.copyWith(color: m.tinta),
          ),
        ),
        Text(
          'Kami kirim link reset ke email kamu',
          style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
        ),
        if (_errorKirim != null) PesanGalatMasuk(pesan: _errorKirim!),
        Text(
          'Masukin email yang kamu pakai waktu daftar. Reset password '
          'lewat email, bukan lewat ID pegawai — biar yang bisa ganti '
          'password cuma orang yang megang emailnya.',
          style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
        ),
        IsianSidik(
          label: l10n.emailLabel,
          petunjuk: l10n.emailHint,
          controller: _email,
          galat: _emailError,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        TombolSidik(
          label: 'KIRIM LINK RESET',
          sibuk: _loading,
          onPressed: _submit,
        ),
      ],
      bawahKartu: Center(
        child: TombolSidik(
          label: l10n.backToLogin,
          ragam: RagamTombolSidik.teks,
          onPressed: _loading ? null : _kembali,
        ),
      ),
    );
  }

  Widget _panelSukses() {
    final m = SidikMaterial.of(context);
    final email = _email.text.trim();

    return KerangkaMasuk(
      isiKartu: [
        const Align(
          alignment: Alignment.centerLeft,
          child: UbinIkon.baris(
            ikon: Icons.mark_email_read_outlined,
            warna: IsiBiruAwan.kabut,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            'Link reset terkirim',
            style: HurufMasuk.judulKartu.copyWith(color: m.tinta),
          ),
        ),
        Text(
          'Kami udah kirim link reset password ke $email.\n\n'
          'Cek juga folder spam kalau nggak nemu. Link-nya berlaku terbatas, '
          'jadi jangan kelamaan.',
          style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
        ),
        TombolSidik(label: 'BALIK KE LOGIN', onPressed: _kembali),
      ],
    );
  }
}
