import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/perhitungan.dart';
import '../../../models/standard.dart';
import '../../../providers/calibration_input_provider.dart';
import '../../../providers/perhitungan_provider.dart';
import 'tabel_perhitungan.dart' show formatAngka;

/// Blok "PERHITUNGAN KONDISI LINGKUNGAN" — dua baris (Suhu Ruangan &
/// Kelembaban) dengan sembilan kolom, persis sheet PERHITUNGAN.
///
/// Teknisi cuma nyatet DUA angka per parameter (awal & akhir kerja); sisanya
/// dihitung backend. Yang bikin kolom Correction & U95% kosong itu cuma satu
/// hal: **thermohygro-nya belum dipilih admin** — makanya pickernya ditaruh
/// langsung di blok ini, bukan di layar pengaturan terpisah.
class BlokKondisi extends ConsumerWidget {
  const BlokKondisi({
    super.key,
    required this.kondisi,
    required this.calibrationId,
  });

  final KondisiLingkungan kondisi;
  final int calibrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.perhitKondisi,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: AppSpacing.lg),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BarisKepala(),
                  if (kondisi.suhu != null)
                    _Baris(label: l10n.perhitSuhuRuangan, baris: kondisi.suhu!),
                  if (kondisi.kelembaban != null)
                    _Baris(
                      label: l10n.perhitKelembaban,
                      baris: kondisi.kelembaban!,
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            _PilihThermohygro(
              kondisi: kondisi,
              calibrationId: calibrationId,
            ),
          ],
        ),
      ),
    );
  }
}

const _lebarLabel = 116.0;
const _lebarKolom = 92.0;

class _BarisKepala extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final kolom = [
      l10n.perhitAwal,
      l10n.perhitAkhir,
      l10n.perhitAverage,
      l10n.perhitIndexed,
      l10n.perhitCorrection,
      l10n.perhitDelta,
      l10n.perhitU95Std,
      l10n.perhitU95Sertifikat,
    ];

    return Row(
      children: [
        const SizedBox(width: _lebarLabel),
        for (final k in kolom)
          SizedBox(
            width: _lebarKolom,
            child: Text(
              k,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.baris});

  final String label;
  final BarisKondisi baris;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nilai = [
      baris.awal,
      baris.akhir,
      baris.average,
      baris.indexedValue,
      baris.correction,
      baris.delta,
      baris.u95StdTh,
      baris.u95Sertifikat,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: _lebarLabel,
            child: Text(
              '$label (${baris.satuan})',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final n in nilai)
            SizedBox(
              width: _lebarKolom,
              child: Text(
                // Strip = belum bisa dihitung, bukan nol. Bedanya penting:
                // koreksi 0 itu hasil pengukuran, koreksi kosong itu data
                // sertifikat thermohygro yang belum diisi.
                n == null ? '—' : formatAngka(n),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Thermohygro Used" — kolom administratif (`PATCH /calibrations/{id}/admin`).
///
/// Begitu dipilih, koreksi & U95% di dua baris atas **langsung ikut terhitung**
/// di server, jadi perhitungannya dimuat ulang sesudah simpan.
class _PilihThermohygro extends ConsumerStatefulWidget {
  const _PilihThermohygro({
    required this.kondisi,
    required this.calibrationId,
  });

  final KondisiLingkungan kondisi;
  final int calibrationId;

  @override
  ConsumerState<_PilihThermohygro> createState() => _PilihThermohygroState();
}

class _PilihThermohygroState extends ConsumerState<_PilihThermohygro> {
  bool _sibuk = false;

  Future<void> _simpan(int standardId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);
    try {
      await ref
          .read(aksiAdminProvider(widget.calibrationId))
          .simpanKolomAdmin(thermohygroStandardId: standardId);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.perhitAdminTersimpan)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final standarAsync = ref.watch(standardListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        standarAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) {
            // Cuma standar yang punya `parameter_kondisi` yang berguna di
            // sini — sisanya nggak akan ngasih koreksi apa pun.
            final thermohygro = list
                .where((s) => s.punyaParameterKondisi)
                .toList();

            return DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.perhitPilihThermohygro,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              hint: Text(widget.kondisi.thermohygro ?? l10n.lkPilih),
              items: [
                for (final Standard s in thermohygro)
                  DropdownMenuItem(
                    value: s.id,
                    enabled: s.masihBerlaku,
                    child: Text(
                      s.masihBerlaku
                          ? s.nama
                          : '${s.nama} (${l10n.lkStandarKadaluarsa})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _sibuk ? null : (v) => v == null ? null : _simpan(v),
            );
          },
        ),
        if (widget.kondisi.thermohygroBelumDipilih) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.perhitThermohygroKosong,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
