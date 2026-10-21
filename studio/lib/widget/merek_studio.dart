import 'package:flutter/material.dart';

import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';

/// Tanda merek Studio: ikon (gambar yang sama dengan ikon peluncur) + nama.
///
/// Dipakai di permukaan [WarnaStudio.sisi] (sidebar, rail, drawer, panel
/// merek layar masuk), jadi warnanya selalu warna sisi — bukan warna
/// permukaan konten.
class MerekStudio extends StatelessWidget {
  const MerekStudio({super.key, this.ukuranIkon = 32, this.denganNama = true});

  final double ukuranIkon;
  final bool denganNama;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;

    final ikon = Image.asset(
      'assets/merek/ikon-studio.png',
      width: ukuranIkon,
      height: ukuranIkon,
      filterQuality: FilterQuality.medium,
      // Dekoratif: nama aplikasi sudah ditulis di sebelahnya.
      excludeFromSemantics: true,
    );

    if (!denganNama) {
      return Semantics(label: l10n.namaAplikasi, child: ikon);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ikon,
        const SizedBox(width: UkuranStudio.j3),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.namaAplikasi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: teks.titleSmall?.copyWith(
                  color: w.sisiTeks,
                  fontSize: (teks.titleSmall?.fontSize ?? 13) + 2,
                ),
              ),
              Text(
                l10n.slogan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: teks.labelMedium?.copyWith(color: w.sisiTeksRedup),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
