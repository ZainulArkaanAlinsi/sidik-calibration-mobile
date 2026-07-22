import 'calibration_history_item.dart';

/// Satu folder perusahaan di daftar akar Arsip
/// (`GET /api/arsip/perusahaan`).
class ArsipPerusahaan {
  const ArsipPerusahaan({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.jumlahAlat,
    required this.jumlahSertifikat,
    this.terakhirKalibrasi,
  });

  final int id;
  final String nama;
  final String alamat;
  final int jumlahAlat;
  final int jumlahSertifikat;
  final DateTime? terakhirKalibrasi;

  factory ArsipPerusahaan.fromJson(Map<String, dynamic> json) {
    final terakhir = json['terakhir_kalibrasi'] as String?;

    return ArsipPerusahaan(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      alamat: json['alamat'] as String? ?? '',
      jumlahAlat: (json['jumlah_alat'] as num?)?.toInt() ?? 0,
      jumlahSertifikat: (json['jumlah_sertifikat'] as num?)?.toInt() ?? 0,
      terakhirKalibrasi: terakhir == null ? null : DateTime.tryParse(terakhir),
    );
  }
}

/// Satu subfolder di dalam folder yang lagi dibuka.
class ArsipFolder {
  const ArsipFolder({
    required this.id,
    required this.nama,
    required this.isRoot,
    required this.jumlahSubfolder,
    required this.jumlahBerkas,
    this.parentId,
  });

  final int id;
  final String nama;
  final int? parentId;

  /// Folder akar perusahaan — dibikin sistem. Tombol Rename/Pindah/Hapus
  /// disembunyiin buat folder ini, bukan nunggu ditolak 422 dulu.
  final bool isRoot;

  final int jumlahSubfolder;
  final int jumlahBerkas;

  /// Folder kosong boleh dihapus; yang masih ada isinya ditolak backend.
  /// Dicek di sini biar tombolnya bisa dimatiin duluan.
  bool get kosong => jumlahSubfolder == 0 && jumlahBerkas == 0;

  factory ArsipFolder.fromJson(Map<String, dynamic> json) {
    return ArsipFolder(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      parentId: (json['parent_id'] as num?)?.toInt(),
      isRoot: json['is_root'] as bool? ?? false,
      jumlahSubfolder: (json['jumlah_subfolder'] as num?)?.toInt() ?? 0,
      jumlahBerkas: (json['jumlah_berkas'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Satu langkah di breadcrumb (akar → ... → folder yang dibuka).
class ArsipBreadcrumb {
  const ArsipBreadcrumb({
    required this.id,
    required this.nama,
    required this.isRoot,
  });

  final int id;
  final String nama;
  final bool isRoot;

  factory ArsipBreadcrumb.fromJson(Map<String, dynamic> json) {
    return ArsipBreadcrumb(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      isRoot: json['is_root'] as bool? ?? false,
    );
  }
}

/// Satu berkas (sesi kalibrasi + sertifikatnya kalau udah terbit).
class ArsipBerkas {
  const ArsipBerkas({
    required this.id,
    required this.status,
    this.nomorSesi,
    this.namaAlat,
    this.namaTeknisi,
    this.tanggalKalibrasi,
    this.keputusan,
    this.nomorSertifikat,
    this.pdfUrl,
  });

  final int id;
  final CalibrationStatus status;
  final String? nomorSesi;
  final String? namaAlat;
  final String? namaTeknisi;
  final DateTime? tanggalKalibrasi;
  final Keputusan? keputusan;
  final String? nomorSertifikat;

  /// Cuma keisi kalau sertifikatnya udah `terbit`.
  final String? pdfUrl;

  factory ArsipBerkas.fromJson(Map<String, dynamic> json) {
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final tanggal = json['tanggal_kalibrasi'] as String?;

    return ArsipBerkas(
      id: (json['id'] as num).toInt(),
      status: CalibrationStatusJson.fromJson(
        json['status'] as String? ?? 'draft',
      ),
      nomorSesi: json['nomor_sesi'] as String?,
      namaAlat: equipment?['nama_alat'] as String?,
      namaTeknisi: teknisi?['nama'] as String?,
      tanggalKalibrasi: tanggal == null ? null : DateTime.tryParse(tanggal),
      keputusan: switch (json['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      nomorSertifikat: sertifikat?['nomor'] as String?,
      pdfUrl: sertifikat?['pdf_url'] as String?,
    );
  }
}

/// Isi satu folder — subfolder + berkas + breadcrumb, sekali ambil.
///
/// Subfolder sengaja nggak dipaginasi backend (jumlahnya kecil, dan file
/// manager yang nyembunyiin folder di halaman 2 bikin orang ngira foldernya
/// ilang); berkas dipaginasi 15/halaman.
class ArsipIsiFolder {
  const ArsipIsiFolder({
    required this.folderId,
    required this.namaFolder,
    required this.isRoot,
    required this.breadcrumb,
    required this.subfolder,
    required this.berkas,
    this.namaPerusahaan,
  });

  final int folderId;
  final String namaFolder;
  final bool isRoot;
  final String? namaPerusahaan;
  final List<ArsipBreadcrumb> breadcrumb;
  final List<ArsipFolder> subfolder;
  final List<ArsipBerkas> berkas;

  bool get kosong => subfolder.isEmpty && berkas.isEmpty;

  factory ArsipIsiFolder.fromJson(Map<String, dynamic> json) {
    final folder = json['folder'] as Map<String, dynamic>? ?? const {};
    final perusahaan = folder['perusahaan'] as Map<String, dynamic>?;
    final crumbs = folder['breadcrumb'] as List<dynamic>? ?? const [];
    final subfolder = json['subfolder'] as List<dynamic>? ?? const [];
    final berkas = json['data'] as List<dynamic>? ?? const [];

    return ArsipIsiFolder(
      folderId: (folder['id'] as num?)?.toInt() ?? 0,
      namaFolder: folder['nama'] as String? ?? '—',
      isRoot: folder['is_root'] as bool? ?? false,
      namaPerusahaan: perusahaan?['nama'] as String?,
      breadcrumb: crumbs
          .cast<Map<String, dynamic>>()
          .map(ArsipBreadcrumb.fromJson)
          .toList(),
      subfolder: subfolder
          .cast<Map<String, dynamic>>()
          .map(ArsipFolder.fromJson)
          .toList(),
      berkas: berkas
          .cast<Map<String, dynamic>>()
          .map(ArsipBerkas.fromJson)
          .toList(),
    );
  }
}
