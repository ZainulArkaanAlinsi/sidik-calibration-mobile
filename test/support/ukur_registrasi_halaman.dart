// Metrik page registration terhadap kunci jawaban foto sintetis.
import 'dart:math' as math;

import 'package:sidik_calibration/services/registrasi_halaman/geometri_halaman.dart'
    show TitikHalaman;

import 'foto_sintetis_halaman.dart';

/// Ukuran satu foto. [terdeteksi] false = registrasi menolak (gagal-aman);
/// angka lain null.
class UkuranFoto {
  const UkuranFoto({
    required this.nama,
    required this.terdeteksi,
    this.alasan,
    this.galatSudutPctFoto,
    this.galatSudutPctHalaman,
    this.fraksiIou07,
    this.iouMin,
    this.fraksiGeser025,
    this.jumlahSel = 0,
    this.msDeteksi,
    this.msWarp,
    this.putaran,
  });

  final String nama;
  final bool terdeteksi;
  final String? alasan;

  /// Galat sudut terbesar, % diagonal FOTO (ukuran prototipe: target ≤ 0,5).
  final double? galatSudutPctFoto;

  /// Sama, % diagonal HALAMAN di foto.
  final double? galatSudutPctHalaman;
  final double? fraksiIou07;
  final double? iouMin;
  final double? fraksiGeser025;
  final int jumlahSel;
  final double? msDeteksi;
  final double? msWarp;
  final int? putaran;
}

/// Ukur satu hasil. [sudutDeteksi] `null` = registrasi menolak ([alasan]).
/// Berkas ini sengaja tidak mengimpor kode yang bergantung Flutter, supaya
/// bisa dikompilasi AOT oleh `tool/ukur_registrasi_halaman.dart`.
UkuranFoto ukurSudut(
  String nama,
  FotoSintetis foto,
  List<TitikHalaman>? sudutDeteksi, {
  String? alasan,
  double? msDeteksi,
  double? msWarp,
  int? putaran,
}) {
  if (sudutDeteksi == null) {
    return UkuranFoto(nama: nama, terdeteksi: false, alasan: alasan);
  }

  final benar = foto.sudutBenar;
  final est = sudutDeteksi;

  // Galat sudut tanpa memandang pelabelan (orientasi 90°/180° tidak bisa
  // ditentukan dari bentuk): tiap sudut hasil ke sudut benar terdekat.
  var galat = 0.0;
  for (final e in est) {
    var terdekat = double.infinity;
    for (final b in benar) {
      terdekat = math.min(terdekat, _jarak(e, b));
    }
    galat = math.max(galat, terdekat);
  }
  final diagHalaman =
      (_jarak(benar[0], benar[2]) + _jarak(benar[1], benar[3])) / 2;

  // Selaraskan pelabelan ke kunci untuk IoU sel.
  var rotasiTerbaik = 0;
  var biayaTerbaik = double.infinity;
  for (var r = 0; r < 4; r++) {
    var biaya = 0.0;
    for (var i = 0; i < 4; i++) {
      biaya += _jarak(est[(i + r) % 4], benar[i]);
    }
    if (biaya < biayaTerbaik) {
      biayaTerbaik = biaya;
      rotasiTerbaik = r;
    }
  }
  final sejajar = [for (var i = 0; i < 4; i++) est[(i + rotasiTerbaik) % 4]];
  final w = foto.halamanPt.w;
  final h = foto.halamanPt.h;
  final he = homografiDari4([
    (x: 0.0, y: 0.0),
    (x: w, y: 0.0),
    (x: w, y: h),
    (x: 0.0, y: h),
  ], sejajar)!;
  final heInv = invers3(he);

  final iou = <double>[];
  var geserBesar = 0;
  for (final k in foto.sel) {
    final sudutSel = [
      proyeksi(foto.homografi, k.x, k.y),
      proyeksi(foto.homografi, k.x + k.w, k.y),
      proyeksi(foto.homografi, k.x + k.w, k.y + k.h),
      proyeksi(foto.homografi, k.x, k.y + k.h),
    ];
    final balik = [for (final p in sudutSel) proyeksi(heInv, p.x, p.y)];
    final x0 = balik.map((p) => p.x).reduce(math.min);
    final x1 = balik.map((p) => p.x).reduce(math.max);
    final y0 = balik.map((p) => p.y).reduce(math.min);
    final y1 = balik.map((p) => p.y).reduce(math.max);
    final ix = math.max(0.0, math.min(k.x + k.w, x1) - math.max(k.x, x0));
    final iy = math.max(0.0, math.min(k.y + k.h, y1) - math.max(k.y, y0));
    final irisan = ix * iy;
    final gabungan = k.w * k.h + (x1 - x0) * (y1 - y0) - irisan;
    iou.add(irisan / gabungan);

    final pusatX = balik.map((p) => p.x).reduce((a, b) => a + b) / 4;
    final pusatY = balik.map((p) => p.y).reduce((a, b) => a + b) / 4;
    final geser = math.sqrt(
      math.pow(pusatX - (k.x + k.w / 2), 2) +
          math.pow(pusatY - (k.y + k.h / 2), 2),
    );
    if (geser / k.h > 0.25) geserBesar++;
  }

  return UkuranFoto(
    nama: nama,
    terdeteksi: true,
    galatSudutPctFoto: galat / foto.diagonalFoto * 100,
    galatSudutPctHalaman: galat / diagHalaman * 100,
    fraksiIou07: iou.where((v) => v >= 0.7).length / iou.length,
    iouMin: iou.reduce(math.min),
    fraksiGeser025: geserBesar / iou.length,
    jumlahSel: iou.length,
    msDeteksi: msDeteksi,
    msWarp: msWarp,
    putaran: putaran,
  );
}

double _jarak(TitikHalaman a, TitikHalaman b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// Ringkasan sekumpulan foto — dicetak di log test dan dipakai tool ukur.
class RingkasanUkur {
  RingkasanUkur(this.judul, this.ukuran);

  final String judul;
  final List<UkuranFoto> ukuran;

  List<UkuranFoto> get ok => ukuran.where((u) => u.terdeteksi).toList();

  double get fraksiTerdeteksi => ukuran.isEmpty ? 0 : ok.length / ukuran.length;

  double get galatMaksPctFoto => ok.isEmpty
      ? double.nan
      : ok.map((u) => u.galatSudutPctFoto!).reduce(math.max);

  double get galatMedianPctFoto =>
      _median([for (final u in ok) u.galatSudutPctFoto!]);

  double get galatMaksPctHalaman => ok.isEmpty
      ? double.nan
      : ok.map((u) => u.galatSudutPctHalaman!).reduce(math.max);

  /// % sel dengan IoU ≥ 0,7, dihitung atas SEMUA sel foto yang terdeteksi.
  double get fraksiSelIou07 {
    var baik = 0.0;
    var total = 0;
    for (final u in ok) {
      baik += u.fraksiIou07! * u.jumlahSel;
      total += u.jumlahSel;
    }

    return total == 0 ? double.nan : baik / total;
  }

  double get fraksiSelGeser025 {
    var buruk = 0.0;
    var total = 0;
    for (final u in ok) {
      buruk += u.fraksiGeser025! * u.jumlahSel;
      total += u.jumlahSel;
    }

    return total == 0 ? double.nan : buruk / total;
  }

  double get iouMinGlobal =>
      ok.isEmpty ? double.nan : ok.map((u) => u.iouMin!).reduce(math.min);

  double get msDeteksiMedian => _median([
    for (final u in ok)
      if (u.msDeteksi != null) u.msDeteksi!,
  ]);

  double get msDeteksiMaks {
    final v = [
      for (final u in ok)
        if (u.msDeteksi != null) u.msDeteksi!,
    ];

    return v.isEmpty ? double.nan : v.reduce(math.max);
  }

  double get msWarpMedian => _median([
    for (final u in ok)
      if (u.msWarp != null) u.msWarp!,
  ]);

  Map<String, int> get alasanGagal {
    final peta = <String, int>{};
    for (final u in ukuran.where((u) => !u.terdeteksi)) {
      peta[u.alasan!] = (peta[u.alasan!] ?? 0) + 1;
    }

    return peta;
  }

  @override
  String toString() =>
      '$judul: terdeteksi ${ok.length}/${ukuran.length} '
      '| galat sudut % diag foto: median ${galatMedianPctFoto.toStringAsFixed(2)} '
      'maks ${galatMaksPctFoto.toStringAsFixed(2)} '
      '(% diag halaman maks ${galatMaksPctHalaman.toStringAsFixed(2)}) '
      '| sel IoU>=0,7 ${(fraksiSelIou07 * 100).toStringAsFixed(1)}% '
      '(IoU min ${iouMinGlobal.toStringAsFixed(2)}) '
      '| sel geser>25% tinggi ${(fraksiSelGeser025 * 100).toStringAsFixed(1)}% '
      '| deteksi ms median ${msDeteksiMedian.toStringAsFixed(0)} '
      'maks ${msDeteksiMaks.toStringAsFixed(0)} '
      '| warp ms median ${msWarpMedian.toStringAsFixed(0)}'
      '${alasanGagal.isEmpty ? '' : ' | gagal: $alasanGagal'}';
}

double _median(List<double> v) {
  if (v.isEmpty) return double.nan;
  final s = [...v]..sort();

  return s[s.length ~/ 2];
}
