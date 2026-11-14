import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import 'status_tampil.dart';

/// Skala jatuh tempo: batang waktu berpenggaris (satu tik per 30 hari), tik
/// jadwal, penanda "hari ini", dan KATA.
///
/// Batang dipakai hemat: hanya untuk alat "Segera" (jadwal <= 30 hari) dan
/// "Lewat jadwal", atau di layar detail alat ([detail]). Alat "Berlaku" yang
/// masih jauh cukup satu kalimat ("8 bulan lagi. Jadwal 13 Jul 2027"), tanpa
/// batang ([tampilkanBatang]). Batang selalu disertai kata dan tidak membawa
/// arti sendiri: warna hanya menebalkan yang sudah ditulis.
///
/// Geometri (keputusan desain, bukan data):
///
/// - belum lewat: jendela 90 hari; tik jadwal di ujung kanan, penanda "hari
///   ini" bergeser kanan mendekatinya; jarak > 90 hari menempel di kiri;
/// - lewat jadwal: jendela 150 hari; tik jadwal di 80% lebar, ekor merah ke
///   kanan = lamanya terlambat (maksimum 30 hari = 20% lebar). Ekor digambar
///   paling sedikit [ekorMinimum] (8%) supaya terlambat 2 hari tidak tampak
///   seperti hiasan; angka sebenarnya ada di kalimat dan di [posisi].
///
/// [hari] `null` = server menandai alat `overdue` tanpa tanggal: jumlah hari
/// tidak boleh ditebak, jadi yang tampil hanya "Lewat jadwal. Tanggal belum
/// diketahui", TANPA batang, ekor, atau angka (model `AlatJatuhTempo.hari`).
///
/// Pembaca layar menerima satu kalimat. [tanggal] sudah diformat pemanggil
/// ("1 Nov 2026", sesuai locale); [kata] mengganti kalimat bawaan bahasa
/// Indonesia ([kataTempo]), mis. dengan terjemahan.
class SkalaTempo extends StatelessWidget {
  const SkalaTempo({
    super.key,
    required this.hari,
    this.tanggal,
    this.kata,
    this.detail = false,
  });

  /// Sisa hari menuju jadwal; negatif = lewat; `null` = lewat jadwal tanpa
  /// tanggal yang diketahui.
  final int? hari;

  /// Tanggal jadwal kalibrasi ulang, siap tampil. `null` bila tidak diketahui.
  final String? tanggal;

  /// Kalimat pengganti. Bawaan: [kataTempo].
  final String? kata;

  /// Layar detail alat: batang selalu tampil, lengkap dengan label "Hari ini"
  /// dan "Jadwal".
  final bool detail;

  /// Satu tik tiap sekian hari.
  static const int hariPerTik = 30;

  /// Jendela saat belum lewat jadwal.
  static const int jendelaHari = 90;

  /// Saat lewat jadwal: bagian sebelum jadwal dan bagian ekor sesudahnya.
  static const int jendelaSebelumLewat = 120;
  static const int jendelaSesudahLewat = 30;

  /// Lebar tampak minimum ekor lewat jadwal (pecahan lebar batang).
  static const double ekorMinimum = 0.08;

  /// Apakah batang digambar: untuk "Segera" dan "Lewat jadwal" (hari <= 30)
  /// atau bila [detail].
  /// Tanpa [hari] (tanggal tak diketahui) tidak ada yang bisa diposisikan,
  /// jadi tidak ada batang.
  static bool tampilkanBatang(int? hari, {bool detail = false}) =>
      hari != null && (detail || hari <= StatusTampil.batasSegeraHari);

  /// Posisi penanda "hari ini" dan tik jadwal sepanjang batang, 0 (kiri)
  /// sampai 1 (kanan).
  static ({double sekarang, double jadwal}) posisi(int hari) {
    if (hari >= 0) {
      final sisa = math.min(hari, jendelaHari);
      return (sekarang: 1 - sisa / jendelaHari, jadwal: 1.0);
    }
    const total = jendelaSebelumLewat + jendelaSesudahLewat;
    const jadwal = jendelaSebelumLewat / total;
    final telat = math.min(-hari, jendelaSesudahLewat);
    return (sekarang: jadwal + telat / total, jadwal: jadwal);
  }

  /// Posisi yang DIGAMBAR: sama dengan [posisi], kecuali ekor lewat jadwal
  /// dilebarkan sampai [ekorMinimum] (dijepit di ujung kanan batang).
  static ({double sekarang, double jadwal}) posisiTampak(int hari) {
    final p = posisi(hari);
    if (hari >= 0) return p;
    return (
      sekarang: math.min(math.max(p.sekarang, p.jadwal + ekorMinimum), 1.0),
      jadwal: p.jadwal,
    );
  }

  /// Posisi tik bulanan (selain tik jadwal), 0..1.
  static List<double> posisiTik(int hari) {
    final total = hari >= 0
        ? jendelaHari
        : jendelaSebelumLewat + jendelaSesudahLewat;
    final jadwal = posisi(hari).jadwal;
    final hasil = <double>[];
    for (var h = hariPerTik; h < total; h += hariPerTik) {
      final p = h / total;
      if ((p - jadwal).abs() > 1e-9) hasil.add(p);
    }
    return hasil;
  }

  /// Kalimat bawaan (Indonesia) untuk [hari] menuju jadwal [tanggal]:
  /// "Lewat 12 hari. Jadwal 1 Nov 2026", "12 hari lagi. Jadwal ...",
  /// "8 bulan lagi. Jadwal ..." (lebih dari 60 hari).
  ///
  /// [hari] `null`: "Lewat jadwal. Tanggal belum diketahui" (tanpa angka).
  /// [tanggal] `null` dengan [hari] terisi: kalimat tanpa bagian "Jadwal ...".
  static String kataTempo(int? hari, String? tanggal) {
    if (hari == null) return 'Lewat jadwal. Tanggal belum diketahui';
    final jadwal = tanggal == null ? '' : '. Jadwal $tanggal';
    if (hari < 0) return 'Lewat ${-hari} hari$jadwal';
    if (hari == 0) return 'Hari ini$jadwal';
    if (hari <= 60) return '$hari hari lagi$jadwal';
    return '${hari ~/ hariPerTik} bulan lagi$jadwal';
  }

  /// Penjajaran (`Alignment.x`, -1 kiri sampai 1 kanan) yang memusatkan label
  /// selebar [lebarLabel] pada titik [posisi] (0 sampai 1) di batang selebar
  /// [lebar], dijepit supaya label tidak keluar dari batang.
  @visibleForTesting
  static double biasTengah({
    required double lebar,
    required double lebarLabel,
    required double posisi,
  }) {
    final ruang = lebar - lebarLabel;
    if (ruang <= 0) return -1;
    final kiri = (lebar * posisi - lebarLabel / 2).clamp(0.0, ruang);
    return kiri / ruang * 2 - 1;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final kalimat = kata ?? kataTempo(hari, tanggal);

    final teks = Text(
      kalimat,
      style: detail
          ? t.titleMedium
          : t.bodyMedium?.copyWith(color: s.onSurface),
    );

    final Widget isi = tampilkanBatang(hari, detail: detail)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Batang(hari: hari!, tanggal: tanggal, detail: detail),
              const SizedBox(height: AppSpacing.sm),
              teks,
            ],
          )
        : teks;

    return Semantics(label: kalimat, excludeSemantics: true, child: isi);
  }
}

class _Batang extends StatelessWidget {
  const _Batang({
    required this.hari,
    required this.tanggal,
    required this.detail,
  });

  final int hari;
  final String? tanggal;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final m = SidikMaterial.of(context);
    final lewat = hari < 0;
    final p = SkalaTempo.posisiTampak(hari);
    final tik = SkalaTempo.posisiTik(hari);
    final gayaLabel = t.labelMedium?.copyWith(color: s.onSurface);
    final skala = MediaQuery.textScalerOf(context);
    final arah = Directionality.of(context);
    const atasTrek = (UkuranTikLab.penanda - UkuranTikLab.trek) / 2;

    return LayoutBuilder(
      builder: (context, batas) {
        final lebar = batas.maxWidth;

        Widget label(String teks, double posisi) {
          final pengukur = TextPainter(
            text: TextSpan(
              text: teks,
              style: DefaultTextStyle.of(context).style.merge(gayaLabel),
            ),
            textDirection: arah,
            textScaler: skala,
            maxLines: 1,
          )..layout();
          final lebarLabel = pengukur.width;
          pengukur.dispose();
          return Align(
            alignment: Alignment(
              SkalaTempo.biasTengah(
                lebar: lebar,
                lebarLabel: lebarLabel,
                posisi: posisi,
              ),
              0,
            ),
            child: Text(teks, style: gayaLabel),
          );
        }

        Widget potong(Key kunci, double dari, double sampai, Color warna) =>
            Positioned(
              key: kunci,
              left: lebar * dari,
              width: lebar * (sampai - dari),
              top: atasTrek,
              height: UkuranTikLab.trek,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: warna,
                  borderRadius: BorderRadius.circular(BentukLab.sel),
                ),
              ),
            );

        Widget batang(
          Key kunci,
          double posisi,
          double tebal,
          double tinggi,
          Color warna,
        ) => Positioned(
          key: kunci,
          left: (lebar * posisi - tebal / 2).clamp(0.0, lebar - tebal),
          width: tebal,
          top: (UkuranTikLab.penanda - tinggi) / 2,
          height: tinggi,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: warna,
              borderRadius: BorderRadius.circular(BentukLab.sel),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (detail) ...[
              label('Hari ini', p.sekarang),
              const SizedBox(height: AppSpacing.xs),
            ],
            SizedBox(
              height: UkuranTikLab.penanda,
              child: Stack(
                children: [
                  potong(
                    const Key('skala-tempo-batang'),
                    0,
                    1,
                    s.outlineVariant,
                  ),
                  potong(
                    const Key('skala-tempo-isi'),
                    0,
                    lewat ? p.jadwal : p.sekarang,
                    s.primary,
                  ),
                  if (lewat)
                    potong(
                      const Key('skala-tempo-ekor'),
                      p.jadwal,
                      p.sekarang,
                      m.gagal,
                    ),
                  for (var i = 0; i < tik.length; i++)
                    batang(
                      Key('skala-tempo-tik-$i'),
                      tik[i],
                      AppUkuran.garis,
                      UkuranTikLab.tikBulan,
                      m.garisTegas,
                    ),
                  batang(
                    const Key('skala-tempo-jadwal'),
                    p.jadwal,
                    UkuranTikLab.batangJadwal,
                    UkuranTikLab.penanda,
                    s.onSurface,
                  ),
                  batang(
                    const Key('skala-tempo-hari-ini'),
                    p.sekarang,
                    UkuranTikLab.batangHariIni,
                    UkuranTikLab.penanda,
                    lewat ? m.gagal : s.primary,
                  ),
                ],
              ),
            ),
            if (detail) ...[
              const SizedBox(height: AppSpacing.xs),
              label(tanggal == null ? 'Jadwal' : 'Jadwal $tanggal', p.jadwal),
            ],
          ],
        );
      },
    );
  }
}
