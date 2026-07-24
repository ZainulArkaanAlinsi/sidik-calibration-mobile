import '../models/perhitungan.dart';
import '../models/validasi.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Hasil approve. [validasi] selalu ikut — backend ngirimnya baik waktu
/// sukses maupun waktu nolak, jadi layar bisa nampilin temuannya tanpa nembak
/// `/validasi` lagi.
class HasilApprove {
  const HasilApprove({
    required this.disetujui,
    required this.butuhKonfirmasi,
    this.validasi,
    this.pesan,
  });

  final bool disetujui;

  /// `true` = ditolak sekali karena ada peringatan. Layar tampilin dialog
  /// "lanjut?", lalu kirim ulang dengan `abaikanPeringatan: true`.
  final bool butuhKonfirmasi;

  final HasilValidasi? validasi;
  final String? pesan;
}

/// Layar utama admin: lembar PERHITUNGAN + periksa/setujui (spesifikasi poin
/// 11 & 12A). Semuanya admin doang — backend nolak role lain dengan 403.
abstract class PerhitunganService {
  Future<Perhitungan> ambil(String token, int calibrationId);

  /// Tombol "Periksa" — hitung ulang & periksa tanpa nyetujuin.
  Future<HasilValidasi> periksa(String token, int calibrationId);

  Future<HasilApprove> setujui(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
  });

  Future<void> tolak(String token, int calibrationId, String catatanRevisi);

  /// Kolom administratif (`PATCH /calibrations/{id}/admin`). Begitu
  /// thermohygro dipilih, koreksi & U95% kondisi lingkungan langsung ikut
  /// terhitung — makanya layar mesti muat ulang perhitungannya sesudah ini.
  Future<void> simpanKolomAdmin(
    String token,
    int calibrationId, {
    String? nomorOrder,
    int? calibrationMethodId,
    int? thermohygroStandardId,
    int? roomId,
    String? tanggalTerima,
  });
}

class ApiPerhitunganService implements PerhitunganService {
  ApiPerhitunganService(this._api);

  final ApiClient _api;

  @override
  Future<Perhitungan> ambil(String token, int calibrationId) async {
    final json = await _api.get(
      '/calibrations/$calibrationId/perhitungan',
      token: token,
    );
    return Perhitungan.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<HasilValidasi> periksa(String token, int calibrationId) async {
    final json = await _api.get(
      '/calibrations/$calibrationId/validasi',
      token: token,
    );
    return HasilValidasi.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<HasilApprove> setujui(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
  }) async {
    try {
      final json = await _api.post(
        '/calibrations/$calibrationId/approve',
        token: token,
        body: {if (abaikanPeringatan) 'abaikan_peringatan': true},
      );

      return HasilApprove(
        disetujui: true,
        butuhKonfirmasi: false,
        validasi: _validasiDari(json),
      );
    } on ApiException catch (e) {
      // 422 di sini BUKAN error tak terduga — itu jalur normal: temuan fatal
      // nahan approve, atau peringatan nahan sekali sampai admin lanjut
      // secara sadar. Dua-duanya bawa hasil validasi lengkap di body-nya.
      if (e.status != 422) rethrow;

      return HasilApprove(
        disetujui: false,
        butuhKonfirmasi: e.butuhKonfirmasi,
        validasi: _validasiDari(e.body),
        pesan: e.message,
      );
    }
  }

  HasilValidasi? _validasiDari(Map<String, dynamic> json) {
    final v = json['validasi'];
    return v is Map<String, dynamic> ? HasilValidasi.fromJson(v) : null;
  }

  @override
  Future<void> tolak(
    String token,
    int calibrationId,
    String catatanRevisi,
  ) async {
    await _api.post(
      '/calibrations/$calibrationId/reject',
      token: token,
      body: {'catatan_revisi': catatanRevisi},
    );
  }

  @override
  Future<void> simpanKolomAdmin(
    String token,
    int calibrationId, {
    String? nomorOrder,
    int? calibrationMethodId,
    int? thermohygroStandardId,
    int? roomId,
    String? tanggalTerima,
  }) async {
    await _api.patch(
      '/calibrations/$calibrationId/admin',
      token: token,
      // Cuma kirim yang beneran diubah — kirim null buat kolom yang nggak
      // disentuh bakal ngosongin isinya di server.
      body: {
        'nomor_order': ?nomorOrder,
        'calibration_method_id': ?calibrationMethodId,
        'thermohygro_standard_id': ?thermohygroStandardId,
        'room_id': ?roomId,
        'tanggal_terima': ?tanggalTerima,
      },
    );
  }
}

/// Data tiruan buat layar & test. Angkanya dari sertifikat ASLI 012-CAL-524
/// (`Master Olah Data_pH for trial_CSV/PERHITUNGAN.csv`), jadi apa yang
/// kelihatan di test itu persis yang dilihat lab di Excel-nya.
class MockPerhitunganService implements PerhitunganService {
  MockPerhitunganService({
    this.gagal = false,
    this.validasi,
    this.thermohygroBelumDipilih = false,
  });

  final bool gagal;
  final bool thermohygroBelumDipilih;

  /// Hasil yang dibalikin `periksa()` & dipakai `setujui()` buat mutusin.
  final HasilValidasi? validasi;

  final List<(String, Object?)> aksi = [];

  HasilValidasi get _validasi =>
      validasi ??
      const HasilValidasi(
        valid: true,
        bolehTerbit: true,
        temuan: [],
        ringkasan: {
          TingkatTemuan.error: 0,
          TingkatTemuan.peringatan: 0,
          TingkatTemuan.info: 0,
        },
      );

  @override
  Future<Perhitungan> ambil(String token, int calibrationId) async {
    if (gagal) throw Exception('server nggak nyaut');

    return Perhitungan(
      nomorSesi: '2405.13.A',
      identitasAlat: const IdentitasAlat(
        namaAlat: 'pH Meter',
        merk: 'Mettler Toledo',
        type: 'Five Easy',
        noSeri: 'B628755900',
        rentangUkur: '0-14',
        kapasitasMax: 14,
        resolusi: 0.01,
        satuan: 'pH',
      ),
      identitasCustomer: const IdentitasCustomer(
        nama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
        alamat: 'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. '
            'Cicalengka, Kab. Bandung, Jawa Barat',
        tanggalTerima: '2024-05-26',
        tanggalKalibrasi: '2024-05-26',
      ),
      kondisiLingkungan: thermohygroBelumDipilih
          ? const KondisiLingkungan(
              suhu: BarisKondisi(
                satuan: '°C',
                awal: 21.3,
                akhir: 21.5,
                average: 21.4,
                delta: 0.2,
                nilaiTerkoreksi: 21.4,
              ),
              kelembaban: BarisKondisi(
                satuan: '%RH',
                awal: 53,
                akhir: 56,
                average: 54.5,
                delta: 3,
                nilaiTerkoreksi: 54.5,
              ),
            )
          : const KondisiLingkungan(
              thermohygro: 'TH-3',
              thermohygroSerial: 'TH-3',
              suhu: BarisKondisi(
                satuan: '°C',
                awal: 21.3,
                akhir: 21.5,
                average: 21.4,
                indexedValue: 19.83,
                correction: -0.43,
                delta: 0.2,
                u95StdTh: 1.7,
                u95Sertifikat: 1.7117242768623688,
                nilaiTerkoreksi: 20.97,
              ),
              kelembaban: BarisKondisi(
                satuan: '%RH',
                awal: 53,
                akhir: 56,
                average: 54.5,
                indexedValue: 47.05,
                correction: -2.55,
                delta: 3,
                u95StdTh: 4.8,
                u95Sertifikat: 5.660388679233963,
                nilaiTerkoreksi: 51.95,
              ),
            ),
      hasil: [
        TabelPerhitungan(
          tahap: 'sebelum_adjustment',
          judul: 'Before Adjustment Reading',
          maxStdev: 0.4293250516799596,
          titik: [
            _titik(1, 4.0092251999999995, [4.04, 4.04, 4.04, 5.00, 4.04], 22.2,
                4.232, 0.22277480000000072, 0.4293250516799596),
            _titik(2, 6.9885032, [7.02, 7.04, 7.05, 7.02, 7.02], 22.3,
                7.029999999999999, 0.04149679999999911, 0.014142135623731119),
            _titik(3, 9.9777956, [9.61, 9.94, 9.66, 9.61, 9.61], 22.2,
                9.685999999999998, -0.29179560000000215, 0.14363147287415806),
          ],
        ),
        TabelPerhitungan(
          tahap: 'sesudah_adjustment',
          judul: 'After Adjustment Reading',
          maxStdev: 0.005477225575051662,
          titik: [
            _titik(1, 4.009244572, [4, 4, 4, 4, 4], 22.2, 4.0,
                -0.009244572000000156, 0.0),
            _titik(2, 6.9889072, [7.01, 7.01, 7, 7, 7], 22.2, 7.004,
                0.015092800000000421, 0.005477225575051662),
            _titik(3, 9.978876900000001, [10.11, 10.11, 10.11, 10.11, 10.11],
                22.1, 10.11, 0.13112310000000012, 0.0),
          ],
        ),
      ],
    );
  }

  static TitikPerhitungan _titik(
    int ke,
    double standard,
    List<double> nilai,
    double suhu,
    double average,
    double correction,
    double stdev,
  ) => TitikPerhitungan(
    titikKe: ke,
    standard: standard,
    standardNominal: [4.00, 7.00, 10.01][ke - 1],
    standardDariSuhu: true,
    satuan: 'pH',
    average: average,
    averageSuhu: suhu,
    correction: correction,
    stdev: stdev,
    pembacaan: [
      for (var i = 0; i < nilai.length; i++)
        PembacaanPerhitungan(repeat: i + 1, nilai: nilai[i], suhu: suhu),
    ],
  );

  @override
  Future<HasilValidasi> periksa(String token, int calibrationId) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('periksa', calibrationId));
    return _validasi;
  }

  @override
  Future<HasilApprove> setujui(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('setujui', abaikanPeringatan));

    final v = _validasi;

    if (!v.bolehTerbit) {
      return HasilApprove(
        disetujui: false,
        butuhKonfirmasi: false,
        validasi: v,
        pesan: 'Ada masalah di data sesi ini yang bikin sertifikatnya '
            'nggak bisa diterbitin.',
      );
    }

    if (!v.valid && !abaikanPeringatan) {
      return HasilApprove(
        disetujui: false,
        butuhKonfirmasi: true,
        validasi: v,
        pesan: 'Hasil hitung ulang beda dari yang tersimpan.',
      );
    }

    return HasilApprove(disetujui: true, butuhKonfirmasi: false, validasi: v);
  }

  @override
  Future<void> tolak(
    String token,
    int calibrationId,
    String catatanRevisi,
  ) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('tolak', catatanRevisi));
  }

  @override
  Future<void> simpanKolomAdmin(
    String token,
    int calibrationId, {
    String? nomorOrder,
    int? calibrationMethodId,
    int? thermohygroStandardId,
    int? roomId,
    String? tanggalTerima,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('kolomAdmin', thermohygroStandardId ?? nomorOrder));
  }
}
