import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';

/// Satu butir [GarisWaktu].
class ButirGarisWaktu {
  const ButirGarisWaktu({
    required this.waktu,
    required this.kalimat,
    this.pelaku,
    this.detail,
  });

  /// Waktu yang sudah diformat pemanggil ("Hari ini, 08.42").
  final String waktu;

  /// Kalimat setelah [pelaku] ("mengubah U standar Buffer pH 10,01").
  final String kalimat;

  /// Pelaku, tampil tebal di depan [kalimat]. Server yang menentukan siapa;
  /// tidak pernah disimpulkan di sini.
  final String? pelaku;

  /// Isi tambahan di bawah kalimat (mis. diff lama coret, baru hijau).
  final Widget? detail;
}

/// Garis waktu riwayat (`Audit.dc.html`, `POLA.md` §Riwayat): simpul primer 12
/// di kiri dengan garis halus 2 dp ke butir berikutnya; waktu 12 `tinta2`,
/// kalimat 15 dengan pelaku tebal.
///
/// - Urutan butir = urutan [butir] dari pemanggil (terbaru di atas bila
///   begitu datanya); komponen tidak mengurutkan dan tidak memformat waktu.
/// - Bukan kontrol. Pembaca layar menerima satu node per butir: "waktu, pelaku
///   kalimat" beserta semantik [ButirGarisWaktu.detail]; simpul dan garis
///   hiasan.
/// - Kalimat panjang membungkus; garis memanjang mengikuti tinggi butir.
class GarisWaktu extends StatelessWidget {
  const GarisWaktu({super.key, required this.butir});

  final List<ButirGarisWaktu> butir;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < butir.length; i++)
          MergeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: UkuranLanjutBiruAwan.simpul,
                      child: Column(
                        children: [
                          const SizedBox(
                            height: UkuranLanjutBiruAwan.simpulAtas,
                          ),
                          SizedBox.square(
                            dimension: UkuranLanjutBiruAwan.simpul,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          if (i != butir.length - 1)
                            Expanded(
                              child: SizedBox(
                                width: UkuranLanjutBiruAwan.garisWaktuGaris,
                                child: ColoredBox(color: m.kertasTepi),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: UkuranLanjutBiruAwan.garisWaktuJarak),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == butir.length - 1
                            ? 0
                            : UkuranLanjutBiruAwan.garisWaktuBawah,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            butir[i].waktu,
                            style: HurufBiruAwan.catatan.copyWith(
                              color: m.tinta2,
                            ),
                          ),
                          const SizedBox(height: JarakBiruAwan.sisipan),
                          Text.rich(
                            TextSpan(
                              style: HurufLanjutBiruAwan.kalimatRiwayat
                                  .copyWith(color: m.tinta),
                              children: [
                                if (butir[i].pelaku != null &&
                                    butir[i].pelaku!.isNotEmpty)
                                  TextSpan(
                                    text: butir[i].pelaku,
                                    style: HurufLanjutBiruAwan.pelakuRiwayat,
                                  ),
                                TextSpan(
                                  text:
                                      (butir[i].pelaku != null &&
                                          butir[i].pelaku!.isNotEmpty)
                                      ? ' ${butir[i].kalimat}'
                                      : butir[i].kalimat,
                                ),
                              ],
                            ),
                          ),
                          if (butir[i].detail != null) ...[
                            const SizedBox(height: JarakBiruAwan.sisipan),
                            butir[i].detail!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
