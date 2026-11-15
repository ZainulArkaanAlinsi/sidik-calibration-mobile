import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';

/// Keadaan satu langkah [StepperTegak].
enum KeadaanLangkah {
  /// Bulat 32 primer + centang putih.
  selesai,

  /// Primer dengan cincin awan 4: langkah yang sedang berjalan.
  sekarang,

  /// Tepi 2 `garisTegas`, isi kertas.
  belum,
}

/// Satu langkah: [judul], [keterangan] opsional, dan [penanda] opsional
/// (mis. `StempelSidik.teks` "Lagi di sini").
class LangkahStepper {
  const LangkahStepper({
    required this.judul,
    required this.keadaan,
    this.keterangan,
    this.penanda,
  });

  final String judul;
  final KeadaanLangkah keadaan;
  final String? keterangan;
  final Widget? penanda;
}

/// Stepper tegak (`Alur.dc.html`, A6 Alur kerja): penanda bulat 32 di kiri,
/// garis penyambung 2 dp, judul 16 di kanan.
///
/// - Keadaan TIDAK hanya warna: judul langkah sekarang 800 (lainnya 600), centang
///   hanya di langkah selesai, dan pembaca layar menerima "Langkah n dari
///   total, selesai / langkah sekarang / belum, judul, keterangan".
/// - Garis ke bawah primer bila langkahnya selesai, selain itu `garisTegas`.
/// - Bukan kontrol: tidak diketuk. Aksi layar (satu tombol utama = langkah
///   berikutnya) ada di luar komponen.
/// - Judul dan keterangan membungkus; baris tumbuh, penyambung memanjang.
class StepperTegak extends StatelessWidget {
  const StepperTegak({super.key, required this.langkah});

  final List<LangkahStepper> langkah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = langkah.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < total; i++)
          _BarisLangkah(
            langkah: langkah[i],
            terakhir: i == total - 1,
            kataSemantik:
                '${l10n.biruAwanLangkahKe(i + 1, total)}, '
                '${switch (langkah[i].keadaan) {
                  KeadaanLangkah.selesai => l10n.biruAwanLangkahSelesai,
                  KeadaanLangkah.sekarang => l10n.biruAwanLangkahSekarang,
                  KeadaanLangkah.belum => l10n.biruAwanLangkahBelum,
                }}',
          ),
      ],
    );
  }
}

class _BarisLangkah extends StatelessWidget {
  const _BarisLangkah({
    required this.langkah,
    required this.terakhir,
    required this.kataSemantik,
  });

  final LangkahStepper langkah;
  final bool terakhir;
  final String kataSemantik;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final s = Theme.of(context).colorScheme;
    final k = langkah.keadaan;
    final selesai = k == KeadaanLangkah.selesai;
    final sekarang = k == KeadaanLangkah.sekarang;

    final Widget penanda = switch (k) {
      KeadaanLangkah.selesai => DecoratedBox(
        decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle),
        child: Center(
          child: Icon(
            Icons.check,
            size: UkuranLanjutBiruAwan.ikonCentang,
            color: s.onPrimary,
          ),
        ),
      ),
      KeadaanLangkah.sekarang => DecoratedBox(
        decoration: BoxDecoration(
          color: s.primary,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(
              color: w.isi(IsiBiruAwan.awan),
              width: UkuranLanjutBiruAwan.stepperCincin,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
        ),
        child: const SizedBox.expand(),
      ),
      KeadaanLangkah.belum => DecoratedBox(
        decoration: BoxDecoration(
          color: m.kertas,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(
              color: m.garisTegas,
              width: UkuranLanjutBiruAwan.stepperTepiBelum,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
        ),
        child: const SizedBox.expand(),
      ),
    };

    final gayaJudul = sekarang
        ? HurufLanjutBiruAwan.judulLangkahSekarang
        : HurufLanjutBiruAwan.judulLangkah;
    final keterangan = langkah.keterangan;

    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: UkuranLanjutBiruAwan.stepperPenanda,
              child: Column(
                children: [
                  Semantics(
                    label: kataSemantik,
                    child: SizedBox.square(
                      dimension: UkuranLanjutBiruAwan.stepperPenanda,
                      child: penanda,
                    ),
                  ),
                  if (!terakhir)
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: UkuranLanjutBiruAwan.stepperGarisMin,
                        ),
                        child: SizedBox(
                          width: UkuranLanjutBiruAwan.stepperGaris,
                          child: ColoredBox(
                            color: selesai ? s.primary : m.garisTegas,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: UkuranLanjutBiruAwan.stepperJarak),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: UkuranLanjutBiruAwan.stepperAtas,
                  bottom: UkuranLanjutBiruAwan.stepperBawah,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langkah.judul,
                      style: gayaJudul.copyWith(
                        color: k == KeadaanLangkah.belum ? m.tinta2 : m.tinta,
                      ),
                    ),
                    if (keterangan != null && keterangan.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: JarakBiruAwan.sisipan,
                        ),
                        child: Text(
                          keterangan,
                          style: HurufBiruAwan.keteranganKecil.copyWith(
                            color: m.tinta2,
                          ),
                        ),
                      ),
                    if (langkah.penanda != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: JarakBiruAwan.sisipan,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: langkah.penanda!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
