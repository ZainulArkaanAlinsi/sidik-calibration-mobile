import '../core/utils/parse_list.dart';

/// Satu tingkat garis waktu arsip (`GET /api/arsip/garis-waktu`).
enum TingkatGarisWaktu {
  tahun,
  bulan,
  pekan,
  hari;

  static TingkatGarisWaktu? dariKode(String? kode) => switch (kode) {
    'tahun' => TingkatGarisWaktu.tahun,
    'bulan' => TingkatGarisWaktu.bulan,
    'pekan' => TingkatGarisWaktu.pekan,
    'hari' => TingkatGarisWaktu.hari,
    _ => null,
  };
}

/// Tanggal kalender polos (`"2026-11-12"`) → `DateTime` tanggal itu juga.
///
/// Dipecah per bagian dan TIDAK lewat `DateTime.parse`/`toLocal()`: kolomnya
/// tanggal tanpa jam, dan menggesernya lewat UTC mundurkan harinya di Jakarta
/// (kontrak arsip-cari §0 butir 4). Bagian jam kalau ada dibuang.
DateTime? tanggalPolos(Object? mentah) {
  if (mentah is! String) return null;
  final cocok = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(mentah);
  if (cocok == null) return null;

  final tahun = int.parse(cocok.group(1)!);
  final bulan = int.parse(cocok.group(2)!);
  final hari = int.parse(cocok.group(3)!);
  final tanggal = DateTime(tahun, bulan, hari);

  // `DateTime(2026, 2, 31)` diam-diam jadi 3 Maret; tanggal yang tidak ada di
  // kalender dianggap tidak terbaca, bukan dibetulkan.
  if (tanggal.month != bulan || tanggal.day != hari) return null;
  return tanggal;
}

int? _bulat(Object? mentah) => switch (mentah) {
  final num angka => angka.toInt(),
  final String teks => int.tryParse(teks),
  _ => null,
};

/// Alamat satu tingkat: persis isi `telusuri` yang dikirim server.
///
/// Parameternya disimpan APA ADANYA (nilai dijadikan teks), bukan dipecah
/// jadi tahun/bulan/pekan di sini: kontrak melarang app menyusun parameter
/// sendiri, dan menyalin kunci yang tidak dikenal lebih aman daripada
/// membuangnya diam-diam.
class PosisiGarisWaktu {
  const PosisiGarisWaktu._(this.parameter);

  /// Tingkat tahun, tanpa induk — titik awal garis waktu.
  static const akar = PosisiGarisWaktu._({'tingkat': 'tahun'});

  /// Dari `kelompok[].telusuri`. Null kalau bukan peta atau tanpa `tingkat`
  /// yang dikenal.
  static PosisiGarisWaktu? dariTelusuri(Object? mentah) {
    if (mentah is! Map) return null;

    final parameter = <String, String>{};
    for (final entri in mentah.entries) {
      final nilai = entri.value;
      if (entri.key is! String || (nilai is! String && nilai is! num)) {
        continue;
      }
      parameter[entri.key as String] = nilai.toString();
    }

    if (TingkatGarisWaktu.dariKode(parameter['tingkat']) == null) return null;
    return PosisiGarisWaktu._(Map.unmodifiable(parameter));
  }

  final Map<String, String> parameter;

  TingkatGarisWaktu get tingkat =>
      TingkatGarisWaktu.dariKode(parameter['tingkat']) ??
      TingkatGarisWaktu.tahun;

  @override
  bool operator ==(Object other) {
    if (other is! PosisiGarisWaktu) return false;
    if (other.parameter.length != parameter.length) return false;
    for (final entri in parameter.entries) {
      if (other.parameter[entri.key] != entri.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    parameter.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Satu kelompok (tahun, bulan, pekan, atau hari). Label, jumlah, dan rentang
/// semuanya dari server — app tidak menghitung apa pun di sini.
class KelompokGarisWaktu {
  const KelompokGarisWaktu({
    required this.kunci,
    required this.label,
    required this.jumlah,
    this.mulai,
    this.selesai,
    this.telusuri,
  });

  final String kunci;

  /// Sudah berbahasa Indonesia dari server (`Pekan 46 (9–15 Nov 2026)`).
  final String label;
  final int jumlah;

  /// Rentang kelompok. Untuk pekan sudah dipotong ke bulannya.
  final DateTime? mulai;
  final DateTime? selesai;

  /// Alamat tingkat berikutnya; null kalau server tidak mengirimnya.
  final PosisiGarisWaktu? telusuri;

  factory KelompokGarisWaktu.fromJson(Map<String, dynamic> json) =>
      KelompokGarisWaktu(
        kunci: json['kunci'] as String,
        label: json['label'] as String? ?? json['kunci'] as String,
        jumlah: _bulat(json['jumlah']) ?? 0,
        mulai: tanggalPolos(json['mulai']),
        selesai: tanggalPolos(json['selesai']),
        telusuri: PosisiGarisWaktu.dariTelusuri(json['telusuri']),
      );
}

/// Satu dokumen pada tingkat `hari`.
class ItemGarisWaktu {
  const ItemGarisWaktu({
    required this.id,
    required this.nomor,
    required this.status,
    this.revisiKe,
    this.tanggal,
    this.namaAlat,
    this.nomorSeri,
    this.perusahaan,
    this.pelangganId,
    this.nomorOrder,
    this.sesiId,
    this.pdfUrl,
  });

  final int id;
  final String nomor;

  /// `terbit`, `dibatalkan`, atau `ditarik` — teks mentah, nilai baru dari
  /// server tetap tampil apa adanya.
  final String status;

  /// Null = terbitan pertama.
  final int? revisiKe;

  /// Tanggal terbit.
  final DateTime? tanggal;
  final String? namaAlat;

  /// Yang diketik teknisi di lembar lebih dulu, baru data alat (urutan dari
  /// server).
  final String? nomorSeri;
  final String? perusahaan;
  final int? pelangganId;
  final String? nomorOrder;

  /// Sesi kalibrasi asal dokumen; dipakai membuka detail.
  final int? sesiId;
  final String? pdfUrl;

  factory ItemGarisWaktu.fromJson(Map<String, dynamic> json) {
    // String kosong dianggap tidak ada, supaya tidak menampilkan baris label
    // kosong ("S/N ").
    String? isi(Object? mentah) =>
        mentah is String && mentah.trim().isNotEmpty ? mentah : null;

    return ItemGarisWaktu(
      id: _bulat(json['id'])!,
      nomor: json['nomor'] as String? ?? '',
      status: json['status'] as String? ?? '',
      revisiKe: _bulat(json['revisi_ke']),
      tanggal: tanggalPolos(json['tanggal']),
      namaAlat: isi(json['nama_alat']),
      nomorSeri: isi(json['serial_number']),
      perusahaan: isi(json['perusahaan']),
      pelangganId: _bulat(json['customer_id']),
      nomorOrder: isi(json['nomor_order']),
      sesiId: _bulat(json['calibration_session_id']),
      pdfUrl: isi(json['pdf_url']),
    );
  }
}

/// Jawaban satu panggilan garis waktu: kelompok tingkat ini, plus (tingkat
/// `hari` saja) satu halaman dokumen.
class HalamanGarisWaktu {
  const HalamanGarisWaktu({
    required this.tingkat,
    required this.totalDokumen,
    required this.kelompok,
    required this.item,
    this.halaman = 1,
    this.halamanTerakhir = 1,
    this.totalItem = 0,
  });

  final TingkatGarisWaktu tingkat;

  /// Jumlah dokumen dalam lingkup ini (sesudah saringan PT), dari server.
  final int totalDokumen;
  final List<KelompokGarisWaktu> kelompok;
  final List<ItemGarisWaktu> item;

  /// Paginasi `item` — `meta` di jawaban server.
  final int halaman;
  final int halamanTerakhir;
  final int totalItem;

  /// Bentuk jawaban `{data: {...}, meta: {...}}`. Melempar [FormatException]
  /// kalau `data` tidak berbentuk garis waktu, supaya server lama yang
  /// menjawab bentuk lain tidak terbaca sebagai "kosong".
  factory HalamanGarisWaktu.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('Jawaban garis waktu tanpa `data`.');
    }
    final tingkat = TingkatGarisWaktu.dariKode(data['tingkat'] as String?);
    if (tingkat == null || data['kelompok'] is! List) {
      throw const FormatException('Jawaban garis waktu tidak dikenal.');
    }

    final meta = json['meta'];
    int dariMeta(String kunci, int cadangan) =>
        meta is Map ? (_bulat(meta[kunci]) ?? cadangan) : cadangan;

    return HalamanGarisWaktu(
      tingkat: tingkat,
      totalDokumen: _bulat(data['total_dokumen']) ?? 0,
      kelompok: parseListAman(data['kelompok'], KelompokGarisWaktu.fromJson),
      item: parseListAman(data['item'], ItemGarisWaktu.fromJson),
      halaman: dariMeta('current_page', 1),
      halamanTerakhir: dariMeta('last_page', 1),
      totalItem: dariMeta('total', 0),
    );
  }
}
