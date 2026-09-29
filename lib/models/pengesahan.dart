/// Satu kartu di antrean pengesahan — `GET /pengesahan/antrean`
/// (`AntreanPengesahanResource` di repo API).
///
/// Gerbang pengesahan (keputusan 26 Sep 2026): admin "Setujui & ajukan
/// terbit" → sesi `menunggu_pengesahan` → super admin "Sahkan & terbitkan" →
/// nomor sertifikat baru dialokasikan. Kartu ini cuma cukup untuk memutuskan
/// "buka yang mana dulu"; detail lengkapnya tetap lewat layar Detail
/// Kalibrasi yang sudah ada.
class ItemPengesahan {
  const ItemPengesahan({
    required this.id,
    required this.nomorSesi,
    required this.status,
    this.keputusan,
    required this.alatNama,
    this.alatMerk,
    this.alatSerial,
    this.pelanggan,
    this.teknisiNama,
    this.teknisiKode,
    this.diperiksaOleh,
    this.diajukanOleh,
    this.tanggalKalibrasi,
    this.diajukanPada,
    this.menungguHari,
    this.catatanPengajuan,
    this.berlakuSampaiDiminta,
  });

  final int id;
  final String nomorSesi;
  final String status;

  /// `PASS` / `FAIL`. FAIL tetap sah dan tetap terbit — tapi pengesah perlu
  /// tahu SEBELUM membuka, karena itu yang paling sering perlu ditelepon ke
  /// pelanggan dulu.
  final String? keputusan;

  final String alatNama;
  final String? alatMerk;
  final String? alatSerial;
  final String? pelanggan;

  final String? teknisiNama;

  /// Inisial yang tercetak di sertifikat (mis. `RZP`) — kartu menampilkan hal
  /// yang sama dengan kertasnya.
  final String? teknisiKode;

  final String? diperiksaOleh;
  final String? diajukanOleh;
  final DateTime? tanggalKalibrasi;
  final DateTime? diajukanPada;

  /// Dihitung SERVER, bukan dari jam HP (yang di lapangan sering meleset).
  final int? menungguHari;

  final String? catatanPengajuan;
  final DateTime? berlakuSampaiDiminta;

  bool get fail => keputusan == 'FAIL';

  factory ItemPengesahan.fromJson(Map<String, dynamic> json) {
    final alat = (json['alat'] as Map<String, dynamic>?) ?? const {};
    final teknisi = (json['teknisi'] as Map<String, dynamic>?) ?? const {};

    return ItemPengesahan(
      id: json['id'] as int,
      nomorSesi: json['nomor_sesi'] as String? ?? '',
      status: json['status'] as String? ?? '',
      keputusan: json['keputusan'] as String?,
      alatNama: alat['nama'] as String? ?? '—',
      alatMerk: alat['merk'] as String?,
      alatSerial: alat['serial_number'] as String?,
      pelanggan: alat['pelanggan'] as String?,
      teknisiNama: teknisi['nama'] as String?,
      teknisiKode: teknisi['kode'] as String?,
      diperiksaOleh: json['diperiksa_oleh'] as String?,
      diajukanOleh: json['diajukan_oleh'] as String?,
      tanggalKalibrasi: DateTime.tryParse(json['tanggal_kalibrasi'] as String? ?? ''),
      diajukanPada: DateTime.tryParse(json['diajukan_pada'] as String? ?? ''),
      menungguHari: (json['menunggu_hari'] as num?)?.toInt(),
      catatanPengajuan: json['catatan_pengajuan'] as String?,
      berlakuSampaiDiminta: DateTime.tryParse(
        json['berlaku_sampai_diminta'] as String? ?? '',
      ),
    );
  }
}

/// Satu temuan pemisahan wewenang dari `PemisahanWewenang` di server.
class TemuanWewenang {
  const TemuanWewenang({required this.kode, required this.pesan});

  final String kode;
  final String pesan;

  static List<TemuanWewenang> dariBody(Map<String, dynamic> body) {
    final wewenang = body['wewenang'] as Map<String, dynamic>?;
    final temuan = wewenang?['temuan'] as List<dynamic>? ?? const [];
    return [
      for (final t in temuan.whereType<Map<String, dynamic>>())
        TemuanWewenang(
          kode: t['kode'] as String? ?? '',
          pesan: t['pesan'] as String? ?? '',
        ),
    ];
  }
}

/// Server menahan pengesahan sekali supaya peringatan pemisahan wewenang
/// DIBACA dulu (422 `butuh_konfirmasi: true`). Layar menangkap ini, menampilkan
/// temuannya, lalu mengirim ulang dengan `abaikan_peringatan: true` kalau
/// pengesahnya memang mau lanjut.
class PengesahanButuhKonfirmasi implements Exception {
  const PengesahanButuhKonfirmasi(this.pesan, this.temuan);

  final String pesan;
  final List<TemuanWewenang> temuan;

  @override
  String toString() => pesan;
}
