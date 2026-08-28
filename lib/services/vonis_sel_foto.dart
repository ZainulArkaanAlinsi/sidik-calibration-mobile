import 'pembaca_halaman.dart' show TeksTerbaca;

/// Vonis satu sel hasil "FOTO TABEL INI" — **dihitung di perangkat**.
///
/// ## Kenapa ini terpisah dari `VonisSel`
///
/// `VonisSel` (model `worksheet_scan.dart`) vonisnya datang dari SERVER, dan
/// docblock-nya menyebut alasannya: aturannya harus sama di semua versi APK,
/// karena HP yang menghitung sendiri bikin dua teknisi dengan versi beda dapat
/// jawaban beda buat foto yang sama.
///
/// Jalur foto ini nggak punya server sama sekali — OCR-nya jalan di perangkat
/// supaya citra lembar kerja pelanggan **tidak pernah keluar dari HP**. Jadi
/// vonisnya memang harus lahir di sini, dan bahaya "dua APK dua jawaban" itu
/// nyata. Yang menutupnya: [AmbangKeyakinan] dibawa masuk dari luar, bukan
/// dipatok di dalam fungsi — begitu server mengirimkan ambangnya lewat bentuk
/// lembar kerja, seluruh APK ikut angka yang sama tanpa nyentuh berkas ini.
/// Sampai itu ada, [AmbangKeyakinan.bawaan] yang dipakai, dan itu **satu
/// tempat**, bukan angka yang berserak.
enum VonisFoto {
  /// Kebaca yakin. **Tidak pernah terjadi di jalur ini** — lihat
  /// [NilaiVonisFoto.dari]. Disediakan supaya kalau suatu saat jalur ini ikut
  /// membaca teks CETAK (bukan tulisan tangan), vonisnya sudah punya tempat.
  hijau,

  /// Keisi, tapi WAJIB dilihat teknisi.
  kuning,

  /// Nggak bisa dipercaya. Nilainya dikosongkan, teknisi mengetik sendiri.
  merah,

  /// Pengenalnya nggak melaporkan keyakinan sama sekali.
  ///
  /// **Bukan sinonim "ragu", dan bukan sinonim "yakin".** ML Kit menyetel
  /// `confidence` cuma di sebagian versi & perangkat. Dibedakan dari [kuning]
  /// karena yang ditampilkan ke teknisi juga beda: kuning menyebut angkanya
  /// ("72%"), yang ini menyebut bahwa angkanya memang tidak ada. Menyamakan
  /// keduanya bikin teknisi mengira sistemnya sudah menilai padahal belum.
  tidakDiketahui;

  /// Sel ini boleh keisi otomatis tanpa dilihat teknisi?
  ///
  /// Cuma [hijau]. [tidakDiketahui] ikut TIDAK boleh — keyakinan yang tidak
  /// dilaporkan bukan izin.
  bool get bolehOtomatis => this == VonisFoto.hijau;

  /// Nilai bacaannya ditampilkan duluan di kotak isian?
  ///
  /// [merah] tidak: vonis merah artinya bacaannya nggak bisa dipercaya, dan
  /// menampilkan angkanya duluan bikin teknisi cuma menyetujui apa yang sudah
  /// ada. Aturan ini disalin dari `PindaiReviewScreen`, yang sudah memutuskan
  /// hal yang sama buat jalur lembar bermarker.
  bool get nilainyaDitampilkan => this != VonisFoto.merah;
}

/// Ambang keyakinan buat memvonis sel.
///
/// Dipisah jadi tipe sendiri (bukan dua `double` yang dioper) supaya nggak ada
/// pemanggil yang ketuker urutannya, dan supaya ada satu tempat yang bisa
/// diganti begitu server mulai mengirim ambangnya.
class AmbangKeyakinan {
  const AmbangKeyakinan({required this.hijau, required this.kuning})
    : assert(hijau > kuning, 'ambang hijau harus di atas kuning');

  /// Ambang bawaan, dipakai selama server belum mengirim angkanya sendiri.
  ///
  /// Angkanya mengikuti kategori yang diminta pemilik proyek: HIGH ≥ 0,90,
  /// MEDIUM 0,70–0,89, LOW < 0,70. Ditulis di SATU tempat supaya waktu lab
  /// memutuskan angka lain, yang diubah cuma baris ini.
  static const bawaan = AmbangKeyakinan(hijau: 0.90, kuning: 0.70);

  final double hijau;
  final double kuning;
}

/// Memvonis satu bacaan OCR.
extension NilaiVonisFoto on VonisFoto {
  /// Vonis buat [keyakinan] sebuah sel di jalur FOTO.
  ///
  /// ## Kenapa [VonisFoto.hijau] tidak pernah keluar dari sini
  ///
  /// Angka di tabel lembar kerja itu **tulisan tangan teknisi**, dan pengenal
  /// teks tetap percaya diri waktu salah membaca coretan tangan — `7,02`
  /// dibaca `7.2` dengan keyakinan tinggi, dan keyakinan tinggi itulah yang
  /// bikin salahnya lolos. `PindaiReviewScreen` sudah memutuskan hal yang sama
  /// buat jalur lembar bermarker ("tulisan tangan nggak pernah dinaikin ke
  /// hijau"), dan alasannya sama persis di sini.
  ///
  /// Akibatnya disengaja: **tidak ada sel di jalur foto yang boleh mendarat di
  /// form tanpa dilihat teknisi.** Yang dihemat fitur ini bukan pemeriksaan,
  /// melainkan pengetikan.
  ///
  /// [tulisanTangan] `false` cuma buat pemanggil yang tahu pasti bahwa yang
  /// dibacanya teks CETAK. Belum ada pemanggil seperti itu hari ini; parameter
  /// ini ada supaya pembeda handwriting/cetak nanti punya tempat masuk yang
  /// jelas, bukan supaya ada yang mematikannya sekarang.
  static VonisFoto dari(
    double? keyakinan, {
    AmbangKeyakinan ambang = AmbangKeyakinan.bawaan,
    bool tulisanTangan = true,
  }) {
    if (keyakinan == null) return VonisFoto.tidakDiketahui;
    if (keyakinan < ambang.kuning) return VonisFoto.merah;
    if (keyakinan < ambang.hijau) return VonisFoto.kuning;

    // Di atas ambang hijau, tapi tulisan tangan — ditahan di kuning. Lihat
    // docblock method ini.
    return tulisanTangan ? VonisFoto.kuning : VonisFoto.hijau;
  }

  /// Vonis langsung dari potongan OCR-nya. Pintasan buat pemanggil yang
  /// memegang [TeksTerbaca] utuh.
  static VonisFoto dariTeks(
    TeksTerbaca t, {
    AmbangKeyakinan ambang = AmbangKeyakinan.bawaan,
    bool tulisanTangan = true,
  }) => dari(t.keyakinan, ambang: ambang, tulisanTangan: tulisanTangan);
}
