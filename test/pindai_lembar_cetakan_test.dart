import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/pindai_lembar.dart';

/// Rantai pindai diadu ke LEMBAR CETAK yang sebenarnya, bukan ke citra karangan.
///
/// `test/assets/lembar-conductivity-v1.png` itu hasil
/// `php artisan ocr:cetak-lembar conductivity_meter`, dirender pada
/// `ukuran_referensi` template (1654×2339). Berkas geometrinya disalin apa
/// adanya dari `database/ocr-templates/conductivity_meter-v1.json`.
///
/// ## Kenapa ini perlu ada
///
/// Kesalahan yang paling mahal di fitur pindai bukan "gagal baca" — itu
/// kelihatan. Yang mahal: koordinat meleset setengah sel, angka mendarat di
/// kolom sebelah, dan **nggak ada gejala apa pun**. Uji di HP nggak bisa
/// dijadikan penjaga harian; ini bisa.
///
/// Yang dibuktikan di sini geometrinya, bukan OCR-nya:
///
///  1. empat marker sudut ketemu di lembar cetaknya sendiri
///  2. sesudah foto dimiringkan & dijulingkan, marker tetap ketemu dan warp
///     mengembalikannya ke ruang template dengan residual kecil
///  3. **tiap satu dari 80 sel mendarat DI DALAM kotak yang tergambar** — crop
///     yang meleset akan memuat garis kotaknya, dan garis itu yang dihitung
void main() {
  final berkasCitra = File('test/assets/lembar-conductivity-v1.png');
  final berkasGeometri = File('test/assets/geometri-conductivity-v1.json');

  late img.Image lembar;
  late Map<String, dynamic> geometri;
  late List<Sudut> tujuan;
  late int lebar;
  late int tinggi;

  setUpAll(() {
    lembar = img.decodePng(berkasCitra.readAsBytesSync())!;
    geometri =
        jsonDecode(berkasGeometri.readAsStringSync()) as Map<String, dynamic>;

    lebar = geometri['ukuran_referensi']['w'] as int;
    tinggi = geometri['ukuran_referensi']['h'] as int;

    tujuan = [
      for (final m in geometri['marker'] as List<dynamic>)
        (
          x: (m['x'] as num).toDouble(),
          y: (m['y'] as num).toDouble(),
        ),
    ];
  });

  /// Semua kotak sel, rata dari kedua tabel.
  List<({String kunci, double x, double y, double w, double h})> semuaSel() => [
    for (final t in geometri['tabel'] as List<dynamic>)
      for (final e in (t['sel'] as Map<String, dynamic>).entries)
        (
          kunci: e.key,
          x: (e.value['x'] as num).toDouble(),
          y: (e.value['y'] as num).toDouble(),
          w: (e.value['w'] as num).toDouble(),
          h: (e.value['h'] as num).toDouble(),
        ),
  ];

  /// Berapa persen piksel gelap di satu potongan.
  ///
  /// Sel kosong di lembar cetak itu putih bersih. Begitu crop-nya meleset ke
  /// tepi, garis kotak setebal beberapa piksel ikut masuk dan angka ini
  /// melonjak — itu yang dipakai sebagai penjaga.
  double gelap(img.Image potongan) {
    var n = 0;
    for (final p in potongan) {
      if (p.luminance < 128) n++;
    }

    return n / (potongan.width * potongan.height);
  }

  test('lembar cetaknya sendiri punya empat marker sudut', () {
    final marker = PindaiLembar().cariMarker(lembar);

    expect(
      marker,
      isNotNull,
      reason: 'Marker nggak ketemu di lembar yang kita cetak sendiri — '
          'kalau ini merah, `ocr:cetak-lembar` atau ambang deteksinya berubah.',
    );
    expect(marker!, hasLength(4));

    // Ketemunya harus DEKAT posisi yang ditulis geometri. Toleransi 12 px:
    // titik berat gumpalan nggak pernah persis di tengah nominal.
    for (var i = 0; i < 4; i++) {
      expect((marker[i].x - tujuan[i].x).abs(), lessThan(12),
          reason: 'Marker $i meleset di sumbu x.');
      expect((marker[i].y - tujuan[i].y).abs(), lessThan(12),
          reason: 'Marker $i meleset di sumbu y.');
    }
  });

  test('tiap sel mendarat di dalam kotaknya, bukan di garisnya', () {
    final mesin = PindaiLembar();
    final marker = mesin.cariMarker(lembar)!;
    final warp = mesin.warp(
      lembar,
      marker,
      lebar: lebar,
      tinggi: tinggi,
      tujuan: tujuan,
    );

    expect(warp.residualPx, lessThan(2.0),
        reason: 'Server nolak di atas 2 px.');

    final sel = semuaSel();
    expect(sel, hasLength(80), reason: '4 titik × 5 repeat × 2 kolom × 2 tabel');

    final meleset = <String>[];

    for (final s in sel) {
      final potongan = mesin.potongSel(
        warp.citra,
        x: s.x,
        y: s.y,
        w: s.w,
        h: s.h,
      );

      // Sel kosong: yang wajar cuma sisa antialias di tepi. Di atas 2% berarti
      // ada garis kotak ikut kepotong — tanda crop-nya meleset ke tepi atau
      // ke sel sebelah.
      if (gelap(potongan) > 0.02) meleset.add(s.kunci);
    }

    expect(
      meleset,
      isEmpty,
      reason: 'Sel ini kepotong kena garis kotak — koordinatnya meleset: '
          '${meleset.take(8).join(", ")}',
    );
  });

  /// Foto beneran nggak pernah rata: HP dipegang miring, kertas nggak sejajar
  /// meja. Yang diuji di sini justru itu — kalau cuma citra sempurna yang
  /// pernah dicoba, warp-nya nggak pernah beneran dipakai.
  /// **Kotak jangkar menaungi tulisan yang beneran tercetak.**
  ///
  /// Jangkar itu penjagaan "geser satu baris" satu-satunya yang MEMBACA ISI,
  /// bukan mengukur geometri: kalau gridnya bergeser, label yang kebaca di
  /// posisi Repeat 2 bakal `X3`. Tapi dia cuma berguna kalau kotaknya jatuh
  /// pas di atas tulisannya — kotak yang meleset bikin sel kosong kebaca,
  /// `cocok: false`, dan SELURUH lembar ditolak walau angkanya benar.
  ///
  /// Yang diadu di sini kotak dari berkas geometri ke tinta di lembar cetak
  /// yang dihasilkan `ocr:cetak-lembar` — dua sisi yang, sejak kotaknya
  /// dihitung `LetakLabelLembar`, memang wajib sama.
  test('kotak jangkar jatuh di atas label yang tercetak', () {
    final jangkar = (geometri['jangkar'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(
      jangkar,
      hasLength(5),
      reason: 'Lembar Conductivity punya 5 Repeat, tiap Repeat satu label.',
    );

    final mesin = PindaiLembar();
    final marker = mesin.cariMarker(lembar)!;
    final warp = mesin.warp(
      lembar,
      marker,
      lebar: lebar,
      tinggi: tinggi,
      tujuan: tujuan,
    );

    for (final j in jangkar) {
      final kotak = j['kotak'] as Map<String, dynamic>;

      expect(
        (kotak['w'] as num) >= 1 && (kotak['h'] as num) >= 1,
        isTrue,
        reason: 'Kotak `0×0` nggak bisa dipotong — jangkarnya mati diam-diam.',
      );

      final potongan = mesin.potongSel(
        warp.citra,
        x: (kotak['x'] as num).toDouble(),
        y: (kotak['y'] as num).toDouble(),
        w: (kotak['w'] as num).toDouble(),
        h: (kotak['h'] as num).toDouble(),
      );

      // Ada tinta di dalamnya — kotak yang meleset ke kertas kosong balik 0%.
      // Ambangnya rendah karena `X1` itu dua huruf di kotak selebar 19 mm.
      expect(
        gelap(potongan),
        greaterThan(0.01),
        reason: 'Kotak jangkar ${j['teks']} jatuh di kertas kosong.',
      );

      // Dan tinta itu BUKAN garis kotak sel yang kebetulan kepotong: label
      // berdiri di luar grid, jadi potongannya nggak boleh separuh hitam.
      expect(
        gelap(potongan),
        lessThan(0.30),
        reason: 'Kotak jangkar ${j['teks']} kena garis grid, bukan tulisannya.',
      );
    }
  });

  test('foto miring & juling dikembalikan ke ruang template', () {
    // Julingkan: keempat sudut digeser beda-beda, plus digeser & diperbesar,
    // seperti foto dari tangan.
    final sumber = <Sudut>[
      (x: 40, y: 70),
      (x: 1600, y: 20),
      (x: 1630, y: 2300),
      (x: 10, y: 2250),
    ];

    final juling = img.Image(width: lebar, height: tinggi);
    img.fill(juling, color: img.ColorRgb8(255, 255, 255));

    // Petakan MUNDUR: tiap piksel tujuan dicari asalnya di lembar rata, biar
    // hasilnya nggak berlubang — cara yang sama dipakai `PindaiLembar.warp`.
    final h = _homografi(sumber, tujuan);

    for (var y = 0; y < tinggi; y++) {
      for (var x = 0; x < lebar; x++) {
        final d = h[6] * x + h[7] * y + h[8];
        if (d == 0) continue;

        final sx = (h[0] * x + h[1] * y + h[2]) / d;
        final sy = (h[3] * x + h[4] * y + h[5]) / d;

        if (sx < 0 || sy < 0 || sx >= lebar || sy >= tinggi) continue;

        juling.setPixel(x, y, lembar.getPixel(sx.round(), sy.round()));
      }
    }

    final mesin = PindaiLembar();
    final marker = mesin.cariMarker(juling);

    expect(marker, isNotNull, reason: 'Marker ilang begitu fotonya miring.');

    final warp = mesin.warp(
      juling,
      marker!,
      lebar: lebar,
      tinggi: tinggi,
      tujuan: tujuan,
    );

    expect(warp.residualPx, lessThan(2.0));

    // Penjaga yang sebenarnya: sesudah diratakan, markernya harus kembali ke
    // posisi nominal. Ini pernyataan geometri langsung — beda dari hitung
    // piksel gelap di bawah, yang cuma pertanda.
    final sesudah = mesin.cariMarker(warp.citra)!;

    for (var i = 0; i < 4; i++) {
      expect((sesudah[i].x - tujuan[i].x).abs(), lessThan(2.0),
          reason: 'Marker $i nggak balik ke tempatnya (sumbu x).');
      expect((sesudah[i].y - tujuan[i].y).abs(), lessThan(2.0),
          reason: 'Marker $i nggak balik ke tempatnya (sumbu y).');
    }

    // Sel-selnya juga harus mendarat di tempat yang sama. Ambangnya di sini
    // 10%, bukan 2% seperti lembar rata, dan itu bukan pelonggaran asal:
    // citra ujinya lewat DUA kali penyalinan tetangga terdekat — sekali waktu
    // dimiringkan, sekali waktu diratakan lagi — dan tiap kali garis kotak
    // setebal 1 px jadi bergerigi lalu merembes ke dalam sel. Terukur di
    // berkas ini: tergelap 7,6%, tengah 4,7%. Foto beneran cuma lewat satu
    // kali penyalinan, jadi angkanya lebih bersih dari ini.
    //
    // Kalau koordinatnya yang meleset (bukan cuma tepinya kotor), angkanya
    // melompat jauh di atas ini — sebelum bug titik berat marker dibetulkan,
    // 50 dari 80 sel lewat ambang 6%.
    var kotor = 0;

    for (final s in semuaSel()) {
      final potongan = mesin.potongSel(
        warp.citra,
        x: s.x,
        y: s.y,
        w: s.w,
        h: s.h,
      );

      if (gelap(potongan) > 0.10) kotor++;
    }

    expect(
      kotor,
      0,
      reason: '$kotor sel meleset sesudah foto miring diratakan.',
    );
  });
}

/// Homografi 3×3 dari empat pasang titik, dipakai cuma buat MEMBUAT foto
/// juling di tes ini.
///
/// Sengaja ditulis ulang di sini, bukan dipinjam dari `PindaiLembar`: kalau
/// pembuat citra ujinya memakai matematika yang sama dengan yang diuji,
/// kesalahan di matematika itu saling menghapus dan tesnya jadi hijau palsu.
List<double> _homografi(List<Sudut> dari, List<Sudut> ke) {
  final a = List.generate(8, (_) => List<double>.filled(9, 0));

  for (var i = 0; i < 4; i++) {
    final x = dari[i].x, y = dari[i].y;
    final u = ke[i].x, v = ke[i].y;

    a[i * 2] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    a[i * 2 + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }

  // Eliminasi Gauss dengan pivot parsial.
  for (var kol = 0; kol < 8; kol++) {
    var pivot = kol;
    for (var r = kol + 1; r < 8; r++) {
      if (a[r][kol].abs() > a[pivot][kol].abs()) pivot = r;
    }

    final tukar = a[kol];
    a[kol] = a[pivot];
    a[pivot] = tukar;

    if (a[kol][kol].abs() < 1e-12) continue;

    for (var r = 0; r < 8; r++) {
      if (r == kol) continue;

      final f = a[r][kol] / a[kol][kol];
      for (var c = kol; c < 9; c++) {
        a[r][c] -= f * a[kol][c];
      }
    }
  }

  final h = <double>[];
  for (var i = 0; i < 8; i++) {
    h.add(a[i][i].abs() < 1e-12 ? 0 : a[i][8] / a[i][i]);
  }
  h.add(1);

  assert(h.every((v) => !v.isNaN && v.isFinite), 'Homografi uji tidak sah.');
  assert(math.max(h[0].abs(), h[4].abs()) > 1e-6, 'Homografi uji runtuh.');

  return h;
}
