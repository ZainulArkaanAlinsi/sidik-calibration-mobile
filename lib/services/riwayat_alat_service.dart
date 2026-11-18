import '../models/alat_pelanggan.dart';
import '../models/revisi_sertifikat.dart' show StatusDokumen;
import 'api_client.dart';

/// Pelacakan pelanggan → alat → sertifikat di sisi LAB, paginasi KURSOR.
///
/// Halaman diminta satu-satu (tidak pernah "semua"), dan tidak ada yang
/// disimpan ke disk: PDF sertifikat tidak disentuh di sini — layar pratinjau
/// yang sudah ada yang mengambilnya, dan unduh hanya atas perintah pengguna.
abstract class RiwayatAlatService {
  /// `GET /customers/{customer}/alat?cursor=&limit=`.
  Future<HalamanKursor<AlatRingkas>> alat(
    String token,
    int customerId, {
    String? kursor,
    int batas = 20,
  });

  /// `GET /equipments/{equipment}/sertifikat?cursor=&limit=` — TERBARU dulu,
  /// termasuk yang digantikan/ditarik/dibatalkan/gagal.
  Future<HalamanKursor<SertifikatRingkas>> sertifikat(
    String token,
    int equipmentId, {
    String? kursor,
    int batas = 20,
  });
}

class ApiRiwayatAlatService implements RiwayatAlatService {
  ApiRiwayatAlatService(this._api);

  final ApiClient _api;

  String _query(String? kursor, int batas) {
    final q = <String>[
      'limit=$batas',
      if (kursor != null && kursor.isNotEmpty)
        'cursor=${Uri.encodeQueryComponent(kursor)}',
    ];
    return '?${q.join('&')}';
  }

  HalamanKursor<T> _halaman<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) buat,
  ) {
    final data = json['data'];
    return HalamanKursor(
      // Baris cacat TIDAK dilewati diam-diam: riwayat yang kurang satu
      // sertifikat lebih berbahaya daripada layar galat.
      items: [
        if (data is List)
          for (final e in data)
            if (e is Map) buat(Map<String, dynamic>.from(e)),
      ],
      kursorBerikut: HalamanKursor.bacaKursor(json),
    );
  }

  @override
  Future<HalamanKursor<AlatRingkas>> alat(
    String token,
    int customerId, {
    String? kursor,
    int batas = 20,
  }) async {
    final json = await _api.get(
      '/customers/$customerId/alat${_query(kursor, batas)}',
      token: token,
    );
    return _halaman(json, AlatRingkas.fromJson);
  }

  @override
  Future<HalamanKursor<SertifikatRingkas>> sertifikat(
    String token,
    int equipmentId, {
    String? kursor,
    int batas = 20,
  }) async {
    final json = await _api.get(
      '/equipments/$equipmentId/sertifikat${_query(kursor, batas)}',
      token: token,
    );
    return _halaman(json, SertifikatRingkas.fromJson);
  }
}

/// Tiruan buat test dan mode mock. Menghasilkan daftar besar dengan kursor
/// buram (`c<offset>`) supaya paginasi dan "muat lagi" teruji.
class MockRiwayatAlatService implements RiwayatAlatService {
  MockRiwayatAlatService({
    this.jumlahAlat = 45,
    this.jumlahSertifikat = 60,
    this.galat,
    this.galatHalamanKedua,
    this.jeda = Duration.zero,
    List<AlatRingkas>? alatTetap,
    List<SertifikatRingkas>? sertifikatTetap,
  }) : _alatTetap = alatTetap,
       _sertifikatTetap = sertifikatTetap;

  final int jumlahAlat;
  final int jumlahSertifikat;

  /// Dilempar oleh SETIAP panggilan.
  final Object? galat;

  /// Dilempar hanya oleh permintaan yang membawa kursor (halaman ke-2 dst).
  final Object? galatHalamanKedua;
  final Duration jeda;
  final List<AlatRingkas>? _alatTetap;
  final List<SertifikatRingkas>? _sertifikatTetap;

  /// Catatan `jenis:id:kursor` untuk assert di test.
  final List<String> catatan = [];

  AlatRingkas _alat(int i) {
    final statusAlat = switch (i % 5) {
      0 => 'lewat_jadwal',
      1 => 'terkalibrasi',
      2 => 'mendekati_jadwal',
      3 => 'belum_pernah',
      _ => 'nonaktif',
    };
    final hari = switch (i % 5) {
      0 => -12,
      2 => 14,
      3 => null,
      _ => 120 + i,
    };
    final jumlah = i % 4;
    return AlatRingkas(
      id: 500 + i,
      nama: i.isEven ? 'Thermohygrometer $i' : 'Timbangan Analitik $i',
      merk: i % 3 == 0 ? 'Fluke' : 'Mettler Toledo',
      model: i % 3 == 0 ? '1620A' : 'XS204',
      nomorSeri: 'SN-${10000 + i}',
      status: switch (i % 5) {
        0 => 'overdue',
        4 => 'nonaktif',
        _ => 'aktif',
      },
      statusAlat: statusAlat,
      jatuhTempo: hari == null ? null : DateTime(2027, 1 + i % 12, 10),
      hariKeJatuhTempo: hari,
      jumlahSertifikat: jumlah,
      sertifikatTerbaru: jumlah == 0
          ? null
          : SertifikatTerbaru(
              id: 9000 + i,
              nomor: 'CAL/2026/${(100 - i).toString().padLeft(4, '0')}',
              keadaan: KeadaanSertifikat.terbit,
              diterbitkanPada: DateTime(2026, 11, 15),
            ),
    );
  }

  SertifikatRingkas _sertifikat(int i) {
    // 20 hari mundur per sertifikat: melintasi bulan dan tahun.
    final tanggal = DateTime(2026, 11, 15).subtract(Duration(days: i * 20));
    final nomor = 'CAL/2026/${(100 - i).toString().padLeft(4, '0')}';
    final dokumen = switch (i % 6) {
      0 => (
        status: 'terbit',
        dokumen: StatusDokumen.berlaku,
        keputusan: 'PASS',
      ),
      1 => (
        status: 'terbit',
        dokumen: StatusDokumen.digantikan,
        keputusan: 'PASS',
      ),
      2 => (
        status: 'ditarik',
        dokumen: StatusDokumen.ditarik,
        keputusan: 'FAIL',
      ),
      3 => (
        status: 'gagal',
        dokumen: StatusDokumen.belumTerbit,
        keputusan: null,
      ),
      4 => (
        status: 'dibatalkan',
        dokumen: StatusDokumen.dibatalkan,
        keputusan: 'PASS',
      ),
      _ => (
        status: 'terbit',
        dokumen: StatusDokumen.berlaku,
        keputusan: 'PASS',
      ),
    };
    final belumTerbit = dokumen.status == 'gagal';
    return SertifikatRingkas(
      id: 9000 + i,
      nomor: nomor,
      keadaan: keadaanSertifikat(dokumen.status, dokumen.dokumen),
      // `gagal` belum punya tanggal terbit (tahun/bulan juga null).
      diterbitkanPada: belumTerbit ? null : tanggal,
      berlakuSampai: belumTerbit
          ? null
          : tanggal.add(const Duration(days: 365)),
      tahun: belumTerbit ? null : tanggal.year,
      bulan: belumTerbit ? null : tanggal.month,
      keputusan: dokumen.keputusan,
      revisiKe: i % 6 == 1 ? 1 : 0,
      revisiDari: i % 6 == 1
          ? RujukanNomor(id: 9000 + i + 1, nomor: '$nomor-R0')
          : null,
      digantikanOleh: dokumen.dokumen == StatusDokumen.digantikan
          ? RujukanNomor(id: 9000 + i - 1, nomor: '$nomor-R1')
          : null,
      ditarikPada: dokumen.status == 'ditarik' ? tanggal : null,
      dibatalkanPada: dokumen.status == 'dibatalkan' ? tanggal : null,
    );
  }

  Future<HalamanKursor<T>> _potong<T>(
    String jenis,
    int id,
    String? kursor,
    int batas,
    int total,
    T Function(int i) buat,
    List<T>? tetap,
  ) async {
    catatan.add('$jenis:$id:${kursor ?? ''}');
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
    if (kursor != null && galatHalamanKedua != null) throw galatHalamanKedua!;

    final jumlah = tetap?.length ?? total;
    final mulai = kursor == null ? 0 : int.parse(kursor.substring(1));
    final akhir = (mulai + batas).clamp(0, jumlah);
    final items = [
      for (var i = mulai; i < akhir; i++) tetap != null ? tetap[i] : buat(i),
    ];
    return HalamanKursor(
      items: items,
      kursorBerikut: akhir < jumlah ? 'c$akhir' : null,
    );
  }

  @override
  Future<HalamanKursor<AlatRingkas>> alat(
    String token,
    int customerId, {
    String? kursor,
    int batas = 20,
  }) =>
      _potong('alat', customerId, kursor, batas, jumlahAlat, _alat, _alatTetap);

  @override
  Future<HalamanKursor<SertifikatRingkas>> sertifikat(
    String token,
    int equipmentId, {
    String? kursor,
    int batas = 20,
  }) => _potong(
    'sertifikat',
    equipmentId,
    kursor,
    batas,
    jumlahSertifikat,
    _sertifikat,
    _sertifikatTetap,
  );
}
