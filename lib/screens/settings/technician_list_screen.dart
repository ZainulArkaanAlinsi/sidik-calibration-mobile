import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/user.dart';
import '../../core/utils/inisial_nama.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/panorama_kartu.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/sidik_loader.dart';

/// Ambang lebar buat pecah jadi dua kolom. Sama dengan ambang di
/// `MasterDetailPane` — satu angka buat satu app.
const _ambangDuaKolom = 900.0;

/// Data Teknisi — kelola akun (setujui pendaftar, tetapkan role, nonaktifkan,
/// reset password).
///
/// **Nggak ada tombol Tambah maupun Hapus**, dan itu disengaja: layar ini jalan
/// di atas `GET /users` + approve/reject/reset-password. Akun lahir dari orang
/// yang daftar sendiri lewat layar Register (status `pending`), lalu admin
/// nyetujui di sini sambil nentuin rolenya. Akun dinonaktifkan, bukan dihapus,
/// biar sesi kalibrasi lama tetap punya jejak siapa tekniknya.
///
/// Sejak 20 Jul backend punya `/api/technicians` yang ada create & delete-nya
/// khusus role `teknisi`. Layar ini belum pindah ke situ — kalau nanti pindah,
/// tombol Tambah & Hapus baru masuk akal ada di sini.
class TechnicianListScreen extends ConsumerWidget {
  const TechnicianListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.bolehkah(
      NamaIzin.akunKelola,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teknisiTitle)),
      body: admin ? const _Isi() : _HanyaAdmin(pesan: l10n.teknisiHanyaAdmin),
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

class _Isi extends ConsumerWidget {
  const _Isi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(userListProvider);
    final controller = ref.read(userListProvider.notifier);
    final aktif = controller.statusAktif;

    final filter = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final (nilai, label) in <(String?, String)>[
            (null, l10n.teknisiFilterSemua),
            ('pending', l10n.teknisiFilterPending),
            ('aktif', l10n.teknisiFilterAktif),
            ('nonaktif', l10n.teknisiFilterNonaktif),
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(label),
                selected: aktif == nilai,
                onSelected: (_) => controller.saring(nilai),
              ),
            ),
        ],
      ),
    );

    final Widget daftar = switch (async) {
      AsyncData(:final value) when value.isEmpty => _Pesan(
        ikon: Icons.people_outline,
        teks: l10n.teknisiKosong,
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: controller.muatUlang,
        // Di jendela laptop, satu kolom kartu yang dibentangin penuh bikin
        // nama di kiri kepisah jauh dari badge status di kanan — mesti dipindai
        // bolak-balik. Di atas ambang, isinya dibatasi lebarnya lalu dipecah
        // jadi dua kolom; di HP dua-duanya nggak kepakai dan tata letaknya
        // persis kayak sebelumnya.
        child: LayoutBuilder(
          builder: (context, batas) {
            final duaKolom = batas.maxWidth >= _ambangDuaKolom;

            return ReadableWidth(
              child: duaKolom
                  ? _DuaKolom(akun: value)
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: value.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _KartuAkun(akun: value[i]),
                    ),
            );
          },
        ),
      ),
      AsyncError() => _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: l10n.teknisiLoadGagal,
        aksi: AppButton(
          label: l10n.teknisiRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: controller.muatUlang,
        ),
      ),
      _ => const Center(child: SidikLoader(size: 88)),
    };

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        filter,
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: daftar),
      ],
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.aksi});

  final IconData ikon;
  final String teks;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              teks,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (aksi != null) ...[const SizedBox(height: AppSpacing.lg), aksi!],
          ],
        ),
      ),
    );
  }
}

class _KartuAkun extends ConsumerWidget {
  const _KartuAkun({required this.akun});

  final User akun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Tombol melar penuh itu benar di HP (sasaran sentuh gede buat teknisi
    // yang mencet sambil pegang alat), salah di jendela laptop — di situ dia
    // jadi spanduk selebar setengah layar.
    final ringkas = MediaQuery.sizeOf(context).width >= _ambangDuaKolom;

    return Card(
      // Panorama dilukis sampai mepet tepi, jadi kartunya yang motong — bukan
      // panoramanya yang dikasih radius sendiri.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanoramaKartu(
            // Benihnya id akun: panorama tiap orang beda tapi tetap sama tiap
            // kali layarnya dibuka. Kalau pakai angka acak biasa, langitnya
            // ganti tiap scroll.
            benih: akun.id,
            tinggi: 104,
            anak: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Align(
                alignment: Alignment.topRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      label: akun.status.label,
                      tone: switch (akun.status) {
                        UserStatus.aktif => BadgeTone.success,
                        UserStatus.pending => BadgeTone.warning,
                        UserStatus.nonaktif => BadgeTone.neutral,
                      },
                      icon: switch (akun.status) {
                        UserStatus.aktif => Icons.check_circle_outline,
                        UserStatus.pending => Icons.hourglass_empty,
                        UserStatus.nonaktif => Icons.block_outlined,
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    StatusBadge(
                      label: akun.role.label,
                      tone: akun.role.isAdmin
                          ? BadgeTone.info
                          : BadgeTone.neutral,
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ruang buat avatar yang nyempil dari panorama. Nama & email
                // sengaja NGGAK ikut naik: teks gelap di atas laut yang terang
                // itu batas kontras yang nggak perlu diambil, dan garis lukisan
                // yang motong tengah baris bikin namanya susah dibaca.
                Padding(
                  padding: const EdgeInsets.only(left: 74, top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        akun.nama,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        akun.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        akun.employeeId.isEmpty
                            ? l10n.teknisiTanpaEmployeeId
                            : akun.employeeId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (akun.status == UserStatus.pending)
                  AppButton(
                    label: l10n.teknisiSetujui,
                    ringkas: ringkas,
                    icon: Icons.check,
                    onPressed: () => _setujui(context, ref),
                  ),
                if (akun.status != UserStatus.nonaktif)
                  AppButton(
                    label: l10n.teknisiTolak,
                    ringkas: ringkas,
                    icon: Icons.block_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _tolak(context, ref),
                  ),
                if (akun.status == UserStatus.aktif)
                  AppButton(
                    label: l10n.teknisiResetPassword,
                    ringkas: ringkas,
                    icon: Icons.lock_reset,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _resetPassword(context, ref),
                  ),
                // Sengaja muncul di SEMUA status, termasuk `pending` dan
                // `nonaktif`. Justru akun yang salah ketik emailnya sering
                // nyangkut di pending — kalau tombolnya cuma ada waktu aktif,
                // yang paling butuh dibetulin malah nggak bisa disentuh.
                AppButton(
                  label: l10n.teknisiEdit,
                  ringkas: ringkas,
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _edit(context, ref),
                ),
              ],
                ),
              ],
            ),
          ),
        ],
          ),
          // Avatar dipasang melayang, bukan di dalam Column: dia harus nembus
          // batas panorama, dan anak Column nggak bisa keluar dari jatahnya
          // tanpa geser semua yang di bawahnya.
          Positioned(
            left: AppSpacing.md,
            top: 104 - 29,
            child: _AvatarAkun(akun: akun),
          ),
        ],
      ),
    );
  }

  Future<void> _setujui(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Role ditentukan admin di sini — backend mewajibkan field `role` di
    // request approve, dan sengaja nggak mercayai apa yang diisi pendaftar.
    final role = await showDialog<UserRole>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.teknisiPilihRole),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in UserRole.values)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(r.label),
                onTap: () => Navigator.of(dialogContext).pop(r),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.teknisiPilihRoleBatal),
          ),
        ],
      ),
    );

    if (role == null) return;

    try {
      await ref.read(userListProvider.notifier).setujui(akun.id, role);
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiDisetujui)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiGagal)));
    }
  }

  Future<void> _tolak(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.teknisiKonfirmTolakJudul),
        content: Text(l10n.teknisiKonfirmTolakIsi),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.teknisiPilihRoleBatal),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.teknisiTolak),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    try {
      await ref.read(userListProvider.notifier).tolak(akun.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiDitolak)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiGagal)));
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Password barunya diketik admin di sini. Backend mewajibkan field
    // `password` — sebelumnya body-nya dikirim kosong, jadi aksi ini selalu
    // gagal 422 tanpa ada yang sadar.
    final passwordBaru = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ResetPasswordDialog(nama: akun.nama),
    );

    if (passwordBaru == null) return;

    try {
      await ref.read(userListProvider.notifier).resetPassword(
        akun.id,
        passwordBaru,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.teknisiPasswordDireset)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiGagal)));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showDialog<_DataAkun>(
      context: context,
      builder: (_) => _EditAkunDialog(akun: akun),
    );

    if (hasil == null) return;

    try {
      await ref
          .read(userListProvider.notifier)
          .ubah(
            akun.id,
            nama: hasil.nama,
            email: hasil.email,
            employeeId: hasil.employeeId,
            department: hasil.department,
            role: hasil.role,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiDiubah)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teknisiGagal)));
    }
  }
}

/// Isi form edit akun yang dibalikin dialog ke pemanggilnya.
class _DataAkun {
  const _DataAkun({
    required this.nama,
    required this.email,
    required this.employeeId,
    required this.department,
    required this.role,
  });

  final String nama;
  final String email;
  final String employeeId;

  /// String kosong = admin sengaja ngosongin departemennya.
  final String department;

  final UserRole role;
}

/// Dialog betulin data akun (`PUT /api/users/{id}`).
///
/// Ada karena reset password jalannya lewat **email** sedangkan login pakai
/// **ID pegawai**: orang yang salah ketik emailnya waktu daftar kekunci
/// selamanya kalau nggak ada yang bisa mbenerin.
///
/// **Status nggak diedit di sini** walaupun backend nerima. Menonaktifkan akun
/// udah punya jalannya sendiri (tombol Tolak), dan dua pintu ke hal yang sama
/// cuma bikin admin ragu mana yang bener.
class _EditAkunDialog extends StatefulWidget {
  const _EditAkunDialog({required this.akun});

  final User akun;

  @override
  State<_EditAkunDialog> createState() => _EditAkunDialogState();
}

class _EditAkunDialogState extends State<_EditAkunDialog> {
  late final _nama = TextEditingController(text: widget.akun.nama);
  late final _email = TextEditingController(text: widget.akun.email);
  late final _employeeId = TextEditingController(text: widget.akun.employeeId);
  late final _department = TextEditingController(
    text: widget.akun.department ?? '',
  );
  late UserRole _role = widget.akun.role;

  String? _errorNama;
  String? _errorEmail;
  String? _errorEmployeeId;

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _employeeId.dispose();
    _department.dispose();
    super.dispose();
  }

  /// Divalidasi di sini juga, bukan cuma ngandelin `422` backend — admin nggak
  /// perlu nunggu bolak-balik ke server cuma buat tahu kolomnya kosong.
  bool _valid() {
    final nama = _nama.text.trim();
    final email = _email.text.trim();
    final employeeId = _employeeId.text.trim();
    final l10n = AppLocalizations.of(context);

    setState(() {
      _errorNama = nama.isEmpty ? l10n.teknisiEditNamaKosong : null;
      _errorEmail = switch (email) {
        '' => l10n.teknisiEditEmailKosong,
        // Sengaja longgar: cuma mastiin ada `@` dan titik sesudahnya. Validasi
        // email yang ketat justru sering nolak alamat yang sah, dan yang
        // berwenang nolak beneran tetap backend.
        _ when !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) =>
          l10n.teknisiEditEmailSalah,
        _ => null,
      };
      _errorEmployeeId = employeeId.isEmpty
          ? l10n.teknisiEditEmployeeIdKosong
          : null;
    });

    return _errorNama == null &&
        _errorEmail == null &&
        _errorEmployeeId == null;
  }

  void _simpan() {
    if (!_valid()) return;

    Navigator.of(context).pop(
      _DataAkun(
        nama: _nama.text.trim(),
        email: _email.text.trim(),
        employeeId: _employeeId.text.trim(),
        department: _department.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.teknisiEditJudul(widget.akun.nama)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nama,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.teknisiEditNama,
                errorText: _errorNama,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.teknisiEditEmail,
                errorText: _errorEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _employeeId,
              decoration: InputDecoration(
                labelText: l10n.teknisiEditEmployeeId,
                errorText: _errorEmployeeId,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _department,
              decoration: InputDecoration(
                labelText: l10n.teknisiEditDepartment,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: InputDecoration(
                labelText: l10n.teknisiEditRole,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final r in UserRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.teknisiPilihRoleBatal),
        ),
        TextButton(onPressed: _simpan, child: Text(l10n.teknisiEditSimpan)),
      ],
    );
  }
}

/// Dialog isi password baru buat akun orang lain.
///
/// Divalidasi di sini juga (bukan cuma ngandelin `422` backend) supaya admin
/// nggak perlu nunggu jalan bolak-balik ke server cuma buat tahu passwordnya
/// kependekan.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.nama});

  final String nama;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  /// Samain sama aturan backend (`min:8`). Kalau salah satu digeser, yang lain
  /// ikut — kalau nggak, admin ketolak server padahal layarnya bilang oke.
  static const _panjangMinimal = 8;

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simpan() {
    final l10n = AppLocalizations.of(context);
    final password = _controller.text;

    if (password.length < _panjangMinimal) {
      setState(() => _error = l10n.teknisiResetPasswordTerlaluPendek);
      return;
    }

    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.teknisiResetPasswordJudul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.teknisiResetPasswordIsi(widget.nama)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.teknisiResetPasswordLabel,
            controller: _controller,
            isPassword: true,
            errorText: _error,
            helperText: l10n.teknisiResetPasswordHelper,
            onSubmitted: (_) => _simpan(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.teknisiPilihRoleBatal),
        ),
        TextButton(
          onPressed: _simpan,
          child: Text(l10n.teknisiResetPassword),
        ),
      ],
    );
  }
}

/// Avatar bulat di kartu akun.
///
/// ## Kenapa cuma foto SENDIRI yang tampil
///
/// Foto profil di app ini disimpan **lokal per perangkat** dan nggak pernah
/// diunggah ke server — lihat catatan panjang di `providers/avatar_provider.dart`.
/// Artinya di HP admin, satu-satunya foto yang ada ya foto admin itu sendiri;
/// foto teknisi lain nggak pernah nyampe ke sini.
///
/// Jadi yang lain dapat inisial berwarna, dan warnanya diturunkan dari id akun
/// biar tiap orang punya warna tetap yang sama tiap kali layarnya dibuka —
/// pengenal yang lumayan, bukan sekadar abu seragam.
///
/// Begitu backend punya kolom foto, yang perlu diubah cuma sumber gambarnya di
/// sini.
class _AvatarAkun extends ConsumerWidget {
  const _AvatarAkun({required this.akun});

  final User akun;

  static const _palet = [
    Color(0xFF3B5BDB),
    Color(0xFF0B7285),
    Color(0xFF9C36B5),
    Color(0xFFC2255C),
    Color(0xFF2B8A3E),
    Color(0xFFE8590C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sendiri = ref.watch(authProvider).value?.id == akun.id;
    final path = sendiri ? ref.watch(avatarPathProvider) : null;

    // `existsSync` dipanggil cuma buat SATU kartu (punya sendiri), bukan tiap
    // baris daftar. Tanpa penjagaan ini, path yang fotonya udah dihapus dari
    // galeri bikin petak merah di tengah kartu.
    final berkas = (path != null && path.isNotEmpty && File(path).existsSync())
        ? File(path)
        : null;

    final warna = _palet[akun.id.abs() % _palet.length];

    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: warna,
        // Cincin sewarna kartu: ini yang misahin avatar dari panorama di
        // belakangnya tanpa perlu bayangan.
        border: Border.all(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          width: 3,
        ),
        image: berkas == null
            ? null
            : DecorationImage(image: FileImage(berkas), fit: BoxFit.cover),
      ),
      child: berkas != null
          ? null
          : Text(
              inisialNama(akun.nama),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// Dua kolom kartu di layar lebar.
///
/// ## Kenapa bukan GridView
///
/// `GridView` nuntut tinggi sel yang seragam, dan kartu di sini **nggak**
/// seragam: akun pending punya empat tombol, akun nonaktif cuma satu. Dipatok
/// ke yang paling tinggi, kartu pendek nyisain lubang; dipatok ke yang paling
/// pendek, kartu panjang kepotong — dan itu persis yang kejadian waktu
/// tingginya ditulis 330 (kepotong 14px).
///
/// Jadi kolomnya dirakit tangan: kartu ganjil-genap dibagi ke dua Column, dan
/// masing-masing kartu tetap setinggi isinya sendiri.
///
/// Konsekuensinya kartunya dibangun semua sekaligus, nggak malas kayak
/// `ListView.builder`. Itu ditanggung sadar: daftar ini isinya akun satu lab —
/// puluhan, bukan ribuan — dan semuanya toh sudah ada di memori dari satu
/// `GET /users`. Kalau suatu saat daftarnya jadi ratusan, ini yang pertama
/// harus dibalik lagi jadi malas.
class _DuaKolom extends StatelessWidget {
  const _DuaKolom({required this.akun});

  final List<User> akun;

  @override
  Widget build(BuildContext context) {
    final kiri = <Widget>[];
    final kanan = <Widget>[];

    for (var i = 0; i < akun.length; i++) {
      final kartu = Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KartuAkun(akun: akun[i]),
      );
      (i.isEven ? kiri : kanan).add(kartu);
    }

    return SingleChildScrollView(
      // Tetap bisa ditarik walau isinya belum penuh selayar — kalau nggak,
      // tarik-buat-segarkan mati di daftar yang cuma berisi dua akun.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: kiri)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(children: kanan)),
        ],
      ),
    );
  }
}
