/// Standar acuan buat dropdown "Standar Acuan" di layar Input Kalibrasi
/// (`GET/POST/PUT/DELETE /api/standards`, `docs/kontrak-api.md` §4). Wajib
/// dikirim (`standard_id`) di `POST /api/calibrations` — ketidakpastiannya
/// jadi komponen Type B terbesar di perhitungan GUM backend.
///
/// Baca: semua role. Tulis (`simpan`/`ubah`/`hapus`): admin doang — salah
/// ngetik ketidakpastian di sini bikin SEMUA sertifikat yang pakai standar
/// itu ikut salah.
class Standard {
  const Standard({
    required this.id,
    required this.nama,
    required this.merk,
    required this.serialNumber,
    required this.masihBerlaku,
    required this.ketidakpastian,
    required this.satuanKetidakpastian,
    required this.faktorCakupan,
    this.model = '',
    this.noSertifikat = '',
    this.tertelusurKe = '',
    this.berlakuSampai,
    this.drift,
    this.koefisienSuhu,
    this.parameterKondisi,
  });

  final int id;
  final String nama;
  final String merk;
  final String model;
  final String serialNumber;

  final String noSertifikat;
  final String tertelusurKe;
  final DateTime? berlakuSampai;

  /// Standar yang `false` ditolak `422` kalau dipakai — jangan ditampilin
  /// bisa dipilih (bukan disembunyikan dari list, cuma dinonaktifkan;
  /// teknisi yang nyari standar biasa dia pakai jangan ngira datanya ilang).
  final bool masihBerlaku;

  /// Nilai **diperluas** (udah dikali [faktorCakupan]), persis kayak yang
  /// tertulis di sertifikat standarnya — backend yang bagi balik waktu
  /// ngitung Type B, mobile cukup nampilin/kirim apa adanya.
  ///
  /// **Boleh null.** Thermohygro nggak pakai kolom ini sama sekali: dia punya
  /// DUA parameter (suhu & kelembaban) dengan U95% beda-beda, jadi angkanya
  /// ada di [parameterKondisi], bukan di sini. Dulu ini non-null dan bikin
  /// seluruh daftar standar gagal di-parse begitu ada satu thermohygro.
  final double? ketidakpastian;
  final String satuanKetidakpastian;
  final double faktorCakupan;

  /// Drift tahunan standar (opsional) — dipakai backend sebagai komponen
  /// Type B tambahan (`GumCalculator::komponenTypeB()`).
  final double? drift;

  /// Persamaan suhu larutan buffer dari sertifikat Merck: `{a, b, c}` buat
  /// y = a·x² + b·x + c. Cuma diisi di larutan buffer pH — inilah yang bikin
  /// nilai Standard di lembar perhitungan jadi 4,0092 di 22,2 °C, bukan 4,00.
  final Map<String, double>? koefisienSuhu;

  /// Data sertifikat thermohygro per parameter:
  /// `{suhu: {indexed_value, correction, u95}, kelembaban: {...}}`.
  final Map<String, Map<String, double?>>? parameterKondisi;

  /// Standar yang siap dipakai buat ngitung nilai titik pada suhu larutan.
  bool get punyaKurvaSuhu => koefisienSuhu != null;

  /// Standar yang bisa dipakai sebagai Thermohygro Used di lembar perhitungan.
  bool get punyaParameterKondisi => parameterKondisi != null;

  Map<String, dynamic> toJson() => {
    'nama': nama,
    if (merk.isNotEmpty) 'merk': merk,
    if (model.isNotEmpty) 'model': model,
    if (serialNumber.isNotEmpty) 'serial_number': serialNumber,
    if (noSertifikat.isNotEmpty) 'no_sertifikat': noSertifikat,
    if (tertelusurKe.isNotEmpty) 'tertelusur_ke': tertelusurKe,
    if (berlakuSampai != null)
      'berlaku_sampai': berlakuSampai!.toUtc().toIso8601String(),
    'ketidakpastian': ketidakpastian,
    if (satuanKetidakpastian.isNotEmpty)
      'satuan_ketidakpastian': satuanKetidakpastian,
    'faktor_cakupan': faktorCakupan,
    if (drift != null) 'drift': drift,
    if (koefisienSuhu != null) 'koefisien_suhu': koefisienSuhu,
    if (parameterKondisi != null) 'parameter_kondisi': parameterKondisi,
  };

  factory Standard.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

    Map<String, double>? koefisien(Object? raw) {
      if (raw is! Map) return null;
      final a = (raw['a'] as num?)?.toDouble();
      final b = (raw['b'] as num?)?.toDouble();
      final c = (raw['c'] as num?)?.toDouble();
      // Ketiganya harus ada — persamaannya nggak kepakai kalau kurang satu,
      // dan backend juga nolak yang setengah terisi.
      if (a == null || b == null || c == null) return null;
      return {'a': a, 'b': b, 'c': c};
    }

    Map<String, Map<String, double?>>? kondisi(Object? raw) {
      if (raw is! Map) return null;

      final hasil = <String, Map<String, double?>>{};
      for (final parameter in const ['suhu', 'kelembaban']) {
        final blok = raw[parameter];
        if (blok is! Map) continue;
        hasil[parameter] = {
          'indexed_value': (blok['indexed_value'] as num?)?.toDouble(),
          'correction': (blok['correction'] as num?)?.toDouble(),
          'u95': (blok['u95'] as num?)?.toDouble(),
        };
      }

      return hasil.isEmpty ? null : hasil;
    }

    return Standard(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      merk: teks('merk'),
      model: teks('model'),
      serialNumber: teks('serial_number'),
      noSertifikat: teks('no_sertifikat'),
      tertelusurKe: teks('tertelusur_ke'),
      berlakuSampai: switch (json['berlaku_sampai']) {
        String s => DateTime.tryParse(s),
        _ => null,
      },
      masihBerlaku: json['masih_berlaku'] as bool? ?? false,
      ketidakpastian: (json['ketidakpastian'] as num?)?.toDouble(),
      satuanKetidakpastian: teks('satuan_ketidakpastian'),
      faktorCakupan: (json['faktor_cakupan'] as num?)?.toDouble() ?? 2,
      drift: (json['drift'] as num?)?.toDouble(),
      koefisienSuhu: koefisien(json['koefisien_suhu']),
      parameterKondisi: kondisi(json['parameter_kondisi']),
    );
  }
}
