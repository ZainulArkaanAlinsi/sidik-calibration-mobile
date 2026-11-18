/// Draf lembar kerja yang diarsipkan (`GET /calibrations?diarsipkan=1`) dan
/// hasil arsipkan/pulihkan.
///
/// Sumber bentuk: `docs/perintah-frontend-crud-lengkap.md` §3.1–§3.3. Arsip
/// bukan hapus: pembacaan mentah, nomor sesi, dan hasil hitung tidak dihapus;
/// Master Data memulihkannya (sesi kembali `draft` persis seperti semula).
library;

/// Jejak pengarsipan: siapa, kapan, dan kenapa.
class JejakArsip {
  const JejakArsip({this.alasan, this.olehNama, this.pada});

  final String? alasan;
  final String? olehNama;
  final DateTime? pada;

  factory JejakArsip.fromJson(Map<String, dynamic> json) {
    final oleh = json['oleh'];
    return JejakArsip(
      alasan: json['alasan'] as String?,
      olehNama: oleh is Map ? oleh['nama'] as String? : null,
      pada: DateTime.tryParse(json['pada'] as String? ?? ''),
    );
  }
}

/// Satu draf di daftar arsip: bentuk ringkas daftar sesi + `arsip`.
class DrafArsipan {
  const DrafArsipan({
    required this.id,
    required this.status,
    this.nomorSesi,
    this.tanggalKalibrasi,
    this.namaAlat = '',
    this.nomorSeri = '',
    this.namaPelanggan = '',
    this.namaTeknisi = '',
    this.arsip = const JejakArsip(),
  });

  final int id;
  final String? nomorSesi;
  final String status;
  final DateTime? tanggalKalibrasi;
  final String namaAlat;
  final String nomorSeri;
  final String namaPelanggan;
  final String namaTeknisi;
  final JejakArsip arsip;

  factory DrafArsipan.fromJson(Map<String, dynamic> json) {
    String nama(Object? o, String kunci) =>
        o is Map ? (o[kunci] as String? ?? '') : '';

    final arsip = json['arsip'];
    return DrafArsipan(
      id: (json['id'] as num).toInt(),
      nomorSesi: json['nomor_sesi'] as String?,
      status: json['status'] as String? ?? 'draft',
      tanggalKalibrasi: DateTime.tryParse(
        json['tanggal_kalibrasi'] as String? ?? '',
      ),
      namaAlat: nama(json['equipment'], 'nama_alat'),
      nomorSeri: nama(json['equipment'], 'serial_number'),
      namaPelanggan: nama(json['pelanggan'], 'nama'),
      namaTeknisi: nama(json['teknisi'], 'nama'),
      arsip: arsip is Map
          ? JejakArsip.fromJson(Map<String, dynamic>.from(arsip))
          : const JejakArsip(),
    );
  }
}

/// Jawaban arsipkan/pulihkan: `data{id, nomor_sesi, status, diarsipkan}`.
class HasilArsipDraf {
  const HasilArsipDraf({
    required this.id,
    required this.diarsipkan,
    this.nomorSesi,
    this.arsip,
  });

  final int id;
  final String? nomorSesi;
  final bool diarsipkan;
  /// Jejak pengarsipan. Idempoten: draf yang sudah diarsipkan dijawab `200`
  /// dengan jejak LAMA (tanpa audit kedua).
  final JejakArsip? arsip;

  factory HasilArsipDraf.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    final arsip = data['arsip'];
    return HasilArsipDraf(
      id: (data['id'] as num).toInt(),
      nomorSesi: data['nomor_sesi'] as String?,
      diarsipkan: data['diarsipkan'] as bool? ?? false,
      arsip: arsip is Map
          ? JejakArsip.fromJson(Map<String, dynamic>.from(arsip))
          : null,
    );
  }
}
