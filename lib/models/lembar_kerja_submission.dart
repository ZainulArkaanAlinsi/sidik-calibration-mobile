import 'calibration_draft.dart' show LokasiKalibrasi;

/// Satu baris tabel hasil siap kirim: satu titik ukur dengan pembacaan
/// Repeat 1..n untuk **dua tahap** sekaligus (before & after adjustment).
///
/// Sel kosong disimpen sebagai `null` di list, **bukan dibuang**. Itu bukan
/// detail teknis: kalau Repeat 2 kosong lalu dibuang, Repeat 3 naik jadi
/// Repeat 2 dan seluruh nomor pengulangannya geser — angka yang nyampe
/// sertifikat jadi ngaku-ngaku diambil di urutan yang salah. Backend yang
/// nyaring null-nya waktu ngitung.
class TitikLembarKerja {
  TitikLembarKerja({
    required this.titikUkur,
    required this.jumlahPengulangan,
    this.standardId,
    this.satuan,
  }) : pembacaan = List<double?>.filled(jumlahPengulangan, null),
       suhu = List<double?>.filled(jumlahPengulangan, null),
       pembacaanSebelum = List<double?>.filled(jumlahPengulangan, null),
       suhuSebelum = List<double?>.filled(jumlahPengulangan, null);

  final double titikUkur;
  final int jumlahPengulangan;

  /// Standar buffer khusus titik ini (pH butuh buffer 4/7/10 yang beda-beda).
  /// `null` = ikut `standard_id` sesi.
  int? standardId;

  final String? satuan;

  /// After adjustment — ini yang dihitung backend.
  final List<double?> pembacaan;
  final List<double?> suhu;

  /// Before adjustment (as-found) — dokumentasi kondisi alat, nggak ikut GUM.
  final List<double?> pembacaanSebelum;
  final List<double?> suhuSebelum;

  /// Baris yang sama sekali belum disentuh. Dipakai buat mutusin baris ini
  /// perlu ikut dikirim apa nggak — bukan buat nahan tombol kirim.
  bool get kosongSemua =>
      pembacaan.every((n) => n == null) &&
      suhu.every((n) => n == null) &&
      pembacaanSebelum.every((n) => n == null) &&
      suhuSebelum.every((n) => n == null);

  Map<String, dynamic> toJson() => {
    'titik_ukur': titikUkur,
    if (satuan != null) 'satuan': satuan,
    if (standardId != null) 'standard_id': standardId,
    // Empat list ini SELALU dikirim penuh sepanjang jumlah pengulangan,
    // termasuk null-nya. Lihat docblock kelas.
    'pembacaan': pembacaan,
    'suhu': suhu,
    'pembacaan_sebelum': pembacaanSebelum,
    'suhu_sebelum': suhuSebelum,
  };
}

/// Dari mana angka di lembar kerja ini datang — nilainya persis yang diterima
/// backend (`CalibrationRequest`: `manual|ocr|ai_vision`).
///
/// Ini catatan asal-usul, bukan hiasan: kalau ada angka sertifikat yang
/// kelihatan meleset, pertanyaan pertamanya selalu "ini diketik teknisi atau
/// hasil baca mesin?". Sebelum ini semua sesi kecatat `manual`, termasuk yang
/// tabelnya diisi dari foto — jawabannya cuma bisa dicari di log server, dan
/// log-nya nggak selamanya ada.
///
/// [aiVision] disimpen walau jalur AI-nya udah dicabut dari aplikasi: sesi lama
/// di database masih bernilai itu, dan enum yang nggak kenal nilainya bikin
/// riwayat gagal dibaca.
enum MetodeInput {
  manual('manual'),

  /// Angkanya masuk lewat pindai lembar kerja (OCR on-device) yang disetujui
  /// teknisi di layar review.
  ocr('ocr'),

  aiVision('ai_vision');

  const MetodeInput(this.api);

  final String api;
}

/// Satu baris "Usage Check": standar mana yang dicentang teknisi.
class StandarDicek {
  const StandarDicek({
    required this.standardId,
    required this.dipakai,
    this.keterangan,
  });

  final int standardId;
  final bool dipakai;
  final String? keterangan;

  Map<String, dynamic> toJson() => {
    'standard_id': standardId,
    'dipakai': dipakai,
    if (keterangan != null && keterangan!.trim().isNotEmpty)
      'keterangan': keterangan!.trim(),
  };
}

/// Body `POST /api/calibrations` & `PUT /api/calibrations/{id}` dari layar
/// lembar kerja.
///
/// Beda dari `CalibrationDraft` yang lama: di sini **nggak ada satu pun field
/// yang wajib** selain alat, dan semua yang kosong dikirim sebagai null.
/// Tombol kirim di layar nggak pernah dikunci — penjagaannya ada di penerbitan
/// sertifikat (validasi admin), bukan di formulirnya.
class LembarKerjaSubmission {
  const LembarKerjaSubmission({
    required this.equipmentId,
    required this.clientRequestId,
    required this.simpanSebagaiDraft,
    this.standardId,
    this.roomId,
    this.lokasi = LokasiKalibrasi.lab,
    this.lokasiNama,
    this.tanggalKalibrasi,
    this.tanggalTerima,
    this.suhuAwal,
    this.suhuAkhir,
    this.kelembabanAwal,
    this.kelembabanAkhir,
    this.tekananAwal,
    this.tekananAkhir,
    this.modeKalibrasi,
    this.tipeSensor,
    this.catatanTeknisi,
    this.thermohygroStandardId,
    this.alatModel,
    this.alatSerialNumber,
    this.alatMerk,
    this.pemilikNama,
    this.pemilikAlamat,
    this.equipmentSatuan,
    this.standarDicek = const [],
    this.spesifikasiAlat = const {},
    this.measurements = const [],
    this.measurementsGrid,
    this.sertakanMeasurements = true,
    this.inputMethod = MetodeInput.manual,
  });

  final int equipmentId;

  /// UUID yang dibikin **sekali per submit**. Kalau sinyal putus pas nunggu
  /// respons dan mobile retry dengan UUID yang sama, backend balikin sesi yang
  /// udah ada — bukan bikin sesi dobel buat satu kejadian kalibrasi.
  final String clientRequestId;

  /// `true` → `status: "draft"` (tersimpan, belum masuk antrean admin, tanggal
  /// boleh kosong). `false` → `menunggu_approval`.
  final bool simpanSebagaiDraft;

  final int? standardId;
  final int? roomId;
  final LokasiKalibrasi lokasi;
  final DateTime? tanggalKalibrasi;
  final DateTime? tanggalTerima;
  final double? suhuAwal;
  final double? suhuAkhir;
  final double? kelembabanAwal;
  final double? kelembabanAkhir;

  /// Tekanan udara ruangan, awal & akhir kerja (hPa).
  ///
  /// Cuma Gas Detector yang punya kolom ini, dan buat dia kolomnya BUKAN
  /// pelengkap: komponen suhu & tekanan di budget ketidakpastiannya lahir dari
  /// PERGESERAN ruangan selama sesi (Δ = |akhir − awal|), jadi tanpa dua angka
  /// ini U95-nya keluar lebih kecil dari yang sebenarnya bisa
  /// dipertanggungjawabkan.
  ///
  /// `null` buat delapan alat lain — lembarnya nggak punya kolomnya, dan
  /// `toJson` di bawah nggak mengirim kunci yang nilainya null.
  final double? tekananAwal;
  final double? tekananAkhir;
  /// Mode kalibrasi TITS — `measure` atau `source`. Null buat sepuluh alat
  /// lain, yang lembarnya nggak punya kotak ini.
  ///
  /// Bukan catatan: arah perhitungan koreksi BERBALIK antara dua mode, dan
  /// tanpa ini backend nolak ngitung seluruh titiknya ketimbang nebak. Kolom
  /// ini punya SESI, bukan alat — satu indikator dikalibrasi dua kali dengan
  /// dua nomor sertifikat.
  final String? modeKalibrasi;

  /// Tipe sensor yang disimulasikan kalibrator — `Type K`/`Type N`/`RTD`/dst.
  ///
  /// Nentuin tabel koreksi kalibrator, drift-nya, dan baris CMC mana yang
  /// dipakai. Null buat alat selain TITS.
  final String? tipeSensor;

  final String? catatanTeknisi;

  /// "6. Thermohygro used" — unit yang dipakai nyatet kondisi ruang. Diisi
  /// TEKNISI (dia yang tau unit mana yang kebawa ke lokasi), bukan admin.
  final int? thermohygroStandardId;

  /// Identitas alat & pemilik seperti yang DIBACA teknisi dari badan alat dan
  /// surat jalan — poin 3-5 & OWNER 1-2 di lembar kerja.
  ///
  /// Sengaja dikirim terpisah dari data master alat: master diisi admin waktu
  /// alat didaftarkan dan bisa udah nggak cocok sama unit fisik yang beneran
  /// datang. Sertifikat mengutamakan angka-angka di sini, master cuma cadangan.
  final String? alatModel;
  final String? alatSerialNumber;
  final String? alatMerk;
  final String? pemilikNama;
  final String? pemilikAlamat;

  /// Satuan yang dipilih teknisi di "7. Satuan Refracto" — `n20D` atau `°Brix`.
  ///
  /// **Null buat alat yang lembar kerjanya nggak punya kolom itu**, dan itu
  /// bukan kelalaian: backend nyimpen nilai ini ke `equipments.satuan`, jadi
  /// ngirimnya terus-terusan bikin tiap kiriman lembar kerja nulis ulang data
  /// master alat — pH Meter bakal ngeset satuan alatnya jadi "pH" tiap sesi,
  /// diam-diam, tanpa ada yang minta.
  ///
  /// Kenapa perlu dikirim sama sekali: `RefractometerProfile` di backend baca
  /// `equipments.satuan` buat milih koefisien suhu (0,00045/°C buat n20D vs
  /// 0,07/°C buat °Brix) dan komponen CMC-nya. Tanpa kolom ini, teknisi yang
  /// mindahin alatnya ke skala °Brix cuma keubah label pembacaannya —
  /// koreksinya tetap dihitung pakai koefisien n20D, meleset 155 kali, dan
  /// nggak ada satu pun yang error.
  final String? equipmentSatuan;

  /// Rentang ukur / kapasitas / resolusi yang DIBACA teknisi dari badan alat.
  ///
  /// Kuncinya datang dari bentuk lembar kerja (`spesifikasi_alat.<kunci>`),
  /// bukan dikarang di sini: alat berikutnya bisa punya baris yang beda, dan
  /// HP nggak boleh jadi tempat kedua yang nyimpen daftar itu.
  ///
  /// Nilainya TEKS apa adanya (`0-100`, `0,001`) — yang tercetak di sertifikat
  /// juga teks, bukan hasil hitung, dan `0-100` emang bukan angka.
  final Map<String, String> spesifikasiAlat;

  /// Nama tempat kalibrasi buat sesi `onsite`, mis. `PT. LDC`.
  final String? lokasiNama;

  final List<StandarDicek> standarDicek;
  final List<TitikLembarKerja> measurements;

  /// `measurements` buat lembar ber-GRID (Enclosure), sudah berbentuk JSON.
  ///
  /// Bentuknya beda sama sepuluh alat lain dan nggak muat di
  /// [TitikLembarKerja]: satu entri di sini bukan satu deret pembacaan, tapi
  /// satu SET POINT yang isinya daftar termokopel (`sensor_grid`) plus baris
  /// `indikator`. Dipaksa lewat [TitikLembarKerja] berarti nambah empat list
  /// yang selamanya null buat sebelas alat, cuma supaya satu alat kebagian
  /// bentuk yang bukan bentuknya.
  ///
  /// Kalau keisi, ini yang dikirim dan [measurements] diabaikan.
  final List<Map<String, dynamic>>? measurementsGrid;

  /// `false` → kunci `measurements` **nggak ikut dikirim sama sekali**, dan
  /// backend cuma memperbarui bagian header tanpa ngehapus pengukuran yang
  /// udah kecatat. Dipakai waktu teknisi cuma ngerapiin identitas/kondisi
  /// lingkungan di draft yang tabelnya udah keisi.
  final bool sertakanMeasurements;

  /// Lihat [MetodeInput]. Bawaannya `manual` — sesi yang tabelnya nggak pernah
  /// disentuh foto tetap kecatat sama kayak sebelumnya.
  final MetodeInput inputMethod;

  static String _tanggal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'equipment_id': equipmentId,
    'client_request_id': clientRequestId,
    'input_method': inputMethod.api,
    'lokasi': lokasi.toApi(),
    // Nama tempat buat sesi Insitu — yang tercetak `Insitu (PT. LDC)` di
    // sertifikat. Dikirim eksplisit (termasuk null) biar `PUT` bisa
    // ngosongin waktu sesinya dipindah balik ke lab.
    'lokasi_nama': lokasiNama,
    'status': simpanSebagaiDraft ? 'draft' : 'menunggu_approval',

    // Tanggal dikirim sebagai tanggal lokal (YYYY-MM-DD), bukan ISO UTC.
    // Kalibrasi jam 8 pagi WIB kalau dikonversi ke UTC mundur ke hari
    // sebelumnya — dan backend punya aturan `before_or_equal:today`, jadi
    // tanggal hari ini bisa lolos/ketolak tergantung jam. Ini tanggal
    // kalender, bukan titik waktu.
    'tanggal_kalibrasi': tanggalKalibrasi == null
        ? null
        : _tanggal(tanggalKalibrasi!),
    'tanggal_terima': tanggalTerima == null ? null : _tanggal(tanggalTerima!),

    // Semua di bawah ini boleh null — itu bentuk sahnya "belum diisi di
    // lapangan", bukan error. Sengaja dikirim eksplisit (bukan dihilangkan
    // kuncinya) supaya PUT bisa MENGOSONGKAN kolom yang tadinya keisi.
    'standard_id': standardId,
    'room_id': roomId,
    'thermohygro_standard_id': thermohygroStandardId,
    'suhu_awal': suhuAwal,
    'suhu_akhir': suhuAkhir,
    'kelembaban_awal': kelembabanAwal,
    'kelembaban_akhir': kelembabanAkhir,
    'tekanan_awal': tekananAwal,
    'tekanan_akhir': tekananAkhir,
    'mode_kalibrasi': modeKalibrasi,
    'tipe_sensor': tipeSensor,
    'catatan_teknisi': catatanTeknisi?.trim(),
    'alat_model': alatModel?.trim(),
    'alat_serial_number': alatSerialNumber?.trim(),
    'alat_merk': alatMerk?.trim(),
    'pemilik_nama': pemilikNama?.trim(),
    'pemilik_alamat': pemilikAlamat?.trim(),

    // Satu-satunya kolom di blok ini yang kuncinya DIHILANGKAN waktu null,
    // bukan dikirim eksplisit. Aturan "kirim null biar PUT bisa mengosongkan"
    // di atas berlaku buat kolom milik sesi; yang ini nulis ke data MASTER
    // alat, dan "kosongin satuan alatnya" nggak pernah jadi maksud teknisi
    // waktu dia ngirim lembar kerja yang kebetulan nggak punya kolom itu.
    if (equipmentSatuan != null) 'equipment_satuan': equipmentSatuan,

    if (spesifikasiAlat.isNotEmpty) 'spesifikasi_alat': spesifikasiAlat,

    'standar_dicek': standarDicek.map((s) => s.toJson()).toList(),

    if (sertakanMeasurements)
      'measurements':
          measurementsGrid ?? measurements.map((m) => m.toJson()).toList(),
  };
}
