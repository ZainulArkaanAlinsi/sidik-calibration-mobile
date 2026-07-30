import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/rumus.dart';
import '../../providers/rumus_provider.dart';
import '../../widgets/skeleton.dart';

/// Riwayat versi satu rumus + tempat nerbitin versi baru.
///
/// Susunannya garis waktu terbaru-dulu, bukan tabel: yang dicari orang di sini
/// "kapan aturannya berubah dan kenapa", dan itu pertanyaan berurutan waktu.
class RumusVersiScreen extends ConsumerWidget {
  const RumusVersiScreen({required this.rumus, super.key});

  final Rumus rumus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final versi = ref.watch(versiRumusProvider(rumus.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(rumus.nama),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(rumus.kode, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _terbitkan(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.rumusTerbitkanVersi),
      ),
      body: versi.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: SkeletonBox(height: 120),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('$e'.replaceFirst('Exception: ', '')),
          ),
        ),
        data: (daftar) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            80, // ruang buat FAB
          ),
          itemCount: daftar.length,
          itemBuilder: (_, i) => _KartuVersi(
            versi: daftar[i],
            formulaId: rumus.id,
          ),
        ),
      ),
    );
  }

  Future<void> _terbitkan(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final isi = await showModalBottomSheet<VersiRumusBaru>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormVersiBaru(
        // Parameter versi yang lagi berlaku dipakai sebagai titik awal —
        // versi baru biasanya ngubah SATU angka, bukan nulis semuanya dari
        // nol. Ngosongin formulir bikin admin ngetik ulang yang nggak berubah,
        // dan tiap ketikan ulang itu peluang salah ketik di angka yang masuk
        // sertifikat.
        awal: rumus.versiBerlaku?.parameter ?? const {},
      ),
    );

    if (isi == null) return;

    try {
      final baru = await ref
          .read(daftarRumusProvider.notifier)
          .terbitkan(rumus.id, isi);

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rumusVersiTerbit(baru.nomorVersi))),
      );
    } catch (e) {
      // Pesan penolakan backend ditampilin APA ADANYA: dia yang tau alasannya
      // ("rentangnya bentrok", "udah kepakai di hasil hitung"), dan admin
      // nggak bisa mbenerin apa pun dari pesan generik.
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _KartuVersi extends ConsumerWidget {
  const _KartuVersi({required this.versi, required this.formulaId});

  final VersiRumus versi;
  final int formulaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tgl = DateFormat('d MMM yyyy');

    final (warna, label) = switch (versi.status) {
      StatusVersiRumus.aktif => (theme.colorScheme.primary, l10n.rumusStatusAktif),
      StatusVersiRumus.draft => (theme.colorScheme.tertiary, l10n.rumusStatusDraft),
      StatusVersiRumus.arsip => (theme.colorScheme.outline, l10n.rumusStatusArsip),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.rumusVersiKe(versi.nomorVersi),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: warna.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: warna),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Rentang berlakunya: ini inti fitur versioning. "Sampai sekarang"
            // ditulis eksplisit — tanggal akhir kosong gampang kebaca sebagai
            // data yang belum keisi.
            Text(
              versi.berlakuSampai == null
                  ? l10n.rumusBerlakuSejak(tgl.format(versi.berlakuDari ?? DateTime.now()))
                  : l10n.rumusBerlakuRentang(
                      tgl.format(versi.berlakuDari ?? DateTime.now()),
                      tgl.format(versi.berlakuSampai!),
                    ),
              style: theme.textTheme.bodySmall,
            ),

            if (versi.parameter.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...versi.parameter.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          e.key,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text('${e.value}', style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (versi.catatan != null && versi.catatan!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(versi.catatan!, style: theme.textTheme.bodySmall),
            ],

            const SizedBox(height: AppSpacing.sm),
            Text(
              // Versi 1 lahir waktu organisasinya pertama nyimpen kalibrasi —
              // pembuat kosong di situ BUKAN data hilang, jadi disebut apa
              // adanya.
              versi.olehSistem
                  ? l10n.rumusDibuatSistem
                  : l10n.rumusDibuatOleh(versi.pembuat ?? '—'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // Draft belum masuk garis waktu, jadi dia satu-satunya yang boleh
            // diaktifin dari sini. Versi aktif/arsip nggak dikasih tombol
            // apa-apa: yang aktif diganti dengan NERBITIN versi baru, bukan
            // diedit — itu inti dari riwayat yang bisa dipertanggungjawabkan.
            if (versi.status == StatusVersiRumus.draft) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _aktifkan(context, ref),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.rumusAktifkan),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _aktifkan(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.rumusAktifkanJudul),
        content: Text(l10n.rumusAktifkanKet),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(l10n.rumusBatal),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l10n.rumusAktifkan),
          ),
        ],
      ),
    );

    if (ya != true) return;

    try {
      await ref
          .read(daftarRumusProvider.notifier)
          .ubahStatus(formulaId, versi.id, StatusVersiRumus.aktif);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

/// Form terbitkan versi baru.
class _FormVersiBaru extends StatefulWidget {
  const _FormVersiBaru({required this.awal});

  final Map<String, dynamic> awal;

  @override
  State<_FormVersiBaru> createState() => _FormVersiBaruState();
}

class _FormVersiBaruState extends State<_FormVersiBaru> {
  late final Map<String, TextEditingController> _param = {
    for (final e in widget.awal.entries)
      e.key: TextEditingController(text: '${e.value}'),
  };
  final _catatan = TextEditingController();

  DateTime _berlakuDari = DateTime.now();
  bool _langsungAktif = false;

  @override
  void dispose() {
    for (final c in _param.values) {
      c.dispose();
    }
    _catatan.dispose();
    super.dispose();
  }

  /// Angka dikembaliin sebagai num kalau kebaca angka, selain itu string apa
  /// adanya — backend nyimpen `parameter` sebagai JSON bebas, dan `"2"` beda
  /// dari `2` waktu nanti dibaca program.
  Object? _nilai(String teks) {
    final t = teks.trim();
    if (t.isEmpty) return null;

    return num.tryParse(t) ?? t;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tgl = DateFormat('d MMMM yyyy');

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
            Text(l10n.rumusTerbitkanVersi, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.rumusFormKet, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.rumusBerlakuDari),
              subtitle: Text(tgl.format(_berlakuDari)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _berlakuDari,
                  // Mundur diizinin: aturan bisa baru dicatat sesudah dipakai,
                  // dan maksa tanggalnya hari ini bikin riwayatnya bohong.
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _berlakuDari = p);
              },
            ),

            if (_param.isNotEmpty) ...[
              const Divider(),
              Text(l10n.rumusParameter, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ..._param.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(
                    controller: e.value,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: e.key,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],

            const Divider(),
            TextField(
              controller: _catatan,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.rumusCatatan,
                hintText: l10n.rumusCatatanHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _langsungAktif,
              onChanged: (v) => setState(() => _langsungAktif = v),
              title: Text(l10n.rumusLangsungAktif),
              // Default mati, dan alasannya disebut: draft belum masuk garis
              // waktu, jadi itu tempat paling aman buat nyoba dulu.
              subtitle: Text(l10n.rumusLangsungAktifKet),
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.rumusBatal),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      VersiRumusBaru(
                        berlakuDari: _berlakuDari,
                        parameter: {
                          for (final e in _param.entries)
                            if (_nilai(e.value.text) != null)
                              e.key: _nilai(e.value.text),
                        },
                        catatan: _catatan.text,
                        langsungAktif: _langsungAktif,
                      ),
                    ),
                    child: Text(l10n.rumusTerbitkan),
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
