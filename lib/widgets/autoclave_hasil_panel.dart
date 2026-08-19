import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/utils/angka.dart';
import '../models/autoclave_hasil.dart';

/// Panel hasil olah data Autoklaf — Section A (Sebaran Suhu), B (Kinerja),
/// C (Tekanan). Dipakai di tiga tempat yang harus tampil SAMA: layar input
/// (preview), detail riwayat sesi, dan layar sertifikat. Satu widget biar
/// angka yang dilihat teknisi = yang di sertifikat = yang di PDF.
///
/// **Nggak ada rumus di sini.** Semua angka dari backend (`AutoclaveCalculator`);
/// widget cuma memformat buat tampilan (suhu 2 desimal, tekanan 4 — ikut master).
class AutoclaveHasilPanel extends StatelessWidget {
  const AutoclaveHasilPanel({super.key, required this.hasil, this.judul});

  final AutoclaveHasil hasil;

  /// Judul opsional di atas panel (mis. "Hasil Olah Data"). Null = tanpa judul.
  final String? judul;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (judul != null) ...[
          Text(judul!, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (hasil.suhu != null) _kartuSuhu(context, hasil.suhu!),
        if (hasil.suhu != null) const SizedBox(height: AppSpacing.md),
        if (hasil.tekanan != null) _kartuTekanan(context, hasil.tekanan!),
      ],
    );
  }

  Widget _kartuSuhu(BuildContext context, AutoclaveSuhu s) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A) Sebaran Suhu', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Table(
              border: TableBorder.all(color: theme.dividerColor),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _barisTabel(
                    ['Sensor', 'Std Terkoreksi', 'Koreksi', 'ΔT'],
                    header: true),
                for (final sen in s.sensor)
                  _barisTabel([
                    '${sen.no}',
                    _f(sen.standarTerkoreksi, 3),
                    _f(sen.koreksi, 3),
                    _f(sen.deltaT, 3),
                  ]),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('B) Kinerja Autoklaf', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _kv('Suhu Indikator (rata)', _f(s.indikatorRata, 2), '°C'),
            _kv('Kestabilan (SS)', _f(s.kestabilan, 3), '°C'),
            _kv('Keseragaman (KS)', _f(s.keseragaman, 3), '°C'),
            _kv('Variasi Keseluruhan (VK)', _f(s.variasi, 3), '°C'),
            const Divider(),
            _kv('U95%', '± ${_f(s.u95, 4)}', '°C', tebal: true),
            _kv('Faktor cakupan (k)', _f(s.k, 4), ''),
          ],
        ),
      ),
    );
  }

  Widget _kartuTekanan(BuildContext context, AutoclaveTekanan t) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('C) Tekanan (${t.satuan})', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _kv('UUT Setting', _f(t.uutSetting, 4), t.satuan),
            _kv('Standard Value', _f(t.standarTerkoreksi, 4), t.satuan),
            _kv('Correction', _f(t.koreksi, 4), t.satuan),
            const Divider(),
            _kv('U95%', '± ${_f(t.u95, 4)}', t.satuan, tebal: true),
            _kv('Faktor cakupan (k)', _f(t.k, 4), ''),
          ],
        ),
      ),
    );
  }

  TableRow _barisTabel(List<String> sel, {bool header = false}) {
    return TableRow(
      children: [
        for (final s in sel)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(s,
                style: header
                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                    : const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _kv(String k, String v, String satuan, {bool tebal = false}) {
    final gaya = tebal ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(k, style: gaya)),
          Text(satuan.isEmpty ? v : '$v $satuan', style: gaya),
        ],
      ),
    );
  }
}

/// Format angka hasil buat tampilan; null jadi "—". Nol belakang dipertahankan
/// sampai [desimal] (ikut gaya sertifikat lab).
String _f(double? v, int desimal) =>
    v == null ? '—' : formatNilai(v, desimalMin: desimal, desimalMaks: desimal);
