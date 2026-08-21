import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../lembar_kerja_state.dart';

/// Pengatur daftar titik ukur, buat lembar yang `titik_bisa_diubah`.
///
/// ## Kenapa panel terpisah, bukan tombol di dalam tabelnya
///
/// Tabel hasil itu grid berlebar terukur — lebar tiap sel dihitung dari jumlah
/// kolom & pengulangan, dan kepala kolomnya dipatok tinggi supaya sebaris sama
/// kolom label yang nempel di kiri. Menyisipkan tombol hapus per baris berarti
/// ikut menghitung ulang semua itu, dan yang paling mungkin pecah justru lembar
/// alat LAIN yang nggak ada hubungannya sama fitur ini.
///
/// Di panel terpisah, tabelnya nggak disentuh sama sekali. Lagipula daftar titik
/// berlaku buat KEDUA tabel (Before & After) sekaligus — menaruhnya di dalam
/// salah satu tabel bakal bikin seolah-olah tiap tahap punya titik sendiri.
///
/// ## Cuma TITS yang memakainya
///
/// Sepuluh alat lain titiknya konstanta: pH 4/7/10, gas 101/25/50/17,9. Di TITS
/// rentang alat pelanggan beda-beda — sesi contoh masternya −20…1000 sembilan
/// titik dan 0…1200 delapan titik — jadi baris yang datang dari backend cuma
/// SARAN.
class PengaturTitik extends StatelessWidget {
  const PengaturTitik({
    super.key,
    required this.isian,
    required this.onBerubah,
  });

  final LembarKerjaState isian;

  /// Dipanggil sesudah daftar titik berubah. Tabelnya dibangun ulang di
  /// [LembarKerjaState.aturTitik]; ini yang bikin layarnya ikut gambar ulang.
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titik = isian.titikBerlaku;
    final satuan = isian.bentuk.satuan;

    return Card(
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
                    satuan.isEmpty ? 'Titik Ukur' : 'Titik Ukur ($satuan)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _tambah(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            Text(
              'Titik bawaan cuma saran — sesuaikan sama rentang alat yang '
              'dikalibrasi. Angka yang dihapus ikut ngosongin kolom '
              'pembacaannya.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (titik.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Belum ada titik. Tekan Tambah buat mulai.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final t in titik)
                    InputChip(
                      label: Text(_teks(t)),
                      onPressed: () => _ubah(context, t),
                      onDeleted: () => _hapus(t),
                      deleteButtonTooltipMessage: 'Hapus titik ${_teks(t)}',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Angka tanpa nol belakang yang bikin ramai — `-20`, bukan `-20.0`.
  String _teks(double nilai) =>
      nilai == nilai.roundToDouble() ? '${nilai.toInt()}' : '$nilai';

  Future<void> _tambah(BuildContext context) async {
    final nilai = await _tanyaAngka(context, judul: 'Tambah titik');
    if (nilai == null) return;

    isian.aturTitik([...isian.titikBerlaku, nilai]);
    onBerubah();
  }

  Future<void> _ubah(BuildContext context, double lama) async {
    final nilai = await _tanyaAngka(
      context,
      judul: 'Ubah titik ${_teks(lama)}',
      awal: _teks(lama),
    );
    if (nilai == null) return;

    isian.aturTitik([
      for (final t in isian.titikBerlaku)
        if (t == lama) nilai else t,
    ]);
    onBerubah();
  }

  void _hapus(double nilai) {
    isian.aturTitik([
      for (final t in isian.titikBerlaku)
        if (t != nilai) t,
    ]);
    onBerubah();
  }

  /// Kotak isian satu angka. Balik `null` kalau dibatalkan ATAU angkanya nggak
  /// kebaca — bukan 0: titik 0 °C itu titik yang sah (sesi source master mulai
  /// dari situ), jadi nggak boleh dipakai sebagai penanda gagal.
  Future<double?> _tanyaAngka(
    BuildContext context, {
    required String judul,
    String? awal,
  }) => showDialog<double>(
    context: context,
    builder: (_) => _DialogAngka(
      judul: judul,
      awal: awal,
      satuan: isian.bentuk.satuan,
    ),
  );
}

/// Dialog satu angka, dengan controller yang hidup selama dialognya.
///
/// StatefulWidget, bukan controller lokal di `showDialog`: controller yang
/// di-dispose tepat sesudah `showDialog` selesai masih dipakai TextField-nya
/// selagi dialognya beranimasi menutup, dan itu melempar
/// "A TextEditingController was used after being disposed" — bukan crash
/// diam-diam, tapi cukup untuk merusak frame berikutnya.
class _DialogAngka extends StatefulWidget {
  const _DialogAngka({
    required this.judul,
    required this.satuan,
    this.awal,
  });

  final String judul;
  final String satuan;
  final String? awal;

  @override
  State<_DialogAngka> createState() => _DialogAngkaState();
}

class _DialogAngkaState extends State<_DialogAngka> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.awal ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Koma diterima sebagai desimal — itu yang diketik teknisi di keyboard
  /// Indonesia, dan `double.tryParse` nggak mengenalinya.
  double? _parse(String teks) =>
      double.tryParse(teks.trim().replaceAll(',', '.'));

  void _simpan() => Navigator.of(context).pop(_parse(_controller.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        // Titik di bawah nol dipakai beneran — sesi measure master mulai dari
        // −20 °C — jadi tanda minus wajib lolos.
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
        ],
        decoration: InputDecoration(
          labelText: widget.satuan.isEmpty ? 'Nilai' : 'Nilai (${widget.satuan})',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _simpan(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _simpan, child: const Text('Simpan')),
      ],
    );
  }
}
