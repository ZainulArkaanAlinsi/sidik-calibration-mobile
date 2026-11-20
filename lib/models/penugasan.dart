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
    this.batal,
    this.diselesaikanPada,
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

  /// Jejak pembatalan (kontrak CRUD lengkap §4, field ADDITIVE): `null`
  /// selama belum dibatalkan. Penugasan lama yang dibatalkan lewat panel
  /// berisi alasan `null`.
  final PenugasanBatal? batal;

  /// Kapan ditutup (`diselesaikan_pada`, ISO-8601; PR #284, field ADDITIVE):
  /// `null` selama belum `selesai` dan sesudah dibuka lagi.
  final DateTime? diselesaikanPada;
  final List<AnggotaPenugasan> teknisi;
  final List<BarisPenugasan> baris;

  bool get grup => tipe == 'grup';
  bool get aktif => status == 'aktif';
  bool get selesai => status == 'selesai';

  /// Semua baris sudah tuntas dan penugasan masih `aktif`: tombol Selesaikan
  /// pantas ditekan. Kontrak #284: "`persen_tuntas` = 100 di detail penugasan
  /// berarti hal yang sama" dengan `siap_ditutup` — kunci `siap_ditutup` hanya
  /// ikut di respons lapor-progres, tidak di daftar/detail. Server tetap yang
  /// memutuskan (`422 penugasan_belum_tuntas`).
  bool get siapDitutup => aktif && persenTuntas >= 100;
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
    batal: switch (json['batal']) {
      final Map<String, dynamic> m => PenugasanBatal.fromJson(m),
      final Map m => PenugasanBatal.fromJson(Map<String, dynamic>.from(m)),
      _ => null,
    },
    diselesaikanPada: switch (json['diselesaikan_pada']) {
      final String t => DateTime.tryParse(t),
      _ => null,
    },
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

/// Siapa membatalkan penugasan, kapan, dan kenapa (`batal` di respons).
class PenugasanBatal {
  const PenugasanBatal({this.alasan, this.oleh, this.pada});

  final String? alasan;

  /// NAMA pembatal (string), sama bentuknya dengan `dibuat_oleh`.
  final String? oleh;
  final DateTime? pada;

  factory PenugasanBatal.fromJson(Map<String, dynamic> json) => PenugasanBatal(
    alasan: json['alasan'] as String?,
    oleh: json['oleh'] as String?,
    pada: DateTime.tryParse(json['pada'] as String? ?? ''),
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
