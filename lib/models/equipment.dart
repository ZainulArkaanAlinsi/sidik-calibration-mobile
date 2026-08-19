/// Status alat. `overdue` **nggak bisa dikirim** waktu simpan — backend
/// yang ngitung dari `tanggal_jatuh_tempo` (`docs/kontrak-api.md` §3).
library;
import '../core/utils/parse_list.dart';

enum EquipmentStatus {
  aktif,
  overdue,
  nonaktif;

  static EquipmentStatus fromApi(String value) => switch (value) {
    'aktif' => EquipmentStatus.aktif,
    'overdue' => EquipmentStatus.overdue,
    _ => EquipmentStatus.nonaktif,
  };

  /// Buat tampilan (badge, filter) — tiga-tiganya valid di sini.
  String get rawValue => switch (this) {
    EquipmentStatus.aktif => 'aktif',
    EquipmentStatus.overdue => 'overdue',
    EquipmentStatus.nonaktif => 'nonaktif',
  };

  // Cuma dua nilai yang boleh dikirim ke server (`docs/kontrak-api.md` §3
  // poin 3) — dropdown form nggak pernah nawarin `overdue`, tapi kalau
  // somehow kejadian, jatuhin ke `aktif` daripada 422 diam-diam.
  String toApi() => this == EquipmentStatus.nonaktif ? 'nonaktif' : 'aktif';
}

/// Satu alat ukur — `GET/POST/PUT/DELETE /api/equipments`
/// (`docs/kontrak-api.md` §3). Beda sama [EquipmentLookup] yang cuma
/// ringkasan buat picker: ini model penuh buat layar CRUD Alat.
class Equipment {
  const Equipment({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    required this.kategori,
    required this.status,
    this.merk = '',
    this.model = '',
    this.noIdentifikasi = '',
    this.pelangganId,
    this.pelangganNama,
    this.tanggalKalibrasiTerakhir,
    this.tanggalJatuhTempo,
    this.rangeMin,
    this.rangeMax,
    this.satuan = '',
    this.resolusi,
    this.toleransi,
    this.lokasi = '',
    this.namaAlatKemampuan,
    this.catatan = '',
    this.resolusiRentang = const [],
  });

  final int id;
  final String namaAlat;
  final String serialNumber;

  /// Kode kategori dari `GET /api/categories` (mis. `panjang`,
  /// `instrumen-analitik`) — bukan nama tampilan.
  final String kategori;
  final EquipmentStatus status;

  final String merk;
  final String model;
  final String noIdentifikasi;

  /// Nunjuk ke `CalibrationCapability.namaAlat` (`GET /api/categories/{kode}`)
  /// — biar backend tau CMC mana yang beneran cocok sama jenis alat ini, bukan
  /// cuma kategorinya doang. **Tanpa ini, ketidakpastian sesi kalibrasi alat
  /// ini dihitung pakai jalur generik (standar + resolusi), bukan angka CMC
  /// resmi hasil akreditasi lab** (`GumCalculator::kemampuanUntukTitik()`).
  /// `null` = belum di-link, alat tetap bisa dikalibrasi lewat jalur generik.
  final String? namaAlatKemampuan;

  /// Dipakai buat nulis (`pelanggan_id` di body). Response-nya objek
  /// nested (`pelanggan: {id, nama}`) — [pelangganNama] itu buat tampilan.
  final int? pelangganId;
  final String? pelangganNama;

  final DateTime? tanggalKalibrasiTerakhir;
  final DateTime? tanggalJatuhTempo;

  /// **Bisa `null`** — sebagian alat batasnya bukan angka (lihat catatan
  /// `range_note` di kontrak §3 buat kemampuan kalibrasi). Jangan diparse
  /// paksa jadi `double`.
  final double? rangeMin;
  final double? rangeMax;
  final String satuan;
  final double? resolusi;

  /// Resolusi PER TITIK standar, lengkap sama satuannya — blok "Resolusi Alat"
  /// di lembar kerja kertas.
  ///
  /// Ini sifat ALAT PELANGGAN, bukan sifat sesi: diisi sekali waktu alatnya
  /// didaftarin, dan dari situ diturunkan satuan tiap baris lembar kerja,
  /// jumlah desimal, dan style sertifikat. Teknisi di lapangan nggak ngisi
  /// satuan apa pun.
  ///
  /// Kosong = alat lama / lembar yang nggak butuh per titik; sistem balik ke
  /// [resolusi] tunggal, persis perilaku sebelumnya.
  final List<ResolusiTitik> resolusiRentang;
  final double? toleransi;
  final String lokasi;
  final String catatan;

  Equipment copyWith({
    String? namaAlat,
    String? serialNumber,
    String? kategori,
    EquipmentStatus? status,
    String? merk,
    String? model,
    String? noIdentifikasi,
    int? pelangganId,
    String? pelangganNama,
    double? rangeMin,
    double? rangeMax,
    String? satuan,
    double? resolusi,
    double? toleransi,
    String? lokasi,
    String? namaAlatKemampuan,
    String? catatan,
    List<ResolusiTitik>? resolusiRentang,
  }) => Equipment(
    id: id,
    // Sempat nggak ikut disalin sama sekali, jadi tiap `copyWith` diam-diam
    // ngosongin band per titik alatnya.
    resolusiRentang: resolusiRentang ?? this.resolusiRentang,
    namaAlat: namaAlat ?? this.namaAlat,
    serialNumber: serialNumber ?? this.serialNumber,
    kategori: kategori ?? this.kategori,
    status: status ?? this.status,
    merk: merk ?? this.merk,
    model: model ?? this.model,
    noIdentifikasi: noIdentifikasi ?? this.noIdentifikasi,
    pelangganId: pelangganId ?? this.pelangganId,
    pelangganNama: pelangganNama ?? this.pelangganNama,
    tanggalKalibrasiTerakhir: tanggalKalibrasiTerakhir,
    tanggalJatuhTempo: tanggalJatuhTempo,
    rangeMin: rangeMin ?? this.rangeMin,
    rangeMax: rangeMax ?? this.rangeMax,
    satuan: satuan ?? this.satuan,
    resolusi: resolusi ?? this.resolusi,
    toleransi: toleransi ?? this.toleransi,
    lokasi: lokasi ?? this.lokasi,
    namaAlatKemampuan: namaAlatKemampuan ?? this.namaAlatKemampuan,
    catatan: catatan ?? this.catatan,
  );

  /// Body `POST`/`PUT` — `pelanggan_id`, bukan objek `pelanggan`
  /// (`docs/kontrak-api.md` §3 poin 2). `status` cuma `aktif`/`nonaktif`.
  Map<String, dynamic> toJson() => {
    // Dikirim SELALU, termasuk waktu kosong. Waktu masih `if (isNotEmpty)`,
    // baris terakhir nggak bisa dihapus dari HP: kiriman tanpa kunci ini kebaca
    // "nggak nyentuh band" di backend (`sometimes`), jadi band lamanya balik
    // lagi begitu layarnya di-refresh.
    //
    // Konsekuensinya: siapa pun yang nyusun [Equipment] buat dikirim WAJIB
    // ngisi [resolusiRentang] dari data alat yang lagi diedit, bukan
    // ngebiarinnya default kosong.
    'resolusi_rentang': [for (final r in resolusiRentang) r.toJson()],
    'nama_alat': namaAlat,
    'serial_number': serialNumber,
    'kategori': kategori,
    'status': status.toApi(),
    if (merk.isNotEmpty) 'merk': merk,
    if (model.isNotEmpty) 'model': model,
    if (noIdentifikasi.isNotEmpty) 'no_identifikasi': noIdentifikasi,
    if (pelangganId != null) 'pelanggan_id': pelangganId,
    if (namaAlatKemampuan != null) 'nama_alat_kemampuan': namaAlatKemampuan,
    if (rangeMin != null) 'range_min': rangeMin,
    if (rangeMax != null) 'range_max': rangeMax,
    if (satuan.isNotEmpty) 'satuan': satuan,
    if (resolusi != null) 'resolusi': resolusi,
    if (toleransi != null) 'toleransi': toleransi,
    if (lokasi.isNotEmpty) 'lokasi': lokasi,
    if (catatan.isNotEmpty) 'catatan': catatan,
  };

  factory Equipment.fromJson(Map<String, dynamic> json) {
    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;
    String teks(String key) => json[key] as String? ?? '';

    return Equipment(
      resolusiRentang: parseListAman<ResolusiTitik>(
        json['resolusi_rentang'],
        ResolusiTitik.fromJson,
      ),
      id: (json['id'] as num).toInt(),
      namaAlat: teks('nama_alat'),
      serialNumber: teks('serial_number'),
      kategori: teks('kategori'),
      status: EquipmentStatus.fromApi(json['status'] as String? ?? 'aktif'),
      merk: teks('merk'),
      model: teks('model'),
      noIdentifikasi: teks('no_identifikasi'),
      pelangganId: (pelanggan?['id'] as num?)?.toInt(),
      pelangganNama: pelanggan?['nama'] as String?,
      namaAlatKemampuan: json['nama_alat_kemampuan'] as String?,
      tanggalKalibrasiTerakhir: switch (json['tanggal_kalibrasi_terakhir']) {
        String s => DateTime.tryParse(s),
        _ => null,
      },
      tanggalJatuhTempo: switch (json['tanggal_jatuh_tempo']) {
        String s => DateTime.tryParse(s),
        _ => null,
      },
      rangeMin: (json['range_min'] as num?)?.toDouble(),
      rangeMax: (json['range_max'] as num?)?.toDouble(),
      satuan: teks('satuan'),
      resolusi: (json['resolusi'] as num?)?.toDouble(),
      toleransi: (json['toleransi'] as num?)?.toDouble(),
      lokasi: teks('lokasi'),
      catatan: teks('catatan'),
    );
  }
}

/// Satu halaman hasil `GET /api/equipments` — data + `meta` paginasi Laravel
/// (`docs/kontrak-api.md` §0).
class EquipmentPage {
  const EquipmentPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<Equipment> items;
  final int currentPage;
  final int lastPage;

  factory EquipmentPage.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? const []);
    final meta = json['meta'] as Map<String, dynamic>?;

    return EquipmentPage(
      items: parseListAman(data, Equipment.fromJson),
      currentPage: (meta?['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta?['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Satu baris blok "Resolusi Alat": resolusi baca alat pelanggan, satuan yang
/// TAMPIL di layarnya, dan penanda baris ini berlaku di mana.
///
/// ## Dua bentuk baris, dan kenapa dua-duanya harus utuh
///
/// **Berkunci [titik]** (Conductivity) — dikunci ke nilai nominal larutan (25 /
/// 1412 / 111), karena satuannya campur: `111 mS/cm` secara ANGKA lebih kecil
/// dari `1412 µS/cm` padahal fisiknya hampir 100× lebih besar, jadi ambang
/// numerik bakal nyangkutin titik 111 ke golongan µS/cm.
///
/// **Berkunci [maks]** (Turbidimeter) — ambang numerik: 0–10 NTU resolusi 0,01,
/// dst. `maks: null` = golongan terakhir, nampung sisanya.
///
/// Dua-duanya numpang di kolom yang sama (`equipments.resolusi_rentang`) dan
/// dibedain `Equipment::bandResolusi()` di backend. Model ini WAJIB bisa
/// bulak-balik dua bentuk itu tanpa berubah: sebelum ada [maks] di sini, baris
/// Turbidimeter yang lewat sini kebaca `titik: 0` dan `maks`-nya lenyap — buka
/// form alat, simpan, dan seluruh resolusi bertingkatnya hilang tanpa error.
class ResolusiTitik {
  const ResolusiTitik({
    this.titik,
    this.maks,
    required this.satuan,
    required this.resolusi,
    this.pakaiMaks = false,
  });

  /// Bentuk barisnya dibaca dari KUNCI yang ada, bukan dari nilainya: `maks`
  /// bernilai `null` itu golongan terakhir Turbidimeter yang sah, dan di Dart
  /// nilainya nggak bisa dibedain dari kunci yang nggak ada sama sekali.
  factory ResolusiTitik.fromJson(Map<String, dynamic> json) => ResolusiTitik(
    titik: (json['titik'] as num?)?.toDouble(),
    maks: (json['maks'] as num?)?.toDouble(),
    satuan: json['satuan'] as String? ?? '',
    resolusi: (json['resolusi'] as num?)?.toDouble() ?? 0,
    pakaiMaks: json.containsKey('maks') && json['titik'] == null,
  );

  /// Nilai nominal larutan standar (25 / 1412 / 111). `null` = baris ini
  /// berbentuk [maks].
  final double? titik;

  /// Batas atas pembacaan (INKLUSIF) buat baris berbentuk ambang. `null` +
  /// [pakaiMaks] = golongan terakhir, nampung sisanya.
  final double? maks;

  /// Satuan yang tampil di layar alat pelanggan buat baris ini — `µS/cm` atau
  /// `mS/cm`. INI yang nentuin satuan sertifikat, bukan satuan lembar.
  final String satuan;

  final double resolusi;

  /// `true` = baris ambang (Turbidimeter), `false` = baris titik standar
  /// (Conductivity).
  final bool pakaiMaks;

  ResolusiTitik salin({
    double? titik,
    double? maks,
    String? satuan,
    double? resolusi,
    bool? pakaiMaks,
  }) {
    final bentukMaks = pakaiMaks ?? this.pakaiMaks;

    return ResolusiTitik(
      // Bentuknya yang nentuin kunci mana yang hidup — baris yang dipindah dari
      // titik ke ambang nggak boleh bawa sisa `titik` lamanya, karena di
      // backend band ber-`titik` selalu menang dan `maks`-nya bakal diabaikan
      // diam-diam.
      titik: bentukMaks ? null : (titik ?? this.titik),
      maks: bentukMaks ? (maks ?? this.maks) : null,
      satuan: satuan ?? this.satuan,
      resolusi: resolusi ?? this.resolusi,
      pakaiMaks: bentukMaks,
    );
  }

  /// Cuma kunci yang relevan sama bentuk barisnya yang dikirim. Ngirim dua-
  /// duanya bikin backend nolak (`EquipmentRequest::after()`).
  Map<String, dynamic> toJson() => {
    if (pakaiMaks) 'maks': maks else 'titik': titik,
    'satuan': satuan,
    'resolusi': resolusi,
  };
}
