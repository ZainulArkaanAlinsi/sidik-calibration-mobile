import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/utils/angka.dart';
import '../l10n/app_localizations.dart';
import '../models/enclosure_sertifikat.dart';

/// Hasil sertifikat Enclosure — A) Sebaran Suhu & B) Kinerja Enklosur, dengan
/// susunan yang sama persis dengan `sertifikat/pdf.blade.php` (cabang
/// `$enclosure`): layar ini dipakai mencocokkan dengan PDF sebelum dokumennya
/// dikirim ke pelanggan.
///
/// **Nol perhitungan.** Angka presisi penuh dari snapshot, dibulatkan di sini
/// dengan desimal yang ikut dibekukan di snapshot.
class EnclosureSertifikatPanel extends StatelessWidget {
  const EnclosureSertifikatPanel({super.key, required this.enclosure});

  final EnclosureSertifikat enclosure;

  String _n(double? v, int desimal) => v == null
      ? '—'
      : formatSertifikat(v, desimal, tandaNol: enclosure.tandaNol);

  /// Faktor cakupan seperti PDF: `desimal_k` tetap, atau paling banyak 2
  /// desimal dengan nol belakang dibuang kalau server tidak menyebutnya.
  String _k(double k) {
    final d = enclosure.desimalK;
    if (d != null) return formatSertifikat(k, d);
    return formatNilai(k, desimalMaks: 2).replaceFirst('.', ',');
  }

  /// Teks Sensor Acuan di kepala kolom sensor. Acuan bisa bergeser per set
  /// point (termokopel bernomor terkecil kosong) — kalau begitu, disebut per
  /// set point, bukan "No. 1" yang jadi pernyataan salah.
  String _teksAcuan(AppLocalizations l10n) {
    final sp = enclosure.setPoint;
    final acuan = {
      for (final s in sp)
        if (s.posisiAcuan != null) s.posisiAcuan!,
    };
    if (acuan.length <= 1) {
      return l10n.sertEncAcuanSatu('${acuan.isEmpty ? 1 : acuan.first}');
    }
    return l10n.sertEncAcuanPerSetPoint(
      sp.map((s) => s.posisiAcuan?.toString() ?? '—').join(' / '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final satuan = enclosure.satuan ?? '°C';
    final d = enclosure.desimal;
    final posisi = enclosure.posisi;
    final sp = enclosure.setPoint;

    final kSemua = [
      for (final s in sp)
        if (s.faktorCakupanK != null) s.faktorCakupanK!,
    ];
    final kTeks = kSemua.map(_k).toSet();

    Widget sel(String teks, {bool tebal = false, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: (tebal ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(fontWeight: tebal ? FontWeight.w700 : null),
      ),
    );

    Widget judul(String teks) => Text(
      teks,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );

    Widget tabel(List<TableRow> baris) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: theme.dividerColor),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: baris,
      ),
    );

    // Kolom posisi kosong tetap satu kolom strip — sama dengan `@empty` PDF.
    final kolomPosisi = posisi.isEmpty ? 1 : posisi.length;

    return Card(
      key: const ValueKey('panel-enclosure-sertifikat'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            judul(l10n.sertEncJudulA),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.sertEncSensorNo(_teksAcuan(l10n)),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            tabel([
              TableRow(
                children: [
                  sel(l10n.sertEncIndikator(satuan), tebal: true),
                  sel(l10n.sertEncStandarKoreksi(satuan), tebal: true),
                  for (var i = 0; i < kolomPosisi; i++)
                    sel(
                      posisi.isEmpty ? '—' : '${posisi[i].posisi}',
                      tebal: true,
                    ),
                  sel(l10n.sertEncU95(satuan), tebal: true),
                ],
              ),
              for (final s in sp) ...[
                TableRow(
                  children: [
                    sel(_n(s.indikator, d)),
                    sel(l10n.sertEncTerukur(satuan)),
                    for (var i = 0; i < kolomPosisi; i++)
                      sel(_n(s.sensorDi(i)?.terukur, d)),
                    sel(_n(s.u95, enclosure.desimalU95)),
                  ],
                ),
                TableRow(
                  children: [
                    // Sel gabungan (rowspan) di PDF — di sini dikosongkan.
                    sel(''),
                    sel(l10n.sertEncKoreksi(satuan)),
                    for (var i = 0; i < kolomPosisi; i++)
                      sel(_n(s.sensorDi(i)?.koreksi, d)),
                    sel(''),
                  ],
                ),
              ],
            ]),
            if (kSemua.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              // Satu kalimat seperti master (`SERTIFIKAT!P37` = k set point
              // pertama); `≈` kalau k set point lain beda di presisi cetak.
              Text(
                l10n.sertEncKalimatK(
                  kTeks.length > 1 ? '≈' : '=',
                  _k(kSemua.first),
                ),
                key: const ValueKey('kalimat-k-enclosure'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            judul(l10n.sertEncJudulB),
            const SizedBox(height: AppSpacing.xs),
            tabel([
              TableRow(
                children: [
                  sel(l10n.sertEncSuhuSetting(satuan), tebal: true),
                  sel(l10n.sertEncSuhuIndikator(satuan), tebal: true),
                  sel(l10n.sertEncKeseragaman(satuan), tebal: true),
                  sel(l10n.sertEncKestabilan(satuan), tebal: true),
                  sel(l10n.sertEncVariasi(satuan), tebal: true),
                ],
              ),
              for (final s in sp)
                TableRow(
                  children: [
                    sel(_n(s.setPoint, d)),
                    sel(_n(s.indikator, d)),
                    sel(_n(s.keseragaman, d)),
                    sel(_n(s.kestabilan, d)),
                    sel(_n(s.variasiKeseluruhan, d)),
                  ],
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
