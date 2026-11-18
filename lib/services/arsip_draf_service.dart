import '../core/utils/parse_list.dart';
import '../models/arsip_draf.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'pengguna_sa_service.dart' show HalamanHasil;

/// Arsipkan draf lembar kerja dan kelola arsipnya.
///
/// Kontrak: `docs/perintah-frontend-crud-lengkap.md` §3. Hanya sesi berstatus
/// `draft` yang bisa diarsipkan; **tidak ada hapus permanen** (nilai yang
/// diisi teknisi tidak pernah hilang, ISO/IEC 17025 7.5.2). Pembuat draf
/// (teknisi) atau admin/super admin mengarsipkan; hanya admin/super admin yang
/// membuka daftar arsip dan memulihkan. Server yang menegakkan.
///
/// Galat 4xx dilempar sebagai `ApiException` (badan asli: `kode`, `errors`,
/// `status`) — layar yang memetakannya ke kalimat.
abstract class ArsipDrafService {
  /// `GET /calibrations?diarsipkan=1` — admin/super admin (selain itu `403
  /// hanya_admin`). 15 per halaman, terakhir diarsipkan di atas.
  Future<HalamanHasil<DrafArsipan>> daftar(
    String token, {
    String? cari,
    int halaman = 1,
  });

  /// `POST /calibrations/{id}/arsipkan` — [alasan] 5–400 karakter. Idempoten.
  Future<HasilArsipDraf> arsipkan(
    String token,
    int id, {
    required String alasan,
  });

  /// `POST /calibrations/{id}/pulihkan` — [alasan] opsional (maks 400).
  Future<HasilArsipDraf> pulihkan(String token, int id, {String? alasan});
}

class ApiArsipDrafService implements ArsipDrafService {
  ApiArsipDrafService(this._api);

  final ApiClient _api;

  @override
  Future<HalamanHasil<DrafArsipan>> daftar(
    String token, {
    String? cari,
    int halaman = 1,
  }) async {
    final q = <String, String>{
      'diarsipkan': '1',
      if (cari != null && cari.trim().isNotEmpty) 'q': cari.trim(),
      if (halaman > 1) 'page': '$halaman',
    };
    final qs = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final json = await _api.get('/calibrations?$qs', token: token);
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);
    return HalamanHasil(
      items: parseListAman(
        json['data'] as List<dynamic>? ?? const [],
        DrafArsipan.fromJson,
      ),
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<HasilArsipDraf> arsipkan(
    String token,
    int id, {
    required String alasan,
  }) async => HasilArsipDraf.fromJson(
    // POST tanpa `client_request_id`: tidak diulang otomatis. Aman: server
    // idempoten (yang sudah diarsipkan dijawab 200, tanpa audit kedua).
    await _api.post(
      '/calibrations/$id/arsipkan',
      token: token,
      body: {'alasan': alasan},
    ),
  );

  @override
  Future<HasilArsipDraf> pulihkan(
    String token,
    int id, {
    String? alasan,
  }) async => HasilArsipDraf.fromJson(
    await _api.post(
      '/calibrations/$id/pulihkan',
      token: token,
      body: {'alasan': ?alasan},
    ),
  );
}

/// Tiruan in-memory buat test dan mode mock. Meniru aturan server seperlunya
/// (alasan 5–400, `bukan_draf`, idempoten arsipkan, `tidak_diarsipkan`).
class MockArsipDrafService implements ArsipDrafService {
  MockArsipDrafService({
    List<DrafArsipan>? awal,
    Map<int, String>? statusSesi,
    this.galat,
    this.ukuranHalaman = 15,
    this.jeda = Duration.zero,
  }) : _data = [...(awal ?? contoh)],
       _statusSesi = {...?statusSesi};

  /// Bila diisi, dilempar oleh SETIAP panggilan (meniru 403/429/jaringan).
  final Object? galat;
  final int ukuranHalaman;
  final Duration jeda;
  final List<DrafArsipan> _data;

  /// Status sesi yang BUKAN draf (id → status) — arsipkan ditolak `bukan_draf`.
  final Map<int, String> _statusSesi;

  /// Catatan panggilan buat assert di test.
  final List<String> catatan = [];

  static final contoh = <DrafArsipan>[
    DrafArsipan(
      id: 412,
      nomorSesi: 'KAL/2026/11/0007',
      status: 'draft',
      tanggalKalibrasi: DateTime(2026, 11, 18),
      namaAlat: 'Timbangan Analitik',
      nomorSeri: 'SN-123',
      namaPelanggan: 'PT Tirta Contoh Mandiri',
      namaTeknisi: 'Dedi Teknisi',
      arsip: JejakArsip(
        alasan: 'Salah pilih alat, dibuat ulang.',
        olehNama: 'Dedi Teknisi',
        pada: DateTime.utc(2026, 11, 18, 3, 20),
      ),
    ),
    DrafArsipan(
      id: 413,
      nomorSesi: 'KAL/2026/11/0008',
      status: 'draft',
      namaAlat: 'pH Meter Mettler Toledo',
      namaPelanggan: 'CV Maju Bersama',
      namaTeknisi: 'Eko Prasetyo',
      arsip: JejakArsip(
        alasan: 'Alat dikembalikan pelanggan sebelum dikerjakan.',
        olehNama: 'Rina Master Data',
        pada: DateTime.utc(2026, 11, 17, 8),
      ),
    ),
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

  @override
  Future<HalamanHasil<DrafArsipan>> daftar(
    String token, {
    String? cari,
    int halaman = 1,
  }) async {
    await _awal('daftar cari=$cari h=$halaman');
    final kata = (cari ?? '').trim().toLowerCase();
    final cocok = _data
        .where(
          (d) =>
              kata.isEmpty ||
              (d.nomorSesi ?? '').toLowerCase().contains(kata) ||
              d.namaAlat.toLowerCase().contains(kata) ||
              d.namaPelanggan.toLowerCase().contains(kata),
        )
        .toList();
    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final mulai = (halaman - 1) * ukuranHalaman;
    return HalamanHasil(
      items: cocok.skip(mulai).take(ukuranHalaman).toList(),
      halaman: halaman,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<HasilArsipDraf> arsipkan(
    String token,
    int id, {
    required String alasan,
  }) async {
    await _awal('arsipkan $id "$alasan"');
    final panjang = alasan.trim().length;
    if (panjang < 5 || panjang > 400) {
      throw _galat422(
        'Alasan harus 5 sampai 400 karakter.',
        errors: {
          'alasan': ['Alasan harus 5 sampai 400 karakter.'],
        },
      );
    }
    final status = _statusSesi[id];
    if (status != null) {
      throw _galat422(
        'Hanya draf yang bisa diarsipkan; sesi ini sudah $status.',
        kode: 'bukan_draf',
        tambahan: {'status': status},
      );
    }
    final ada = _data.where((d) => d.id == id).firstOrNull;
    if (ada != null) {
      return HasilArsipDraf(
        id: id,
        nomorSesi: ada.nomorSesi,
        diarsipkan: true,
        arsip: ada.arsip,
      );
    }
    final baru = DrafArsipan(
      id: id,
      status: 'draft',
      arsip: JejakArsip(
        alasan: alasan.trim(),
        olehNama: 'Rina Master Data',
        pada: DateTime.now().toUtc(),
      ),
    );
    _data.insert(0, baru);
    return HasilArsipDraf(id: id, diarsipkan: true, arsip: baru.arsip);
  }

  @override
  Future<HasilArsipDraf> pulihkan(
    String token,
    int id, {
    String? alasan,
  }) async {
    await _awal('pulihkan $id ${alasan ?? ''}');
    final ada = _data.where((d) => d.id == id).firstOrNull;
    if (ada == null) {
      throw _galat422(
        'Draf ini tidak sedang diarsipkan.',
        kode: 'tidak_diarsipkan',
      );
    }
    _data.removeWhere((d) => d.id == id);
    return HasilArsipDraf(id: id, nomorSesi: ada.nomorSesi, diarsipkan: false);
  }
}
