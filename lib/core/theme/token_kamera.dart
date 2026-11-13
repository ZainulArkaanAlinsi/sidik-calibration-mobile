/// Ukuran & kepekatan lapisan layar kamera "Foto lembar kerja".
///
/// WARNA tidak ada di sini: kamera memakai bahan KACA dari `SidikMaterial`
/// (`kaca` untuk dasar gelap, `lcdTeks` untuk teks & ikon, `lcdAmber` untuk
/// penanda perhatian) — token yang sama di tema terang dan gelap, karena
/// pratinjau kamera memang selalu "gelap". Jarak & sudut: `AppSpacing`.
///
/// Dipisah dari `AppSpacing` karena angka-angka ini hanya bermakna untuk satu
/// layar, tapi tetap tidak boleh ditulis mentah di widget.
class TokenKamera {
  const TokenKamera._();

  /// Sasaran sentuh minimum (dp) untuk tombol apa pun di layar kamera.
  static const double sasaranSentuh = 48;

  /// Tombol jepret: satu-satunya aksi utama, jauh lebih besar dari minimum
  /// supaya kena dengan ibu jari sambil memegang HP dan lembar.
  static const double tombolJepret = 80;

  /// Tebal cincin luar tombol jepret.
  static const double cincinJepret = 4;

  /// Penanda titik fokus setelah ketuk.
  static const double cincinFokus = 64;
  static const double garisFokus = 2;

  /// Sudut bingkai panduan: tebal garis dan rentang panjangnya.
  static const double garisSudut = 3;

  /// Tebal garis gelap di kedua sisi sudut terang (agar tampak di atas kertas
  /// putih).
  static const double tepiSudut = 1.5;
  static const double sudutMin = 16;
  static const double sudutMaks = 40;
  static const double porsiSudut = 0.12;

  /// Sisa di tiap sisi area pratinjau yang tidak dipakai bingkai panduan.
  static const double sisaBingkai = 0.06;

  /// Kepekatan dasar gelap di bawah SEMUA teks & tombol yang menumpang di atas
  /// pratinjau. Pratinjau bisa selembar kertas putih; dasar ini yang menjamin
  /// kontras teks ≥ 4,5:1 (dijaga `test/kamera_pindai_desain_test.dart`).
  static const double dasarLapisan = 0.86;

  /// Redaman area di luar bingkai panduan.
  static const double redamanBingkai = 0.35;

  /// Lebar maksimum kartu teks, supaya baris tetap enak dibaca di tablet.
  static const double lebarTeksMaks = 480;

  /// Lebar rel kontrol di sisi (layar lanskap / tablet).
  static const double lebarRel = 112;

  /// Alpha tombol jepret saat dimatikan.
  static const double jepretMati = 0.38;
}
