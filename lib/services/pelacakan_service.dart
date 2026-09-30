import '../models/pelacakan.dart';
import 'api_client.dart';

/// Pelacakan paket alat (poin 1 & 7). Baca: semua peran lab. Serah terima
/// (`tahap-fisik`): admin & super admin.
abstract class PelacakanService {
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  });

  Future<(PaketLacak, List<LangkahGarisWaktu>)> detail(String token, int id);

  /// [tahap] `siap_diambil` / `diserahkan`. Waktu diserahkan, [kepada] wajib —
  /// server menolak tanpanya, karena "sudah diserahkan" tanpa nama penerima
  /// tidak bisa dipertanggungjawabkan.
  Future<void> tandaiTahapFisik(
    String token,
    int itemId, {
    required String tahap,
    String? kepada,
  });
}

class ApiPelacakanService implements PelacakanService {
  ApiPelacakanService(this._api);

  final ApiClient _api;

  @override
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  }) async {
    final query = <String, String>{
      if (cari != null && cari.trim().isNotEmpty) 'q': cari.trim(),
      if (terlambat) 'terlambat': '1',
    };
    final path = query.isEmpty
        ? '/pelacakan'
        : '/pelacakan?${query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final json = await _api.get(path, token: token);
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final d in data.whereType<Map<String, dynamic>>())
        PaketLacak.fromJson(d),
    ];
  }

  @override
  Future<(PaketLacak, List<LangkahGarisWaktu>)> detail(
    String token,
    int id,
  ) async {
    final json = await _api.get('/pelacakan/$id', token: token);
    final paket = PaketLacak.fromJson(json['data'] as Map<String, dynamic>);
    final garis = [
      for (final g in (json['garis_waktu'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        LangkahGarisWaktu.fromJson(g),
    ];
    return (paket, garis);
  }

  @override
  Future<void> tandaiTahapFisik(
    String token,
    int itemId, {
    required String tahap,
    String? kepada,
  }) async {
    await _api.post(
      '/pelacakan/item/$itemId/tahap-fisik',
      token: token,
      body: {
        'tahap_fisik': tahap,
        if (kepada != null && kepada.trim().isNotEmpty)
          'diserahkan_kepada': kepada.trim(),
      },
    );
  }
}

class MockPelacakanService implements PelacakanService {
  static final _paket = [
    PaketLacak(
      id: 34,
      nomor: 'ORD/2026/09/0034',
      pelanggan: 'PT Tirta Mandiri Laboratorium',
      tanggalMasuk: DateTime(2026, 9, 22),
      tanggalJanjiSelesai: DateTime(2026, 9, 30),
      tahap: 'dikalibrasi',
      tahapLabel: 'Dikalibrasi',
      jumlahAlat: 3,
      jumlahSelesai: 1,
      alat: const [
        AlatDalamPaket(
          itemId: 1,
          nama: 'Timbangan Analitik',
          merk: 'Ohaus PX224',
          serialNumber: 'C3349',
          teknisi: 'RZP',
          tahap: 'sertifikat_terbit',
          tahapLabel: 'Sertifikat terbit',
          nomorSertifikat: 'CAL/2026/09/0141',
          keputusan: 'PASS',
        ),
        AlatDalamPaket(
          itemId: 2,
          nama: 'pH Meter',
          merk: 'Hanna HI2211',
          serialNumber: 'HI2211-0419',
          teknisi: 'RZP',
          tahap: 'menunggu_pengesahan',
          tahapLabel: 'Menunggu pengesahan',
        ),
        AlatDalamPaket(
          itemId: 3,
          nama: 'Thermohygrometer',
          merk: 'Lutron HT-3007',
          serialNumber: 'L-3007-118',
          teknisi: 'HWJ',
          tahap: 'dikalibrasi',
          tahapLabel: 'Dikalibrasi',
        ),
      ],
    ),
  ];

  @override
  Future<List<PaketLacak>> daftar(
    String token, {
    String? cari,
    bool terlambat = false,
  }) async => _paket;

  @override
  Future<(PaketLacak, List<LangkahGarisWaktu>)> detail(
    String token,
    int id,
  ) async => (
    _paket.firstWhere((p) => p.id == id),
    const [
      LangkahGarisWaktu(kode: 'diterima', label: 'Diterima', lewat: true, sekarang: false),
      LangkahGarisWaktu(kode: 'dikalibrasi', label: 'Dikalibrasi', lewat: false, sekarang: true),
      LangkahGarisWaktu(kode: 'menunggu_pemeriksaan', label: 'Menunggu pemeriksaan admin', lewat: false, sekarang: false),
      LangkahGarisWaktu(kode: 'menunggu_pengesahan', label: 'Menunggu pengesahan', lewat: false, sekarang: false),
      LangkahGarisWaktu(kode: 'sertifikat_terbit', label: 'Sertifikat terbit', lewat: false, sekarang: false),
      LangkahGarisWaktu(kode: 'siap_diambil', label: 'Siap diambil', lewat: false, sekarang: false),
      LangkahGarisWaktu(kode: 'diserahkan', label: 'Diserahkan', lewat: false, sekarang: false),
    ],
  );

  @override
  Future<void> tandaiTahapFisik(
    String token,
    int itemId, {
    required String tahap,
    String? kepada,
  }) async {}
}
