/// Versi ringkas alat — cuma field yang dibutuhin picker di layar Input
/// Kalibrasi (`GET /api/equipments`, `docs/kontrak-api.md` §3). Bukan model
/// penuh buat CRUD Alat (itu punya layarnya sendiri).
class EquipmentLookup {
  const EquipmentLookup({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    required this.kategori,
    required this.status,
  });

  final int id;
  final String namaAlat;
  final String serialNumber;
  final String kategori;

  /// `aktif` / `overdue` / `nonaktif`.
  final String status;

  factory EquipmentLookup.fromJson(Map<String, dynamic> json) {
    return EquipmentLookup(
      id: (json['id'] as num).toInt(),
      namaAlat: json['nama_alat'] as String,
      serialNumber: json['serial_number'] as String? ?? '',
      kategori: json['kategori'] as String? ?? '',
      status: json['status'] as String? ?? 'aktif',
    );
  }
}
