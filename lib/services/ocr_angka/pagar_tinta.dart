import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ukuran "tinta" satu crop sel (peta tinta ala praproses model A rig):
/// kertas = persentil 90 abu-abu, tinta = `1 - abu/kertas` (0 kertas, 1 gelap).
class UkuranTinta {
  const UkuranTinta({required this.gelap, required this.kontras});

  /// Porsi piksel di jendela tengah dengan tinta > [PagarTinta.batasGelap].
  final double gelap;

  /// Persentil 98 dikurangi median tinta di jendela tengah.
  final double kontras;
}

/// Pagar tinta: crop yang praktis tak berisi apa-apa tidak dikirim ke model.
///
/// ## Apa yang dijamin (dan tidak)
///
/// Crop ditolak hanya bila KEDUA ukuran rendah ([gelapMin], [kontrasMin]).
/// Angkanya dipilih di set uji sintetis rig (5.900 crop; `pagar_tinta` di
/// dokumen `docs/ocr-angka-onnx.md`): pada angka ini 0 dari 4.400 sel berisi
/// dan 0 dari 908 jawaban benar ikut tertolak, 12,8% sel kosong biasa dan 5,3%
/// sel kosong sulit tertolak.
///
/// Pagar ini TIDAK menyaring garis tabel atau noise: ukuran tinta tidak bisa
/// memisahkan garis dari tulisan tanpa membuang jawaban benar (setiap ambang
/// yang lebih ketat membuang 7–34% jawaban benar). Penahan sel kosong bergaris
/// adalah gerbang format + ambang `jalur`, bukan pagar ini. Hemat waktu per
/// lembar jauh di bawah perkiraan awal (25–30% sel kosong): ±13% sel kosong.
class PagarTinta {
  const PagarTinta._();

  /// Tinta di atas ini dihitung "gelap".
  static const batasGelap = 0.30;

  /// Pinggiran yang diabaikan (porsi tiap sisi): garis sel dan sisa tetangga.
  static const margin = 0.15;

  static const gelapMin = 0.002;
  static const kontrasMin = 0.02;

  /// Ukur [potongan]. Hasilnya dihitung ulang dari piksel, tanpa efek samping.
  static UkuranTinta ukur(img.Image potongan) {
    final w = potongan.width;
    final h = potongan.height;
    // Citra tanpa piksel: tidak ada tinta (bukan galat).
    if (w < 1 || h < 1) return const UkuranTinta(gelap: 0, kontras: 0);

    final abu = _abu(potongan);

    // Kertas = persentil 90 (nilai ke ceil(0,9 n) dari yang terkecil), min 1.
    final hist = List<int>.filled(256, 0);
    for (final v in abu) {
      hist[v]++;
    }
    final target = (0.9 * abu.length).ceil();
    var kumulatif = 0;
    var kertas = 255;
    for (var v = 0; v < 256; v++) {
      kumulatif += hist[v];
      if (kumulatif >= target) {
        kertas = v;
        break;
      }
    }
    if (kertas < 1) kertas = 1;

    var my = (h * margin).round();
    var mx = (w * margin).round();
    if (h - 2 * my < 2 || w - 2 * mx < 2) {
      my = 0;
      mx = 0;
    }

    final tinta = <double>[];
    var gelap = 0;
    for (var y = my; y < h - my; y++) {
      for (var x = mx; x < w - mx; x++) {
        final t = 1.0 - (abu[y * w + x] / kertas).clamp(0.0, 1.0);
        tinta.add(t);
        if (t > batasGelap) gelap++;
      }
    }
    tinta.sort();

    return UkuranTinta(
      gelap: gelap / tinta.length,
      kontras: _persentil(tinta, 0.98) - _persentil(tinta, 0.5),
    );
  }

  /// `true` bila crop punya cukup tinta untuk dibaca.
  static bool adaTinta(UkuranTinta u) =>
      !(u.gelap < gelapMin && u.kontras < kontrasMin);

  /// Persentil dengan interpolasi linier (sama dengan `np.percentile`).
  static double _persentil(List<double> terurut, double q) {
    final pos = q * (terurut.length - 1);
    final bawah = pos.floor();
    final atas = pos.ceil();
    return terurut[bawah] + (terurut[atas] - terurut[bawah]) * (pos - bawah);
  }

  /// Abu-abu bilangan bulat `(299 R + 587 G + 114 B + 500) ~/ 1000` per piksel.
  static Uint8List _abu(img.Image c) {
    var a = c;
    if (a.hasPalette || a.format != img.Format.uint8 || a.numChannels != 3) {
      a = a.convert(format: img.Format.uint8, numChannels: 3);
    }
    final b = a.getBytes(order: img.ChannelOrder.rgb);
    final n = a.width * a.height;
    final keluar = Uint8List(n);
    for (var i = 0; i < n; i++) {
      keluar[i] =
          (b[i * 3] * 299 + b[i * 3 + 1] * 587 + b[i * 3 + 2] * 114 + 500) ~/
          1000;
    }
    return keluar;
  }
}
