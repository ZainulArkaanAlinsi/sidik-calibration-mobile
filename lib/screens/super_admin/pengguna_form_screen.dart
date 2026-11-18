import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart' show userListProvider;
import '../../providers/super_admin_provider.dart';
import '../../providers/technician_provider.dart';
import '../../services/auth_service.dart' show ApiException, AuthException;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import 'hak_super_admin.dart';
import 'widgets/kolom_berlabel.dart';
import 'widgets/pesan_layar.dart';

/// Tambah pengguna (admin atau teknisi) dan ubah data pengguna.
///
/// - **Tambah**: peran yang ditawarkan mengikuti izin server — Admin
///   (`pengguna.buat-admin`, `POST /users`) dan Teknisi (`teknisi.kelola`,
///   `POST /technicians`). `super_admin`, `viewer`, dan `pelanggan` tidak
///   pernah bisa dibuat dari sini.
/// - **Ubah**: hanya kolom yang BERUBAH yang dikirim (`PUT /users/{id}`).
///   Sandi tidak bisa diubah di sini — pakai Setel ulang sandi.
///
/// Sandi awal diketik dua kali, dikirim sekali, lalu dikosongkan; tidak
/// ditulis ke log atau state apa pun.
class PenggunaFormScreen extends ConsumerStatefulWidget {
  const PenggunaFormScreen({super.key, this.akun});

  /// `null` = tambah pengguna baru.
  final User? akun;

  @override
  ConsumerState<PenggunaFormScreen> createState() => _PenggunaFormScreenState();
}

class _PenggunaFormScreenState extends ConsumerState<PenggunaFormScreen> {
  /// Samakan dengan aturan server (`min:8`). Kalau salah satu digeser, yang
  /// lain ikut — kalau tidak, layar bilang oke tapi server menolak.
  static const _panjangSandiMinimal = 8;

  late final _nama = TextEditingController(text: widget.akun?.nama ?? '');
  late final _employeeId = TextEditingController(
    text: widget.akun?.employeeId ?? '',
  );
  late final _email = TextEditingController(text: widget.akun?.email ?? '');
  late final _department = TextEditingController(
    text: widget.akun?.department ?? '',
  );
  final _password = TextEditingController();
  final _ulang = TextEditingController();

  /// Peran yang dipilih (tambah) atau yang akan dikirim (ubah).
  UserRole? _peran;

  /// Kunci: nama, employee_id, email, department, password, ulang, role.
  Map<String, String> _galat = {};
  String? _galatUmum;
  String? _berhasil;
  bool _menyimpan = false;

  bool get _ubah => widget.akun != null;

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

  /// Peran yang boleh dipilih: tambah → sesuai izin server; ubah → admin /
  /// teknisi (yang bisa diberikan).
  List<UserRole> _pilihanPeran({
    required bool bolehAdmin,
    required bool bolehTeknisi,
  }) {
    if (_ubah) return UserRole.bisaDiberikan;
    return [if (bolehAdmin) UserRole.admin, if (bolehTeknisi) UserRole.teknisi];
  }

  bool _valid() {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();

    final galat = <String, String>{
      if (_nama.text.trim().isEmpty) 'nama': l10n.buatTekNamaKosong,
      if (_employeeId.text.trim().isEmpty)
        'employee_id': l10n.buatTekEmployeeIdKosong
      // `@` dibaca server sebagai email waktu login: ID pegawai ber-@ tidak
      // akan pernah bisa dipakai masuk.
      else if (_employeeId.text.contains('@'))
        'employee_id': l10n.buatTekEmployeeIdAt,
      if (email.isEmpty)
        'email': l10n.buatTekEmailKosong
      // Longgar: hanya memastikan ada `@` dan titik sesudahnya; yang
      // berwenang menolak alamat beneran tetap server.
      else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
        'email': l10n.buatTekEmailSalah,
      if (!_ubah) ...{
        // Sandi TIDAK di-trim: spasi di tepi bisa disengaja.
        if (_password.text.length < _panjangSandiMinimal)
          'password': l10n.buatTekPasswordPendek
        else if (_password.text != _ulang.text)
          'ulang': l10n.buatTekPasswordBeda,
      },
    };

    setState(() {
      _galat = galat;
      _galatUmum = null;
    });
    return galat.isEmpty;
  }

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
        'role',
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
      // Pesan umum server dipakai bila tidak ada satu pun kolom yang cocok.
      _galatUmum = dipetakan.isEmpty ? e.message : null;
    });
  }

  Future<void> _simpan() async {
    if (_menyimpan || !_valid()) return;

    final l10n = AppLocalizations.of(context);
    final peran = _peran;
    if (!_ubah && peran == null) return;

    // Mode ubah: hitung kolom yang berubah SEBELUM menyentuh jaringan.
    String? ubahNama, ubahEmail, ubahId, ubahDept;
    UserRole? ubahPeran;
    if (_ubah) {
      final a = widget.akun!;
      if (_nama.text.trim() != a.nama) ubahNama = _nama.text.trim();
      if (_email.text.trim() != a.email) ubahEmail = _email.text.trim();
      if (_employeeId.text.trim() != a.employeeId) {
        ubahId = _employeeId.text.trim();
      }
      if (_department.text.trim() != (a.department ?? '')) {
        // String kosong tetap terkirim: cara mengosongkan departemen.
        ubahDept = _department.text.trim();
      }
      if (_peran != null && _peran != a.role) ubahPeran = _peran;

      if (ubahNama == null &&
          ubahEmail == null &&
          ubahId == null &&
          ubahDept == null &&
          ubahPeran == null) {
        setState(() => _galatUmum = l10n.saFormTanpaPerubahan);
        return;
      }
    }

    setState(() {
      _menyimpan = true;
      _berhasil = null;
      _galatUmum = null;
    });

    // Salinan lokal; hidupnya hanya selama satu permintaan ini.
    final sandi = _password.text;

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      if (_ubah) {
        await ref
            .read(penggunaSaServiceProvider)
            .ubah(
              token,
              widget.akun!.id,
              nama: ubahNama,
              email: ubahEmail,
              employeeId: ubahId,
              department: ubahDept,
              role: ubahPeran,
            );
        ref.invalidate(userListProvider);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final departemen = _department.text.trim();
      if (peran == UserRole.admin) {
        await ref
            .read(penggunaSaServiceProvider)
            .buatAdmin(
              token,
              nama: _nama.text.trim(),
              employeeId: _employeeId.text.trim(),
              email: _email.text.trim(),
              password: sandi,
              department: departemen.isEmpty ? null : departemen,
            );
      } else {
        await ref
            .read(technicianServiceProvider)
            .buat(
              token,
              nama: _nama.text.trim(),
              employeeId: _employeeId.text.trim(),
              email: _email.text.trim(),
              password: sandi,
              department: departemen.isEmpty ? null : departemen,
            );
      }

      // Daftar di layar ini dan di Data Teknisi (layar lama) harus memuat
      // akun baru.
      ref.invalidate(userListProvider);
      ref.read(penggunaSaProvider.notifier).muatUlang();

      if (!mounted) return;
      final namaBaru = _nama.text.trim();
      final idBaru = _employeeId.text.trim();
      _nama.clear();
      _employeeId.clear();
      _email.clear();
      _department.clear();
      // Sandi dikosongkan begitu terkirim.
      _password.clear();
      _ulang.clear();
      setState(() {
        _galat = {};
        _berhasil = l10n.saFormBerhasilBuat(namaBaru, idBaru);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 422) {
        _petakan422(e);
      } else {
        setState(() => _galatUmum = e.message);
      }
    } on TokenHilangException {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.historySessionExpired);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _galatUmum = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _galatUmum = l10n.buatTekGagal);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  String _labelPeran(AppLocalizations l10n, UserRole r) => switch (r) {
    UserRole.admin => l10n.saPeranAdminMasterData,
    UserRole.teknisi => l10n.saPeranTeknisi,
    UserRole.viewer => l10n.saPeranViewer,
    UserRole.superAdmin => r.label,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final pilihan = _pilihanPeran(
      bolehAdmin: ref.bolehBuatAdmin,
      bolehTeknisi: ref.bolehBuatTeknisi,
    );
    final tanpaIzin = !_ubah && pilihan.isEmpty;

    // Peran terpilih bawaan: peran akun (ubah) / pilihan pertama (tambah).
    _peran ??= _ubah
        ? widget.akun!.role
        : (pilihan.contains(UserRole.teknisi)
              ? UserRole.teknisi
              : pilihan.firstOrNull);

    return Scaffold(
      appBar: AppBar(
        title: Text(_ubah ? l10n.saFormUbahJudul : l10n.saFormTambahJudul),
      ),
      body: SafeArea(
        top: false,
        child: tanpaIzin
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin)
            : ReadableWidth(
                maksimum: 560,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_berhasil != null) ...[
                      _KartuBerhasil(pesan: _berhasil!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      _ubah ? l10n.saFormIntroUbah : l10n.saFormIntroTambah,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(l10n.saFormPeran, style: tema.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    if (_ubah &&
                        !UserRole.bisaDiberikan.contains(widget.akun!.role))
                      Text(
                        l10n.saFormPeranTetap(widget.akun!.role.label),
                        style: tema.textTheme.bodyMedium,
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final r in pilihan)
                            ChoiceChip(
                              key: Key('peran-${r.api}'),
                              label: Text(_labelPeran(l10n, r)),
                              selected: _peran == r,
                              onSelected: _menyimpan
                                  ? null
                                  : (_) => setState(() => _peran = r),
                            ),
                        ],
                      ),
                    if (_galat['role'] != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _galat['role']!,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    KolomBerlabel(
                      label: l10n.buatTekNama,
                      controller: _nama,
                      enabled: !_menyimpan,
                      errorText: _galat['nama'],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(255)],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KolomBerlabel(
                      label: l10n.buatTekEmployeeId,
                      controller: _employeeId,
                      enabled: !_menyimpan,
                      errorText: _galat['employee_id'],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KolomBerlabel(
                      label: l10n.buatTekEmail,
                      controller: _email,
                      enabled: !_menyimpan,
                      errorText: _galat['email'],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(255)],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KolomBerlabel(
                      label: l10n.buatTekDepartment,
                      controller: _department,
                      enabled: !_menyimpan,
                      errorText: _galat['department'],
                      textInputAction: _ubah
                          ? TextInputAction.done
                          : TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(255)],
                    ),
                    if (!_ubah) ...[
                      const SizedBox(height: AppSpacing.md),
                      KolomBerlabel(
                        label: l10n.buatTekPassword,
                        controller: _password,
                        isPassword: true,
                        enabled: !_menyimpan,
                        errorText: _galat['password'],
                        helperText: l10n.buatTekPasswordHelper,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      KolomBerlabel(
                        label: l10n.buatTekPasswordUlang,
                        controller: _ulang,
                        isPassword: true,
                        enabled: !_menyimpan,
                        errorText: _galat['ulang'],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _simpan(),
                      ),
                    ],
                    if (_galatUmum != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _galatUmum!,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _ubah ? l10n.saFormSimpan : l10n.saFormBuat,
                      icon: _ubah
                          ? Icons.save_outlined
                          : Icons.person_add_alt_1_outlined,
                      isLoading: _menyimpan,
                      onPressed: _menyimpan ? null : _simpan,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _KartuBerhasil extends StatelessWidget {
  const _KartuBerhasil({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: tema.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(pesan, style: tema.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
