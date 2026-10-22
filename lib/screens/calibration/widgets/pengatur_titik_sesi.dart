import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/titik_sesi.dart';
import '../lembar_kerja_state.dart';
import '../titik_sesi_state.dart';

/// Pesan manusia untuk [GalatTitikSesi].
String pesanGalatTitikSesi(AppLocalizations l10n, GalatTitikSesi g) =>
    switch (g) {
      GalatTitikSesi.tabelTidakAda => l10n.titikSesiGalatTabel,
      GalatTitikSesi.tidakBolehTambah => l10n.titikSesiGalatTidakBolehTambah,
      GalatTitikSesi.nominalKembar => l10n.titikSesiGalatKembar,
      GalatTitikSesi.aktifPenuh => l10n.titikSesiGalatAktifPenuh,
      GalatTitikSesi.aktifMinimum => l10n.titikSesiGalatAktifMinimum,
      GalatTitikSesi.totalPenuh => l10n.titikSesiGalatTotalPenuh,
      GalatTitikSesi.alasanPendek => l10n.titikSesiGalatAlasanPendek,
      GalatTitikSesi.alasanPelanggan => l10n.titikSesiGalatAlasanPelanggan,
      GalatTitikSesi.tidakBolehNonaktif =>
        l10n.titikSesiGalatTidakBolehNonaktif,
      GalatTitikSesi.pertamaTerkunci => l10n.titikSesiGalatPertama,
      GalatTitikSesi.punyaPembacaan => l10n.titikSesiGalatPunyaPembacaan,
      GalatTitikSesi.nominalDipatok => l10n.titikSesiGalatDipatok,
      GalatTitikSesi.faseTidakBoleh => l10n.titikSesiGalatFase,
      GalatTitikSesi.titikTidakAda => l10n.titikSesiGalatTidakAda,
      GalatTitikSesi.barisPenuh => l10n.titikSesiGalatBarisPenuh,
    };

/// Angka tanpa nol belakang — `-20`, bukan `-20.0`.
String teksNominal(double nilai) =>
    nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

/// Pengatur titik ukur SESI (set disimpan server, PRD §55).
///
/// Beda dari `PengaturTitik` lama: titik TIDAK PERNAH dihapus. Yang ada cuma
/// tambah, ubah nominal (selama belum ada pembacaan), nonaktifkan dengan
/// alasan (pembacaannya tetap tersimpan & terkirim apa adanya), dan aktifkan
/// lagi. Aturan yang sama ditegakkan server.
class PengaturTitikSesi extends StatelessWidget {
  const PengaturTitikSesi({
    super.key,
    required this.isian,
    required this.tabel,
    required this.onBerubah,
  });

  final LembarKerjaState isian;
  final TabelBatasTitik tabel;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final daftar = isian.titikSesiTabel(tabel.kode);
    final mode = isian.modeTitikSesi(tabel.kode);
    final bolehTambah = tabel.bolehTambah && mode != ModeBarisTitikSesi.tetap;
    final satuan = tabel.satuan ?? isian.bentuk.satuan;
    final aktif = daftar.where((t) => t.aktif).length;
    final pengulangan = tabel.pengulangan;
    final redup = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      key: ValueKey('pengatur-titik-sesi-${tabel.kode}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    satuan.isEmpty
                        ? l10n.titikSesiJudul
                        : l10n.titikSesiJudulSatuan(satuan),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (bolehTambah)
                  TextButton.icon(
                    key: const ValueKey('titik-sesi-tambah'),
                    onPressed: () => _tambah(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.titikSesiTambah),
                  ),
              ],
            ),
            Text(l10n.titikSesiKeterangan, style: redup),
            Text(l10n.titikSesiAktifRingkas(aktif, tabel.maks), style: redup),
            if (!bolehTambah && tabel.alasanTambah != null)
              Text(tabel.alasanTambah!, style: redup),
            if (!tabel.bolehNonaktif && tabel.alasanNonaktif != null)
              Text(tabel.alasanNonaktif!, style: redup),
            if (pengulangan != null)
              Text(
                pengulangan.dipatok
                    ? l10n.titikSesiPengulanganDipatok(pengulangan.min)
                    : l10n.titikSesiPengulangan(
                        isian.bentuk.jumlahPengulangan,
                        pengulangan.min,
                        pengulangan.maks,
                      ),
                style: redup,
              ),
            const SizedBox(height: AppSpacing.sm),
            if (daftar.isEmpty)
              Text(
                l10n.titikSesiKosong,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              for (final t in daftar) _barisTitik(context, t),
          ],
        ),
      ),
    );
  }

  Widget _barisTitik(BuildContext context, TitikSesi t) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final luarCmc = t.aktif && isian.titikSesi.diLuarCmc.contains(t.id);
    final terkunci = isian.titikSesi.pertamaTerkunci(t);
    final redup = theme.colorScheme.onSurfaceVariant;

    final keterangan = <String>[
      switch (t.asal) {
        AsalTitik.profil => l10n.titikSesiAsalProfil,
        AsalTitik.teknisi => l10n.titikSesiAsalTeknisi,
        AsalTitik.pelanggan => l10n.titikSesiAsalPelanggan,
      },
      if (t.denganSebelum) l10n.titikSesiFaseSebelumRingkas,
      if (terkunci) l10n.titikSesiTerkunciPertama,
      if (!t.aktif) l10n.titikSesiNonaktifLabel(t.alasan ?? '-'),
      if (t.aktif && t.asal == AsalTitik.pelanggan && t.alasan != null)
        t.alasan!,
      if (t.justifikasiCmc != null)
        l10n.titikSesiJustifikasiTerisi(t.justifikasiCmc!),
    ];

    return Opacity(
      key: ValueKey('titik-sesi-${t.id}'),
      opacity: t.aktif ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              t.aktif ? Icons.radio_button_checked : Icons.block,
              size: 18,
              color: t.aktif ? theme.colorScheme.primary : redup,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teksNominal(t.nominal),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: t.aktif ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    keterangan.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: redup),
                  ),
                  if (luarCmc)
                    Text(
                      t.justifikasiCmc == null
                          ? l10n.titikSesiDiLuarCmc
                          : l10n.titikSesiDiLuarCmcBerjustifikasi,
                      key: ValueKey('titik-sesi-cmc-${t.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.justifikasiCmc == null
                            ? theme.colorScheme.error
                            : redup,
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey('titik-sesi-menu-${t.id}'),
              tooltip: l10n.titikSesiAksi,
              onSelected: (aksi) => _aksi(context, t, aksi),
              itemBuilder: (_) => [
                if (t.aktif)
                  PopupMenuItem(value: 'ubah', child: Text(l10n.titikSesiUbah)),
                if (t.aktif)
                  PopupMenuItem(
                    value: 'nonaktif',
                    enabled: tabel.bolehNonaktif && !terkunci,
                    child: Text(l10n.titikSesiNonaktifkan),
                  )
                else
                  PopupMenuItem(
                    value: 'aktif',
                    child: Text(l10n.titikSesiAktifkan),
                  ),
                if (luarCmc || t.justifikasiCmc != null)
                  PopupMenuItem(
                    value: 'cmc',
                    child: Text(l10n.titikSesiJustifikasi),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _lapor(BuildContext context, GalatTitikSesi? galat) {
    if (galat == null) {
      onBerubah();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesanGalatTitikSesi(AppLocalizations.of(context), galat)),
      ),
    );
  }

  Future<void> _aksi(BuildContext context, TitikSesi t, String aksi) async {
    final l10n = AppLocalizations.of(context);
    final nominal = teksNominal(t.nominal);

    switch (aksi) {
      case 'ubah':
        final hasil = await showDialog<_HasilDialog>(
          context: context,
          builder: (_) => _DialogTitik(
            judul: l10n.titikSesiUbahJudul(nominal),
            satuan: tabel.satuan ?? '',
            awal: nominal,
          ),
        );
        if (hasil?.nominal == null || !context.mounted) return;
        _lapor(context, isian.ubahNominalTitikSesi(t.id, hasil!.nominal!));
      case 'nonaktif':
        final alasan = await showDialog<String>(
          context: context,
          builder: (_) => _DialogTeks(
            kunci: 'titik-sesi-alasan',
            judul: l10n.titikSesiNonaktifkanJudul(nominal),
            pesan: l10n.titikSesiNonaktifkanPesan,
            label: l10n.titikSesiAlasan,
            minimal: alasanTitikMinimal,
          ),
        );
        if (alasan == null || !context.mounted) return;
        _lapor(context, isian.nonaktifkanTitikSesi(t.id, alasan));
      case 'aktif':
        _lapor(context, isian.aktifkanTitikSesi(t.id));
      case 'cmc':
        final teks = await showDialog<String>(
          context: context,
          builder: (_) => _DialogTeks(
            kunci: 'titik-sesi-justifikasi',
            judul: l10n.titikSesiJustifikasiJudul(nominal),
            pesan: l10n.titikSesiDiLuarCmc,
            label: l10n.titikSesiJustifikasi,
            awal: t.justifikasiCmc,
            minimal: 0,
          ),
        );
        if (teks == null || !context.mounted) return;
        _lapor(context, isian.aturJustifikasiCmc(t.id, teks));
    }
  }

  Future<void> _tambah(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final hasil = await showDialog<_HasilDialog>(
      context: context,
      builder: (_) => _DialogTitik(
        judul: l10n.titikSesiTambahJudul,
        satuan: tabel.satuan ?? '',
        pilihAsal: true,
        bolehSebelum: tabel.bolehFaseSebelum,
      ),
    );
    final nominal = hasil?.nominal;
    if (nominal == null || !context.mounted) return;

    _lapor(
      context,
      isian.tambahTitikSesi(
        tabel: tabel.kode,
        nominal: nominal,
        asal: hasil!.asal,
        alasan: hasil.alasan,
        denganSebelum: hasil.denganSebelum,
      ),
    );
  }
}

class _HasilDialog {
  const _HasilDialog({
    this.nominal,
    this.asal = AsalTitik.teknisi,
    this.alasan,
    this.denganSebelum = false,
  });

  final double? nominal;
  final AsalTitik asal;
  final String? alasan;
  final bool denganSebelum;
}

/// Dialog nominal (+ asal & alasan untuk titik baru). Controller hidup
/// selama dialognya — lihat `_DialogAngka` di `pengatur_titik.dart`.
class _DialogTitik extends StatefulWidget {
  const _DialogTitik({
    required this.judul,
    required this.satuan,
    this.awal,
    this.pilihAsal = false,
    this.bolehSebelum = false,
  });

  final String judul;
  final String satuan;
  final String? awal;
  final bool pilihAsal;
  final bool bolehSebelum;

  @override
  State<_DialogTitik> createState() => _DialogTitikState();
}

class _DialogTitikState extends State<_DialogTitik> {
  late final _nominal = TextEditingController(text: widget.awal ?? '');
  final _alasan = TextEditingController();
  AsalTitik _asal = AsalTitik.teknisi;
  bool _sebelum = false;
  String? _galat;

  @override
  void dispose() {
    _nominal.dispose();
    _alasan.dispose();
    super.dispose();
  }

  void _simpan() {
    final l10n = AppLocalizations.of(context);
    final n = angkaTitikSesi(_nominal.text);
    if (n == null) {
      setState(() => _galat = l10n.titikSesiGalatAngka);
      return;
    }
    if (_asal == AsalTitik.pelanggan &&
        _alasan.text.trim().length < alasanTitikMinimal) {
      setState(() => _galat = l10n.titikSesiGalatAlasanPelanggan);
      return;
    }
    Navigator.of(context).pop(
      _HasilDialog(
        nominal: n,
        asal: _asal,
        alasan: _alasan.text.trim().isEmpty ? null : _alasan.text.trim(),
        denganSebelum: _sebelum,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.judul),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('titik-sesi-nominal'),
            controller: _nominal,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
            ],
            decoration: InputDecoration(
              labelText: widget.satuan.isEmpty
                  ? l10n.titikSesiNominal
                  : l10n.titikSesiNominalSatuan(widget.satuan),
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.pilihAsal) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<AsalTitik>(
              segments: [
                ButtonSegment(
                  value: AsalTitik.teknisi,
                  label: Text(l10n.titikSesiAsalTeknisi),
                ),
                ButtonSegment(
                  value: AsalTitik.pelanggan,
                  label: Text(l10n.titikSesiAsalPelanggan),
                ),
              ],
              selected: {_asal},
              onSelectionChanged: (s) => setState(() => _asal = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('titik-sesi-alasan-tambah'),
              controller: _alasan,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _asal == AsalTitik.pelanggan
                    ? l10n.titikSesiAlasanPelanggan
                    : l10n.titikSesiAlasanOpsional,
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.bolehSebelum)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sebelum,
                onChanged: (v) => setState(() => _sebelum = v ?? false),
                title: Text(l10n.titikSesiDenganSebelum),
              ),
          ],
          if (_galat != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _galat!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.titikSesiBatal),
        ),
        FilledButton(
          key: const ValueKey('titik-sesi-simpan'),
          onPressed: _simpan,
          child: Text(l10n.titikSesiSimpan),
        ),
      ],
    );
  }
}

/// Dialog satu teks wajib (alasan / justifikasi).
class _DialogTeks extends StatefulWidget {
  const _DialogTeks({
    required this.kunci,
    required this.judul,
    required this.pesan,
    required this.label,
    required this.minimal,
    this.awal,
  });

  final String kunci;
  final String judul;
  final String pesan;
  final String label;
  final int minimal;
  final String? awal;

  @override
  State<_DialogTeks> createState() => _DialogTeksState();
}

class _DialogTeksState extends State<_DialogTeks> {
  late final _ctl = TextEditingController(text: widget.awal ?? '');
  String? _galat;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_ctl.text.trim().length < widget.minimal) {
      setState(
        () => _galat = AppLocalizations.of(context).titikSesiGalatAlasanPendek,
      );
      return;
    }
    Navigator.of(context).pop(_ctl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.judul),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.pesan),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey(widget.kunci),
            controller: _ctl,
            autofocus: true,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _galat,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.titikSesiBatal),
        ),
        FilledButton(
          key: ValueKey('${widget.kunci}-simpan'),
          onPressed: _simpan,
          child: Text(l10n.titikSesiSimpan),
        ),
      ],
    );
  }
}
