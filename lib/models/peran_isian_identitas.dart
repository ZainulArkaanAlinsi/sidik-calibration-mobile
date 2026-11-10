/// Peran sebuah kolom lembar kerja untuk WARNA isian: identitas alat yang
/// tercetak di sertifikat, atau (eksplisit) bukan.
///
/// SATU tempat. Tabel [peranIsianIdentitas] adalah satu-satunya daftar kode
/// kolom identitas; layar, state, dan test membacanya dari sini. Kolom yang
/// tidak ada di tabel TIDAK ditebak: perilakunya tetap seperti sebelumnya
/// (lihat `LembarKerjaState.fieldWajib`).
///
/// ## Dari mana daftar ini
///
/// Kode kolom diambil dari bentuk lembar yang dikirim server
/// (`App\Services\Calibration\Profiles\*::bentukLembarKerja`, API `main`
/// 10 Nov 2026) dan dari cermin lokalnya (`contoh_lembar_kerja_*`,
/// `test/fixtures`), bukan ditebak dari label:
///
///  - nama alat → `equipment.nama_alat` (otomatis)
///  - merek / tipe / nomor seri → `alat_merk`, `alat_model`,
///    `alat_serial_number` (diketik teknisi, diisi awal dari master alat);
///    `equipment.*` untuk lembar yang menarik langsung dari alat
///  - pelanggan → `pemilik_nama`, `pemilik_alamat` (diketik, diisi awal dari
///    master alat); `customer.*` (otomatis)
///  - kapasitas / rentang ukur / resolusi → `spesifikasi_alat.kapasitas`,
///    `.resolusi`, `.rentang_ukur`, `.volumetric.kapasitas_ml`,
///    `.volumetric.resolusi_ml`; `equipment.range_resolusi` (otomatis)
///  - lokasi → `lokasi`, `lokasi_nama`
///  - tanggal kalibrasi → `tanggal_kalibrasi`
///
/// ## Yang TIDAK ada di profil mana pun yang diperiksa
///
/// "Nomor identifikasi" alat (`Equipment.noIdentifikasi` ada di data alat)
/// tidak punya kolom di bentuk lembar enam alat prioritas — jadi tidak ada
/// kode yang bisa dipetakan. Menambah entri tanpa kolom nyata hanya tabel
/// yang bohong.
///
/// ## Arti "identitas-wajib"
///
/// Hanya PENANDA WARNA: kolom kosong tampil oranye + `*`, terisi hijau. Ini
/// BUKAN gerbang kirim — server menandai semua kolom `wajib: false` dan draf
/// selalu boleh disimpan setengah jadi. Gerbang kirim tetap
/// `LembarKerjaScreen._submit`.
enum PeranIsian {
  /// Identitas yang tercetak di sertifikat: diwarnai menurut ISI.
  identitasWajib,

  /// Sengaja tidak diwarnai (tidak tercetak, penentu hitung yang sudah
  /// punya aturannya sendiri, atau bukan tugas teknisi). Dicatat eksplisit
  /// supaya "belum dipikirkan" dan "sudah diputuskan netral" tidak tertukar.
  opsional,
}

/// kode kolom -> peran. Lihat dokumentasi berkas ini sebelum menambah entri.
const Map<String, PeranIsian> peranIsianIdentitas = {
  // --- Nama alat
  'equipment.nama_alat': PeranIsian.identitasWajib,

  // --- Merek / tipe / nomor seri: ditarik langsung dari alat (otomatis)
  'equipment.merk': PeranIsian.identitasWajib,
  'equipment.model': PeranIsian.identitasWajib,
  'equipment.serial_number': PeranIsian.identitasWajib,

  // --- Merek / tipe / nomor seri: diketik teknisi dari badan alat
  'alat_merk': PeranIsian.identitasWajib,
  'alat_model': PeranIsian.identitasWajib,
  'alat_serial_number': PeranIsian.identitasWajib,

  // --- Pelanggan
  'pemilik_nama': PeranIsian.identitasWajib,
  'pemilik_alamat': PeranIsian.identitasWajib,
  'customer.nama': PeranIsian.identitasWajib,
  'customer.alamat': PeranIsian.identitasWajib,

  // --- Kapasitas / rentang ukur / resolusi
  'equipment.range_resolusi': PeranIsian.identitasWajib,
  'spesifikasi_alat.kapasitas': PeranIsian.identitasWajib,
  'spesifikasi_alat.resolusi': PeranIsian.identitasWajib,
  'spesifikasi_alat.rentang_ukur': PeranIsian.identitasWajib,
  'spesifikasi_alat.volumetric.kapasitas_ml': PeranIsian.identitasWajib,
  'spesifikasi_alat.volumetric.resolusi_ml': PeranIsian.identitasWajib,

  // --- Lokasi & tanggal kalibrasi
  'lokasi': PeranIsian.identitasWajib,
  'lokasi_nama': PeranIsian.identitasWajib,
  'tanggal_kalibrasi': PeranIsian.identitasWajib,

  // --- Sengaja netral (diputuskan, bukan terlewat)
  //
  // Tanggal diterima: bukan salah satu identitas yang diminta pemilik; belum
  // ada bukti tercetak di sertifikat.
  'tanggal_terima': PeranIsian.opsional,
  // Ruangan (Inlab): dropdown master ruangan; belum ada bukti ia dicetak
  // sebagai "lokasi" di sertifikat.
  'room_id': PeranIsian.opsional,
  // Order Number: BACA SAJA di lembar kerja, diisi Master Data di layar
  // periksa. Teknisi tidak bisa melengkapinya, jadi tidak boleh oranye.
  'nomor_order': PeranIsian.opsional,
  // Penentu hitung, bukan identitas tercetak: kelas, toleransi, tipe
  // thermocouple alat pelanggan, nilai e Timbangan. Yang menentukan angka
  // sudah punya aturan sendiri (`LembarKerjaState._kodePenentuAngka`).
  'spesifikasi_alat.volumetric.kelas': PeranIsian.opsional,
  'spesifikasi_alat.volumetric.toleransi_ml': PeranIsian.opsional,
  'spesifikasi_alat.tipe_thermocouple': PeranIsian.opsional,
  'spesifikasi_alat.nilai_e': PeranIsian.opsional,
  'spesifikasi_alat.kelas': PeranIsian.opsional,
};

/// `true` bila [kode] adalah identitas alat yang diwarnai menurut ISI.
bool adalahIdentitasWajib(String kode) =>
    peranIsianIdentitas[kode] == PeranIsian.identitasWajib;
