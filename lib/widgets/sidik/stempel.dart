import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../l10n/app_localizations.dart';
import 'status_tampil.dart';

/// Stempel status: persegi sudut 4 ([BentukLab.stempel]), ikon + kata, tinta di
/// atas latar tipis nadanya. SATU sumber tampilan status Lab, pengganti
/// `StatusBadge` dan `StatusSidik`.
///
/// Status SELALU ikon + kata, tidak pernah warna saja (buta warna, fotokopi
/// hitam-putih). Nada [NadaStempel.netral] (draf, nonaktif) digambar bergaris
/// tepi tanpa isi, supaya bentuknya beda dari "menunggu" yang abu berisi.
///
/// [tenang] membuang latar, garis tepi, dan bantalan: untuk keadaan normal di
/// baris yang tidak perlu bersuara. Kata panjang ("Masa berlaku berakhir")
/// membungkus, tidak dipotong. Ikon ikut skala huruf supaya tetap sebaris
/// dengan teks. Kata dari ARB (Indonesia dan English). Pembaca layar menerima
/// "Status: kata". Stempel bukan tombol.
class Stempel extends StatelessWidget {
  const Stempel(this.status, {super.key, this.tenang = false});

  final StatusTampil status;

  /// Tanpa latar, garis tepi, dan bantalan.
  final bool tenang;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final kata = status.label(l10n);
    final (tinta, latar) = status.warna(m);
    final netral = status.nada == NadaStempel.netral;
    final skala = MediaQuery.textScalerOf(context);
    final gaya = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: tinta,
      fontSize: UkuranTeksLab.stempel,
      height: UkuranTeksLab.stempelBaris / UkuranTeksLab.stempel,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      label: l10n.stempelSemantik(kata),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tenang ? null : latar,
          borderRadius: BorderRadius.circular(BentukLab.stempel),
          border: netral && !tenang
              ? Border.all(color: m.garisTegas, width: AppUkuran.garis)
              : null,
        ),
        child: Padding(
          padding: tenang
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                status.ikon,
                size: skala.scale(UkuranIkonLab.stempel),
                color: tinta,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(kata, style: gaya)),
            ],
          ),
        ),
      ),
    );
  }
}
