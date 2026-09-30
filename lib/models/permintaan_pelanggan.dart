/// Permintaan kalibrasi yang diajukan pelanggan dari aplikasinya —
/// `GET /api/permintaan-pelanggan` (antrean) & `/{id}` (detail), sisi LAB.
///
/// Keputusan pemilik proyek 30 Sep 2026 (§41 backend): pelanggan mengajukan,
/// semua admin aktif menerimanya, SALAH SATU admin menerima (lahir Order) atau
/// menolak dengan alasan. Tidak pernah otomatis.
library;

/// Empat status yang dikenal server. Nilai lain (server lebih baru dari
/// aplikasi) jatuh ke [StatusPermintaan.lainnya] — kartunya tetap tampil,
/// tombol putusnya tidak.
enum StatusPermintaan {
  baru('baru'),
  diterima('diterima'),
  ditolak('ditolak'),
  dibatalkan('dibatalkan'),
  lainnya('');

  const StatusPermintaan(this.kode);

  final String kode;

  static StatusPermintaan dariApi(String? kode) => values.firstWhere(
    (s) => s.kode == kode && s != lainnya,
    orElse: () => lainnya,
  );

  /// Hanya `baru` yang bisa diputuskan (terima/tolak). Sisanya dijawab 422.
  bool get bisaDiputuskan => this == baru;
}

/// Cara alat sampai ke lab. Hanya dua (kontrak §1).
enum MetodePengantaran {
  diantarSendiri('diantar_sendiri'),
  diambilLab('diambil_lab');

  const MetodePengantaran(this.kode);

  final String kode;

  static MetodePengantaran? dariApi(String? kode) {
    for (final m in values) {
      if (m.kode == kode) return m;
    }
    return null;
  }
}

/// Satu baris alat di permintaan.
///
/// [id] = id BARIS permintaan (dipakai `alat_baru[].item_id` saat Terima),
/// bukan id alat. [equipmentId] `null` selama alat baru belum didaftarkan lab.
class AlatPermintaan {
  const AlatPermintaan({
    required this.id,
    this.equipmentId,
    required this.baru,
    required this.namaAlat,
    this.merk,
    this.model,
    this.serialNumber,
    this.noIdentifikasi,
    this.rentangMin,
    this.rentangMaks,
    this.satuan,
    this.resolusi,
    this.lokasi,
    this.catatan,
    this.perluKategori = false,
    this.perluNomorSeri = false,
  });

  final int id;
  final int? equipmentId;

  /// Alat yang belum terdaftar atas pelanggan ini saat diajukan.
  final bool baru;

  final String namaAlat;
  final String? merk;
  final String? model;
  final String? serialNumber;
  final String? noIdentifikasi;
  final num? rentangMin;
  final num? rentangMaks;
  final String? satuan;
  final num? resolusi;
  final String? lokasi;
  final String? catatan;

  /// Petunjuk SERVER untuk layar Terima — bukan ditebak dari [baru]: alat baru
  /// yang sudah didaftarkan (permintaan diterima) tidak lagi memerlukannya.
  final bool perluKategori;
  final bool perluNomorSeri;

  /// "0 – 14 pH"; `null` kalau pelanggan tidak mengisi rentang.
  String? get rentang {
    if (rentangMin == null && rentangMaks == null) return null;
    final a = rentangMin == null ? '' : _angka(rentangMin!);
    final b = rentangMaks == null ? '' : _angka(rentangMaks!);
    final s = satuan == null || satuan!.isEmpty ? '' : ' $satuan';
    return '$a – $b$s';
  }

  static String _angka(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  factory AlatPermintaan.fromJson(Map<String, dynamic> j) => AlatPermintaan(
    id: (j['id'] as num).toInt(),
    equipmentId: (j['equipment_id'] as num?)?.toInt(),
    baru: j['baru'] == true,
    namaAlat: j['nama_alat'] as String? ?? '—',
    merk: j['merk'] as String?,
    model: j['model'] as String?,
    serialNumber: j['serial_number'] as String?,
    noIdentifikasi: j['no_identifikasi'] as String?,
    rentangMin: j['rentang_min'] as num?,
    rentangMaks: j['rentang_maks'] as num?,
    satuan: j['satuan'] as String?,
    resolusi: j['resolusi'] as num?,
    lokasi: j['lokasi'] as String?,
    catatan: j['catatan'] as String?,
    perluKategori: j['perlu_kategori'] == true,
    perluNomorSeri: j['perlu_nomor_seri'] == true,
  );
}

/// Permintaan lengkap. Bentuk antrean (3.1) dan detail (3.2) SAMA, jadi satu
/// kelas.
class PermintaanPelanggan {
  const PermintaanPelanggan({
    required this.id,
    required this.nomor,
    required this.status,
    this.pelangganId,
    this.pelangganNama,
    this.pemohonNama,
    this.pemohonEmail,
    this.pemohonTelepon,
    this.metode,
    this.tanggalDari,
    this.tanggalSampai,
    this.catatan,
    this.alasanPenolakan,
    this.diputuskanOleh,
    this.diputuskanPada,
    this.dibatalkanPada,
    this.orderId,
    this.orderNomor,
    this.jumlahAlat = 0,
    this.jumlahPesan = 0,
    this.alat = const [],
    this.dibuatPada,
  });

  final int id;
  final String nomor;
  final StatusPermintaan status;
  final int? pelangganId;
  final String? pelangganNama;
  final String? pemohonNama;
  final String? pemohonEmail;
  final String? pemohonTelepon;
  final MetodePengantaran? metode;

  /// Keinginan pelanggan, BUKAN janji — lab yang memutuskan tanggal pastinya.
  final DateTime? tanggalDari;
  final DateTime? tanggalSampai;

  final String? catatan;

  /// Hanya terisi kalau `ditolak`; dibaca pelanggan apa adanya.
  final String? alasanPenolakan;
  final String? diputuskanOleh;
  final DateTime? diputuskanPada;
  final DateTime? dibatalkanPada;

  /// Terisi sesudah `diterima`.
  final int? orderId;
  final String? orderNomor;

  final int jumlahAlat;
  final int jumlahPesan;
  final List<AlatPermintaan> alat;
  final DateTime? dibuatPada;

  /// Berapa hari sudah menunggu — [hariIni] DIOPER pemanggil (bukan
  /// `DateTime.now()`), supaya layar & golden bisa dipatok ke jam yang sama.
  int? menungguHari(DateTime hariIni) {
    final mulai = dibuatPada?.toLocal();
    if (mulai == null) return null;
    final a = DateTime(mulai.year, mulai.month, mulai.day);
    final b = DateTime(hariIni.year, hariIni.month, hariIni.day);
    return b.difference(a).inDays;
  }

  factory PermintaanPelanggan.fromJson(Map<String, dynamic> j) {
    final cust = (j['customer'] as Map<String, dynamic>?) ?? const {};
    final pemohon = (j['pemohon'] as Map<String, dynamic>?) ?? const {};
    final order = j['order'] as Map<String, dynamic>?;
    final oleh = j['diputuskan_oleh'];

    return PermintaanPelanggan(
      id: (j['id'] as num).toInt(),
      nomor: j['nomor'] as String? ?? '',
      status: StatusPermintaan.dariApi(j['status'] as String?),
      pelangganId: (cust['id'] as num?)?.toInt(),
      pelangganNama: cust['nama'] as String?,
      pemohonNama: pemohon['nama'] as String?,
      pemohonEmail: pemohon['email'] as String?,
      pemohonTelepon: pemohon['telepon'] as String?,
      metode: MetodePengantaran.dariApi(j['metode_pengantaran'] as String?),
      tanggalDari: DateTime.tryParse(
        j['tanggal_diinginkan_dari'] as String? ?? '',
      ),
      tanggalSampai: DateTime.tryParse(
        j['tanggal_diinginkan_sampai'] as String? ?? '',
      ),
      catatan: j['catatan'] as String?,
      alasanPenolakan: j['alasan_penolakan'] as String?,
      // Bentuknya belum dikunci kontrak: string nama, atau objek `{nama}`.
      diputuskanOleh: switch (oleh) {
        final String s => s,
        final Map<String, dynamic> m => m['nama'] as String?,
        _ => null,
      },
      diputuskanPada: DateTime.tryParse(j['diputuskan_pada'] as String? ?? ''),
      dibatalkanPada: DateTime.tryParse(j['dibatalkan_pada'] as String? ?? ''),
      orderId: (order?['id'] as num?)?.toInt(),
      orderNomor: order?['nomor'] as String?,
      jumlahAlat: (j['jumlah_alat'] as num?)?.toInt() ?? 0,
      jumlahPesan: (j['jumlah_pesan'] as num?)?.toInt() ?? 0,
      alat: [
        for (final a in (j['alat'] as List<dynamic>? ?? const []))
          if (a is Map<String, dynamic>) AlatPermintaan.fromJson(a),
      ],
      dibuatPada: DateTime.tryParse(j['dibuat_pada'] as String? ?? ''),
    );
  }
}

/// Halaman antrean + angka badge (`meta.jumlah_baru`, tidak terpengaruh filter).
class HalamanPermintaan {
  const HalamanPermintaan({
    required this.items,
    this.total = 0,
    this.jumlahBaru = 0,
  });

  final List<PermintaanPelanggan> items;
  final int total;
  final int jumlahBaru;
}

/// Satu pesan di utas. Sisi LAB melihat nama pengirim sebenarnya (3.5).
class PesanPermintaan {
  const PesanPermintaan({
    required this.id,
    required this.dariLab,
    this.namaPengirim,
    required this.isi,
    this.dibuatPada,
  });

  final int id;

  /// `sisi == 'lab'`. Dipakai menata gelembung: pesan lab di kanan.
  final bool dariLab;
  final String? namaPengirim;
  final String isi;
  final DateTime? dibuatPada;

  factory PesanPermintaan.fromJson(Map<String, dynamic> j) {
    final pengirim = j['pengirim'] as Map<String, dynamic>?;
    return PesanPermintaan(
      id: (j['id'] as num).toInt(),
      dariLab: j['sisi'] == 'lab',
      namaPengirim:
          pengirim?['nama'] as String? ?? j['nama_pengirim'] as String?,
      isi: j['isi'] as String? ?? '',
      dibuatPada: DateTime.tryParse(j['dibuat_pada'] as String? ?? ''),
    );
  }
}

/// Utas + penanda percakapan masih terbuka (`meta.percakapan_terbuka`).
class UtasPermintaan {
  const UtasPermintaan({required this.pesan, this.terbuka = true});

  final List<PesanPermintaan> pesan;
  final bool terbuka;
}

/// Kelengkapan satu alat baru saat Terima (`alat_baru[]` di badan POST).
class LengkapiAlatBaru {
  const LengkapiAlatBaru({
    required this.itemId,
    required this.kategoriId,
    this.serialNumber,
  });

  /// `alat[].id` dari permintaan INI (id baris, bukan id alat).
  final int itemId;

  /// `equipment_category_id` — id kategori milik lab ini.
  final int kategoriId;

  /// Kosong = biarkan ketikan pelanggan; diisi = menimpanya.
  final String? serialNumber;

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'equipment_category_id': kategoriId,
    if (serialNumber != null && serialNumber!.trim().isNotEmpty)
      'serial_number': serialNumber!.trim(),
  };
}

/// 422 dari aksi permintaan, sudah dipilah per kunci `errors`.
///
/// Layar Terima butuh kuncinya, bukan cuma `message`: bentrok nomor seri harus
/// muncul DI BAWAH kolom alat yang bersangkutan
/// (`alat_baru.{item_id}.serial_number`), bukan jadi satu snackbar yang tidak
/// bilang alat mana.
class GalatPermintaan implements Exception {
  const GalatPermintaan(this.pesan, {this.errors = const {}});

  final String pesan;
  final Map<String, List<String>> errors;

  /// Pesan pertama untuk [kunci], atau `null`.
  String? untuk(String kunci) {
    final l = errors[kunci];
    return l == null || l.isEmpty ? null : l.first;
  }

  /// Galat status ("sudah diputuskan admin lain") — bukan salah isian.
  String? get status => untuk('status');

  static GalatPermintaan dariBody(String pesan, Map<String, dynamic> body) {
    final mentah = body['errors'];
    final hasil = <String, List<String>>{};
    if (mentah is Map) {
      mentah.forEach((k, v) {
        if (v is List) hasil['$k'] = [for (final e in v) '$e'];
        if (v is String) hasil['$k'] = [v];
      });
    }
    return GalatPermintaan(pesan, errors: hasil);
  }

  @override
  String toString() => pesan;
}
