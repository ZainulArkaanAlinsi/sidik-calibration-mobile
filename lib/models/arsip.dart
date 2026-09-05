import 'calibration_history_item.dart';
import '../core/utils/parse_list.dart';

/// Satu folder perusahaan di daftar akar Arsip
/// (`GET /api/arsip/perusahaan`).
///
/// **Endpoint ini ngelist FOLDER, bukan pelanggan** — dan dua id yang datang
/// dari situ beda arti. Lihat [id] dan [pelangganId].
class ArsipPerusahaan {
  const ArsipPerusahaan({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.jumlahAlat,
    required this.jumlahSertifikat,
    this.pelangganId,
    this.terakhirKalibrasi,
  });

  /// **Id FOLDER**, bukan id pelanggan. Dipakai buat `GET /arsip/folders/{id}`.
  final int id;

  /// **Id PELANGGAN** — `json['pelanggan']['id']`, dan ini yang dipakai buat
  /// `GET /arsip/perusahaan/{customer}/folder`.
  ///
  /// Dulu jalur itu dikasih [id] (id folder), dan itu bug yang paling sepi
  /// bentuknya: rutenya ngiket ke `Customer`, jadi id folder 3 membuka arsip
  /// pelanggan id 3 — **PT yang beda**, status 200, nol error. Folder akar PT
  /// dibikin belakangan dan urutannya nggak ikut urutan pelanggan, jadi dua id
  /// itu sering beda; di uji tiga PT, dua di antaranya kebuka arsip PT lain.
  ///
  /// `null` = folder akar yang nggak nempel ke pelanggan mana pun
  /// (`folders.customer_id` boleh kosong). Di situ yang benar dibuka lewat
  /// [id] sebagai folder biasa — bukan ditebak ke pelanggan.
  final int? pelangganId;

  final String nama;

  /// Alamat pelanggannya, dibaca dari `json['pelanggan']['alamat']` —
  /// **bukan** `json['alamat']` di tingkat atas, yang nggak pernah ada.
  /// Selama itu dibaca dari tingkat atas, alamat di kartu PT selalu kosong dan
  /// baris kecil di bawah namanya nggak pernah kelihatan.
  final String alamat;

  final int jumlahAlat;
  final int jumlahSertifikat;
  final DateTime? terakhirKalibrasi;

  factory ArsipPerusahaan.fromJson(Map<String, dynamic> json) {
    final terakhir = json['terakhir_kalibrasi'] as String?;
    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;

    return ArsipPerusahaan(
      id: (json['id'] as num).toInt(),
      pelangganId: (pelanggan?['id'] as num?)?.toInt(),
      nama: json['nama'] as String? ?? '—',
      alamat: (pelanggan?['alamat'] as String?) ?? '',
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
    this.tipe = 'manual',
    this.dibuatPada,
  });

  final int id;
  final String nama;
  final int? parentId;

  /// Folder akar perusahaan — dibikin sistem. Tombol Rename/Pindah/Hapus
  /// disembunyiin buat folder ini, bukan nunggu ditolak 422 dulu.
  final bool isRoot;

  /// `sistem` = kebentuk otomatis dari data (mis. `PT / tahun`), bukan dibikin
  /// admin. **Lebih luas dari [isRoot]:** folder tahun di dalam folder PT juga
  /// `sistem` walau bukan akar.
  final String tipe;

  final int jumlahSubfolder;
  final int jumlahBerkas;

  /// Kapan foldernya dibikin — **punya jam**. Backend udah ngirim (`dibuat_pada`
  /// di `FolderResource`), cuma nggak pernah dibaca di sini, jadi folder tahun
  /// & folder manual yang dibikin di hari yang sama nggak bisa dibedain.
  final DateTime? dibuatPada;

  /// Folder kosong boleh dihapus; yang masih ada isinya ditolak backend.
  /// Dicek di sini biar tombolnya bisa dimatiin duluan.
  bool get kosong => jumlahSubfolder == 0 && jumlahBerkas == 0;

  bool get folderSistem => tipe == 'sistem' || isRoot;

  /// Folder sistem **nggak bisa dipindah** — backend nolak `422`.
  ///
  /// Dicek di sini biar folder-nya nggak bisa di-drag SAMA SEKALI, bukan
  /// dibiarin ditarik lalu ditolak. Drag yang keliatan jalan tapi selalu gagal
  /// itu lebih bikin frustrasi daripada item yang jelas nggak bisa ditarik.
  bool get bisaDipindah => !folderSistem;

  factory ArsipFolder.fromJson(Map<String, dynamic> json) {
    return ArsipFolder(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      parentId: (json['parent_id'] as num?)?.toInt(),
      isRoot: json['is_root'] as bool? ?? false,
      tipe: json['tipe'] as String? ?? 'manual',
      // Kuncinya `jumlah_folder`/`jumlah_file` — itu yang ditulis
      // `FolderResource` di server dan yang tercatat di
      // `docs/kontrak-api.md`. Sampai 3 Sep 2026 di sini terbaca
      // `jumlah_subfolder`/`jumlah_berkas`, dua nama yang TIDAK PERNAH dikirim
      // siapa pun.
      //
      // Gagalnya sunyi total, dan `?? 0` yang menyunyikannya: tiap folder di
      // layar Arsip menulis "0 folder · 0 berkas" apa pun isinya, dan `kosong`
      // di bawah ikut selalu true — jadi menu Hapus menyala buat folder yang
      // masih ada isinya, persis yang penjaga itu dibikin buat mencegah.
      //
      // Yang bikin ini bertahan lama: `MockArsipService` menyusun objeknya
      // LANGSUNG lewat konstruktor, bukan lewat `fromJson`. Jadi di mode mock
      // angkanya benar dan seluruh test hijau — cuma jalur API asli yang salah.
      jumlahSubfolder: (json['jumlah_folder'] as num?)?.toInt() ?? 0,
      jumlahBerkas: (json['jumlah_file'] as num?)?.toInt() ?? 0,
      // UTC dari backend → waktu lokal; tanpa ini jamnya mundur 7 jam.
      dibuatPada: switch (json['dibuat_pada']) {
        String s => DateTime.tryParse(s)?.toLocal(),
        _ => null,
      },
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

  /// Bentuknya satu baris `file[]` dari `GET /arsip/folders/{id}`.
  ///
  /// **`id` di sini id SESI KALIBRASI, bukan id baris `folder_files`.** Dua
  /// alasannya, dan dua-duanya mengikat:
  ///
  /// 1. Layar ini membuka `CalibrationDetailScreen(calibrationId: berkas.id)`.
  ///    Diberi id berkas, yang kebuka sesi orang lain yang nomornya kebetulan
  ///    sama — status 200, nol error.
  /// 2. `PUT /arsip/berkas/{sesiId}/pindah` juga minta id sesi; kontraknya
  ///    menyebut "itu yang dipegang mobile di layar arsip".
  ///
  /// Baris yang bukan lembar kerja (sertifikat unggahan, berkas manual) nggak
  /// punya sesi sama sekali, jadi **dilempar** — `parseListAman` yang
  /// membuangnya. Menyimpannya dengan id berkas justru bentuk kegagalan yang
  /// lagi dicegah: kartunya kelihatan bisa dipencet, lalu membuka sesi yang
  /// salah.
  factory ArsipBerkas.fromJson(Map<String, dynamic> json) {
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    final lembar = json['lembar_kerja'] as Map<String, dynamic>?;
    final idSesi = (lembar?['calibration_session_id'] as num?)?.toInt();

    if (idSesi == null) {
      throw const FormatException(
        'baris arsip tanpa `lembar_kerja.calibration_session_id` — '
        'nggak punya sesi buat dibuka',
      );
    }

    final equipment = lembar?['equipment'] as Map<String, dynamic>?;
    final teknisi = lembar?['teknisi'] as Map<String, dynamic>?;
    final tanggal = lembar?['tanggal_kalibrasi'] as String?;

    return ArsipBerkas(
      id: idSesi,
      status: CalibrationStatusJson.fromJson(
        lembar?['status'] as String? ?? 'draft',
      ),
      nomorSesi: lembar?['nomor_sesi'] as String?,
      namaAlat: equipment?['nama_alat'] as String?,
      namaTeknisi: teknisi?['nama'] as String?,
      tanggalKalibrasi: tanggal == null ? null : DateTime.tryParse(tanggal),
      keputusan: switch (lembar?['keputusan']) {
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

  /// Bentuknya `{ "data": { ...folder, breadcrumb[], sub_folder[], file[] } }`.
  ///
  /// **Sempat dibaca dengan bentuk yang beda sama sekali** — `json['folder']`,
  /// `json['subfolder']`, dan `json['data']` sebagai daftar berkas. Nggak satu
  /// pun kunci itu ada di respons server, dan `json['data']` yang sebenarnya
  /// objek bikin `as List` NGELEMPAR: tiap folder yang dibuka lawan server asli
  /// gagal, dan layarnya berhenti di pesan error.
  ///
  /// Nggak ketahuan karena seluruh test arsip lewat `MockArsipService` yang
  /// bikin objeknya langsung — parser ini nggak pernah sekali pun diadu ke
  /// payload sungguhan. Sekarang ada `arsip_bentuk_asli_test.dart` yang
  /// nyuapin JSON hasil rekam dari server.
  factory ArsipIsiFolder.fromJson(Map<String, dynamic> json) {
    final folder = json['data'] as Map<String, dynamic>? ?? const {};
    final pelanggan = folder['pelanggan'] as Map<String, dynamic>?;
    final crumbs = folder['breadcrumb'] as List<dynamic>? ?? const [];
    final subfolder = folder['sub_folder'] as List<dynamic>? ?? const [];
    final berkas = folder['file'] as List<dynamic>? ?? const [];

    return ArsipIsiFolder(
      folderId: (folder['id'] as num?)?.toInt() ?? 0,
      namaFolder: folder['nama'] as String? ?? '—',
      // Diturunkan, bukan diminta ke server: folder akar itu yang induknya
      // kosong, dan `parent_id` udah ikut di tiap baris.
      isRoot: folder['parent_id'] == null,
      namaPerusahaan: pelanggan?['nama'] as String?,
      breadcrumb: parseListAman(crumbs, ArsipBreadcrumb.fromJson),
      subfolder: parseListAman(subfolder, ArsipFolder.fromJson),
      berkas: parseListAman(berkas, ArsipBerkas.fromJson),
    );
  }
}
