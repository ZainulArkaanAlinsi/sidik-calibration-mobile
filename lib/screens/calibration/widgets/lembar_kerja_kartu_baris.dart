import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/lembar_kerja.dart';
import '../lembar_kerja_state.dart';

/// Tabel-tabel sebaris digambar SATU KARTU PER BARIS — susunan kertas.
///
/// Dipakai bagian yang backend-nya menandai `tampilan: kartu_per_baris`
/// (Anak Timbangan, SIDIK-FM-CAL-0541): kertasnya satu blok per keping berisi
/// Nominal AT, lalu Standard / UUT / UUT / Standard × X1 X2 X3. Digambar sebagai
/// empat tabel peran terpisah, teknisi harus menggulir naik-turun empat kali
/// untuk satu keping (laporan lapangan 5 Okt 2026).
///
/// **Cuma tampilan.** Tiap kotak di sini controller yang SAMA dengan yang
/// dipakai tabel biasa ([LembarKerjaState.titikUntukBaris] → `kotak`,
/// `titikCtl`, `kotakBarisCtl`), jadi payload, draft, dan olah datanya tidak
/// tahu kartu ini ada.
class LembarKerjaKartuBaris extends StatelessWidget {
  const LembarKerjaKartuBaris({
    super.key,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  /// Tabel sebaris, urut seperti di kertas. Yang PERTAMA jadi acuan: nominal
  /// dan kotak per barisnya dibaca payload dari situ.
  final List<TabelHasil> tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// `Standard (S1) — penimbangan standar, pertama` → `Standard (S1)`.
  static String labelPendek(String judul) {
    final i = judul.indexOf(' —');
    return (i < 0 ? judul : judul.substring(0, i)).trim();
  }

  @override
  Widget build(BuildContext context) {
    if (tabel.isEmpty) return const SizedBox.shrink();

    final acuan = tabel.first;
    final barisAcuan = isian.barisTabel(acuan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < barisAcuan.length; i++) ...[
          _Kartu(
            nomor: i + 1,
            indeks: i,
            tabel: tabel,
            isian: isian,
            onBerubah: onBerubah,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (isian.bisaTambahBaris(tabel.last))
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('tambah-baris'),
              onPressed: () {
                isian.tambahBaris();
                onBerubah();
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah baris'),
            ),
          ),
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.nomor,
    required this.indeks,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  final int nomor;
  final int indeks;
  final List<TabelHasil> tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acuan = tabel.first;
    final barisAcuan = isian.barisTabel(acuan);
    final tsAcuan = isian.titikUntukBaris(barisAcuan, indeks, acuan);
    final satuan = isian.bentuk.satuan;
    final jumlahUlang = acuan.pengulangan.length;

    if (tsAcuan == null) return const SizedBox.shrink();

    Widget kotakAngka(TextEditingController ctl, {Key? key}) => TextField(
      key: key,
      controller: ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      onChanged: (_) => onBerubah(),
    );

    return Container(
      key: ValueKey('kartu-baris-$nomor'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kepala blok: nomor, Nominal AT, dan kotak per baris (No. Identitas)
          // — di kertas tempatnya `Nominal AT` dan `( )` di atas X1–X3.
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('$nomor.', style: theme.textTheme.titleSmall),
              ),
              Expanded(
                child: TextField(
                  key: ValueKey('kartu-nominal-$nomor'),
                  controller: tsAcuan.titikCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: satuan.isEmpty ? 'Nominal' : 'Nominal ($satuan)',
                  ),
                  onChanged: (_) => onBerubah(),
                ),
              ),
              for (final f in acuan.kolomBaris)
                if (f.kode != 'no_probe') ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      key: ValueKey('kartu-${f.kode}-$nomor'),
                      controller: tsAcuan.kotakBarisCtl(acuan.kunciTabel, f.kode),
                      keyboardType: f.tipe == TipeField.teks
                          ? TextInputType.text
                          : const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText: f.label,
                        hintText: f.tipe == TipeField.teks ? 'mis. 20*' : null,
                      ),
                      onChanged: (_) => onBerubah(),
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Kepala kolom X1..Xn.
          Row(
            children: [
              const SizedBox(width: 104),
              for (var r = 0; r < jumlahUlang; r++)
                Expanded(
                  child: Text(
                    'X${r + 1}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var k = 0; k < tabel.length; k++)
            Builder(
              builder: (context) {
                final t = tabel[k];
                final baris = isian.barisTabel(t);
                final ts = indeks < baris.length ? isian.titikUntukBaris(baris, indeks, t) : null;
                if (ts == null || t.kolom.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          LembarKerjaKartuBaris.labelPendek(t.judul),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      for (var r = 0; r < t.pengulangan.length; r++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: kotakAngka(
                              ts.kotak(t.kunciTabel, t.kolom.first.kode, r),
                              // Indeks tabel, bukan `kunciTabel`: keempat
                              // tabel ABBA berbagi kunci tabel yang sama
                              // (dibedakan offset barisnya).
                              key: ValueKey('kartu-t$k-$nomor-$r'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
