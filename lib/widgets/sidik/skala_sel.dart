import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';

/// Keadaan satu tik pada [SkalaSel].
enum KeadaanTik {
  /// Semua sel yang diwakili sudah terisi: digambar penuh.
  penuh,

  /// Sebagian sel terisi (hanya pada lembar > 60 sel, satu tik = satu
  /// kelompok): digambar bergaris tepi dengan setengah bawah terisi.
  sebagian,

  /// Belum ada yang terisi: hanya garis tepi.
  kosong,
}

/// Kemajuan pengisian lembar: SATU TIK PER SEL, berpenggaris. Tik terisi penuh
/// kobalt, tik kosong hanya bergaris tepi tegas, jadi terbaca tanpa warna.
///
/// Lembar dengan lebih dari 60 sel ([batasTikTunggal]) dikelompokkan: satu tik
/// mewakili beberapa sel berurutan (paling banyak [maksKelompok] tik), dan tik
/// kelompok yang baru sebagian terisi digambar [KeadaanTik.sebagian].
///
/// [kata] ("12 dari 30 sel") tampil di bawah tik dan menjadi label pembaca
/// layar; matikan lewat [tampilkanKata] bila layar sudah menuliskannya. Nilai
/// di luar jangkauan dijepit (terisi < 0 atau > total).
class SkalaSel extends StatelessWidget {
  const SkalaSel({
    super.key,
    required this.terisi,
    required this.total,
    this.kata,
    this.tampilkanKata = true,
  });

  final int terisi;
  final int total;

  /// Kalimat pengganti. Bawaan: "12 dari 30 sel" atau "Belum ada sel".
  final String? kata;

  /// Tulis [kata] di bawah tik.
  final bool tampilkanKata;

  /// Sampai jumlah sel ini, tiap sel punya tiknya sendiri.
  static const int batasTikTunggal = 60;

  /// Jumlah tik paling banyak bila sel dikelompokkan.
  static const int maksKelompok = 30;

  /// Keadaan tik-tik untuk [terisi] dari [total] sel.
  static List<KeadaanTik> susunTik({required int terisi, required int total}) {
    if (total <= 0) return const [];
    final isi = terisi.clamp(0, total);
    if (total <= batasTikTunggal) {
      return [
        for (var i = 0; i < total; i++)
          i < isi ? KeadaanTik.penuh : KeadaanTik.kosong,
      ];
    }
    final perKelompok = (total / maksKelompok).ceil();
    final jumlah = (total / perKelompok).ceil();
    return [
      for (var g = 0; g < jumlah; g++)
        () {
          final awal = g * perKelompok;
          final ukuran = (total - awal).clamp(0, perKelompok);
          final terisiDi = (isi - awal).clamp(0, ukuran);
          if (terisiDi >= ukuran) return KeadaanTik.penuh;
          if (terisiDi <= 0) return KeadaanTik.kosong;
          return KeadaanTik.sebagian;
        }(),
    ];
  }

  /// Kalimat bawaan.
  static String kataSel(int terisi, int total) => total <= 0
      ? 'Belum ada sel'
      : '${terisi.clamp(0, total)} dari $total sel';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final m = SidikMaterial.of(context);
    final tik = susunTik(terisi: terisi, total: total);
    final kalimat = kata ?? kataSel(terisi, total);

    Widget satuTik(int i, KeadaanTik k) => Expanded(
      key: ValueKey('tik-sel-$i-${k.name}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UkuranTikLab.jarakTikSel / 2,
        ),
        child: SizedBox(
          height: UkuranTikLab.tikSel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: k == KeadaanTik.penuh ? s.primary : null,
              border: k == KeadaanTik.penuh
                  ? null
                  : Border.all(
                      color: k == KeadaanTik.sebagian
                          ? s.primary
                          : m.garisTegas,
                      width: AppUkuran.garis,
                    ),
            ),
            child: k == KeadaanTik.sebagian
                ? FractionallySizedBox(
                    heightFactor: 0.5,
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(color: s.primary),
                  )
                : null,
          ),
        ),
      ),
    );

    return Semantics(
      // "terisi" hanya ditambahkan pada kalimat bawaan: kalimat buatan layar
      // ("12 dari 30 sel terisi") dibacakan apa adanya, bukan "terisi terisi".
      label: (kata != null || tik.isEmpty) ? kalimat : '$kalimat terisi',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tik.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < tik.length; i++) satuTik(i, tik[i]),
              ],
            ),
          if (tampilkanKata) ...[
            if (tik.isNotEmpty) const SizedBox(height: AppSpacing.xs),
            Text(kalimat, style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}
