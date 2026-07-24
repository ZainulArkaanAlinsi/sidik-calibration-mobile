import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/status_badge.dart';

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
    final admin = ref.watch(authProvider).value?.role.isAdmin ?? false;

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
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _KartuAkun(akun: value[i]),
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
      _ => const Center(child: CircularProgressIndicator()),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(akun.nama, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        akun.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (akun.status == UserStatus.pending)
                  AppButton(
                    label: l10n.teknisiSetujui,
                    icon: Icons.check,
                    onPressed: () => _setujui(context, ref),
                  ),
                if (akun.status != UserStatus.nonaktif)
                  AppButton(
                    label: l10n.teknisiTolak,
                    icon: Icons.block_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _tolak(context, ref),
                  ),
                if (akun.status == UserStatus.aktif)
                  AppButton(
                    label: l10n.teknisiResetPassword,
                    icon: Icons.lock_reset,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _resetPassword(context, ref),
                  ),
              ],
            ),
          ],
        ),
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
