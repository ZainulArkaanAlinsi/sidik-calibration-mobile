/// Bentuk lembar kerja contoh **Micrometer** (kelompok Panjang, alat ke-25).
///
/// ## Kenapa berkas ini ada, dan kenapa isinya nggak diketik tangan
///
/// Isinya salinan APA ADANYA dari respons
/// `GET /api/calibrations/lembar-kerja?equipment_id=…` untuk alat contoh
/// `ZQ-100` (Micrometer Digital Mitutoyo IP65, kapasitas 50 mm, resolusi
/// 0,001 mm) — sesi `0106-CAL-1023` yang ter-seed di backend. Digenerate dari
/// JSON-nya, bukan disusun ulang di sini: bentuk yang diketik tangan bakal
/// menyimpang diam-diam begitu backendnya direvisi, dan test yang jalan di atas
/// bentuk basi memberi rasa aman yang salah.
///
/// ## Yang dijaga bentuk ini, dan nggak dijaga bentuk lain mana pun
///
/// Empat hal cuma ada di lembar ini:
///
///  1. **Tabel yang barisnya TERKUNCI.** `hasil` memasang
///     `titik_bisa_diubah: false` dengan sebelas `titik_ukur` yang SUDAH
///     terisi dari kertas (`SIDIK-FM-CAL-0522.B_Rev.1`). Dua puluh empat
///     lembar sebelumnya membiarkan teknisi menyusun titiknya sendiri; di sini
///     nominal balok ukurnya dipatok Instruksi Kerja, dan yang diketik ulang
///     teknisi tetap kalah di server. Kotak `titik_ukur` wajib read-only, dan
///     tombol tambah/hapus baris nggak boleh muncul.
///  2. **Nomor formulir yang ikut ALAT.** `kode_dokumen` di sini `…0522.B…`
///     karena kapasitasnya 50 mm. Empat kertas, empat nomor; alat di luar
///     keempat pita CMC memulangkan `null` dan sesinya diblokir.
///  3. **Dua tabel ber-`tahap` SAMA yang dipisah `offset_kunci`.** `hasil` dan
///     `evaluasi` dua-duanya `sesudah_adjustment` tanpa `peran`, jadi
///     `TabelHasil.kunciTabel` keduanya sama. Tanpa `offset_kunci: 1000` di
///     `evaluasi`, dua tabel itu bisa berbagi satu `TitikState` — kelas
///     kegagalan yang sama dengan Accuracy vs Repeatability di Timbangan.
///  4. **Tabel yang isinya BUKAN titik ukur.** `evaluasi` menyatakan
///     `simpan_ke: spesifikasi_alat.micrometer.pra_evaluasi`. Sepuluh
///     pembacaan berulang di SATU titik, dan dari situ pengulangan (Type A)
///     seluruh sesi lahir — bukan dari lima pembacaan tiap titik. Kurang dari
///     dua angka di situ memblokir seluruh sesi.
///
/// Dropdown `spesifikasi_alat.micrometer.satuan` MENENTUKAN ANGKA, bukan
/// hiasan: server mengalikan seluruh pembacaan dengan faktornya (mm ×1,
/// inch ×25,4, µm ×0,001) sekali di ujung masuk. Master lab sendiri pernah
/// salah di sini — satuan `inch` dengan angka milimeter menerbitkan koreksi
/// −61 mm pada balok ukur 2,5 mm, tanpa satu pun sel memprotes.
///
/// Yang TIDAK ada di lembar ini, dan sengaja: kotak suhu balok ukur & suhu
/// UUT. Keduanya diturunkan server dari rata-rata `suhu_awal`/`suhu_akhir` —
/// terbukti begitu di keempat workbook master.
library;

/// Blok admin nggak ada di lembar ini: `MicrometerProfile` nggak memasang
/// bagian `administratif`, dan `nomor_order` sudah tampil buat teknisi di blok
/// `pemilik`. Parameternya tetap diterima supaya cabang di
/// `lembar_kerja_service.dart` seragam dengan dua puluh empat lembar lain.
Map<String, dynamic> contohBentukLembarKerjaMicrometer({
  bool untukAdmin = false,
}) {
  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0522.B_Rev.1',
    'kode_metode': 'SIDIK-IK-CAL-0515_Rev.3',
    'nomor_lingkup': 'LK-285-IDN',
    'judul': 'Calibration Work Sheet - Micrometer (25-50 mm)',
    'jumlah_pengulangan': 5,
    'satuan': 'mm',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Isi SATUAN alat lebih dulu — dia yang mengubah semua angka lembar ini ke mm. Nominal balok ukurnya SUDAH DIPATOK kertas (sebelas titik per rentang) dan tidak bisa diubah: tumpukan keping yang membentuknya ditentukan Instruksi Kerja, bukan dipilih di lapangan. Baris Evaluasi WAJIB diisi sepuluh-duanya — dari situ pengulangannya lahir, bukan dari lima pembacaan tiap titik.',
    'budget_ketidakpastian': {
      'tersedia': true,
      'sumber': 'Master_Olah_Data_Micrometer_{025,2550,5075,75100}mm.xlsm',
      'catatan':
          'Sembilan komponen tingkat-SESI, lantai CMC empat pita (0,83 / 0,87 / 0,91 / 0,91 µm). Sesi yang kapasitasnya di luar keempat pita diblokir, bukan diterbitkan tanpa lantai.',
    },
    'bagian': [
      {
        'kode': 'identitas_alat',
        'halaman': 1,
        'judul': 'Identitas Alat dan Data Customer',
        'field': [
          {
            'kode': 'equipment_id',
            'label': 'Nama Alat',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_alat',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'equipment.nama_alat',
            'label': 'Nama Alat',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_merk',
            'label': 'Merk',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_model',
            'label': 'Type',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_serial_number',
            'label': 'No. Seri',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.micrometer.satuan',
            'label': 'Satuan Alat',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {'nilai': 'mm', 'label': 'mm'},
              {'nilai': 'inch', 'label': 'inch'},
              {'nilai': 'µm', 'label': 'µm'},
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.rentang_ukur',
            'label': 'Rentang Ukur',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.micrometer.kapasitas_mm',
            'label': 'Kapasitas Max.',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'mm',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.micrometer.resolusi_mm',
            'label': 'Resolusi Alat',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'mm',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_terima',
            'label': 'Tgl. Diterima',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_kalibrasi',
            'label': 'Tgl. Kalibrasi',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_awal',
            'label': 'Suhu Ruangan — awal',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_akhir',
            'label': 'Suhu Ruangan — akhir',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_awal',
            'label': 'Kelembapan — awal',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_akhir',
            'label': 'Kelembapan — akhir',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'lokasi',
            'label': 'Lokasi Kalibrasi',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {'nilai': 'lab', 'label': 'Inlab'},
              {'nilai': 'onsite', 'label': 'Insitu'},
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'room_id',
            'label': 'Ruangan (Inlab)',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_ruangan',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': {
              'kode': 'lokasi',
              'nilai': ['lab'],
            },
          },
          {
            'kode': 'lokasi_nama',
            'label': 'Nama Tempat (Insitu)',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': {
              'kode': 'lokasi',
              'nilai': ['onsite'],
            },
          },
          {
            'kode': 'thermohygro_standard_id',
            'label': 'Environmental Meter Used',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_thermohygro',
            'satuan': null,
            'pilihan': [
              {'nilai': '1', 'label': 'TH-1', 'grup': 'Thermohygro lab'},
              {'nilai': '2', 'label': 'TH-2', 'grup': 'Thermohygro lab'},
              {'nilai': '3', 'label': 'TH-3', 'grup': 'Thermohygro lab'},
              {'nilai': '4', 'label': 'TH-4', 'grup': 'Thermohygro lab'},
              {'nilai': '5', 'label': 'TH-5', 'grup': 'Thermohygro lab'},
              {'nilai': '6', 'label': 'TH-6', 'grup': 'Thermohygro lab'},
              {'nilai': '7', 'label': 'TH-7', 'grup': 'Thermohygro lab'},
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'pemilik',
        'halaman': 1,
        'judul': 'Data Customer',
        'field': [
          {
            'kode': 'pemilik_nama',
            'label': 'Nama Customer',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'pemilik_alamat',
            'label': 'Alamat Customer',
            'tipe': 'teks_panjang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'nomor_order',
            'label': 'Order Number',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'usage_check',
        'halaman': 1,
        'judul': 'Standard Used',
        'baris': [
          {
            'label': 'Gauge Block Standard/Metrology/GB-9122-0',
            'standard_id': 60,
            'serial_number': '160006',
            'no_sertifikat': '160006',
            'tertelusur_ke': 'LK-410-IDN',
            'terdaftar': true,
          },
        ],
        'field': [
          {
            'kode': 'standar_dicek.*.dipakai',
            'label': 'Usage Check',
            'tipe': 'centang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'standar_dicek.*.keterangan',
            'label': 'Keterangan',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'hasil',
        'halaman': 1,
        'judul': 'Data Kalibrasi',
        'field': const [],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'mikro_pembacaan',
            'judul': 'Pembacaan Alat',
            'satuan': 'mm',
            'judul_nilai': 'Nominal Balok Ukur',
            'judul_pengulangan': 'Pembacaan Alat',
            'titik_bisa_diubah': false,
            'baris': [
              {'nomor': 1, 'titik_ukur': 25, 'label': '25', 'satuan': 'mm'},
              {'nomor': 2, 'titik_ukur': 27.5, 'label': '27,5', 'satuan': 'mm'},
              {'nomor': 3, 'titik_ukur': 31, 'label': '31', 'satuan': 'mm'},
              {'nomor': 4, 'titik_ukur': 32.7, 'label': '32,7', 'satuan': 'mm'},
              {'nomor': 5, 'titik_ukur': 35.3, 'label': '35,3', 'satuan': 'mm'},
              {'nomor': 6, 'titik_ukur': 37.9, 'label': '37,9', 'satuan': 'mm'},
              {'nomor': 7, 'titik_ukur': 40, 'label': '40', 'satuan': 'mm'},
              {'nomor': 8, 'titik_ukur': 42.6, 'label': '42,6', 'satuan': 'mm'},
              {'nomor': 9, 'titik_ukur': 45.2, 'label': '45,2', 'satuan': 'mm'},
              {
                'nomor': 10,
                'titik_ukur': 47.8,
                'label': '47,8',
                'satuan': 'mm',
              },
              {'nomor': 11, 'titik_ukur': 50, 'label': '50', 'satuan': 'mm'},
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'mm',
              },
            ],
            'pengulangan': [1, 2, 3, 4, 5],
          },
        ],
      },
      {
        'kode': 'evaluasi',
        'halaman': 1,
        'judul': 'Evaluasi',
        'field': const [],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'pra_pembacaan',
            'judul': 'Evaluasi (pembacaan berulang)',
            'satuan': 'mm',
            'judul_nilai': 'Evaluasi',
            'judul_pengulangan': 'Pembacaan',
            'titik_bisa_diubah': false,
            'offset_kunci': 1000,
            'simpan_ke': 'spesifikasi_alat.micrometer.pra_evaluasi',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'Evaluasi',
                'satuan': 'mm',
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'mm',
              },
            ],
            'pengulangan': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          },
        ],
      },
      {
        'kode': 'penutup',
        'halaman': 1,
        'judul': 'Catatan & Tanda Tangan',
        'field': [
          {
            'kode': 'catatan_teknisi',
            'label': 'Catatan',
            'tipe': 'teks_panjang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'teknisi.nama',
            'label': 'Dikalibrasi Oleh',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'reviewer.nama',
            'label': 'Diperiksa Oleh',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
    ],
    'alat_baru': {'kategori': 'panjang', 'nama_alat_kemampuan': 'Micrometer'},
    'pindai_foto': {
      'kolom_suhu': false,
      'standar_di_baris': false,
      'didukung': false,
      'lokal': true,
    },
  };
}


/// Bentuk lembar kerja contoh **Height Gauge 600 mm** (kelompok Panjang, alat
/// ke-26).
///
/// Salinan APA ADANYA dari respons
/// `GET /api/calibrations/lembar-kerja?equipment_id=…` untuk alat contoh
/// `1610232804` (Height Gauge Insize Digital, kapasitas 600 mm, resolusi
/// 0,01 mm) — sesi `001-UBLK-05.26` yang ter-seed di backend. Digenerate dari
/// JSON-nya, bukan disusun ulang di sini.
///
/// ## Yang beda dari Micrometer di atas, dan kenapa itu penting
///
/// Keduanya kelompok Panjang dan sama-sama bertitik pra-cetak, jadi gampang
/// disangka kembar. Empat hal membedakannya, dan tiga di antaranya menggerakkan
/// angka:
///
///  1. **TIGA tabel, bukan dua.** Selain `hasil` (10 titik x 3 pembacaan) dan
///     `evaluasi` (10 pembacaan berulang), ada `paralelisme` (1 baris x 3).
///     Ketiganya ber-`tahap` sama, jadi `evaluasi` dan `paralelisme` dipisah
///     `offset_kunci` **1000 dan 2000** — dua angka yang berbeda. Micrometer
///     cuma butuh satu offset karena tabelnya cuma dua.
///  2. **`paralelisme` SELALU mm**, tidak ikut dropdown satuan. Dia dibaca pada
///     Dial Indicator standar (resolusi 0,001 mm), dan batas kelulusannya
///     (<= 0,01 mm) ditulis dalam mm. Menyeretnya ikut satuan alat bikin sesi
///     `inch` mengubah 0,002 jadi 0,0508 mm -> hasilnya lewat batas -> kaki
///     sertifikat mencetak **"Not Good" palsu**. `evaluasi` dan `hasil` yang
///     ikut satuan alat.
///  3. **Tidak ada `nomor_lingkup`, dan `kode_dokumen` null.** Height Gauge di
///     LUAR lampiran akreditasi LK-285-IDN, jadi kop lembarnya tidak boleh
///     mencetak nomor lingkup; dan kertas lembar kerjanya sendiri belum turun
///     dari lab. Jangan menambahkan keduanya di sisi HP.
///  4. **Tidak ada lantai CMC.** Di Micrometer, komponen budget yang hilang
///     mendarat di lantai CMC dan hasilnya masih di atas kemampuan
///     terakreditasi — salah, tapi tertampung. Di sini tidak ada yang
///     menampung **maupun** menahan: U95 langsung terbit terlalu kecil, tanpa
///     satu pun angka yang terlihat ganjil.
///
/// Karena nomor 4 itu, dropdown `spesifikasi_alat.height_gauge.satuan` dan
/// kotak `…resolusi_mm` WAJIB masuk `_kodePenentuAngka` di
/// `lembar_kerja_state.dart` — satuan yang kelupaan dipilih jatuh ke `mm` di
/// server dan sesi berskala inch salah 25,4x.
///
/// Field khas lembar ini: `spesifikasi_alat.height_gauge.kerataan_muka_ukur`,
/// SATU dropdown (`baik`/`buruk`) — bukan dua checkbox. Master lab memakai dua
/// checkbox dan di sesi contohnya **dua-duanya tercentang sekaligus**, tanpa
/// satu pun sel memprotes.
Map<String, dynamic> contohBentukLembarKerjaHeightGauge({
  bool untukAdmin = false,
}) {
  return {
    'kode_dokumen': null,
    'kode_metode': 'SIDIK-IK-CAL-0539_Rev.0',
    'judul': 'Calibration Work Sheet - Height Gauge',
    'jumlah_pengulangan': 3,
    'satuan': 'mm',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian': 'Isi SATUAN alat lebih dulu — dia yang mengubah pembacaan dan blok Evaluation ke mm. Nominalnya SUDAH DIPATOK Instruksi Kerja (sepuluh titik, 25..600 mm) dan tidak bisa diubah. Blok Evaluation WAJIB diisi sepuluh-duanya: dari situ ketidakpastian keterulangan lahir, bukan dari tiga pembacaan tiap titik — dan alat ini tidak punya lantai CMC yang menampungnya kalau blok itu kosong. Paralelisme dibaca pada Dial Indicator standar (resolusi 0,001 mm), jadi angkanya SELALU mm apa pun satuan Height Gauge-nya.',
    'budget_ketidakpastian': {
      'tersedia': true,
      'sumber': 'Master_olda_Height_Gauge_600_mm_2026.xlsm',
      'catatan': 'Sembilan komponen tingkat-SESI dalam mm (bukan µm). TANPA lantai CMC — Height Gauge di luar lampiran akreditasi LK-285-IDN, dan sel lantai masternya (`AA19`) memang kosong. Sesi yang blok Evaluation-nya kurang dari dua pembacaan, sepuluh-duanya identik, atau resolusinya kosong TIDAK diterbitkan.',
    },
    'bagian': [
      {
        'kode': 'identitas_alat',
        'halaman': 1,
        'judul': 'Identitas Alat dan Data Customer',
        'field': [
          {
            'kode': 'equipment_id',
            'label': 'Nama Alat',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_alat',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'equipment.nama_alat',
            'label': 'Nama Alat',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_merk',
            'label': 'Merk',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_model',
            'label': 'Type',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_serial_number',
            'label': 'No. Seri',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.height_gauge.satuan',
            'label': 'Satuan Alat',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'mm',
                'label': 'mm',
              },
              {
                'nilai': 'inch',
                'label': 'inch',
              },
              {
                'nilai': 'µm',
                'label': 'µm',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.rentang_ukur',
            'label': 'Rentang Ukur',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.height_gauge.kapasitas_mm',
            'label': 'Kapasitas Max.',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'mm',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.height_gauge.resolusi_mm',
            'label': 'Resolusi Alat',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'mm',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_terima',
            'label': 'Tgl. Diterima',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_kalibrasi',
            'label': 'Tgl. Kalibrasi',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_awal',
            'label': 'Suhu Ruangan — awal',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_akhir',
            'label': 'Suhu Ruangan — akhir',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_awal',
            'label': 'Kelembapan — awal',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_akhir',
            'label': 'Kelembapan — akhir',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.height_gauge.kerataan_muka_ukur',
            'label': 'Kerataan Muka Ukur',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'baik',
                'label': 'Baik (Good)',
              },
              {
                'nilai': 'buruk',
                'label': 'Buruk (Not Good)',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'lokasi',
            'label': 'Lokasi Kalibrasi',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'lab',
                'label': 'Inlab',
              },
              {
                'nilai': 'onsite',
                'label': 'Insitu',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'room_id',
            'label': 'Ruangan (Inlab)',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_ruangan',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': {
              'kode': 'lokasi',
              'nilai': [
                'lab',
              ],
            },
          },
          {
            'kode': 'lokasi_nama',
            'label': 'Nama Tempat (Insitu)',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': {
              'kode': 'lokasi',
              'nilai': [
                'onsite',
              ],
            },
          },
          {
            'kode': 'thermohygro_standard_id',
            'label': 'Environmental Meter Used',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_thermohygro',
            'satuan': null,
            'pilihan': [
              {
                'nilai': '1',
                'label': 'TH-1',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '2',
                'label': 'TH-2',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '3',
                'label': 'TH-3',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '4',
                'label': 'TH-4',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '5',
                'label': 'TH-5',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '6',
                'label': 'TH-6',
                'grup': 'Thermohygro lab',
              },
              {
                'nilai': '7',
                'label': 'TH-7',
                'grup': 'Thermohygro lab',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'pemilik',
        'halaman': 1,
        'judul': 'Data Customer',
        'field': [
          {
            'kode': 'pemilik_nama',
            'label': 'Nama Customer',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'pemilik_alamat',
            'label': 'Alamat Customer',
            'tipe': 'teks_panjang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'nomor_order',
            'label': 'Order Number',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'usage_check',
        'halaman': 1,
        'judul': 'Standard Used',
        'baris': [
          {
            'label': 'Caliper Checker/Metrology/CMG-9060C',
            'standard_id': 61,
            'serial_number': '800035',
            'no_sertifikat': '800035',
            'tertelusur_ke': 'LK-404-IDN',
            'terdaftar': true,
          },
        ],
        'field': [
          {
            'kode': 'standar_dicek.*.dipakai',
            'label': 'Usage Check',
            'tipe': 'centang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'standar_dicek.*.keterangan',
            'label': 'Keterangan',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'paralelisme',
        'halaman': 1,
        'judul': 'Paralelisme Ujung Scriber',
        'field': const [],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'paralelisme',
            'judul': 'Pengukuran Paralelisme (Dial Indicator, res. 0,001 mm)',
            'satuan': 'mm',
            'judul_nilai': 'Paralelisme',
            'judul_pengulangan': 'Pembacaan',
            'titik_bisa_diubah': false,
            'offset_kunci': 2000,
            'simpan_ke': 'spesifikasi_alat.height_gauge.paralelisme',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'Paralelisme',
                'satuan': 'mm',
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'mm',
              },
            ],
            'pengulangan': [
              1,
              2,
              3,
            ],
          },
        ],
      },
      {
        'kode': 'evaluasi',
        'halaman': 1,
        'judul': 'Evaluation',
        'field': const [],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'pra_pembacaan',
            'judul': 'Evaluation (pembacaan berulang di kapasitas)',
            'satuan': 'mm',
            'judul_nilai': 'Evaluation',
            'judul_pengulangan': 'Pembacaan',
            'titik_bisa_diubah': false,
            'offset_kunci': 1000,
            'simpan_ke': 'spesifikasi_alat.height_gauge.pra_evaluasi',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'Evaluation',
                'satuan': 'mm',
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'mm',
              },
            ],
            'pengulangan': [
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
            ],
          },
        ],
      },
      {
        'kode': 'hasil',
        'halaman': 1,
        'judul': 'Measurement',
        'field': const [],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'hg_pembacaan',
            'judul': 'Pembacaan Alat',
            'satuan': 'mm',
            'judul_nilai': 'Nominal Step Gauge',
            'judul_pengulangan': 'Pembacaan Alat',
            'titik_bisa_diubah': false,
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': 25,
                'label': '25',
                'satuan': 'mm',
              },
              {
                'nomor': 2,
                'titik_ukur': 50,
                'label': '50',
                'satuan': 'mm',
              },
              {
                'nomor': 3,
                'titik_ukur': 100,
                'label': '100',
                'satuan': 'mm',
              },
              {
                'nomor': 4,
                'titik_ukur': 150,
                'label': '150',
                'satuan': 'mm',
              },
              {
                'nomor': 5,
                'titik_ukur': 200,
                'label': '200',
                'satuan': 'mm',
              },
              {
                'nomor': 6,
                'titik_ukur': 300,
                'label': '300',
                'satuan': 'mm',
              },
              {
                'nomor': 7,
                'titik_ukur': 400,
                'label': '400',
                'satuan': 'mm',
              },
              {
                'nomor': 8,
                'titik_ukur': 500,
                'label': '500',
                'satuan': 'mm',
              },
              {
                'nomor': 9,
                'titik_ukur': 550,
                'label': '550',
                'satuan': 'mm',
              },
              {
                'nomor': 10,
                'titik_ukur': 600,
                'label': '600',
                'satuan': 'mm',
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'mm',
              },
            ],
            'pengulangan': [
              1,
              2,
              3,
            ],
          },
        ],
      },
      {
        'kode': 'penutup',
        'halaman': 1,
        'judul': 'Catatan & Tanda Tangan',
        'field': [
          {
            'kode': 'catatan_teknisi',
            'label': 'Catatan',
            'tipe': 'teks_panjang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'teknisi.nama',
            'label': 'Dikalibrasi Oleh',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'reviewer.nama',
            'label': 'Diperiksa Oleh',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': const [],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
    ],
  };
}
