import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Masukan model: tensor `[1, 3, 48, lebar]` (urutan kanal B, G, R).
class TensorSel {
  const TensorSel({
    required this.data,
    required this.lebar,
    required this.lebarIsi,
  });

  final Float32List data;

  /// Lebar kanvas (paling sedikit [PraprosesSel.lebarMin]); sisanya nol.
  final int lebar;

  /// Lebar bagian yang berisi citra sel, dalam piksel.
  final int lebarIsi;

  static const tinggi = PraprosesSel.tinggi;
  static const kanal = 3;
}

/// Praproses crop sel → masukan PP-OCR rec. SAMA dengan `MesinPaddle._praproses`
/// di rig `sidik-ocr-eval` (`sidik_ocr/mesin.py`), yang mengikuti
/// `resize_norm_img` PaddleOCR:
///
///  1. RGB → BGR;
///  2. tinggi 48, lebar = `ceil(48 * lebar / tinggi)` (paling kecil 16),
///     bilinear ala OpenCV `INTER_LINEAR` (titik tengah piksel, koefisien 11-bit);
///  3. `(x/255 - 0,5) / 0,5`;
///  4. tempel di kiri kanvas lebar `max(320, lebar)`, sisanya NOL (setelah
///     normalisasi).
///
/// Crop yang diberikan harus sudah memuat padding sel seperti set uji; padding
/// bukan urusan fungsi ini. Pengubah ukuran sengaja ditulis sendiri (bukan
/// `copyResize` milik paket `image`) supaya bobotnya sama dengan OpenCV: selisih
/// interpolasi menggeser skor `jalur` dan ambang 0,990 dipilih di rig.
class PraprosesSel {
  const PraprosesSel._();

  static const tinggi = 48;
  static const lebarMin = 320;

  /// Batas atas lebar kanvas dan sisi crop: sel angka tidak pernah selebar itu.
  /// Crop di atasnya (geometri salah, foto rusak) tidak dibaca; tanpa batas,
  /// crop 1 piksel tinggi menghasilkan tensor ratusan ribu piksel lebar.
  static const lebarMaks = 2048;
  static const sisiMaks = 2048;

  /// Crop `sw×sh` masih wajar dibaca? (sisi ≤ [sisiMaks], lebar kanvas ≤
  /// [lebarMaks]).
  static bool ukuranWajar(int sw, int sh) =>
      sw >= 1 &&
      sh >= 1 &&
      sw <= sisiMaks &&
      sh <= sisiMaks &&
      math.max(16, (tinggi * sw / sh).ceil()) <= lebarMaks;
  static const _bitKoef = 11;
  static const _skalaKoef = 1 << _bitKoef;

  static TensorSel proses(img.Image potongan) {
    final sw = potongan.width;
    final sh = potongan.height;
    if (!ukuranWajar(sw, sh)) {
      throw ArgumentError('ukuran potongan tak wajar ($sw×$sh)');
    }

    final rw = math.max(16, (tinggi * sw / sh).ceil());
    final kecil = ubahUkuranBgr(_rgb(potongan), sw, sh, rw, tinggi);
    final lebar = math.max(lebarMin, rw);
    final data = Float32List(TensorSel.kanal * tinggi * lebar);

    for (var y = 0; y < tinggi; y++) {
      for (var x = 0; x < rw; x++) {
        final dari = (y * rw + x) * 3;
        for (var c = 0; c < 3; c++) {
          data[(c * tinggi + y) * lebar + x] = kecil[dari + c] / 127.5 - 1.0;
        }
      }
    }

    return TensorSel(data: data, lebar: lebar, lebarIsi: rw);
  }

  /// Bita RGB padat (3 kanal, 8 bit) apa pun format asal citranya.
  static Uint8List _rgb(img.Image c) {
    var a = c;
    if (a.hasPalette || a.format != img.Format.uint8 || a.numChannels != 3) {
      a = a.convert(format: img.Format.uint8, numChannels: 3);
    }
    final b = a.getBytes(order: img.ChannelOrder.rgb);
    if (b.length != a.width * a.height * 3) {
      throw StateError('buffer citra ${b.length} bita, bukan RGB padat');
    }
    return b;
  }

  /// RGB `sw×sh` → BGR `dw×dh` (urutan baris, kolom, kanal), meniru
  /// `cv2.resize(..., INTER_LINEAR)` untuk citra 8-bit: bobot dibulatkan ke
  /// 11 bit, lintasan horizontal lalu vertikal, pembulatan di akhir (`>> 22`).
  ///
  /// OpenCV memakai jalur SIMD untuk lintasan vertikal yang bisa berbeda ±1
  /// tingkat abu dari rumus skalar ini; tes paritas mengizinkan ±1.
  static Uint8List ubahUkuranBgr(
    Uint8List rgb,
    int sw,
    int sh,
    int dw,
    int dh,
  ) {
    final (xofs, xa0, xa1) = _koefisien(sw, dw);
    final (yofs, ya0, ya1) = _koefisien(sh, dh);

    // Lintasan horizontal untuk SEMUA baris sumber (kecil: ≤ 100×330 piksel).
    final h = Int32List(sh * dw * 3);
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < dw; x++) {
        final tetangga = xofs[x] + 1 < sw ? xofs[x] + 1 : sw - 1;
        final s0 = (y * sw + xofs[x]) * 3;
        final s1 = (y * sw + tetangga) * 3;
        final o = (y * dw + x) * 3;
        for (var c = 0; c < 3; c++) {
          h[o + c] = rgb[s0 + c] * xa0[x] + rgb[s1 + c] * xa1[x];
        }
      }
    }

    final keluar = Uint8List(dh * dw * 3);
    for (var y = 0; y < dh; y++) {
      final r0 = yofs[y] * dw * 3;
      final r1 = (yofs[y] + 1 < sh ? yofs[y] + 1 : sh - 1) * dw * 3;
      for (var i = 0; i < dw * 3; i++) {
        final v = (ya0[y] * h[r0 + i] + ya1[y] * h[r1 + i] + (1 << 21)) >> 22;
        final x = i ~/ 3;
        final c = i % 3;
        // RGB → BGR: kanal sumber 0 (R) tinggal di indeks 2.
        keluar[(y * dw + x) * 3 + (2 - c)] = v < 0 ? 0 : (v > 255 ? 255 : v);
      }
    }

    return keluar;
  }

  /// Posisi sumber + dua bobot 11-bit per piksel tujuan (`resizeGeneric_`).
  static (Int32List, Int32List, Int32List) _koefisien(int ds, int dd) {
    final ofs = Int32List(dd);
    final a0 = Int32List(dd);
    final a1 = Int32List(dd);
    final skala = 1.0 / (dd / ds);

    for (var i = 0; i < dd; i++) {
      var fx = _f32((i + 0.5) * skala - 0.5);
      var sx = fx.floor();
      fx = _f32(fx - sx);
      if (sx < 0) {
        fx = 0;
        sx = 0;
      }
      if (sx >= ds - 1) {
        fx = 0;
        sx = ds - 1;
      }
      ofs[i] = sx;
      a0[i] = _bulat(_f32(_f32(1.0 - fx) * _skalaKoef));
      a1[i] = _bulat(_f32(fx * _skalaKoef));
    }

    return (ofs, a0, a1);
  }

  static final _f32Buf = Float32List(1);
  static double _f32(double v) {
    _f32Buf[0] = v;
    return _f32Buf[0];
  }

  /// `cvRound`: bulatkan ke genap bila tepat di tengah.
  static int _bulat(double v) {
    final f = v.floorToDouble();
    final d = v - f;
    if (d < 0.5) return f.toInt();
    if (d > 0.5) return f.toInt() + 1;
    return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
  }
}
