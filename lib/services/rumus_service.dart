import '../core/utils/parse_list.dart';
import '../models/rumus.dart';
import 'api_client.dart';

/// Rumus kalibrasi berversi. **Admin doang** — salah ngetik di sini ngubah
/// angka yang masuk sertifikat terakreditasi, dan backend jaga itu dengan 403.
abstract class RumusService {
  Future<List<Rumus>> daftar(String token);

  /// Riwayat versi satu rumus, terbaru dulu.
  Future<List<VersiRumus>> versi(String token, int formulaId);

  /// "Sesi tanggal sekian dihitung pakai aturan yang mana?"
  ///
  /// Beda dari "aturan apa yang dipakai sekarang" — dan yang ini yang ditanya
  /// waktu ada yang minta pertanggungjawaban angka lama.
  Future<VersiRumus?> versiPadaTanggal(String token, int formulaId, DateTime tanggal);

  Future<VersiRumus> terbitkanVersi(String token, int formulaId, VersiRumusBaru isi);

  /// Ubah status versi (`aktif` / `arsip`) dan/atau catatannya.
  Future<VersiRumus> ubahVersi(
    String token,
    int versiId, {
    StatusVersiRumus? status,
    String? catatan,
  });
}

class ApiRumusService implements RumusService {
  ApiRumusService(this._api);

  final ApiClient _api;

  @override
  Future<List<Rumus>> daftar(String token) async {
    final json = await _api.get('/formulas', token: token);

    return parseListAman(
      json['data'] as List<dynamic>? ?? const [],
      Rumus.fromJson,
    );
  }

  @override
  Future<List<VersiRumus>> versi(String token, int formulaId) async {
    final json = await _api.get('/formulas/$formulaId/versions', token: token);

    return parseListAman(
      json['data'] as List<dynamic>? ?? const [],
      VersiRumus.fromJson,
    );
  }

  @override
  Future<VersiRumus?> versiPadaTanggal(
    String token,
    int formulaId,
    DateTime tanggal,
  ) async {
    final iso = tanggal.toIso8601String().split('T').first;
    final json = await _api.get(
      '/formulas/$formulaId/versi-berlaku?tanggal=$iso',
      token: token,
    );

    final data = json['data'];

    // `null` itu jawaban yang SAH: tanggalnya bisa jatuh sebelum versi
    // pertama pernah berlaku. Dibedain dari error biar layarnya bisa bilang
    // "belum ada aturan buat tanggal itu", bukan "gagal muat".
    return data is Map<String, dynamic> ? VersiRumus.fromJson(data) : null;
  }

  @override
  Future<VersiRumus> terbitkanVersi(
    String token,
    int formulaId,
    VersiRumusBaru isi,
  ) async {
    final json = await _api.post(
      '/formulas/$formulaId/versions',
      token: token,
      body: isi.toJson(),
    );

    return VersiRumus.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<VersiRumus> ubahVersi(
    String token,
    int versiId, {
    StatusVersiRumus? status,
    String? catatan,
  }) async {
    final json = await _api.patch(
      '/formula-versions/$versiId',
      token: token,
      // Dua-duanya opsional: PATCH ini dipakai buat ngubah status DOANG,
      // catatan doang, atau dua-duanya. Kunci yang nggak dikirim artinya
      // "jangan disentuh" — beda dari dikirim bernilai null, yang backend
      // baca sebagai permintaan ngosongin.
      body: <String, dynamic>{
        'status': ?status?.kode,
        'catatan': ?catatan,
      },
    );

    return VersiRumus.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }
}

/// Data tiruan buat test & mode mock.
class MockRumusService implements RumusService {
  MockRumusService({this.jeda = Duration.zero, this.gagal = false});

  final Duration jeda;
  final bool gagal;

  static final _v1 = VersiRumus(
    id: 1,
    formulaId: 1,
    nomorVersi: 1,
    sumber: SumberRumus.kode,
    status: StatusVersiRumus.aktif,
    berlakuDari: DateTime(2024, 1, 1),
    parameter: const {'faktor_cakupan': 2, 'tingkat_kepercayaan': 95},
    catatan: 'Versi awal, dibikin sistem waktu kalibrasi pertama disimpan.',
    olehSistem: true,
    dibuatPada: DateTime(2024, 1, 1),
  );

  final List<VersiRumus> _versi = [_v1];

  @override
  Future<List<Rumus>> daftar(String token) async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal memuat rumus.');

    return [
      Rumus(
        id: 1,
        kode: 'GUM-PH',
        nama: 'Ketidakpastian GUM — pH Meter',
        besaran: 'pH',
        deskripsi: 'Gabungan Type A (sebaran pembacaan) & Type B (CMC lab).',
        jumlahVersi: _versi.length,
        versiBerlaku: _versi.firstWhere(
          (v) => v.masihBerlaku,
          orElse: () => _v1,
        ),
      ),
    ];
  }

  @override
  Future<List<VersiRumus>> versi(String token, int formulaId) async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal memuat versi.');

    return _versi.reversed.toList();
  }

  @override
  Future<VersiRumus?> versiPadaTanggal(
    String token,
    int formulaId,
    DateTime tanggal,
  ) async {
    await Future<void>.delayed(jeda);

    return _versi
        .where((v) => !v.berlakuDari!.isAfter(tanggal))
        .fold<VersiRumus?>(null, (a, b) => a == null || b.nomorVersi > a.nomorVersi ? b : a);
  }

  @override
  Future<VersiRumus> terbitkanVersi(
    String token,
    int formulaId,
    VersiRumusBaru isi,
  ) async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal menerbitkan versi.');

    final baru = VersiRumus(
      id: _versi.length + 1,
      formulaId: formulaId,
      nomorVersi: _versi.length + 1,
      sumber: SumberRumus.kode,
      status: isi.langsungAktif
          ? StatusVersiRumus.aktif
          : StatusVersiRumus.draft,
      berlakuDari: isi.berlakuDari,
      parameter: isi.parameter,
      catatan: isi.catatan,
      pembuat: 'Admin',
      dibuatPada: DateTime.now(),
    );

    _versi.add(baru);

    return baru;
  }

  @override
  Future<VersiRumus> ubahVersi(
    String token,
    int versiId, {
    StatusVersiRumus? status,
    String? catatan,
  }) async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal mengubah versi.');

    final i = _versi.indexWhere((v) => v.id == versiId);
    final lama = _versi[i];

    final baru = VersiRumus(
      id: lama.id,
      formulaId: lama.formulaId,
      nomorVersi: lama.nomorVersi,
      sumber: lama.sumber,
      status: status ?? lama.status,
      berlakuDari: lama.berlakuDari,
      berlakuSampai: lama.berlakuSampai,
      parameter: lama.parameter,
      ekspresi: lama.ekspresi,
      catatan: catatan ?? lama.catatan,
      pembuat: lama.pembuat,
      olehSistem: lama.olehSistem,
      dibuatPada: lama.dibuatPada,
    );

    _versi[i] = baru;

    return baru;
  }
}
