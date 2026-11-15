import 'package:flutter/material.dart';

import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../l10n/app_localizations.dart';

/// Bilah langkah (`PilihAlat.dc.html`, `LAYAR.md` 02): satu segmen per langkah,
/// tinggi 6, sudut 3, jarak 6; segmen sampai langkah sekarang primer, sisanya
/// `garisDekor`; label 12 di bawah tiap segmen ("1 Alat").
///
/// - [label] kata tiap langkah dari pemanggil (l10n); nomornya ditambahkan di
///   sini. [aktif] = indeks langkah sekarang (mulai 0); di luar rentang
///   dibatasi ke ujungnya.
/// - Langkah sekarang: label 800 primerTua; selesai: 700 primerTua; belum: 400
///   `tinta2`. Keadaan juga dibaca lewat kata, bukan hanya warna: pembaca layar
///   menerima "Langkah n dari total, selesai / langkah sekarang / belum, label"
///   per segmen.
/// - Bukan kontrol; tidak diketuk. Label membungkus (maks 2 baris) di huruf
///   besar, tidak meluap di 320 dp x 1,3.
class BilahLangkah extends StatelessWidget {
  const BilahLangkah({super.key, required this.label, required this.aktif});

  final List<String> label;
  final int aktif;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final lanjut = WarnaLanjutBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final total = label.length;
    final sekarang = total == 0 ? 0 : aktif.clamp(0, total - 1);
    final s = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Semantics(
              label:
                  '${l10n.biruAwanLangkahKe(i + 1, total)}, '
                  '${i < sekarang
                      ? l10n.biruAwanLangkahSelesai
                      : i == sekarang
                      ? l10n.biruAwanLangkahSekarang
                      : l10n.biruAwanLangkahBelum}, ${label[i]}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: UkuranBiruAwan.bilahLangkah,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i <= sekarang ? s.primary : lanjut.garisDekor,
                        borderRadius: BorderRadius.circular(
                          UkuranLanjutBiruAwan.bilahRadius,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: JarakBiruAwan.sisipan),
                  Text(
                    '${i + 1} ${label[i]}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: switch (i.compareTo(sekarang)) {
                      < 0 => HurufLanjutBiruAwan.labelBilahSelesai.copyWith(
                        color: m.biruTinta,
                      ),
                      0 => HurufLanjutBiruAwan.labelBilahSekarang.copyWith(
                        color: m.biruTinta,
                      ),
                      _ => HurufLanjutBiruAwan.labelBilah.copyWith(
                        color: m.tinta2,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
          if (i != total - 1) const SizedBox(width: JarakBiruAwan.sisipan),
        ],
      ],
    );
  }
}
