import 'dart:math' as math;
import 'dart:ui';

/// Mesin 3D mini — cukup buat render alat kalibrasi low-poly di atas Canvas
/// Flutter, tanpa WebView, tanpa JavaScript, tanpa paket eksternal.
///
/// ## Kenapa bukan three.js / WebGL beneran
///
/// three.js itu pustaka JavaScript; di Flutter dia cuma bisa jalan lewat
/// WebView (Android/iOS) atau kanvas HTML (web). Dua-duanya berarti nempelin
/// mesin render kedua di dalam app: puluhan MB, satu isolate JS, dan frame
/// yang nggak pernah sinkron sama frame Flutter. Buat satu objek hiasan di
/// dashboard, ongkosnya nggak sepadan.
///
/// Yang dipakai di sini jalur pendeknya: proyeksi perspektif + urutan gambar
/// dari belakang ke depan (painter's algorithm) + pencahayaan Lambert, semua
/// dihitung di Dart lalu digambar sebagai path. `Canvas` Flutter sendiri udah
/// jalan di GPU (Impeller), jadi hasilnya tetap dirasterisasi hardware —
/// yang dikerjakan CPU cuma transform beberapa ratus titik per frame.
///
/// Batas wajarnya: **ratusan segi, bukan ribuan**. Kalau suatu saat butuh
/// model beneran (mesh ribuan segitiga, tekstur, bayangan), ini bukan
/// tempatnya — pindah ke `flutter_scene`/`flutter_gpu`.

/// Titik sekaligus vektor 3D. Immutable biar mesh bisa dibikin `const`-ish dan
/// dipakai ulang antar-frame tanpa takut ada yang ngubah diam-diam.
class Vek3 {
  const Vek3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vek3 nol = Vek3(0, 0, 0);

  Vek3 operator +(Vek3 o) => Vek3(x + o.x, y + o.y, z + o.z);
  Vek3 operator -(Vek3 o) => Vek3(x - o.x, y - o.y, z - o.z);
  Vek3 operator *(double s) => Vek3(x * s, y * s, z * s);

  double dot(Vek3 o) => x * o.x + y * o.y + z * o.z;

  Vek3 cross(Vek3 o) =>
      Vek3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get panjang => math.sqrt(x * x + y * y + z * z);

  /// Vektor satuan. Vektor nol dibalikin apa adanya — dinormalisasi bakal
  /// jadi NaN dan NaN yang nyasar ke `Path` bikin seluruh frame ilang, bukan
  /// cuma satu segi.
  Vek3 get satuan {
    final p = panjang;
    return p == 0 ? this : Vek3(x / p, y / p, z / p);
  }

  /// Putar terhadap sumbu Y (yaw) — ini yang bikin objek muter kayak di
  /// turntable.
  Vek3 putarY(double sudut) {
    final c = math.cos(sudut);
    final s = math.sin(sudut);
    return Vek3(x * c + z * s, y, -x * s + z * c);
  }

  /// Putar terhadap sumbu X (pitch) — dipakai buat miringin kamera ke bawah
  /// biar objeknya kelihatan dari agak atas.
  Vek3 putarX(double sudut) {
    final c = math.cos(sudut);
    final s = math.sin(sudut);
    return Vek3(x, y * c - z * s, y * s + z * c);
  }

  /// Putar terhadap sumbu Z (roll).
  Vek3 putarZ(double sudut) {
    final c = math.cos(sudut);
    final s = math.sin(sudut);
    return Vek3(x * c - y * s, x * s + y * c, z);
  }

  @override
  String toString() =>
      'Vek3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, '
      '${z.toStringAsFixed(3)})';
}

/// Satu bidang datar (poligon) di permukaan mesh.
///
/// Indeksnya nunjuk ke daftar titik milik [Mesh3D]. Urutannya WAJIB berlawanan
/// arah jarum jam kalau dilihat dari luar objek — normal dihitung dari urutan
/// itu, dan normal yang kebalik bikin bidangnya gelap terus plus lolos dari
/// pembuangan sisi belakang.
class Segi3 {
  const Segi3(
    this.indeks, {
    required this.warna,
    this.kilap = 0.0,
    this.tembusPandang = 1.0,
  });

  final List<int> indeks;

  /// Warna dasar bahan, sebelum kena cahaya.
  final Color warna;

  /// Seberapa "logam/kaca" bidangnya: 0 = matte (cat), 1 = pantulan tajam.
  /// Cuma ngatur seberapa kuat kilau tepi & sorot cahayanya.
  final double kilap;

  /// 1 = pejal. Di bawah itu dipakai buat kaca (gelas beaker) — dan bidang
  /// tembus pandang SELALU digambar belakangan supaya yang di baliknya
  /// kelihatan.
  final double tembusPandang;
}

/// Kumpulan titik + segi. Satu alat kalibrasi = satu mesh hasil gabungan
/// beberapa bentuk dasar.
class Mesh3D {
  const Mesh3D(this.titik, this.segi);

  final List<Vek3> titik;
  final List<Segi3> segi;

  static const Mesh3D kosong = Mesh3D(<Vek3>[], <Segi3>[]);

  int get jumlahSegi => segi.length;

  /// Sambung beberapa mesh jadi satu, sambil geser indeks seginya.
  ///
  /// Ini yang bikin alat dirakit dari bentuk dasar: badan + tuas + jarum
  /// digabung sekali di awal, terus per frame yang dikerjakan tinggal
  /// transform titik — bukan bikin ulang geometrinya.
  static Mesh3D gabung(List<Mesh3D> bagian) {
    final titik = <Vek3>[];
    final segi = <Segi3>[];
    for (final m in bagian) {
      final geser = titik.length;
      titik.addAll(m.titik);
      for (final s in m.segi) {
        segi.add(
          Segi3(
            [for (final i in s.indeks) i + geser],
            warna: s.warna,
            kilap: s.kilap,
            tembusPandang: s.tembusPandang,
          ),
        );
      }
    }
    return Mesh3D(titik, segi);
  }

  /// Geser seluruh mesh. Dipakai waktu ngerakit, bukan per frame.
  Mesh3D geser(Vek3 delta) => Mesh3D([for (final t in titik) t + delta], segi);

  Mesh3D skala(double s) => Mesh3D([for (final t in titik) t * s], segi);

  Mesh3D putarX(double sudut) =>
      Mesh3D([for (final t in titik) t.putarX(sudut)], segi);

  Mesh3D putarY(double sudut) =>
      Mesh3D([for (final t in titik) t.putarY(sudut)], segi);

  Mesh3D putarZ(double sudut) =>
      Mesh3D([for (final t in titik) t.putarZ(sudut)], segi);

  /// Balok sejajar sumbu, dari [min] ke [maks].
  static Mesh3D balok(
    Vek3 min,
    Vek3 maks, {
    required Color warna,
    double kilap = 0.25,
    Color? warnaAtas,
  }) {
    final t = <Vek3>[
      Vek3(min.x, min.y, maks.z), // 0 depan-kiri-bawah
      Vek3(maks.x, min.y, maks.z), // 1 depan-kanan-bawah
      Vek3(maks.x, maks.y, maks.z), // 2 depan-kanan-atas
      Vek3(min.x, maks.y, maks.z), // 3 depan-kiri-atas
      Vek3(min.x, min.y, min.z), // 4 belakang-kiri-bawah
      Vek3(maks.x, min.y, min.z), // 5
      Vek3(maks.x, maks.y, min.z), // 6
      Vek3(min.x, maks.y, min.z), // 7
    ];
    return Mesh3D(t, [
      Segi3(const [0, 1, 2, 3], warna: warna, kilap: kilap), // depan
      Segi3(const [5, 4, 7, 6], warna: warna, kilap: kilap), // belakang
      Segi3(const [4, 0, 3, 7], warna: warna, kilap: kilap), // kiri
      Segi3(const [1, 5, 6, 2], warna: warna, kilap: kilap), // kanan
      Segi3(
        const [3, 2, 6, 7],
        warna: warnaAtas ?? warna,
        kilap: kilap,
      ), // atas
      Segi3(const [4, 5, 1, 0], warna: warna, kilap: kilap), // bawah
    ]);
  }

  /// Tabung / kerucut terpotong berdiri di sumbu Y.
  ///
  /// [sisi] = jumlah sisi keliling. 12–16 udah kelihatan bulat di ukuran
  /// layar HP; di atas itu cuma nambah segi yang nggak kebedain.
  static Mesh3D tabung({
    required double jariBawah,
    required double jariAtas,
    required double yBawah,
    required double yAtas,
    int sisi = 14,
    required Color warna,
    Color? warnaTutup,
    double kilap = 0.4,
    double tembusPandang = 1.0,
    bool tutupAtas = true,
    bool tutupBawah = true,
  }) {
    final titik = <Vek3>[];
    for (var i = 0; i < sisi; i++) {
      final a = i / sisi * math.pi * 2;
      titik.add(Vek3(math.cos(a) * jariBawah, yBawah, math.sin(a) * jariBawah));
    }
    for (var i = 0; i < sisi; i++) {
      final a = i / sisi * math.pi * 2;
      titik.add(Vek3(math.cos(a) * jariAtas, yAtas, math.sin(a) * jariAtas));
    }

    final segi = <Segi3>[];
    for (var i = 0; i < sisi; i++) {
      final j = (i + 1) % sisi;
      segi.add(
        Segi3(
          // Urutannya [bawah-i, atas-i, atas-j, bawah-j] — berlawanan arah
          // jarum jam DILIHAT DARI LUAR tabung. Kebalik dikit aja, normalnya
          // nunjuk ke dalam: bidangnya gelap terus dan yang kelihatan malah
          // rongga dalamnya.
          [i, sisi + i, sisi + j, j],
          warna: warna,
          kilap: kilap,
          tembusPandang: tembusPandang,
        ),
      );
    }
    if (tutupAtas) {
      segi.add(
        Segi3(
          [for (var i = sisi - 1; i >= 0; i--) sisi + i],
          warna: warnaTutup ?? warna,
          kilap: kilap,
          tembusPandang: tembusPandang,
        ),
      );
    }
    if (tutupBawah) {
      segi.add(
        Segi3(
          [for (var i = 0; i < sisi; i++) i],
          warna: warnaTutup ?? warna,
          kilap: kilap,
          tembusPandang: tembusPandang,
        ),
      );
    }
    return Mesh3D(titik, segi);
  }

  /// Bidang datar (buat lantai/kertas). Normalnya menghadap +Y.
  static Mesh3D bidang({
    required double lebar,
    required double dalam,
    double y = 0,
    required Color warna,
    double kilap = 0.1,
    double tembusPandang = 1.0,
  }) {
    final hx = lebar / 2;
    final hz = dalam / 2;
    return Mesh3D(
      [Vek3(-hx, y, hz), Vek3(hx, y, hz), Vek3(hx, y, -hz), Vek3(-hx, y, -hz)],
      [
        Segi3(
          const [0, 1, 2, 3],
          warna: warna,
          kilap: kilap,
          tembusPandang: tembusPandang,
        ),
      ],
    );
  }
}
