import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Empat penanda sudut yang ketemu di foto, urut kiri-atas → kanan-atas →
/// kanan-bawah → kiri-bawah.
typedef Sudut = ({double x, double y});

/// Hasil penyelarasan foto ke ruang template.
class HasilWarp {
  const HasilWarp({
    required this.citra,
    required this.marker,
    required this.residualPx,
  });

  /// Citra yang udah diratakan ke `ukuran_referensi` template. Ini yang jadi
  /// dasar potong sel — dan yang dilampirkan sebagai `citra_warp`.
  final img.Image citra;

  /// Posisi marker di foto ASLI, buat dikirim ke server sebagai bukti geometri.
  final List<Sudut> marker;

  /// Seberapa jauh keempat sudut meleset dari persegi panjang sempurna sesudah
  /// diratakan, dalam piksel. Server nolak di atas 2 px.
  final double residualPx;
}

/// Mesin pindai lembar kerja — **semuanya jalan di HP**.
///
/// Fotonya nggak pernah keluar dari perangkat: yang dikirim ke server cuma teks
/// per sel, skor, dan kotak koordinatnya. Ini yang bikin jalur ini beda dari AI
/// Vision — nol biaya per foto, jalan tanpa sinyal, dan citra pelanggan nggak
/// nyampe pihak ketiga.
///
/// ## Kenapa markernya kotak hitam, bukan ArUco
///
/// Lembar kerjanya kita sendiri yang cetak (`ocr:cetak-lembar` di backend), jadi
/// bentuk markernya kita yang tentukan. ArUco bawa id & orientasi, tapi di
/// halaman A4 keempat sudut urutannya udah pasti dari posisinya sendiri — dan
/// mbaca ArUco butuh OpenCV, puluhan MB di APK buat sesuatu yang nggak kepakai.
///
/// Kotak hitam pejal cukup dideteksi dengan: ambang gelap → titik berat gumpalan
/// per kuadran. Itu Dart murni, dan ini isinya.
class PindaiLembar {
  const PindaiLembar();

  /// Ambang gelap buat memisahkan marker dari kertas.
  ///
  /// Sengaja rendah: yang dicari TINTA HITAM PEJAL, bukan tulisan pensil. Kalau
  /// dinaikin, garis tabel & angka tebal ikut kehitung dan titik beratnya lari.
  static const _ambangGelap = 90;

  /// Marker dicari cuma di POJOK, bukan sekujur halaman.
  ///
  /// Tanpa batas ini, kotak isian yang tergelap (mis. sel yang dicoret) bisa
  /// menang jadi "gumpalan tergelap" dan seluruh grid meleset. Angkanya longgar
  /// (30% sisi) supaya foto yang agak miring atau kejauhan tetap kebaca.
  static const _kuadran = 0.30;

  /// Cari empat penanda sudut di foto.
  ///
  /// `null` = nggak ketemu keempatnya. Itu BUKAN error yang perlu ditelan:
  /// tanpa empat sudut, nggak ada cara meratakan fotonya, dan meratakan pakai
  /// tiga sudut berarti menebak yang keempat — persis tebakan yang bikin angka
  /// mendarat di sel sebelah.
  List<Sudut>? cariMarker(img.Image foto) {
    final w = foto.width;
    final h = foto.height;
    final lebarKuadran = (w * _kuadran).round();
    final tinggiKuadran = (h * _kuadran).round();

    // Urutannya DIPATOK: kiri-atas, kanan-atas, kanan-bawah, kiri-bawah — sama
    // dengan urutan `marker` di berkas geometri (id 0..3).
    final kuadran = <({int x0, int y0, int x1, int y1})>[
      (x0: 0, y0: 0, x1: lebarKuadran, y1: tinggiKuadran),
      (x0: w - lebarKuadran, y0: 0, x1: w, y1: tinggiKuadran),
      (x0: w - lebarKuadran, y0: h - tinggiKuadran, x1: w, y1: h),
      (x0: 0, y0: h - tinggiKuadran, x1: lebarKuadran, y1: h),
    ];

    // Sudut halaman yang dituju tiap kuadran — dipakai buat milih gumpalan
    // mana yang marker. Urutannya sama dengan `kuadran` di atas.
    final sudut = <({int x, int y})>[
      (x: 0, y: 0),
      (x: w - 1, y: 0),
      (x: w - 1, y: h - 1),
      (x: 0, y: h - 1),
    ];

    final hasil = <Sudut>[];

    for (var i = 0; i < kuadran.length; i++) {
      final k = kuadran[i];
      final titik = _titikBeratGelap(
        foto,
        k.x0,
        k.y0,
        k.x1,
        k.y1,
        sudutX: sudut[i].x,
        sudutY: sudut[i].y,
      );

      if (titik == null) return null;
      hasil.add(titik);
    }

    return hasil;
  }

  /// Gumpalan yang lebih kecil dari ini dianggap bintik, bukan marker.
  ///
  /// Marker tercetak 90 px di ruang template; cincin hitamnya sendiri ~5.000
  /// piksel. Ambang 200 memberi ruang buat foto yang jauh lebih kecil dari
  /// lembar aslinya, tanpa meloloskan noda sensor.
  static const _selGumpalanMin = 200;

  /// Tetangga yang dianggap masih satu gumpalan: jendela 5×5, bukan 4 arah.
  ///
  /// Marker di foto nyata jarang utuh. Perspektif bikin piksel diambil dengan
  /// tetangga terdekat, dan barisan piksel yang seharusnya rapat jadi
  /// berlubang selebar 1 px; bayangan tipis & ambang gelap yang ketat bisa
  /// memutusnya juga. Empat arah bikin satu marker terbaca sebagai belasan
  /// serpihan, masing-masing terlalu kecil buat lolos [_selGumpalanMin], dan
  /// hasilnya `null` — pindai gagal total padahal markernya kelihatan jelas
  /// oleh mata.
  ///
  /// Jarak 2 px cukup buat menjembatani lubang selebar 1 px, dan masih jauh
  /// lebih rapat dari jarak marker ke tulisan terdekat di lembar kita.
  static const _tetangga = [
    [-2, -2], [-1, -2], [0, -2], [1, -2], [2, -2],
    [-2, -1], [-1, -1], [0, -1], [1, -1], [2, -1],
    [-2, 0], [-1, 0], [1, 0], [2, 0],
    [-2, 1], [-1, 1], [0, 1], [1, 1], [2, 1],
    [-2, 2], [-1, 2], [0, 2], [1, 2], [2, 2],
  ];

  /// Titik berat SATU GUMPALAN gelap — yang paling dekat sudut halaman.
  ///
  /// ## Kenapa bukan titik berat seluruh kuadran
  ///
  /// Dulu begitu, dan itu salah dengan cara yang nggak kelihatan. Kuadrannya
  /// 30% sisi halaman — di lembar cetak kita sendiri, kotak itu ikut memuat
  /// teks kop (kiri-atas) dan QR versi lembar (kanan-atas). Dua-duanya tinta
  /// hitam, jadi dua-duanya ikut ditimbang, dan pusatnya ketarik ke dalam.
  ///
  /// Diukur di `test/assets/lembar-conductivity-v1.png`: marker kiri-atas yang
  /// semestinya di (90, 90) kebaca di (130,7 · 116,0) — meleset 41 px. Meleset
  /// segitu di keempat sudut bikin warp-nya menyusut, dan tiap sel kepotong
  /// bergeser. Nggak ada error yang muncul; angkanya cuma mendarat agak
  /// melenceng, dan makin ke tengah halaman makin parah.
  ///
  /// Sekarang: dari piksel gelap yang paling dekat sudut, gumpalannya
  /// ditelusuri (flood fill 4-arah) sampai habis, lalu titik beratnya diambil
  /// dari gumpalan ITU saja. Teks & QR gumpalan lain — nggak nyambung ke
  /// marker, jadi nggak pernah ikut. Titik beratnya sendiri tetap dipakai
  /// (bukan kotak pembatas), sama alasannya seperti dulu: satu piksel nyasar
  /// bikin kotak pembatas melar, titik berat cuma bergeser sedikit.
  ///
  /// Gumpalan yang terlalu kecil dilewati, bukan dipakai — noda sensor di ujung
  /// halaman lebih dekat ke sudut daripada markernya.
  Sudut? _titikBeratGelap(
    img.Image foto,
    int x0,
    int y0,
    int x1,
    int y1, {
    required int sudutX,
    required int sudutY,
  }) {
    final lebar = x1 - x0;
    final tinggi = y1 - y0;

    if (lebar <= 0 || tinggi <= 0) return null;

    bool gelap(int x, int y) {
      final p = foto.getPixel(x, y);

      return (p.r * 0.299 + p.g * 0.587 + p.b * 0.114) <= _ambangGelap;
    }

    // Semua piksel gelap kuadran, diurutkan dari yang paling dekat sudut.
    // Kandidat benih ditelusuri berurutan sampai ketemu gumpalan yang cukup
    // besar buat disebut marker.
    final benih = <int>[];

    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (gelap(x, y)) benih.add((y - y0) * lebar + (x - x0));
      }
    }

    if (benih.length < _selGumpalanMin) return null;

    double jarak(int i) {
      final dx = (i % lebar + x0) - sudutX;
      final dy = (i ~/ lebar + y0) - sudutY;

      return (dx * dx + dy * dy).toDouble();
    }

    benih.sort((a, b) => jarak(a).compareTo(jarak(b)));

    final sudahDilihat = List<bool>.filled(lebar * tinggi, false);

    for (final awal in benih) {
      if (sudahDilihat[awal]) continue;

      var jumlahX = 0.0;
      var jumlahY = 0.0;
      var n = 0;

      // Flood fill iteratif — rekursif bakal kehabisan tumpukan di gumpalan
      // sebesar QR.
      final tumpuk = <int>[awal];
      sudahDilihat[awal] = true;

      while (tumpuk.isNotEmpty) {
        final i = tumpuk.removeLast();
        final lx = i % lebar;
        final ly = i ~/ lebar;

        jumlahX += lx + x0;
        jumlahY += ly + y0;
        n++;

        for (final d in _tetangga) {
          final nx = lx + d[0];
          final ny = ly + d[1];

          if (nx < 0 || ny < 0 || nx >= lebar || ny >= tinggi) continue;

          final j = ny * lebar + nx;
          if (sudahDilihat[j]) continue;
          if (!gelap(nx + x0, ny + y0)) continue;

          sudahDilihat[j] = true;
          tumpuk.add(j);
        }
      }

      if (n >= _selGumpalanMin) return (x: jumlahX / n, y: jumlahY / n);
    }

    return null;
  }

  /// Ratakan foto ke ruang template lewat warp perspektif dari empat sudut.
  ///
  /// Sesudah ini, koordinat sel di berkas geometri bisa dipakai APA ADANYA —
  /// dan itu inti keselamatan fitur ini: yang dipotong bukan tebakan posisi,
  /// tapi kotak yang sama persis dengan yang dipakai waktu lembarnya dicetak.
  HasilWarp warp(
    img.Image foto,
    List<Sudut> marker, {
    required int lebar,
    required int tinggi,
    required List<Sudut> tujuan,
  }) {
    final m = _homografi(marker, tujuan);
    final hasil = img.Image(width: lebar, height: tinggi);

    // Diputihin dulu. Foto yang miring nggak pernah menutupi seluruh ruang
    // template — ada pinggiran yang nggak kepetakan, dan `img.Image` lahir
    // HITAM PEKAT. Pinggiran hitam itu bukan cuma jelek di `citra_warp` yang
    // dilampirkan sebagai bukti: dia gumpalan gelap terbesar di pojok, jadi
    // apa pun yang mencari marker di citra hasil warp bakal menemukan dia,
    // bukan markernya. Putih = "di luar kertas", dan itu yang benar.
    img.fill(hasil, color: img.ColorRgb8(255, 255, 255));

    // Dipetakan MUNDUR (tujuan → sumber) supaya nggak ada piksel bolong: kalau
    // maju, beberapa piksel tujuan nggak pernah kesentuh dan hasilnya berlubang.
    final balik = _invers(m);

    for (var y = 0; y < tinggi; y++) {
      for (var x = 0; x < lebar; x++) {
        final d = balik[6] * x + balik[7] * y + balik[8];
        if (d == 0) continue;

        final sx = (balik[0] * x + balik[1] * y + balik[2]) / d;
        final sy = (balik[3] * x + balik[4] * y + balik[5]) / d;

        if (sx < 0 || sy < 0 || sx >= foto.width || sy >= foto.height) continue;

        // Dibulatkan SESUDAH batasnya diperiksa, jadi harus dijepit lagi:
        // `1653,6` lolos pemeriksaan `< 1654` lalu membulat jadi `1654` —
        // satu di luar jangkauan, dan `image` melemparnya sebagai RangeError
        // yang menjatuhkan seluruh pindai. Cuma kena di baris & kolom paling
        // ujung, jadi foto yang pas-pasan rata nggak pernah memicunya; yang
        // memicu justru foto miring, yang justru bentuk normalnya.
        hasil.setPixel(
          x,
          y,
          foto.getPixel(
            sx.round().clamp(0, foto.width - 1),
            sy.round().clamp(0, foto.height - 1),
          ),
        );
      }
    }

    return HasilWarp(
      citra: hasil,
      marker: marker,
      residualPx: _residual(marker, tujuan, m),
    );
  }

  /// Potong satu sel dari citra yang UDAH diratakan.
  ///
  /// Margin kecil ditambahkan biar garis kotaknya sendiri nggak ikut kepotong —
  /// garis hitam di tepi crop gampang kebaca ML Kit sebagai `1` atau `-`.
  img.Image potongSel(
    img.Image warp, {
    required double x,
    required double y,
    required double w,
    required double h,
    double margin = 0.06,
  }) {
    final mx = (w * margin).round();
    final my = (h * margin).round();

    return img.copyCrop(
      warp,
      x: (x + mx).round().clamp(0, warp.width - 1),
      y: (y + my).round().clamp(0, warp.height - 1),
      width: (w - mx * 2).round().clamp(1, warp.width),
      height: (h - my * 2).round().clamp(1, warp.height),
    );
  }

  /// Skor mutu foto — dihitung DI HP supaya teknisi nggak nunggu server cuma
  /// buat ditolak.
  ///
  /// Ambangnya milik server (`config/ocr.php`); yang di sini cuma menghitung,
  /// bukan memutuskan. Angkanya dikirim apa adanya, nggak dibulatkan.
  ({double blur, double kecerahan, double glare}) mutu(img.Image citra) {
    // Laplacian variance: makin tajam, makin besar sebarannya.
    var jumlah = 0.0;
    var jumlahKuadrat = 0.0;
    var n = 0;
    var totalAbu = 0.0;
    var terang = 0;

    for (var y = 1; y < citra.height - 1; y++) {
      for (var x = 1; x < citra.width - 1; x++) {
        double abu(int px, int py) {
          final p = citra.getPixel(px, py);

          return p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
        }

        final pusat = abu(x, y);
        final lap = abu(x - 1, y) +
            abu(x + 1, y) +
            abu(x, y - 1) +
            abu(x, y + 1) -
            4 * pusat;

        jumlah += lap;
        jumlahKuadrat += lap * lap;
        totalAbu += pusat;
        if (pusat > 245) terang++;
        n++;
      }
    }

    if (n == 0) return (blur: 0, kecerahan: 0, glare: 0);

    final rata = jumlah / n;

    return (
      blur: jumlahKuadrat / n - rata * rata,
      kecerahan: totalAbu / n,
      glare: terang / n,
    );
  }

  /// Homografi 3x3 dari empat pasang titik (sumber → tujuan).
  ///
  /// Diselesaikan sebagai sistem linear 8x8 dengan eliminasi Gauss. Ditulis
  /// sendiri, bukan narik paket aljabar: cuma butuh satu fungsi, dan
  /// dependensi tambahan di jalur yang menyentuh data pelanggan itu ongkos yang
  /// nggak sebanding.
  List<double> _homografi(List<Sudut> sumber, List<Sudut> tujuan) {
    final a = List.generate(8, (_) => List<double>.filled(9, 0));

    for (var i = 0; i < 4; i++) {
      final s = sumber[i];
      final t = tujuan[i];

      a[i * 2] = [s.x, s.y, 1, 0, 0, 0, -s.x * t.x, -s.y * t.x, t.x];
      a[i * 2 + 1] = [0, 0, 0, s.x, s.y, 1, -s.x * t.y, -s.y * t.y, t.y];
    }

    for (var kolom = 0; kolom < 8; kolom++) {
      var pivot = kolom;
      for (var baris = kolom + 1; baris < 8; baris++) {
        if (a[baris][kolom].abs() > a[pivot][kolom].abs()) pivot = baris;
      }

      final tukar = a[kolom];
      a[kolom] = a[pivot];
      a[pivot] = tukar;

      final p = a[kolom][kolom];
      if (p.abs() < 1e-12) continue;

      for (var j = kolom; j < 9; j++) {
        a[kolom][j] /= p;
      }

      for (var baris = 0; baris < 8; baris++) {
        if (baris == kolom) continue;
        final f = a[baris][kolom];
        if (f == 0) continue;

        for (var j = kolom; j < 9; j++) {
          a[baris][j] -= f * a[kolom][j];
        }
      }
    }

    return [for (var i = 0; i < 8; i++) a[i][8], 1];
  }

  List<double> _invers(List<double> m) {
    final det = m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);

    if (det.abs() < 1e-12) return m;

    return [
      (m[4] * m[8] - m[5] * m[7]) / det,
      (m[2] * m[7] - m[1] * m[8]) / det,
      (m[1] * m[5] - m[2] * m[4]) / det,
      (m[5] * m[6] - m[3] * m[8]) / det,
      (m[0] * m[8] - m[2] * m[6]) / det,
      (m[2] * m[3] - m[0] * m[5]) / det,
      (m[3] * m[7] - m[4] * m[6]) / det,
      (m[1] * m[6] - m[0] * m[7]) / det,
      (m[0] * m[4] - m[1] * m[3]) / det,
    ];
  }

  /// Rata-rata jarak sudut hasil proyeksi ke posisi yang diharapkan.
  ///
  /// Ini yang dikirim sebagai `residual_reproyeksi_px`. Nilai besar artinya
  /// keempat "sudut" yang ketemu bukan sudut lembar — mis. tiga marker + satu
  /// bayangan gelap. Server nolak di atas 2 px, dan itu penjagaan yang bener:
  /// lebih baik foto ulang daripada grid yang meleset diam-diam.
  double _residual(List<Sudut> sumber, List<Sudut> tujuan, List<double> m) {
    var total = 0.0;

    for (var i = 0; i < sumber.length; i++) {
      final s = sumber[i];
      final d = m[6] * s.x + m[7] * s.y + m[8];
      if (d == 0) continue;

      final px = (m[0] * s.x + m[1] * s.y + m[2]) / d;
      final py = (m[3] * s.x + m[4] * s.y + m[5]) / d;

      total += math.sqrt(
        math.pow(px - tujuan[i].x, 2) + math.pow(py - tujuan[i].y, 2),
      );
    }

    return total / sumber.length;
  }

  /// Baca citra dari byte foto. `null` kalau formatnya nggak dikenal.
  img.Image? baca(Uint8List byte) => img.decodeImage(byte);
}
