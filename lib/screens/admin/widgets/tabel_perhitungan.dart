import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/angka.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/perhitungan.dart';

/// Angka lembar perhitungan ditampilkan **apa adanya dari server** — nggak ada
/// pembulatan, dan nggak ada operasi aritmetika di file ini. Yang diatur cuma
/// berapa desimal yang kelihatan biar muat di kolom sempit.
///
/// Delegasi ke [formatNilai]: `desimalMin` = resolusi titik (nol belakang di
/// bawahnya DIPERTAHANKAN → "4,60" bukan "4,6"), `maksDesimal` = batas atas biar
/// nilai presisi penuh (`4.0092251999999995`) nggak makan selebar layar.
String formatAngka(double n, {int maksDesimal = 4, int desimalMin = 0}) =>
    formatNilai(n, desimalMin: desimalMin, desimalMaks: maksDesimal);

/// Satu tabel "DATA HASIL KALIBRASI" (Before / After adjustment).
///
/// Susunannya persis sheet PERHITUNGAN: **kolom = titik ukur**, header-nya
/// nilai `Standard`, isinya Repeat 1..n (pH & °C), lalu ditutup baris
/// **Average**, **Correction**, **STDEV**, dan **MAX STDEV**.
///
/// Perhatikan: ini KEBALIKAN dari lembar kerja teknisi, yang barisnya titik
/// ukur dan kolomnya Repeat. Bukan kesalahan — dua dokumen itu memang beda
/// susunannya, dan yang dicontek di sini sheet PERHITUNGAN-nya.
class TabelPerhitunganWidget extends StatelessWidget {
  const TabelPerhitunganWidget({super.key, required this.tabel});

  final TabelPerhitungan tabel;

  static const _lebarLabel = 96.0;
  static const _lebarKolom = 108.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (tabel.titik.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tabel.judul,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nilai Standard per titik. BUKAN nilai nominal —
              // ini nilai buffer pada suhu larutan saat itu.
              _Baris(
                label: l10n.perhitStandard,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.standard == null
                        ? '—'
                        : formatAngka(t.standard!, maksDesimal: 7, desimalMin: t.desimal ?? 0),
                ],
              ),
              _Baris(
                label: '',
                kecil: true,
                sel: [for (final t in tabel.titik) t.satuan ?? ''],
              ),
              const Divider(height: AppSpacing.md),

              for (var r = 0; r < tabel.jumlahPengulangan; r++)
                _Baris(
                  label: '${l10n.perhitRepeat} ${r + 1}',
                  sel: [
                    for (final t in tabel.titik)
                      r < t.pembacaan.length ? _sel(t.pembacaan[r], t.desimal) : '—',
                  ],
                ),

              const Divider(height: AppSpacing.md),
              _Baris(
                label: l10n.perhitAverage,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.average == null
                        ? '—'
                        : '${formatAngka(t.average!, desimalMin: t.desimal ?? 0)}'
                              '${t.averageSuhu == null ? '' : '  ·  ${formatAngka(t.averageSuhu!)} °C'}',
                ],
              ),
              _Baris(
                label: l10n.perhitCorrection,
                tebal: true,
                sel: [
                  for (final t in tabel.titik)
                    t.correction == null
                        ? '—'
                        : formatAngka(t.correction!, maksDesimal: 7),
                ],
              ),
              _Baris(
                label: l10n.perhitStdev,
                sel: [
                  for (final t in tabel.titik)
                    t.stdev == null
                        ? '—'
                        : formatAngka(t.stdev!, maksDesimal: 7),
                ],
              ),
            ],
          ),
        ),

        if (tabel.maxStdev != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${l10n.perhitMaxStdev}: ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatAngka(tabel.maxStdev!, maksDesimal: 7),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _sel(PembacaanPerhitungan p, int? desimal) {
    final nilai = formatAngka(p.nilai, desimalMin: desimal ?? 0);
    final suhu = p.suhu;
    return suhu == null ? nilai : '$nilai  ·  ${formatAngka(suhu)} °C';
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.sel,
    this.tebal = false,
    this.kecil = false,
  });

  final String label;
  final List<String> sel;
  final bool tebal;
  final bool kecil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaya = kecil
        ? theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodySmall?.copyWith(
            fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: TabelPerhitunganWidget._lebarLabel,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          for (final s in sel)
            SizedBox(
              width: TabelPerhitunganWidget._lebarKolom,
              child: Text(s, textAlign: TextAlign.center, style: gaya),
            ),
        ],
      ),
    );
  }
}
