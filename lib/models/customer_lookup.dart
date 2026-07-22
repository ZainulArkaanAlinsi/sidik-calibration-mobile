/// Pelanggan versi ringkas — cuma `id` + `nama`, secukupnya buat isi dropdown.
///
/// Beda sama [Customer] yang model penuh buat layar CRUD Pelanggan: yang ini
/// datang dari `GET /api/arsip/perusahaan`, yang emang cuma ngirim dua field
/// itu. Sengaja dibikin tipe sendiri (bukan maksain `Customer` dengan alamat,
/// telepon, dsb. diisi string kosong) biar nggak ada yang salah sangka kalau
/// data lengkapnya ada di sini — pola yang sama kayak `EquipmentLookup`.
class CustomerLookup {
  const CustomerLookup({required this.id, required this.nama});

  final int id;
  final String nama;

  factory CustomerLookup.fromJson(Map<String, dynamic> json) => CustomerLookup(
    id: (json['id'] as num).toInt(),
    nama: json['nama'] as String? ?? '',
  );
}
