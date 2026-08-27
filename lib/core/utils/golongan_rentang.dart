import '../../models/category.dart';
import 'angka.dart';

/// Satu golongan rentang siap-isi, dirangkum dari baris-baris kemampuan (CMC)
/// milik SATU `nama_alat` di `GET /api/categories/{kode}`.
///
/// Angka-angka ini datang dari lampiran akreditasi LK-285-IDN — rentang yang
/// ditentukan PT Sidik, yang selama ini diketik ulang teknisi dari lembar
/// kerja kertas. Golongan inilah yang dipakai buat mengisinya otomatis.
class GolonganRentang {
  const GolonganRentang({
    required this.satuan,
    this.parameter,
    this.min,
    this.maks,
    this.catatan,
  });

  /// Satuan yang dipakai SEMUA baris di golongan ini — itu yang bikin dia satu
  /// golongan.
  final String satuan;

  /// Nama parameternya kalau baris-barisnya sepakat satu parameter
  /// (`Suhu`, `Kelembapan`, `Tekanan`), `null` kalau beda-beda.
  ///
  /// Mesin UTM golongan `kN` isinya `Tekan` DAN `Tarik` — dua-duanya beneran
  /// kN, jadi rentangnya sah digabung, tapi namanya nggak bisa dipilih salah
  /// satu. Di situ `parameter` sengaja `null` biar labelnya nggak bohong.
  final String? parameter;

  /// Gabungan batas bawah/atas semua baris di golongan ini. **Bisa `null`** —
  /// sebagian kemampuan batasnya bukan angka (Oven: `range_min` kosong,
  /// [catatan]-nya "ambient").
  final double? min;
  final double? maks;

  /// `range_note` kalau baris-barisnya sepakat satu catatan.
  final String? catatan;

  /// Ada yang bisa diisi ke form. Golongan tanpa angka sama sekali nggak usah
  /// ditawarin.
  bool get adaIsinya => min != null || maks != null;

  String get minTeks => min == null ? '' : formatNilai(min!);
  String get maksTeks => maks == null ? '' : formatNilai(maks!);
}

/// Rangkum baris kemampuan satu nama alat jadi golongan-golongan rentang.
///
/// **Dikelompokkan per SATUAN, bukan digabung jadi satu.** Satu `nama_alat`
/// beneran bisa punya dua besaran yang beda sama sekali, dan menggabungnya
/// menghasilkan angka yang salah — bukan angka yang kurang teliti:
///
/// | nama_alat        | baris master                        | kalau digabung |
/// |------------------|-------------------------------------|----------------|
/// | Thermohygrometer | Suhu 15–50 °C, Kelembapan 30–90 %RH | 15–90 tanpa satuan |
/// | Autoklaf         | Suhu 105–121 °C, Tekanan 0–4 bar    | 0–121 tanpa satuan |
/// | Spectrophotometer| 190–810 nm, 10–100 %T               | 10–810 tanpa satuan |
/// | Mesin UTM        | 0–500 kgf, 10–3000 kN               | 0–3000 tanpa satuan |
///
/// Angka gabungan kayak gitu nggak ditolak siapa pun: dia lolos ke kolom
/// `range_min`/`range_max` alat, ikut ke lembar kerja, dan ikut ke sertifikat.
///
/// Yang SATU satuan aman digabung, dan itu justru yang paling sering: rentang
/// master dipecah per golongan ketidakpastian, bukan per besaran. Thermocouple
/// −20–150 / 150–400 / 400–600 °C itu satu alat rentang −20–600 °C; Termometer
/// Gelas 0–100 / 100–200 °C jadi 0–200 °C.
///
/// Urutan golongannya ngikutin urutan baris dari server (Suhu dulu, baru
/// Kelembapan) — bukan diurut ulang, biar yang utama tetap di depan.
List<GolonganRentang> golonganRentangDari(
  Iterable<CalibrationCapability> baris,
) {
  final perSatuan = <String, List<CalibrationCapability>>{};
  for (final k in baris) {
    // Satuan kosong tetap dikelompokkan (jadi golongan ''), bukan dibuang:
    // rentangnya masih kepakai, cuma satuannya yang diketik teknisi sendiri.
    perSatuan.putIfAbsent((k.satuan ?? '').trim(), () => []).add(k);
  }

  final hasil = <GolonganRentang>[];
  for (final entri in perSatuan.entries) {
    final set = entri.value;
    final minSemua = set.map((k) => k.rangeMin).nonNulls;
    final maksSemua = set.map((k) => k.rangeMax).nonNulls;

    final golongan = GolonganRentang(
      satuan: entri.key,
      parameter: _sepakat(set.map((k) => k.parameter)),
      min: minSemua.isEmpty ? null : minSemua.reduce((a, b) => a < b ? a : b),
      maks: maksSemua.isEmpty ? null : maksSemua.reduce((a, b) => a > b ? a : b),
      catatan: _sepakat(set.map((k) => k.rangeNote)),
    );
    if (golongan.adaIsinya) hasil.add(golongan);
  }
  return hasil;
}

/// Nilai yang disepakati semua baris, `null` kalau ada yang beda atau kosong.
String? _sepakat(Iterable<String?> nilai) {
  final unik = nilai
      .map((n) => (n ?? '').trim())
      .where((n) => n.isNotEmpty)
      .toSet();
  return unik.length == 1 ? unik.first : null;
}
