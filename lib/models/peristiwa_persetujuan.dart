/// Satu peristiwa di riwayat persetujuan sesi — dari
/// `GET /api/calibrations/{id}/riwayat-persetujuan` (khusus admin & super
/// admin, keputusan pemilik proyek 6 Okt 2026).
///
/// Kolom `catatanRevisi` di detail sesi cuma menyimpan alasan TERAKHIR. Riwayat
/// ini memuat tiap penolakan dengan alasannya masing-masing — server membacanya
/// dari jejak audit, jadi alasan lama tidak hilang walau ditimpa.
class PeristiwaPersetujuan {
  const PeristiwaPersetujuan({
    required this.jenis,
    required this.status,
    this.statusSebelumnya,
    this.waktu,
    this.olehNama,
    this.alasan,
    this.kolom = const [],
  });

  /// `diajukan`, `diajukan_ulang`, `ditolak`, `menunggu_pengesahan`,
  /// `disetujui`, `kembali_ke_draft`. Jenis yang belum dikenal app tetap
  /// ditampilkan apa adanya — server boleh menambah jenis baru.
  final String jenis;
  final String status;
  final String? statusSebelumnya;
  final DateTime? waktu;

  /// Null = perubahan oleh sistem (queue/command), bukan orang.
  final String? olehNama;

  /// Hanya di `ditolak`.
  final String? alasan;

  /// Kode kolom / kode sel yang ditandai admin saat menolak (`revisi_field`).
  final List<String> kolom;

  bool get ditolak => jenis == 'ditolak';

  factory PeristiwaPersetujuan.fromJson(Map<String, dynamic> json) {
    final oleh = json['oleh'];
    return PeristiwaPersetujuan(
      jenis: json['jenis'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusSebelumnya: json['status_sebelumnya'] as String?,
      waktu: DateTime.tryParse(json['waktu'] as String? ?? '')?.toLocal(),
      olehNama: oleh is Map ? oleh['nama'] as String? : null,
      alasan: json['alasan'] as String?,
      kolom: [
        for (final k in (json['kolom'] as List<dynamic>? ?? const []))
          if (k != null) '$k',
      ],
    );
  }
}
