import '../core/utils/parse_list.dart';
import '../models/ruangan.dart';
import 'api_client.dart';

/// Ruangan lab & metode kalibrasi (IK).
///
/// Baca: semua peran. Tulis: **admin doang** — backend jaga dengan 403, jadi
/// tombolnya juga disembunyiin di layar biar nggak nawarin yang pasti ditolak.
abstract class RuanganService {
  Future<List<Ruangan>> daftarRuangan(String token);

  Future<Ruangan> simpanRuangan(String token, Ruangan data);

  Future<Ruangan> ubahRuangan(String token, Ruangan data);

  Future<void> hapusRuangan(String token, int id);

  Future<List<MetodeKalibrasi>> daftarMetode(String token);

  Future<MetodeKalibrasi> simpanMetode(String token, MetodeKalibrasi data);

  Future<MetodeKalibrasi> ubahMetode(String token, MetodeKalibrasi data);

  Future<void> hapusMetode(String token, int id);
}

class ApiRuanganService implements RuanganService {
  ApiRuanganService(this._api);

  final ApiClient _api;

  static Map<String, dynamic> _isi(Map<String, dynamic> json) =>
      (json['data'] ?? json) as Map<String, dynamic>;

  /// `GET /rooms` itu **berpaginasi** `paginate(15)` yang dipatok di backend —
  /// `per_page` nggak dihormati. Kalau cuma halaman 1 yang dibaca, ruangan
  /// ke-16 dan seterusnya ilang dari layar tanpa error apa pun, dan admin
  /// nggak punya cara tau ada yang kurang.
  ///
  /// Jadi halamannya diikutin sampai habis. Master data ruangan nggak bakal
  /// ribuan, jadi ini murah — dan lebih murah lagi daripada data yang hilang
  /// diam-diam.
  ///
  /// Batas 50 halaman dipasang sebagai rem: kalau backend suatu saat balikin
  /// `next` yang muter, layarnya berhenti, bukan ngeloop selamanya.
  @override
  Future<List<Ruangan>> daftarRuangan(String token) async {
    final semua = <Ruangan>[];

    for (var halaman = 1; halaman <= 50; halaman++) {
      final json = await _api.get('/rooms?page=$halaman', token: token);

      semua.addAll(
        parseListAman(
          json['data'] as List<dynamic>? ?? const [],
          Ruangan.fromJson,
        ),
      );

      final meta = json['meta'];
      // Nggak ada `meta` = respons belum/nggak dipaginasi. Sekali ambil cukup.
      if (meta is! Map<String, dynamic>) break;

      final kini = (meta['current_page'] as num?)?.toInt() ?? halaman;
      final akhir = (meta['last_page'] as num?)?.toInt() ?? halaman;
      if (kini >= akhir) break;
    }

    return semua;
  }

  @override
  Future<Ruangan> simpanRuangan(String token, Ruangan data) async {
    final json = await _api.post('/rooms', token: token, body: data.toJson());
    return Ruangan.fromJson(_isi(json));
  }

  @override
  Future<Ruangan> ubahRuangan(String token, Ruangan data) async {
    final json = await _api.put(
      '/rooms/${data.id}',
      token: token,
      body: data.toJson(),
    );

    return Ruangan.fromJson(_isi(json));
  }

  @override
  Future<void> hapusRuangan(String token, int id) =>
      _api.delete('/rooms/$id', token: token);

  @override
  Future<List<MetodeKalibrasi>> daftarMetode(String token) async {
    final json = await _api.get('/calibration-methods', token: token);

    return parseListAman(
      json['data'] as List<dynamic>? ?? const [],
      MetodeKalibrasi.fromJson,
    );
  }

  @override
  Future<MetodeKalibrasi> simpanMetode(
    String token,
    MetodeKalibrasi data,
  ) async {
    final json = await _api.post(
      '/calibration-methods',
      token: token,
      body: data.toJson(),
    );

    return MetodeKalibrasi.fromJson(_isi(json));
  }

  @override
  Future<MetodeKalibrasi> ubahMetode(
    String token,
    MetodeKalibrasi data,
  ) async {
    final json = await _api.put(
      '/calibration-methods/${data.id}',
      token: token,
      body: data.toJson(),
    );

    return MetodeKalibrasi.fromJson(_isi(json));
  }

  @override
  Future<void> hapusMetode(String token, int id) =>
      _api.delete('/calibration-methods/$id', token: token);
}

/// Data tiruan buat test & mode mock.
class MockRuanganService implements RuanganService {
  MockRuanganService({this.jeda = Duration.zero, this.gagal = false});

  final Duration jeda;
  final bool gagal;

  final List<Ruangan> _ruangan = [
    const Ruangan(
      id: 1,
      kode: 'LAB-01',
      nama: 'Lab Kalibrasi Kimia',
      lokasi: 'Lantai 2',
      suhuMin: 20,
      suhuMaks: 24,
      kelembabanMin: 45,
      kelembabanMaks: 65,
    ),
  ];

  final List<MetodeKalibrasi> _metode = [
    MetodeKalibrasi(
      id: 1,
      kode: 'SIDIK-IK-CAL-0506',
      nama: 'Kalibrasi pH Meter',
      revisi: '4',
      berlakuMulai: DateTime(2024, 10, 28),
    ),
  ];

  Future<void> _tunggu(String apa) async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal memuat $apa.');
  }

  @override
  Future<List<Ruangan>> daftarRuangan(String token) async {
    await _tunggu('ruangan');
    return List.of(_ruangan);
  }

  @override
  Future<Ruangan> simpanRuangan(String token, Ruangan data) async {
    await _tunggu('ruangan');
    _ruangan.add(
      Ruangan(
        id: _ruangan.length + 1,
        kode: data.kode,
        nama: data.nama,
        lokasi: data.lokasi,
        suhuMin: data.suhuMin,
        suhuMaks: data.suhuMaks,
        kelembabanMin: data.kelembabanMin,
        kelembabanMaks: data.kelembabanMaks,
        keterangan: data.keterangan,
        aktif: data.aktif,
      ),
    );

    return _ruangan.last;
  }

  @override
  Future<Ruangan> ubahRuangan(String token, Ruangan data) async {
    await _tunggu('ruangan');
    final i = _ruangan.indexWhere((r) => r.id == data.id);
    if (i >= 0) _ruangan[i] = data;

    return data;
  }

  @override
  Future<void> hapusRuangan(String token, int id) async {
    await _tunggu('ruangan');
    _ruangan.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<MetodeKalibrasi>> daftarMetode(String token) async {
    await _tunggu('metode');
    return List.of(_metode);
  }

  @override
  Future<MetodeKalibrasi> simpanMetode(
    String token,
    MetodeKalibrasi data,
  ) async {
    await _tunggu('metode');
    _metode.add(
      MetodeKalibrasi(
        id: _metode.length + 1,
        kode: data.kode,
        nama: data.nama,
        revisi: data.revisi,
        berlakuMulai: data.berlakuMulai,
        keterangan: data.keterangan,
        aktif: data.aktif,
      ),
    );

    return _metode.last;
  }

  @override
  Future<MetodeKalibrasi> ubahMetode(
    String token,
    MetodeKalibrasi data,
  ) async {
    await _tunggu('metode');
    final i = _metode.indexWhere((m) => m.id == data.id);
    if (i >= 0) _metode[i] = data;

    return data;
  }

  @override
  Future<void> hapusMetode(String token, int id) async {
    await _tunggu('metode');
    _metode.removeWhere((m) => m.id == id);
  }
}
