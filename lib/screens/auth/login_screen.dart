import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/biru_awan/isian_sidik.dart';
import '../../widgets/biru_awan/kartu_sidik24.dart';
import '../../widgets/biru_awan/tombol_sidik.dart';
import 'forgot_password_screen.dart';
import 'widgets/kerangka_masuk.dart';

/// Pesan buat kegagalan login yang BUKAN [AuthException].
///
/// Dulu cabang ini selalu bilang "Nggak bisa nyambung ke server" — tebakan yang
/// ditulis seolah fakta. Padahal kegagalan LOKAL mendarat di cabang yang sama:
/// `auth_provider.login` nyimpen token sesudah auth sukses, dan waktu Keychain
/// macOS nolak (errSecMissingEntitlement/-34018), yang muncul di layar tetap
/// "server bermasalah". Akibatnya sehari kebuang ngoprek `artisan serve`, IP,
/// dan adb — padahal backend-nya sehat, bahkan lagi MODE MOCK yang nggak punya
/// server sama sekali.
///
/// Aturannya sekarang: sebut server HANYA kalau errornya memang error jaringan.
/// Selain itu tampilkan penyebab aslinya — jelek dilihat, tapi bisa ditindak
/// lanjuti. Pesan yang menyesatkan jauh lebih mahal daripada pesan yang jujur
/// tapi teknis.
String _pesanGagalLogin(Object error) {
  final teknis = error.toString();
  // Dicocokin lewat teks, bukan `is SocketException`, biar file ini nggak perlu
  // impor `dart:io` (bikin build web mental).
  const penandaJaringan = [
    'SocketException',
    'TimeoutException',
    'ClientException',
    'HandshakeException',
    'Connection refused',
    'Failed host lookup',
  ];
  if (penandaJaringan.any(teknis.contains)) {
    return 'Nggak bisa nyambung ke server. Coba lagi.';
  }
  return 'Login gagal di perangkat ini: $teknis';
}

/// Layar Login — desain Biru Awan (artboard E0): hero langit dengan plat logo
/// dan kartu putih berisi isian serta tombol Masuk.
/// Isinya sama persis kayak sebelumnya: login pakai ID pegawai **atau** email,
/// validasi lokal dulu, error dari server ditampilin apa adanya, plus panel
/// bantuan buat mode dev/mock. Cuma susunan dan gayanya yang berubah.
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
  bool _sandiTampak = false;

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

  void _bukaLupaPassword() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()));

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final loading = auth.isLoading;

    // Cuma pesan dari AuthException yang ditampilin apa adanya. Sisanya lewat
    // [_pesanGagalLogin] — lihat catatan di sana kenapa nggak boleh main tuduh
    // server.
    final errorLogin = switch (auth) {
      AsyncError(:final AuthException error) => error.message,
      AsyncError(:final error) => _pesanGagalLogin(error),
      _ => null,
    };

    return KerangkaMasuk(
      isiKartu: [
        Semantics(
          header: true,
          child: Text(
            l10n.masukJudul,
            style: HurufMasuk.judulKartu.copyWith(color: m.tinta),
          ),
        ),
        if (errorLogin != null) PesanGalatMasuk(pesan: errorLogin),
        IsianSidik(
          label: l10n.loginIdentifierLabel,
          controller: _identifier,
          galat: _identifierError,
          enabled: !loading,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
        ),
        IsianSidik(
          label: l10n.passwordLabel,
          controller: _password,
          obscureText: !_sandiTampak,
          galat: _passwordError,
          enabled: !loading,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          akhir: _TombolTampilkanSandi(
            tampak: _sandiTampak,
            onTap: () => setState(() => _sandiTampak = !_sandiTampak),
          ),
        ),
        // Tanpa link "Daftar": akun dibuat admin, bukan didaftarkan sendiri.
        // Backend menjawab 404 buat `POST /register`, jadi tombolnya cuma bakal
        // nganterin orang ke jalan buntu.
        Align(
          alignment: Alignment.centerRight,
          child: TombolSidik(
            label: l10n.forgotPasswordLink,
            ragam: RagamTombolSidik.teks,
            onPressed: loading ? null : _bukaLupaPassword,
          ),
        ),
        TombolSidik(
          label: 'MASUK',
          ikon: Icons.arrow_forward,
          sibuk: loading,
          onPressed: _submit,
        ),
      ],
      bawahKartu: const _DevHint(),
    );
  }
}

/// "Tampilkan" / "Sembunyikan" sandi di ujung isian. Teks 14 tinta kedua
/// (artboard E0), area ketuk >= 48 dp, dibaca pembaca layar sebagai tombol
/// dengan kata yang sama dengan yang tampak.
class _TombolTampilkanSandi extends StatelessWidget {
  const _TombolTampilkanSandi({required this.tampak, required this.onTap});

  final bool tampak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final label = tampak
        ? l10n.masukSembunyikanSandi
        : l10n.masukTampilkanSandi;

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: UkuranBiruAwan.tombolKembali,
            minHeight: UkuranBiruAwan.tombolKembali,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel bantuan dev/mock — dipendem di prod. Isinya sama kayak sebelumnya,
/// cuma dikasih kulit Biru Awan (kartu kabut).
class _DevHint extends StatelessWidget {
  const _DevHint();

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProd) return const SizedBox.shrink();

    final m = SidikMaterial.of(context);
    final mock = AppConfig.useMock;

    return KartuSidik24(
      latar: LatarKartu.kabut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Text(
            mock ? 'MODE MOCK — TANPA SERVER' : 'MODE DEV — NEMBAK API ASLI',
            style: HurufBiruAwan.stempel.copyWith(color: m.tinta),
          ),
          Text(
            // Mock & API asli sekarang pakai kredensial SAMA: SDK-000x /
            // rahasia123. Dulu mock masih `ASM-` + `password123` (sisa nama
            // "asmo") sementara backend udah `SDK-` + `rahasia123` — beda dua
            // set bikin orang ngetik yang diinget lalu ditolak terus. Disamain
            // biar satu set aja yang perlu diinget.
            mock
                ? 'SDK-0001 (admin) · SDK-0002 (teknisi) · SDK-0003 (viewer)\n'
                      'Password: rahasia123'
                : 'SDK-0001 (admin) · SDK-0002 (teknisi) · SDK-0003 (viewer)\n'
                      'SDK-0099 (pending, buat nyoba akun ditolak)\n'
                      'Password: rahasia123\n'
                      'Server: ${AppConfig.apiBaseUrl}',
            style: HurufBiruAwan.keteranganKecil.copyWith(color: m.tinta),
          ),
        ],
      ),
    );
  }
}
