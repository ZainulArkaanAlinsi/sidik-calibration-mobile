import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audit_log.dart';
import '../../models/izin.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/izin_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik_loader.dart';
import '../../widgets/status_badge.dart';

/// Riwayat perubahan data lab (`GET /api/audit-logs`) — admin & super admin,
/// **baca saja**.
///
/// Tidak ada tombol ubah/hapus/ekspor dan tidak akan ada: baris riwayat
/// tulis-sekali di server, dan riwayat yang bisa disunting dari HP berhenti
/// jadi bukti. Ekspor CSV untuk asesor belum ada jalur simpan berkasnya di app.
///
/// Izinnya nebeng `pengguna.kelola`: `MatriksIzin::PETA` server belum punya
/// entri `audit.*`, padahal `/audit-logs` ada di grup `role:admin` yang sama
/// dengan `/users` (super admin lolos lewat aturan baca GET). Begitu server
/// menambah izin sendiri, ganti satu nama di bawah ini.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehkah(
      NamaIzin.penggunaKelola,
      cadangan: ref.watch(authProvider).value?.role.hakAdmin ?? false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditJudul),
        actions: [if (boleh) const _TombolFilter()],
      ),
      body: boleh
          ? const ReadableWidth(child: _Isi())
          : _Pesan(ikon: Icons.lock_outline, teks: l10n.auditHanyaAdmin),
    );
  }
}

/// Aksi yang dikenal server diterjemahkan; aksi lain (`dibaca`,
/// `akses_lintas_lab`, …) ditampilkan apa adanya, bukan disembunyikan.
String _labelAksi(AppLocalizations l10n, String aksi) => switch (aksi) {
  'dibikin' => l10n.auditAksiDibikin,
  'diubah' => l10n.auditAksiDiubah,
  'dihapus' => l10n.auditAksiDihapus,
  'dipulihkan' => l10n.auditAksiDipulihkan,
  _ => aksi,
};

BadgeTone _nadaAksi(String aksi) => switch (aksi) {
  'dibikin' => BadgeTone.success,
  'diubah' => BadgeTone.info,
  'dihapus' => BadgeTone.danger,
  'dipulihkan' => BadgeTone.warning,
  _ => BadgeTone.neutral,
};

String _waktu(BuildContext context, DateTime? waktu) {
  if (waktu == null) return '-';
  final locale = Localizations.localeOf(context).languageCode;
  return DateFormat('d MMM yyyy HH:mm', locale).format(waktu);
}

String _entitas(AppLocalizations l10n, AuditLogItem item) =>
    l10n.auditEntitas(item.entitasTipe, item.entitasId?.toString() ?? '-');

String _pelaku(AppLocalizations l10n, AuditLogItem item) =>
    item.olehSistem || item.pelakuNama == null
    ? l10n.auditOlehSistem
    : l10n.auditOleh(item.pelakuNama!);

class _TombolFilter extends ConsumerWidget {
  const _TombolFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Di-watch supaya lencana jumlah filter ikut berubah.
    ref.watch(auditLogProvider);
    final controller = ref.read(auditLogProvider.notifier);
    final aktif = controller.filter.jumlahAktif;

    return IconButton(
      tooltip: l10n.auditFilter,
      onPressed: () async {
        final hasil = await showDialog<FilterAuditLog>(
          context: context,
          builder: (_) => _FilterDialog(awal: controller.filter),
        );
        if (hasil != null) await controller.terapkanFilter(hasil);
      },
      icon: Badge(
        isLabelVisible: aktif > 0,
        label: Text('$aktif'),
        child: const Icon(Icons.filter_list),
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(auditLogProvider);
    final controller = ref.read(auditLogProvider.notifier);

    return switch (async) {
      AsyncData(:final value) when value.isEmpty => _Pesan(
        ikon: Icons.history_toggle_off,
        teks: l10n.auditKosong,
        aksi: controller.filter.kosong
            ? null
            : AppButton(
                label: l10n.auditReset,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    controller.terapkanFilter(const FilterAuditLog()),
              ),
      ),
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: controller.muatUlang,
        child: _Daftar(
          items: value,
          bisaMuatLagi: controller.bisaMuatLagi,
          onMuatLagi: controller.muatLebihBanyak,
        ),
      ),
      AsyncError(:final error) => _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.auditGagalMuat,
        aksi: AppButton(
          label: l10n.auditCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: controller.muatUlang,
        ),
      ),
      _ => const Center(child: SidikLoader(size: 88)),
    };
  }
}

class _Daftar extends StatelessWidget {
  const _Daftar({
    required this.items,
    required this.bisaMuatLagi,
    required this.onMuatLagi,
  });

  final List<AuditLogItem> items;
  final bool bisaMuatLagi;
  final Future<void> Function() onMuatLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // [catatan] + baris + [tombol muat lagi]
    final jumlah = 1 + items.length + (bisaMuatLagi ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: jumlah,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Text(
            l10n.auditBacaSaja,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        if (i <= items.length) return _BarisAudit(item: items[i - 1]);

        return _TombolMuatLagi(onMuatLagi: onMuatLagi);
      },
    );
  }
}

class _TombolMuatLagi extends StatefulWidget {
  const _TombolMuatLagi({required this.onMuatLagi});

  final Future<void> Function() onMuatLagi;

  @override
  State<_TombolMuatLagi> createState() => _TombolMuatLagiState();
}

class _TombolMuatLagiState extends State<_TombolMuatLagi> {
  bool _memuat = false;
  bool _gagal = false;

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _gagal = false;
    });
    try {
      await widget.onMuatLagi();
    } catch (_) {
      // Daftar yang sudah kelihatan tidak dirusak; cukup kasih tahu
      // halaman berikutnya gagal.
      if (mounted) setState(() => _gagal = true);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_gagal)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.auditMuatGagal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        AppButton(
          label: l10n.auditMuatLagi,
          variant: AppButtonVariant.secondary,
          isLoading: _memuat,
          onPressed: _memuat ? null : _muat,
        ),
      ],
    );
  }
}

class _BarisAudit extends StatelessWidget {
  const _BarisAudit({required this.item});

  final AuditLogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _DetailDialog(item: item),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _entitas(l10n, item),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_pelaku(l10n, item)} · ${_waktu(context, item.dicatatPada)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: _labelAksi(l10n, item.aksi),
                tone: _nadaAksi(item.aksi),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rincian satu baris: kolom apa berubah, dari apa ke apa.
class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.item});

  final AuditLogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String nilai(PerubahanKolom p, Object? mentah) {
      // Kolom rahasia tidak pernah ditampilkan nilainya, kosong atau tidak.
      if (p.rahasia) return l10n.auditNilaiDisembunyikan;
      return PerubahanKolom.teks(mentah) ?? l10n.auditNilaiKosong;
    }

    return AlertDialog(
      title: Text(_entitas(l10n, item)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  StatusBadge(
                    label: _labelAksi(l10n, item.aksi),
                    tone: _nadaAksi(item.aksi),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_pelaku(l10n, item)} · ${_waktu(context, item.dicatatPada)}',
                style: theme.textTheme.bodySmall,
              ),
              if (item.catatan case final catatan? when catatan.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${l10n.auditCatatan}: $catatan',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const Divider(height: AppSpacing.lg),
              if (item.perubahan.isEmpty)
                Text(l10n.auditTanpaRincian, style: theme.textTheme.bodySmall)
              else
                for (final p in item.perubahan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.kolom, style: theme.textTheme.titleSmall),
                        Text('${l10n.auditSebelum}: ${nilai(p, p.lama)}'),
                        Text('${l10n.auditSesudah}: ${nilai(p, p.baru)}'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.auditTutup),
        ),
      ],
    );
  }
}

/// Dialog penyaring. Mengembalikan [FilterAuditLog] baru (kosong = reset),
/// atau `null` kalau dibatalkan.
class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.awal});

  final FilterAuditLog awal;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late final _tipe = TextEditingController(text: widget.awal.entityType ?? '');
  late final _id = TextEditingController(
    text: widget.awal.entityId?.toString() ?? '',
  );
  late String? _aksi = widget.awal.aksi;
  late DateTime? _dari = widget.awal.dari;
  late DateTime? _sampai = widget.awal.sampai;

  @override
  void dispose() {
    _tipe.dispose();
    _id.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool dari}) async {
    final awal = (dari ? _dari : _sampai) ?? DateTime.now();
    final dipilih = await showDatePicker(
      context: context,
      initialDate: awal,
      // "Sampai" tidak boleh sebelum "dari": server menolaknya 422.
      firstDate: dari ? DateTime(2020) : (_dari ?? DateTime(2020)),
      lastDate: DateTime(2100),
    );
    if (dipilih == null) return;
    setState(() {
      if (dari) {
        _dari = dipilih;
        if (_sampai != null && _sampai!.isBefore(dipilih)) _sampai = null;
      } else {
        _sampai = dipilih;
      }
    });
  }

  FilterAuditLog _hasil() {
    final tipe = _tipe.text.trim();
    return FilterAuditLog(
      aksi: _aksi,
      entityType: tipe.isEmpty ? null : tipe,
      entityId: int.tryParse(_id.text.trim()),
      dari: _dari,
      sampai: _sampai,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    String tgl(DateTime? d) => d == null
        ? l10n.auditPilihTanggal
        : DateFormat('d MMM yyyy', locale).format(d);

    return AlertDialog(
      title: Text(l10n.auditFilterJudul),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.auditFilterAksi,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(l10n.auditSemua),
                    selected: _aksi == null,
                    onSelected: (_) => setState(() => _aksi = null),
                  ),
                  for (final a in FilterAuditLog.aksiTersaring)
                    ChoiceChip(
                      label: Text(_labelAksi(l10n, a)),
                      selected: _aksi == a,
                      onSelected: (_) => setState(() => _aksi = a),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _tipe,
                decoration: InputDecoration(
                  labelText: l10n.auditFilterTipe,
                  hintText: l10n.auditFilterTipeHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _id,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.auditFilterId,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _pilihTanggal(dari: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('${l10n.auditFilterDari}: ${tgl(_dari)}'),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => _pilihTanggal(dari: false),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('${l10n.auditFilterSampai}: ${tgl(_sampai)}'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const FilterAuditLog()),
          child: Text(l10n.auditReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_hasil()),
          child: Text(l10n.auditTerapkan),
        ),
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
