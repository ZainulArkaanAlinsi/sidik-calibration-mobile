import 'dart:math' as math;
import 'dart:ui';

import 'mesh3d.dart';

/// Kamera turntable: selalu ngeliat ke titik asal, posisinya ditentukan
/// [jarak] + [yaw] + [pitch]. Nggak ada kamera bebas — buat panel hiasan,
/// orbit sekitar objek udah semua yang dibutuhin, dan modelnya jauh lebih
/// gampang dibaca daripada matriks view umum.
class Kamera3D {
  const Kamera3D({
    this.jarak = 6.2,
    this.yaw = 0.0,
    this.pitch = 0.34,
    this.fov = 0.92,
    this.geser = Offset.zero,
    this.zoom = 1.0,
  });

  /// Jarak kamera ke titik asal, dalam satuan dunia.
  final double jarak;

  /// Putaran mendatar (radian). Ini yang bikin objek kelihatan muter.
  final double yaw;

  /// Kemiringan ke bawah (radian). Positif = ngeliat dari atas.
  final double pitch;

  /// Bukaan lensa vertikal (radian).
  final double fov;

  /// Geser hasil proyeksi dalam pecahan sisi terpendek — buat naruh objek
  /// nggak persis di tengah panel tanpa mindahin objeknya di dunia (mindahin
  /// objek bikin perspektifnya ikut miring).
  final Offset geser;

  final double zoom;

  Kamera3D salin({double? yaw, double? pitch, double? jarak, double? zoom}) =>
      Kamera3D(
        jarak: jarak ?? this.jarak,
        yaw: yaw ?? this.yaw,
        pitch: pitch ?? this.pitch,
        fov: fov,
        geser: geser,
        zoom: zoom ?? this.zoom,
      );
}

/// Satu sumber cahaya arah + ambient. Sengaja cuma satu: dua sumber cahaya di
/// objek low-poly bikin bidangnya keliatan datar, bukan lebih hidup.
class Cahaya3D {
  const Cahaya3D({
    this.arah = const Vek3(-0.45, 0.82, 0.62),
    this.ambient = 0.42,
    this.warnaTepi = const Color(0xFF5CC8FF),
    this.kuatTepi = 0.55,
  });

  final Vek3 arah;

  /// Terang minimum bidang yang membelakangi cahaya. Di bawah ~0.3 sisi
  /// gelapnya jadi hitam pekat dan siluetnya ilang di latar gelap.
  final double ambient;

  /// Warna kilau tepi ("rim light") — yang bikin objek kebaca kayak
  /// dilapis kaca, bukan blok warna datar.
  final Color warnaTepi;

  final double kuatTepi;
}

/// Satu benda di adegan: mesh + transformasinya.
///
/// Transform disimpan sebagai angka, bukan matriks, karena yang dianimasikan
/// per frame cuma [putarY] — nyusun matriks penuh tiap frame buat itu doang
/// cuma nambah kerja.
class Objek3D {
  const Objek3D({
    required this.mesh,
    this.posisi = Vek3.nol,
    this.putarX = 0.0,
    this.putarY = 0.0,
    this.putarZ = 0.0,
    this.skala = 1.0,
    this.bayangan = 0.0,
    this.opasitas = 1.0,
  });

  final Mesh3D mesh;
  final Vek3 posisi;
  final double putarX;
  final double putarY;
  final double putarZ;
  final double skala;

  /// Lebar bayangan kontak di lantai (satuan dunia). 0 = nggak digambar.
  /// Bayangan ini yang bikin benda "napak", bukan ngambang.
  final double bayangan;

  /// Peredup seluruh objek — dipakai buat munculin/ngilangin benda pas
  /// transisi, tanpa ngutak-ngatik warna tiap seginya.
  final double opasitas;
}

/// Adegan siap gambar.
class Adegan3D {
  const Adegan3D({
    required this.objek,
    this.kamera = const Kamera3D(),
    this.cahaya = const Cahaya3D(),
    this.garisTepi = 0.0,
  });

  final List<Objek3D> objek;
  final Kamera3D kamera;
  final Cahaya3D cahaya;

  /// Ketebalan garis tepi tiap bidang (0 = mati). Nggak ada di render 3D
  /// modern, tapi ini yang ngasih rasa "panel instrumen"/cetak biru retro.
  final double garisTepi;

  int get jumlahSegi {
    var n = 0;
    for (final o in objek) {
      n += o.mesh.jumlahSegi;
    }
    return n;
  }
}

class _SegiSiap {
  _SegiSiap(this.path, this.warna, this.kedalaman);

  final Path path;
  final Color warna;
  final double kedalaman;
}

/// Gambar [adegan] memenuhi [size].
///
/// Urutannya: transform titik sekali per objek → buang bidang yang
/// membelakangi kamera → proyeksi perspektif → urutkan dari yang paling jauh →
/// gambar. Ini painter's algorithm: nggak ada z-buffer, jadi bentuk yang
/// saling tembus bakal salah urut. Buat benda pejal yang kepisah, hasilnya
/// nggak kebedain — dan ongkosnya seperseratus dari z-buffer di CPU.
void gambarAdegan(Canvas canvas, Size size, Adegan3D adegan) {
  if (size.isEmpty) return;

  final kamera = adegan.kamera;
  final cahaya = adegan.cahaya;
  final arahCahaya = cahaya.arah.satuan;

  // Skala layar dari sisi terpendek: panel bisa lebar atau tinggi, tapi
  // objeknya harus segede itu-itu aja.
  final f = 1 / math.tan(kamera.fov / 2);
  final skalaLayar = size.shortestSide / 2 * kamera.zoom;
  final pusat = Offset(
    size.width / 2 + kamera.geser.dx * size.shortestSide,
    size.height / 2 + kamera.geser.dy * size.shortestSide,
  );

  // Titik di ruang kamera dihitung dengan muter DUNIA-nya berlawanan arah
  // kamera, lalu mundurin sejauh `jarak`. Hasilnya sama dengan matriks view,
  // tapi tanpa nyusun matriks.
  Vek3 keRuangKamera(Vek3 p) =>
      p.putarY(-kamera.yaw).putarX(kamera.pitch) - Vek3(0, 0, kamera.jarak);

  Offset? proyeksi(Vek3 pKamera) {
    // Bidang dekat. Titik di belakang kamera diproyeksi jadi bayangan cermin
    // di seberang layar kalau dibiarin — seginya dibuang aja.
    final z = -pKamera.z;
    if (z < 0.12) return null;
    return Offset(
      pusat.dx + f * pKamera.x / z * skalaLayar,
      pusat.dy - f * pKamera.y / z * skalaLayar,
    );
  }

  final siap = <_SegiSiap>[];

  for (final objek in adegan.objek) {
    if (objek.opasitas <= 0.004) continue;
    final mesh = objek.mesh;
    if (mesh.segi.isEmpty) continue;

    // Bayangan kontak digambar duluan & di luar urutan kedalaman: dia nempel
    // di lantai persis di bawah bendanya, jadi nggak pernah nutupin apa pun.
    if (objek.bayangan > 0) {
      // Bidang bayangannya lantai tempat benda BERDIRI, bukan y = 0 dunia:
      // objek yang digeser ke bawah biar pas di tengah panel tetap harus
      // punya bayangan yang nempel di kakinya.
      final kaki = keRuangKamera(objek.posisi);
      final titikKaki = proyeksi(kaki);
      if (titikKaki != null) {
        final lebar = objek.bayangan * skalaLayar * f / math.max(0.12, -kaki.z);
        // Tiga oval menipis, bukan `MaskFilter.blur`: blur beneran maksa
        // `saveLayer` tiap frame — persis yang dulu bikin `NeuInset` ngelag di
        // HP low-end (lihat catatan di `neu.dart`). Di ukuran sekecil ini
        // bedanya nggak kebedain.
        for (var lapis = 0; lapis < 3; lapis++) {
          final skala = 1.0 + lapis * 0.42;
          canvas.drawOval(
            Rect.fromCenter(
              center: titikKaki,
              width: lebar * skala,
              height: lebar * skala * 0.34,
            ),
            Paint()
              ..color = const Color(
                0xFF000000,
              ).withValues(alpha: (0.17 - lapis * 0.05) * objek.opasitas),
          );
        }
      }
    }

    // Transform titik SEKALI per objek, bukan sekali per bidang: satu titik
    // rata-rata dipakai 3 bidang, jadi ini motong dua per tiga kerjanya.
    final dunia = <Vek3>[];
    final kam = <Vek3>[];
    final layar = <Offset?>[];
    for (final t in mesh.titik) {
      var p = t * objek.skala;
      if (objek.putarZ != 0) p = p.putarZ(objek.putarZ);
      if (objek.putarX != 0) p = p.putarX(objek.putarX);
      if (objek.putarY != 0) p = p.putarY(objek.putarY);
      p = p + objek.posisi;
      dunia.add(p);
      final k = keRuangKamera(p);
      kam.add(k);
      layar.add(proyeksi(k));
    }

    // Kebalikan dari transform view di atas: ini titik kamera dinyatakan
    // dalam koordinat dunia, dipakai buat arah pandang tiap bidang.
    final posisiKamera = Vek3(
      0,
      0,
      kamera.jarak,
    ).putarX(-kamera.pitch).putarY(kamera.yaw);

    for (final segi in mesh.segi) {
      final n = segi.indeks.length;
      if (n < 3) continue;

      final a = dunia[segi.indeks[0]];
      final b = dunia[segi.indeks[1]];
      final c = dunia[segi.indeks[2]];
      final normal = (b - a).cross(c - a).satuan;

      // Titik tengah bidang, buat arah pandang & pengurutan kedalaman.
      var sx = 0.0, sy = 0.0, sz = 0.0, sd = 0.0;
      var adaYangDiLuar = false;
      for (final i in segi.indeks) {
        final t = dunia[i];
        sx += t.x;
        sy += t.y;
        sz += t.z;
        sd += kam[i].z;
        if (layar[i] == null) adaYangDiLuar = true;
      }
      if (adaYangDiLuar) continue;
      final tengah = Vek3(sx / n, sy / n, sz / n);
      final arahPandang = (posisiKamera - tengah).satuan;

      final hadap = normal.dot(arahPandang);
      // Bidang tembus pandang tetap digambar dari belakang — itu justru yang
      // bikin gelas kebaca sebagai gelas.
      if (hadap <= 0 && segi.tembusPandang >= 0.999) continue;

      final sisiLuar = hadap > 0;
      final n2 = sisiLuar ? normal : normal * -1;

      // Lambert + sorot Blinn-Phong sederhana.
      final lambert = math.max(0.0, n2.dot(arahCahaya));
      final terang = cahaya.ambient + (1 - cahaya.ambient) * lambert;
      final setengah = (arahCahaya + arahPandang).satuan;
      final sorot =
          math.pow(math.max(0.0, n2.dot(setengah)), 26).toDouble() * segi.kilap;

      // Kilau tepi: bidang yang hampir sejajar arah pandang dikasih warna
      // aksen. Ini trik yang bikin low-poly kelihatan dilapis kaca.
      final tepi =
          math.pow(1 - math.min(1.0, n2.dot(arahPandang).abs()), 3).toDouble() *
          segi.kilap *
          cahaya.kuatTepi;

      var r = segi.warna.r * terang + sorot;
      var g = segi.warna.g * terang + sorot;
      var bb = segi.warna.b * terang + sorot;
      r = r + (cahaya.warnaTepi.r - r) * tepi.clamp(0.0, 1.0);
      g = g + (cahaya.warnaTepi.g - g) * tepi.clamp(0.0, 1.0);
      bb = bb + (cahaya.warnaTepi.b - bb) * tepi.clamp(0.0, 1.0);

      final path = Path()
        ..moveTo(layar[segi.indeks[0]]!.dx, layar[segi.indeks[0]]!.dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(layar[segi.indeks[i]]!.dx, layar[segi.indeks[i]]!.dy);
      }
      path.close();

      siap.add(
        _SegiSiap(
          path,
          Color.from(
            alpha: segi.warna.a * segi.tembusPandang * objek.opasitas,
            red: r.clamp(0.0, 1.0),
            green: g.clamp(0.0, 1.0),
            blue: bb.clamp(0.0, 1.0),
          ),
          sd / n,
        ),
      );
    }
  }

  // Paling jauh duluan. z di ruang kamera makin negatif = makin jauh.
  siap.sort((a, b) => a.kedalaman.compareTo(b.kedalaman));

  final isi = Paint()..style = PaintingStyle.fill;
  final tepi = adegan.garisTepi <= 0
      ? null
      : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = adegan.garisTepi
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16));
  for (final s in siap) {
    canvas.drawPath(s.path, isi..color = s.warna);
    if (tepi != null) canvas.drawPath(s.path, tepi);
  }
}
