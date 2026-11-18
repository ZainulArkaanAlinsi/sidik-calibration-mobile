import '../core/utils/parse_list.dart';
import '../models/category.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Kelola kategori alat dari aplikasi Lab: daftar (termasuk nonaktif), buat,
/// ubah nama, nonaktifkan/aktifkan, hapus yang tidak dipakai.
///
/// Kontrak: `docs/perintah-frontend-crud-lengkap.md` §2. Hanya admin dan super
/// admin (`kategori.kelola`). `kode` dibuat server dari nama dan TIDAK PERNAH
/// berubah (dipakai di URL dan field `kategori` alat). Server yang menegakkan;
/// layar hanya menyembunyikan tombol.
///
/// Galat 4xx dilempar sebagai `ApiException` (badan asli: `kode`, `errors`,
/// `kategori`, `pemakai`) — layar yang memetakannya ke kalimat.
abstract class KategoriKelolaService {
  /// `GET /categories?termasuk_nonaktif=1` — satu halaman penuh (tidak
  /// dipaginasi server), diurut nama.
  Future<List<Category>> daftar(String token);

  /// `POST /categories` — [nama] 2–100 karakter; `kode` dari server.
  Future<Category> buat(String token, {required String nama});

  /// `PUT /categories/{kode}` — hanya nama.
  Future<Category> ubahNama(String token, String kode, {required String nama});

  /// `POST /categories/{kode}/nonaktifkan` — [alasan] opsional (maks 400).
  /// Idempoten.
  Future<Category> nonaktifkan(String token, String kode, {String? alasan});

  /// `POST /categories/{kode}/aktifkan` — idempoten.
  Future<Category> aktifkan(String token, String kode);

  /// `DELETE /categories/{kode}` — hapus lunak; `422 kategori_dipakai` bila
  /// masih dipakai.
  Future<void> hapus(String token, String kode);
}

class ApiKategoriKelolaService implements KategoriKelolaService {
  ApiKategoriKelolaService(this._api);

  final ApiClient _api;

  Category _kategori(Map<String, dynamic> json) =>
      Category.fromJson((json['data'] ?? json) as Map<String, dynamic>);

  @override
  Future<List<Category>> daftar(String token) async {
    final json = await _api.get('/categories?termasuk_nonaktif=1', token: token);
    return parseListAman(
      json['data'] as List<dynamic>? ?? const [],
      Category.fromJson,
    );
  }

  @override
  Future<Category> buat(String token, {required String nama}) async =>
      // POST tanpa `client_request_id`: tidak diulang otomatis, jadi sinyal
      // putus-nyambung tidak melahirkan dua kategori; nama kembar ditolak
      // server (`nama_kategori_kembar`) bila jawabannya hilang dan diulang.
      _kategori(
        await _api.post('/categories', token: token, body: {'nama': nama}),
      );

  @override
  Future<Category> ubahNama(
    String token,
    String kode, {
    required String nama,
  }) async => _kategori(
    await _api.put(
      '/categories/${Uri.encodeComponent(kode)}',
      token: token,
      body: {'nama': nama},
    ),
  );

  @override
  Future<Category> nonaktifkan(
    String token,
    String kode, {
    String? alasan,
  }) async => _kategori(
    await _api.post(
      '/categories/${Uri.encodeComponent(kode)}/nonaktifkan',
      token: token,
      body: {'alasan': ?alasan},
    ),
  );

  @override
  Future<Category> aktifkan(String token, String kode) async => _kategori(
    await _api.post(
      '/categories/${Uri.encodeComponent(kode)}/aktifkan',
      token: token,
      body: {},
    ),
  );

  @override
  Future<void> hapus(String token, String kode) async {
    await _api.delete('/categories/${Uri.encodeComponent(kode)}', token: token);
  }
}

/// Tiruan in-memory buat test dan mode mock. Meniru aturan server seperlunya:
/// slug dari nama (`-2`, `-3` bila bentrok), nama unik tanpa membedakan huruf
/// besar/kecil, hapus ditolak bila dipakai.
class MockKategoriKelolaService implements KategoriKelolaService {
  MockKategoriKelolaService({
    List<Category>? awal,
    this.galat,
    this.jeda = Duration.zero,
  }) : _data = [...(awal ?? contoh)];

  /// Bila diisi, dilempar oleh SETIAP panggilan (meniru 403/429/jaringan).
  final Object? galat;
  final Duration jeda;
  final List<Category> _data;

  /// Catatan panggilan buat assert di test.
  final List<String> catatan = [];

  static final contoh = <Category>[
    const Category(
      id: 1,
      kode: 'massa',
      nama: 'Massa',
      jumlahAlat: 12,
      jumlahKemampuan: 8,
      jumlahTanpaCmc: 1,
    ),
    const Category(id: 2, kode: 'tekanan', nama: 'Tekanan'),
    Category(
      id: 3,
      kode: 'suhu-lama',
      nama: 'Suhu Lama',
      aktif: false,
      nonaktifPada: DateTime.utc(2026, 11, 10, 3),
      jumlahAlat: 3,
    ),
    const Category(id: 4, kode: 'panjang', nama: 'Panjang', jumlahAlat: 5),
  ];

  Future<void> _awal(String panggilan) async {
    catatan.add(panggilan);
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
  }

  ApiException _galat422(
    String pesan, {
    String? kode,
    Map<String, dynamic>? errors,
    Map<String, dynamic>? tambahan,
  }) => ApiException(
    pesan,
    status: 422,
    body: {'message': pesan, 'kode': ?kode, 'errors': ?errors, ...?tambahan},
  );

  static String _normal(String nama) =>
      nama.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _slug(String nama) => _normal(nama)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Category _cari(String kode) => _data.firstWhere(
    (c) => c.kode == kode,
    orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
  );

  void _periksaNama(String nama, {String? kecuali}) {
    final bersih = nama.trim();
    if (bersih.length < 2 || bersih.length > 100) {
      throw _galat422(
        'Nama harus 2 sampai 100 karakter.',
        errors: {
          'nama': ['Nama harus 2 sampai 100 karakter.'],
        },
      );
    }
    if (_slug(bersih).isEmpty) {
      throw _galat422(
        'Nama harus memuat huruf atau angka.',
        errors: {
          'nama': ['Nama harus memuat huruf atau angka.'],
        },
      );
    }
    final kembar = _data
        .where((c) => c.kode != kecuali && _normal(c.nama) == _normal(bersih))
        .firstOrNull;
    if (kembar != null) {
      throw _galat422(
        'Sudah ada kategori bernama itu.',
        kode: 'nama_kategori_kembar',
        errors: {
          'nama': ['Sudah ada kategori bernama itu.'],
        },
        tambahan: {
          'kategori': {
            'kode': kembar.kode,
            'nama': kembar.nama,
            'aktif': kembar.aktif,
          },
        },
      );
    }
  }

  @override
  Future<List<Category>> daftar(String token) async {
    await _awal('daftar');
    final urut = [..._data]..sort((a, b) => a.nama.compareTo(b.nama));
    return urut;
  }

  @override
  Future<Category> buat(String token, {required String nama}) async {
    await _awal('buat "$nama"');
    _periksaNama(nama);
    var kode = _slug(nama);
    var n = 2;
    while (_data.any((c) => c.kode == kode)) {
      kode = '${_slug(nama)}-${n++}';
    }
    final baru = Category(
      id: _data.fold<int>(0, (m, c) => (c.id ?? 0) > m ? c.id! : m) + 1,
      kode: kode,
      nama: nama.trim(),
    );
    _data.add(baru);
    return baru;
  }

  Category _ganti(String kode, Category Function(Category) f) {
    final i = _data.indexWhere((c) => c.kode == kode);
    return _data[i] = f(_data[i]);
  }

  Category _salin(
    Category c, {
    String? nama,
    bool? aktif,
    DateTime? nonaktifPada,
  }) => Category(
    id: c.id,
    kode: c.kode,
    nama: nama ?? c.nama,
    rentangUkur: c.rentangUkur,
    ketidakpastianTerbaik: c.ketidakpastianTerbaik,
    satuan: c.satuan,
    aktif: aktif ?? c.aktif,
    nonaktifPada: aktif == true ? null : (nonaktifPada ?? c.nonaktifPada),
    jumlahAlat: c.jumlahAlat,
    jumlahKemampuan: c.jumlahKemampuan,
    jumlahTanpaCmc: c.jumlahTanpaCmc,
  );

  @override
  Future<Category> ubahNama(
    String token,
    String kode, {
    required String nama,
  }) async {
    await _awal('ubahNama $kode "$nama"');
    _cari(kode);
    _periksaNama(nama, kecuali: kode);
    return _ganti(kode, (c) => _salin(c, nama: nama.trim()));
  }

  @override
  Future<Category> nonaktifkan(
    String token,
    String kode, {
    String? alasan,
  }) async {
    await _awal('nonaktifkan $kode ${alasan ?? ''}');
    _cari(kode);
    if ((alasan ?? '').length > 400) {
      throw _galat422(
        'Alasan maksimal 400 karakter.',
        errors: {
          'alasan': ['Alasan maksimal 400 karakter.'],
        },
      );
    }
    return _ganti(
      kode,
      (c) => c.aktif
          ? _salin(c, aktif: false, nonaktifPada: DateTime.now().toUtc())
          : c,
    );
  }

  @override
  Future<Category> aktifkan(String token, String kode) async {
    await _awal('aktifkan $kode');
    _cari(kode);
    return _ganti(kode, (c) => _salin(c, aktif: true));
  }

  @override
  Future<void> hapus(String token, String kode) async {
    await _awal('hapus $kode');
    final c = _cari(kode);
    if (!c.bisaDihapus) {
      throw _galat422(
        'Kategori ini masih dipakai.',
        kode: 'kategori_dipakai',
        tambahan: {
          'pemakai': {
            'alat': c.jumlahAlat,
            'kemampuan': c.jumlahKemampuan,
            'penugasan': 0,
            'metode': 0,
            'rumus': 0,
          },
        },
      );
    }
    _data.removeWhere((x) => x.kode == kode);
  }
}
