import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Satu batang [GrafikBatang].
class BatangGrafik {
  const BatangGrafik({
    required this.label,
    required this.nilai,
    required this.teksNilai,
  });

  /// Nama di bawah batang ("Sen").
  final String label;

  /// Tinggi relatif batang; hanya dipakai menggambar. Nilai negatif atau
  /// bukan angka digambar sebagai batang kosong.
  final double nilai;

  /// Angka yang tampil di atas batang dan dibaca pembaca layar. Teks dari
  /// pemanggil: grafik tidak memformat, membulatkan, atau menghitung.
  final String teksNilai;
}

/// Grafik batang tegak (`BerandaAdmin.dc.html` "Grafik pekerjaan"): angka mono
/// 12 di atas, batang sudut 10, nama di bawah. Batang yang disorot
/// ([sorot], mis. hari ini) `primer`, lainnya `awan`.
///
/// - Tinggi batang = `nilai / nilaiMaks`; [nilaiMaks] bawaan = nilai terbesar
///   (atau 1 bila semua nol, tanpa bagi nol). Nilai 0 tampil sebagai batang
///   kosong, tidak diberi tinggi palsu.
/// - Masuk: batang tumbuh dari dasar 240 ms setelah jeda 240 ms (sekali, tanpa
///   `repeat`). "Kurangi gerak" = langsung penuh. Angkanya TIDAK dianimasikan.
/// - Sorotan tidak hanya warna: nama hari menebal, dan pembaca layar menerima
///   [penandaSorot] ("hari ini") di butir itu.
/// - Semantik: grup berlabel [semantik] bila diberikan; tiap kolom satu node
///   "label, angka" (angka di atas batang tidak dibaca dua kali).
/// - Angka panjang mengecil (`FittedBox`), tidak meluap, juga di 320 dp x 1,3.
class GrafikBatang extends StatefulWidget {
  const GrafikBatang({
    super.key,
    required this.batang,
    this.sorot,
    this.penandaSorot,
    this.semantik,
    this.nilaiMaks,
    this.tinggi = UkuranLanjutBiruAwan.batangTinggi,
  });

  final List<BatangGrafik> batang;

  /// Indeks batang yang disorot (`null` = tidak ada).
  final int? sorot;

  /// Kata untuk pembaca layar pada batang yang disorot ("hari ini").
  final String? penandaSorot;

  /// Nama grafik untuk pembaca layar ("Grafik pekerjaan, 7 hari").
  final String? semantik;
  final double? nilaiMaks;
  final double tinggi;

  @override
  State<GrafikBatang> createState() => _GrafikBatangState();
}

class _GrafikBatangState extends State<GrafikBatang>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _tumbuh = const AlwaysStoppedAnimation<double>(1);
  bool _mulai = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mulai) return;
    _mulai = true;
    final gerak = AppMotion.hormati(context, AppMotion.sedang);
    if (gerak == Duration.zero) {
      _c.value = 1;
      return;
    }
    // Jeda satu langkah gerak (240 ms) lalu tumbuh 240 ms: satu pengendali.
    _c.duration = gerak * 2;
    _tumbuh = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.5, 1, curve: AppMotion.masuk),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _tinggiRelatif(double nilai, double maks) {
    if (!nilai.isFinite || nilai <= 0 || maks <= 0) return 0;
    return math.min(1, nilai / maks);
  }

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final data = widget.batang;
    final terbesar = data.fold<double>(
      0,
      (a, b) => b.nilai.isFinite ? math.max(a, b.nilai) : a,
    );
    final maks = widget.nilaiMaks ?? (terbesar > 0 ? terbesar : 1);

    final kolom = <Widget>[];
    for (var i = 0; i < data.length; i++) {
      final b = data[i];
      final disorot = widget.sorot == i;
      final isi = disorot
          ? Theme.of(context).colorScheme.primary
          : w.isi(IsiBiruAwan.awan);
      final penanda = widget.penandaSorot;
      final suaraPembaca = [
        b.label,
        b.teksNilai,
        if (disorot && penanda != null && penanda.isNotEmpty) penanda,
      ].join(', ');
      kolom.add(
        Expanded(
          child: Semantics(
            container: true,
            label: suaraPembaca,
            excludeSemantics: true,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    b.teksNilai,
                    maxLines: 1,
                    style: HurufLanjutBiruAwan.nilaiBatang.copyWith(
                      color: m.tinta,
                    ),
                  ),
                ),
                const SizedBox(height: JarakBiruAwan.sisipan),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tumbuh,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      widthFactor: 1,
                      heightFactor:
                          _tinggiRelatif(b.nilai, maks) * _tumbuh.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isi,
                          borderRadius: BorderRadius.circular(
                            UkuranLanjutBiruAwan.batangRadius,
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: JarakBiruAwan.sisipan),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    b.label,
                    maxLines: 1,
                    style:
                        (disorot
                                ? HurufLanjutBiruAwan.labelBatangSorot
                                : HurufLanjutBiruAwan.labelBatang)
                            .copyWith(color: disorot ? m.biruTinta : m.tinta2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (i != data.length - 1) {
        kolom.add(const SizedBox(width: AppSpacing.sm));
      }
    }

    final grafik = SizedBox(
      height: widget.tinggi,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kolom,
      ),
    );
    final nama = widget.semantik;
    if (nama == null || nama.isEmpty) return grafik;
    return Semantics(container: true, label: nama, child: grafik);
  }
}
