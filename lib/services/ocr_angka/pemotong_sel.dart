import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kotak satu sel dalam PIKSEL halaman lurus (boleh pecahan).
typedef KotakPiksel = ({double x, double y, double w, double h});

/// Kenapa [PemotongSel] tidak yakin bagian mana yang milik baris ini.
enum SebabPemotongTakYakin {
  /// Kotak sel terlalu kecil untuk dipotong dengan aman.
  kotakTerlaluKecil,

  /// Tinta milik baris menempel di tepi atas/bawah jendela (batas meluber):
  /// tulisan masih berlanjut di luar yang boleh dilihat.
  tintaMelewatiJendelaVertikal,

  /// Tinta menempel di tepi kiri/kanan jendela: angka pertama/terakhir bisa
  /// terpotong (`19.2000` terbaca `9.2000` lolos gerbang format).
  tintaMenempelTepiSamping,

  /// Satu komponen lebih tinggi daripada baris: coretan atau tulisan baris lain
  /// yang tersambung.
  komponenMelebihiBaris,

  /// Garis datar panjang di tengah sel (STRIP "—", sisa garis tabel yang tidak
  /// terhapus): bukan angka dan jangan sampai terbaca "1".
  garisDatar,
}

/// Hasil memotong satu sel.
class HasilPotongSel {
  const HasilPotongSel({
    this.crop,
    this.sebabTakYakin,
    this.luasTinta = 0,
    this.kiri = 0,
    this.atas = 0,
  });

  /// Tidak ada tulisan milik baris ini (sel kosong, atau hanya garis tabel dan
  /// bintik).
  const HasilPotongSel.kosong() : this();

  /// Crop RGB (abu-abu direplikasi) untuk `PraprosesSel`: kertas putih, hanya
  /// komponen milik baris, dipangkas ke kotak tinta + margin. `null` bila
  /// [sebabTakYakin] = [SebabPemotongTakYakin.kotakTerlaluKecil] atau tidak ada
  /// tulisan.
  final img.Image? crop;

  /// Bukan `null` = pemotong tidak yakin; pemanggil TIDAK boleh menjadikan
  /// bacaan sel ini usulan (sel masuk review, merah).
  final SebabPemotongTakYakin? sebabTakYakin;

  /// Jumlah piksel tinta milik baris (diagnostik).
  final int luasTinta;

  /// Posisi pojok kiri-atas [crop] di halaman (diagnostik/paritas).
  final int kiri;
  final int atas;

  bool get takYakin => sebabTakYakin != null;
}

/// Setelan [PemotongSel]. Hampir semua ukuran RELATIF terhadap tinggi sel `h`
/// (piksel), supaya tidak bergantung resolusi halaman: rig dipasang di foto
/// ±4.100 px lebar (baris ±45 px) sedangkan kanvas pindai di HP 3 px/pt (baris
/// ±25 px). Bidang `...Px` yang diisi mengganti ukuran relatifnya (dipakai alat
/// paritas untuk mengunci angka mutlak rig).
///
/// SEMUA angka di sini disetel dari DUA foto (Sieve, Piston) sambil melihat
/// hasilnya: bukan bukti akurasi lapangan.
class SetelanPemotong {
  const SetelanPemotong({
    this.meluber = 0.60,
    this.marginSamping = 0.11,
    this.marginSampingPx,
    this.panjangGaris = 4 / 3,
    this.panjangGarisPx,
    this.tolGaris = 0.30,
    this.cakupanGarisMin = 0.60,
    this.areaKomponenMin = 0.003,
    this.areaKomponenMinPx,
    this.pitaBaris = 0.15,
    this.padX = 0.35,
    this.padY = 0.15,
    this.luasTotalMin = 0.02,
    this.garisTegakMin = 1.2,
    this.garisTegakLebarMaks = 0.30,
    this.tepiTipisLebarMaks = 0.08,
    this.tepiTipisTinggiMin = 0.9,
    this.tepiAreaMin = 0.02,
    this.dekatSisi = 0.5,
    this.komponenTinggiMaks = 1.35,
    this.garisDatarLebarMin = 1.0,
    this.garisDatarTinggiMaks = 0.30,
    this.garisDatarRasioMin = 4.0,
    this.kernelLatar = 1.8,
    this.kernelLatarPx,
  });

  /// Jendela boleh meluber ke atas/bawah sebanyak ini × `h` (kode rig:
  /// `ext=0.60`; ringkasan tugas menulis ±0,5, angka rig yang dipakai).
  final double meluber;

  /// Sisi kiri/kanan dipotong sebesar ini × `h` (rig: 5 px pada baris ±45 px)
  /// agar garis tegak sel tidak masuk.
  final double marginSamping;
  final int? marginSampingPx;

  /// Garis mendatar = deretan tinta (setelah ditebalkan 3×3) sepanjang minimal
  /// ini × `h` (rig: 60 px pada baris ±45 px).
  final double panjangGaris;
  final int? panjangGarisPx;

  /// Garis tabel hanya dicari dalam jarak ini × `h` dari tepi atas/bawah kotak.
  /// Garis datar di tengah sel adalah TULISAN (STRIP), bukan garis tabel.
  final double tolGaris;

  /// Garis tabel harus membentang minimal sebagian ini dari lebar jendela.
  final double cakupanGarisMin;

  /// Komponen lebih kecil daripada ini × `h²` dibuang (rig: 6 px pada h=45;
  /// paling kecil 3 px).
  final double areaKomponenMin;
  final int? areaKomponenMinPx;

  /// Komponen "milik baris" bila pusat vertikalnya di dalam sel ± ini × `h`.
  final double pitaBaris;

  /// Bantalan di sekeliling kotak tinta (× `h`), mendatar dan menegak.
  final double padX;
  final double padY;

  /// Total tinta milik baris di bawah ini × `h²` dianggap sel kosong (bintik,
  /// debu): satu angka "1" ±0,05, bintik 6–25 px pada h=45 ±0,003–0,012.
  final double luasTotalMin;

  /// Komponen setinggi ini × `h`, selebar paling banyak [garisTegakLebarMaks]
  /// × `h`, dan berada dalam [dekatSisi] × `h` dari tepi kiri/kanan jendela
  /// adalah garis tegak tabel yang masuk jendela: dibuang.
  final double garisTegakMin;
  final double garisTegakLebarMaks;
  final double dekatSisi;

  /// Komponen yang menyentuh tepi kiri/kanan jendela, selebar paling banyak
  /// [tepiTipisLebarMaks] × `h` dan setinggi minimal [tepiTipisTinggiMin] × `h`,
  /// juga garis tegak tabel (serpihan garis yang sedikit melewati margin).
  final double tepiTipisLebarMaks;
  final double tepiTipisTinggiMin;

  /// Komponen yang menyentuh tepi kiri/kanan jendela dan luasnya di bawah ini ×
  /// `h²` adalah serpihan garis/bintik, bukan angka yang terpotong: dibuang
  /// (tanpa itu serpihan membuat crop melebar dan memicu "tidak yakin" palsu).
  final double tepiAreaMin;

  /// Komponen lebih tinggi daripada ini × `h` → tidak yakin.
  final double komponenTinggiMaks;

  /// Komponen selebar minimal ini × `h`, setinggi paling banyak
  /// [garisDatarTinggiMaks] × `h`, berasio lebar/tinggi ≥ [garisDatarRasioMin]
  /// adalah garis datar → tidak yakin.
  final double garisDatarLebarMin;
  final double garisDatarTinggiMaks;
  final double garisDatarRasioMin;

  /// Lebar kernel pelurus latar (dilatasi) × tinggi baris median (rig: 80 px
  /// pada baris ±45 px).
  final double kernelLatar;
  final int? kernelLatarPx;
}

/// Citra halaman lurus + estimasi latar (kecerahan kertas) untuk menormalkan
/// pencahayaan per wilayah. Meniru `pipa.normalisasi` rig:
/// `norm = clip(abu / max(latar, 20), 0, 1,2) × 255`, latar = dilatasi elips
/// pada citra yang dikecilkan 8× → median 5 → Gauss → dibesarkan.
///
/// Hanya abu-abu halaman (1 bita/piksel) dan kisi latar kecil yang disimpan;
/// citra ternormalisasi dihitung PER WILAYAH sel ([isiNorm]), bukan sepenuh
/// halaman.
class HalamanTernormal {
  HalamanTernormal._(
    this.abu,
    this.lebar,
    this.tinggi,
    this._latar,
    this._lw,
    this._lh,
  );

  final Uint8List abu;
  final int lebar;
  final int tinggi;
  final Float32List _latar;
  final int _lw;
  final int _lh;

  /// Faktor pengecilan kisi latar (rig: 8).
  static const skalaLatar = 8;

  /// Bangun dari halaman lurus. [kernelLatarPx]: lebar dilatasi dalam piksel
  /// halaman (rig: 80). Mahal (satu lintasan seluruh halaman) — jalankan di
  /// isolate latar.
  static HalamanTernormal dari(
    img.Image halaman, {
    required int kernelLatarPx,
  }) {
    final w = halaman.width;
    final h = halaman.height;
    final abu = _abuDari(halaman);

    final lw = math.max(1, w ~/ skalaLatar);
    final lh = math.max(1, h ~/ skalaLatar);
    var kecil = _kecilkanRataRata(abu, w, h, lw, lh);

    // Lebar kernel di kisi kecil: ganjil, paling kecil 3 (rig: 80/8 → 11).
    var k = (kernelLatarPx / skalaLatar).round();
    k = math.max(3, k | 1);

    kecil = _dilatasiElips(kecil, lw, lh, k);
    kecil = _median5(kecil, lw, lh);
    kecil = _gaussPantul(kecil, lw, lh, 0.55 * k);

    final latar = Float32List(lw * lh);
    for (var i = 0; i < latar.length; i++) {
      latar[i] = kecil[i].toDouble();
    }

    return HalamanTernormal._(abu, w, h, latar, lw, lh);
  }

  /// Isi [keluar] (baris demi baris, lebar `x1-x0`) dengan abu ternormalisasi
  /// wilayah `[x0,x1) × [y0,y1)`; latar diinterpolasi bilinear dari kisi.
  void isiNorm(int x0, int y0, int x1, int y1, Uint8List keluar) {
    final rw = x1 - x0;
    final sx = lebar / _lw;
    final sy = tinggi / _lh;

    // Bobot horizontal dihitung sekali per panggilan (rw kecil).
    final xa = Int32List(rw);
    final xb = Int32List(rw);
    final wx = Float32List(rw);
    for (var i = 0; i < rw; i++) {
      var f = (x0 + i + 0.5) / sx - 0.5;
      if (f < 0) f = 0;
      if (f > _lw - 1) f = (_lw - 1).toDouble();
      final a = f.floor();
      xa[i] = a;
      xb[i] = math.min(a + 1, _lw - 1);
      wx[i] = f - a;
    }

    var o = 0;
    for (var y = y0; y < y1; y++) {
      var f = (y + 0.5) / sy - 0.5;
      if (f < 0) f = 0;
      if (f > _lh - 1) f = (_lh - 1).toDouble();
      final ja = f.floor();
      final jb = math.min(ja + 1, _lh - 1);
      final wy = f - ja;
      final ra = ja * _lw;
      final rb = jb * _lw;

      for (var i = 0; i < rw; i++) {
        final a = _latar[ra + xa[i]] * (1 - wx[i]) + _latar[ra + xb[i]] * wx[i];
        final b = _latar[rb + xa[i]] * (1 - wx[i]) + _latar[rb + xb[i]] * wx[i];
        final lat = a * (1 - wy) + b * wy;
        final n = abu[y * lebar + x0 + i] / (lat < 20 ? 20 : lat);
        final v = (n > 1.2 ? 1.2 : n) * 255.0;
        keluar[o++] = v >= 255 ? 255 : v.toInt();
      }
    }
  }

  // ---- abu-abu ---------------------------------------------------------------

  /// Abu-abu `cv2.cvtColor` (BGR2GRAY, titik tetap 14 bit) dari citra apa pun.
  static Uint8List _abuDari(img.Image c) {
    var a = c;
    if (a.hasPalette || a.format != img.Format.uint8 || a.numChannels < 3) {
      a = a.convert(format: img.Format.uint8, numChannels: 3);
    }
    final b = a.getBytes(order: img.ChannelOrder.rgb);
    final n = a.width * a.height;
    if (b.length != n * 3) {
      throw StateError('buffer citra ${b.length} bita, bukan RGB padat');
    }
    final keluar = Uint8List(n);
    for (var i = 0, p = 0; i < n; i++, p += 3) {
      keluar[i] =
          (b[p] * 4899 + b[p + 1] * 9617 + b[p + 2] * 1868 + 8192) >> 14;
    }

    return keluar;
  }

  // ---- kisi latar ------------------------------------------------------------

  /// Rata-rata blok (setara `INTER_AREA` untuk pengecilan), dibulatkan.
  static Uint8List _kecilkanRataRata(
    Uint8List abu,
    int w,
    int h,
    int lw,
    int lh,
  ) {
    final keluar = Uint8List(lw * lh);
    final kolom = Int32List(w);

    for (var j = 0; j < lh; j++) {
      final ya = j * h ~/ lh;
      final yb = math.max(ya + 1, (j + 1) * h ~/ lh);
      kolom.fillRange(0, w, 0);
      for (var y = ya; y < yb; y++) {
        final baris = y * w;
        for (var x = 0; x < w; x++) {
          kolom[x] += abu[baris + x];
        }
      }

      for (var i = 0; i < lw; i++) {
        final xa = i * w ~/ lw;
        final xb = math.max(xa + 1, (i + 1) * w ~/ lw);
        var jumlah = 0;
        for (var x = xa; x < xb; x++) {
          jumlah += kolom[x];
        }
        final n = (yb - ya) * (xb - xa);
        keluar[j * lw + i] = (jumlah + n ~/ 2) ~/ n;
      }
    }

    return keluar;
  }

  /// Dilatasi (maks) dengan elemen elips ala `getStructuringElement(ELLIPSE)`.
  static Uint8List _dilatasiElips(Uint8List s, int w, int h, int k) {
    final r = k ~/ 2;
    final setengah = List<int>.generate(k, (i) {
      final dy = i - r;
      if (dy.abs() > r) return -1;
      final invR2 = r == 0 ? 0.0 : 1.0 / (r * r);

      return (r * math.sqrt((r * r - dy * dy) * invR2)).round();
    });

    final keluar = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var m = 0;
        for (var i = 0; i < k; i++) {
          final dx = setengah[i];
          if (dx < 0) continue;
          final yy = y + i - r;
          if (yy < 0 || yy >= h) continue;
          final xa = math.max(0, x - dx);
          final xb = math.min(w - 1, x + dx);
          final baris = yy * w;
          for (var xx = xa; xx <= xb; xx++) {
            final v = s[baris + xx];
            if (v > m) m = v;
          }
        }
        keluar[y * w + x] = m;
      }
    }

    return keluar;
  }

  /// Median 5×5, tepi direplikasi.
  static Uint8List _median5(Uint8List s, int w, int h) {
    final keluar = Uint8List(w * h);
    final jendela = Uint8List(25);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var n = 0;
        for (var dy = -2; dy <= 2; dy++) {
          final yy = math.min(math.max(y + dy, 0), h - 1);
          for (var dx = -2; dx <= 2; dx++) {
            final xx = math.min(math.max(x + dx, 0), w - 1);
            jendela[n++] = s[yy * w + xx];
          }
        }
        // Pengurutan sisip 25 bita: median = indeks 12.
        for (var i = 1; i < 25; i++) {
          final v = jendela[i];
          var j = i - 1;
          while (j >= 0 && jendela[j] > v) {
            jendela[j + 1] = jendela[j];
            j--;
          }
          jendela[j + 1] = v;
        }
        keluar[y * w + x] = jendela[12];
      }
    }

    return keluar;
  }

  /// Gauss terpisah, tepi dipantulkan tanpa mengulang piksel tepi
  /// (`BORDER_REFLECT_101`), keluaran dibulatkan ke bita.
  static Uint8List _gaussPantul(Uint8List s, int w, int h, double sigma) {
    final r = math.max(1, (sigma * 3).ceil());
    final bobot = Float64List(2 * r + 1);
    var total = 0.0;
    for (var i = -r; i <= r; i++) {
      final v = math.exp(-(i * i) / (2 * sigma * sigma));
      bobot[i + r] = v;
      total += v;
    }
    for (var i = 0; i < bobot.length; i++) {
      bobot[i] /= total;
    }

    int pantul(int i, int n) {
      if (n == 1) return 0;
      final p = 2 * (n - 1);
      var j = i % p;
      if (j < 0) j += p;

      return j < n ? j : p - j;
    }

    final tengah = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var jumlah = 0.0;
        for (var i = -r; i <= r; i++) {
          jumlah += s[y * w + pantul(x + i, w)] * bobot[i + r];
        }
        tengah[y * w + x] = jumlah;
      }
    }

    final keluar = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var jumlah = 0.0;
        for (var i = -r; i <= r; i++) {
          jumlah += tengah[pantul(y + i, h) * w + x] * bobot[i + r];
        }
        final v = jumlah.round();
        keluar[y * w + x] = v < 0 ? 0 : (v > 255 ? 255 : v);
      }
    }

    return keluar;
  }
}

/// Pemotong sel v2 ("luas"): memotong tulisan SATU baris dari halaman lurus.
///
/// ## Kenapa ada
///
/// Di foto nyata sel utuh Sieve/Piston berbentuk 5–8:1; model angka berlebar
/// tetap 320 px sehingga 60% sel tidak pernah sampai ke model. Memangkas crop ke
/// kotak tinta menaikkan cakupan tetapi tinta menempel/terpotong di tepi
/// atas-bawah (87 dari 95 sel) sehingga palang atas "7" hilang dan lahir
/// salah-yakin (1/7, 9→1). Varian D rig ("luas") memperbaikinya (cakupan 44,2%,
/// 42/42 benar, 0 salah-yakin — DALAM SAMPEL, dua foto, parameter disetel sambil
/// melihatnya; BUKAN akurasi lapangan). Ini porting Dart-nya.
///
/// ## Langkah (per sel)
///
///  1. Wilayah = kotak sel, meluber vertikal [SetelanPemotong.meluber] × `h`,
///     sisi kiri/kanan dipotong [SetelanPemotong.marginSamping];
///  2. normalisasi pencahayaan ([HalamanTernormal.isiNorm]);
///  3. HAPUS GARIS TABEL MENDATAR: deretan tinta panjang yang berada di tepi
///     atas/bawah kotak (garis terluar di tiap sisi). Garis datar di TENGAH sel
///     adalah tulisan (STRIP "—") dan dibiarkan;
///  4. JEMBATANI goresan yang melintas garis: bila ada tinta di atas DAN di
///     bawah garis dengan celah ≤ ±2× tebal garis, piksel garis di kolom itu
///     dikembalikan menjadi tinta (palang "7", kaki "9", angka yang melewati
///     garis tidak terputus);
///  5. komponen terhubung (8 tetangga); komponen tinggi yang tipis, serpihan
///     tipis di tepi kiri/kanan, dan bintik di tepi dibuang (garis tegak tabel);
///  6. hanya komponen MILIK BARIS yang dipertahankan: pusat vertikalnya di
///     dalam sel ± [SetelanPemotong.pitaBaris] × `h`, luas ≥ batas bintik;
///  7. kanvas putih, salin abu ternormalisasi di sekitar komponen (3×3), pangkas
///     ke kotak tinta + bantalan.
///
/// ## Pemotong tidak yakin → [HasilPotongSel.sebabTakYakin]
///
/// Bila tulisan menempel di tepi jendela (terpotong), satu komponen lebih tinggi
/// daripada baris, atau ada garis datar panjang di tengah sel. Pemanggil
/// meneruskannya sebagai `perluCek`; model tidak dijalankan.
///
/// ## Performa
///
/// Satu lintasan seluruh halaman (abu-abu + kisi latar), lalu kerja per sel
/// hanya di wilayahnya. Penyangga kerja dipakai ulang antar sel (tumbuh sesuai
/// wilayah terbesar); alokasi per sel hanya crop keluarannya. Jalankan di
/// isolate latar (`JalankanPindaiAsli` memanggilnya di isolate perataan).
///
/// Murni Dart, hanya `package:image` untuk membaca/membuat citra.
class PemotongSel {
  PemotongSel._(this._halaman, this._s);

  final HalamanTernormal _halaman;
  final SetelanPemotong _s;
  final _Kerja _kerja = _Kerja();

  /// Potong [kotak] dari [halaman]; hasil sejajar dengan [kotak].
  static List<HasilPotongSel> potongSemua(
    img.Image halaman,
    List<KotakPiksel> kotak, {
    SetelanPemotong setelan = const SetelanPemotong(),
  }) {
    if (kotak.isEmpty) return const [];

    final tinggi = kotak.map((k) => k.h).toList()..sort();
    final hMedian = tinggi[tinggi.length ~/ 2];
    final kernel =
        setelan.kernelLatarPx ?? (setelan.kernelLatar * hMedian).round();
    final pemotong = PemotongSel._(
      HalamanTernormal.dari(halaman, kernelLatarPx: kernel),
      setelan,
    );

    return [for (final k in kotak) pemotong.potong(k)];
  }

  /// Untuk alat paritas: pemotong dari halaman yang sudah disiapkan.
  static PemotongSel dari(
    HalamanTernormal halaman, {
    SetelanPemotong setelan = const SetelanPemotong(),
  }) => PemotongSel._(halaman, setelan);

  HalamanTernormal get halaman => _halaman;

  /// Ambang abu ternormalisasi: tinta bila `< 0,78 × 255` (rig `tinta`).
  static const _batasTinta = 198;

  /// Ambang untuk mendeteksi garis tabel: `< 0,80 × 255` (rig `garis_h_ketat`).
  static const _batasGaris = 203;

  HasilPotongSel potong(KotakPiksel kotak) {
    final s = _s;
    final w = _halaman.lebar;
    final hal = _halaman.tinggi;

    final xl = kotak.x.round();
    final yt = kotak.y.round();
    final xr = (kotak.x + kotak.w).round();
    final yb = (kotak.y + kotak.h).round();
    final h = yb - yt;
    if (h < 12 || xr - xl < 24) {
      return const HasilPotongSel(
        sebabTakYakin: SebabPemotongTakYakin.kotakTerlaluKecil,
      );
    }

    final e = (s.meluber * h).round();
    final marg =
        s.marginSampingPx ?? math.max(1, (s.marginSamping * h).round());
    final y0 = math.max(0, yt - e);
    final y1 = math.min(hal, yb + e);
    final x0 = math.max(0, xl + marg);
    final x1 = math.min(w, xr - marg);
    final rw = x1 - x0;
    final rh = y1 - y0;
    if (rw < 12 || rh < 12) {
      return const HasilPotongSel(
        sebabTakYakin: SebabPemotongTakYakin.kotakTerlaluKecil,
      );
    }

    final n = rw * rh;
    final k = _kerja..pastikan(n);
    final norm = k.norm;
    final tinta = k.tinta;
    final garis = k.garis;
    final lab = k.label;

    _halaman.isiNorm(x0, y0, x1, y1, norm);

    // ---- tinta & biner garis ---------------------------------------------------
    for (var i = 0; i < n; i++) {
      final v = norm[i];
      tinta[i] = v <= _batasTinta ? 1 : 0;
      k.biner[i] = v <= _batasGaris ? 1 : 0;
    }

    // ---- 3. garis tabel mendatar ----------------------------------------------
    final panjang =
        s.panjangGarisPx ?? math.max(8, (s.panjangGaris * h).round());
    _tandaiGarisPanjang(k, rw, rh, panjang);

    final tepiAtas = yt - y0;
    final tepiBawah = yb - y0;
    final tol = math.max(2, (s.tolGaris * h).round());
    final (:pita, :tebal) = _pilihGarisTabel(
      k,
      rw,
      rh,
      tepiAtas: tepiAtas,
      tepiBawah: tepiBawah,
      tol: tol,
      cakupanMin: (s.cakupanGarisMin * rw).ceil(),
    );

    // Piksel garis TERPILIH saja yang dihapus dari tinta; garis datar lain
    // (tulisan) tetap tinta.
    for (var i = 0; i < n; i++) {
      k.mask[i] = 0;
    }
    for (final p in pita) {
      for (var y = p.r0; y <= p.r1; y++) {
        for (var x = 0; x < rw; x++) {
          final i = y * rw + x;
          if (garis[i] == 1) {
            tinta[i] = 0;
            k.mask[i] = 1;
          }
        }
      }
    }

    // ---- 4. jembatan -----------------------------------------------------------
    for (var pi = 0; pi < pita.length; pi++) {
      _jembatani(k, rw, rh, pita[pi], tebal[pi]);
    }

    // ---- 5. komponen -----------------------------------------------------------
    // Latar belakang komponen: tinta ATAU piksel jembatan (mask == 2).
    final komp = _labeli(k, rw, rh);

    final areaMin =
        s.areaKomponenMinPx ?? math.max(3, (s.areaKomponenMin * h * h).round());
    final pusatAtas = tepiAtas - s.pitaBaris * h;
    final pusatBawah = tepiBawah + s.pitaBaris * h;

    final milik = <int>[];
    for (var c = 1; c <= komp.jumlah; c++) {
      final lebarK = komp.maxX[c] - komp.minX[c] + 1;
      final tinggiK = komp.maxY[c] - komp.minY[c] + 1;
      // Garis tegak tabel yang masuk jendela: tipis, tinggi, dan DEKAT TEPI
      // kiri/kanan. Goresan tegak di tengah sel (angka "1" yang tinggi) bukan
      // garis, walau sama tipisnya.
      final dekatSisi =
          komp.minX[c] <= s.dekatSisi * h ||
          komp.maxX[c] >= rw - 1 - s.dekatSisi * h;
      if (dekatSisi &&
          tinggiK >= s.garisTegakMin * h &&
          lebarK <= s.garisTegakLebarMaks * h) {
        continue;
      }
      final disisi = komp.minX[c] <= 0 || komp.maxX[c] >= rw - 1;
      if (disisi &&
          lebarK <= s.tepiTipisLebarMaks * h &&
          tinggiK >= s.tepiTipisTinggiMin * h) {
        continue; // serpihan garis tegak yang melewati margin
      }
      if (disisi && komp.area[c] < s.tepiAreaMin * h * h) continue;
      if (komp.area[c] < areaMin) continue;
      final pusatY = komp.jumlahY[c] / komp.area[c];
      if (pusatY >= pusatAtas && pusatY <= pusatBawah) milik.add(c);
    }

    if (milik.isEmpty) return const HasilPotongSel.kosong();

    var luas = 0;
    var minX = rw, maxX = -1, minY = rh, maxY = -1;
    for (final c in milik) {
      luas += komp.area[c];
      minX = math.min(minX, komp.minX[c]);
      maxX = math.max(maxX, komp.maxX[c]);
      minY = math.min(minY, komp.minY[c]);
      maxY = math.max(maxY, komp.maxY[c]);
    }
    if (luas < s.luasTotalMin * h * h) return const HasilPotongSel.kosong();

    // ---- ketidakyakinan --------------------------------------------------------
    SebabPemotongTakYakin? sebab;
    if (minY <= 0 || maxY >= rh - 1) {
      sebab = SebabPemotongTakYakin.tintaMelewatiJendelaVertikal;
    } else if (minX <= 0 || maxX >= rw - 1) {
      sebab = SebabPemotongTakYakin.tintaMenempelTepiSamping;
    }
    for (final c in milik) {
      final lebarK = komp.maxX[c] - komp.minX[c] + 1;
      final tinggiK = komp.maxY[c] - komp.minY[c] + 1;
      if (tinggiK > s.komponenTinggiMaks * h) {
        sebab ??= SebabPemotongTakYakin.komponenMelebihiBaris;
      }
      if (lebarK >= s.garisDatarLebarMin * h &&
          tinggiK <= s.garisDatarTinggiMaks * h &&
          lebarK >= s.garisDatarRasioMin * tinggiK) {
        sebab ??= SebabPemotongTakYakin.garisDatar;
      }
    }

    // ---- 7. kanvas ---------------------------------------------------------------
    final padX = (s.padX * h).round();
    final padY = (s.padY * h).round();
    final xa = math.max(0, minX - padX);
    final xb = math.min(rw, maxX + padX + 1);
    final ya = math.max(0, minY - padY);
    final yb2 = math.min(rh, maxY + padY + 1);
    final cw = xb - xa;
    final ch = yb2 - ya;

    final rgb = Uint8List(cw * ch * 3)..fillRange(0, cw * ch * 3, 255);
    final dipertahankan = Uint8List(komp.jumlah + 1);
    for (final c in milik) {
      dipertahankan[c] = 1;
    }

    bool tetanggaDipertahankan(int x, int y) {
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= rh) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= rw) continue;
          final l = lab[yy * rw + xx];
          if (l > 0 && dipertahankan[l] == 1) return true;
        }
      }

      return false;
    }

    for (var y = ya; y < yb2; y++) {
      for (var x = xa; x < xb; x++) {
        if (!tetanggaDipertahankan(x, y)) continue;
        final i = y * rw + x;
        var v = norm[i];
        final l = lab[i];
        // Piksel jembatan milik komponen yang dipertahankan: tinta pekat.
        if (l > 0 && dipertahankan[l] == 1 && k.mask[i] == 2 && v > 60) {
          v = 60;
        }
        final o = ((y - ya) * cw + (x - xa)) * 3;
        rgb[o] = v;
        rgb[o + 1] = v;
        rgb[o + 2] = v;
      }
    }

    final crop = img.Image.fromBytes(
      width: cw,
      height: ch,
      bytes: rgb.buffer,
      numChannels: 3,
    );

    return HasilPotongSel(
      crop: crop,
      sebabTakYakin: sebab,
      luasTinta: luas,
      kiri: x0 + xa,
      atas: y0 + ya,
    );
  }

  // ---------------------------------------------------------------------------
  // Garis mendatar

  /// Tandai di `garis` piksel yang berada pada deretan mendatar sepanjang
  /// ≥ [panjang] di `biner` yang ditebalkan 3×3 (rig: dilatasi 3×3 lalu
  /// pembukaan dengan kernel `(panjang, 1)`; deretan di tepi wilayah dihitung
  /// utuh karena garisnya berlanjut keluar jendela).
  static void _tandaiGarisPanjang(_Kerja k, int rw, int rh, int panjang) {
    final biner = k.biner;
    final melebar = k.melebar;
    final garis = k.garis;

    for (var y = 0; y < rh; y++) {
      for (var x = 0; x < rw; x++) {
        var ada = 0;
        for (var dy = -1; dy <= 1 && ada == 0; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= rh) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= rw) continue;
            if (biner[yy * rw + xx] == 1) {
              ada = 1;
              break;
            }
          }
        }
        melebar[y * rw + x] = ada;
      }
    }

    garis.fillRange(0, rw * rh, 0);
    for (var y = 0; y < rh; y++) {
      var x = 0;
      while (x < rw) {
        if (melebar[y * rw + x] == 0) {
          x++;
          continue;
        }
        var akhir = x;
        while (akhir < rw && melebar[y * rw + akhir] == 1) {
          akhir++;
        }
        if (akhir - x >= panjang) {
          for (var i = x; i < akhir; i++) {
            garis[y * rw + i] = 1;
          }
        }
        x = akhir;
      }
    }
  }

  /// Pita (baris berurutan yang memuat piksel garis) yang menjadi GARIS TABEL:
  /// di tiap sisi (atas, bawah) pita terluar yang pusatnya dalam [tol] dari tepi
  /// kotak dan membentang ≥ [cakupanMin] kolom. Mengembalikan pita beserta
  /// ketebalannya (persentil 90 jumlah piksel garis per kolom).
  static ({List<_Pita> pita, List<int> tebal}) _pilihGarisTabel(
    _Kerja k,
    int rw,
    int rh, {
    required int tepiAtas,
    required int tepiBawah,
    required int tol,
    required int cakupanMin,
  }) {
    final garis = k.garis;
    final semua = <_Pita>[];

    var y = 0;
    while (y < rh) {
      var ada = false;
      for (var x = 0; x < rw && !ada; x++) {
        ada = garis[y * rw + x] == 1;
      }
      if (!ada) {
        y++;
        continue;
      }
      var akhir = y;
      while (akhir + 1 < rh) {
        var lanjut = false;
        for (var x = 0; x < rw && !lanjut; x++) {
          lanjut = garis[(akhir + 1) * rw + x] == 1;
        }
        if (!lanjut) break;
        akhir++;
      }

      var cakupan = 0;
      for (var x = 0; x < rw; x++) {
        for (var r = y; r <= akhir; r++) {
          if (garis[r * rw + x] == 1) {
            cakupan++;
            break;
          }
        }
      }
      semua.add(_Pita(y, akhir, cakupan));
      y = akhir + 1;
    }

    _Pita? atas;
    _Pita? bawah;
    for (final p in semua) {
      if (p.cakupan < cakupanMin) continue;
      final pusat = (p.r0 + p.r1) / 2;
      if ((pusat - tepiAtas).abs() <= tol &&
          (atas == null || pusat < atas.pusat)) {
        atas = p;
      }
      if ((pusat - tepiBawah).abs() <= tol &&
          (bawah == null || pusat > bawah.pusat)) {
        bawah = p;
      }
    }

    final pita = <_Pita>[?atas, ?bawah];
    final tebal = <int>[];
    for (final p in pita) {
      final kolom = <int>[];
      for (var x = 0; x < rw; x++) {
        var c = 0;
        for (var r = p.r0; r <= p.r1; r++) {
          if (garis[r * rw + x] == 1) c++;
        }
        if (c > 0) kolom.add(c);
      }
      kolom.sort();
      tebal.add(kolom.isEmpty ? 0 : kolom[((kolom.length - 1) * 0.9).floor()]);
    }

    return (pita: pita, tebal: tebal);
  }

  /// Jembatani goresan yang melintas satu pita garis: di tiap kolom, bila ada
  /// tinta (bukan garis) di atas DAN di bawah pita dan seluruh deretan nol di
  /// antaranya ≤ `2 × tebal + 3` (rig: penutupan menegak `(1, tebal + 4)`),
  /// piksel garis kolom itu menjadi tinta jembatan (`mask = 2`).
  static void _jembatani(_Kerja k, int rw, int rh, _Pita p, int tebal) {
    final tinta = k.tinta;
    final mask = k.mask;
    final celahMaks = 2 * tebal + 3;

    for (var x = 0; x < rw; x++) {
      var atas = -1;
      var bawah = -1;
      for (var r = p.r0; r <= p.r1; r++) {
        if (mask[r * rw + x] == 1) {
          if (atas < 0) atas = r;
          bawah = r;
        }
      }
      if (atas < 0) continue;

      final tebalKolom = bawah - atas + 1;
      final sisa = celahMaks - tebalKolom;
      if (sisa < 0) continue;

      // Cari tinta di atas pita (jarak nol ≤ sisa) dan di bawahnya.
      var nolAtas = 0;
      var y = atas - 1;
      while (y >= 0 && tinta[y * rw + x] == 0 && nolAtas <= sisa) {
        nolAtas++;
        y--;
      }
      if (y < 0 || tinta[y * rw + x] == 0) continue;

      var nolBawah = 0;
      y = bawah + 1;
      while (y < rh && tinta[y * rw + x] == 0 && nolBawah <= sisa) {
        nolBawah++;
        y++;
      }
      if (y >= rh || tinta[y * rw + x] == 0) continue;

      if (nolAtas + nolBawah <= sisa) {
        for (var r = atas; r <= bawah; r++) {
          if (mask[r * rw + x] == 1) mask[r * rw + x] = 2;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Komponen terhubung

  /// Beri label komponen (8 tetangga) pada tinta ∪ jembatan. Hasil label di
  /// `k.label` (0 = latar).
  static _Komponen _labeli(_Kerja k, int rw, int rh) {
    final tinta = k.tinta;
    final mask = k.mask;
    final lab = k.label;
    final tumpukan = k.tumpukan;
    final n = rw * rh;
    lab.fillRange(0, n, 0);

    final komp = _Komponen();
    for (var awal = 0; awal < n; awal++) {
      if (lab[awal] != 0 || (tinta[awal] == 0 && mask[awal] != 2)) continue;

      final id = komp.baru();
      var atas = 0;
      tumpukan[atas++] = awal;
      lab[awal] = id;

      while (atas > 0) {
        final p = tumpukan[--atas];
        final y = p ~/ rw;
        final x = p - y * rw;
        komp.tambah(id, x, y);

        for (var dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= rh) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= rw || (dx == 0 && dy == 0)) continue;
            final q = yy * rw + xx;
            if (lab[q] != 0 || (tinta[q] == 0 && mask[q] != 2)) continue;
            lab[q] = id;
            tumpukan[atas++] = q;
          }
        }
      }
    }

    return komp;
  }
}

class _Pita {
  const _Pita(this.r0, this.r1, this.cakupan);

  final int r0;
  final int r1;
  final int cakupan;

  double get pusat => (r0 + r1) / 2;
}

/// Statistik komponen terhubung (indeks mulai dari 1).
class _Komponen {
  int jumlah = 0;
  final area = <int>[0];
  final jumlahY = <int>[0];
  final minX = <int>[0];
  final maxX = <int>[0];
  final minY = <int>[0];
  final maxY = <int>[0];

  int baru() {
    jumlah++;
    area.add(0);
    jumlahY.add(0);
    minX.add(1 << 30);
    maxX.add(-1);
    minY.add(1 << 30);
    maxY.add(-1);

    return jumlah;
  }

  void tambah(int id, int x, int y) {
    area[id]++;
    jumlahY[id] += y;
    if (x < minX[id]) minX[id] = x;
    if (x > maxX[id]) maxX[id] = x;
    if (y < minY[id]) minY[id] = y;
    if (y > maxY[id]) maxY[id] = y;
  }
}

/// Penyangga kerja yang dipakai ulang antar sel.
class _Kerja {
  Uint8List norm = Uint8List(0);
  Uint8List tinta = Uint8List(0);
  Uint8List biner = Uint8List(0);
  Uint8List melebar = Uint8List(0);
  Uint8List garis = Uint8List(0);
  Uint8List mask = Uint8List(0);
  Int32List label = Int32List(0);
  Int32List tumpukan = Int32List(0);

  void pastikan(int n) {
    if (norm.length >= n) return;
    // Tumbuh 1,5× supaya wilayah yang sedikit lebih besar tidak mengalokasi ulang.
    final kapasitas = n + n ~/ 2;
    norm = Uint8List(kapasitas);
    tinta = Uint8List(kapasitas);
    biner = Uint8List(kapasitas);
    melebar = Uint8List(kapasitas);
    garis = Uint8List(kapasitas);
    mask = Uint8List(kapasitas);
    label = Int32List(kapasitas);
    tumpukan = Int32List(kapasitas);
  }
}
