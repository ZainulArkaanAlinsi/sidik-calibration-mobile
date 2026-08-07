import 'mock_store.dart';
import '../models/calibration_detail.dart';
import '../core/utils/parse_list.dart';
import '../models/calibration_history_item.dart';
import 'api_client.dart';

abstract class HistoryService {
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token);

  /// Antrean approval admin: **semua kiriman dari semua teknisi**, bukan cuma
  /// punya sendiri (`GET /api/calibrations?status=menunggu_approval`).
  ///
  /// Beda dari [ambilRiwayat] yang nggak nyaring status. Teknisi yang nembak ini
  /// tetap cuma dapat sesi miliknya — penyaringnya di controller backend,
  /// bukan di query param dari mobile.
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(String token);

  /// `GET /api/calibrations/{id}` — versi lengkap satu sesi, termasuk
  /// breakdown per titik ukur (`docs/kontrak-api.md` §4).
  Future<CalibrationDetail> ambilDetail(String token, int id);
}

/// Nembak `GET /api/calibrations` (live sejak 14 Jul,
/// `docs/kontrak-api.md` §4).
///
/// Teknisi **selalu** dapat sesi miliknya doang, apa pun query-nya — yang
/// nyaring controller backend, bukan parameter dari mobile.
class ApiHistoryService implements HistoryService {
  ApiHistoryService(this._api);

  final ApiClient _api;

  /// Riwayat kalibrasi.
  ///
  /// **`mine=true` sengaja NGGAK dikirim.** Dulu dikirim, dan itu bikin Riwayat
  /// KOSONG buat admin: `mine=true` nyaring ke sesi milik si pemanggil, dan
  /// admin nggak pernah bikin sesi sendiri. Dari layar kelihatannya "Riwayat
  /// nggak bisa dibuka" — padahal kebuka, cuma isinya nol.
  ///
  /// Aman buat teknisi: backend NGGAK percaya parameter ini apa adanya —
  /// `CalibrationController::index()` maksa saring `teknisi_id` buat role
  /// teknisi apa pun isi query-nya, justru biar teknisi nggak bisa ngintip
  /// kerjaan orang lain dengan ngirim `mine=false`. Jadi tanpa parameter ini
  /// teknisi tetap lihat punyanya sendiri, dan admin lihat semuanya.
  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) =>
      _semuaHalaman('/calibrations', token);

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(String token) =>
      _semuaHalaman('/calibrations?status=menunggu_approval', token);

  /// Batas pengaman kalau `meta` dari server ngaco — 20 × 15 = 300 sesi.
  /// Tanpa ini, `last_page` yang salah bisa bikin app nembak server terus
  /// sampai teknisi kehabisan kuota.
  static const _maksHalaman = 20;

  /// Tarik SEMUA halaman, bukan cuma halaman pertama.
  ///
  /// `CalibrationController::index()` di backend itu `paginate(15)`. Dulu di
  /// sini cuma `json['data']` yang dibaca dan `meta`-nya diabaikan, jadi
  /// mobile berhenti di 15 baris tanpa ada cara apa pun buat lihat sisanya —
  /// nggak ada tombol "muat lagi" di layar mana pun.
  ///
  /// Dua akibatnya nyata:
  ///
  /// - **Antrean approval bohong.** Kartu dashboard ngitung `count()` PENUH
  ///   (`DashboardController`), sementara layar antrean cuma sanggup nampilin
  ///   15. Admin baca "23 menunggu approval" lalu ngeliat 15 baris, dan 8
  ///   kiriman teknisi nggak bisa disentuh sama sekali.
  /// - **Riwayat teknisi kepotong** di 15 sesi terakhir; sesi lama ilang dari
  ///   layar walaupun ada di server.
  ///
  /// Nggak kekejar test karena semua mock balikin daftar pendek dalam satu
  /// halaman — 15 baris itu batas yang cuma kelihatan di lab yang lagi ramai.
  Future<List<CalibrationHistoryItem>> _semuaHalaman(
    String path,
    String token,
  ) async {
    final hasil = <CalibrationHistoryItem>[];
    final pemisah = path.contains('?') ? '&' : '?';

    for (var halaman = 1; halaman <= _maksHalaman; halaman++) {
      final json = await _api.get('$path${pemisah}page=$halaman', token: token);
      hasil.addAll(
        parseListAman(json['data'], CalibrationHistoryItem.fromJson),
      );

      final meta = json['meta'];
      final terakhir = meta is Map ? (meta['last_page'] as num?)?.toInt() : null;

      // `meta` nggak ada = server lama yang nggak paginate: apa yang kebaca
      // barusan itu semuanya, jangan nembak halaman kedua.
      if (terakhir == null || halaman >= terakhir) break;
    }

    return hasil;
  }

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    final json = await _api.get('/calibrations/$id', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return CalibrationDetail.fromJson(data);
  }
}

/// Data tiruan — sekarang cuma dipakai **test**, sama kayak
/// `MockDashboardService` (`GET /api/calibrations` udah live).
class MockHistoryService implements HistoryService {
  MockHistoryService({
    this.kosong = false,
    this.gagal = false,
    this.jeda = Duration.zero,
  });

  final bool kosong;
  final bool gagal;
  final Duration jeda;

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async {
    final semua = await ambilRiwayat(token);
    return semua
        .where((s) => s.status == CalibrationStatus.menungguApproval)
        .toList();
  }

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);

    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return const [];

    return sesiMock();
  }

  /// Semua sesi yang kelihatan di build mock: yang dikirim lewat app
  /// ([MockStore]) + contoh bawaan.
  ///
  /// Dipisah jadi fungsi supaya **angka di dashboard dihitung dari daftar yang
  /// SAMA**. Sebelum ini dashboard nulis `menunggu_approval: 5` apa adanya
  /// sementara antreannya cuma punya 1 sesi berstatus itu — dua angka di satu
  /// layar yang saling membantah, dan badge-nya nggak ikut naik waktu teknisi
  /// ngirim lembar baru.
  static List<CalibrationHistoryItem> sesiMock() {
    final sekarang = DateTime.now();

    return [
      // Sesi yang barusan dikirim teknisi ditaruh paling depan — itu yang
      // dicari orang, bukan contoh bawaan. Kosong kalau belum ada yang ngirim.
      ...MockStore.instance.sesi,
      CalibrationHistoryItem(
        id: 1,
        namaAlat: 'Jangka Sorong Mitutoyo',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 1)),
        status: CalibrationStatus.disetujui,
        keputusan: Keputusan.pass,
        nomorSertifikat: 'CAL/2026/07/0001',
        certificateId: 901,
      ),
      CalibrationHistoryItem(
        id: 2,
        namaAlat: 'Timbangan Digital Ohaus',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 3)),
        status: CalibrationStatus.disetujui,
        keputusan: Keputusan.fail,
        nomorSertifikat: 'CAL/2026/07/0004',
        certificateId: 902,
      ),
      CalibrationHistoryItem(
        id: 3,
        namaAlat: 'Termometer Digital Fluke',
        namaTeknisi: 'Sari',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 5)),
        status: CalibrationStatus.menungguApproval,
      ),
      CalibrationHistoryItem(
        id: 4,
        namaAlat: 'Multimeter Fluke 87V',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 6)),
        status: CalibrationStatus.perluRevisi,
      ),
      CalibrationHistoryItem(
        id: 5,
        namaAlat: 'Pressure Gauge WIKA',
        namaTeknisi: 'Sari',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 9)),
        status: CalibrationStatus.draft,
      ),

      // Pelengkap supaya jumlah per status MASUK AKAL & bisa dihitung sendiri
      // di layar: 5 menunggu approval, 2 draft, 18 selesai.
      //
      // Bukan sekadar biar angka dashboard cocok — badge "5" di sidebar itu
      // janji ke admin bahwa ada 5 yang nunggu. Waktu antreannya cuma nampilin
      // 1 baris, yang salah bukan badge-nya doang: admin nggak tau lagi mana
      // yang bisa dipercaya.
      for (var i = 0; i < 4; i++)
        CalibrationHistoryItem(
          id: 20 + i,
          namaAlat: _alatContoh[i % _alatContoh.length],
          namaTeknisi: i.isEven ? 'Andi' : 'Sari',
          tanggalKalibrasi: sekarang.subtract(Duration(days: 2 + i)),
          status: CalibrationStatus.menungguApproval,
        ),
      CalibrationHistoryItem(
        id: 30,
        namaAlat: 'Oven Memmert UN55',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 11)),
        status: CalibrationStatus.draft,
      ),
      for (var i = 0; i < 16; i++)
        CalibrationHistoryItem(
          id: 40 + i,
          namaAlat: _alatContoh[i % _alatContoh.length],
          namaTeknisi: i.isEven ? 'Sari' : 'Andi',
          tanggalKalibrasi: sekarang.subtract(Duration(days: 14 + i * 3)),
          status: CalibrationStatus.disetujui,
          keputusan: i % 7 == 0 ? Keputusan.fail : Keputusan.pass,
          nomorSertifikat: 'CAL/2026/0${(i % 7) + 1}/${(i + 10).toString().padLeft(4, '0')}',
          certificateId: 910 + i,
        ),
    ];
  }

  /// Nama alat buat sesi pelengkap — diputer biar riwayatnya nggak kelihatan
  /// satu alat doang.
  static const _alatContoh = [
    'pH Meter Mettler Toledo',
    'Turbidimeter HACH 2100Q',
    'Chlorine Meter Hanna HI97711',
    'Timbangan Digital Ohaus',
    'Termometer Digital Fluke',
    'Jangka Sorong Mitutoyo',
  ];

  /// Titik contoh angkanya diambil dari `PERHITUNGAN.csv` master worksheet
  /// pH (`Project-PT-Sidik/Master Olah Data_pH for trial_CSV`) — biar layar
  /// detail bisa dites pakai angka yang realistis, bukan asal-asalan. Bentuk
  /// field-nya dikunci ke `CalibrationResource::toArray()` backend
  /// (`sidik-calibration-api`, commit `06af54e`).
  static const _titikContoh = [
    MeasurementResult(
      titikKe: 1,
      titikUkur: 4.009244572,
      rataRata: 4,
      error: -0.009244572,
      koreksi: 0.009244572,
      standarDeviasi: 0,
      jumlahPengulangan: 5,
      typeA: 0,
      typeB: 0.01171610510631313,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 4 (U=0.02 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.01,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.01171610510631313,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02343221021262627,
      toleransi: 0.05,
      keputusan: Keputusan.pass,
      standarAcuan: StandardRef(id: 2, nama: 'pH Buffer Solution 4', noSertifikat: 'HC32513535'),
    ),
    MeasurementResult(
      titikKe: 2,
      titikUkur: 6.9889072,
      rataRata: 7.004,
      error: 0.0150928,
      koreksi: -0.0150928,
      standarDeviasi: 0.005477225575051544,
      jumlahPengulangan: 5,
      typeA: 0.005477225575051544,
      typeB: 0.01047,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 7 (U=0.02 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.01,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.010714869473539,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02110894987572546,
      toleransi: 0.05,
      keputusan: Keputusan.pass,
      standarAcuan: StandardRef(id: 3, nama: 'pH Buffer Solution 7', noSertifikat: 'HC46341939'),
    ),
    MeasurementResult(
      titikKe: 3,
      titikUkur: 9.9788769,
      rataRata: 10.11,
      error: 0.1311231,
      koreksi: -0.1311231,
      standarDeviasi: 0,
      jumlahPengulangan: 5,
      typeA: 0,
      typeB: 0.0157,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 10 (U=0.024 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.012,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.0157,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.031,
      toleransi: 0.05,
      keputusan: Keputusan.fail,
      standarAcuan: StandardRef(id: 4, nama: 'pH Buffer Solution 10', noSertifikat: 'HC45400338'),
    ),
  ];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (gagal) throw Exception('server nggak nyaut');

    final riwayat = await ambilRiwayat(token);
    final item = riwayat.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Sesi kalibrasi nggak ketemu.'),
    );

    final sudahDihitung =
        item.status == CalibrationStatus.disetujui ||
        item.status == CalibrationStatus.menungguApproval;

    return CalibrationDetail(
      id: item.id,
      namaAlat: item.namaAlat,
      namaTeknisi: item.namaTeknisi,
      tanggalKalibrasi: item.tanggalKalibrasi,
      status: item.status,
      keputusan: item.keputusan,
      certificateId: item.certificateId,
      catatanRevisi: item.catatanRevisi,
      nomorSesi: 'KAL/2026/07/${item.id.toString().padLeft(4, '0')}',
      standarAcuan: const StandardRef(id: 1, nama: 'Gauge Block Set Grade 0'),
      suhuRuang: 21.4,
      kelembaban: 54.5,
      lokasi: 'lab',
      sertifikat: item.certificateId == null
          ? null
          : CertificateRef(
              id: item.certificateId!,
              nomor: item.nomorSertifikat ?? 'CAL/2026/07/0000',
              status: 'terbit',
              pdfUrl: 'https://contoh.sidik.co.id/certificates/${item.certificateId}/download',
              // Backend asli BELUM ngirim dua field ini (lihat
              // `docs/permintaan-backend-alur-revisi-qr.md` §2). Diisi di mock
              // biar layar QR-nya bisa digarap & diuji sekarang — begitu
              // backend nambahin, nggak ada yang perlu diubah di layar.
              qrToken: 'sidik-${item.certificateId}-a1b2c3d4',
              qrUrl:
                  'https://contoh.sidik.co.id/verify/sidik-${item.certificateId}-a1b2c3d4',
            ),
      titik: sudahDihitung ? _titikContoh : const [],
    );
  }
}
