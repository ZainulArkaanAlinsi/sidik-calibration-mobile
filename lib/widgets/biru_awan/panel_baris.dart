import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../core/theme/warna_biru_awan.dart';
import 'ubin_ikon.dart';

/// Panel putih sudut 16 bergaris halus yang memuat baris-baris ([BarisMenu64], [BarisDaftar72])
/// dipisah garis halus 1 dp (`POLA.md` §Daftar: daftar padat memakai panel
/// berbaris, bukan kartu terpisah).
///
/// Pemisah disisipkan di antara baris, tidak sesudah baris terakhir. Bantalan:
/// [PanelBaris.new] 6 (menu), [PanelBaris.daftar] atas-bawah 4 dan samping 14.
/// Panel memotong riak ketukan baris pada sudutnya.
class PanelBaris extends StatelessWidget {
  /// Panel baris menu (bantalan 6).
  const PanelBaris({
    super.key,
    required this.anak,
    this.padding = const EdgeInsets.all(JarakBiruAwan.sisipan),
  });

  /// Panel baris daftar (bantalan 4 atas-bawah, 14 samping).
  const PanelBaris.daftar({super.key, required this.anak})
    : padding = const EdgeInsets.symmetric(
        horizontal: JarakBiruAwan.panelDaftar,
        vertical: AppSpacing.xs,
      );

  final List<Widget> anak;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Material(
      color: m.kertas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
        side: BorderSide(color: m.kertasTepi, width: AppUkuran.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < anak.length; i++) ...[
              if (i > 0)
                SizedBox(
                  height: AppUkuran.garis,
                  child: ColoredBox(color: m.kertasTepi),
                ),
              anak[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu baris yang bisa diketuk atau hanya baca; dipakai bersama oleh
/// [BarisMenu64] dan [BarisDaftar72].
Widget _simpulSemantik({
  required Widget isi,
  required VoidCallback? onTap,
  required String? semantik,
}) {
  // Satu node semantik: aksi ketuk melekat di node yang sama dengan labelnya.
  if (semantik != null) {
    return Semantics(
      button: onTap != null,
      label: semantik,
      onTap: onTap,
      excludeSemantics: true,
      child: isi,
    );
  }
  return MergeSemantics(
    child: Semantics(button: onTap != null, onTap: onTap, child: isi),
  );
}

/// Baris menu 64 (`Kelola lab`, `Profil`): ubin ikon bulat 44 berwarna, judul
/// 16/700, sub-judul 13 tinta kedua, panah di ujung bila bisa diketuk.
///
/// Minimum 64 dp, tumbuh bila huruf diperbesar. [akhir] (mis. lencana) tampil
/// sebelum panah. Taruh di dalam [PanelBaris].
class BarisMenu64 extends StatelessWidget {
  const BarisMenu64({
    super.key,
    required this.judul,
    required this.ikon,
    this.keterangan,
    this.warna = IsiBiruAwan.kabut,
    this.akhir,
    this.onTap,
    this.semantik,
  });

  final String judul;
  final String? keterangan;
  final IconData ikon;

  /// Warna ubin ikon; bergilir kabut, hijau, awan, kuning, koral tipis
  /// (`LAYAR.md` M1) supaya baris mudah dibedakan.
  final IsiBiruAwan warna;
  final Widget? akhir;
  final VoidCallback? onTap;

  /// Label pembaca layar pengganti. `null` = gabungan judul dan keterangan.
  final String? semantik;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final isi = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: UkuranBiruAwan.barisMenu),
      child: Padding(
        padding: const EdgeInsets.all(JarakBiruAwan.barisMenu),
        child: Row(
          children: [
            UbinIkon(ikon: ikon, warna: warna),
            const SizedBox(width: JarakBiruAwan.blok),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    judul,
                    style: HurufBiruAwan.label.copyWith(color: m.tinta),
                  ),
                  if (keterangan != null) ...[
                    const SizedBox(height: JarakBiruAwan.baris),
                    Text(
                      keterangan!,
                      style: HurufBiruAwan.keteranganKecil.copyWith(
                        color: m.tinta2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (akhir != null) ...[
              const SizedBox(width: AppSpacing.sm),
              akhir!,
            ],
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: UkuranKomponenBiruAwan.panah,
                color: m.tinta2,
              ),
            ],
          ],
        ),
      ),
    );
    return _simpulSemantik(
      isi: InkWell(onTap: onTap, child: isi),
      onTap: onTap,
      semantik: semantik,
    );
  }
}

/// Baris daftar (`Jadwal`, `Kalibrasi` "lanjutkan pekerjaan" dan "aktivitas
/// terbaru"): [awal] (biasanya [UbinIkon.baris] berisi visual alat), judul
/// 16/600, [nomor] mono 12, keterangan 13, [catatan] 13 (mis. waktu pembaruan),
/// dan [akhir] di kanan (lencana status, angka hari + tanggal).
///
/// Minimum 64 dp (dulu 72; nama kelas peninggalan), tumbuh bila huruf
/// diperbesar. [akhir] mendapat paling banyak
/// 40 % lebar (`UkuranBaris.bagianStempel`) dan membungkus, tidak memotong.
/// Taruh di dalam [PanelBaris.daftar]. Tanpa [onTap] baris hanya baca.
class BarisDaftar72 extends StatelessWidget {
  const BarisDaftar72({
    super.key,
    required this.judul,
    this.keterangan,
    this.nomor,
    this.catatan,
    this.awal,
    this.akhir,
    this.onTap,
    this.semantik,
  });

  final String judul;
  final String? keterangan;

  /// Baris terakhir kecil di bawah keterangan, mis. "Diperbarui 5 menit lalu".
  /// Hanya ditulis bila ada isinya (tidak ada titik waktu yang dikarang).
  final String? catatan;

  /// Nomor KAL/..., serial: IBM Plex Mono.
  final String? nomor;
  final Widget? awal;
  final Widget? akhir;
  final VoidCallback? onTap;
  final String? semantik;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final isi = LayoutBuilder(
      builder: (context, batas) => ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: UkuranBiruAwan.barisDaftar,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              if (awal != null) ...[
                awal!,
                const SizedBox(width: JarakBiruAwan.blok),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HurufBiruAwan.judulBaris.copyWith(color: m.tinta),
                    ),
                    if (nomor != null)
                      Text(
                        nomor!,
                        style: HurufBiruAwan.nomor.copyWith(color: m.tinta2),
                      ),
                    if (keterangan != null)
                      Text(
                        keterangan!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HurufBiruAwan.keteranganKecil.copyWith(
                          color: m.tinta2,
                        ),
                      ),
                    if (catatan != null)
                      Text(
                        catatan!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HurufBiruAwan.keteranganKecil.copyWith(
                          color: m.tinta2,
                        ),
                      ),
                  ],
                ),
              ),
              if (akhir != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: batas.maxWidth * UkuranBaris.bagianStempel,
                  ),
                  child: akhir!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return _simpulSemantik(
      isi: InkWell(onTap: onTap, child: isi),
      onTap: onTap,
      semantik: semantik,
    );
  }
}
