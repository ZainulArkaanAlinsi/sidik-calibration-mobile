import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/organization.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

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
  late final _standarAkreditasi = TextEditingController(
    text: widget.data.standarAkreditasi,
  );

  late DateTime? _akreditasiMulai = widget.data.akreditasiMulai;
  late DateTime? _akreditasiBerakhir = widget.data.akreditasiBerakhir;

  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _telepon.dispose();
    _email.dispose();
    _noAkreditasi.dispose();
    _standarAkreditasi.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool mulai}) async {
    final awal = (mulai ? _akreditasiMulai : _akreditasiBerakhir) ?? DateTime.now();
    final dipilih = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dipilih == null) return;
    setState(() {
      if (mulai) {
        _akreditasiMulai = dipilih;
      } else {
        _akreditasiBerakhir = dipilih;
      }
    });
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
              standarAkreditasi: _standarAkreditasi.text.trim(),
              akreditasiMulai: _akreditasiMulai,
              akreditasiBerakhir: _akreditasiBerakhir,
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
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    String fmt(DateTime? d) => d == null
        ? l10n.orgPilihTanggal
        : DateFormat('d MMM yyyy', locale).format(d);

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
        const SizedBox(height: AppSpacing.lg),

        Row(
          children: [
            Expanded(
              child: Text(
                l10n.orgAkreditasi.toUpperCase(),
                style: theme.textTheme.labelLarge,
              ),
            ),
            StatusBadge(
              label: widget.data.akreditasiMasihBerlaku
                  ? l10n.orgAkreditasiBerlaku
                  : l10n.orgAkreditasiKadaluarsa,
              tone: widget.data.akreditasiMasihBerlaku
                  ? BadgeTone.success
                  : BadgeTone.danger,
              icon: widget.data.akreditasiMasihBerlaku
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(label: l10n.orgNoAkreditasi, controller: _noAkreditasi),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.orgStandarAkreditasi,
          controller: _standarAkreditasi,
          hint: l10n.orgStandarAkreditasiHint,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pilihTanggal(mulai: true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.orgAkreditasiMulai.toUpperCase(),
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                  ),
                  child: Text(fmt(_akreditasiMulai)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: InkWell(
                onTap: () => _pilihTanggal(mulai: false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.orgAkreditasiBerakhir.toUpperCase(),
                    prefixIcon: const Icon(Icons.event_busy_outlined, size: 20),
                  ),
                  child: Text(fmt(_akreditasiBerakhir)),
                ),
              ),
            ),
          ],
        ),
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
