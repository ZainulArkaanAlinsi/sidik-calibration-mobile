/// Order kalibrasi — satu pengiriman alat dari pelanggan.
///
/// Bentuknya `orders ──1:N── order_items ──0:N── calibration_sessions`:
/// sesi kalibrasi lahir belakangan, pas teknisi mulai ngerjain.
class OrderKalibrasi {
  const OrderKalibrasi({
    required this.id,
    required this.nomor,
    required this.status,
    required this.namaPelanggan,
    required this.jumlahAlat,
    this.tanggalMasuk,
    this.tanggalJanjiSelesai,
    this.catatan,
    this.items = const [],
  });

  final int id;
  final String nomor;
  final String status;
  final String namaPelanggan;

  /// Dikirim backend sebagai hitungan (`jumlah_alat`) di daftar, biar kartu
  /// nggak perlu muat semua item cuma buat nulis "5 alat".
  final int jumlahAlat;

  final DateTime? tanggalMasuk;
  final DateTime? tanggalJanjiSelesai;
  final String? catatan;

  /// Cuma keisi di endpoint detail (`GET /orders/{id}`). Di daftar biasanya
  /// kosong — pakai [jumlahAlat] buat ringkasannya.
  final List<OrderItem> items;

  /// Janji selesai udah lewat dan ordernya belum kelar. Dipakai buat nyorot
  /// baris yang perlu didahulukan.
  bool get telat {
    final janji = tanggalJanjiSelesai;
    if (janji == null || status == 'selesai') return false;
    return janji.isBefore(DateTime.now());
  }

  factory OrderKalibrasi.fromJson(Map<String, dynamic> json) {
    DateTime? tanggal(String key) {
      final nilai = json[key];
      return nilai == null ? null : DateTime.tryParse(nilai.toString());
    }

    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;

    return OrderKalibrasi(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nomor: json['nomor']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      namaPelanggan: pelanggan?['nama']?.toString() ?? '',
      jumlahAlat:
          (json['jumlah_alat'] as num?)?.toInt() ??
          (json['items'] as List<dynamic>?)?.length ??
          0,
      tanggalMasuk: tanggal('tanggal_masuk'),
      tanggalJanjiSelesai: tanggal('tanggal_janji_selesai'),
      catatan: json['catatan']?.toString(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(),
    );
  }
}

/// Satu alat di dalam order.
///
/// Teknisi nempel di sini, **bukan di order**: satu pengiriman bisa campur
/// disiplin — jangka sorong dan pH meter di kardus yang sama dikerjain orang
/// beda.
///
/// [teknisiId] itu siapa yang **ditugaskan** dan boleh dioper. Beda dari
/// teknisi di sesi kalibrasi, yang nyatet siapa yang **sudah ngerjain** dan
/// kepake di sertifikat — yang itu nggak boleh berubah.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    this.teknisiId,
    this.namaTeknisi,
    this.kondisiTerima,
    this.kelengkapan,
    this.catatan,
    this.rentangUkur,
  });

  final int id;
  final String namaAlat;
  final String serialNumber;

  /// null = belum dibagi ke siapa pun.
  final int? teknisiId;
  final String? namaTeknisi;

  final String? kondisiTerima;
  final String? kelengkapan;
  final String? catatan;

  /// Format dari backend, mis. `0–14 pH`.
  final String? rentangUkur;

  bool get sudahDitugaskan => teknisiId != null;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final alat = json['alat'] as Map<String, dynamic>?;

    return OrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaAlat: alat?['nama_alat']?.toString() ?? '',
      serialNumber: alat?['serial_number']?.toString() ?? '',
      teknisiId: (teknisi?['id'] as num?)?.toInt(),
      namaTeknisi: teknisi?['nama']?.toString(),
      kondisiTerima: json['kondisi_terima']?.toString(),
      kelengkapan: json['kelengkapan']?.toString(),
      catatan: json['catatan']?.toString(),
      rentangUkur: alat?['rentang_ukur']?.toString(),
    );
  }
}
