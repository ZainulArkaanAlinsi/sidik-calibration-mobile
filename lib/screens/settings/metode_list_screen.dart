import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ruangan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ruangan_provider.dart';
import '../../widgets/skeleton.dart';

/// Master Metode Kalibrasi (Instruksi Kerja / IK).
///
/// Kodenya kecetak di sertifikat (`SIDIK-IK-CAL-0506`), dan yang harus tercetak
/// itu **revisi yang berlaku waktu kalibrasinya dikerjakan** — bukan yang
/// terbaru. Makanya `kode` dan `revisi` dipisah, persis kayak dokumen mutunya.
class MetodeListScreen extends ConsumerWidget {
  const MetodeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daftar = ref.watch(daftarMetodeProvider);
    final admin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.metodeTitle)),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.metodeTambah),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(daftarMetodeProvider.notifier).muatUlang(),
        child: daftar.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: SkeletonBox(height: 80),
              ),
            ),
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$e'.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.metodeKosong, textAlign: TextAlign.center),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    80,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _Kartu(
                    metode: list[i],
                    bisaUbah: admin,
                    onUbah: () => _form(context, ref, list[i]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref,
    MetodeKalibrasi? awal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showModalBottomSheet<MetodeKalibrasi>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Form(awal: awal),
    );

    if (hasil == null) return;

    try {
      await ref.read(daftarMetodeProvider.notifier).simpan(hasil);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.metode,
    required this.bisaUbah,
    required this.onUbah,
  });

  final MetodeKalibrasi metode;
  final bool bisaUbah;
  final VoidCallback onUbah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(metode.nama, style: theme.textTheme.titleSmall)),
            if (!metode.aktif)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(l10n.ruanganNonaktif),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Kode + revisi ditulis nyatu persis kayak di sertifikat, biar
            // gampang dicocokin sama lembar yang dipegang.
            Text(metode.kodeLengkap, style: theme.textTheme.bodyMedium),
            if (metode.berlakuMulai != null) ...[
              const SizedBox(height: 2),
              Text(
                l10n.metodeBerlakuMulai(
                  DateFormat('d MMM yyyy').format(metode.berlakuMulai!),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: bisaUbah
            ? IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onUbah,
              )
            : null,
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({this.awal});

  final MetodeKalibrasi? awal;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _kode = TextEditingController(text: widget.awal?.kode ?? '');
  late final _nama = TextEditingController(text: widget.awal?.nama ?? '');
  late final _revisi = TextEditingController(text: widget.awal?.revisi ?? '');

  late DateTime? _berlaku = widget.awal?.berlakuMulai;
  late bool _aktif = widget.awal?.aktif ?? true;
  String? _galat;

  @override
  void dispose() {
    for (final c in [_kode, _nama, _revisi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _kirim() {
    final kode = _kode.text.trim();
    final nama = _nama.text.trim();

    if (kode.isEmpty || nama.isEmpty) {
      setState(() => _galat = AppLocalizations.of(context).ruanganWajib);
      return;
    }

    Navigator.of(context).pop(
      MetodeKalibrasi(
        id: widget.awal?.id ?? 0,
        kode: kode,
        nama: nama,
        revisi: _revisi.text.trim().isEmpty ? null : _revisi.text.trim(),
        berlakuMulai: _berlaku,
        aktif: _aktif,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.awal == null ? l10n.metodeTambah : l10n.metodeUbah,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _kode,
              decoration: InputDecoration(
                labelText: l10n.metodeKode,
                hintText: 'SIDIK-IK-CAL-0506',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _revisi,
              decoration: InputDecoration(
                labelText: l10n.metodeRevisi,
                hintText: '4',
                helperText: l10n.metodeRevisiKet,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                labelText: l10n.metodeNama,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.metodeBerlaku),
              subtitle: Text(
                _berlaku == null
                    ? l10n.metodeBerlakuKosong
                    : DateFormat('d MMMM yyyy').format(_berlaku!),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _berlaku ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _berlaku = p);
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
              title: Text(l10n.ruanganAktif),
              subtitle: Text(l10n.metodeAktifKet),
            ),

            if (_galat != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_galat!, style: TextStyle(color: theme.colorScheme.error)),
            ],

            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.ruanganBatal),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _kirim,
                    child: Text(l10n.ruanganSimpan),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
