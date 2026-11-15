import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Ukuran [AvatarInisial] (garis tengah): 36 (tumpukan, baris), 48, 52 (kepala
/// laci), 84 (hero profil).
enum UkuranAvatarInisial {
  kecil(UkuranLanjutBiruAwan.avatarKecil),
  sedang(UkuranLanjutBiruAwan.avatarSedang),
  laci(UkuranLanjutBiruAwan.avatarLaci),
  besar(UkuranLanjutBiruAwan.avatarBesar);

  const UkuranAvatarInisial(this.garisTengah);
  final double garisTengah;

  TextStyle get gaya => switch (this) {
    kecil => HurufLanjutBiruAwan.inisialKecil,
    sedang => HurufLanjutBiruAwan.inisialSedang,
    laci => HurufLanjutBiruAwan.inisialLaci,
    besar => HurufLanjutBiruAwan.inisialBesar,
  };
}

/// Isi [AvatarInisial].
enum RagamAvatarInisial {
  /// Kabut berisi inisial primerTua: di atas kertas atau latar halaman.
  kabut,

  /// Putih berisi inisial primerTua: di atas hero langit (`LAYAR.md` 06 Profil).
  putih,

  /// Langit berisi inisial navy: kepala laci (`LAYAR.md` avatar 52 langit).
  langit,
}

/// Bulatan berisi inisial nama (`ELEMEN.md` §Kontrol kecil: avatar 36/48/84,
/// inisial 800).
///
/// - Inisial dari pemanggil ([inisial]) atau diturunkan dari nama dengan
///   [AvatarInisial.dariNama] ([inisialDari]: huruf pertama dua kata pertama,
///   APA ADANYA; nama dari server sudah berkapital). Tidak ada foto dan tidak
///   ada warna acak per orang: warna hanya mengikuti [ragam].
/// - [label] (mis. nama lengkap) terpasang ke pembaca layar bila diberikan.
///   Tanpa [label], avatar hiasan (nama biasanya sudah tertulis di sebelahnya).
/// - [onTap] opsional; bila ada, area sentuh >= 48 dp di sekeliling bulatan
///   (avatar 36 menambah ruang 6 dp di tiap sisi) dan semantik membawa aksi.
///   Tanpa [onTap], ukuran persis garis tengahnya.
/// - Inisial mengecil (`FittedBox`) alih-alih meluap saat huruf sistem 1,3.
class AvatarInisial extends StatelessWidget {
  const AvatarInisial({
    super.key,
    required this.inisial,
    this.ukuran = UkuranAvatarInisial.sedang,
    this.ragam = RagamAvatarInisial.kabut,
    this.label,
    this.onTap,
  }) : assert(
         onTap == null || (label != null && label != ''),
         'AvatarInisial dengan onTap wajib punya label',
       );

  /// Inisial dari [nama]; [label] bawaan = [nama].
  AvatarInisial.dariNama(
    String nama, {
    super.key,
    this.ukuran = UkuranAvatarInisial.sedang,
    this.ragam = RagamAvatarInisial.kabut,
    String? label,
    this.onTap,
  }) : assert(
         onTap == null ||
             nama.trim().isNotEmpty ||
             (label?.isNotEmpty ?? false),
         "AvatarInisial dengan onTap wajib punya label",
       ),
       inisial = inisialDari(nama),
       label = label ?? (nama.trim().isEmpty ? null : nama.trim());

  final String inisial;
  final UkuranAvatarInisial ukuran;
  final RagamAvatarInisial ragam;
  final String? label;
  final VoidCallback? onTap;

  /// Huruf pertama dari satu atau dua kata pertama [nama] ("Siti Aminah" ->
  /// "SA", "budi" -> "b", "" -> ""). Tidak mengubah huruf besar-kecil.
  static String inisialDari(String nama) {
    final kata = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((k) => k.isNotEmpty)
        .take(2);
    return kata.map((k) => k.characters.first).join();
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final lanjut = WarnaLanjutBiruAwan.of(context);
    final (Color isi, Color tinta) = switch (ragam) {
      RagamAvatarInisial.kabut => (w.isi(IsiBiruAwan.kabut), m.biruTinta),
      RagamAvatarInisial.putih => (m.kertas, m.biruTinta),
      RagamAvatarInisial.langit => (lanjut.isiHero, lanjut.tintaHero),
    };
    final d = ukuran.garisTengah;

    final bulatan = SizedBox.square(
      dimension: d,
      child: DecoratedBox(
        decoration: BoxDecoration(color: isi, shape: BoxShape.circle),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(d / 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                inisial,
                maxLines: 1,
                style: ukuran.gaya.copyWith(color: tinta),
              ),
            ),
          ),
        ),
      ),
    );

    final nama = label;
    final aktif = onTap != null;
    final Widget isiAvatar = aktif
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.square(
              dimension: math.max(d, AppUkuran.sasaranSentuh),
              child: Center(child: bulatan),
            ),
          )
        : bulatan;

    if (nama == null || nama.isEmpty) {
      return aktif ? isiAvatar : ExcludeSemantics(child: isiAvatar);
    }
    return Semantics(
      label: nama,
      button: aktif,
      onTap: onTap,
      excludeSemantics: true,
      child: isiAvatar,
    );
  }
}
