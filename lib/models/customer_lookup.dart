/// Pelanggan versi ringkas buat pemilih di form Alat — `id`, `nama`, `alamat`.
///
/// Beda sama [Customer] yang model penuh buat layar CRUD Pelanggan: yang ini
/// datang dari `GET /api/customers/lookup`, yang sengaja nggak ngirim
/// `contact_person`/`telepon`/`email`. Dibikin tipe sendiri (bukan maksain
/// `Customer` dengan field sisanya diisi string kosong) biar nggak ada yang
/// salah sangka data lengkapnya ada di sini — pola yang sama kayak
/// `EquipmentLookup`.
class CustomerLookup {
  const CustomerLookup({required this.id, required this.nama, this.alamat});

  /// **`customers.id`**, dan ini yang dikirim balik sebagai `pelanggan_id`
  /// waktu alatnya disimpan.
  ///
  /// Pernah BUKAN itu. Waktu daftar ini masih ditarik dari
  /// `GET /api/arsip/perusahaan`, `id` yang datang itu id **folder** — dan
  /// folder id 1 gampang milik pelanggan id 3. Alatnya kesimpen ke pelanggan
  /// yang salah tanpa satu pun error: `pelanggan_id`-nya sah, cuma nunjuk ke
  /// PT lain.
  final int id;

  final String nama;

  /// Alamat pelanggan. **Bisa null/kosong** — kolomnya boleh kosong di master.
  ///
  /// Yang bikin daftarnya kepakai, bukan cuma lengkap: satu kawasan industri
  /// isinya belasan PT bernama mirip, dan yang dipegang teknisi alamat
  /// penjemputannya.
  final String? alamat;

  factory CustomerLookup.fromJson(Map<String, dynamic> json) => CustomerLookup(
    id: (json['id'] as num).toInt(),
    nama: json['nama'] as String? ?? '',
    alamat: json['alamat'] as String?,
  );

  /// Bentuk yang sama dengan yang datang dari server.
  ///
  /// Sengaja identik supaya isi simpanan di HP bisa dibaca lewat [fromJson]
  /// yang itu-itu juga — dua bentuk yang beda tipis buat hal yang sama itu
  /// tempat lahirnya bug yang cuma muncul waktu offline, yaitu waktu yang
  /// paling nggak enak buat menemukannya.
  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'alamat': alamat};
}
