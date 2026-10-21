part of 'grid_sel.dart';

/// Ukuran (sudah dikali zoom), gabungan, dan navigasi satu lembar — dihitung
/// sekali per tata letak/zoom/ukuran layar, bukan per sel.
///
/// Dua rentang: [barisData]×[kolomData] = rentang TERPAKAI (yang ditanyakan
/// ke sumber sel), [jumlahBaris]×[jumlahKolom] = yang digambar (terpakai +
/// sel kosong sampai layar penuh).
class _Geometri {
  _Geometri({
    required this.tataLetak,
    required this.zoom,
    required this.barisData,
    required this.kolomData,
    required this.jumlahBaris,
    required this.jumlahKolom,
    required this.barisBeku,
    required this.kolomBeku,
  }) : lebarKepalaBaris = lebarKepalaBarisUntuk(jumlahBaris, zoom),
       tinggiKepala = tinggiKepalaUntuk(zoom) {
    _lebar = Float64List(jumlahKolom + 2);
    _x = Float64List(jumlahKolom + 2);
    for (var k = 1; k <= jumlahKolom; k++) {
      _lebar[k] = skala(tataLetak.lebar(k), zoom);
      _x[k + 1] = _x[k] + _lebar[k];
    }
    _tinggi = Float64List(jumlahBaris + 2);
    _y = Float64List(jumlahBaris + 2);
    for (var b = 1; b <= jumlahBaris; b++) {
      _tinggi[b] = skala(tataLetak.tinggi(b), zoom);
      _y[b + 1] = _y[b] + _tinggi[b];
    }
    tinggiTerkunci = tinggiKepala + _y[barisBeku + 1];
    lebarTerkunci = lebarKepalaBaris + _x[kolomBeku + 1];
    _susunGabungan();
  }

  /// Ukuran Excel pada zoom 100 % → dp pada [zoom], dibulatkan ke piksel
  /// utuh supaya garis kisi tetap tajam. 0 (tersembunyi) tetap 0.
  static double skala(double nilai, double zoom) {
    if (nilai <= 0) return 0;
    if (zoom == 1) return nilai;
    return math.max(1, (nilai * zoom).roundToDouble());
  }

  /// Tinggi kepala kolom: setinggi baris bawaan Excel, ikut zoom.
  static double tinggiKepalaUntuk(double zoom) =>
      math.max(12, (20 * zoom).roundToDouble());

  static double lebarKepalaBarisUntuk(int jumlahBaris, double zoom) => math.max(
    24,
    (math.max(32.0, '$jumlahBaris'.length * 7.5 + 12) * zoom).roundToDouble(),
  );

  final TataLetakGrid tataLetak;
  final double zoom;
  final int barisData;
  final int kolomData;
  final int jumlahBaris;
  final int jumlahKolom;
  final int barisBeku;
  final int kolomBeku;
  final double lebarKepalaBaris;
  final double tinggiKepala;
  late final double tinggiTerkunci;
  late final double lebarTerkunci;
  late final Float64List _lebar;
  late final Float64List _tinggi;

  /// Tepi kiri kolom k / tepi atas baris b dari kolom 1 / baris 1 (tanpa
  /// kepala, tanpa gulir). `_x[k+1] - _x[k]` = lebar kolom k.
  late final Float64List _x;
  late final Float64List _y;

  final _penuh = <int, RentangSel>{};
  final _tampil = <int, RentangSel>{};
  final daftarGabungan = <RentangSel>[];

  double lebar(int kolom) =>
      kolom >= 1 && kolom <= jumlahKolom ? _lebar[kolom] : 0;

  double tinggi(int baris) =>
      baris >= 1 && baris <= jumlahBaris ? _tinggi[baris] : 0;

  /// Tepi kiri kolom [kolom] dari tepi kiri kolom 1.
  double xKolom(int kolom) => _x[kolom.clamp(1, jumlahKolom + 1)];

  /// Tepi atas baris [baris] dari tepi atas baris 1.
  double yBaris(int baris) => _y[baris.clamp(1, jumlahBaris + 1)];

  /// Lebar kolom [awal]..[akhir] (0 bila [akhir] < [awal]).
  double lebarRentang(int awal, int akhir) =>
      akhir < awal ? 0 : xKolom(akhir + 1) - xKolom(awal);

  /// Tinggi baris [awal]..[akhir] (0 bila [akhir] < [awal]).
  double tinggiRentang(int awal, int akhir) => akhir < awal
      ? 0
      : _y[(akhir + 1).clamp(1, jumlahBaris + 1)] -
            _y[awal.clamp(1, jumlahBaris + 1)];

  bool diLuarData(int baris, int kolom) =>
      baris > barisData || kolom > kolomData;

  void _susunGabungan() {
    for (final g0 in tataLetak.gabungan) {
      // Dijepit ke dimensi tampil: TableView menolak gabungan di luar
      // jumlah baris/kolom.
      if (g0.barisAwal > jumlahBaris || g0.kolomAwal > jumlahKolom) continue;
      final g = RentangSel(
        g0.barisAwal,
        g0.kolomAwal,
        math.min(g0.barisAkhir, jumlahBaris),
        math.min(g0.kolomAkhir, jumlahKolom),
      );
      if (g.tunggal) continue;
      // Gabungan bertumpuk (tidak sah di Excel): yang belakangan diabaikan.
      if (daftarGabungan.any(g.beririsan)) continue;
      daftarGabungan.add(g);

      // TableView tidak mengizinkan sel gabungan melintasi batas terkunci;
      // dipecah di batas freeze, isinya tetap di bagian yang memuat sel
      // kiri-atas.
      final potongBaris = [
        if (g.barisAwal <= barisBeku && g.barisAkhir > barisBeku) ...[
          (g.barisAwal, barisBeku),
          (barisBeku + 1, g.barisAkhir),
        ] else
          (g.barisAwal, g.barisAkhir),
      ];
      final potongKolom = [
        if (g.kolomAwal <= kolomBeku && g.kolomAkhir > kolomBeku) ...[
          (g.kolomAwal, kolomBeku),
          (kolomBeku + 1, g.kolomAkhir),
        ] else
          (g.kolomAwal, g.kolomAkhir),
      ];
      for (final (b1, b2) in potongBaris) {
        for (final (k1, k2) in potongKolom) {
          final bagian = RentangSel(b1, k1, b2, k2);
          for (var b = b1; b <= b2; b++) {
            for (var k = k1; k <= k2; k++) {
              _penuh[kunciSel(b, k)] = g;
              _tampil[kunciSel(b, k)] = bagian;
            }
          }
        }
      }
    }
  }

  RentangSel? gabunganPenuh(AlamatSel a) => _penuh[kunciSel(a.baris, a.kolom)];

  bool digabung(int baris, int kolom) =>
      _penuh.containsKey(kunciSel(baris, kolom));

  RentangSel? gabunganTampil(int baris, int kolom) =>
      _tampil[kunciSel(baris, kolom)];

  /// Sel di dalam gabungan diwakili sel kiri-atasnya.
  AlamatSel jangkar(AlamatSel a) {
    final g = gabunganPenuh(a);
    return g == null ? a : g.awal;
  }

  AlamatSel jepit(AlamatSel a) => AlamatSel(
    a.baris.clamp(1, math.max(1, jumlahBaris)),
    a.kolom.clamp(1, math.max(1, jumlahKolom)),
  );

  /// Perluas rentang sampai setiap gabungan yang tersentuh termuat utuh.
  RentangSel perluasGabungan(RentangSel r) {
    var hasil = r;
    var berubah = true;
    while (berubah) {
      berubah = false;
      for (final g in daftarGabungan) {
        if (hasil.beririsan(g)) {
          final baru = hasil.gabung(g);
          if (baru != hasil) {
            hasil = baru;
            berubah = true;
          }
        }
      }
    }
    return hasil;
  }

  /// Offset gulir baris/kolom tak-terkunci: TableView mengukur dari 0 di
  /// baris/kolom tak-terkunci pertama.
  double offsetBaris(int baris) {
    if (baris <= barisBeku) return 0;
    return _y[baris.clamp(1, jumlahBaris + 1)] - _y[barisBeku + 1];
  }

  double offsetKolom(int kolom) {
    if (kolom <= kolomBeku) return 0;
    return _x[kolom.clamp(1, jumlahKolom + 1)] - _x[kolomBeku + 1];
  }

  bool _barisSembunyi(int b) => tinggi(b) <= 0;
  bool _kolomSembunyi(int k) => lebar(k) <= 0;

  int barisTampilPertama() {
    for (var b = 1; b <= jumlahBaris; b++) {
      if (!_barisSembunyi(b)) return b;
    }
    return 1;
  }

  int kolomTampilPertama() {
    for (var k = 1; k <= jumlahKolom; k++) {
      if (!_kolomSembunyi(k)) return k;
    }
    return 1;
  }

  /// Baris/kolom tampil terakhir di rentang TERPAKAI (Ctrl+End, Ctrl+↓/→);
  /// lembar tanpa data = tepi area yang digambar.
  int barisDataTerakhir() {
    final batas = barisData >= 1 ? barisData : jumlahBaris;
    for (var b = batas; b >= 1; b--) {
      if (!_barisSembunyi(b)) return b;
    }
    return math.max(1, batas);
  }

  int kolomDataTerakhir() {
    final batas = kolomData >= 1 ? kolomData : jumlahKolom;
    for (var k = batas; k >= 1; k--) {
      if (!_kolomSembunyi(k)) return k;
    }
    return math.max(1, batas);
  }

  /// Satu langkah dari [a]: keluar dari gabungannya dulu, lewati baris/kolom
  /// tersembunyi, berhenti di tepi area yang digambar.
  AlamatSel langkah(AlamatSel a, int db, int dk) {
    final g = gabunganPenuh(a) ?? RentangSel.tunggal(a);
    var b = a.baris;
    var k = a.kolom;
    if (db > 0) b = g.barisAkhir + 1;
    if (db < 0) b = g.barisAwal - 1;
    if (dk > 0) k = g.kolomAkhir + 1;
    if (dk < 0) k = g.kolomAwal - 1;
    while (db != 0 && b >= 1 && b <= jumlahBaris && _barisSembunyi(b)) {
      b += db;
    }
    while (dk != 0 && k >= 1 && k <= jumlahKolom && _kolomSembunyi(k)) {
      k += dk;
    }
    if (b < 1 || b > jumlahBaris || k < 1 || k > jumlahKolom) return a;
    return jangkar(AlamatSel(b, k));
  }

  /// Ctrl+panah: ke tepi rentang TERPAKAI (baris/kolom tampil pertama /
  /// terakhir).
  ///
  /// Beda dari Excel, yang berhenti di tepi BLOK data: grid tidak memegang
  /// seluruh isi (dimuat per halaman), jadi tepi blok tidak bisa diketahui
  /// tanpa memuat semuanya.
  AlamatSel tepi(AlamatSel a, int db, int dk) => AlamatSel(
    db > 0 ? barisDataTerakhir() : (db < 0 ? barisTampilPertama() : a.baris),
    dk > 0 ? kolomDataTerakhir() : (dk < 0 ? kolomTampilPertama() : a.kolom),
  );

  /// PgUp/PgDn: sejauh baris yang muat di [ruang] (tinggi area gulir).
  AlamatSel halaman(AlamatSel a, int arah, double ruang) {
    var b = a.baris;
    var terpakai = 0.0;
    var langkahan = 0;
    while (true) {
      final berikut = b + arah;
      if (berikut < 1 || berikut > jumlahBaris) break;
      final t = tinggi(berikut);
      if (langkahan > 0 && terpakai + t > ruang) break;
      terpakai += t;
      b = berikut;
      if (t > 0) langkahan++;
    }
    while (b >= 1 && b <= jumlahBaris && _barisSembunyi(b)) {
      b -= arah;
    }
    if (b < 1 || b > jumlahBaris) return a;
    return jangkar(AlamatSel(b, a.kolom));
  }
}
