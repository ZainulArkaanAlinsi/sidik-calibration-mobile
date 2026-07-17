/// Status alat. Nilainya persis kayak yang dikirim API (lihat
/// `docs/kontrak-api.md` §3): `aktif` / `overdue` / `nonaktif`.
enum EquipmentStatus {
  aktif,
  overdue,
  nonaktif;

  /// Status asing dari backend nggak bikin app crash — dianggap `nonaktif`
  /// (paling nggak berbahaya: nggak dianggap siap pakai).
  static EquipmentStatus fromApi(String value) => switch (value) {
    'aktif' => EquipmentStatus.aktif,
    'overdue' => EquipmentStatus.overdue,
    _ => EquipmentStatus.nonaktif,
  };

  /// `overdue` dihitung backend dari `tanggal_jatuh_tempo`, nggak bisa
  /// dikirim di `POST`/`PUT` (ditolak `422`) — cuma `aktif`/`nonaktif` yang
  /// boleh diset dari mobile.
  String get apiValue => switch (this) {
    EquipmentStatus.aktif => 'aktif',
    EquipmentStatus.overdue => 'overdue',
    EquipmentStatus.nonaktif => 'nonaktif',
  };
}

/// Pelanggan pemilik alat — dikirim nested di response (`pelanggan: {...}`),
/// tapi ditulis pakai `pelanggan_id` doang waktu `POST`/`PUT`.
class EquipmentCustomer {
  const EquipmentCustomer({required this.id, required this.nama});

  final int id;
  final String nama;

  factory EquipmentCustomer.fromJson(Map<String, dynamic> json) {
    return EquipmentCustomer(
      id: json['id'] as int,
      nama: json['nama'] as String,
    );
  }
}

class Equipment {
  const Equipment({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    required this.kategori,
    required this.merk,
    required this.status,
    this.pelanggan,
    this.tanggalKalibrasiTerakhir,
    this.tanggalJatuhTempo,
    this.toleransi,
  });

  final int id;
  final String namaAlat;
  final String serialNumber;
  final String kategori;
  final String merk;
  final EquipmentStatus status;

  /// **Bisa null.** Alat yang baru ditambahin teknisi di lapangan belum
  /// tentu langsung ke-assign ke pelanggan.
  final EquipmentCustomer? pelanggan;

  final DateTime? tanggalKalibrasiTerakhir;
  final DateTime? tanggalJatuhTempo;

  /// Bonus field di luar kontrak dasar, dibutuhin buat gerbang PASS/FAIL pas
  /// layar kalibrasi nanti (`toleransi` kosong = kalibrasi ditolak backend).
  final double? toleransi;

  factory Equipment.fromJson(Map<String, dynamic> json) {
    DateTime? tanggal(String key) {
      final nilai = json[key] as String?;
      return nilai == null ? null : DateTime.parse(nilai);
    }

    final pelangganJson = json['pelanggan'] as Map<String, dynamic>?;

    return Equipment(
      id: json['id'] as int,
      namaAlat: json['nama_alat'] as String,
      serialNumber: json['serial_number'] as String,
      kategori: json['kategori'] as String,
      merk: json['merk'] as String,
      status: EquipmentStatus.fromApi(json['status'] as String),
      pelanggan: pelangganJson == null
          ? null
          : EquipmentCustomer.fromJson(pelangganJson),
      tanggalKalibrasiTerakhir: tanggal('tanggal_kalibrasi_terakhir'),
      tanggalJatuhTempo: tanggal('tanggal_jatuh_tempo'),
      toleransi: (json['toleransi'] as num?)?.toDouble(),
    );
  }

  /// Payload buat `POST`/`PUT` — beda dari bentuk response: `pelanggan_id`
  /// (bukan objek `pelanggan`), dan `status` cuma boleh `aktif`/`nonaktif`
  /// (`overdue` ditolak backend, dia yang ngitung sendiri).
  Map<String, dynamic> toJson({int? pelangganId}) {
    return {
      'nama_alat': namaAlat,
      'serial_number': serialNumber,
      'kategori': kategori,
      'merk': merk,
      'status': status.apiValue,
      'pelanggan_id': ?pelangganId,
      if (toleransi != null) 'toleransi': toleransi,
    };
  }
}
