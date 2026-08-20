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
import '../../auth/widgets/neu.dart';

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
    final l10n = AppLocalizations.of(context);

    return NeuRaised(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul blok disamain persis sama `_Blok` di layar Perhitungan:
          // huruf kecil beraksen + garis tipis dari bayangan, bukan Divider
          // Material yang kelihatan kayak garis nempel.
          Text(
            l10n.perhitKondisi.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: NeuColors.of(context).accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 1,
            color: NeuColors.of(context).darkShadow.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpacing.sm),

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
          _PilihThermohygro(kondisi: kondisi, calibrationId: calibrationId),
        ],
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
    final c = NeuColors.of(context);

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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
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
    final c = NeuColors.of(context);

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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text,
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
                style: TextStyle(
                  fontSize: 12.5,
                  // Strip diredam biar beda jelas dari angka beneran.
                  color: n == null ? c.textMuted : c.text,
                ),
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
  const _PilihThermohygro({required this.kondisi, required this.calibrationId});

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
    final standarAsync = ref.watch(standardListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        standarAsync.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          // Dulu ini `SizedBox.shrink()` — pickernya LENYAP tanpa sepatah kata
          // kalau `GET /standards` gagal, sementara peringatan "thermohygro
          // belum dipilih" di bawah tetap nongol. Jadi admin dikasih tahu ada
          // yang kurang, terus kontrol buat mbenerinnya diumpetin: jalan buntu
          // yang kelihatan kayak app-nya rusak, bukan jaringannya.
          error: (_, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 14,
                color: AppColors.statusPeringatan(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.standarLoadFailed,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.statusPeringatan(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(standardListProvider),
                child: Text(l10n.standarRetry),
              ),
            ],
          ),
          data: (list) {
            // Cuma standar yang punya `parameter_kondisi` yang berguna di
            // sini — sisanya nggak akan ngasih koreksi apa pun.
            final thermohygro = list
                .where((s) => s.punyaParameterKondisi)
                .toList();

            return NeuInset(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  dropdownColor: NeuColors.of(context).base,
                  // DITURUNKAN dari theme, bukan TextStyle telanjang:
                  // `DropdownButtonFormField.style` MENGGANTI gaya teksnya, bukan
                  // nambahin — jadi `TextStyle(...)` tanpa `fontFamily` bikin nilai
                  // di dropdown ini berhenti pakai Inter sementara semua teks di
                  // sekitarnya masih. Ketahuan dari golden: 'TH-3' kerender jadi
                  // kotak-kotak.
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: NeuColors.of(context).text,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.perhitPilihThermohygro,
                    labelStyle: TextStyle(
                      color: NeuColors.of(context).textMuted,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
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
                  onChanged: _sibuk
                      ? null
                      : (v) => v == null ? null : _simpan(v),
                ),
              ),
            );
          },
        ),
        if (widget.kondisi.thermohygroBelumDipilih) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: AppColors.statusPeringatan(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.perhitThermohygroKosong,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.statusPeringatan(context),
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
