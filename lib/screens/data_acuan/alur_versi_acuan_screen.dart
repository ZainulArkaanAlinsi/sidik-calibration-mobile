import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alur_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'simulasi_versi_acuan_screen.dart';
import 'widgets/hak_alur_acuan.dart';
import 'widgets/keadaan_acuan.dart';

/// Alur versi data acuan satu profil (T2.2/T2.3): versi data + status +
/// ringkasan simulasi + `wajib_diakui` + log, plus aksi Ajukan / Jalankan
/// simulasi / Tolak / Aktifkan untuk yang berhak ([hakAlurAcuan]).
///
/// Dipakai DUA aplikasi: aplikasi lab (aksi tulis) dan Sidik Studio (baca
/// saja — [alurAcuanBacaSajaProvider], token Studio ditolak di rute tulis).
class AlurVersiAcuanScreen extends StatelessWidget {
  const AlurVersiAcuanScreen({super.key, required this.kode, this.nama});

  final String kode;
  final String? nama;

  @override
  Widget build(BuildContext context) => GerbangDataAcuan(
    judul: AppLocalizations.of(context).alurAcuanJudul,
    child: _Alur(kode: kode, nama: nama),
  );
}

/// Tarik ulang semua yang bisa berubah karena satu aksi alur.
void _segarkanSesudahAksi(WidgetRef ref) {
  ref.invalidate(alurAcuanProvider);
  ref.invalidate(laporanSimulasiAcuanProvider);
  ref.invalidate(garisWaktuAcuanProvider);
  ref.invalidate(daftarPaketAcuanProvider);
  ref.invalidate(detailPaketAcuanProvider);
  ref.invalidate(berlakuAcuanProvider);
}

class _Alur extends ConsumerWidget {
  const _Alur({required this.kode, this.nama});

  final String kode;
  final String? nama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final alur = ref.watch(alurAcuanProvider(kode));
    final bacaSaja = ref.watch(alurAcuanBacaSajaProvider);
    final hak = hakAlurAcuan(ref);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.alurAcuanJudul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              nama ?? kode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(alurAcuanProvider(kode).future),
        child: alur.when(
          loading: () => const KerangkaDaftarAcuan(),
          error: (e, _) => GalatAcuan(
            galat: e,
            onCobaLagi: () => ref.invalidate(alurAcuanProvider(kode)),
          ),
          data: (versi) {
            if (versi.isEmpty) {
              return KeadaanAcuan(
                ikon: Icons.timeline,
                judul: l10n.alurAcuanKosong,
                keterangan: bacaSaja ? l10n.alurAcuanBacaSajaKet : null,
              );
            }
            return ReadableWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (bacaSaja) const _BannerBacaSaja(),
                  for (final v in versi)
                    _KartuVersiAlur(
                      key: ValueKey('alur-versi-${v.id}'),
                      kode: kode,
                      versi: v,
                      hak: hak,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BannerBacaSaja extends StatelessWidget {
  const _BannerBacaSaja();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('alur-baca-saja'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: m.tungguTipis,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: m.tunggu),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: m.tunggu),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.alurAcuanBacaSajaJudul,
                  style: theme.textTheme.titleSmall?.copyWith(color: m.tinta),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.alurAcuanBacaSajaKet,
                  style: theme.textTheme.bodySmall?.copyWith(color: m.tinta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuVersiAlur extends ConsumerWidget {
  const _KartuVersiAlur({
    super.key,
    required this.kode,
    required this.versi,
    required this.hak,
  });

  final String kode;
  final VersiAlurAcuan versi;
  final HakAlurAcuan hak;

  Future<void> _aksi(
    BuildContext context,
    WidgetRef ref,
    Widget dialog,
    String sukses,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final berhasil = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (berhasil != true) return;
    _segarkanSesudahAksi(ref);
    messenger?.showSnackBar(SnackBar(content: Text(sukses)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final v = versi.versi;
    final status = versi.status;
    final sim = versi.simulasi;
    final sha = v.isiSha256;
    final layanan = ref.read(dataAcuanServiceProvider);

    final tombol = <Widget>[
      if (hak.bolehAjukan(status))
        FilledButton.icon(
          key: ValueKey('alur-ajukan-${v.id}'),
          icon: const Icon(Icons.send_outlined, size: 18),
          label: Text(l10n.alurAcuanAjukan),
          onPressed: () => _aksi(
            context,
            ref,
            _DialogAjukan(
              kirim: (alasan, rujukan) async => layanan.ajukan(
                await tokenAksiAcuan(ref),
                v.id,
                alasan: alasan,
                rujukan: rujukan,
              ),
            ),
            l10n.alurAcuanSuksesAjukan(v.nomor),
          ),
        ),
      if (hak.bolehSimulasi(status))
        OutlinedButton.icon(
          key: ValueKey('alur-simulasi-${v.id}'),
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: Text(l10n.alurAcuanJalankanSimulasi),
          onPressed: () => _aksi(
            context,
            ref,
            _DialogKonfirmasi(
              judul: l10n.alurAcuanJalankanSimulasi,
              keterangan: l10n.alurAcuanSimulasiKonfirmasi,
              tombol: l10n.alurAcuanJalankanSimulasi,
              kirim: () async =>
                  layanan.jalankanSimulasi(await tokenAksiAcuan(ref), v.id),
            ),
            l10n.alurAcuanSuksesSimulasi,
          ),
        ),
      if (hak.bolehTolak(status))
        OutlinedButton.icon(
          key: ValueKey('alur-tolak-${v.id}'),
          icon: const Icon(Icons.block, size: 18),
          label: Text(l10n.alurAcuanTolak),
          onPressed: () => _aksi(
            context,
            ref,
            _DialogTolak(
              kirim: (alasan) async => layanan.tolak(
                await tokenAksiAcuan(ref),
                v.id,
                alasan: alasan,
              ),
            ),
            l10n.alurAcuanSuksesTolak(v.nomor),
          ),
        ),
      if (hak.bolehAktifkan(status))
        FilledButton.icon(
          key: ValueKey('alur-aktifkan-${v.id}'),
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: Text(l10n.alurAcuanAktifkan),
          onPressed: () => _aksi(
            context,
            ref,
            _DialogAktifkan(
              versi: versi,
              kirim: (berlaku, sandi, catatan, pengakuan) async =>
                  layanan.aktifkan(
                    await tokenAksiAcuan(ref),
                    v.id,
                    berlakuMulai: berlaku,
                    password: sandi,
                    catatan: catatan,
                    pengakuan: pengakuan,
                  ),
            ),
            l10n.alurAcuanSuksesAktifkan(v.nomor),
          ),
        ),
    ];

    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.acuanVersiNomor(v.nomor),
                style: SidikTheme.gayaAngka(ukuran: 16, warna: m.tinta),
              ),
              LencanaVersiAcuan(v.kodeStatus),
              Text(
                teksBerlakuAcuan(v.berlakuMulai, v.berlakuSampai, l10n, locale),
                style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
              ),
            ],
          ),
          if (sha != null)
            Tooltip(
              message: sha,
              child: Text(
                shaPendekAcuan(sha),
                style: SidikTheme.gayaAngka(
                  ukuran: 12,
                  berat: FontWeight.w400,
                  warna: m.tinta2,
                ),
              ),
            ),
          if (v.alasan != null && v.alasan!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                v.alasan!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _RingkasSimulasi(versiId: v.id, nomor: v.nomor, sim: sim),
          if (tombol.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: tombol,
            ),
          ],
          if (versi.log.isNotEmpty)
            // Material sendiri: Kertas berlatar, tinta ListTile butuh ancestor.
            Material(
              type: MaterialType.transparency,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('alur-log-${v.id}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    l10n.alurAcuanLog(versi.log.length),
                    style: theme.textTheme.bodyMedium,
                  ),
                  children: [for (final l in versi.log) _BarisLog(log: l)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingkasSimulasi extends StatelessWidget {
  const _RingkasSimulasi({
    required this.versiId,
    required this.nomor,
    required this.sim,
  });

  final int versiId;
  final int nomor;
  final SimulasiVersiAcuan sim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final r = sim.ringkasan;
    final warnaStatus = switch (sim.status) {
      StatusSimulasiAcuan.terbaru => m.lulus,
      StatusSimulasiAcuan.kedaluwarsa || StatusSimulasiAcuan.gagal => m.gagal,
      _ => m.tinta2,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l10n.alurAcuanSimulasiJudul}: '),
              TextSpan(
                text: labelStatusSimulasi(sim, l10n),
                style: TextStyle(
                  color: warnaStatus,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          key: ValueKey('alur-sim-status-$versiId'),
          style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
        ),
        if (r != null)
          Text(
            l10n.alurAcuanRingkasan(
              r.sesiTotal ?? 0,
              r.sesiBerubah ?? 0,
              r.cetakBerubah ?? 0,
              r.terbitCetakBerubah ?? 0,
              r.vonisBerubah ?? 0,
              r.sesiGagal ?? 0,
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
          ),
        if ((r?.bersamaAntarVarian ?? 0) > 0)
          Text(
            l10n.alurAcuanBersama(r!.bersamaAntarVarian!),
            style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
          ),
        if (r?.catatanSumber != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              r!.catatanSumber!,
              style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
            ),
          ),
        if (sim.wajibDiakui.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.alurAcuanWajibDiakui,
            style: theme.textTheme.labelMedium?.copyWith(color: m.tinta),
          ),
          for (final b in sim.wajibDiakui)
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: m.awas),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    labelButirPengakuan(b, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(color: m.tinta),
                  ),
                ),
              ],
            ),
        ],
        if (sim.id != null)
          TextButton.icon(
            key: ValueKey('alur-laporan-$versiId'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: Text(l10n.alurAcuanLihatLaporan),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SimulasiVersiAcuanScreen(versiId: versiId, nomor: nomor),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarisLog extends StatelessWidget {
  const _BarisLog({required this.log});

  final LogAlurAcuan log;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final aksi = switch (log.aksi) {
      'dibuat' => l10n.alurAcuanAksiDibuat,
      'ajukan' => l10n.alurAcuanAksiAjukan,
      'simulasi' => l10n.alurAcuanAksiSimulasi,
      'sahkan' => l10n.alurAcuanAksiSahkan,
      'tolak' => l10n.alurAcuanAksiTolak,
      'buang' => l10n.alurAcuanAksiBuang,
      'pensiun' => l10n.alurAcuanAksiPensiun,
      _ => log.aksi,
    };
    final transisi = log.statusDari == null && log.statusKe == null
        ? ''
        : ' · ${log.statusDari == null ? '—' : labelStatusVersiAcuan(log.statusDari!, l10n)}'
              ' → ${log.statusKe == null ? '—' : labelStatusVersiAcuan(log.statusKe!, l10n)}';
    final waktu = log.pada == null
        ? ''
        : '${tanggalAcuan(log.pada!.toLocal(), locale)} '
              '${log.pada!.toLocal().hour.toString().padLeft(2, '0')}:'
              '${log.pada!.toLocal().minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$aksi$transisi',
            style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
          ),
          Text(
            [
              if (waktu.isNotEmpty) waktu,
              if (log.userId != null) l10n.alurAcuanOleh(log.userId!),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
          ),
          if (log.alasan != null)
            Text(
              log.alasan!,
              style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── dialog aksi

/// Kerangka dialog aksi: menjalankan [kirim], menampilkan galat yang sudah
/// dipetakan, menutup dengan `true` bila berhasil.
mixin _AksiDialog<T extends StatefulWidget> on State<T> {
  bool sibuk = false;
  String? galat;

  Future<void> jalankan(Future<void> Function() kirim) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      sibuk = true;
      galat = null;
    });
    try {
      await kirim();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => galat = pesanGalatAlurAcuan(e, l10n));
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  Widget teksGalat() => galat == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            galat!,
            key: const ValueKey('alur-dialog-galat'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );

  List<Widget> tombolDialog(String label, VoidCallback? kirim) {
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        key: const ValueKey('alur-dialog-batal'),
        onPressed: sibuk ? null : () => Navigator.of(context).pop(false),
        child: Text(l10n.alurAcuanBatal),
      ),
      FilledButton(
        key: const ValueKey('alur-dialog-kirim'),
        onPressed: sibuk ? null : kirim,
        child: sibuk
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    ];
  }
}

bool _alasanSah(String teks) =>
    teks.trim().length >= ButirPengakuanAcuan.panjangMinimum;

class _DialogKonfirmasi extends StatefulWidget {
  const _DialogKonfirmasi({
    required this.judul,
    required this.keterangan,
    required this.tombol,
    required this.kirim,
  });

  final String judul;
  final String keterangan;
  final String tombol;
  final Future<void> Function() kirim;

  @override
  State<_DialogKonfirmasi> createState() => _DialogKonfirmasiState();
}

class _DialogKonfirmasiState extends State<_DialogKonfirmasi> with _AksiDialog {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.judul),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(widget.keterangan), teksGalat()],
    ),
    actions: tombolDialog(widget.tombol, () => jalankan(widget.kirim)),
  );
}

class _DialogTolak extends StatefulWidget {
  const _DialogTolak({required this.kirim});

  final Future<void> Function(String alasan) kirim;

  @override
  State<_DialogTolak> createState() => _DialogTolakState();
}

class _DialogTolakState extends State<_DialogTolak> with _AksiDialog {
  final _alasan = TextEditingController();
  String? _galatAlasan;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  void _kirim() {
    final l10n = AppLocalizations.of(context);
    final alasan = _alasan.text.trim();
    setState(
      () => _galatAlasan = _alasanSah(alasan) ? null : l10n.alurAcuanAlasanMin,
    );
    if (_galatAlasan != null) return;
    jalankan(() => widget.kirim(alasan));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.alurAcuanTolak),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.alurAcuanTolakKet),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('tolak-alasan'),
              controller: _alasan,
              enabled: !sibuk,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.alurAcuanAlasan,
                errorText: _galatAlasan,
              ),
            ),
            teksGalat(),
          ],
        ),
      ),
      actions: tombolDialog(l10n.alurAcuanTolak, _kirim),
    );
  }
}

class _BarisRujukan {
  _BarisRujukan() : nilai = TextEditingController();

  String jenis = RujukanAjuanAcuan.jenisSah.first;
  final TextEditingController nilai;
}

class _DialogAjukan extends StatefulWidget {
  const _DialogAjukan({required this.kirim});

  final Future<void> Function(String alasan, List<RujukanAjuanAcuan> rujukan)
  kirim;

  @override
  State<_DialogAjukan> createState() => _DialogAjukanState();
}

class _DialogAjukanState extends State<_DialogAjukan> with _AksiDialog {
  static const _maksRujukan = 20;

  final _alasan = TextEditingController();
  final _rujukan = <_BarisRujukan>[];
  String? _galatAlasan;
  String? _galatRujukan;

  @override
  void dispose() {
    _alasan.dispose();
    for (final r in _rujukan) {
      r.nilai.dispose();
    }
    super.dispose();
  }

  String _labelJenis(String jenis, AppLocalizations l10n) => switch (jenis) {
    'sertifikat_standar' => l10n.alurAcuanJenisSertifikatStandar,
    'ik' => l10n.alurAcuanJenisIk,
    'lampiran' => l10n.alurAcuanJenisLampiran,
    'sel_master' => l10n.alurAcuanJenisSelMaster,
    _ => l10n.alurAcuanJenisLain,
  };

  void _kirim() {
    final l10n = AppLocalizations.of(context);
    final alasan = _alasan.text.trim();
    final rujukanKosong = _rujukan.any((r) => r.nilai.text.trim().isEmpty);
    setState(() {
      _galatAlasan = _alasanSah(alasan) ? null : l10n.alurAcuanAlasanMin;
      _galatRujukan = rujukanKosong ? l10n.alurAcuanRujukanNilaiWajib : null;
    });
    if (_galatAlasan != null || _galatRujukan != null) return;
    final rujukan = [
      for (final r in _rujukan)
        RujukanAjuanAcuan(jenis: r.jenis, nilai: r.nilai.text.trim()),
    ];
    jalankan(() => widget.kirim(alasan, rujukan));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.alurAcuanAjukan),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('ajukan-alasan'),
                controller: _alasan,
                enabled: !sibuk,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: l10n.alurAcuanAlasan,
                  errorText: _galatAlasan,
                ),
              ),
              Text(l10n.alurAcuanRujukan, style: theme.textTheme.labelLarge),
              for (var i = 0; i < _rujukan.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('ajukan-rujukan-jenis-$i'),
                          initialValue: _rujukan[i].jenis,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.alurAcuanRujukanJenis,
                          ),
                          items: [
                            for (final j in RujukanAjuanAcuan.jenisSah)
                              DropdownMenuItem(
                                value: j,
                                child: Text(
                                  _labelJenis(j, l10n),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: sibuk
                              ? null
                              : (j) => setState(
                                  () => _rujukan[i].jenis = j ?? 'lain',
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          key: ValueKey('ajukan-rujukan-nilai-$i'),
                          controller: _rujukan[i].nilai,
                          enabled: !sibuk,
                          maxLength: 255,
                          decoration: InputDecoration(
                            labelText: l10n.alurAcuanRujukanNilai,
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.alurAcuanHapusRujukan,
                        icon: const Icon(Icons.close),
                        onPressed: sibuk
                            ? null
                            : () => setState(
                                () => _rujukan.removeAt(i).nilai.dispose(),
                              ),
                      ),
                    ],
                  ),
                ),
              if (_galatRujukan != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _galatRujukan!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_rujukan.length < _maksRujukan)
                TextButton.icon(
                  key: const ValueKey('ajukan-tambah-rujukan'),
                  onPressed: sibuk
                      ? null
                      : () => setState(() => _rujukan.add(_BarisRujukan())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.alurAcuanTambahRujukan),
                ),
              teksGalat(),
            ],
          ),
        ),
      ),
      actions: tombolDialog(l10n.alurAcuanAjukan, _kirim),
    );
  }
}

typedef _KirimAktifkan =
    Future<void> Function(
      DateTime berlakuMulai,
      String sandi,
      String? catatan,
      Map<String, String> pengakuan,
    );

class _DialogAktifkan extends StatefulWidget {
  const _DialogAktifkan({required this.versi, required this.kirim});

  final VersiAlurAcuan versi;
  final _KirimAktifkan kirim;

  @override
  State<_DialogAktifkan> createState() => _DialogAktifkanState();
}

class _DialogAktifkanState extends State<_DialogAktifkan> with _AksiDialog {
  final _sandi = TextEditingController();
  final _catatan = TextEditingController();
  late final Map<String, TextEditingController> _pengakuan = {
    for (final b in widget.versi.simulasi.wajibDiakui)
      b: TextEditingController(),
  };
  final Map<String, String?> _galatPengakuan = {};
  String? _galatSandi;
  late DateTime _berlaku = _hariIni();

  static DateTime _hariIni() {
    final s = DateTime.now();
    return DateTime(s.year, s.month, s.day);
  }

  @override
  void dispose() {
    _sandi.dispose();
    _catatan.dispose();
    for (final c in _pengakuan.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final hariIni = _hariIni();
    final pilih = await showDatePicker(
      context: context,
      initialDate: _berlaku,
      firstDate: hariIni,
      lastDate: DateTime(hariIni.year + 5, hariIni.month, hariIni.day),
    );
    if (pilih != null && mounted) setState(() => _berlaku = pilih);
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final sandi = _sandi.text;
    setState(() {
      _galatSandi = sandi.isEmpty ? l10n.alurAcuanSandiWajib : null;
      for (final MapEntry(key: b, value: c) in _pengakuan.entries) {
        _galatPengakuan[b] = _alasanSah(c.text)
            ? null
            : l10n.alurAcuanAlasanMin;
      }
    });
    if (_galatSandi != null || _galatPengakuan.values.any((g) => g != null)) {
      return;
    }
    final catatan = _catatan.text.trim();
    await jalankan(
      () => widget.kirim(_berlaku, sandi, catatan.isEmpty ? null : catatan, {
        for (final MapEntry(key: b, value: c) in _pengakuan.entries)
          b: c.text.trim(),
      }),
    );
    // Sandi tidak bertahan sesudah satu kali kirim, apa pun hasilnya (bila
    // berhasil, dialog sudah tertutup dan isiannya ikut dibuang).
    if (mounted) _sandi.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final sim = widget.versi.simulasi;
    final simTerbaru = sim.status == StatusSimulasiAcuan.terbaru;

    return AlertDialog(
      title: Text(
        '${l10n.alurAcuanAktifkan} '
        '${l10n.acuanVersiNomor(widget.versi.nomor)}',
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!simTerbaru)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.alurAcuanSimulasiHarusTerbaru,
                    key: const ValueKey('aktifkan-sim-belum-terbaru'),
                    style: TextStyle(color: m.gagal),
                  ),
                ),
              Text(
                l10n.alurAcuanAktifkanKet,
                style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.alurAcuanBerlakuMulai}: '
                      '${tanggalAcuan(_berlaku, locale)}',
                      key: const ValueKey('aktifkan-berlaku'),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('aktifkan-ubah-tanggal'),
                    onPressed: sibuk ? null : _pilihTanggal,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(l10n.alurAcuanUbahTanggal),
                  ),
                ],
              ),
              if (_pengakuan.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.alurAcuanPengakuanJudul,
                  style: theme.textTheme.labelLarge,
                ),
                for (final MapEntry(key: b, value: c) in _pengakuan.entries)
                  TextField(
                    key: ValueKey('aktifkan-pengakuan-$b'),
                    controller: c,
                    enabled: !sibuk,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: labelButirPengakuan(b, l10n),
                      errorText: _galatPengakuan[b],
                    ),
                  ),
              ],
              TextField(
                key: const ValueKey('aktifkan-catatan'),
                controller: _catatan,
                enabled: !sibuk,
                maxLength: 2000,
                decoration: InputDecoration(labelText: l10n.alurAcuanCatatan),
              ),
              TextField(
                key: const ValueKey('aktifkan-sandi'),
                controller: _sandi,
                enabled: !sibuk,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.alurAcuanSandi,
                  errorText: _galatSandi,
                ),
              ),
              teksGalat(),
            ],
          ),
        ),
      ),
      actions: tombolDialog(l10n.alurAcuanAktifkan, simTerbaru ? _kirim : null),
    );
  }
}
