/// Pelacakan paket alat — `GET /pelacakan`, `GET /pelacakan/{order}`
/// (`PaketLacakResource` + `TahapPaket` di repo API).
///
/// Tahapnya DITURUNKAN server dari status sesi & sertifikat, bukan kolom yang
/// disimpan — jadi aplikasi ini tidak pernah menghitung tahap sendiri, cuma
/// menampilkan kode & label yang dikirim.
class PaketLacak {
  const PaketLacak({
    required this.id,
    required this.nomor,
    this.pelanggan,
    this.tanggalMasuk,
    this.tanggalJanjiSelesai,
    this.terlambatHari,
    required this.tahap,
    required this.tahapLabel,
    required this.jumlahAlat,
    required this.jumlahSelesai,
    this.alat = const [],
  });

  final int id;
  final String nomor;
  final String? pelanggan;
  final DateTime? tanggalMasuk;
  final DateTime? tanggalJanjiSelesai;

  /// Null = tidak terlambat (atau sudah diserahkan — server berhenti
  /// menghitung begitu alat diserahkan).
  final int? terlambatHari;

  /// Tahap paket = tahap alat yang PALING TERTINGGAL.
  final String tahap;
  final String tahapLabel;
  final int jumlahAlat;
  final int jumlahSelesai;
  final List<AlatDalamPaket> alat;

  double get persenSelesai => jumlahAlat == 0 ? 0 : jumlahSelesai / jumlahAlat;

  factory PaketLacak.fromJson(Map<String, dynamic> json) => PaketLacak(
    id: json['id'] as int,
    nomor: json['nomor'] as String? ?? '',
    pelanggan: json['pelanggan'] as String?,
    tanggalMasuk: DateTime.tryParse(json['tanggal_masuk'] as String? ?? ''),
    tanggalJanjiSelesai: DateTime.tryParse(
      json['tanggal_janji_selesai'] as String? ?? '',
    ),
    terlambatHari: (json['terlambat_hari'] as num?)?.toInt(),
    tahap: json['tahap'] as String? ?? '',
    tahapLabel: json['tahap_label'] as String? ?? '',
    jumlahAlat: (json['jumlah_alat'] as num?)?.toInt() ?? 0,
    jumlahSelesai: (json['jumlah_selesai'] as num?)?.toInt() ?? 0,
    alat: [
      for (final a in (json['alat'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        AlatDalamPaket.fromJson(a),
    ],
  );
}

class AlatDalamPaket {
  const AlatDalamPaket({
    required this.itemId,
    required this.nama,
    this.merk,
    this.serialNumber,
    this.teknisi,
    required this.tahap,
    this.tahapLabel,
    this.nomorSesi,
    this.nomorSertifikat,
    this.keputusan,
    this.diserahkanKepada,
  });

  final int itemId;
  final String nama;
  final String? merk;
  final String? serialNumber;

  /// Kode teknisi (inisial), sama seperti yang tercetak di sertifikat.
  final String? teknisi;
  final String tahap;
  final String? tahapLabel;
  final String? nomorSesi;
  final String? nomorSertifikat;
  final String? keputusan;
  final String? diserahkanKepada;

  bool get sudahDiserahkan => tahap == 'diserahkan';
  bool get bisaDiserahkan =>
      tahap == 'sertifikat_terbit' || tahap == 'siap_diambil';

  factory AlatDalamPaket.fromJson(Map<String, dynamic> json) {
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    return AlatDalamPaket(
      itemId: json['item_id'] as int,
      nama: json['nama'] as String? ?? '—',
      merk: json['merk'] as String?,
      serialNumber: json['serial_number'] as String?,
      teknisi: json['teknisi'] as String?,
      tahap: json['tahap'] as String? ?? '',
      tahapLabel: json['tahap_label'] as String?,
      nomorSesi: json['nomor_sesi'] as String?,
      nomorSertifikat: sertifikat?['nomor'] as String?,
      keputusan: json['keputusan'] as String?,
      diserahkanKepada: json['diserahkan_kepada'] as String?,
    );
  }
}

/// Satu langkah garis waktu — disusun server supaya app lab & app pelanggan
/// tidak punya dua salinan urutan tahap yang bisa beda versi.
class LangkahGarisWaktu {
  const LangkahGarisWaktu({
    required this.kode,
    required this.label,
    required this.lewat,
    required this.sekarang,
  });

  final String kode;
  final String label;
  final bool lewat;
  final bool sekarang;

  factory LangkahGarisWaktu.fromJson(Map<String, dynamic> json) =>
      LangkahGarisWaktu(
        kode: json['kode'] as String? ?? '',
        label: json['label'] as String? ?? '',
        lewat: json['lewat'] as bool? ?? false,
        sekarang: json['sekarang'] as bool? ?? false,
      );
}
