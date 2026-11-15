import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Warna isi [UbinKpi]. Maknanya dibawa [UbinKpi.label], bukan warna: warna
/// hanya penekanan (koral = lewat jadwal, hijau = sertifikat terbit).
enum RagamUbinKpi {
  /// Putih (kertas): angka biasa ("Total alat").
  putih,
  kabut,
  hijau,
  kuning,
  awan,
  koral,

  /// Navy, sudut 28: ubin ringkasan antrean admin.
  navy,
}

/// Ubin angka ringkas (`BerandaAdmin.dc.html`, ubin KPI 2 x 2): label 13/700 di
/// atas, angka 36/800 di kiri bawah, catatan kecil di kanan bawah ("se-lab",
/// "+4"). Tinggi minimum 112, sudut 24, bantalan 16; tumbuh bila huruf sistem
/// membesar.
///
/// - Angka ([nilai]) dan [catatan] adalah TEKS dari pemanggil (dari provider
///   yang sama dengan layar tujuan); ubin tidak menghitung, membulatkan, atau
///   menganimasikan angka (angka tidak boleh "berhitung naik").
/// - [onTap] `null` = ubin hanya informasi: tanpa riak, tanpa skala tekan,
///   tanpa aksi di semantik. Bila ada, seluruh ubin (>= 112 x lebarnya) dapat
///   diketuk.
/// - Semantik satu node: "label, angka, catatan"; label terpasang juga tanpa
///   [onTap].
/// - Angka terlalu panjang mengecil (`FittedBox`) alih-alih meluap.
/// - Catatan memakai tinta penuh, bukan opasitas 0,8 seperti artboard, supaya
///   kontras di atas koral dan kuning tidak turun.
class UbinKpi extends StatelessWidget {
  const UbinKpi({
    super.key,
    required this.label,
    required this.nilai,
    this.catatan,
    this.ragam = RagamUbinKpi.putih,
    this.onTap,
  });

  final String label;
  final String nilai;
  final String? catatan;
  final RagamUbinKpi ragam;
  final VoidCallback? onTap;

  /// Teks semantik gabungan.
  String get teksSemantik => [
    label,
    nilai,
    if (catatan != null && catatan!.isNotEmpty) catatan!,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final (Color isi, Color tinta) = switch (ragam) {
      RagamUbinKpi.putih => (m.kertas, m.tinta),
      RagamUbinKpi.kabut => (
        w.isi(IsiBiruAwan.kabut),
        w.tinta(IsiBiruAwan.kabut),
      ),
      RagamUbinKpi.hijau => (
        w.isi(IsiBiruAwan.hijau),
        w.tinta(IsiBiruAwan.hijau),
      ),
      RagamUbinKpi.kuning => (
        w.isi(IsiBiruAwan.kuning),
        w.tinta(IsiBiruAwan.kuning),
      ),
      RagamUbinKpi.awan => (w.isi(IsiBiruAwan.awan), w.tinta(IsiBiruAwan.awan)),
      RagamUbinKpi.koral => (
        w.isi(IsiBiruAwan.koral),
        w.tinta(IsiBiruAwan.koral),
      ),
      RagamUbinKpi.navy => (m.tinta, m.kertas),
    };
    final radius = ragam == RagamUbinKpi.navy
        ? BentukBiruAwan.hero
        : BentukBiruAwan.kartu;
    final sudut = BorderRadius.circular(radius);
    final aktif = onTap != null;

    final isiUbin = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: UkuranLanjutBiruAwan.kpiTinggiMin,
      ),
      child: Padding(
        padding: const EdgeInsets.all(UkuranLanjutBiruAwan.kpiBantalan),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: HurufLanjutBiruAwan.labelKpi.copyWith(color: tinta),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nilai,
                      maxLines: 1,
                      style: HurufLanjutBiruAwan.angkaKpi.copyWith(
                        color: tinta,
                      ),
                    ),
                  ),
                ),
                if (catatan != null && catatan!.isNotEmpty) ...[
                  const SizedBox(width: JarakBiruAwan.sisipan),
                  Flexible(
                    child: Text(
                      catatan!,
                      textAlign: TextAlign.end,
                      style: HurufBiruAwan.catatan.copyWith(color: tinta),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: aktif,
      label: teksSemantik,
      onTap: onTap,
      excludeSemantics: true,
      child: TekanSkala(
        aktif: aktif,
        child: Material(
          color: isi,
          borderRadius: sudut,
          clipBehavior: Clip.antiAlias,
          child: aktif ? InkWell(onTap: onTap, child: isiUbin) : isiUbin,
        ),
      ),
    );
  }
}
