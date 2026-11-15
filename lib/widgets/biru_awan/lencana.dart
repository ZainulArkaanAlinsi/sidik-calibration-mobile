import 'package:flutter/material.dart';

import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';
import 'tombol_bulat.dart';

/// Warna [Lencana]: koral (belum dibaca, antrean) atau kuning (perlu dicek).
enum RagamLencana { koral, kuning }

/// Lencana jumlah (`ELEMEN.md` §Kontrol kecil): koral tinggi 22, kuning 26,
/// titik 10. Angka 12/800 navy di atas isi (kontras 6,85:1 koral, 10,59:1
/// kuning), tepi 2 dp warna latar halaman supaya terpisah dari tombol di
/// bawahnya.
///
/// - Jumlah <= 0 = tidak tampil (`SizedBox.shrink`): "0 belum dibaca" tidak
///   pernah digambar. Di atas [UkuranLanjutBiruAwan.lencanaMaks] tampil "99+".
/// - [label] (mis. "12 belum dibaca") terpasang ke pembaca layar bila diberikan.
///   Tanpa [label] lencana hiasan: pemakai yang menempelkannya di tombol
///   memasang jumlahnya di label tombol itu (lihat [LoncengBerlencana]).
/// - Bukan kontrol; tidak punya aksi ketuk. Angka dari pemanggil (provider),
///   tidak dihitung di sini.
class Lencana extends StatelessWidget {
  const Lencana({
    super.key,
    required int this.jumlah,
    this.ragam = RagamLencana.koral,
    this.label,
  }) : titik = false;

  /// Titik 10 tanpa angka ("ada yang baru"). Wajib punya [label] bila dipakai
  /// sendirian; tanpa label titik hiasan.
  const Lencana.titik({super.key, this.ragam = RagamLencana.koral, this.label})
    : jumlah = null,
      titik = true;

  final int? jumlah;
  final bool titik;
  final RagamLencana ragam;
  final String? label;

  /// Teks angka yang tampil untuk [jumlah] ("7", "99+").
  static String teksJumlah(int jumlah) =>
      jumlah > UkuranLanjutBiruAwan.lencanaMaks
      ? '${UkuranLanjutBiruAwan.lencanaMaks}+'
      : '$jumlah';

  @override
  Widget build(BuildContext context) {
    if (!titik && (jumlah ?? 0) <= 0) return const SizedBox.shrink();
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final pilihan = ragam == RagamLencana.koral
        ? IsiBiruAwan.koral
        : IsiBiruAwan.kuning;
    final isi = w.isi(pilihan);
    final tinta = w.tinta(pilihan);
    final tepi = BorderSide(
      color: m.meja,
      width: UkuranLanjutBiruAwan.lencanaTepi,
    );

    final Widget gambar;
    if (titik) {
      gambar = SizedBox.square(
        dimension: UkuranLanjutBiruAwan.lencanaTitik,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isi,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(tepi),
          ),
        ),
      );
    } else {
      final tinggi = ragam == RagamLencana.koral
          ? UkuranLanjutBiruAwan.lencanaKoral
          : UkuranLanjutBiruAwan.lencanaKuning;
      gambar = ConstrainedBox(
        constraints: BoxConstraints(minWidth: tinggi, minHeight: tinggi),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isi,
            borderRadius: BorderRadius.circular(BentukBiruAwan.pil),
            border: Border.fromBorderSide(tepi),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UkuranLanjutBiruAwan.lencanaBantalan,
              ),
              child: Text(
                teksJumlah(jumlah!),
                maxLines: 1,
                style: HurufLanjutBiruAwan.lencana.copyWith(color: tinta),
              ),
            ),
          ),
        ),
      );
    }

    final nama = label;
    if (nama == null || nama.isEmpty) return ExcludeSemantics(child: gambar);
    return Semantics(label: nama, excludeSemantics: true, child: gambar);
  }
}

/// Tombol lonceng 48 putih dengan lencana koral di sudut kanan atas
/// (`LAYAR.md` 01 Kalibrasi, `POLA.md` kepala tab): [TombolBulat] + [Lencana].
///
/// - [label] mencakup jumlahnya ("Notifikasi, 12 belum dibaca"); lencana di
///   dalamnya hiasan, jadi jumlah tidak dibaca dua kali. Pemanggil menyusun
///   kalimat itu dari l10n.
/// - Ketuk di mana pun pada bulatan 48 bekerja, termasuk di bawah lencana
///   (lencana tidak menangkap ketukan).
/// - [jumlah] <= 0: tombol tanpa lencana.
class LoncengBerlencana extends StatelessWidget {
  const LoncengBerlencana({
    super.key,
    required this.label,
    required this.jumlah,
    required this.onPressed,
    this.ikon = Icons.notifications_none,
  });

  final String label;
  final int jumlah;
  final VoidCallback? onPressed;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TombolBulat(ikon: ikon, label: label, onPressed: onPressed),
        if (jumlah > 0)
          Positioned(
            top: UkuranLanjutBiruAwan.lencanaAtas,
            right: UkuranLanjutBiruAwan.lencanaKanan,
            child: IgnorePointer(child: Lencana(jumlah: jumlah)),
          ),
      ],
    );
  }
}
