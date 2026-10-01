import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/koreksi_pelanggan.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/koreksi_provider.dart';
import '../../widgets/foto_pelanggan.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../../widgets/skeleton.dart';
import '../certificate/sertifikat_screen.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;
import 'antrean_koreksi_screen.dart'
    show bolehMemutuskanKoreksi, statusKoreksi;

/// Satu koreksi dari pelanggan: siapa, apa yang diminta (lama → baru), bukti
/// foto, dan keputusannya.
///
/// Tombol Terima/Tolak hanya muncul kalau statusnya `menunggu` DAN perannya
/// admin. Super admin melihat satu kalimat yang bilang kenapa tidak ada tombol
/// — bukan layar yang diam-diam lebih pendek. Server tetap penjaganya (403).
class DetailKoreksiScreen extends ConsumerWidget {
  const DetailKoreksiScreen({super.key, required this.koreksiId});

  final int koreksiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(detailKoreksiProvider(koreksiId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.koreksiDetailJudul(koreksiId))),
      body: switch (async) {
        AsyncData(:final value) => ReadableWidth(child: _Isi(koreksi: value)),
        AsyncError(:final error) => _Gagal(
          teks: error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.koreksiGagalDetail,
          onCobaLagi: () => ref.invalidate(detailKoreksiProvider(koreksiId)),
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: SkeletonBox(height: 120),
        ),
      },
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.teks, required this.onCobaLagi});

  final String teks;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(teks, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SidikTombol(
            label: AppLocalizations.of(context).custRetry,
            ikon: Icons.refresh,
            onPressed: onCobaLagi,
          ),
        ),
      ],
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.koreksi});

  final Koreksi koreksi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final k = koreksi;
    final sertifikat = k.jenis == JenisKoreksi.sertifikat;
    final perluKeputusan = k.status.bisaDiputuskan;
    final boleh = bolehMemutuskanKoreksi(ref);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(detailKoreksiProvider(k.id));
              await ref.read(detailKoreksiProvider(k.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Kertas(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (sertifikat
                                      ? l10n.koreksiJenisSertifikat
                                      : l10n.koreksiJenisAlat)
                                  .toUpperCase(),
                              style: m.gayaEtsa(ukuran: 11),
                            ),
                          ),
                          SidikLencana(statusKoreksi(l10n, k.status)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        k.pelangganNama ?? '—',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (k.diajukanOleh != null || k.diajukanPada != null)
                        _Baris(
                          label: l10n.koreksiDiajukan,
                          isi: [
                            ?k.diajukanOleh,
                            if (k.diajukanPada != null)
                              tanggalPendek(context, k.diajukanPada!.toLocal()),
                          ].join(' · '),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        (sertifikat
                                ? l10n.koreksiTargetSertifikat
                                : l10n.koreksiTargetAlat)
                            .toUpperCase(),
                        style: m.gayaEtsa(ukuran: 11),
                      ),
                      if (sertifikat && k.sertifikatId != null)
                        _TautanSertifikat(
                          key: const ValueKey('tautan-koreksi-sertifikat'),
                          id: k.sertifikatId!,
                          nomor: k.sertifikatNomor ?? '—',
                        )
                      else if (sertifikat)
                        Text(
                          k.sertifikatNomor ?? '—',
                          style: SidikTheme.gayaAngka(ukuran: 14),
                        ),
                      if (k.alatNama != null)
                        Text(k.alatNama!, style: theme.textTheme.bodyMedium),
                      if (k.alatSerial != null && k.alatSerial!.isNotEmpty)
                        Text(
                          k.alatSerial!,
                          style: SidikTheme.gayaAngka(
                            ukuran: 13,
                            warna: m.tinta2,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.koreksiPerubahanJudul(k.perubahan.length),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Kertas(
                  key: const ValueKey('tabel-perubahan-koreksi'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      for (var i = 0; i < k.perubahan.length; i++) ...[
                        if (i > 0) const Divider(height: AppSpacing.lg),
                        _BarisPerubahan(perubahan: k.perubahan[i]),
                      ],
                    ],
                  ),
                ),
                if (k.catatan != null && k.catatan!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Kertas(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _Baris(
                      label: l10n.koreksiCatatanPelanggan,
                      isi: k.catatan!,
                      tanpaJarak: true,
                    ),
                  ),
                ],
                if (k.foto.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.koreksiFoto(k.foto.length),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DeretFotoPelanggan(foto: k.foto),
                ],
                if (!perluKeputusan) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Keputusan(koreksi: k),
                ],
              ],
            ),
          ),
        ),
        if (perluKeputusan)
          _Bilah(
            boleh: boleh,
            onTolak: () => _tolak(context, ref),
            onTerima: () => _terima(context, ref),
          ),
      ],
    );
  }

  Future<void> _terima(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasil = await showModalBottomSheet<Koreksi>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LembarTerimaKoreksi(koreksi: koreksi),
    );
    if (hasil == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasil.revisi == null
              ? l10n.koreksiDiterimaToast
              : l10n.koreksiDiterimaRevisiToast(hasil.revisi!.nomor),
        ),
      ),
    );
  }

  Future<void> _tolak(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DialogTolakKoreksi(koreksiId: koreksi.id),
    );
    if (ok == true) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.koreksiDitolakToast)));
    }
  }
}

class _Bilah extends StatelessWidget {
  const _Bilah({
    required this.boleh,
    required this.onTolak,
    required this.onTerima,
  });

  final bool boleh;
  final VoidCallback onTolak;
  final VoidCallback onTerima;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: m.kertas,
          border: Border(top: BorderSide(color: m.garis)),
        ),
        child: boleh
            ? Row(
                children: [
                  Expanded(
                    child: SidikTombol(
                      key: const ValueKey('tombol-tolak-koreksi'),
                      label: l10n.koreksiTolak,
                      ikon: Icons.close,
                      ragam: RagamTombol.bahayaGaris,
                      penuh: true,
                      onPressed: onTolak,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SidikTombol(
                      key: const ValueKey('tombol-terima-koreksi'),
                      label: l10n.koreksiTerima,
                      ikon: Icons.check,
                      ragam: RagamTombol.utama,
                      penuh: true,
                      onPressed: onTerima,
                    ),
                  ),
                ],
              )
            : Text(
                l10n.koreksiBacaSaja,
                key: const ValueKey('catatan-baca-saja-koreksi'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}

/// Satu pasang label-etsa + isi.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.isi,
    this.tanpaJarak = false,
  });

  final String label;
  final String isi;
  final bool tanpaJarak;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Padding(
      padding: EdgeInsets.only(top: tanpaJarak ? 0 : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
          Text(isi, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Satu baris perubahan: label, lalu nilai lama → nilai baru. Nilai pakai
/// lebar digit tetap (nomor seri, tanggal).
class _BarisPerubahan extends StatelessWidget {
  const _BarisPerubahan({required this.perubahan});

  final PerubahanKoreksi perubahan;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final p = perubahan;

    return Column(
      key: ValueKey('perubahan-${p.field}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.label.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                label: l10n.koreksiNilaiLama,
                child: Text(
                  p.lama == null || p.lama!.isEmpty ? '—' : p.lama!,
                  style: SidikTheme.gayaAngka(
                    ukuran: 14,
                    warna: m.tinta2,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.arrow_forward, size: 16, color: m.tinta2),
            ),
            Expanded(
              child: Semantics(
                label: l10n.koreksiNilaiBaru,
                child: Text(
                  p.baru == null || p.baru!.isEmpty ? '—' : p.baru!,
                  style: SidikTheme.gayaAngka(
                    ukuran: 14,
                    berat: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TautanSertifikat extends StatelessWidget {
  const _TautanSertifikat({super.key, required this.id, required this.nomor});

  final int id;
  final String nomor;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SertifikatScreen(certificateId: id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          nomor,
          style: SidikTheme.gayaAngka(
            ukuran: 14,
            berat: FontWeight.w600,
            warna: m.biru,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

/// Hasil keputusan: tanggapan (dibaca pelanggan), siapa & kapan, dan sertifikat
/// pengganti kalau koreksi sertifikat diterima.
class _Keputusan extends StatelessWidget {
  const _Keputusan({required this.koreksi});

  final Koreksi koreksi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final k = koreksi;

    return Kertas(
      key: const ValueKey('keputusan-koreksi'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (k.tanggapan != null && k.tanggapan!.isNotEmpty)
            _Baris(
              label: l10n.koreksiTanggapan,
              isi: k.tanggapan!,
              tanpaJarak: true,
            ),
          if (k.ditinjauOleh != null || k.ditinjauPada != null)
            _Baris(
              label: l10n.koreksiDitinjau,
              isi: [
                ?k.ditinjauOleh,
                if (k.ditinjauPada != null)
                  tanggalPendek(context, k.ditinjauPada!.toLocal()),
              ].join(' · '),
            ),
          if (k.revisi != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.koreksiRevisiLahir.toUpperCase(),
              style: SidikMaterial.of(context).gayaEtsa(ukuran: 11),
            ),
            _TautanSertifikat(
              key: const ValueKey('tautan-koreksi-revisi'),
              id: k.revisi!.id,
              nomor: k.revisi!.nomor,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Terima ───────────────────────────────────────────────────────────────────

/// Lembar "Terima koreksi": tanggapan (opsional), nilai yang boleh dibetulkan
/// admin sebelum diterapkan, dan alasan revisi (hanya koreksi sertifikat).
///
/// Yang dikirim ke `perubahan` hanya isian yang BERBEDA dari yang diminta
/// pelanggan — sisanya dibiarkan server memakai nilai aslinya. Galat 422 tampil
/// di sini (`errors["perubahan.serial_number"]` di bawah kolomnya), lembar
/// tetap terbuka supaya isiannya tidak hilang.
class LembarTerimaKoreksi extends ConsumerStatefulWidget {
  const LembarTerimaKoreksi({super.key, required this.koreksi});

  final Koreksi koreksi;

  @override
  ConsumerState<LembarTerimaKoreksi> createState() =>
      _LembarTerimaKoreksiState();
}

class _LembarTerimaKoreksiState extends ConsumerState<LembarTerimaKoreksi> {
  late final Map<String, TextEditingController> _nilai;
  final _tanggapan = TextEditingController();
  final _alasan = TextEditingController();
  bool _sibuk = false;
  Map<String, String> _galat = {};
  String? _banner;

  @override
  void initState() {
    super.initState();
    _nilai = {
      for (final p in widget.koreksi.perubahan)
        p.field: TextEditingController(text: p.baru ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _nilai.values) {
      c.dispose();
    }
    _tanggapan.dispose();
    _alasan.dispose();
    super.dispose();
  }

  /// Hanya isian yang diubah admin dari nilai yang diminta pelanggan.
  Map<String, String> get _override => {
    for (final p in widget.koreksi.perubahan)
      if (_nilai[p.field]!.text.trim().isNotEmpty &&
          _nilai[p.field]!.text.trim() != (p.baru ?? '').trim())
        p.field: _nilai[p.field]!.text.trim(),
  };

  Future<void> _kirim() async {
    if (_sibuk) return;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final aksi = ref.read(koreksiAksiProvider);

    // Isian yang dikosongkan tidak bisa jadi nilai baru.
    final kosong = {
      for (final p in widget.koreksi.perubahan)
        if (_nilai[p.field]!.text.trim().isEmpty) p.field: l10n.koreksiNilaiWajib,
    };
    if (kosong.isNotEmpty) {
      setState(() {
        _galat = kosong;
        _banner = null;
      });
      return;
    }

    setState(() {
      _sibuk = true;
      _galat = {};
      _banner = null;
    });
    try {
      final hasil = await aksi.terima(
        widget.koreksi.id,
        tanggapan: _tanggapan.text,
        perubahan: _override,
        alasan: widget.koreksi.jenis == JenisKoreksi.sertifikat
            ? _alasan.text
            : null,
      );
      navigator.pop(hasil);
    } on GalatAksi catch (e) {
      if (!mounted) return;
      final galat = <String, String>{};
      for (final p in widget.koreksi.perubahan) {
        final pesan = e.untuk('perubahan.${p.field}');
        if (pesan != null) galat[p.field] = pesan;
      }
      final a = e.untuk('alasan');
      if (a != null) galat['alasan'] = a;
      final t = e.untuk('tanggapan');
      if (t != null) galat['tanggapan'] = t;
      // "Sudah diputus admin lain" dan sejenisnya membawa `{message}` saja.
      if (!e.adaGalatIsian) aksi.segarkan(widget.koreksi.id);
      setState(() {
        _sibuk = false;
        _galat = galat;
        _banner = galat.isEmpty ? e.pesan : l10n.revisiPeriksaIsian;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _banner = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final k = widget.koreksi;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          key: const ValueKey('lembar-terima-koreksi'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.koreksiTerimaJudul, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              k.jenis == JenisKoreksi.sertifikat
                  ? l10n.koreksiTerimaPenjelasanSertifikat
                  : l10n.koreksiTerimaPenjelasanAlat,
              style: theme.textTheme.bodySmall,
            ),
            if (_banner != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                key: const ValueKey('banner-terima-koreksi'),
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: m.gagalTipis,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: m.gagal),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _banner!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m.gagal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final p in k.perubahan) ...[
              TextField(
                key: ValueKey('isian-terima-${p.field}'),
                controller: _nilai[p.field],
                enabled: !_sibuk,
                onChanged: (_) {
                  if (_galat.containsKey(p.field)) {
                    setState(() => _galat = {..._galat}..remove(p.field));
                  }
                },
                decoration: InputDecoration(
                  labelText: p.label,
                  helperText: l10n.koreksiNilaiDiminta(p.baru ?? '—'),
                  helperMaxLines: 2,
                  errorText: _galat[p.field],
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (k.jenis == JenisKoreksi.sertifikat) ...[
              TextField(
                key: const ValueKey('isian-terima-alasan'),
                controller: _alasan,
                enabled: !_sibuk,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.koreksiAlasanRevisi,
                  helperText: l10n.koreksiAlasanRevisiHelper(k.id),
                  helperMaxLines: 2,
                  errorText: _galat['alasan'],
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              key: const ValueKey('isian-terima-tanggapan'),
              controller: _tanggapan,
              enabled: !_sibuk,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.koreksiTanggapanOpsional,
                helperText: l10n.koreksiTanggapanHelper,
                helperMaxLines: 2,
                errorText: _galat['tanggapan'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SidikTombol(
                    label: l10n.custCancel,
                    ragam: RagamTombol.teks,
                    penuh: true,
                    onPressed: _sibuk ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SidikTombol(
                    key: const ValueKey('kirim-terima-koreksi'),
                    label: l10n.koreksiTerimaKirim,
                    ikon: Icons.check,
                    ragam: RagamTombol.utama,
                    penuh: true,
                    sibuk: _sibuk,
                    onPressed: _sibuk ? null : _kirim,
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

// ── Tolak ────────────────────────────────────────────────────────────────────

/// Dialog penolakan: tanggapan WAJIB, dibaca pelanggan apa adanya. Aksinya
/// dijalankan di sini supaya galat 422 tampil di tempat; menutup dengan `true`
/// = ditolak.
class DialogTolakKoreksi extends ConsumerStatefulWidget {
  const DialogTolakKoreksi({super.key, required this.koreksiId});

  final int koreksiId;

  @override
  ConsumerState<DialogTolakKoreksi> createState() => _DialogTolakKoreksiState();
}

class _DialogTolakKoreksiState extends ConsumerState<DialogTolakKoreksi> {
  final _teks = TextEditingController();
  bool _sibuk = false;
  String? _galat;
  String? _banner;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final aksi = ref.read(koreksiAksiProvider);
    if (_sibuk) return;
    if (_teks.text.trim().isEmpty) {
      setState(() => _galat = l10n.koreksiTanggapanWajib);
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
      _banner = null;
    });
    try {
      await aksi.tolak(widget.koreksiId, _teks.text);
      navigator.pop(true);
    } on GalatAksi catch (e) {
      if (!mounted) return;
      if (!e.adaGalatIsian) aksi.segarkan(widget.koreksiId);
      setState(() {
        _sibuk = false;
        _galat = e.untuk('tanggapan');
        _banner = e.adaGalatIsian ? null : e.pesan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _banner = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return AlertDialog(
      key: const ValueKey('dialog-tolak-koreksi'),
      title: Text(l10n.koreksiTolakJudul),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_banner != null) ...[
            Text(
              _banner!,
              key: const ValueKey('banner-tolak-koreksi'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: m.gagal),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            key: const ValueKey('isian-tolak-koreksi'),
            controller: _teks,
            enabled: !_sibuk,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_galat != null) setState(() => _galat = null);
            },
            decoration: InputDecoration(
              hintText: l10n.koreksiTolakPetunjuk,
              helperText: l10n.koreksiTolakHelper,
              helperMaxLines: 2,
              errorText: _galat,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sibuk ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.custCancel),
        ),
        TextButton(
          key: const ValueKey('kirim-tolak-koreksi'),
          onPressed: _sibuk ? null : _kirim,
          child: Text(l10n.koreksiTolakKirim),
        ),
      ],
    );
  }
}
