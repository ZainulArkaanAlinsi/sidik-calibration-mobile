/// Perbandingan isian asli teknisi lawan sekarang
/// (`GET /api/calibrations/{id}/bandingkan`, K-50-02, admin & super admin).
///
/// Parser defensif: field yang hilang jatuh ke bawaan aman, tidak melempar.
library;

class PengubahSel {
  const PengubahSel({this.id, this.nama});

  final int? id;
  final String? nama;

  static PengubahSel? dariJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final nama = raw['nama'];
    return PengubahSel(
      id: id is num ? id.toInt() : null,
      nama: nama is String && nama.isNotEmpty ? nama : null,
    );
  }
}

class SelBanding {
  const SelBanding({
    required this.kunci,
    required this.asli,
    required this.sekarang,
    required this.berubah,
    this.diubahOleh,
    this.diubahPada,
    this.alasan,
  });

  /// Pembacaan: `titik_<titik_ke>.<peran_sensor>.<tahap>.sensor_<n>.pembacaan_<n>`.
  /// Autoklaf: jalur titik di `lembar` (mis. `lembar.suhu.disk.0.0`).
  final String kunci;

  /// Angka (num) atau teks, apa adanya dari server. Tidak dibulatkan.
  final Object? asli;
  final Object? sekarang;
  final bool berubah;

  /// Hanya ada di sel yang berubah.
  final PengubahSel? diubahOleh;
  final DateTime? diubahPada;
  final String? alasan;

  static SelBanding? dariJson(Object? raw) {
    if (raw is! Map) return null;
    final kunci = raw['kunci'];
    if (kunci is! String || kunci.isEmpty) return null;
    final pada = raw['diubah_pada'];
    final alasan = raw['alasan'];
    return SelBanding(
      kunci: kunci,
      asli: raw['asli'],
      sekarang: raw['sekarang'],
      berubah: raw['berubah'] == true,
      diubahOleh: PengubahSel.dariJson(raw['diubah_oleh']),
      diubahPada: pada is String ? DateTime.tryParse(pada) : null,
      alasan: alasan is String && alasan.isNotEmpty ? alasan : null,
    );
  }
}

class Bandingkan {
  const Bandingkan({
    required this.sesiId,
    required this.status,
    required this.adaAsli,
    required this.jenis,
    required this.totalSel,
    required this.jumlahBerubah,
    required this.sel,
    this.asliDibekukanPada,
  });

  final int sesiId;
  final String status;

  /// `false` = sesi lama yang belum pernah dikoreksi: tidak ada yang berubah.
  final bool adaAsli;

  /// `pembacaan` | `autoclave`.
  final String jenis;
  final DateTime? asliDibekukanPada;
  final int totalSel;
  final int jumlahBerubah;
  final List<SelBanding> sel;

  factory Bandingkan.dariJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map ? json['data'] : json) as Map;
    int bulat(Object? v) => v is num ? v.toInt() : 0;
    final dibekukan = data['asli_dibekukan_pada'];
    final sel = <SelBanding>[
      if (data['sel'] is List)
        for (final e in data['sel'] as List) ?SelBanding.dariJson(e),
    ];
    return Bandingkan(
      sesiId: bulat(data['sesi_id']),
      status: data['status'] is String ? data['status'] as String : '',
      adaAsli: data['ada_asli'] == true,
      jenis: data['jenis'] is String ? data['jenis'] as String : 'pembacaan',
      asliDibekukanPada: dibekukan is String
          ? DateTime.tryParse(dibekukan)
          : null,
      totalSel: data['total_sel'] is num ? bulat(data['total_sel']) : sel.length,
      jumlahBerubah: data['jumlah_berubah'] is num
          ? bulat(data['jumlah_berubah'])
          : sel.where((s) => s.berubah).length,
      sel: sel,
    );
  }
}
