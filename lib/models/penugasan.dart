/// Penugasan teknisi, personal & grup — `/penugasan` (slice D di repo API).
///
/// Beda dari `order_items.teknisi_id`: itu "alat nomor seri INI dikerjakan
/// siapa"; ini RENCANA ("minggu ini 10 autoklaf & 4 timbangan"), dan barangnya
/// belum tentu sudah masuk lab.
class Penugasan {
  const Penugasan({
    required this.id,
    required this.judul,
    required this.tipe,
    required this.status,
    this.tanggalTarget,
    required this.terlambat,
    required this.persenTuntas,
    this.catatan,
    this.dibuatOleh,
    this.teknisi = const [],
    this.baris = const [],
  });

  final int id;
  final String judul;

  /// `personal` / `grup`.
  final String tipe;

  /// `aktif` / `selesai` / `dibatalkan`.
  final String status;
  final DateTime? tanggalTarget;
  final bool terlambat;

  /// 0–100, dipotong di 100 oleh server walau yang dilaporkan melebihi rencana.
  final int persenTuntas;
  final String? catatan;
  final String? dibuatOleh;
  final List<AnggotaPenugasan> teknisi;
  final List<BarisPenugasan> baris;

  bool get grup => tipe == 'grup';
  bool get aktif => status == 'aktif';
  AnggotaPenugasan? get ketua =>
      teknisi.where((t) => t.peran == 'ketua').firstOrNull;

  factory Penugasan.fromJson(Map<String, dynamic> json) => Penugasan(
    id: json['id'] as int,
    judul: json['judul'] as String? ?? '',
    tipe: json['tipe'] as String? ?? 'personal',
    status: json['status'] as String? ?? 'aktif',
    tanggalTarget: DateTime.tryParse(json['tanggal_target'] as String? ?? ''),
    terlambat: json['terlambat'] as bool? ?? false,
    persenTuntas: (json['persen_tuntas'] as num?)?.toInt() ?? 0,
    catatan: json['catatan'] as String?,
    dibuatOleh: json['dibuat_oleh'] as String?,
    teknisi: [
      for (final t in (json['teknisi'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        AnggotaPenugasan.fromJson(t),
    ],
    baris: [
      for (final b in (json['item'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        BarisPenugasan.fromJson(b),
    ],
  );
}

class AnggotaPenugasan {
  const AnggotaPenugasan({
    required this.id,
    required this.nama,
    this.kode,
    required this.peran,
    this.dilihatPada,
  });

  final int id;
  final String nama;
  final String? kode;

  /// `ketua` / `anggota`.
  final String peran;

  /// Kapan PERTAMA membuka tugasnya — jawaban jujur untuk "dia udah tau
  /// belum?". Null = belum pernah membuka.
  final DateTime? dilihatPada;

  factory AnggotaPenugasan.fromJson(Map<String, dynamic> json) =>
      AnggotaPenugasan(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nama: json['nama'] as String? ?? '—',
        kode: json['kode'] as String?,
        peran: json['peran'] as String? ?? 'anggota',
        dilihatPada: DateTime.tryParse(json['dilihat_pada'] as String? ?? ''),
      );
}

/// Satu baris "+" di layar penugasan: jenis alat & jumlahnya.
class BarisPenugasan {
  const BarisPenugasan({
    this.id,
    required this.jenisAlat,
    required this.jumlah,
    this.jumlahSelesai = 0,
    this.paket,
    this.catatan,
  });

  final int? id;
  final String jenisAlat;
  final int jumlah;
  final int jumlahSelesai;
  final String? paket;
  final String? catatan;

  factory BarisPenugasan.fromJson(Map<String, dynamic> json) => BarisPenugasan(
    id: (json['id'] as num?)?.toInt(),
    jenisAlat: json['jenis_alat'] as String? ?? '',
    jumlah: (json['jumlah'] as num?)?.toInt() ?? 0,
    jumlahSelesai: (json['jumlah_selesai'] as num?)?.toInt() ?? 0,
    paket: json['paket'] as String?,
    catatan: json['catatan'] as String?,
  );

  Map<String, dynamic> keJson() => {
    'jenis_alat': jenisAlat,
    'jumlah': jumlah,
    if (catatan != null && catatan!.isNotEmpty) 'catatan': catatan,
  };
}
