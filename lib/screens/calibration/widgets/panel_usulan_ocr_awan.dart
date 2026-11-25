import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_ukuran.dart';
import '../../../models/usulan_ocr_awan.dart';
import '../lembar_kerja_state.dart' show kuningPerluDicek;
import 'teks_ocr_awan.dart';

/// Gaya tombol 48 dp seukuran isi (tema memaksa tombol selebar ruang, salah di
/// dalam `Wrap`). Sama dengan `_gayaTombolCek` di `tanda_cek_sel.dart`.
const _gayaTombol = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, AppUkuran.sasaranSentuh)),
);

/// Layar usulan hasil OCR awan per sel (gerbang 3, DRAF menunggu persetujuan
/// tampilan).
///
/// Widget ini TIDAK menyimpan keadaan papan dan TIDAK memanggil jaringan;
/// pemanggil memegang [PapanUsulanAwan] dan menukarnya tiap callback.
///
/// Aturan yang dijaga di tampilan:
///  - Tidak ada tombol "pakai semua": tiap callback menyangkut SATU kunci.
///  - Tidak ada warna hijau dan tidak ada kata "terverifikasi": tulisan tangan
///    tidak pernah hijau. Belum diputuskan = kuning + ikon peringatan; sudah
///    diputuskan = warna utama + ikon centang (bukan hijau).
///  - `teks_awan` dan `teks_normal` berdampingan bila berbeda.
///  - Alasan dalam kalimat manusia ([TeksOcrAwan.alasan]), bukan kode mentah.
///  - Semua teks lewat l10n ([TeksOcrAwan]); tidak ada string di berkas ini.
///  - Nilai yang tampil tidak dibulatkan atau dihitung ulang.
///
/// Dipasang di `FotoReviewScreen`, dan hanya tampil sesudah teknisi menekan
/// "Minta usulan awan" (tombol itu sendiri hanya ada bila sakelar klien,
/// izin, dan sakelar server mengizinkan). Titik masuknya sejak kontrak 22B
/// adalah potongan sel yang diunggah HP, bukan `scan_id`.
class PanelUsulanOcrAwan extends StatelessWidget {
  const PanelUsulanOcrAwan({
    super.key,
    required this.papan,
    required this.labelSel,
    required this.onPakai,
    required this.onUbah,
    required this.onTolak,
    required this.onKembalikan,
  });

  final PapanUsulanAwan papan;

  /// Nama sel yang dikenal teknisi (mis. "Set Point 7,00 · Ulangan 2"). Kunci
  /// server tidak ditampilkan mentah.
  final String Function(String kunci) labelSel;

  final void Function(String kunci) onPakai;
  final void Function(String kunci, String teks) onUbah;
  final void Function(String kunci) onTolak;
  final void Function(String kunci) onKembalikan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = TeksOcrAwan.dari(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.judul, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(t.penjelasan, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          t.sisa(papan.jumlahMenunggu),
          key: const ValueKey('usulan-sisa'),
          style: theme.textTheme.labelLarge,
        ),
        if (papan.sebagian) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(t.sebagian, style: theme.textTheme.bodySmall),
        ],
        if (papan.dilewati.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            t.dilewati(papan.dilewati.length),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final u in papan.usulan) ...[
          _KartuUsulan(
            key: ValueKey('usulan-${u.kunci}'),
            usulan: u,
            label: labelSel(u.kunci),
            onPakai: () => onPakai(u.kunci),
            onUbah: (teks) => onUbah(u.kunci, teks),
            onTolak: () => onTolak(u.kunci),
            onKembalikan: () => onKembalikan(u.kunci),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (papan.tanpaUsulan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(t.judulTanpaUsulan, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final s in papan.tanpaUsulan)
            _BarisTanpaUsulan(
              key: ValueKey('tanpa-usulan-${s.kunci}'),
              sel: s,
              label: labelSel(s.kunci),
            ),
        ],
      ],
    );
  }
}

class _KartuUsulan extends StatefulWidget {
  const _KartuUsulan({
    super.key,
    required this.usulan,
    required this.label,
    required this.onPakai,
    required this.onUbah,
    required this.onTolak,
    required this.onKembalikan,
  });

  final UsulanSelAwan usulan;
  final String label;
  final VoidCallback onPakai;
  final void Function(String teks) onUbah;
  final VoidCallback onTolak;
  final VoidCallback onKembalikan;

  @override
  State<_KartuUsulan> createState() => _KartuUsulanState();
}

class _KartuUsulanState extends State<_KartuUsulan> {
  final _isian = TextEditingController();
  bool _mengubah = false;

  @override
  void dispose() {
    _isian.dispose();
    super.dispose();
  }

  bool get _isianSah => bacaAngkaUsulan(_isian.text) != null;

  void _mulaiUbah() => setState(() {
    _isian.text = widget.usulan.teksUsulan;
    _isian.selection = TextSelection.collapsed(offset: _isian.text.length);
    _mengubah = true;
  });

  void _simpan() {
    if (!_isianSah) return;
    widget.onUbah(_isian.text);
    setState(() => _mengubah = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = TeksOcrAwan.dari(context);
    final u = widget.usulan;
    final dua = u.duaBentuk;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: u.perluDicek
              ? kuningPerluDicek
              : theme.colorScheme.outlineVariant,
          width: u.perluDicek ? AppUkuran.garisTebal : AppUkuran.garis,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.label, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(width: AppSpacing.sm),
                _Status(keputusan: u.keputusan),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (dua != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Bentuk(
                      judul: t.labelAwan,
                      nilai: dua.awan,
                      kunci: const ValueKey('bentuk-awan'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Bentuk(
                      judul: t.labelNormal,
                      nilai: dua.normal,
                      kunci: const ValueKey('bentuk-normal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(t.duaBentukBeda, style: theme.textTheme.bodySmall),
            ] else
              _Bentuk(
                judul: t.labelUsulan,
                nilai: u.teksUsulan,
                kunci: const ValueKey('bentuk-usulan'),
              ),
            for (final kode in u.sel.alasan) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: AppUkuran.ikonSebaris,
                    color: kuningPerluDicek,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      t.alasan(kode),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (_mengubah) _bentukUbah(theme) else _aksi(theme, u),
          ],
        ),
      ),
    );
  }

  Widget _aksi(ThemeData theme, UsulanSelAwan u) {
    final t = TeksOcrAwan.dari(context);
    final k = u.kunci;

    if (u.perluDicek) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          FilledButton(
            key: ValueKey('usulan-pakai-$k'),
            style: _gayaTombol,
            onPressed: widget.onPakai,
            child: Text(t.pakai),
          ),
          OutlinedButton(
            key: ValueKey('usulan-ubah-$k'),
            style: _gayaTombol,
            onPressed: _mulaiUbah,
            child: Text(t.ubah),
          ),
          TextButton(
            key: ValueKey('usulan-tolak-$k'),
            style: _gayaTombol,
            onPressed: widget.onTolak,
            child: Text(t.tolak),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (u.terkonfirmasi)
          Expanded(
            child: Text(
              t.nilaiPegangan(u.teksFinal!),
              key: ValueKey('usulan-nilai-$k'),
              style: theme.textTheme.titleSmall,
            ),
          )
        else
          const Spacer(),
        TextButton(
          key: ValueKey('usulan-kembalikan-$k'),
          style: _gayaTombol,
          onPressed: widget.onKembalikan,
          child: Text(t.batalkan),
        ),
      ],
    );
  }

  Widget _bentukUbah(ThemeData theme) {
    final t = TeksOcrAwan.dari(context);
    final k = widget.usulan.kunci;
    final salah = _isian.text.trim().isNotEmpty && !_isianSah;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('usulan-isian-$k'),
          controller: _isian,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-.,]')),
          ],
          decoration: InputDecoration(
            labelText: t.labelIsian,
            errorText: salah ? t.galatIsian : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _simpan(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              key: ValueKey('usulan-simpan-$k'),
              style: _gayaTombol,
              onPressed: _isianSah ? _simpan : null,
              child: Text(t.simpan),
            ),
            TextButton(
              key: ValueKey('usulan-batal-$k'),
              style: _gayaTombol,
              onPressed: () => setState(() => _mengubah = false),
              child: Text(t.batal),
            ),
          ],
        ),
      ],
    );
  }
}

/// Satu bentuk teks + judul kecilnya. Angka tidak diubah sedikit pun.
class _Bentuk extends StatelessWidget {
  const _Bentuk({
    required this.judul,
    required this.nilai,
    required this.kunci,
  });

  final String judul;
  final String nilai;
  final Key kunci;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(judul, style: theme.textTheme.bodySmall),
        Text(nilai, key: kunci, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

/// Penanda keputusan: ikon + kata, bukan warna saja, dan tidak pernah hijau.
class _Status extends StatelessWidget {
  const _Status({required this.keputusan});

  final KeputusanUsulan keputusan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = TeksOcrAwan.dari(context);

    final (IconData ikon, String teks, Color warna) = switch (keputusan) {
      KeputusanUsulan.menunggu => (
        Icons.warning_amber_rounded,
        t.perluDicek,
        kuningPerluDicek,
      ),
      KeputusanUsulan.dipakai => (
        Icons.check_circle_outline,
        t.dipakai,
        theme.colorScheme.primary,
      ),
      KeputusanUsulan.diubah => (
        Icons.edit_outlined,
        t.diubah,
        theme.colorScheme.primary,
      ),
      KeputusanUsulan.ditolak => (
        Icons.block,
        t.ditolak,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: teks,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: AppUkuran.ikonSebaris, color: warna),
            const SizedBox(width: AppSpacing.xs),
            Text(
              teks,
              key: const ValueKey('usulan-status'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisTanpaUsulan extends StatelessWidget {
  const _BarisTanpaUsulan({super.key, required this.sel, required this.label});

  final SelTanpaUsulanAwan sel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = TeksOcrAwan.dari(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          Text(
            t.tanpaUsulan(sel.sebab),
            style: theme.textTheme.bodySmall,
          ),
          for (final kode in sel.alasan)
            Text(t.alasan(kode), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
