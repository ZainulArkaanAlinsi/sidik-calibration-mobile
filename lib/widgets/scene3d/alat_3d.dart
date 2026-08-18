import 'dart:math' as math;
import 'dart:ui';

import 'mesh3d.dart';

/// Model 3D alat kalibrasi, dirakit dari bentuk dasar di [Mesh3D].
///
/// Semua model dibikin **low-poly dengan sengaja**: satu alat 60–110 bidang.
/// Yang dikejar bukan kemiripan foto, tapi siluet yang langsung kebaca di
/// ukuran ibu jari — anak timbangan kebaca dari pinggangnya, jangka sorong
/// dari rahang + rel-nya.
///
/// Ukurannya pakai satuan dunia yang seragam: tiap alat kira-kira setinggi
/// 2 satuan dan berdiri di atas lantai y = 0. Jadi alat bisa ditukar-tukar di
/// satu adegan tanpa nyetel ulang kamera.
class Alat3D {
  const Alat3D._();

  // Bahan. Semua alat pakai palet yang sama biar sekumpulan alat kebaca
  // sebagai satu keluarga, bukan tumpukan mainan warna-warni.
  static const Color _baja = Color(0xFFCBD7E2);
  static const Color _bajaGelap = Color(0xFF93A7B8);
  static const Color _bajaTua = Color(0xFF6C7F90);
  static const Color _bodiNavy = Color(0xFF17334C);
  static const Color _bodiNavyTua = Color(0xFF0E2236);
  static const Color _teal = Color(0xFF19A899);
  static const Color _amber = Color(0xFFF2B84B);
  static const Color _layar = Color(0xFF0A1F2C);
  static const Color _kaca = Color(0xFF9AD7E8);
  static const Color _cairan = Color(0xFF1F8FA8);
  static const Color _kertas = Color(0xFFF3F6FA);

  /// Balok yang ditaruh pakai titik tengah + ukuran — jauh lebih enak dibaca
  /// waktu ngerakit daripada dua sudut berlawanan.
  static Mesh3D _kotak(
    Vek3 pusat,
    Vek3 ukuran, {
    required Color warna,
    double kilap = 0.3,
    Color? warnaAtas,
  }) {
    final h = ukuran * 0.5;
    return Mesh3D.balok(
      pusat - h,
      pusat + h,
      warna: warna,
      kilap: kilap,
      warnaAtas: warnaAtas,
    );
  }

  /// **Anak timbangan** (mass standard) — benda paling ikonik di lab
  /// kalibrasi: pinggang mengecil, kepala tombol, dudukan lebar.
  static Mesh3D anakTimbangan() => Mesh3D.gabung([
    // Alas
    Mesh3D.tabung(
      jariBawah: 0.86,
      jariAtas: 0.80,
      yBawah: 0,
      yAtas: 0.30,
      warna: _baja,
      warnaTutup: _bajaGelap,
      kilap: 0.75,
    ),
    // Cincin aksen di pinggang alas — penanda kelas massa di alat aslinya.
    Mesh3D.tabung(
      jariBawah: 0.83,
      jariAtas: 0.83,
      yBawah: 0.30,
      yAtas: 0.38,
      warna: _amber,
      kilap: 0.85,
      tutupAtas: false,
      tutupBawah: false,
    ),
    // Badan yang mengecil ke atas
    Mesh3D.tabung(
      jariBawah: 0.80,
      jariAtas: 0.44,
      yBawah: 0.36,
      yAtas: 1.30,
      warna: _baja,
      warnaTutup: _bajaGelap,
      kilap: 0.8,
    ),
    // Leher
    Mesh3D.tabung(
      jariBawah: 0.30,
      jariAtas: 0.30,
      yBawah: 1.28,
      yAtas: 1.62,
      warna: _bajaGelap,
      kilap: 0.7,
    ),
    // Kepala tombol
    Mesh3D.tabung(
      jariBawah: 0.46,
      jariAtas: 0.34,
      yBawah: 1.60,
      yAtas: 1.92,
      warna: _baja,
      warnaTutup: Color(0xFFE8F1F8),
      kilap: 0.9,
    ),
  ]);

  /// **Jangka sorong** (caliper) — rel + dua rahang + skala nonius.
  /// Ditidurin agak miring supaya rahangnya kebaca dari depan.
  static Mesh3D jangkaSorong() {
    final bagian = <Mesh3D>[
      // Rel utama
      _kotak(
        const Vek3(0.15, 0.92, 0),
        const Vek3(2.60, 0.20, 0.34),
        warna: _baja,
        warnaAtas: const Color(0xFFE6EEF5),
        kilap: 0.8,
      ),
      // Rahang tetap (bawah + atas)
      _kotak(
        const Vek3(-1.05, 0.58, 0),
        const Vek3(0.22, 0.90, 0.30),
        warna: _bajaGelap,
        kilap: 0.7,
      ),
      _kotak(
        const Vek3(-1.05, 1.36, 0),
        const Vek3(0.22, 0.72, 0.30),
        warna: _bajaGelap,
        kilap: 0.7,
      ),
      // Rahang geser
      _kotak(
        const Vek3(0.02, 0.62, 0),
        const Vek3(0.20, 0.82, 0.32),
        warna: _bajaTua,
        kilap: 0.7,
      ),
      _kotak(
        const Vek3(0.02, 1.32, 0),
        const Vek3(0.20, 0.64, 0.32),
        warna: _bajaTua,
        kilap: 0.7,
      ),
      // Badan skala nonius yang nempel di rahang geser
      _kotak(
        const Vek3(0.36, 0.92, 0),
        const Vek3(0.72, 0.42, 0.40),
        warna: _bodiNavy,
        warnaAtas: _bodiNavyTua,
        kilap: 0.35,
      ),
      // Layar digital
      _kotak(
        const Vek3(0.36, 1.16, 0.16),
        const Vek3(0.56, 0.24, 0.10),
        warna: _layar,
        warnaAtas: _teal,
        kilap: 0.95,
      ),
      // Tangkai kedalaman yang njulur ke kanan
      _kotak(
        const Vek3(1.44, 0.92, 0),
        const Vek3(0.90, 0.10, 0.10),
        warna: _bajaGelap,
        kilap: 0.8,
      ),
    ];

    // Garis skala. Dibikin dari balok tipis, bukan tekstur — di ukuran layar
    // HP dia cuma perlu kebaca sebagai "ada gurat-gurat halus di rel".
    for (var i = 0; i < 7; i++) {
      bagian.add(
        _kotak(
          Vek3(-0.72 + i * 0.24, 1.02, 0.175),
          const Vek3(0.035, 0.12, 0.01),
          warna: _bodiNavy,
          kilap: 0.1,
        ),
      );
    }
    return Mesh3D.gabung(bagian);
  }

  /// **Termohigrometer / probe suhu** — badan tegak berlayar, batang probe,
  /// ujung sensor. Ini bentuk yang paling sering dipegang teknisi di lapangan.
  static Mesh3D probeSuhu() => Mesh3D.gabung([
    // Dudukan
    _kotak(
      const Vek3(0, 0.09, 0),
      const Vek3(1.02, 0.18, 0.66),
      warna: _bodiNavyTua,
      kilap: 0.3,
    ),
    // Badan
    _kotak(
      const Vek3(0, 0.80, 0),
      const Vek3(0.86, 1.28, 0.44),
      warna: _bodiNavy,
      warnaAtas: const Color(0xFF1D3E5C),
      kilap: 0.4,
    ),
    // Layar
    _kotak(
      const Vek3(0, 0.98, 0.23),
      const Vek3(0.62, 0.52, 0.04),
      warna: _layar,
      kilap: 0.95,
    ),
    // Baris angka di layar
    _kotak(
      const Vek3(-0.06, 1.06, 0.256),
      const Vek3(0.34, 0.13, 0.01),
      warna: _teal,
      kilap: 1.0,
    ),
    _kotak(
      const Vek3(-0.11, 0.88, 0.256),
      const Vek3(0.24, 0.07, 0.01),
      warna: const Color(0xFF2E5D6E),
      kilap: 0.6,
    ),
    // Tombol
    _kotak(
      const Vek3(0.22, 0.60, 0.23),
      const Vek3(0.18, 0.10, 0.04),
      warna: _amber,
      kilap: 0.7,
    ),
    // Batang probe
    Mesh3D.tabung(
      jariBawah: 0.055,
      jariAtas: 0.055,
      yBawah: 1.40,
      yAtas: 2.10,
      sisi: 10,
      warna: _baja,
      kilap: 0.85,
    ).geser(const Vek3(0.30, 0, 0)),
    // Ujung sensor
    Mesh3D.tabung(
      jariBawah: 0.085,
      jariAtas: 0.02,
      yBawah: 2.08,
      yAtas: 2.26,
      sisi: 10,
      warna: _amber,
      kilap: 0.9,
    ).geser(const Vek3(0.30, 0, 0)),
  ]);

  /// **Gelas ukur + probe pH** — satu-satunya model yang pakai bidang tembus
  /// pandang. Kacanya digambar dua sisi (depan & belakang) jadi cairannya
  /// beneran kelihatan dari balik dinding gelas.
  static Mesh3D gelasProbe() => Mesh3D.gabung([
    // Cairan (digambar duluan, ketutup kaca)
    Mesh3D.tabung(
      jariBawah: 0.60,
      jariAtas: 0.62,
      yBawah: 0.04,
      yAtas: 0.86,
      warna: _cairan,
      warnaTutup: const Color(0xFF44BFD1),
      kilap: 0.6,
    ),
    // Dinding gelas
    Mesh3D.tabung(
      jariBawah: 0.64,
      jariAtas: 0.68,
      yBawah: 0,
      yAtas: 1.20,
      warna: _kaca,
      kilap: 1.0,
      tembusPandang: 0.30,
      tutupAtas: false,
      tutupBawah: false,
    ),
    // Bibir gelas
    Mesh3D.tabung(
      jariBawah: 0.68,
      jariAtas: 0.70,
      yBawah: 1.18,
      yAtas: 1.24,
      warna: const Color(0xFFD7F0F7),
      kilap: 1.0,
      tembusPandang: 0.55,
      tutupAtas: false,
      tutupBawah: false,
    ),
    // Batang probe yang nyelup
    Mesh3D.tabung(
      jariBawah: 0.075,
      jariAtas: 0.075,
      yBawah: 0.20,
      yAtas: 1.86,
      sisi: 10,
      warna: _baja,
      kilap: 0.85,
    ).geser(const Vek3(0.18, 0, -0.06)),
    // Kepala probe
    _kotak(
      const Vek3(0.18, 2.00, -0.06),
      const Vek3(0.34, 0.34, 0.30),
      warna: _bodiNavy,
      warnaAtas: _teal,
      kilap: 0.5,
    ),
  ]);

  /// **Sertifikat** — lembar + pita segel. Hasil akhir seluruh alur kerja
  /// app ini, jadi dia yang muncul di scene terakhir onboarding.
  static Mesh3D sertifikat() {
    final bagian = <Mesh3D>[
      // Lembar, direbahin dikit biar kelihatan bidangnya
      _kotak(
        const Vek3(0, 0.72, 0),
        const Vek3(1.36, 1.80, 0.05),
        warna: _kertas,
        kilap: 0.25,
      ),
      // Kepala berwarna
      _kotak(
        const Vek3(0, 1.42, 0.031),
        const Vek3(1.36, 0.40, 0.01),
        warna: _bodiNavy,
        kilap: 0.3,
      ),
      // Segel bundar
      Mesh3D.tabung(
        jariBawah: 0.20,
        jariAtas: 0.20,
        yBawah: 0.02,
        yAtas: 0.05,
        sisi: 12,
        warna: _amber,
        warnaTutup: const Color(0xFFFFD98A),
        kilap: 0.8,
      ).putarX(math.pi / 2).geser(const Vek3(0.40, 0.34, 0.06)),
    ];
    // Baris teks
    for (var i = 0; i < 5; i++) {
      bagian.add(
        _kotak(
          Vek3(-0.16, 1.14 - i * 0.17, 0.031),
          Vek3(0.86 - (i.isOdd ? 0.22 : 0), 0.055, 0.01),
          warna: const Color(0xFFB9C6D4),
          kilap: 0.1,
        ),
      );
    }
    return Mesh3D.gabung(bagian);
  }

  /// **Papan lembar kerja + HP yang lagi motret** — scene "isi lembar kerja"
  /// di onboarding. Sudut HP-nya dimiringin ke lembar, jadi hubungan
  /// "difoto → masuk tabel" kebaca tanpa teks.
  static Mesh3D lembarKerja() {
    final bagian = <Mesh3D>[
      // Papan jalan
      _kotak(
        const Vek3(0, 0.06, 0),
        const Vek3(1.50, 0.12, 1.94),
        warna: _bodiNavy,
        warnaAtas: _bodiNavyTua,
        kilap: 0.3,
      ),
      // Kertas
      _kotak(
        const Vek3(0, 0.14, 0.06),
        const Vek3(1.30, 0.04, 1.72),
        warna: _kertas,
        warnaAtas: const Color(0xFFFDFEFF),
        kilap: 0.2,
      ),
      // Penjepit
      _kotak(
        const Vek3(0, 0.20, -0.82),
        const Vek3(0.62, 0.14, 0.22),
        warna: _bajaGelap,
        kilap: 0.8,
      ),
    ];
    // Kisi tabel di kertas — tiga kolom, empat baris.
    for (var b = 0; b < 4; b++) {
      bagian.add(
        _kotak(
          Vek3(0, 0.17, -0.34 + b * 0.40),
          const Vek3(1.10, 0.006, 0.02),
          warna: const Color(0xFF9FB0C1),
          kilap: 0.05,
        ),
      );
    }
    for (var k = 0; k < 2; k++) {
      bagian.add(
        _kotak(
          Vek3(-0.18 + k * 0.36, 0.17, 0.26),
          const Vek3(0.02, 0.006, 1.24),
          warna: const Color(0xFF9FB0C1),
          kilap: 0.05,
        ),
      );
    }
    // HP yang megang kamera, dimiringin ke lembar.
    bagian.add(
      Mesh3D.gabung([
        _kotak(
          Vek3.nol,
          const Vek3(0.72, 1.36, 0.08),
          warna: _bodiNavyTua,
          kilap: 0.5,
        ),
        _kotak(
          const Vek3(0, 0.04, 0.045),
          const Vek3(0.60, 1.14, 0.01),
          warna: _layar,
          kilap: 0.95,
        ),
        // Bingkai pindai di layar
        _kotak(
          const Vek3(0, 0.16, 0.052),
          const Vek3(0.44, 0.03, 0.01),
          warna: _teal,
          kilap: 1.0,
        ),
        _kotak(
          const Vek3(0, -0.28, 0.052),
          const Vek3(0.44, 0.03, 0.01),
          warna: _teal,
          kilap: 1.0,
        ),
        _kotak(
          const Vek3(0, 0.52, 0.052),
          const Vek3(0.18, 0.06, 0.01),
          warna: _amber,
          kilap: 1.0,
        ),
      ]).putarX(-0.42).putarZ(0.16).geser(const Vek3(0.86, 1.14, 0.42)),
    );
    return Mesh3D.gabung(bagian);
  }
}
