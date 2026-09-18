/// Bentuk lembar kerja contoh **Hydrometer** (kelompok Volumetrik, alat ke-33).
///
/// DIGENERATE `docs/skrip/gen-contoh-lembar-kerja.php` di repo API — jangan
/// disunting tangan.
///
/// ## Kenapa lembar ini tidak sebangun dengan satu pun lembar lain
///
/// Tiga puluh dua lembar sebelumnya berbentuk "standar lawan pembacaan".
/// Hydrometer tidak: yang dipungut kertas `SIDIK-FM-CAL-0533_Rev.2` adalah
/// **massa hasil timbang (gram)** dan **suhu air (°C)**, masing-masing tiga
/// ulangan per titik skala — dan densitas yang dicetak sertifikat tidak pernah
/// diketik siapa pun, dia hasil metode Cuckow di server.
///
///  1. **Dua tabel yang harus SINKRON** (`simpan_ke`
///     `measurements[].hydro_massa` dan `measurements[].hydro_suhu`) — kolom
///     ke-n keduanya merujuk titik skala yang sama, dan server MENOLAK titik
///     yang cuma punya salah satunya. Digabung per POSISI baris, sama seperti
///     tiga tabel Jangka Sorong dan kelima tabel Flowmeter; `titik_ukur` tiap
///     `measurements[i]` datang dari tabel massa, yang disebut duluan.
///  2. **`offset_kunci` berbeda di ketiga tabelnya** (1000 massa, 2000 diameter
///     stem, 3000 suhu). Tanpa itu ketiganya berbagi satu `Map<double,
///     TitikState>` — `tahap`-nya sama dan `titik_ukur` bawaannya 0,0 — jadi
///     angka yang diketik di satu tabel muncul di tabel lain.
///  3. **Varian beban tambahan** (`spesifikasi_alat.hydrometer.pakai_beban_tambahan`)
///     menentukan RUMUS MANA yang dipakai, dan kotak `Sl` di bawahnya cuma
///     muncul kalau dipilih `ya` (`tampil_kalau`). Itu yang membuat "tidak
///     perlu sinker" tidak tertukar dengan "lupa mengisi sinker".
///
///     Dropdown `pilihan`, BUKAN saklar boolean: `TipeField.fromApi` cuma
///     mengenal tujuh tipe, dan tipe tak dikenal jatuh ke `TipeField.teks`
///     tanpa satu pun error — teknisi bakal melihat kotak ketikan bebas untuk
///     pertanyaan yang menentukan rumus, dan apa pun yang diketik dibaca server
///     sebagai "tidak".
///  4. **Kotak tekanan udara (hPa)** di blok identitas — tidak dimiliki lembar
///     mana pun selain Gas Detector, dan di sini WAJIB: densitas udara lahir
///     dari situ.
///  5. **Kedua tabel `titik_bisa_diubah: true`** — beda dari Micrometer & Dial
///     Indicator yang nominalnya terkunci kertas. Keduanya, bukan salah
///     satunya: titik yang ditambah teknisi hidup di satu daftar milik seluruh
///     lembar, jadi dua tabel yang sama-sama `true` tumbuh berbarengan. Batas
///     LIMA titik ditegakkan server (`CalibrationController::susunBlokHydrometer`),
///     bukan lewat kunci bentuk lembar — kontrak lembar kerja HP tidak punya
///     batas jumlah titik, dan kunci yang tidak dibaca klien bikin batasnya
///     cuma ada di atas kertas.
///  6. **Desimal per BARIS** (`desimal`: 4 massa, 1 suhu, 3 diameter stem) —
///     satu-satunya tempat kontrak ini menyatakan ketelitian kotak isian.
library;

/// Bentuk lembar kerja contoh **Hydrometer**.
///
/// Kode profil `hydrometer`, satuan `g/ml`, kertas `SIDIK-FM-CAL-0533_Rev.2`.
Map<String, dynamic> contohBentukLembarKerjaHydrometer({
  bool untukAdmin = false,
}) {
  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0533_Rev.2',
    'kode_metode': 'SIDIK-IK-CAL-0525_Rev.3',
    'nomor_lingkup': 'LK-285-IDN',
    'judul': 'Calibration Worksheet - Hydrometer',
    'jumlah_pengulangan': 3,
    'satuan': 'g/ml',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian': 'Yang diisi BUKAN pembacaan densitas: tiap titik skala diisi tiga kali timbang (gram, 4 desimal) dan tiga kali baca suhu air (°C, 1 desimal). Densitasnya dihitung server dengan metode Cuckow. Nyalakan "Pakai beban tambahan" hanya kalau hydrometer-nya memang butuh sinker — rumusnya beda, dan kosong karena tidak perlu harus bisa dibedakan dari kosong karena lupa. Tekanan udara (hPa) wajib: tanpa itu densitas udara tidak bisa dihitung.',
    'budget_ketidakpastian': {
      'tersedia': true,
      'sumber': 'Master Olah Data Hydrometer 0.600-0.650 & 1.800-2.000 (.xlsm)',
      'catatan': 'Sebelas komponen PER TITIK skala dalam g/ml, k dari t-Student (v_eff dipotong ke bawah), lantai CMC per pita densitas. Sesi yang titiknya di luar pita CMC, ulangannya bukan tiga, diameter stem-nya bukan tiga ukuran, atau tekanan udaranya kosong TIDAK diterbitkan.',
    },
    'bagian': [
      {
        'kode': 'identitas_alat',
        'halaman': 1,
        'judul': 'Equipment Identity',
        'field': [
          {
            'kode': 'equipment_id',
            'label': 'Pilih Alat',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': 'master_alat',
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'equipment.nama_alat',
            'label': 'Name',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.rentang_ukur',
            'label': 'Range',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.satuan_densitas',
            'label': 'Satuan Densitas',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'g/ml',
                'label': 'g/ml',
              },
              {
                'nilai': 'kg/m3',
                'label': 'kg/m3',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.resolusi',
            'label': 'Resolution',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'g/ml',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.suhu_acuan_faktor',
            'label': 'Temperature',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_terima',
            'label': 'Received Date',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tanggal_kalibrasi',
            'label': 'Calibration Date',
            'tipe': 'tanggal',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_model',
            'label': 'Type/Model',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_serial_number',
            'label': 'Serial Number/LPI',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'alat_merk',
            'label': 'Merk/Manufacture',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_awal',
            'label': 'Env. Condition — First (°C)',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'suhu_akhir',
            'label': 'Env. Condition — End (°C)',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_awal',
            'label': 'Env. Condition — First (%RH)',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'kelembaban_akhir',
            'label': 'Env. Condition — End (%RH)',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': '%RH',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tekanan_awal',
            'label': 'Tekanan Udara — awal',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'hPa',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'tekanan_akhir',
            'label': 'Tekanan Udara — akhir',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'hPa',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'lokasi',
            'label': 'Location',
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
            'pilihan': <dynamic>[],
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
            'pilihan': <dynamic>[],
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
            'label': 'TH Used',
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
        'judul': 'Owner',
        'field': [
          {
            'kode': 'pemilik_nama',
            'label': 'Name',
            'tipe': 'teks',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'pemilik_alamat',
            'label': 'Address',
            'tipe': 'teks_panjang',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
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
            'pilihan': <dynamic>[],
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
            'label': 'Analytical Balance Fujitsu',
            'standard_id': 76,
            'serial_number': '1129063525',
            'no_sertifikat': '1129063525',
            'tertelusur_ke': 'LK-305-IDN',
            'terdaftar': true,
          },
          {
            'label': 'Digital Caliper Tesa',
            'standard_id': 63,
            'serial_number': 'LPI-0368',
            'no_sertifikat': 'LPI-0368',
            'tertelusur_ke': 'LK-285-IDN',
            'terdaftar': true,
          },
          {
            'label': 'Temp. Kalibrator Victor',
            'standard_id': null,
            'serial_number': null,
            'no_sertifikat': null,
            'tertelusur_ke': null,
            'terdaftar': false,
          },
          {
            'label': 'RTD Sensor/SH1/20',
            'standard_id': 48,
            'serial_number': 'SH1/20',
            'no_sertifikat': 'SH1/20',
            'tertelusur_ke': 'SNSU-BSN',
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
            'pilihan': <dynamic>[],
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
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
      {
        'kode': 'pre_condition',
        'halaman': 1,
        'judul': '1. Pre Condition',
        'field': [
          {
            'kode': 'spesifikasi_alat.hydrometer.pakai_beban_tambahan',
            'label': 'Beban Tambahan (Sinker)',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'ya',
                'label': 'Pakai beban tambahan',
              },
              {
                'nilai': 'tidak',
                'label': 'Tanpa beban tambahan',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.beban_tambahan',
            'label': 'Sl — Beban Tambahan',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'g',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': {
              'kode': 'spesifikasi_alat.hydrometer.pakai_beban_tambahan',
              'nilai': [
                'ya',
              ],
            },
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.massa_udara',
            'label': 'Ma — Massa Hydrometer di Udara',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': 'g',
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.tegangan_permukaan',
            'label': 'yx — Tegangan Permukaan Hydrometer',
            'tipe': 'angka',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.satuan_tegangan',
            'label': 'Satuan Tegangan Permukaan',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': null,
            'pilihan': [
              {
                'nilai': 'dyne/cm',
                'label': 'dyne/cm',
              },
              {
                'nilai': 'mN/m',
                'label': 'mN/m',
              },
              {
                'nilai': 'N/m',
                'label': 'N/m',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'spesifikasi_alat.hydrometer.suhu_acuan_alat',
            'label': 'tr — Suhu Acuan Hydrometer',
            'tipe': 'pilihan',
            'wajib': false,
            'sumber': null,
            'satuan': '°C',
            'pilihan': [
              {
                'nilai': '15',
                'label': '15 °C',
              },
              {
                'nilai': '20',
                'label': '20 °C',
              },
              {
                'nilai': '27.5',
                'label': '27,5 °C',
              },
            ],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'hydro_diameter',
            'judul': 'D Stem (cm) — tiga kali ukur',
            'satuan': 'cm',
            'judul_nilai': 'D Stem',
            'judul_pengulangan': 'Ukur ke',
            'titik_bisa_diubah': false,
            'offset_kunci': 2000,
            'simpan_ke': 'spesifikasi_alat.hydrometer.diameter_stem',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'D Stem',
                'satuan': 'cm',
                'desimal': 3,
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Nilai',
                'tipe': 'angka',
                'satuan': 'cm',
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
        'kode': 'hasil',
        'halaman': 1,
        'judul': '2. Measurement',
        'field': <dynamic>[],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'hydro_massa',
            'offset_kunci': 1000,
            'judul': 'a. Weight — Weight of Hydrometer (gram)',
            'satuan': 'g',
            'judul_nilai': 'Point of Calibration',
            'judul_pengulangan': 'Timbang ke',
            'titik_bisa_diubah': true,
            'simpan_ke': 'measurements[].hydro_massa',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'Titik 1',
                'satuan': 'g/ml',
                'desimal': 4,
              },
              {
                'nomor': 2,
                'titik_ukur': null,
                'label': 'Titik 2',
                'satuan': 'g/ml',
                'desimal': 4,
              },
              {
                'nomor': 3,
                'titik_ukur': null,
                'label': 'Titik 3',
                'satuan': 'g/ml',
                'desimal': 4,
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Massa',
                'tipe': 'angka',
                'satuan': 'g',
              },
            ],
            'pengulangan': [
              1,
              2,
              3,
            ],
          },
          {
            'tahap': 'sesudah_adjustment',
            'grup': 'hydro_suhu',
            'offset_kunci': 3000,
            'judul': 'b. Temperature — Temperature (°C)',
            'satuan': '°C',
            'judul_nilai': 'Point of Calibration',
            'judul_pengulangan': 'Baca ke',
            'titik_bisa_diubah': true,
            'simpan_ke': 'measurements[].hydro_suhu',
            'baris': [
              {
                'nomor': 1,
                'titik_ukur': null,
                'label': 'Titik 1',
                'satuan': 'g/ml',
                'desimal': 1,
              },
              {
                'nomor': 2,
                'titik_ukur': null,
                'label': 'Titik 2',
                'satuan': 'g/ml',
                'desimal': 1,
              },
              {
                'nomor': 3,
                'titik_ukur': null,
                'label': 'Titik 3',
                'satuan': 'g/ml',
                'desimal': 1,
              },
            ],
            'kolom': [
              {
                'kode': 'pembacaan',
                'label': 'Suhu',
                'tipe': 'angka',
                'satuan': '°C',
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
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'teknisi.nama',
            'label': 'Calibrated by',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
          {
            'kode': 'reviewer.nama',
            'label': 'Checked by',
            'tipe': 'teks',
            'wajib': false,
            'sumber': 'otomatis',
            'satuan': null,
            'pilihan': <dynamic>[],
            'hanya_admin': false,
            'tampil_kalau': null,
          },
        ],
      },
    ],
  };
}
