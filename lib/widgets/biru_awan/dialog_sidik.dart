import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../core/theme/warna_biru_awan.dart';
import 'tombol_sidik.dart';
import 'toast_sidik.dart';

/// Kartu dialog konfirmasi Biru Awan (`ELEMEN.md` §Dialog konfirmasi): ubin ikon
/// 56 sudut 20, judul 20/26 800, isi 14/20, lalu dua tombol pil 48 (Batal di
/// kiri, aksi di kanan). Kartu saja; [tampilkanDialogSidik] membukanya di atas
/// latar redup.
///
/// - [aksi] memakai kata kerja yang jelas ("Kirim", "Hapus", "Tarik
///   sertifikat"), tidak pernah "OK" atau "Ya". [bahaya] mewarnainya merah
///   (`TombolSidik` ragam `bahaya`) dan ubinnya koral tipis.
/// - [batal] `null` = hanya satu tombol (dialog pemberitahuan).
/// - Lebar kartu 340 (HP) atau 420 (>= 600 dp). Bila lebar isi < 240 atau huruf
///   > 1,15 kedua tombol bertumpuk: aksi di atas, Batal di bawah.
/// - Pembaca layar: simpul rute bernama [judul] (`namesRoute`); isinya dibaca
///   berurutan, tombol berlabel.
class DialogSidik extends StatelessWidget {
  const DialogSidik({
    super.key,
    required this.ikon,
    required this.judul,
    required this.aksi,
    required this.onAksi,
    this.isi,
    this.batal,
    this.onBatal,
    this.bahaya = false,
  });

  final IconData ikon;
  final String judul;
  final String? isi;
  final String aksi;
  final VoidCallback? onAksi;
  final String? batal;
  final VoidCallback? onBatal;
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final u = WarnaUmpanBalikBiruAwan.of(context);
    final ukuranLayar = MediaQuery.sizeOf(context);
    final lebarMaks = ukuranLayar.width >= AmbangLab.tablet
        ? UkuranUmpanBalikBiruAwan.dialogLebarLebar
        : UkuranUmpanBalikBiruAwan.dialogLebarHp;

    final tombolAksi = TombolSidik(
      label: aksi,
      onPressed: onAksi,
      ragam: bahaya ? RagamTombolSidik.bahaya : RagamTombolSidik.tegas,
      lebarPenuh: true,
    );
    final tombolBatal = batal == null
        ? null
        : TombolSidik(
            label: batal!,
            onPressed: onBatal,
            ragam: RagamTombolSidik.sekunder,
            lebarPenuh: true,
          );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: judul,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: lebarMaks,
          maxHeight: ukuranLayar.height,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: m.kertas,
            borderRadius: BorderRadius.circular(BentukBiruAwan.dialog),
            boxShadow: u.bayanganDialog,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(
                UkuranUmpanBalikBiruAwan.dialogBantalan,
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final skala = MediaQuery.textScalerOf(context).scale(1);
                  final bertumpuk =
                      tombolBatal != null &&
                      (c.maxWidth <
                              UkuranUmpanBalikBiruAwan.dialogBertumpukDi ||
                          skala > AmbangLab.hurufBesar);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UbinUmpanBalik(
                                ikon: ikon,
                                warna: bahaya
                                    ? IsiBiruAwan.koralTipis
                                    : IsiBiruAwan.kabut,
                                ukuran: UkuranUmpanBalikBiruAwan.dialogUbin,
                                radius:
                                    UkuranUmpanBalikBiruAwan.dialogUbinRadius,
                                ukuranIkon: UkuranUmpanBalikBiruAwan.dialogIkon,
                              ),
                              const SizedBox(
                                height: UkuranUmpanBalikBiruAwan.dialogCelah,
                              ),
                              Text(
                                judul,
                                style: HurufBiruAwan.judulAnak.copyWith(
                                  color: m.tinta,
                                ),
                              ),
                              if (isi != null && isi!.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  isi!,
                                  style: HurufBiruAwan.keterangan.copyWith(
                                    color: m.tinta2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (tombolBatal == null)
                        tombolAksi
                      else if (bertumpuk) ...[
                        tombolAksi,
                        const SizedBox(
                          height: UkuranUmpanBalikBiruAwan.dialogCelahTombol,
                        ),
                        tombolBatal,
                      ] else
                        Row(
                          children: [
                            Expanded(child: tombolBatal),
                            const SizedBox(
                              width: UkuranUmpanBalikBiruAwan.dialogCelahTombol,
                            ),
                            Expanded(child: tombolAksi),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Membuka [DialogSidik] di atas latar redup navy 42 %. Mengembalikan `true`
/// bila [aksi] diketuk; `false` untuk Batal, ketukan di latar, atau tombol
/// kembali. Muncul dengan pudar 240 ms; "kurangi gerak" = tanpa animasi.
Future<bool> tampilkanDialogSidik(
  BuildContext context, {
  required IconData ikon,
  required String judul,
  required String aksi,
  String? isi,
  String? batal,
  bool bahaya = false,
}) async {
  final latar = WarnaUmpanBalikBiruAwan.of(context).scrim;
  final labelLatar = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final gerak = AppMotion.hormati(context, AppMotion.sedang);
  final hasil = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: labelLatar,
    barrierColor: latar,
    transitionDuration: gerak,
    pageBuilder: (konteks, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: DialogSidik(
            ikon: ikon,
            judul: judul,
            isi: isi,
            aksi: aksi,
            onAksi: () => Navigator.of(konteks).pop(true),
            batal: batal,
            onBatal: () => Navigator.of(konteks).pop(false),
            bahaya: bahaya,
          ),
        ),
      ),
    ),
    transitionBuilder: (konteks, animasi, _, anak) => FadeTransition(
      opacity: CurvedAnimation(parent: animasi, curve: AppMotion.masuk),
      child: anak,
    ),
  );
  return hasil ?? false;
}
