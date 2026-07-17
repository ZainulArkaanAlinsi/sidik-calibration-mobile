import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/organization.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/skeleton.dart';

/// Data PT yang dicetak di kop sertifikat — satu baris doang, jadi cukup
/// satu form (bukan list+detail kayak Pelanggan).
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider);
    final l10n = AppLocalizations.of(context);

    final data = org.value;

    final Widget isi;
    if (data != null) {
      isi = _Form(data: data);
    } else if (org.hasError) {
      isi = _Gagal(
        pesan: org.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.orgLoadFailed,
        onCobaLagi: () => ref.read(organizationProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(appBar: AppBar(title: Text(l10n.orgTitle)), body: isi);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.data});

  final Organization data;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _nama = TextEditingController(text: widget.data.nama);
  late final _alamat = TextEditingController(text: widget.data.alamat);
  late final _telepon = TextEditingController(text: widget.data.telepon);
  late final _email = TextEditingController(text: widget.data.email);
  late final _noAkreditasi = TextEditingController(
    text: widget.data.noAkreditasi,
  );

  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _telepon.dispose();
    _email.dispose();
    _noAkreditasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _menyimpan = true);

    try {
      await ref
          .read(organizationProvider.notifier)
          .simpan(
            Organization(
              nama: _nama.text.trim(),
              alamat: _alamat.text.trim(),
              telepon: _telepon.text.trim(),
              email: _email.text.trim(),
              noAkreditasi: _noAkreditasi.text.trim(),
            ),
          );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.orgSaved)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orgSaveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppTextField(label: l10n.orgNama, controller: _nama),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.orgAlamat, controller: _alamat),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.orgTelepon,
          controller: _telepon,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.orgEmail,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.orgNoAkreditasi, controller: _noAkreditasi),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.orgSave,
          isLoading: _menyimpan,
          onPressed: _menyimpan ? null : _simpan,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).orgRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: List.generate(
        5,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: SkeletonBox(height: 52, width: double.infinity),
        ),
      ),
    );
  }
}
