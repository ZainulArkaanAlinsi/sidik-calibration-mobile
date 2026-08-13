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

    final hasil = <Sudut>[];

    for (final k in kuadran) {
      final titik = _titikBeratGelap(foto, k.x0, k.y0, k.x1, k.y1);
      if (titik == null) return null;
      hasil.add(titik);
    }

    return hasil;
  }

  /// Titik berat piksel gelap di satu kuadran.
  ///
  /// Dipakai titik berat, bukan kotak pembatas: kotak pembatas ikut melar kalau
  /// ada satu piksel gelap nyasar di pinggir kuadran (bayangan jari, garis
  /// tepi), sementara titik berat cuma bergeser sedikit.
  Sudut? _titikBeratGelap(img.Image foto, int x0, int y0, int x1, int y1) {
    var jumlahX = 0.0;
    var jumlahY = 0.0;
    var n = 0;

    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final p = foto.getPixel(x, y);
        final abu = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round();

        if (abu <= _ambangGelap) {
          jumlahX += x;
          jumlahY += y;
          n++;
        }
      }
    }

    // Kertas polos tanpa marker bakal ngasih segelintir piksel gelap dari noise
    // sensor. Ambang jumlah ini yang misahin "ada markernya" dari "kebetulan
    // ada bintik".
    if (n < 200) return null;

    return (x: jumlahX / n, y: jumlahY / n);
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

        hasil.setPixel(x, y, foto.getPixel(sx.round(), sy.round()));
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
