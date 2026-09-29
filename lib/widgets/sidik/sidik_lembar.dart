import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';

/// Keadaan satu sel di lembar kerja.
///
/// Namanya sengaja sejajar dengan `TandaSel` di
/// `lib/screens/calibration/lembar_kerja_state.dart` supaya pemetaannya
/// sebaris, bukan terjemahan.
enum TandaSelSidik {
  /// Diketik manusia. Tinta pulpen.
  pulpen,

  /// Datang dari foto/OCR. **Pensil** — karena memang belum dipastikan
  /// manusia. Aturan lama tetap berlaku: `keyakinan == null` berarti TIDAK
  /// DIKETAHUI, bukan "kemungkinan benar".
  pensil,

  /// Ditandai admin waktu mengembalikan sesi. Coretan pulpen merah.
  revisi,

  /// Belum diisi.
  kosong,

  /// Terkunci karena alternatif satuan.
  terkunci,
}

/// Satu sel angka di lembar kerja — kotak isian di formulir, dengan garis
/// bawah tebal tempat menulis.
///
/// ```dart
/// SelLembar(
///   nilai: '4,012',
///   tanda: TandaSelSidik.pensil,
///   onTap: () => _fokus(titik, ulang),
/// )
/// ```
class SelLembar extends StatelessWidget {
  const SelLembar({
    super.key,
    this.nilai,
    this.tanda = TandaSelSidik.pulpen,
    this.fokus = false,
    this.onTap,
    this.lebar = 72,
    this.label,
  });

  final String? nilai;
  final TandaSelSidik tanda;
  final bool fokus;
  final VoidCallback? onTap;
  final double lebar;

  /// Dibacakan pembaca layar, mis. "Titik 4,00 pH, repeat 2".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final kosong = nilai == null || nilai!.isEmpty;

    final (Color teks, Color dasar, Color bawah, bool miring) = switch (tanda) {
      TandaSelSidik.pulpen => (m.tinta, m.kertas, m.tinta2, false),
      TandaSelSidik.pensil => (m.pensil, m.awasTipis, m.awas, true),
      TandaSelSidik.revisi => (m.gagal, m.gagalTipis, m.gagal, false),
      TandaSelSidik.terkunci => (m.tinta2, m.kertas2, m.kertasTepi, false),
      TandaSelSidik.kosong => (m.tinta2, m.kertas, m.tinta2, false),
    };

    final keterangan = switch (tanda) {
      TandaSelSidik.pensil => 'dari foto, perlu dicek',
      TandaSelSidik.revisi => 'ditandai admin',
      TandaSelSidik.terkunci => 'terkunci',
      _ => null,
    };

    return Semantics(
      label: [
        if (label != null) label,
        if (kosong) 'kosong' else nilai,
        if (keterangan != null) keterangan,
      ].whereType<String>().join(', '),
      excludeSemantics: true,
      button: onTap != null,
      child: GestureDetector(
        onTap: tanda == TandaSelSidik.terkunci ? null : onTap,
        child: Container(
          width: lebar,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: kosong ? Alignment.center : Alignment.centerRight,
          decoration: BoxDecoration(
            color: dasar,
            // TANPA borderRadius: sisi-sisi sel ini berbeda warna (garis bawah
            // = tanda isian), dan Flutter menolak borderRadius pada Border yang
            // warnanya tidak seragam. Sel lembar kerja bersudut tajam memang
            // lebih mirip formulir cetak.
            border: Border(
              top: BorderSide(color: fokus ? m.biru : m.kertasTepi),
              left: BorderSide(color: fokus ? m.biru : m.kertasTepi),
              right: BorderSide(color: fokus ? m.biru : m.kertasTepi),
              bottom: BorderSide(color: fokus ? m.biru : bawah, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 2,
                offset: const Offset(0, 1),
                blurStyle: BlurStyle.inner,
              ),
              if (fokus)
                BoxShadow(
                  color: m.biru.withValues(alpha: 0.22),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
            ],
          ),
          child: kosong
              ? Text(
                  '—',
                  style: TextStyle(
                    color: m.tinta2.withValues(alpha: 0.55),
                    fontSize: 15,
                  ),
                )
              : Text(
                  nilai!,
                  style: SidikTheme.gayaAngka(warna: teks).copyWith(
                    fontStyle: miring ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Sel yang benar-benar bisa diketik. Bungkus [TextField] dengan tampilan
/// yang sama persis dengan [SelLembar].
class SelLembarIsi extends StatelessWidget {
  const SelLembarIsi({
    super.key,
    required this.controller,
    this.tanda = TandaSelSidik.pulpen,
    this.lebar = 72,
    this.label,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final TandaSelSidik tanda;
  final double lebar;
  final String? label;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final (Color teks, Color dasar, Color bawah) = switch (tanda) {
      TandaSelSidik.pensil => (m.pensil, m.awasTipis, m.awas),
      TandaSelSidik.revisi => (m.gagal, m.gagalTipis, m.gagal),
      _ => (m.tinta, m.kertas, m.tinta2),
    };

    return Semantics(
      label: label,
      textField: true,
      child: SizedBox(
        width: lebar,
        height: 48,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Teknisi Indonesia mengetik koma. Titik tetap diterima dan
          // dinormalkan di lapisan state, bukan di sini.
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
          ],
          style: SidikTheme.gayaAngka(warna: teks),
          decoration: InputDecoration(
            hintText: '—',
            isDense: true,
            filled: true,
            fillColor: dasar,
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            border: _tepi(bawah),
            enabledBorder: _tepi(bawah),
            focusedBorder: _tepi(m.biru),
          ),
        ),
      ),
    );
  }

  InputBorder _tepi(Color bawah) => UnderlineInputBorder(
    borderRadius: BorderRadius.circular(3),
    borderSide: BorderSide(color: bawah, width: 2),
  );
}

/// Meteran bergaya skala vernier: alur cekung berisi batang berkilau, dengan
/// tick tiap 10%.
///
/// Dipakai buat progres pengisian lembar kerja, kelengkapan draf, dan bar di
/// kartu ringkasan.
class SidikMeter extends StatelessWidget {
  const SidikMeter({
    super.key,
    required this.nilai,
    this.nada,
    this.tinggi = 10,
    this.label,
  });

  /// 0..1
  final double nilai;

  /// Kosongkan untuk biru (netral/progres). Isi untuk status.
  final Color? nada;

  final double tinggi;

  /// Dibacakan pembaca layar, mis. "Terisi 14 dari 20 sel".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final warna = nada ?? m.biru;
    final v = nilai.clamp(0.0, 1.0);

    return Semantics(
      label: label ?? 'Progres ${(v * 100).round()} persen',
      value: '${(v * 100).round()}%',
      excludeSemantics: true,
      child: Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: m.kertas2,
          borderRadius: BorderRadius.circular(tinggi / 2),
          border: Border.all(color: m.kertasTepi),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 3,
              offset: const Offset(0, 2),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tinggi / 2),
          child: Stack(
            children: [
              // Positioned.fill memberi batas ketat ke FractionallySizedBox.
              // Tanpa itu, di dalam Stack dia dapat batas longgar dan
              // tingginya jadi nol — batangnya hilang sama sekali.
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(warna, Colors.white, 0.28)!,
                          warna,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Tick tiap 10% — yang bikin dia kebaca sebagai skala ukur,
              // bukan bar progres biasa.
              Positioned.fill(
                child: CustomPaint(painter: _PelukisTick(m.meja)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PelukisTick extends CustomPainter {
  const _PelukisTick(this.warna);

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = warna.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cat);
    }
  }

  @override
  bool shouldRepaint(_PelukisTick old) => old.warna != warna;
}
