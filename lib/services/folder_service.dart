import '../models/folder.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

abstract class FolderService {
  /// [parentId] null = folder akar (daftar PT).
  Future<List<Folder>> daftar(String token, {int? parentId});

  /// Sub-folder + file di dalamnya.
  Future<Folder> detail(String token, int id);

  /// Bikin folder baru. **Admin doang** — backend nolak role lain dengan 403.
  ///
  /// Hasilnya SELALU `tipe: manual`; tipe `sistem` cuma boleh lahir dari
  /// `FolderOrganizer` di backend, biar nggak ada folder "sistem" palsu yang
  /// nggak nyambung ke data mana pun.
  Future<Folder> buat(String token, {required String nama, int? parentId});

  /// Ganti nama / keterangan. Folder `sistem` **namanya nggak bisa diubah**
  /// (backend nolak `prohibited`): namanya = nama PT / tahun, dan itu yang
  /// dipakai buat nemuin folder yang udah ada. Begitu direname, sertifikat
  /// berikutnya bikin folder baru dan arsipnya kepecah dua.
  Future<Folder> ubah(
    String token,
    int id, {
    String? nama,
    String? keterangan,
  });

  Future<void> hapus(String token, int id);
}

/// `GET /api/folders`. Bacanya semua role — isinya udah disaring per-role di
/// controller (teknisi cuma lihat file miliknya sendiri). Nulisnya admin doang,
/// dan mobile emang nggak nyediain jalur nulis: folder kebentuk otomatis.
class ApiFolderService implements FolderService {
  ApiFolderService(this._api);

  final ApiClient _api;

  @override
  Future<List<Folder>> daftar(String token, {int? parentId}) async {
    final path = parentId == null
        ? '/folders'
        : '/folders?parent_id=$parentId';

    final json = await _api.get(path, token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return parseListAman(data, Folder.fromJson);
  }

  @override
  Future<Folder> detail(String token, int id) async {
    final json = await _api.get('/folders/$id', token: token);
    return Folder.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Folder> buat(
    String token, {
    required String nama,
    int? parentId,
  }) async {
    final json = await _api.post(
      '/folders',
      token: token,
      body: {'nama': nama, 'parent_id': ?parentId},
    );
    return Folder.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Folder> ubah(
    String token,
    int id, {
    String? nama,
    String? keterangan,
  }) async {
    final json = await _api.put(
      '/folders/$id',
      token: token,
      body: {
        // Cuma kirim yang beneran diubah — `nama` buat folder sistem ditolak
        // backend, jadi jangan ikut kekirim waktu yang diubah keterangannya.
        'nama': ?nama,
        'keterangan': ?keterangan,
      },
    );
    return Folder.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/folders/$id', token: token);
  }
}

class MockFolderService implements FolderService {
  MockFolderService({this.kosong = false, this.gagal = false});

  final bool kosong;
  final bool gagal;

  /// Jejak aksi tulis buat test — `('buat', nama)`, `('ubah', id)`, dst.
  final List<(String, Object?)> aksi = [];

  @override
  Future<Folder> buat(String token, {required String nama, int? parentId}) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('buat', nama));
    return Folder(
      id: 99,
      nama: nama,
      // Backend selalu bikin folder tangan sebagai `manual`.
      tipe: 'manual',
      parentId: parentId,
      jumlahFolder: 0,
      jumlahFile: 0,
    );
  }

  @override
  Future<Folder> ubah(
    String token,
    int id, {
    String? nama,
    String? keterangan,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('ubah', id));
    return Folder(
      id: id,
      nama: nama ?? 'Arsip Lama',
      tipe: 'manual',
      parentId: null,
      keterangan: keterangan,
      jumlahFolder: 0,
      jumlahFile: 1,
    );
  }

  @override
  Future<void> hapus(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    aksi.add(('hapus', id));
  }

  static const _akar = [
    Folder(
      id: 1,
      nama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
      tipe: 'sistem',
      parentId: null,
      jumlahFolder: 2,
      jumlahFile: 0,
    ),
    Folder(
      id: 2,
      nama: 'PT ANEKA SARANA',
      tipe: 'sistem',
      parentId: null,
      jumlahFolder: 1,
      jumlahFile: 0,
    ),
    Folder(
      id: 3,
      nama: 'Arsip Lama',
      tipe: 'manual',
      parentId: null,
      jumlahFolder: 0,
      jumlahFile: 1,
    ),
  ];

  @override
  Future<List<Folder>> daftar(String token, {int? parentId}) async {
    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return const [];
    if (parentId == null) return _akar;

    return const [
      Folder(
        id: 11,
        nama: '2026',
        tipe: 'sistem',
        parentId: 1,
        jumlahFolder: 0,
        jumlahFile: 2,
      ),
    ];
  }

  @override
  Future<Folder> detail(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');

    return Folder(
      id: id,
      nama: id == 11 ? '2026' : 'PT TIRTA GRACIA SEMESTA MANDIRI',
      tipe: 'sistem',
      parentId: id == 11 ? 1 : null,
      jumlahFolder: id == 11 ? 0 : 1,
      jumlahFile: id == 11 ? 2 : 0,
      subFolder: id == 11
          ? const []
          : const [
              Folder(
                id: 11,
                nama: '2026',
                tipe: 'sistem',
                parentId: 1,
                jumlahFolder: 0,
                jumlahFile: 2,
              ),
            ],
      file: id == 11
          ? const [
              FolderFile(
                id: 101,
                folderId: 11,
                nama: '012-CAL-524.pdf',
                downloadUrl: 'https://contoh/folder-files/101/download',
                mime: 'application/pdf',
                ukuran: 248_512,
                sertifikatNomor: '012-CAL-524',
                sertifikatSiapDiunduh: true,
              ),
            ]
          : const [],
    );
  }
}
