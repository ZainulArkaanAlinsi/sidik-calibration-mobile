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

/// Satu baris riwayat kalibrasi — versi ringkas dari respons
/// `GET /api/calibrations` (§4 `docs/kontrak-api.md`), cuma field yang
/// dibutuhin layar Riwayat.
class CalibrationHistoryItem {
  const CalibrationHistoryItem({
    required this.id,
    required this.namaAlat,
    required this.namaTeknisi,
    required this.tanggalKalibrasi,
    required this.status,
    this.keputusan,
    this.nomorSertifikat,
  });

  final int id;
  final String namaAlat;
  final String namaTeknisi;
  final DateTime tanggalKalibrasi;
  final CalibrationStatus status;

  /// Cuma keisi kalau [status] `disetujui` (sesi udah dihitung backend).
  final Keputusan? keputusan;

  /// Cuma keisi kalau sertifikatnya udah terbit.
  final String? nomorSertifikat;

  factory CalibrationHistoryItem.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;

    return CalibrationHistoryItem(
      id: (json['id'] as num).toInt(),
      namaAlat: equipment?['nama_alat'] as String? ?? '—',
      namaTeknisi: teknisi?['nama'] as String? ?? '—',
      tanggalKalibrasi: DateTime.parse(json['tanggal_kalibrasi'] as String),
      status: CalibrationStatusJson.fromJson(json['status'] as String),
      keputusan: switch (hasil?['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      nomorSertifikat: json['nomor_sertifikat'] as String?,
    );
  }
}
