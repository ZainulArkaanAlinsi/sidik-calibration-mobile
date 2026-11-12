// Ukur page registration pada foto sintetis RESOLUSI PENUH (12 MP) — galat
// sudut, IoU sel, dan waktu. BUKAN bagian aplikasi (tidak masuk APK).
//
// Murni Dart tanpa Flutter, jadi bisa dikompilasi AOT (waktu yang jauh lebih
// dekat ke perangkat daripada `flutter test` yang JIT):
//
//   dart compile exe tool/ukur_registrasi_halaman.dart -o ukur_registrasi.exe
//   ./ukur_registrasi.exe --matriks=24 --keluar=laporan.json
//
// Opsi:
//   --skala=1.0      skala kanvas prototipe (1.0 = 4032x3024 / 3024x4032)
//   --batas=26       jumlah foto prototipe yang diukur (0 = lewati)
//   --matriks=24     jumlah foto variasi acak (0 = lewati)
//   --prototipe=...  berkas geometri (bawaan: fixture test)
//   --keluar=...     tulis laporan JSON per foto
//
// JANGAN dijalankan bersamaan dengan proses berat lain (aturan repo).
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/registrasi_halaman/deteksi_sudut_halaman.dart';
import 'package:sidik_calibration/services/registrasi_halaman/geometri_halaman.dart'
    show jarakTitik;
import 'package:sidik_calibration/services/registrasi_halaman/hasil_deteksi_halaman.dart';

import '../test/support/foto_sintetis_halaman.dart';
import '../test/support/ukur_registrasi_halaman.dart';

/// Salinan setara `ratakanHalaman` (lib/services/registrasi_jangkar_teks.dart)
/// HANYA untuk mengukur waktu warp di AOT: berkas aslinya mengimpor Flutter
/// sehingga tidak bisa dikompilasi di sini. Bilinear, kanvas `halamanPt × skala`.
img.Image _warpUntukUkur(
  img.Image foto,
  List<double> m, // point halaman → piksel foto
  ({double w, double h}) halamanPt,
  double skala,
) {
  final lebar = (halamanPt.w * skala).round();
  final tinggi = (halamanPt.h * skala).round();
  final sb = foto.toUint8List();
  final sw = foto.width;
  final sh = foto.height;
  final strideS = foto.rowStride;
  final hasil = img.Image(width: lebar, height: tinggi);
  final hb = hasil.toUint8List();
  final strideH = hasil.rowStride;
  final sx = lebar / halamanPt.w;
  final sy = tinggi / halamanPt.h;

  for (var y = 0; y < tinggi; y++) {
    final ty = (y + 0.5) / sy;
    var o = y * strideH;
    for (var x = 0; x < lebar; x++, o += 3) {
      final tx = (x + 0.5) / sx;
      final w = m[6] * tx + m[7] * ty + m[8];
      final px = (m[0] * tx + m[1] * ty + m[2]) / w - 0.5;
      final py = (m[3] * tx + m[4] * ty + m[5]) / w - 0.5;
      if (px < 0 || py < 0 || px > sw - 1 || py > sh - 1) {
        hb[o] = 255;
        hb[o + 1] = 255;
        hb[o + 2] = 255;
        continue;
      }
      final x0 = px.floor();
      final y0 = py.floor();
      final x1 = x0 + 1 < sw ? x0 + 1 : x0;
      final y1 = y0 + 1 < sh ? y0 + 1 : y0;
      final fx = px - x0;
      final fy = py - y0;
      final a = y0 * strideS + x0 * 3;
      final b = y0 * strideS + x1 * 3;
      final c = y1 * strideS + x0 * 3;
      final d = y1 * strideS + x1 * 3;
      for (var k = 0; k < 3; k++) {
        final atas = sb[a + k] + (sb[b + k] - sb[a + k]) * fx;
        final bawah = sb[c + k] + (sb[d + k] - sb[c + k]) * fx;
        hb[o + k] = (atas + (bawah - atas) * fy).round().clamp(0, 255);
      }
    }
  }

  return hasil;
}

class _Baris {
  _Baris(this.ukuran, this.msDecode, this.msIsolate, this.msWarp, this.json);

  final UkuranFoto ukuran;
  final double msDecode;
  final double msIsolate;
  final double msWarp;
  final Map<String, Object?> json;
}

HasilDeteksiHalaman _deteksiDiIsolate(img.Image foto) =>
    deteksiSudutHalaman(foto);

Future<_Baris> _proses(String nama, SpesifikasiFoto spek) async {
  final f = hasilkanFotoSintetis(spek);
  // Seperti foto kamera: bita JPEG -> decode (waktu decode ikut diukur).
  final jpeg = Uint8List.fromList(img.encodeJpg(f.foto, quality: 80));
  final sd = Stopwatch()..start();
  final foto = img.decodeJpg(jpeg)!;
  final msDecode = sd.elapsedMicroseconds / 1000;

  final st = Stopwatch()..start();
  final hasil = deteksiSudutHalaman(foto);
  final msSinkron = st.elapsedMicroseconds / 1000;

  final si = Stopwatch()..start();
  await Isolate.run(() => _deteksiDiIsolate(foto));
  final msIsolate = si.elapsedMicroseconds / 1000;

  var msWarp = 0.0;
  UkuranFoto ukuran;
  switch (hasil) {
    case DeteksiHalamanGagal():
      ukuran = ukurSudut(nama, f, null, alasan: hasil.alasan.name);
    case DeteksiHalamanBerhasil():
      // Warp 3 px/pt dari foto penuh (urutan sudut = urutan halaman, putaran 0
      // atau 1 menurut kanvas; di sini cukup H dari sudut yang selaras).
      final w = f.halamanPt.w;
      final h = f.halamanPt.h;
      final rasioFoto =
          jarakTitik(hasil.sudut[0], hasil.sudut[1]) /
          jarakTitik(hasil.sudut[0], hasil.sudut[3]);
      final potret = w < h;
      final urut = (rasioFoto < 1) == potret
          ? hasil.sudut
          : [hasil.sudut[3], hasil.sudut[0], hasil.sudut[1], hasil.sudut[2]];
      final hm = homografiDari4([
        (x: 0.0, y: 0.0),
        (x: w, y: 0.0),
        (x: w, y: h),
        (x: 0.0, y: h),
      ], urut);
      if (hm != null) {
        final sw = Stopwatch()..start();
        _warpUntukUkur(foto, hm, f.halamanPt, 3.0);
        msWarp = sw.elapsedMicroseconds / 1000;
      }
      ukuran = ukurSudut(
        nama,
        f,
        hasil.sudut,
        msDeteksi: msSinkron,
        msWarp: msWarp,
      );
  }

  final diag = hasil is DeteksiHalamanBerhasil ? hasil.diagnostik : null;

  return _Baris(ukuran, msDecode, msIsolate, msWarp, {
    'foto': nama,
    'ukuran_px': [foto.width, foto.height],
    'terdeteksi': ukuran.terdeteksi,
    'alasan': ukuran.alasan,
    'galat_sudut_pct_diagonal_foto': ukuran.galatSudutPctFoto,
    'galat_sudut_pct_diagonal_halaman': ukuran.galatSudutPctHalaman,
    'sel_iou_ge_07': ukuran.fraksiIou07,
    'iou_min': ukuran.iouMin,
    'sel_geser_gt_025_tinggi': ukuran.fraksiGeser025,
    'jumlah_sel': ukuran.jumlahSel,
    'ms_decode_jpeg': msDecode,
    'ms_deteksi_sinkron': msSinkron,
    'ms_deteksi_isolate_total': msIsolate,
    'ms_perkecil': diag?.durasiKecilMs,
    'ms_warp_3pxpt': msWarp,
    'diagnostik': diag?.toJson(),
  });
}

Future<void> main(List<String> args) async {
  String opsi(String nama, String bawaan) {
    for (final a in args) {
      if (a.startsWith('--$nama=')) return a.substring(nama.length + 3);
    }

    return bawaan;
  }

  final sk = double.parse(opsi('skala', '1.0'));
  final jumlahMatriks = int.parse(opsi('matriks', '24'));
  final batasPrototipe = int.parse(opsi('batas', '26'));
  final berkas = opsi(
    'prototipe',
    'test/fixtures/registrasi_halaman/geometri_prototipe.json',
  );
  final keluar = opsi('keluar', '');

  final baris = <_Baris>[];
  final prototipe = <_Baris>[];

  // ---- A. 26 foto prototipe (geometri sebenarnya dari kunci jawaban) ----------
  final data =
      jsonDecode(File(berkas).readAsStringSync()) as Map<String, dynamic>;
  const meja = [(70, 90, 110), (110, 95, 80), (95, 100, 105), (60, 70, 65)];
  const px2pt = 72 / 250;
  var n = 0;
  for (final g in (data['foto'] as List).cast<Map<String, dynamic>>().take(
    batasPrototipe,
  )) {
    final rng = math.Random(n);
    final kanvas = (g['kanvas'] as List).cast<num>();
    final hp = (g['halaman_pt'] as List).cast<num>();
    final deg = g['deg'] as Map<String, dynamic>;
    final berat = deg['berat'] as bool;
    final hRaster = (g['H'] as List)
        .cast<num>()
        .map((e) => e.toDouble())
        .toList();
    final hPt = kali3(kali3([sk, 0, 0, 0, sk, 0, 0, 0, 1], hRaster), [
      1 / px2pt,
      0,
      0,
      0,
      1 / px2pt,
      0,
      0,
      0,
      1,
    ]);
    final spek = SpesifikasiFoto(
      seed: 4000 + n,
      halamanPt: (w: hp[0].toDouble(), h: hp[1].toDouble()),
      lebarFoto: (kanvas[0] * sk).round(),
      tinggiFoto: (kanvas[1] * sk).round(),
      warnaAlas: meja[rng.nextInt(meja.length)],
      gradienCahaya: berat
          ? 0.25 + 0.2 * rng.nextDouble()
          : 0.1 + 0.18 * rng.nextDouble(),
      bayanganTangan: rng.nextBool() ? 0.15 + 0.15 * rng.nextDouble() : 0,
      blurPx: (deg['blur_sigma'] as num) * sk,
      noise: (deg['noise_sigma'] as num).toDouble(),
      jpegQ: g['jpeg_q'] as int,
      homografi: hPt,
      sel: [
        for (final b in (g['sel'] as List))
          KotakPt(
            (b[0] as num) * px2pt,
            (b[1] as num) * px2pt,
            (b[2] as num) * px2pt,
            (b[3] as num) * px2pt,
          ),
      ],
    );
    final b = await _proses(g['berkas'] as String, spek);
    prototipe.add(b);
    baris.add(b);
    stdout.writeln('prototipe ${g['berkas']}: ${_satu(b)}');
    n++;
  }

  // ---- B. variasi acak ---------------------------------------------------------
  final matriks = <_Baris>[];
  final rng = math.Random(2026);
  double u(double a, double b) => a + (b - a) * rng.nextDouble();
  const halaman = [
    (w: 612.0, h: 792.0),
    (w: 595.2, h: 841.8),
    (w: 792.0, h: 612.0),
    (w: 841.8, h: 595.2),
    (w: 612.0, h: 1008.0),
  ];
  const alasan = [JenisAlas.gelap, JenisAlas.sedang, JenisAlas.kayuTerang];
  for (var i = 0; i < jumlahMatriks; i++) {
    final hal = halaman[i % halaman.length];
    final lanskap = hal.w > hal.h;
    final lebar = ((lanskap ? 4032 : 3024) * sk).round();
    final tinggi = ((lanskap ? 3024 : 4032) * sk).round();
    final a = alasan[i % alasan.length];
    final spek = SpesifikasiFoto(
      seed: 9000 + i,
      halamanPt: hal,
      lebarFoto: lebar,
      tinggiFoto: tinggi,
      alas: a,
      rollDeg: u(-25, 25),
      pitchDeg: u(0, 22),
      yawDeg: u(-18, 18),
      isi: u(0.86, 0.93),
      geserX: u(-1, 1),
      geserY: u(-1, 1),
      fRel: u(0.75, 1.1),
      gradienCahaya: u(0.05, 0.3),
      bayanganTangan: rng.nextBool() ? u(0.1, 0.4) : 0,
      blurPx: u(0.9, 2.3) * sk,
      noise: u(3, 11),
      jpegQ: 55 + rng.nextInt(35),
    );
    final b = await _proses('matriks_${a.name}_$i', spek);
    matriks.add(b);
    baris.add(b);
    stdout.writeln('matriks ${a.name}_$i: ${_satu(b)}');
  }

  stdout.writeln('');
  if (prototipe.isNotEmpty) {
    _ringkas(
      'PROTOTIPE (${prototipe.length} foto, skala kanvas $sk)',
      prototipe,
    );
  }
  if (matriks.isNotEmpty) _ringkas('MATRIKS ($jumlahMatriks foto)', matriks);

  if (keluar.isNotEmpty) {
    File(keluar).writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'skala_kanvas': sk,
        'foto': [for (final b in baris) b.json],
      }),
    );
    stdout.writeln('laporan: $keluar');
  }
}

String _satu(_Baris b) {
  final u = b.ukuran;
  if (!u.terdeteksi) return 'GAGAL ${u.alasan}';

  return 'galat ${u.galatSudutPctFoto!.toStringAsFixed(2)}% '
      'iou07 ${(u.fraksiIou07! * 100).toStringAsFixed(1)}% '
      'deteksi ${u.msDeteksi!.toStringAsFixed(0)} ms '
      'isolate ${b.msIsolate.toStringAsFixed(0)} ms '
      'decode ${b.msDecode.toStringAsFixed(0)} ms '
      'warp ${b.msWarp.toStringAsFixed(0)} ms';
}

double _median(List<double> v) {
  if (v.isEmpty) return double.nan;
  final s = [...v]..sort();

  return s[s.length ~/ 2];
}

void _ringkas(String judul, List<_Baris> b) {
  final r = RingkasanUkur(judul, [for (final x in b) x.ukuran]);
  stdout.writeln('== $r');
  stdout.writeln(
    '   waktu (ms, median/maks): decode JPEG '
    '${_median([for (final x in b) x.msDecode]).toStringAsFixed(0)}/'
    '${b.map((x) => x.msDecode).reduce(math.max).toStringAsFixed(0)}; '
    'deteksi sinkron ${r.msDeteksiMedian.toStringAsFixed(0)}/'
    '${r.msDeteksiMaks.toStringAsFixed(0)}; '
    'deteksi lewat isolate ${_median([for (final x in b) x.msIsolate]).toStringAsFixed(0)}/'
    '${b.map((x) => x.msIsolate).reduce(math.max).toStringAsFixed(0)}; '
    'warp 3 px/pt ${_median([for (final x in b)
      if (x.msWarp > 0) x.msWarp]).toStringAsFixed(0)}',
  );
}
