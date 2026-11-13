import '../core/utils/parse_list.dart';
import '../core/utils/tanggal_api.dart';
import '../models/calibration_history_item.dart';
import '../models/garis_waktu_arsip.dart';
import '../models/pencarian_arsip.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Arsip menurut waktu + pencarian terpadu (kontrak
/// `docs/perintah-frontend-arsip-cari.md` di repo API).
///
/// Dua rute, satu aturan: kata cari dikirim APA ADANYA dan semua penyaringan,
/// pengelompokan, dan peringkat dikerjakan server. Teknisi hanya mendapat
/// dokumen dari sesinya sendiri — server yang menegakkannya, bukan parameter
/// dari sini.
abstract class ArsipCariService {
  /// `GET /api/arsip/garis-waktu` untuk satu tingkat.
  ///
  /// [posisi] adalah `telusuri` milik kelompok yang dibuka (atau
  /// [PosisiGarisWaktu.akar]); [halaman] hanya berarti di tingkat `hari`,
  /// yang dokumennya berpaginasi.
  Future<HalamanGarisWaktu> garisWaktu(
    String token, {
    required PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman = 1,
  });

  /// `GET /api/calibrations?bentuk=ringan` dengan saringan [filter].
  Future<HalamanRiwayat> cariRiwayat(
    String token, {
    required FilterArsip filter,
    int halaman = 1,
  });
}

class ApiArsipCariService implements ArsipCariService {
  ApiArsipCariService(this._api);

  final ApiClient _api;

  /// Batas atas `per_page` di server; 50 baris ringan per tarikan.
  static const perHalamanRiwayat = 50;

  /// `Uri(queryParameters:)` yang meng-encode: `/` jadi `%2F` dan spasi jadi
  /// `+`, jadi `CAL/2026/10/0001` sampai ke server utuh.
  static String _alamat(String path, Map<String, String> query) =>
      '$path?${Uri(queryParameters: query).query}';

  @override
  Future<HalamanGarisWaktu> garisWaktu(
    String token, {
    required PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman = 1,
  }) async {
    final query = <String, String>{
      ...posisi.parameter,
      'customer_id': ?pelangganId?.toString(),
      if (halaman > 1) 'page': '$halaman',
    };

    final Map<String, dynamic> json;
    try {
      json = await _api.get(_alamat('/arsip/garis-waktu', query), token: token);
    } on ApiException catch (e) {
      // Rutenya belum ada di server ini.
      if (e.status == 404) throw const ServerBelumMendukungArsipException();
      rethrow;
    }

    try {
      return HalamanGarisWaktu.fromJson(json);
    } on FormatException {
      throw const ServerBelumMendukungArsipException();
    }
  }

  @override
  Future<HalamanRiwayat> cariRiwayat(
    String token, {
    required FilterArsip filter,
    int halaman = 1,
  }) async {
    final query = <String, String>{
      'bentuk': 'ringan',
      'per_page': '$perHalamanRiwayat',
      'page': '$halaman',
      'q': ?filter.kataKirim,
      if (filter.dari != null) 'dari': tanggalApi(filter.dari!),
      if (filter.sampai != null) 'sampai': tanggalApi(filter.sampai!),
      'customer_id': ?filter.pelangganId?.toString(),
    };

    final json = await _api.get(_alamat('/calibrations', query), token: token);

    // Server lama mengabaikan parameter baru dan menjawab 15 baris dengan
    // saringan tak terpakai. Daftar seperti itu tidak boleh tampil sebagai
    // hasil cari — `per_page` yang dikembalikan `meta` adalah buktinya.
    final meta = json['meta'];
    final perHalaman = meta is Map ? (meta['per_page'] as num?)?.toInt() : null;
    if (perHalaman != perHalamanRiwayat) {
      throw const ServerBelumMendukungArsipException();
    }

    final baris = parseListAman(json['data'], CalibrationHistoryItem.fromJson);
    return HalamanRiwayat(
      baris: baris,
      halaman: (meta['current_page'] as num?)?.toInt() ?? halaman,
      halamanTerakhir: (meta['last_page'] as num?)?.toInt() ?? halaman,
      total: (meta['total'] as num?)?.toInt() ?? baris.length,
    );
  }
}

/// Data tiruan — dipakai test dan mode mock. Mencatat tiap panggilan supaya
/// test bisa memeriksa PARAMETER yang dikirim, bukan cuma hasil yang kembali.
class MockArsipCariService implements ArsipCariService {
  MockArsipCariService({
    this.kosong = false,
    this.gagal = false,
    this.jeda = Duration.zero,
    List<CalibrationHistoryItem>? sesi,
  }) : sesi = sesi ?? _sesiContoh;

  /// Arsip yang belum berisi apa-apa.
  final bool kosong;
  final bool gagal;
  final Duration jeda;
  final List<CalibrationHistoryItem> sesi;

  final panggilanGarisWaktu =
      <({PosisiGarisWaktu posisi, int? pelangganId, int halaman})>[];
  final panggilanRiwayat = <({FilterArsip filter, int halaman})>[];

  @override
  Future<HalamanGarisWaktu> garisWaktu(
    String token, {
    required PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman = 1,
  }) async {
    panggilanGarisWaktu.add((
      posisi: posisi,
      pelangganId: pelangganId,
      halaman: halaman,
    ));
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (gagal) throw Exception('server nggak nyaut');

    if (kosong) {
      return HalamanGarisWaktu(
        tingkat: posisi.tingkat,
        totalDokumen: 0,
        kelompok: const [],
        item: const [],
      );
    }

    return switch (posisi.parameter) {
      {'tingkat': 'tahun'} => _tahun,
      {'tingkat': 'bulan', 'tahun': '2026'} => _bulan,
      {'tingkat': 'pekan', 'tahun': '2026', 'bulan': '11'} => _pekan,
      {'tingkat': 'hari', 'tahun': '2026', 'bulan': '11', 'pekan': '46'} =>
        _hari,
      _ => HalamanGarisWaktu(
        tingkat: posisi.tingkat,
        totalDokumen: 0,
        kelompok: const [],
        item: const [],
      ),
    };
  }

  @override
  Future<HalamanRiwayat> cariRiwayat(
    String token, {
    required FilterArsip filter,
    int halaman = 1,
  }) async {
    panggilanRiwayat.add((filter: filter, halaman: halaman));
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (gagal) throw Exception('server nggak nyaut');

    final cocok = [
      if (!kosong)
        for (final s in sesi)
          if (s.cocokDengan(filter.kataKirim ?? '')) s,
    ];
    return HalamanRiwayat(
      baris: cocok,
      halaman: halaman,
      halamanTerakhir: 1,
      total: cocok.length,
    );
  }

  // Bentuk dan label disalin dari contoh di kontrak arsip-cari §3.
  static final _tahun = HalamanGarisWaktu(
    tingkat: TingkatGarisWaktu.tahun,
    totalDokumen: 6,
    kelompok: [
      _kelompok('2026', '2026', 5, {'tingkat': 'bulan', 'tahun': 2026}),
      _kelompok('2025', '2025', 1, {'tingkat': 'bulan', 'tahun': 2025}),
    ],
    item: const [],
  );

  static final _bulan = HalamanGarisWaktu(
    tingkat: TingkatGarisWaktu.bulan,
    totalDokumen: 5,
    kelompok: [
      _kelompok('2026-11', 'November 2026', 4, {
        'tingkat': 'pekan',
        'tahun': 2026,
        'bulan': 11,
      }),
      _kelompok('2026-10', 'Oktober 2026', 1, {
        'tingkat': 'pekan',
        'tahun': 2026,
        'bulan': 10,
      }),
    ],
    item: const [],
  );

  static final _pekan = HalamanGarisWaktu(
    tingkat: TingkatGarisWaktu.pekan,
    totalDokumen: 4,
    kelompok: [
      _kelompok('2026-W46', 'Pekan 46 (9–15 Nov 2026)', 3, {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
      }),
      _kelompok('2026-W44', 'Pekan 44 (1 Nov 2026)', 1, {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 44,
      }),
    ],
    item: const [],
  );

  static final _hari = HalamanGarisWaktu(
    tingkat: TingkatGarisWaktu.hari,
    totalDokumen: 3,
    kelompok: [
      _kelompok('2026-11-12', 'Kamis, 12 Nov 2026', 2, {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
        'tanggal': '2026-11-12',
      }),
      _kelompok('2026-11-09', 'Senin, 9 Nov 2026', 1, {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
        'tanggal': '2026-11-09',
      }),
    ],
    item: [
      ItemGarisWaktu(
        id: 6,
        nomor: 'CAL/2026/11/0005',
        status: 'terbit',
        tanggal: DateTime(2026, 11, 12),
        namaAlat: 'Micrometer',
        nomorSeri: 'SN-0205',
        perusahaan: 'PT Contoh Alfa',
        pelangganId: 1,
        sesiId: 6,
      ),
      ItemGarisWaktu(
        id: 5,
        nomor: 'CAL/2026/11/0004',
        status: 'terbit',
        tanggal: DateTime(2026, 11, 12),
        namaAlat: 'Jangka Sorong',
        nomorSeri: 'SN-0204',
        perusahaan: 'PT Contoh Alfa',
        pelangganId: 1,
        nomorOrder: 'PO-2026-0042',
        sesiId: 5,
      ),
    ],
    totalItem: 3,
  );

  static KelompokGarisWaktu _kelompok(
    String kunci,
    String label,
    int jumlah,
    Map<String, Object> telusuri,
  ) => KelompokGarisWaktu(
    kunci: kunci,
    label: label,
    jumlah: jumlah,
    telusuri: PosisiGarisWaktu.dariTelusuri(telusuri),
  );

  static final _sesiContoh = [
    CalibrationHistoryItem(
      id: 5,
      namaAlat: 'Jangka Sorong',
      namaTeknisi: 'Dr. Arch Schaefer',
      tanggalKalibrasi: DateTime(2026, 11, 11),
      status: CalibrationStatus.disetujui,
      keputusan: Keputusan.pass,
      nomorSesi: 'KAL/2026/11/9005',
      nomorSeri: 'SN-0204',
      namaPelanggan: 'PT Contoh Alfa',
      nomorSertifikat: 'CAL/2026/11/0004',
      statusSertifikat: 'terbit',
      nomorOrder: 'PO-2026-0042',
      nomorOrderDiketahui: true,
    ),
  ];
}
