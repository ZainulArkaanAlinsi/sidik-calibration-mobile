import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/data_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import 'garis_waktu_acuan_screen.dart';
import 'riwayat_sel_acuan_screen.dart';
import 'widgets/grid_acuan.dart';
import 'widgets/keadaan_acuan.dart';

/// S2 Studio Data Acuan — BACA saja (CR-48 P3, 04-UI-UX-Flow §4).
///
/// Tab lembar dibangun dari `skema` paket di server; isinya dari `isi` versi
/// yang dibuka (bawaan: versi aktif hari ini; dari garis waktu: versi mana pun
/// yang boleh dilihat peran ini — server yang menyaring).
///
/// Tidak ada tombol sunting / buat draf / ajukan / sahkan: rute tulisnya
/// (P2) belum lahir di server, dan tombol yang tidak bisa berbuat apa-apa
/// lebih buruk daripada tidak ada tombol.
class StudioAcuanScreen extends StatelessWidget {
  const StudioAcuanScreen({
    super.key,
    required this.kode,
    this.nama,
    this.versiId,
  });

  /// Kode paket (= kode profil, mis. `micrometer`).
  final String kode;

  /// Nama tampilan bila sudah diketahui pemanggil (judul tidak berkedip).
  final String? nama;

  /// Versi yang dibuka. `null` = versi aktif hari ini.
  final int? versiId;

  @override
  Widget build(BuildContext context) => GerbangDataAcuan(
    judul: nama ?? kode,
    child: _Studio(kode: kode, nama: nama, versiId: versiId),
  );
}

class _Studio extends ConsumerWidget {
  const _Studio({required this.kode, this.nama, this.versiId});

  final String kode;
  final String? nama;
  final int? versiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(detailPaketAcuanProvider(kode));
    final judul = detail.value?.nama ?? nama ?? kode;

    void bukaGarisWaktu() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GarisWaktuAcuanScreen(kode: kode, nama: judul),
      ),
    );

    Widget rangka({required Widget body}) => _RangkaStudio(
      judul: judul,
      onGarisWaktu: detail.hasValue ? bukaGarisWaktu : null,
      body: body,
    );

    return detail.when(
      loading: () => rangka(body: const KerangkaGridAcuan()),
      error: (e, _) => rangka(
        body: GalatAcuan(
          galat: e,
          onCobaLagi: () => ref.invalidate(detailPaketAcuanProvider(kode)),
        ),
      ),
      data: (paket) {
        final id = versiId ?? paket.versiAktif?.id;
        if (id == null) {
          return rangka(
            body: KeadaanAcuan(
              ikon: Icons.event_busy_outlined,
              judul: l10n.acuanTanpaVersiAktif,
              keterangan: l10n.acuanTanpaVersiAktifKet,
            ),
          );
        }

        final skema = paket.skema;
        if (skema == null || skema.lembar.isEmpty) {
          return rangka(
            body: KeadaanAcuan(
              ikon: Icons.grid_off_outlined,
              judul: l10n.acuanSkemaKosong,
            ),
          );
        }

        final versi = ref.watch(versiAcuanProvider(id));
        return versi.when(
          loading: () => rangka(body: const KerangkaGridAcuan()),
          error: (e, _) => rangka(
            body: GalatAcuan(
              galat: e,
              onCobaLagi: () => ref.invalidate(versiAcuanProvider(id)),
            ),
          ),
          data: (v) => _StudioTab(
            judul: judul,
            skema: skema,
            versi: v,
            onGarisWaktu: bukaGarisWaktu,
          ),
        );
      },
    );
  }
}

/// AppBar + isi untuk keadaan sebelum tab tersedia (memuat, galat, kosong).
class _RangkaStudio extends StatelessWidget {
  const _RangkaStudio({
    required this.judul,
    required this.body,
    this.onGarisWaktu,
  });

  final String judul;
  final Widget body;
  final VoidCallback? onGarisWaktu;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: _JudulStudio(judul: judul),
      actions: [
        if (onGarisWaktu != null) _TombolGarisWaktu(onPressed: onGarisWaktu!),
      ],
    ),
    body: body,
  );
}

class _JudulStudio extends StatelessWidget {
  const _JudulStudio({required this.judul, this.versi});

  final String judul;
  final VersiAcuan? versi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = versi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(judul, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (v != null)
          Text(
            '${l10n.acuanVersiNomor(v.nomor)} · '
            '${labelStatusVersiAcuan(v.kodeStatus, l10n)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _TombolGarisWaktu extends StatelessWidget {
  const _TombolGarisWaktu({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).acuanGarisWaktu,
    icon: const Icon(Icons.timeline),
    onPressed: onPressed,
  );
}

class _StudioTab extends ConsumerStatefulWidget {
  const _StudioTab({
    required this.judul,
    required this.skema,
    required this.versi,
    required this.onGarisWaktu,
  });

  final String judul;
  final SkemaAcuan skema;
  final VersiAcuan versi;
  final VoidCallback onGarisWaktu;

  @override
  ConsumerState<_StudioTab> createState() => _StudioTabState();
}

class _StudioTabState extends ConsumerState<_StudioTab> {
  /// Sel terakhir yang diketuk, per lembar — penanda posisi waktu kembali
  /// dari rincian/riwayat sel.
  final _terpilih = <String, SelTerpilihAcuan>{};

  late List<List<MapEntry<String, Map<String, Object?>>>> _barisPerLembar;

  @override
  void initState() {
    super.initState();
    _bacaBaris();
  }

  @override
  void didUpdateWidget(covariant _StudioTab lama) {
    super.didUpdateWidget(lama);
    if (!identical(lama.versi, widget.versi) ||
        !identical(lama.skema, widget.skema)) {
      _bacaBaris();
    }
  }

  void _bacaBaris() {
    _barisPerLembar = [
      for (final lembar in widget.skema.lembar)
        urutBarisTampilAcuan(
          lembar,
          barisLembarAcuan(lembar, widget.versi.isi),
        ),
    ];
  }

  void _ketukSel(LembarSkemaAcuan lembar, String kunci, KolomSkemaAcuan kolom) {
    setState(() => _terpilih[lembar.kode] = (kunci: kunci, kolom: kolom.kode));

    final sel = _barisPerLembar[widget.skema.lembar.indexOf(lembar)]
        .firstWhere((b) => b.key == kunci)
        .value;

    // Riwayat sel: server menjawab 404 untuk teknisi dan untuk versi berjenis
    // selain `data` (`DataAcuanController::riwayatSel`) — tombolnya tidak
    // ditawarkan di dua keadaan itu.
    final bolehRiwayat =
        bolehLihatSemuaVersiAcuan(peranDataAcuan(ref)) &&
        widget.versi.jenis == 'data';

    tampilkanRincianSelAcuan(
      context,
      lembar: lembar,
      kolom: kolom,
      kunci: kunci,
      ada: sel.containsKey(kolom.kode),
      nilai: sel[kolom.kode],
      onRiwayat: bolehRiwayat
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RiwayatSelAcuanScreen(
                  sel: (
                    versiId: widget.versi.id,
                    lembar: lembar.kode,
                    kunci: kunci,
                    kolom: kolom.kode,
                  ),
                  labelLembar: lembar.label,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final lembar = widget.skema.lembar;
    final versi = widget.versi;
    final bukanAktif = versi.status != StatusVersiAcuan.aktif;

    return DefaultTabController(
      key: ValueKey('${versi.id}:${lembar.map((l) => l.kode).join(',')}'),
      length: lembar.length,
      child: Scaffold(
        appBar: AppBar(
          title: _JudulStudio(judul: widget.judul, versi: versi),
          actions: [
            IconButton(
              tooltip: l10n.acuanInfoVersi,
              icon: const Icon(Icons.info_outline),
              onPressed: () => tampilkanInfoVersiAcuan(context, versi),
            ),
            _TombolGarisWaktu(onPressed: widget.onGarisWaktu),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final l in lembar)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.label),
                      if (l.kolom.any((k) => k.perluKonfirmasi)) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.flag_outlined, size: 16, color: m.awas),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (bukanAktif)
              Container(
                width: double.infinity,
                color: m.awasTipis,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.acuanBukanVersiAktif(
                    labelStatusVersiAcuan(versi.kodeStatus, l10n),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: m.tinta),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  for (var i = 0; i < lembar.length; i++)
                    _IsiLembar(
                      lembar: lembar[i],
                      baris: _barisPerLembar[i],
                      terpilih: _terpilih[lembar[i].kode],
                      onTapSel: (kunci, kolom) =>
                          _ketukSel(lembar[i], kunci, kolom),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IsiLembar extends StatelessWidget {
  const _IsiLembar({
    required this.lembar,
    required this.baris,
    required this.onTapSel,
    this.terpilih,
  });

  final LembarSkemaAcuan lembar;
  final List<MapEntry<String, Map<String, Object?>>> baris;
  final void Function(String kunci, KolomSkemaAcuan kolom) onTapSel;
  final SelTerpilihAcuan? terpilih;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    if (baris.isEmpty) {
      // P2 menambah "Tambah baris" di sini — belum, karena belum ada rute tulis.
      return KeadaanAcuan(
        ikon: Icons.table_rows_outlined,
        judul: l10n.acuanLembarKosong,
      );
    }

    final adaKonfirmasi = lembar.kolom.any((k) => k.perluKonfirmasi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridAcuan(
            lembar: lembar,
            baris: baris,
            terpilih: terpilih,
            onTapSel: onTapSel,
          ),
        ),
        Container(
          color: m.kertas2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.acuanKakiLembar(baris.length),
                style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
              ),
              if (adaKonfirmasi)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 16, color: m.awas),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l10n.acuanPerluKonfirmasi,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m.tinta2,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────── lembar bawah

Future<void> _lembarBawah(
  BuildContext context, {
  required String judul,
  required List<Widget> isi,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    minChildSize: 0.3,
    maxChildSize: 0.95,
    builder: (context, gulir) => ListView(
      controller: gulir,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        Text(judul, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        ...isi,
      ],
    ),
  ),
);

/// Satu baris "label — isi" di lembar bawah.
class _BarisInfo extends StatelessWidget {
  const _BarisInfo({required this.label, required this.isi});

  final String label;
  final Widget isi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: m.tinta2),
          ),
          const SizedBox(height: 2),
          isi,
        ],
      ),
    );
  }
}

/// Rincian satu sel: nilai tersimpan PERSIS, asal sel master, tanda
/// konfirmasi. [onRiwayat] `null` = tombol riwayat tidak ditawarkan (server
/// menjawab 404 untuk peran/versi ini).
Future<void> tampilkanRincianSelAcuan(
  BuildContext context, {
  required LembarSkemaAcuan lembar,
  required KolomSkemaAcuan kolom,
  required String kunci,
  required bool ada,
  required Object? nilai,
  VoidCallback? onRiwayat,
}) {
  final l10n = AppLocalizations.of(context);
  final m = SidikMaterial.of(context);
  final theme = Theme.of(context);
  final mono = SidikTheme.gayaAngka(
    ukuran: 14,
    berat: FontWeight.w500,
    warna: m.tinta,
  );

  return _lembarBawah(
    context,
    judul: [kolom.label, ?kolom.satuan].join(' · '),
    isi: [
      _BarisInfo(
        label: l10n.acuanSelLembar,
        isi: Text(lembar.label, style: theme.textTheme.bodyMedium),
      ),
      _BarisInfo(
        label: l10n.acuanSelKunci,
        isi: SelectableText(kunci, style: mono),
      ),
      _BarisInfo(
        label: l10n.acuanSelNilai,
        isi: !ada || nilai == null
            ? TeksSelAcuan(ada: ada, nilai: nilai, kolom: kolom, ukuran: 20)
            : SelectableText(
                teksNilaiAcuan(nilai)!,
                style: mono.copyWith(fontSize: 20),
              ),
      ),
      _BarisInfo(
        label: l10n.acuanSelTipe,
        isi: Text(kolom.tipe, style: mono),
      ),
      _BarisInfo(
        label: l10n.acuanSelAsal,
        isi: kolom.asal == null
            ? Text(
                l10n.acuanSelAsalKosong,
                style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta2),
              )
            : SelectableText(kolom.asal!, style: mono),
      ),
      if (kolom.perluKonfirmasi)
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: m.awasTipis,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: m.awas),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.acuanSelPerluKonfirmasiKet,
                  style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
                ),
              ),
            ],
          ),
        ),
      if (onRiwayat != null)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onRiwayat,
            icon: const Icon(Icons.history),
            label: Text(l10n.acuanSelRiwayat),
          ),
        ),
    ],
  );
}

/// Info versi: nomor, status, berlaku, sha256 (dipendekkan), pengesah,
/// alasan, rujukan. `*_oleh` masih id user (kontrak §15) — ditulis sebagai
/// id, bukan ditebak namanya.
Future<void> tampilkanInfoVersiAcuan(BuildContext context, VersiAcuan versi) {
  final l10n = AppLocalizations.of(context);
  final m = SidikMaterial.of(context);
  final theme = Theme.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final mono = SidikTheme.gayaAngka(
    ukuran: 14,
    berat: FontWeight.w500,
    warna: m.tinta,
  );
  final teks = theme.textTheme.bodyMedium?.copyWith(color: m.tinta);
  final redup = theme.textTheme.bodyMedium?.copyWith(color: m.tinta2);
  final sha = versi.isiSha256;

  return _lembarBawah(
    context,
    judul: '${l10n.acuanInfoVersi} · ${l10n.acuanVersiNomor(versi.nomor)}',
    isi: [
      _BarisInfo(
        label: l10n.acuanInfoStatus,
        isi: Align(
          alignment: Alignment.centerLeft,
          child: LencanaVersiAcuan(versi.kodeStatus),
        ),
      ),
      _BarisInfo(
        label: l10n.acuanInfoJenis,
        isi: Text(
          versi.jenis == 'bentuk' ? l10n.acuanJenisBentuk : l10n.acuanJenisData,
          style: teks,
        ),
      ),
      _BarisInfo(
        label: l10n.acuanInfoBerlaku,
        isi: Text(
          teksBerlakuAcuan(
            versi.berlakuMulai,
            versi.berlakuSampai,
            l10n,
            locale,
          ),
          style: teks,
        ),
      ),
      _BarisInfo(
        label: l10n.acuanInfoSha,
        isi: sha == null
            ? Text(l10n.acuanInfoShaBelum, style: redup)
            : Tooltip(
                message: sha,
                child: Text(shaPendekAcuan(sha), style: mono),
              ),
      ),
      if (versi.skemaVersi != null)
        _BarisInfo(
          label: l10n.acuanInfoSkema,
          isi: Text(l10n.acuanVersiNomor(versi.skemaVersi!), style: mono),
        ),
      if (versi.dibuatPada != null)
        _BarisInfo(
          label: l10n.acuanInfoDibuat,
          isi: Text(
            waktuLengkap(versi.dibuatPada!.toLocal(), locale),
            style: teks,
          ),
        ),
      _BarisInfo(
        label: l10n.acuanInfoDisahkan,
        isi: versi.disahkanOleh == null
            ? Text(l10n.acuanInfoBelumDisahkan, style: redup)
            : Text(
                l10n.acuanInfoOlehPada(
                  versi.disahkanOleh!,
                  versi.disahkanPada == null
                      ? '—'
                      : waktuLengkap(versi.disahkanPada!.toLocal(), locale),
                ),
                style: teks,
              ),
      ),
      if (versi.alasan != null && versi.alasan!.isNotEmpty)
        _BarisInfo(
          label: l10n.acuanInfoAlasan,
          isi: Text(versi.alasan!, style: teks),
        ),
      if (versi.rujukan.isNotEmpty)
        _BarisInfo(
          label: l10n.acuanInfoRujukan,
          isi: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in versi.rujukan)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    [r.jenis, ?r.nilai, ?r.catatan].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: m.tinta),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
