/// Satu pelanggan — `docs/kontrak-api.md` §8 (`GET/POST/PUT/DELETE
/// /api/customers`). `jumlahAlat` cuma ada di response, dipakai buat
/// nampilin peringatan waktu mau hapus.
class Customer {
  const Customer({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.contactPerson,
    required this.telepon,
    required this.email,
    this.jumlahAlat = 0,
  });

  final int id;
  final String nama;
  final String alamat;
  final String contactPerson;
  final String telepon;
  final String email;
  final int jumlahAlat;

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'alamat': alamat,
    'contact_person': contactPerson,
    'telepon': telepon,
    'email': email,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

    return Customer(
      id: (json['id'] as num).toInt(),
      nama: teks('nama'),
      alamat: teks('alamat'),
      contactPerson: teks('contact_person'),
      telepon: teks('telepon'),
      email: teks('email'),
      jumlahAlat: (json['jumlah_alat'] as num?)?.toInt() ?? 0,
    );
  }
}
