import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ukuran "tinta" satu crop sel (peta tinta ala praproses model A rig):
/// kertas = persentil 90 abu-abu, tinta = `1 - abu/kertas` (0 kertas, 1 gelap).
class UkuranTinta {
  const UkuranTinta({required this.gelap, required this.kontras});

  /// Porsi piksel di jendela tengah dengan tinta > [PagarTinta.batasGelap].
  /// SATU-SATUNYA ukuran yang memutuskan [PagarTinta.adaTinta].
  final double gelap;

  /// Persentil 98 dikurangi median tinta di jendela tengah. Hanya untuk
  /// diagnostik: TIDAK lagi ikut memutuskan (lihat [PagarTinta]).
  final double kontras;
}

/// Pagar tinta: crop yang praktis tak berisi apa-apa tidak dikirim ke model.
///
/// ## Apa yang menentukan (berubah 13 Nov 2026, foto nyata)
///
/// Dulu crop ditolak bila `gelap < 0,002` DAN `kontras < 0,02` (diukur di 5.900
/// crop SINTETIS). Di dua foto nyata cabang `kontras` kena tekstur kertas:
/// median kontras sel kosong 0,031, jadi hanya 11 dari 53 sel kosong yang
/// tertolak. `gelap` saja memisahkan bersih. Angka `gelap` per sumber crop
/// (SEMUA in-sample: 53 sel kosong, 95 sel berisi, dua foto; alat paritas
/// `tool/ukur_pemotong_sel.dart`, docs/ocr-angka-onnx.md §12):
///
/// | crop | sel kosong maks | sel berisi min |
/// |---|---|---|
/// | rig, sel utuh ternormalisasi (`norm_app`) | 0,0000 | 0,063 |
/// | rig, varian D Python (`potong_luas`) | 0,013 | 0,033 |
/// | Dart `PemotongSel`, setelan rig mutlak | 0,0000 | 0,083 (Piston), 0,144 (Sieve) |
/// | Dart `PemotongSel`, setelan produksi | 0,0000 | 0,080 (Piston), 0,206 (Sieve) |
///
/// Maka sekarang HANYA [gelapMin] yang memutuskan. Tidak ada cabang kontras.
///
/// ## Tinta pudar
///
/// `PemotongSel` menganggap tinta bila abu ternormalisasi ≤ 0,78 × kertas,
/// sedangkan [batasGelap] menghitung "gelap" hanya di bawah 0,70 × kertas.
/// Tinta pudar (rasio 0,70–0,78) lolos pemotong tetapi `gelap` = 0 di sini.
/// `MesinAngka.bacaPotongan` memperlakukan crop yang ADA tetapi ditolak pagar
/// sebagai `perluCek` (`AlasanSelAngka.tintaPudar`), bukan `kosong`.
///
/// ## Yang dijamin (dan tidak)
///
/// Pagar ini TIDAK menyaring garis tabel: ukuran tinta tidak memisahkan garis
/// dari tulisan. Itu tugas `PemotongSel` (garis dihapus sebelum diukur) dan,
/// sesudahnya, gerbang format + ambang `jalur`.
///
/// ## Ambang SEMENTARA
///
/// [gelapMin] dipilih dari DUA foto (95 sel berisi, 53 sel kosong) dan berlaku
/// pada crop hasil `PemotongSel`; pada crop mentah satu goresan tipis 1 px di
/// sel lebar kini tidak lolos lagi (lihat tes). Perlu data lebih banyak
/// (docs/ocr-angka-onnx.md §8) sebelum diperlakukan sebagai angka yang terbukti.
class PagarTinta {
  const PagarTinta._();

  /// Tinta di atas ini dihitung "gelap".
  static const batasGelap = 0.30;

  /// Pinggiran yang diabaikan (porsi tiap sisi): garis sel dan sisa tetangga.
  static const margin = 0.15;

  /// Porsi minimum piksel gelap di jendela tengah agar crop dianggap berisi.
  /// Sementara, IN-SAMPLE dari 2 foto: pada crop varian D Python sel kosong maks
  /// 0,013 dan sel berisi min 0,033; pada crop Dart sel kosong maks 0,0000 dan
  /// sel berisi min 0,08 (tabel di atas). Rentang kasar yang masuk akal
  /// 0,02–0,03; diambil ujung bawah: salah menahan sel kosong = satu sel
  /// tambahan untuk dicek teknisi, salah membuang sel berisi = tulisan hilang
  /// diam-diam. Batasnya dikunci dari dua sisi oleh tes kerapatan antara
  /// (0,014 ditolak, 0,026 lolos).
  static const gelapMin = 0.02;

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

  /// `true` bila crop punya cukup tinta untuk dibaca. Hanya `gelap` yang
  /// menentukan; ditulis `>=` supaya nilai NaN jatuh ke "tidak ada tinta".
  static bool adaTinta(UkuranTinta u) => u.gelap >= gelapMin;

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
