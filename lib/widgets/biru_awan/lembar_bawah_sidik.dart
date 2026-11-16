import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'toast_sidik.dart';

/// Isi lembar bawah Biru Awan (`ELEMEN.md` §Lembar bawah): sudut atas 32,
/// pegangan 44 x 5, bantalan 10/16/20, judul 20/26 800 dengan tombol tutup 44
/// (sasaran 48), lalu isi yang bergulir. Tingginya paling banyak 80 % layar.
///
/// Widget ini menggambar latar dan sudutnya sendiri; [tampilkanLembarBawahSidik]
/// membukanya lewat `showModalBottomSheet` (usap turun atau ketuk latar untuk
/// menutup) dengan latar bawaan transparan.
///
/// - [judul] menjadi header pembaca layar; pegangan hiasan (tanpa semantik).
/// - [onTutup] `null` = menutup rute terdekat (`Navigator.maybePop`).
/// - Isian di dalamnya memakai `IsianSidik`; tombol utama penuh di bawah isi
///   (pemanggil yang menaruhnya di [child]).
class LembarBawahSidik extends StatelessWidget {
  const LembarBawahSidik({
    super.key,
    required this.judul,
    required this.child,
    this.onTutup,
  });

  final String judul;
  final Widget child;
  final VoidCallback? onTutup;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final u = WarnaUmpanBalikBiruAwan.of(context);
    final l10n = AppLocalizations.of(context);
    final tinggiMaks =
        MediaQuery.sizeOf(context).height * AppUkuran.nisbiLembar;
    final bawahAman = MediaQuery.viewPaddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tinggiMaks),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: m.kertas,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BentukBiruAwan.lembarBawah),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.only(
              top: UkuranUmpanBalikBiruAwan.lembarBantalanAtas,
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: UkuranUmpanBalikBiruAwan.lembarBantalanBawah + bawahAman,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Center(
                    child: SizedBox(
                      width: UkuranUmpanBalikBiruAwan.peganganLebar,
                      height: UkuranUmpanBalikBiruAwan.peganganTinggi,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: u.pegangan,
                          borderRadius: BorderRadius.circular(
                            BentukBiruAwan.pil,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: JarakBiruAwan.blok),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          judul,
                          style: HurufBiruAwan.judulAnak.copyWith(
                            color: m.tinta,
                          ),
                        ),
                      ),
                    ),
                    TombolTutupSidik(
                      label: l10n.biruAwanTutup,
                      ukuran: UkuranUmpanBalikBiruAwan.lembarTutup,
                      onPressed: onTutup ?? () => Navigator.maybePop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Membuka [LembarBawahSidik] berisi hasil [bangun]. Ditutup dengan usap turun,
/// ketuk latar, tombol tutup, atau `Navigator.pop` dengan hasil. "Kurangi gerak"
/// = muncul dan hilang tanpa animasi.
Future<T?> tampilkanLembarBawahSidik<T>(
  BuildContext context, {
  required String judul,
  required WidgetBuilder bangun,
}) {
  final u = WarnaUmpanBalikBiruAwan.of(context);
  final gerak = AppMotion.hormati(context, AppMotion.sedang);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: u.scrim,
    sheetAnimationStyle: gerak == Duration.zero
        ? AnimationStyle.noAnimation
        : AnimationStyle(duration: gerak, reverseDuration: gerak),
    builder: (konteks) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(konteks).bottom),
      child: LembarBawahSidik(
        judul: judul,
        onTutup: () => Navigator.of(konteks).pop(),
        child: Builder(builder: bangun),
      ),
    ),
  );
}
