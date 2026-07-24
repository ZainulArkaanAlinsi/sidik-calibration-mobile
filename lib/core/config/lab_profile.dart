/// Identitas laboratorium terakreditasi.
///
/// Sumbernya **Lampiran Sertifikat Akreditasi No. LK-285-IDN** (KAN,
/// SNI ISO/IEC 17025:2017) — lihat `Project-PT-Sidik/04 - Referensi Teknis/`.
///
/// Ini bukan sekadar teks branding: **nama & nomor akreditasi di sini yang
/// muncul di sertifikat kalibrasi**. Sertifikat wajib atas nama lab yang
/// beneran terakreditasi KAN. Salah nama = sertifikatnya nggak sah.
class LabProfile {
  const LabProfile._();

  static const String nama = 'PT Sistem Dirgantara Inovasi Teknologi';
  static const String namaSingkat = 'PT Sidik';
  static const String nomorAkreditasi = 'LK-285-IDN';
  static const String standar = 'SNI ISO/IEC 17025:2017';

  static const String alamat =
      'Kawasan Niaga MTC/MIM Blok J No 25, Buahbatu, Kota Bandung, Jawa Barat';
  static const String telepon = '(022) 7537623';
  static const String email = 'sidikkalibrasi@pt-sidik.com';

  /// Masa berlaku akreditasi. Kalau lewat tanggal ini, sertifikat baru
  /// **nggak boleh** diterbitkan sampai akreditasinya diperpanjang.
  static final DateTime akreditasiMulai = DateTime(2024, 10, 28);
  static final DateTime akreditasiBerakhir = DateTime(2029, 10, 27);

  /// Faktor cakupan & tingkat kepercayaan yang dinyatakan di lampiran
  /// akreditasi. Dipakai di perhitungan ketidakpastian (GUM) dan dicetak di
  /// sertifikat.
  static const double faktorCakupanK = 2.0;
  static const int tingkatKepercayaanPersen = 95;

  static const String catatanKetidakpastian =
      'Ketidakpastian diperluas dinyatakan pada tingkat kepercayaan 95% '
      'dengan faktor cakupan k=2.';
}
