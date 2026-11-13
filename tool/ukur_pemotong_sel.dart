// Alat dev: PARITAS `PemotongSel` (Dart) lawan varian D ("luas") rig Python.
// BUKAN bagian aplikasi (tidak masuk APK). Berjalan di HOST saja — tidak
// menyentuh perangkat atau emulator. Model TFLite TIDAK dijalankan di sini:
// yang diukur hanya kemiripan CROP terhadap crop rig yang bacaannya sudah
// diukur di Python.
//
// Tidak ada data nyata di repo. Semua masukan dibaca dari folder yang ditunjuk
// variabel lingkungan `SIDIK_PARITAS_DIR` (atau `--dir=`), berisi hasil
// `dump_rig.py` (skrip itu tidak masuk repo; ia mengeluarkan, per foto):
//
//   sel.json                      daftar sel: foto, tabel, baris, kolom, rect
//                                 [xl,yt,xr,yb], label (teks atau KOSONG/CORET/
//                                 TIMPA/STRIP/?), luas {berkas,kiri,atas,lebar,
//                                 tinggi} atau null (rig: tak ada tinta milik baris)
//   <foto>_up.png                 halaman lurus (BGR → PNG, lossless)
//   <foto>_norm.png               abu ternormalisasi rig (kertas ≈ 255)
//   <foto>_NNN_luas.png           crop varian D rig per sel
//
// Foto asli memuat nama pelanggan: folder itu JANGAN dimasukkan ke repo dan
// keluaran alat ini hanya angka agregat serta kunci sel generik (tabel, baris,
// kolom).
//
//   SIDIK_PARITAS_DIR=... dart run tool/ukur_pemotong_sel.dart [opsi]
//
// Opsi:
//   --dir=PATH       folder masukan (bawaan: $SIDIK_PARITAS_DIR)
//   --keluar=FILE    tulis laporan JSON
//   --skala=0.6      ulangi pada halaman yang dikecilkan (kepekaan resolusi;
//                    kanvas pindai HP ±3 px/pt, foto rig ±5 px/pt)
//   --rinci          cetak tiap sel yang pemotongnya tidak yakin
//   --simpan-crop=D  tulis crop Dart (setelan produksi) ke folder D, DI LUAR repo
//   --geser=3        ulangi dengan semua kotak digeser (dx=+geser, dy=-geser)
//
// ANGKA DI SINI IN-SAMPLE: dua foto, parameter disetel sambil melihatnya.
// Bukan akurasi lapangan.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/ocr_angka/pagar_tinta.dart';
import 'package:sidik_calibration/services/ocr_angka/pemotong_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/praproses_sel.dart';

/// Setelan yang mengunci angka MUTLAK rig (margin 5 px, garis ≥ 60 px, bintik
/// < 6 px, kernel latar 80 px) — membedakan selisih algoritma dari selisih
/// pilihan ukuran relatif.
const _setelanRig = SetelanPemotong(
  marginSampingPx: 5,
  panjangGarisPx: 60,
  areaKomponenMinPx: 6,
  kernelLatarPx: 80,
);

void main(List<String> args) {
  String? opsi(String nama) {
    for (final a in args) {
      if (a.startsWith('--$nama=')) return a.substring(nama.length + 3);
    }

    return null;
  }

  final dirArg = opsi('dir') ?? Platform.environment['SIDIK_PARITAS_DIR'];
  if (dirArg == null || dirArg.isEmpty) {
    stderr.writeln(
      'Set SIDIK_PARITAS_DIR (atau --dir=) ke folder keluaran dump_rig.py.',
    );
    exit(64);
  }
  final dir = Directory(dirArg);
  final daftar =
      (jsonDecode(File('${dir.path}/sel.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  final rinci = args.contains('--rinci');
  final simpanCrop = opsi('simpan-crop');
  final skalaOpsi = double.tryParse(opsi('skala') ?? '');
  final geserOpsi = int.tryParse(opsi('geser') ?? '');

  final laporan = <String, dynamic>{};

  final fotoList = daftar.map((e) => e['foto'] as String).toSet().toList();
  for (final foto in fotoList) {
    final sel = daftar.where((e) => e['foto'] == foto).toList();
    stdout.writeln('\n=== $foto: ${sel.length} sel ===');

    final up = img.decodePng(
      File('${dir.path}/${foto}_up.png').readAsBytesSync(),
    )!;
    final normRig = img.decodePng(
      File('${dir.path}/${foto}_norm.png').readAsBytesSync(),
    )!;
    stdout.writeln('halaman ${up.width}x${up.height}');

    laporan[foto] = {
      'rig_mutlak': _jalankan(
        'A. setelan rig (angka mutlak)',
        dir,
        up,
        normRig,
        sel,
        _setelanRig,
        faktor: 1,
      ),
      'relatif': _jalankan(
        'B. setelan produksi (relatif terhadap tinggi baris)',
        dir,
        up,
        normRig,
        sel,
        const SetelanPemotong(),
        faktor: 1,
        rinci: rinci,
        simpanDir: simpanCrop,
      ),
      if (geserOpsi != null)
        'relatif_geser': _jalankan(
          'C. produksi, semua kotak digeser (dx=+$geserOpsi, dy=-$geserOpsi)',
          dir,
          up,
          normRig,
          sel,
          const SetelanPemotong(),
          faktor: 1,
          dx: geserOpsi,
          dy: -geserOpsi,
        ),
      if (skalaOpsi != null)
        'relatif_skala': _jalankan(
          'D. produksi, halaman dikecilkan ×$skalaOpsi',
          dir,
          up,
          normRig,
          sel,
          const SetelanPemotong(),
          faktor: skalaOpsi,
        ),
    };
  }

  final keluar = opsi('keluar');
  if (keluar != null) {
    File(
      keluar,
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(laporan));
    stdout.writeln('\nlaporan: $keluar');
  }
}

String _jenis(String label) {
  if (label == 'KOSONG') return 'kosong';
  if (label == 'CORET' || label == 'TIMPA' || label == 'STRIP') return 'serah';
  if (label == '?') return 'ambigu';

  return 'isi';
}

Map<String, dynamic> _jalankan(
  String judul,
  Directory dir,
  img.Image upAsli,
  img.Image normRig,
  List<Map<String, dynamic>> sel,
  SetelanPemotong setelan, {
  required double faktor,
  int dx = 0,
  int dy = 0,
  bool rinci = false,
  String? simpanDir,
}) {
  stdout.writeln('\n--- $judul ---');

  final skalaPemisah = faktor != 1;
  final up = skalaPemisah
      ? img.copyResize(
          upAsli,
          width: (upAsli.width * faktor).round(),
          height: (upAsli.height * faktor).round(),
          interpolation: img.Interpolation.average,
        )
      : upAsli;

  final kotak = <KotakPiksel>[
    for (final s in sel)
      (
        x: ((s['rect'] as List)[0] as int) * faktor + dx,
        y: ((s['rect'] as List)[1] as int) * faktor + dy,
        w:
            (((s['rect'] as List)[2] as int) -
                ((s['rect'] as List)[0] as int)) *
            faktor,
        h:
            (((s['rect'] as List)[3] as int) -
                ((s['rect'] as List)[1] as int)) *
            faktor,
      ),
  ];

  final sw = Stopwatch()..start();
  final hMedian = (kotak.map((k) => k.h).toList()..sort())[kotak.length ~/ 2];
  final kernel =
      setelan.kernelLatarPx ?? (setelan.kernelLatar * hMedian).round();
  final halaman = HalamanTernormal.dari(up, kernelLatarPx: kernel);
  final tHalaman = sw.elapsedMilliseconds;
  final pemotong = PemotongSel.dari(halaman, setelan: setelan);
  final hasil = [for (final k in kotak) pemotong.potong(k)];
  final tTotal = sw.elapsedMilliseconds;

  // ---- kesetaraan normalisasi (hanya pada skala 1) ----------------------------
  final selisihNorm = <double>[];
  var kesepakatanTinta = 0, totalTinta = 0;
  if (!skalaPemisah) {
    final rigBita = normRig.getBytes();
    for (var i = 0; i < sel.length; i++) {
      final r = sel[i]['rect'] as List;
      final h = (r[3] as int) - (r[1] as int);
      final e = (setelan.meluber * h).round();
      final marg =
          setelan.marginSampingPx ??
          math.max(1, (setelan.marginSamping * h).round());
      final y0 = math.max(0, (r[1] as int) - e);
      final y1 = math.min(up.height, (r[3] as int) + e);
      final x0 = (r[0] as int) + marg;
      final x1 = (r[2] as int) - marg;
      final rw = x1 - x0;
      if (rw < 4 || y1 - y0 < 4) continue;
      final buf = Uint8List(rw * (y1 - y0));
      halaman.isiNorm(x0, y0, x1, y1, buf);
      var jumlah = 0;
      var o = 0;
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++, o++) {
          final a = buf[o];
          final b = rigBita[y * normRig.width + x];
          jumlah += (a - b).abs();
          final ta = a <= 198, tb = b <= 198;
          if (ta || tb) {
            totalTinta++;
            if (ta && tb) kesepakatanTinta++;
          }
        }
      }
      selisihNorm.add(jumlah / buf.length);
    }
    selisihNorm.sort();
    stdout.writeln(
      'normalisasi vs rig: selisih abu rata-rata per sel median '
      '${_f(_pct(selisihNorm, 0.5))}, p95 ${_f(_pct(selisihNorm, 0.95))}, '
      'maks ${_f(selisihNorm.last)} (skala 0-255); '
      'IoU tinta (<=198) = ${_f(kesepakatanTinta / math.max(1, totalTinta))} '
      'waktu halaman ${tHalaman}ms',
    );
  }

  // ---- per sel -----------------------------------------------------------------
  final iouKotak = <double>[];
  final iouTinta = <double>[];
  final selisihPiksel = <double>[];
  final kosongSama = <String, int>{
    'sama': 0,
    'rigKosongDartIsi': 0,
    'rigIsiDartKosong': 0,
  };
  final berbeda = <String>[];
  final sebabCacah = <String, int>{};
  final gelapPerJenis = <String, List<double>>{
    'kosong': [],
    'isi': [],
    'serah': [],
    'ambigu': [],
  };
  final takYakinPerJenis = <String, int>{};
  final adaPerJenis = <String, int>{};
  final jenisCacah = <String, int>{};
  var isiRig = 0,
      usulanRig = 0,
      usulanRigDitahan = 0,
      usulanBenarDitahan = 0,
      bukanUsulanDitahan = 0,
      salahDitahan = 0;
  var lebarLebih320 = 0;
  var cakupanPagar = 0;

  for (var i = 0; i < sel.length; i++) {
    final s = sel[i];
    final jenis = _jenis(s['label'] as String);
    jenisCacah[jenis] = (jenisCacah[jenis] ?? 0) + 1;
    final d = hasil[i];
    final id = '${s['tabel']}/${s['baris']}/${s['kolom']}';

    if (simpanDir != null && d.crop != null) {
      Directory(simpanDir).createSync(recursive: true);
      File(
        '$simpanDir/${s['foto']}_${s['indeks']}_dart.png',
      ).writeAsBytesSync(img.encodePng(d.crop!));
    }
    final lolosPagar =
        d.crop != null && PagarTinta.adaTinta(PagarTinta.ukur(d.crop!));
    // Sama dengan MesinAngka.bacaPotongan: crop ADA tetapi ditolak pagar =
    // perluCek (tinta pudar), BUKAN kosong; pemotong ragu = perluCek.
    final perluCekPemotong = d.takYakin || (d.crop != null && !lolosPagar);
    if (s['rig_status'] != null && jenis == 'isi') {
      isiRig++;
      if (s['rig_status'] == 'usulan') {
        usulanRig++;
        if (perluCekPemotong) {
          usulanRigDitahan++;
          if (s['rig_benar'] == '1') usulanBenarDitahan++;
        }
      } else if (perluCekPemotong) {
        bukanUsulanDitahan++;
      }
      if (s['rig_benar'] == '0' && perluCekPemotong) salahDitahan++;
    }
    if (rinci && d.takYakin) {
      final h = kotak[i].h;
      stdout.writeln(
        '  takYakin $id [$jenis ${s['label'] == 'KOSONG' ? '' : 'berlabel'}] '
        '${d.sebabTakYakin!.name} h=${h.toStringAsFixed(0)} '
        'crop=${d.crop?.width}x${d.crop?.height} '
        'luas/h2=${(d.luasTinta / (h * h)).toStringAsFixed(3)} '
        'gelap=${d.crop == null ? '-' : PagarTinta.ukur(d.crop!).gelap.toStringAsFixed(3)}',
      );
    }
    if (perluCekPemotong) {
      takYakinPerJenis[jenis] = (takYakinPerJenis[jenis] ?? 0) + 1;
      final sebab = d.sebabTakYakin?.name ?? 'tintaPudar';
      sebabCacah[sebab] = (sebabCacah[sebab] ?? 0) + 1;
    }

    final crop = d.crop;
    if (crop != null) {
      adaPerJenis[jenis] = (adaPerJenis[jenis] ?? 0) + 1;
      final g = PagarTinta.ukur(crop).gelap;
      gelapPerJenis[jenis]!.add(g);
      if (PraprosesSel.lebarHasilResize(crop.width, crop.height) > 320) {
        lebarLebih320++;
      }
      if (PagarTinta.adaTinta(PagarTinta.ukur(crop))) cakupanPagar++;
    } else {
      gelapPerJenis[jenis]!.add(0);
    }

    if (skalaPemisah || dx != 0 || dy != 0) {
      // Hanya tingkat status; crop rig tidak sejajar dengan kotak yang digeser/
      // diskalakan.
      final rigLuas = s['luas'] as Map<String, dynamic>?;
      if ((rigLuas == null) != (crop == null)) {
        kosongSama[rigLuas == null ? 'rigKosongDartIsi' : 'rigIsiDartKosong'] =
            kosongSama[rigLuas == null
                ? 'rigKosongDartIsi'
                : 'rigIsiDartKosong']! +
            1;
        berbeda.add('$id [$jenis] kosong-beda');
      } else {
        kosongSama['sama'] = kosongSama['sama']! + 1;
      }
      if (rigLuas != null && crop != null) {
        final rl = rigLuas['lebar'] as int, rt = rigLuas['tinggi'] as int;
        final rk = (rigLuas['kiri'] as int) * faktor + dx;
        final ra = (rigLuas['atas'] as int) * faktor + dy;
        iouKotak.add(
          _iouKotak(
            rk,
            ra,
            rl * faktor,
            rt * faktor,
            d.kiri.toDouble(),
            d.atas.toDouble(),
            crop.width.toDouble(),
            crop.height.toDouble(),
          ),
        );
      }
      continue;
    }

    final rigLuas = s['luas'] as Map<String, dynamic>?;
    if (rigLuas == null && crop == null) {
      kosongSama['sama'] = kosongSama['sama']! + 1;
      continue;
    }
    if (rigLuas == null) {
      kosongSama['rigKosongDartIsi'] = kosongSama['rigKosongDartIsi']! + 1;
      berbeda.add(
        '$id [$jenis] rig kosong, Dart berisi'
        '${d.takYakin ? ' (takYakin ${d.sebabTakYakin!.name})' : ''}',
      );
      continue;
    }
    if (crop == null) {
      kosongSama['rigIsiDartKosong'] = kosongSama['rigIsiDartKosong']! + 1;
      berbeda.add('$id [$jenis] rig berisi, Dart kosong');
      continue;
    }
    kosongSama['sama'] = kosongSama['sama']! + 1;

    final rigCrop = img.decodePng(
      File('${dir.path}/${rigLuas['berkas']}').readAsBytesSync(),
    )!;
    final rk = rigLuas['kiri'] as int, ra = rigLuas['atas'] as int;

    iouKotak.add(
      _iouKotak(
        rk.toDouble(),
        ra.toDouble(),
        rigCrop.width.toDouble(),
        rigCrop.height.toDouble(),
        d.kiri.toDouble(),
        d.atas.toDouble(),
        crop.width.toDouble(),
        crop.height.toDouble(),
      ),
    );

    // Tinta & selisih piksel di gabungan kedua crop (di luar crop = kertas 255).
    final ux0 = math.min(rk, d.kiri), uy0 = math.min(ra, d.atas);
    final ux1 = math.max(rk + rigCrop.width, d.kiri + crop.width);
    final uy1 = math.max(ra + rigCrop.height, d.atas + crop.height);
    var inter = 0, uni = 0;
    var beda = 0;
    final dartBita = crop.getBytes(order: img.ChannelOrder.rgb);
    for (var y = uy0; y < uy1; y++) {
      for (var x = ux0; x < ux1; x++) {
        int vr = 255, vd = 255;
        final xr = x - rk, yr = y - ra;
        if (xr >= 0 && yr >= 0 && xr < rigCrop.width && yr < rigCrop.height) {
          vr = rigCrop.getPixel(xr, yr).r.toInt();
        }
        final xd = x - d.kiri, yd = y - d.atas;
        if (xd >= 0 && yd >= 0 && xd < crop.width && yd < crop.height) {
          vd = dartBita[(yd * crop.width + xd) * 3];
        }
        final tr = vr <= 198, td = vd <= 198;
        if (tr || td) {
          uni++;
          if (tr && td) inter++;
        }
        beda += (vr - vd).abs();
      }
    }
    iouTinta.add(uni == 0 ? 1.0 : inter / uni);
    selisihPiksel.add(beda / ((ux1 - ux0) * (uy1 - uy0)));
  }

  iouKotak.sort();
  iouTinta.sort();
  selisihPiksel.sort();

  String ringkas(List<double> v) => v.isEmpty
      ? '-'
      : 'n=${v.length} min ${_f(v.first)} p10 ${_f(_pct(v, 0.1))} median ${_f(_pct(v, 0.5))} '
            '>=0.9: ${v.where((x) => x >= 0.9).length} >=0.8: ${v.where((x) => x >= 0.8).length}';

  if (iouKotak.isNotEmpty) {
    stdout.writeln('IoU kotak crop (rig vs Dart): ${ringkas(iouKotak)}');
  }
  if (iouTinta.isNotEmpty) {
    stdout.writeln('IoU tinta (<=198, gabungan crop): ${ringkas(iouTinta)}');
    stdout.writeln(
      'selisih piksel rata-rata (0-255): median ${_f(_pct(selisihPiksel, 0.5))} '
      'p95 ${_f(_pct(selisihPiksel, 0.95))} maks ${_f(selisihPiksel.last)}',
    );
  }
  stdout.writeln(
    'kosong/berisi cocok: ${kosongSama['sama']} dari ${sel.length}; '
    'rig kosong & Dart berisi ${kosongSama['rigKosongDartIsi']}; '
    'rig berisi & Dart kosong ${kosongSama['rigIsiDartKosong']}',
  );
  stdout.writeln('jenis label: $jenisCacah; Dart punya crop: $adaPerJenis');
  stdout.writeln(
    'pemotong TIDAK YAKIN (dan lolos pagar tinta => perluCek) per jenis: '
    '$takYakinPerJenis; sebab: $sebabCacah',
  );
  if (isiRig > 0) {
    stdout.writeln(
      'efek ke USULAN rig (varian D, ambang 0,990 + gerbang): dari $isiRig sel '
      'berisi, rig menjadikan $usulanRig usulan; $usulanRigDitahan di antaranya '
      'jadi perluCek karena pemotong tak yakin ($usulanBenarDitahan di antaranya BENAR); '
      'perluCek rig lain yang kini ditahan pemotong: $bukanUsulanDitahan; '
      'bacaan rig yang SALAH dan ditahan pemotong: $salahDitahan',
    );
  }
  for (final j in ['kosong', 'isi', 'serah']) {
    final g = gelapPerJenis[j]!;
    if (g.isEmpty) continue;
    final urut = [...g]..sort();
    stdout.writeln(
      'gelap crop Dart [$j] n=${g.length}: min ${_f(urut.first, 4)} median '
      '${_f(_pct(urut, 0.5), 4)} maks ${_f(urut.last, 4)}; '
      'lolos pagar (>= ${PagarTinta.gelapMin}): ${urut.where((x) => x >= PagarTinta.gelapMin).length}',
    );
  }
  stdout.writeln(
    'crop Dart yang hasil resize-nya > 320 px: $lebarLebih320 (dari $cakupanPagar lolos pagar tinta)',
  );
  stdout.writeln(
    'waktu: halaman ${tHalaman}ms, semua sel ${tTotal}ms (waktu di host: JIT bila `dart run`, AOT bila exe; BUKAN HP)',
  );
  if (berbeda.isNotEmpty) {
    stdout.writeln(
      'sel yang kosong/berisinya beda dari rig (${berbeda.length}):',
    );
    for (final b in berbeda.take(30)) {
      stdout.writeln('  $b');
    }
  }

  return {
    'iou_kotak': {
      'n': iouKotak.length,
      'median': iouKotak.isEmpty ? null : _pct(iouKotak, 0.5),
      'min': iouKotak.isEmpty ? null : iouKotak.first,
    },
    'iou_tinta': {
      'n': iouTinta.length,
      'median': iouTinta.isEmpty ? null : _pct(iouTinta, 0.5),
      'min': iouTinta.isEmpty ? null : iouTinta.first,
      'ge_0_9': iouTinta.where((x) => x >= 0.9).length,
    },
    'kosong_berisi': kosongSama,
    'tak_yakin_per_jenis': takYakinPerJenis,
    'sebab': sebabCacah,
    'norm_selisih_median': selisihNorm.isEmpty ? null : _pct(selisihNorm, 0.5),
    'norm_iou_tinta': totalTinta == 0 ? null : kesepakatanTinta / totalTinta,
    'waktu_ms': {'halaman': tHalaman, 'total': tTotal},
  };
}

double _iouKotak(
  double x1,
  double y1,
  double w1,
  double h1,
  double x2,
  double y2,
  double w2,
  double h2,
) {
  final ix = math.max(0.0, math.min(x1 + w1, x2 + w2) - math.max(x1, x2));
  final iy = math.max(0.0, math.min(y1 + h1, y2 + h2) - math.max(y1, y2));
  final inter = ix * iy;
  final uni = w1 * h1 + w2 * h2 - inter;

  return uni <= 0 ? 0 : inter / uni;
}

double _pct(List<double> terurut, double q) {
  if (terurut.isEmpty) return double.nan;
  final pos = q * (terurut.length - 1);
  final a = pos.floor(), b = pos.ceil();

  return terurut[a] + (terurut[b] - terurut[a]) * (pos - a);
}

String _f(double v, [int d = 3]) => v.isNaN ? '-' : v.toStringAsFixed(d);
