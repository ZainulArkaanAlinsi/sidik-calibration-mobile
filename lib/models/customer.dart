/// Pelanggan (`GET /api/customers`) — dipakai buat dropdown pencarian
/// pelanggan di form Alat. **Admin-only** di kontrak API §8; role lain nggak
/// bisa manggil endpoint ini.
class Customer {
  const Customer({required this.id, required this.nama});

  final int id;
  final String nama;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(id: json['id'] as int, nama: json['nama'] as String);
  }
}
