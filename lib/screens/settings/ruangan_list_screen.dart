import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ruangan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ruangan_provider.dart';
import '../../widgets/skeleton.dart';

/// Master Ruangan lab.
///
/// Kenapa perlu: `rooms` kosong 0 baris sejak awal dan nggak ada layarnya sama
/// sekali, jadi sesi lab jalan pakai `lokasi=lab` tanpa `room_id`. Selama itu,
/// pertanyaan "sesi ini dikerjain di ruangan mana, dan kondisinya masuk syarat
/// nggak" nggak punya jawaban.
class RuanganListScreen extends ConsumerWidget {
  const RuanganListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daftar = ref.watch(daftarRuanganProvider);
    final admin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruanganTitle)),
      // Tombol tambah cuma buat admin — backend nolak yang lain dengan 403,
      // jadi nawarin tombolnya cuma bikin orang nabrak dinding.
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _formRuangan(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.ruanganTambah),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(daftarRuanganProvider.notifier).muatUlang(),
        child: daftar.when(
          loading: () => const _Memuat(),
          error: (e, _) => _Gagal(
            pesan: '$e'.replaceFirst('Exception: ', ''),
            onCobaLagi: () =>
                ref.read(daftarRuanganProvider.notifier).muatUlang(),
          ),
          data: (list) => list.isEmpty
              ? _Kosong(pesan: l10n.ruanganKosong)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    80,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _KartuRuangan(
                    ruangan: list[i],
                    bisaUbah: admin,
                    onUbah: () => _formRuangan(context, ref, list[i]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _formRuangan(
    BuildContext context,
    WidgetRef ref,
    Ruangan? awal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showModalBottomSheet<Ruangan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormRuangan(awal: awal),
    );

    if (hasil == null) return;

    try {
      await ref.read(daftarRuanganProvider.notifier).simpan(hasil);
    } catch (e) {
      // Pesan backend apa adanya: dia yang tau "kode udah dipakai" atau
      // "suhu minimum lebih besar dari maksimum".
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _KartuRuangan extends StatelessWidget {
  const _KartuRuangan({
    required this.ruangan,
    required this.bisaUbah,
    required this.onUbah,
  });

  final Ruangan ruangan;
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
            Expanded(child: Text(ruangan.nama, style: theme.textTheme.titleSmall)),
            if (!ruangan.aktif)
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
            Text(
              [
                ruangan.kode,
                if (ruangan.lokasi != null && ruangan.lokasi!.isNotEmpty)
                  ruangan.lokasi!,
              ].join(' · '),
            ),
            // Rentang syarat ditulis kalau lengkap. Rentang setengah
            // ("20 – ") lebih membingungkan daripada nggak ada.
            if (ruangan.rentangSuhu != null || ruangan.rentangKelembaban != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  ?ruangan.rentangSuhu,
                  ?ruangan.rentangKelembaban,
                ].join('  ·  '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        isThreeLine: true,
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

class _FormRuangan extends StatefulWidget {
  const _FormRuangan({this.awal});

  final Ruangan? awal;

  @override
  State<_FormRuangan> createState() => _FormRuanganState();
}

class _FormRuanganState extends State<_FormRuangan> {
  late final _kode = TextEditingController(text: widget.awal?.kode ?? '');
  late final _nama = TextEditingController(text: widget.awal?.nama ?? '');
  late final _lokasi = TextEditingController(text: widget.awal?.lokasi ?? '');
  late final _suhuMin = TextEditingController(text: _teks(widget.awal?.suhuMin));
  late final _suhuMaks = TextEditingController(text: _teks(widget.awal?.suhuMaks));
  late final _rhMin = TextEditingController(text: _teks(widget.awal?.kelembabanMin));
  late final _rhMaks = TextEditingController(text: _teks(widget.awal?.kelembabanMaks));

  late bool _aktif = widget.awal?.aktif ?? true;
  String? _galat;

  static String _teks(double? v) => v == null ? '' : '$v';

  @override
  void dispose() {
    for (final c in [_kode, _nama, _lokasi, _suhuMin, _suhuMaks, _rhMin, _rhMaks]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _angka(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _kirim() {
    final kode = _kode.text.trim();
    final nama = _nama.text.trim();

    if (kode.isEmpty || nama.isEmpty) {
      setState(() => _galat = AppLocalizations.of(context).ruanganWajib);
      return;
    }

    // Dicek di sini juga, bukan cuma di server: batas kebalik itu salah ketik
    // yang gampang kejadian, dan nunggu server buat ngasih tau bikin admin
    // ngirim dulu baru ketauan.
    final sMin = _angka(_suhuMin);
    final sMaks = _angka(_suhuMaks);
    final rMin = _angka(_rhMin);
    final rMaks = _angka(_rhMaks);

    if ((sMin != null && sMaks != null && sMin > sMaks) ||
        (rMin != null && rMaks != null && rMin > rMaks)) {
      setState(() => _galat = AppLocalizations.of(context).ruanganRentangKebalik);
      return;
    }

    Navigator.of(context).pop(
      Ruangan(
        id: widget.awal?.id ?? 0,
        kode: kode,
        nama: nama,
        lokasi: _lokasi.text.trim().isEmpty ? null : _lokasi.text.trim(),
        suhuMin: sMin,
        suhuMaks: sMaks,
        kelembabanMin: rMin,
        kelembabanMaks: rMaks,
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
              widget.awal == null ? l10n.ruanganTambah : l10n.ruanganUbah,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _kode,
              decoration: InputDecoration(
                labelText: l10n.ruanganKode,
                hintText: 'LAB-01',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nama,
              decoration: InputDecoration(
                labelText: l10n.ruanganNama,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _lokasi,
              decoration: InputDecoration(
                labelText: l10n.ruanganLokasi,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            Text(l10n.ruanganSyarat, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: _angkaField(_suhuMin, l10n.ruanganSuhuMin)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _angkaField(_suhuMaks, l10n.ruanganSuhuMaks)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _angkaField(_rhMin, l10n.ruanganRhMin)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _angkaField(_rhMaks, l10n.ruanganRhMaks)),
              ],
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
              title: Text(l10n.ruanganAktif),
              subtitle: Text(l10n.ruanganAktifKet),
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

  Widget _angkaField(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}

class _Memuat extends StatelessWidget {
  const _Memuat();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: List.generate(
      3,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: SkeletonBox(height: 88),
      ),
    ),
  );
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.xl),
    children: [
      const Icon(Icons.meeting_room_outlined, size: 48),
      const SizedBox(height: AppSpacing.md),
      Text(pesan, textAlign: TextAlign.center),
    ],
  );
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Icon(Icons.error_outline, size: 48),
        const SizedBox(height: AppSpacing.md),
        Text(pesan, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: FilledButton(
            onPressed: onCobaLagi,
            child: Text(l10n.rumusCobaLagi),
          ),
        ),
      ],
    );
  }
}
