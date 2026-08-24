/// Status siklus hidup sesi kalibrasi. Ngikutin `docs/kontrak-api.md` §4 —
/// kalau backend nambah nilai baru, tambahin di sini juga.
enum CalibrationStatus { draft, menungguApproval, disetujui, perluRevisi }

extension CalibrationStatusJson on CalibrationStatus {
  static CalibrationStatus fromJson(String value) => switch (value) {
    'draft' => CalibrationStatus.draft,
    'menunggu_approval' => CalibrationStatus.menungguApproval,
    'disetujui' => CalibrationStatus.disetujui,
    'perlu_revisi' => CalibrationStatus.perluRevisi,
    // Status yang belum dikenal dianggap draft — paling aman (nggak ngaku
    // udah disetujui padahal belum).
    _ => CalibrationStatus.draft,
  };
}

/// Keputusan hasil kalibrasi. `null` kalau sesi belum sampai titik penentu
/// (masih draft / belum ada pengukuran).
enum Keputusan { pass, fail }

/// Titik waktu dari backend → `DateTime` LOKAL. Null-aman: field-nya belum ada
/// di respons backend lama.
DateTime? _waktu(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

/// Satu baris riwayat kalibrasi — versi ringkas dari respons
/// `GET /api/calibrations` (§4 `docs/kontrak-api.md`), cuma field yang
/// dibutuhin layar Riwayat.
class CalibrationHistoryItem {
  const CalibrationHistoryItem({
    required this.id,
    required this.namaAlat,
    required this.namaTeknisi,
    this.tanggalKalibrasi,
    required this.status,
    this.profil,
    this.namaAlatKemampuan,
    this.keputusan,
    this.nomorSertifikat,
    this.catatanRevisi,
    this.certificateId,
    this.namaPelanggan,
    this.dikirimPada,
    this.diperiksaPada,
    this.diubahPada,
  });

  final int id;
  final String namaAlat;

  /// Kode profil lembar kerja sesi ini (`tits`, `conductivity_meter`, …), dari
  /// `equipment.profil`. Lihat [CalibrationDetail.profil] soal kenapa nebak
  /// dari [namaAlat] nggak cukup. Null buat respons backend lama.
  final String? profil;

  /// Nama JENIS alat menurut lampiran akreditasi (`pH Meter`, `Oven`,
  /// `Temperature Indicator tanpa Sensor`), dari `equipment.nama_alat_kemampuan`.
  ///
  /// Bedanya sama [namaAlat]: yang itu nama alat PELANGGAN dan bentuknya bebas
  /// — "pH Meter Mettler Toledo", "Turbidimeter Hach", "Visible
  /// Spectrofotometer". Buat kepala kelompok di layar Draf yang dibutuhin
  /// justru jenisnya, dan nurunin jenis dari [profil] berarti nulis tabel
  /// `ph_meter` → "pH Meter" di dalam APK — tabel yang pasti ketinggalan tiap
  /// alat baru masuk lewat `POST /api/categories/{kode}/kemampuan`.
  ///
  /// Null buat respons backend lama — layar jatuh ke [namaAlat].
  final String? namaAlatKemampuan;

  final String namaTeknisi;

  /// PT pemilik alat. Dipakai layar antrean approval buat ngelompokkin
  /// kiriman per perusahaan — admin mikirnya "beresin punya Maju Jaya dulu",
  /// bukan per teknisi. Null buat respons backend lama.
  final String? namaPelanggan;

  /// Tanggal kalender kalibrasi. **Boleh null.**
  ///
  /// Kolomnya di backend nullable sejak migrasi
  /// `2026_07_23_120300_make_tanggal_kalibrasi_nullable_on_calibration_sessions_table`
  /// — justru supaya draf boleh disimpen setengah jadi, sebelum teknisi tau
  /// alatnya bakal dikerjain kapan.
  ///
  /// Dulu dibaca `DateTime.parse(json['tanggal_kalibrasi'] as String)`. Buat
  /// draf tanpa tanggal cast-nya melempar, `parseListAman` nelen lemparannya,
  /// dan barisnya DILEWAT diam-diam: dashboard ngitung draf itu, daftar
  /// Riwayat & antrean nggak nampilinnya. Dua angka di satu app yang saling
  /// membantah, tanpa satu pun pesan error yang bisa dikejar.
  final DateTime? tanggalKalibrasi;
  final CalibrationStatus status;

  /// Cuma keisi kalau [status] `disetujui` (sesi udah dihitung backend).
  final Keputusan? keputusan;

  /// Cuma keisi kalau sertifikatnya udah terbit.
  final String? nomorSertifikat;

  /// Catatan dari admin waktu nolak sesi (`status == perluRevisi`).
  final String? catatanRevisi;

  /// `null` sesaat setelah `approve` — sertifikatnya lagi digenerate di
  /// queue backend (`docs/kontrak-api.md` §5).
  final int? certificateId;

  /// Titik waktu — **punya jam**, beda dari [tanggalKalibrasi] yang cuma
  /// tanggal kalender (kolomnya `date` di backend, jamnya nggak pernah ada).
  ///
  /// Adanya karena beberapa sesi masuk di HARI yang sama nggak bisa dibedain
  /// mana yang terbaru: yang kelihatan cuma `10 Agt 2026` berulang-ulang,
  /// padahal urutan itu yang nentuin mana yang diperiksa duluan.
  ///
  /// Null buat respons backend lama — layar jatuh ke tanggal saja.
  final DateTime? dikirimPada;

  final DateTime? diperiksaPada;

  final DateTime? diubahPada;

  /// Kapan baris ini TERAKHIR bergerak, menurut statusnya sekarang.
  ///
  /// Satu getter, bukan tiga tanggal berjejer di layar: yang dicari orang itu
  /// "mana yang paling baru", bukan riwayat lengkapnya. Sesi yang udah
  /// diperiksa dinilai dari waktu diperiksa, yang masih nunggu dari waktu
  /// dikirim, dan draft yang belum pernah dikirim dari waktu terakhir diubah.
  DateTime? get waktuTerakhir => switch (status) {
    CalibrationStatus.disetujui ||
    CalibrationStatus.perluRevisi => diperiksaPada ?? dikirimPada ?? diubahPada,
    _ => dikirimPada ?? diubahPada,
  };

  CalibrationHistoryItem copyWith({
    CalibrationStatus? status,
    Keputusan? keputusan,
    String? catatanRevisi,
    int? certificateId,
  }) => CalibrationHistoryItem(
    id: id,
    namaAlat: namaAlat,
    profil: profil,
    namaAlatKemampuan: namaAlatKemampuan,
    namaTeknisi: namaTeknisi,
    tanggalKalibrasi: tanggalKalibrasi,
    status: status ?? this.status,
    keputusan: keputusan ?? this.keputusan,
    nomorSertifikat: nomorSertifikat,
    catatanRevisi: catatanRevisi ?? this.catatanRevisi,
    certificateId: certificateId ?? this.certificateId,
    namaPelanggan: namaPelanggan,
    dikirimPada: dikirimPada,
    diperiksaPada: diperiksaPada,
    diubahPada: diubahPada,
  );

  factory CalibrationHistoryItem.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;

    // Nomor sertifikat datang BERSARANG di `sertifikat.nomor`, bukan sebagai
    // `nomor_sertifikat` di tingkat atas — kunci itu nggak ada sama sekali di
    // respons `GET /api/calibrations` (diadu ke server asli 21 Agt 2026).
    //
    // Selama ini dibaca dari tingkat atas, jadi nilainya SELALU null buat
    // setiap sesi yang sertifikatnya udah terbit. Efeknya kelihatan sebagai
    // "nomornya nggak muncul": lencana Alur Kerja jatuh ke tulisan umum
    // "Disetujui" (`sesi.nomorSertifikat ?? l10n.alurStatusDisetujui`), dan
    // baris riwayat kehilangan satu-satunya penanda yang bisa diadu ke
    // sertifikat cetak.
    //
    // Tiga model tetangga yang baca sertifikat dari respons yang sama —
    // `arsip.dart`, `folder.dart`, `calibration_detail.dart` — semuanya udah
    // baca `sertifikat['nomor']`. Yang ini ketinggalan sendirian.
    //
    // Test nggak nangkep karena `MockHistoryService` ngisi `nomorSertifikat`
    // langsung lewat konstruktor, jadi `fromJson` yang salah itu nggak pernah
    // kelewatan jalur mock.
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;

    // Sengaja `is String`, bukan `as String?`: cast masih melempar kalau suatu
    // hari kunci ini datang sebagai angka/objek — dan yang nelen lemparannya
    // `parseListAman`, persis jalur yang bikin draf ilang senyap. Nggak
    // di-`toLocal()` juga: kolomnya `date`, jamnya selalu 00:00, dan digeser
    // zona waktu bikin tanggalnya kecetak mundur sehari di Jakarta.
    final tanggal = json['tanggal_kalibrasi'];

    return CalibrationHistoryItem(
      id: (json['id'] as num).toInt(),
      namaAlat: equipment?['nama_alat'] as String? ?? '—',
      profil: equipment?['profil'] as String?,
      namaAlatKemampuan: equipment?['nama_alat_kemampuan'] as String?,
      namaTeknisi: teknisi?['nama'] as String? ?? '—',
      tanggalKalibrasi: tanggal is String ? DateTime.tryParse(tanggal) : null,
      status: CalibrationStatusJson.fromJson(json['status'] as String),
      keputusan: switch (hasil?['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      // Tingkat atas tetap dipakai sebagai cadangan: kalau suatu hari backend
      // nambahin kuncinya, yang kebaca tetap nomor yang bener — bukan null.
      nomorSertifikat:
          sertifikat?['nomor'] as String? ?? json['nomor_sertifikat'] as String?,
      catatanRevisi: json['catatan_revisi'] as String?,
      certificateId: (json['certificate_id'] as num?)?.toInt(),
      namaPelanggan:
          (json['pelanggan'] as Map<String, dynamic>?)?['nama'] as String?,
      // ISO 8601 dari backend (UTC) → dijadiin waktu LOKAL. Tanpa `toLocal()`
      // jamnya kecetak mundur 7 jam di Jakarta, dan itu justru bikin urutan
      // "yang terbaru" kelihatan salah — persis masalah yang mau dipecahin.
      dikirimPada: _waktu(json['submitted_at']),
      diperiksaPada: _waktu(json['reviewed_at']),
      diubahPada: _waktu(json['updated_at']),
    );
  }
}
