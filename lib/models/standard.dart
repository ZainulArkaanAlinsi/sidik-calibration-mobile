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
  final double ketidakpastian;
  final String satuanKetidakpastian;
  final double faktorCakupan;

  /// Drift tahunan standar (opsional) — dipakai backend sebagai komponen
  /// Type B tambahan (`GumCalculator::komponenTypeB()`).
  final double? drift;

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
  };

  factory Standard.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

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
      ketidakpastian: (json['ketidakpastian'] as num).toDouble(),
      satuanKetidakpastian: teks('satuan_ketidakpastian'),
      faktorCakupan: (json['faktor_cakupan'] as num?)?.toDouble() ?? 2,
      drift: (json['drift'] as num?)?.toDouble(),
    );
  }
}
