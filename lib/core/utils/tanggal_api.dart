/// Format tanggal buat dikirim ke API.
///
/// ## Kenapa ini ada
///
/// Kolom tanggal di backend bertipe `date` — **nggak ada jamnya**. Dulu mobile
/// ngirimnya `toUtc().toIso8601String()`, dan itu MUNDURIN TANGGALNYA sehari
/// buat semua pengguna di Indonesia:
///
/// ```
/// teknisi milih  : 30 Mei
/// dikirim        : 2026-05-29T17:00:00.000Z   ← UTC+7 digeser ke UTC
/// backend simpan : 29 Mei                      ← kolom `date`, jamnya dibuang
/// ```
///
/// Indonesia seluruhnya di timur UTC (+7/+8/+9), jadi ini **selalu** mundur,
/// bukan kadang-kadang. Di sertifikat kalibrasi, tanggal yang meleset sehari
/// itu cacat dokumen terkendali — bukan sekadar salah tampil.
///
/// Backend udah mbenerin sisi mereka 28 Juli (semua field tanggal jadi
/// `yyyy-MM-dd` polos). Ini sisi kirimnya.
///
/// ## Aturannya
///
/// Buat kolom `date`, pakai [tanggalApi] — ambil komponen tanggal **apa
/// adanya**, tanpa mampir ke UTC. Buat kolom yang beneran butuh jam
/// (`created_at`, dsb) UTC tetap benar; jangan pakai helper ini di situ.
library;

/// `DateTime` → `"yyyy-MM-dd"`, pakai komponen **lokal** apa adanya.
///
/// Sengaja nggak lewat `toUtc()`: yang dipilih teknisi di date picker itu
/// tanggal kalender, bukan titik waktu. 30 Mei ya 30 Mei, di zona mana pun
/// HP-nya disetel.
String tanggalApi(DateTime tanggal) {
  final bulan = tanggal.month.toString().padLeft(2, '0');
  final hari = tanggal.day.toString().padLeft(2, '0');
  return '${tanggal.year}-$bulan-$hari';
}
