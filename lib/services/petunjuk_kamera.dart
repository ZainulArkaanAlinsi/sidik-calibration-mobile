import 'dart:isolate';
import 'dart:typed_data';

import 'jalankan_pindai.dart' show AmbangMutu;

/// Ambang awal petunjuk langsung layar kamera — SATU sumber untuk semua angka.
///
/// ## Asal angka (13 Nov 2026) — PERLU DIKALIBRASI DI PERANGKAT
///
/// Semua nilai di bawah adalah USULAN dari uji degradasi sintetis pada DUA foto
/// lembar nyata di rig (bukan terbukti, bukan dari ukuran HP asli). Besaran
/// dihitung pada bingkai yang diperkecil ke sisi panjang
/// [sisiPanjangAnalisisPx] (foto asli rig: variansi Laplacian 3476 dan 1979;
/// rasio gradien x/y 0,42–0,45). Frame kamera HP bisa beda (resolusi analisis,
/// pencahayaan, isi lembar yang lebih jarang dari dua contoh itu), jadi angka
/// ini hanya dipakai untuk SARAN di layar kamera — tidak pernah memblokir
/// jepret.
///
/// Yang SENGAJA tidak berubah: [AmbangMutu] (salinan `config/ocr.php` server)
/// tetap penentu penolakan pasca-jepret. Pasangan yang sama dipakai bersama
/// dan dijaga `test/petunjuk_kamera_test.dart`.
abstract final class AmbangFotoLembar {
  /// Sisi panjang bingkai tempat semua besaran di bawah dihitung.
  static const sisiPanjangAnalisisPx = 1000;

  // ── Blur (variansi Laplacian pada bingkai ±1000 px) ────────────────────────
  /// ≥ ini = tajam.
  static const blurBaikMin = 1500.0;

  /// < ini = saran foto ulang. Di antara [blurSaranUlangMaks] dan
  /// [blurBaikMin] = peringatan (belum ditampilkan sebagai saran).
  static const blurSaranUlangMaks = 600.0;

  // ── Blur gerak (rasio energi gradien lemah ÷ kuat) ─────────────────────────
  /// Asli 0,42–0,45. < ini = saran foto ulang. Dihitung sebagai min÷maks
  /// energi gradien horizontal/vertikal, jadi tak tergantung apakah buffer
  /// kamera sudah diputar sesuai tegaknya lembar.
  static const gerakRasioMin = 0.25;

  // ── Resolusi (BELUM terhubung ke layar: tak terukur dari frame langsung) ──
  /// Tinggi baris tabel di foto penuh: ≥ baik, < tolak. Tolak ≈ 24 px =
  /// `AmbangMutu.pxPerSelMin` (gerbang pasca-jepret yang sudah ada).
  static const tinggiBarisBaikPx = 35.0;
  static const tinggiBarisTolakPx = 25.0;

  /// Sisi panjang foto yang setara bila lembar memenuhi bingkai. Resolusi
  /// jepret kamera sendiri (`resolusiKameraPindai`) dijaga ≥ ini oleh test.
  static const sisiPanjangMinPx = 3300;

  // ── Gelap (median kecerahan kertas, 0–255) ─────────────────────────────────
  /// ≥ ini = baik; di antara [kecerahanSaranSenterMaks] dan ini = peringatan.
  static const kecerahanBaikMin = 100.0;

  /// < ini = saran senter. Sama dengan `AmbangMutu.kecerahanMin` (penolakan
  /// pasca-jepret) — SATU angka, dipinjam, bukan salinan.
  static const kecerahanSaranSenterMaks = AmbangMutu.kecerahanMin;

  // ── Bayangan (blok-blok kertas: persentil-5 ÷ persentil-95) ────────────────
  static const bayanganRasioMin = 0.25;

  /// Kecerahan blok kertas paling gelap (persentil-5) minimal.
  static const bayanganTergelapMin = 50.0;

  // ── Silau (porsi piksel jenuh di area kertas) ──────────────────────────────
  static const jenuhMin = 250;
  static const jenuhPorsiMaks = 0.10;

  // ── Posisi ─────────────────────────────────────────────────────────────────
  /// Miring kamera (BELUM terhubung: tak terukur tanpa sensor). Gerbang
  /// pasca-jepret tetap `AmbangMutu.miringMaksDeg` (8°).
  static const miringKameraMaksDeg = 15.0;

  /// Margin bingkai: pita tepi setebal ini (pecahan sisi frame) yang kebanyakan
  /// kertas = halaman mungkin terpotong.
  static const marginTepi = 0.02;

  /// Jeda antar contoh frame. Biaya utamanya menyalin frame dari kamera ke
  /// Dart, bukan hitungannya (dikerjakan di isolate lain).
  static const selangContoh = Duration(milliseconds: 700);

  /// Contoh frame yang tak pernah datang (kosong/timeout) berturut-turut
  /// sebelum petunjuk langsung dihentikan: tiap putaran start/stop aliran
  /// frame ada biayanya, jadi tidak boleh berputar selamanya.
  static const contohKosongMaks = 3;
}

/// Satu frame dari kamera, hanya kanal TERANG (luma) — cukup untuk petunjuk
/// langsung di layar kamera. Warna tidak dibutuhkan, dan kanal lain tidak
/// pernah disalin: [bita] menunjuk langsung ke plane yang dikirim kamera.
///
/// Android (YUV420/NV21): plane Y, [langkahPiksel] 1, [awal] 0.
/// iOS (BGRA): satu plane, [langkahPiksel] 4, [awal] 1 (kanal hijau — bobot
/// terbesar dalam luma, dan petunjuk ini memang kasar).
class FrameLuma {
  const FrameLuma({
    required this.bita,
    required this.lebar,
    required this.tinggi,
    required this.barisBita,
    this.langkahPiksel = 1,
    this.awal = 0,
  });

  final Uint8List bita;
  final int lebar;
  final int tinggi;

  /// Byte per baris (rowStride) — bisa lebih besar dari [lebar] * langkah.
  final int barisBita;
  final int langkahPiksel;
  final int awal;

  int luma(int x, int y) => bita[awal + y * barisBita + x * langkahPiksel];
}

/// Hasil ukur kasar satu frame (pada bingkai ±[AmbangFotoLembar.sisiPanjangAnalisisPx]).
class UkuranFrame {
  const UkuranFrame({
    required this.kecerahanKertas,
    required this.glare,
    required this.ketajaman,
    required this.anisotropi,
    required this.bayanganRasio,
    required this.bayanganTergelap,
    required this.kertasTerlihat,
    required this.sisiMenyentuhTepi,
  });

  /// Kecerahan kertas (0–255): persentil-75 luma jendela tengah. Kertas adalah
  /// mode terang; tinta dan alas gelap hanyalah minoritas gelapnya.
  final double kecerahanKertas;

  /// Porsi piksel jenuh (≥ [AmbangFotoLembar.jenuhMin]) di antara piksel
  /// kertas jendela tengah; 0 bila kertas terlalu sedikit untuk dinilai.
  final double glare;

  /// Variansi Laplacian piksel di dekat kertas (rumus `PindaiLembar.mutu`).
  /// `null` bila tidak ada kertas.
  final double? ketajaman;

  /// min÷maks energi gradien x/y — 1 = merata, mendekati 0 = tersapu satu arah
  /// (blur gerak). `null` bila tak terukur.
  final double? anisotropi;

  /// Persentil-5 ÷ persentil-95 kecerahan blok-blok kertas (tinta diabaikan
  /// karena tiap blok diwakili persentil-90-nya). `null` bila blok terlalu
  /// sedikit.
  final double? bayanganRasio;

  /// Persentil-5 kecerahan blok kertas (0–255).
  final double? bayanganTergelap;

  /// Ada kertas (area terang cukup luas) di jendela tengah.
  final bool kertasTerlihat;

  /// Berapa dari empat tepi frame (0..4) yang hampir seluruhnya kertas —
  /// tanda kertas melewati tepi bingkai kamera.
  final int sisiMenyentuhTepi;
}

/// Pengukur kasar untuk petunjuk langsung layar kamera.
///
/// ## Performa
///
/// Frame kamera (bisa 3840×2160) diperkecil dulu ke sisi panjang
/// [AmbangFotoLembar.sisiPanjangAnalisisPx] dengan rata-rata kotak, lalu diukur:
/// ±1 juta langkah sederhana tanpa alokasi per piksel. Itu terlalu berat untuk
/// isolate UI di HP murah, jadi layar memakai [ukurFrameDiIsolate] (isolate
/// lain) sekali per contoh frame, bukan per frame.
///
/// ## Apa yang BUKAN
///
/// Ini bukan gerbang mutu. Gerbangnya tetap `AmbangMutu` pasca-jepret. Semua
/// batas di sini ada di [AmbangFotoLembar] dan masih perlu dikalibrasi di
/// perangkat.
abstract final class UkurFrame {
  /// Pecahan frame di tiap sisi yang DIBUANG dari jendela tengah (15% → jendela
  /// = 70% tengah). Tempat kertas seharusnya berada; alas gelap di tepi tidak
  /// ikut menurunkan kecerahan.
  static const potongJendela = 0.15;

  /// Piksel "kertas": ≥ [porsiKertasRel] × persentil-90 jendela, dan tidak
  /// kurang dari [kertasMin]. Relatif supaya kertas yang agak gelap pun masih
  /// dikenali sebagai kertas.
  static const porsiKertasRel = 0.6;
  static const kertasMin = AmbangMutu.kecerahanMin;

  /// Porsi jendela yang harus kertas supaya "kertas terlihat".
  static const porsiKertasMin = 0.25;

  /// Persentil yang mewakili kecerahan kertas.
  static const persentilKertas = 0.75;

  /// Porsi pita tepi yang harus kertas supaya tepi itu dianggap tersentuh.
  static const porsiPitaKertas = 0.60;

  /// Jendela dibagi blok sebanyak ini per sumbu untuk menilai bayangan, dan
  /// minimal sebanyak ini blok kertas agar penilaian dianggap sah.
  static const blokPerSumbu = 10;
  static const blokKertasMin = 9;

  /// `null` kalau [asli] terlalu kecil untuk diukur.
  static UkuranFrame? ukur(FrameLuma asli) {
    if (asli.lebar < 32 || asli.tinggi < 32) return null;

    final f = _padat(asli, AmbangFotoLembar.sisiPanjangAnalisisPx);
    final w = f.lebar;
    final h = f.tinggi;
    final b = f.bita;

    final x0 = (w * potongJendela).round();
    final x1 = (w * (1 - potongJendela)).round();
    final y0 = (h * potongJendela).round();
    final y1 = (h * (1 - potongJendela)).round();

    final hist = Int32List(256);
    var n = 0;
    for (var y = y0; y < y1; y++) {
      final baris = y * w;
      for (var x = x0; x < x1; x++) {
        hist[b[baris + x]]++;
        n++;
      }
    }
    if (n == 0) return null;

    final p90 = _persentil(hist, n, 0.90);
    final kecerahanKertas = _persentil(hist, n, persentilKertas).toDouble();
    final ambang = (porsiKertasRel * p90) < kertasMin
        ? kertasMin
        : porsiKertasRel * p90;

    var kertas = 0;
    var jenuh = 0;
    for (var v = 0; v < 256; v++) {
      if (v < ambang) continue;
      kertas += hist[v];
      if (v >= AmbangFotoLembar.jenuhMin) jenuh += hist[v];
    }
    final porsiKertas = kertas / n;
    final kertasTerlihat = porsiKertas >= porsiKertasMin && p90 >= kertasMin;
    // Terlalu sedikit kertas (mis. satu lampu di ruang gelap) tidak dinilai
    // silau.
    final glare = porsiKertas >= porsiKertasMin && kertas > 0
        ? jenuh / kertas
        : 0.0;

    double? ketajaman;
    double? anisotropi;
    double? bayanganRasio;
    double? bayanganTergelap;
    var sisi = 0;

    if (kertasTerlihat) {
      var m = 0;
      var jumlah = 0.0;
      var kuadrat = 0.0;
      var ex = 0.0;
      var ey = 0.0;
      for (var y = y0 + 1; y < y1 - 1; y++) {
        final baris = y * w;
        for (var x = x0 + 1; x < x1 - 1; x++) {
          final i = baris + x;
          final c = b[i];
          final l = b[i - 1];
          final r = b[i + 1];
          final u = b[i - w];
          final d = b[i + w];
          // Jauh dari kertas (alas gelap polos): tidak ikut diukur.
          if (c < ambang &&
              l < ambang &&
              r < ambang &&
              u < ambang &&
              d < ambang) {
            continue;
          }
          final lap = l + r + u + d - 4 * c;
          jumlah += lap;
          kuadrat += lap * lap;
          final gx = r - l;
          final gy = d - u;
          ex += gx * gx;
          ey += gy * gy;
          m++;
        }
      }
      if (m > 0) {
        final rata = jumlah / m;
        ketajaman = kuadrat / m - rata * rata;
        final besar = ex > ey ? ex : ey;
        final kecil = ex > ey ? ey : ex;
        if (besar > 0) anisotropi = kecil / besar;
      }

      final bayangan = _bayangan(b, w, x0, x1, y0, y1, ambang);
      bayanganRasio = bayangan?.rasio;
      bayanganTergelap = bayangan?.tergelap;
      sisi = _sisiMenyentuhTepi(b, w, h, ambang);
    }

    return UkuranFrame(
      kecerahanKertas: kecerahanKertas,
      glare: glare,
      ketajaman: ketajaman,
      anisotropi: anisotropi,
      bayanganRasio: bayanganRasio,
      bayanganTergelap: bayanganTergelap,
      kertasTerlihat: kertasTerlihat,
      sisiMenyentuhTepi: sisi,
    );
  }

  /// Frame jadi larik luma padat (tanpa stride/pad), diperkecil dengan
  /// rata-rata kotak sampai sisi panjangnya ≤ [sisiPanjang].
  static ({Uint8List bita, int lebar, int tinggi}) _padat(
    FrameLuma f,
    int sisiPanjang,
  ) {
    final panjang = f.lebar > f.tinggi ? f.lebar : f.tinggi;
    final k = (panjang + sisiPanjang - 1) ~/ sisiPanjang;
    final w = f.lebar ~/ k;
    final h = f.tinggi ~/ k;
    final keluar = Uint8List(w * h);

    if (k == 1) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          keluar[y * w + x] = f.luma(x, y);
        }
      }

      return (bita: keluar, lebar: w, tinggi: h);
    }

    final bagi = k * k;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var jumlah = 0;
        for (var dy = 0; dy < k; dy++) {
          for (var dx = 0; dx < k; dx++) {
            jumlah += f.luma(x * k + dx, y * k + dy);
          }
        }
        keluar[y * w + x] = jumlah ~/ bagi;
      }
    }

    return (bita: keluar, lebar: w, tinggi: h);
  }

  static int _persentil(Int32List hist, int n, double q) {
    final target = (n * q).ceil().clamp(1, n);
    var acc = 0;
    for (var v = 0; v < 256; v++) {
      acc += hist[v];
      if (acc >= target) return v;
    }

    return 255;
  }

  /// Bayangan: tiap blok diwakili persentil-90-nya (tinta diabaikan), lalu
  /// blok-blok DI DALAM kotak pembatas blok yang terang (kertas) dibandingkan.
  /// Bayangan yang memotong sisi kertas (separuh halaman gelap) berada di luar
  /// kotak itu dan tidak terdeteksi — batasan yang diketahui.
  static ({double rasio, double tergelap})? _bayangan(
    Uint8List b,
    int w,
    int x0,
    int x1,
    int y0,
    int y1,
    double ambang,
  ) {
    const g = blokPerSumbu;
    final lebarBlok = (x1 - x0) ~/ g;
    final tinggiBlok = (y1 - y0) ~/ g;
    if (lebarBlok < 2 || tinggiBlok < 2) return null;

    final nilai = List<int>.filled(g * g, 0);
    final hist = Int32List(256);
    for (var by = 0; by < g; by++) {
      for (var bx = 0; bx < g; bx++) {
        hist.fillRange(0, 256, 0);
        for (
          var y = y0 + by * tinggiBlok;
          y < y0 + (by + 1) * tinggiBlok;
          y++
        ) {
          final baris = y * w;
          for (
            var x = x0 + bx * lebarBlok;
            x < x0 + (bx + 1) * lebarBlok;
            x++
          ) {
            hist[b[baris + x]]++;
          }
        }
        nilai[by * g + bx] = _persentil(hist, lebarBlok * tinggiBlok, 0.90);
      }
    }

    var minX = g;
    var maxX = -1;
    var minY = g;
    var maxY = -1;
    for (var by = 0; by < g; by++) {
      for (var bx = 0; bx < g; bx++) {
        if (nilai[by * g + bx] < ambang) continue;
        if (bx < minX) minX = bx;
        if (bx > maxX) maxX = bx;
        if (by < minY) minY = by;
        if (by > maxY) maxY = by;
      }
    }
    if (maxX < 0) return null;

    final dalam = <int>[
      for (var by = minY; by <= maxY; by++)
        for (var bx = minX; bx <= maxX; bx++) nilai[by * g + bx],
    ]..sort();
    if (dalam.length < blokKertasMin) return null;

    final p5 = dalam[((dalam.length - 1) * 0.05).floor()];
    final p95 = dalam[((dalam.length - 1) * 0.95).floor()];
    if (p95 <= 0) return null;

    return (rasio: p5 / p95, tergelap: p5.toDouble());
  }

  /// Empat pita tepi (kiri, kanan, atas, bawah): berapa yang kebanyakan kertas.
  static int _sisiMenyentuhTepi(Uint8List b, int w, int h, double ambang) {
    final tebalX = (w * AmbangFotoLembar.marginTepi).ceil().clamp(1, w);
    final tebalY = (h * AmbangFotoLembar.marginTepi).ceil().clamp(1, h);

    double porsi(int xa, int xb, int ya, int yb) {
      var n = 0;
      var t = 0;
      for (var y = ya; y < yb; y++) {
        for (var x = xa; x < xb; x++) {
          if (b[y * w + x] >= ambang) t++;
          n++;
        }
      }

      return n == 0 ? 0 : t / n;
    }

    var sisi = 0;
    if (porsi(0, tebalX, 0, h) >= porsiPitaKertas) sisi++;
    if (porsi(w - tebalX, w, 0, h) >= porsiPitaKertas) sisi++;
    if (porsi(0, w, 0, tebalY) >= porsiPitaKertas) sisi++;
    if (porsi(0, w, h - tebalY, h) >= porsiPitaKertas) sisi++;

    return sisi;
  }
}

/// Pengukur frame yang dipakai layar kamera. Bawaan: [ukurFrameDiIsolate].
/// Test menyuntikkan versi sinkron (isolate tidak jalan di jam palsu test).
typedef PengukurFrame = Future<UkuranFrame?> Function(FrameLuma frame);

/// [UkurFrame.ukur] di isolate lain: memperkecil dan mengukur frame bisa
/// puluhan milidetik di HP murah, dan itu tidak boleh menahan frame UI.
Future<UkuranFrame?> ukurFrameDiIsolate(FrameLuma frame) =>
    Isolate.run(() => UkurFrame.ukur(frame));

/// Saran di layar kamera. SARAN — tidak pernah memblokir jepret.
enum PetunjukKamera {
  /// Gelap dan senter bisa dinyalakan (belum menyala).
  gelapNyalakanSenter,

  /// Gelap tapi senter sudah menyala / tidak ada: cari cahaya lain.
  gelapTambahCahaya,

  silau,

  /// Bayangan tajam di atas kertas (tabel terbelah gelap-terang).
  bayangan,

  /// Kertas melewati tepi bingkai: halaman bisa terpotong.
  halamanTerpotong,

  buram,

  /// Gambar tersapu satu arah (HP bergerak).
  buramGerak,

  /// Masih terbaca tapi di bawah kecerahan baik (peringatan).
  agakGelap,
}

/// Pilih SATU saran paling penting, atau `null` kalau frame tampak baik.
///
/// Urutan = apa yang harus dibereskan dulu: gelap (percuma menilai yang lain),
/// silau, bayangan, halaman terpotong (sehalus apa pun, halaman yang terpotong
/// tidak bisa diluruskan), buram, buram gerak, terakhir peringatan agak gelap.
///
/// Semua batas dari [AmbangFotoLembar] — usulan awal yang perlu dikalibrasi di
/// perangkat; di HP berframe kecil atau lembar yang lebih jarang dari contoh
/// rig, ukuran ketajaman bisa bergeser.
PetunjukKamera? petunjukDari(
  UkuranFrame u, {
  required bool senterTersedia,
  required bool senterNyala,
}) {
  if (u.kecerahanKertas < AmbangFotoLembar.kecerahanSaranSenterMaks) {
    return senterTersedia && !senterNyala
        ? PetunjukKamera.gelapNyalakanSenter
        : PetunjukKamera.gelapTambahCahaya;
  }
  if (u.glare > AmbangFotoLembar.jenuhPorsiMaks) return PetunjukKamera.silau;

  if (u.kertasTerlihat) {
    final rasio = u.bayanganRasio;
    final gelapnya = u.bayanganTergelap;
    if (rasio != null &&
        gelapnya != null &&
        (rasio < AmbangFotoLembar.bayanganRasioMin ||
            gelapnya < AmbangFotoLembar.bayanganTergelapMin)) {
      return PetunjukKamera.bayangan;
    }
    if (u.sisiMenyentuhTepi > 0) return PetunjukKamera.halamanTerpotong;

    final tajam = u.ketajaman;
    if (tajam != null && tajam < AmbangFotoLembar.blurSaranUlangMaks) {
      return PetunjukKamera.buram;
    }
    final gerak = u.anisotropi;
    if (gerak != null && gerak < AmbangFotoLembar.gerakRasioMin) {
      return PetunjukKamera.buramGerak;
    }
  }

  if (u.kecerahanKertas < AmbangFotoLembar.kecerahanBaikMin) {
    return PetunjukKamera.agakGelap;
  }

  return null;
}

/// Peredam kedip: saran baru baru tampil setelah muncul [sampelUntukMuncul]
/// kali berturut-turut, dan baru hilang setelah [sampelUntukHilang] sampel
/// bersih berturut-turut. Satu frame buruk (tangan bergoyang sesaat) tidak
/// boleh membuat teks di layar berkedip.
class PenyaringPetunjuk {
  PenyaringPetunjuk({this.sampelUntukMuncul = 2, this.sampelUntukHilang = 2});

  final int sampelUntukMuncul;
  final int sampelUntukHilang;

  PetunjukKamera? _tampil;
  PetunjukKamera? _calon;
  var _hitung = 0;

  PetunjukKamera? get tampil => _tampil;

  /// Masukkan hasil satu sampel; kembalikan saran yang boleh tampil sekarang.
  PetunjukKamera? masukkan(PetunjukKamera? baru) {
    if (baru == _tampil) {
      _calon = null;
      _hitung = 0;

      return _tampil;
    }

    if (baru == _calon) {
      _hitung++;
    } else {
      _calon = baru;
      _hitung = 1;
    }

    final butuh = baru == null ? sampelUntukHilang : sampelUntukMuncul;
    if (_hitung >= butuh) {
      _tampil = baru;
      _calon = null;
      _hitung = 0;
    }

    return _tampil;
  }

  /// Lupakan semuanya (mis. senter baru dinyalakan — sampel lama tak berlaku).
  void ulang() {
    _tampil = null;
    _calon = null;
    _hitung = 0;
  }
}
