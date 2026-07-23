import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/lembar_kerja.dart';
import '../../../models/standard.dart';
import '../../../providers/calibration_input_provider.dart';
import '../lembar_kerja_state.dart';

/// Satu tabel hasil kalibrasi — Before atau After adjustment.
///
/// Susunannya ngikutin tabel yang tercetak di lembar kerja: **baris = larutan
/// standar**, **kolom = Repeat 1..5**, dan tiap sel isinya **dua angka**
/// (pH & °C). Jumlah baris/kolom/pengulangannya diambil dari [tabel] yang
/// dikirim backend, bukan dipatok di sini.
///
/// Tabelnya digulung mendatar, bukan diperas biar muat: lima Repeat × dua
/// kotak angka nggak akan kebaca di layar HP kalau dipaksa masuk. Kolom
/// pertama (nilai larutan standar) tetap nempel di kiri supaya teknisi nggak
/// kehilangan konteks baris waktu geser ke Repeat 5.
class LembarKerjaTabel extends StatelessWidget {
  const LembarKerjaTabel({
    super.key,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  final TabelHasil tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  static const _lebarSel = 78.0;
  static const _lebarLabel = 104.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kolom label yang nempel — di luar area gulung.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelKepala(
                  lebar: _lebarLabel,
                  teks: 'Standard',
                  tinggi: _tinggiKepala,
                ),
                for (final baris in tabel.baris)
                  _SelKepala(
                    lebar: _lebarLabel,
                    teks: baris.label,
                    tinggi: _tinggiBaris,
                    kiri: true,
                  ),
              ],
            ),

            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris kepala: Repeat 1..n, tiap satu dibagi dua kolom.
                    Row(
                      children: [
                        for (final r in tabel.pengulangan)
                          _KepalaPengulangan(
                            nomor: r,
                            kolom: tabel.kolom,
                            lebarSel: _lebarSel,
                          ),
                      ],
                    ),

                    for (final baris in tabel.baris)
                      Row(
                        children: [
                          for (var i = 0; i < tabel.pengulangan.length; i++)
                            for (final kolom in tabel.kolom)
                              _SelAngka(
                                lebar: _lebarSel,
                                controller: isian
                                    .titik[baris.titikUkur]!
                                    .kotak(tabel.tahap, kolom.kode, i),
                              ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Standar buffer per titik cuma dipilih SEKALI (di tabel pertama) —
        // buffer yang dipakai sama untuk before & after adjustment, cuma
        // suhunya yang beda. Nanyain dua kali cuma bikin peluang salah pilih.
        if (tabel.sebelumAdjustment) ...[
          const SizedBox(height: AppSpacing.md),
          for (final baris in tabel.baris)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PilihStandarTitik(
                label: baris.label,
                state: isian.titik[baris.titikUkur]!,
                onBerubah: onBerubah,
              ),
            ),
        ],
      ],
    );
  }

  static const _tinggiKepala = 44.0;
  static const _tinggiBaris = 56.0;
}

class _KepalaPengulangan extends StatelessWidget {
  const _KepalaPengulangan({
    required this.nomor,
    required this.kolom,
    required this.lebarSel,
  });

  final int nomor;
  final List<KolomTabelHasil> kolom;
  final double lebarSel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: lebarSel * kolom.length,
      height: LembarKerjaTabel._tinggiKepala,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.lkRepeat} $nomor',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final k in kolom)
                SizedBox(
                  width: lebarSel,
                  child: Text(
                    k.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelKepala extends StatelessWidget {
  const _SelKepala({
    required this.lebar,
    required this.teks,
    required this.tinggi,
    this.kiri = false,
  });

  final double lebar;
  final String teks;
  final double tinggi;
  final bool kiri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Align(
        alignment: kiri ? Alignment.centerLeft : Alignment.center,
        child: Text(
          teks,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SelAngka extends StatelessWidget {
  const _SelAngka({required this.lebar, required this.controller});

  final double lebar;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: lebar,
      height: LembarKerjaTabel._tinggiBaris,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            // Koma diterima juga — formulir kertasnya pakai koma desimal, dan
            // teknisi ngetik sesuai yang dia lihat. Dikonversi waktu parsing.
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*')),
          ],
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

/// Standar buffer yang dipakai di satu titik. pH butuh standar BEDA per titik
/// (buffer 4/7/10), bukan satu standar buat seluruh sesi.
class _PilihStandarTitik extends ConsumerWidget {
  const _PilihStandarTitik({
    required this.label,
    required this.state,
    required this.onBerubah,
  });

  final String label;
  final TitikState state;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    return standarAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        // Standar yang punya kurva suhu ditaruh duluan: itu yang bikin nilai
        // Standard-nya ngikutin suhu larutan, bukan mentok di nilai nominal.
        final urut = [...list]
          ..sort((a, b) {
            if (a.punyaKurvaSuhu == b.punyaKurvaSuhu) return 0;
            return a.punyaKurvaSuhu ? -1 : 1;
          });

        return DropdownButtonFormField<int>(
          initialValue: state.standardId,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: '${l10n.lkStandarPerTitik} $label',
            border: const OutlineInputBorder(),
          ),
          hint: Text(l10n.lkPilih),
          items: [
            for (final Standard s in urut)
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
          onChanged: (value) {
            state.standardId = value;
            onBerubah();
          },
        );
      },
    );
  }
}
