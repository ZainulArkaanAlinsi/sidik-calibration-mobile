import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/teknisi.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/izin_provider.dart';
import '../../providers/master_data_provider.dart' show userListProvider;
import '../../providers/technician_provider.dart';
import '../../services/auth_service.dart' show ApiException, AuthException;
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/readable_width.dart';

/// Buat akun teknisi baru (`POST /api/technicians`) — admin & super admin.
///
/// Layar sendiri, bukan tombol di Data Teknisi: Data Teknisi mengelola akun
/// yang SUDAH ada (`/users*`) dan tidak diubah perilakunya.
///
/// ## Yang sengaja tidak ada di sini
///
/// - **Pilihan role.** Server memaksa `teknisi` (`TechnicianRequest` tidak
///   menerima `role`); layar yang menawarkannya cuma jadi jalan pintas
///   membuat akun admin yang selalu ditolak.
/// - **Pilihan status.** Akun buatan admin langsung `aktif`.
/// - **Tampilan sandi.** Sandi awal diketik dua kali, dikirim sekali, lalu
///   dikosongkan; tidak ditulis ke log, banner, atau penyimpanan apa pun.
class BuatTeknisiScreen extends ConsumerWidget {
  const BuatTeknisiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Gerbangnya sama dengan `GET /technicians` (satu grup `role:admin` dengan
    // `POST`); `teknisi.kelola` memang dipetakan ke rute itu di server.
    final boleh = ref.bolehkah(
      NamaIzin.teknisiKelola,
      cadangan: ref.watch(authProvider).value?.role.hakAdmin ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.buatTekJudul)),
      body: boleh
          ? const ReadableWidth(child: _Formulir())
          : _HanyaAdmin(pesan: l10n.buatTekHanyaAdmin),
    );
  }
}

class _HanyaAdmin extends StatelessWidget {
  const _HanyaAdmin({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Formulir extends ConsumerStatefulWidget {
  const _Formulir();

  @override
  ConsumerState<_Formulir> createState() => _FormulirState();
}

class _FormulirState extends ConsumerState<_Formulir> {
  /// Samakan dengan `TechnicianRequest` di server. Kalau salah satu digeser,
  /// yang lain ikut — kalau tidak, admin ditolak server padahal layarnya
  /// bilang oke.
  static const _panjangSandiMinimal = 8;
  static const _maksNama = 255;
  static const _maksEmployeeId = 50;
  static const _maksEmail = 255;
  static const _maksDepartemen = 255;

  final _nama = TextEditingController();
  final _employeeId = TextEditingController();
  final _email = TextEditingController();
  final _department = TextEditingController();
  final _password = TextEditingController();
  final _ulang = TextEditingController();

  /// Galat per kolom, berkunci nama kolom server (`nama`, `employee_id`,
  /// `email`, `department`, `password`) + `ulang` (cuma ada di layar).
  Map<String, String> _galat = {};
  String? _galatUmum;
  Teknisi? _berhasil;
  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _employeeId.dispose();
    _email.dispose();
    _department.dispose();
    _password.dispose();
    _ulang.dispose();
    super.dispose();
  }

  /// Divalidasi di sini juga, bukan cuma ngandelin `422` server — admin tidak
  /// perlu menunggu bolak-balik cuma untuk tahu kolomnya kosong.
  bool _valid() {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();

    final galat = <String, String>{
      if (_nama.text.trim().isEmpty) 'nama': l10n.buatTekNamaKosong,
      if (_employeeId.text.trim().isEmpty)
        'employee_id': l10n.buatTekEmployeeIdKosong
      // Server membaca identifier login yang memuat `@` sebagai EMAIL
      // (`AuthController::login`), jadi ID pegawai ber-@ tidak akan pernah
      // bisa dipakai login — akunnya jadi terkunci sejak dibuat.
      else if (_employeeId.text.contains('@'))
        'employee_id': l10n.buatTekEmployeeIdAt,
      if (email.isEmpty)
        'email': l10n.buatTekEmailKosong
      // Sengaja longgar: cuma memastikan ada `@` dan titik sesudahnya. Yang
      // berwenang menolak alamat beneran tetap server.
      else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
        'email': l10n.buatTekEmailSalah,
      // Sandi TIDAK di-trim: spasi di tepi bisa disengaja.
      if (_password.text.length < _panjangSandiMinimal)
        'password': l10n.buatTekPasswordPendek
      else if (_password.text != _ulang.text)
        'ulang': l10n.buatTekPasswordBeda,
    };

    setState(() {
      _galat = galat;
      _galatUmum = null;
    });

    return galat.isEmpty;
  }

  /// `422` Laravel: `{"errors": {"email": ["…"]}}`. Pesan pertama tiap kolom
  /// ditempel ke kolomnya; kalau bentuknya tidak dikenali, pesan umum server
  /// yang dipakai (jangan diganti kalimat sendiri — server tahu sebabnya).
  void _petakan422(ApiException e) {
    final errors = e.body['errors'];
    final dipetakan = <String, String>{};

    if (errors is Map) {
      const dikenal = {
        'nama',
        'employee_id',
        'email',
        'department',
        'password',
      };
      for (final MapEntry(:key, :value) in errors.entries) {
        if (!dikenal.contains(key)) continue;
        if (value is List && value.isNotEmpty) {
          dipetakan['$key'] = '${value.first}';
        } else if (value is String) {
          dipetakan['$key'] = value;
        }
      }
    }

    setState(() {
      _galat = dipetakan;
      _galatUmum = dipetakan.isEmpty ? e.message : null;
    });
  }

  Future<void> _simpan() async {
    if (_menyimpan || !_valid()) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _menyimpan = true;
      _berhasil = null;
      _galatUmum = null;
    });

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      final departemen = _department.text.trim();
      final baru = await ref
          .read(technicianServiceProvider)
          .buat(
            token,
            nama: _nama.text.trim(),
            employeeId: _employeeId.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            department: departemen.isEmpty ? null : departemen,
          );

      // Daftar akun di layar Data Teknisi harus memuat akun baru ini waktu
      // dibuka berikutnya.
      ref.invalidate(userListProvider);

      if (!mounted) return;
      _nama.clear();
      _employeeId.clear();
      _email.clear();
      _department.clear();
      // Sandi dikosongkan begitu terkirim: tidak ada alasan menahannya di
      // memori widget lebih lama.
      _password.clear();
      _ulang.clear();
      setState(() {
        _galat = {};
        _berhasil = baru;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 422) {
        _petakan422(e);
      } else {
        // 403/404/429/5xx: pesan server sudah manusiawi (`ApiClient`).
        setState(() => _galatUmum = e.message);
      }
    } on TokenHilangException {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.historySessionExpired);
    } on AuthException catch (e) {
      // Koneksi putus dkk.: pesannya sudah dirancang untuk dibaca user.
      if (!mounted) return;
      setState(() => _galatUmum = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.buatTekGagal);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (_berhasil case final baru?) ...[
          _Berhasil(pesan: l10n.buatTekBerhasil(baru.nama, baru.employeeId)),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          l10n.buatTekIntro,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.buatTekNama,
          controller: _nama,
          errorText: _galat['nama'],
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(_maksNama)],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.buatTekEmployeeId,
          controller: _employeeId,
          errorText: _galat['employee_id'],
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(_maksEmployeeId)],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.buatTekEmail,
          controller: _email,
          errorText: _galat['email'],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(_maksEmail)],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.buatTekDepartment,
          controller: _department,
          errorText: _galat['department'],
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(_maksDepartemen)],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.buatTekPassword,
          controller: _password,
          isPassword: true,
          errorText: _galat['password'],
          helperText: l10n.buatTekPasswordHelper,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.buatTekPasswordUlang,
          controller: _ulang,
          isPassword: true,
          errorText: _galat['ulang'],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _simpan(),
        ),
        if (_galatUmum case final pesan?) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              pesan,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.buatTekSimpan,
          icon: Icons.person_add_alt_1_outlined,
          isLoading: _menyimpan,
          onPressed: _menyimpan ? null : _simpan,
        ),
      ],
    );
  }
}

class _Berhasil extends StatelessWidget {
  const _Berhasil({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(pesan, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
