/// Satu folder di Folder Manager (`GET /api/folders`).
///
/// Sebagian besar isinya **kebentuk sendiri**: tiap sertifikat terbit langsung
/// masuk ke `PT / tahun` lewat `FolderOrganizer` di backend. Jadi tugas mobile
/// cuma nampilin & menelusuri — bukan bikin strukturnya.
class Folder {
  const Folder({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.parentId,
    this.keterangan,
    this.pelangganNama,
    this.jumlahFolder,
    this.jumlahFile,
    this.subFolder = const [],
    this.file = const [],
  });

  final int id;
  final String nama;

  /// `sistem` = kebentuk otomatis dari data. Backend **nolak** rename/hapus
  /// folder sistem, jadi tombolnya disembunyiin di layar — biar user nggak
  /// nyoba lalu ditolak.
  final String tipe;

  final int? parentId;
  final String? keterangan;
  final String? pelangganNama;

  /// Dihitung backend lewat `withCount`. Null = nggak dimuat di respons ini
  /// (mis. waktu folder muncul sebagai anak di endpoint detail), bukan nol.
  final int? jumlahFolder;
  final int? jumlahFile;

  /// Cuma keisi di `GET /api/folders/{id}`.
  final List<Folder> subFolder;
  final List<FolderFile> file;

  bool get folderSistem => tipe == 'sistem';

  /// Folder yang isinya nol — dipakai buat nampilin keadaan kosong yang jujur
  /// daripada layar putih.
  bool get kosong => (jumlahFolder ?? 0) == 0 && (jumlahFile ?? 0) == 0;

  factory Folder.fromJson(Map<String, dynamic> json) {
    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;

    return Folder(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '',
      tipe: json['tipe'] as String? ?? 'manual',
      parentId: (json['parent_id'] as num?)?.toInt(),
      keterangan: json['keterangan'] as String?,
      pelangganNama: pelanggan?['nama'] as String?,
      jumlahFolder: (json['jumlah_folder'] as num?)?.toInt(),
      jumlahFile: (json['jumlah_file'] as num?)?.toInt(),
      subFolder: (json['sub_folder'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Folder.fromJson)
          .toList(),
      file: (json['file'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(FolderFile.fromJson)
          .toList(),
    );
  }
}

/// Satu file di dalam folder (`GET /api/folder-files`).
class FolderFile {
  const FolderFile({
    required this.id,
    required this.folderId,
    required this.nama,
    required this.downloadUrl,
    this.sumber,
    this.mime,
    this.ukuran,
    this.keterangan,
    this.diunggahOleh,
    this.sertifikatNomor,
    this.sertifikatSiapDiunduh = false,
  });

  final int id;
  final int folderId;
  final String nama;

  /// URL absolut dari backend — butuh header Authorization, jadi nggak bisa
  /// dibuka langsung di browser luar.
  final String downloadUrl;

  final String? sumber;
  final String? mime;
  final int? ukuran;
  final String? keterangan;
  final String? diunggahOleh;

  /// File sertifikat nggak disalin — dia nunjuk ke sertifikat aslinya.
  final String? sertifikatNomor;

  /// `false` kalau PDF-nya masih digenerate (job antrean) — tombol unduhnya
  /// dimatiin, bukan ngasih file setengah jadi.
  final bool sertifikatSiapDiunduh;

  bool get dariSertifikat => sertifikatNomor != null;

  /// Ukuran yang kebaca manusia. Null kalau backend nggak ngirim ukurannya.
  String? get ukuranTerbaca {
    final b = ukuran;
    if (b == null) return null;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory FolderFile.fromJson(Map<String, dynamic> json) {
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;

    return FolderFile(
      id: (json['id'] as num).toInt(),
      folderId: (json['folder_id'] as num?)?.toInt() ?? 0,
      nama: json['nama'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      sumber: json['sumber'] as String?,
      mime: json['mime'] as String?,
      ukuran: (json['ukuran'] as num?)?.toInt(),
      keterangan: json['keterangan'] as String?,
      diunggahOleh: json['diunggah_oleh'] as String?,
      sertifikatNomor: sertifikat?['nomor'] as String?,
      sertifikatSiapDiunduh: sertifikat?['siap_diunduh'] as bool? ?? false,
    );
  }
}
