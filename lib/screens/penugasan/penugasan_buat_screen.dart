import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/penugasan.dart';
import '../../models/user.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/pengendalian_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Tugaskan teknisi — personal atau grup, dengan baris "+" jenis alat &
/// jumlahnya (artboard `SA_Penugasan_Buat`).
///
/// Urutan teknisi yang dipilih BERMAKNA: yang pertama jadi ketua. Grup tanpa
/// ketua jadi pekerjaan yang semua orang anggap sedang dikerjakan orang lain.
class PenugasanBuatScreen extends ConsumerStatefulWidget {
  const PenugasanBuatScreen({super.key});

  @override
  ConsumerState<PenugasanBuatScreen> createState() =>
      _PenugasanBuatScreenState();
}

class _BarisIsian {
  final jenis = TextEditingController();
  final jumlah = TextEditingController(text: '1');

  void dispose() {
    jenis.dispose();
    jumlah.dispose();
  }
}

class _PenugasanBuatScreenState extends ConsumerState<PenugasanBuatScreen> {
  final _judul = TextEditingController();
  final _catatan = TextEditingController();
  final List<_BarisIsian> _baris = [_BarisIsian()];
  final List<int> _teknisi = [];
  DateTime? _target;
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _judul.dispose();
    _catatan.dispose();
    for (final b in _baris) {
      b.dispose();
    }
    super.dispose();
  }

  List<BarisPenugasan> get _barisValid => [
    for (final b in _baris)
      if (b.jenis.text.trim().isNotEmpty &&
          (int.tryParse(b.jumlah.text) ?? 0) > 0)
        BarisPenugasan(
          jenisAlat: b.jenis.text.trim(),
          jumlah: int.parse(b.jumlah.text),
        ),
  ];

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    if (_judul.text.trim().isEmpty) {
      setState(() => _galat = l10n.penugasanGalatJudul);
      return;
    }
    if (_teknisi.isEmpty) {
      setState(() => _galat = l10n.penugasanGalatTeknisi);
      return;
    }
    if (_barisValid.isEmpty) {
      setState(() => _galat = l10n.penugasanGalatBaris);
      return;
    }

    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(daftarPenugasanProvider.notifier)
          .buat(
            judul: _judul.text.trim(),
            teknisi: List.of(_teknisi),
            baris: _barisValid,
            tanggalTarget: _target,
            catatan: _catatan.text,
          );
      navigator.pop();
    } catch (e) {
      setState(() => _galat = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pengguna = ref.watch(userListProvider).value ?? const <User>[];
    final teknisi = pengguna
        .where(
          (u) => u.role == UserRole.teknisi && u.status == UserStatus.aktif,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.penugasanTugaskan)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextField(
              controller: _judul,
              decoration: InputDecoration(
                labelText: l10n.penugasanJudulIsian,
                hintText: l10n.penugasanJudulContoh,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _target == null
                    ? l10n.penugasanPilihTarget
                    : l10n.penugasanTarget(tanggalPendek(context, _target)),
              ),
              onPressed: () async {
                final hariIni = DateUtils.dateOnly(DateTime.now());
                final pilih = await showDatePicker(
                  context: context,
                  firstDate: hariIni,
                  lastDate: hariIni.add(const Duration(days: 365)),
                  initialDate: _target ?? hariIni.add(const Duration(days: 3)),
                );
                if (pilih != null) setState(() => _target = pilih);
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(l10n.penugasanPilihTeknisi, style: theme.textTheme.titleSmall),
            Text(l10n.penugasanKetuaPertama, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (teknisi.isEmpty)
              Text(
                l10n.penugasanTeknisiKosong,
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in teknisi)
                    FilterChip(
                      label: Text(
                        _teknisi.isNotEmpty && _teknisi.first == t.id
                            ? '${t.kodeTeknisi ?? t.nama} · ${l10n.penugasanKetua}'
                            : t.kodeTeknisi ?? t.nama,
                      ),
                      tooltip: t.nama,
                      selected: _teknisi.contains(t.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _teknisi.add(t.id);
                        } else {
                          _teknisi.remove(t.id);
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),

            Text(l10n.penugasanRincian, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _baris.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _baris[i].jenis,
                        decoration: InputDecoration(
                          labelText: l10n.penugasanJenisAlat,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _baris[i].jumlah,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.penugasanJumlah,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.penugasanHapusBaris,
                      icon: const Icon(Icons.close),
                      onPressed: _baris.length == 1
                          ? null
                          : () => setState(() => _baris.removeAt(i).dispose()),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.penugasanTambahBaris),
                onPressed: () => setState(() => _baris.add(_BarisIsian())),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _catatan,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.penugasanCatatan),
            ),
            if (_galat != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_galat!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Satu-satunya aksi utama layar ini — ragam `utama` dipakai sekali.
            SidikTombol(
              label: l10n.penugasanKirim,
              ikon: Icons.send_outlined,
              ragam: RagamTombol.utama,
              penuh: true,
              sibuk: _sibuk,
              onPressed: _simpan,
            ),
          ],
        ),
      ),
    );
  }
}
