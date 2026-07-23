import '../models/folder.dart';
import 'api_client.dart';

abstract class FolderService {
  /// [parentId] null = folder akar (daftar PT).
  Future<List<Folder>> daftar(String token, {int? parentId});

  /// Sub-folder + file di dalamnya.
  Future<Folder> detail(String token, int id);
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

    return data.cast<Map<String, dynamic>>().map(Folder.fromJson).toList();
  }

  @override
  Future<Folder> detail(String token, int id) async {
    final json = await _api.get('/folders/$id', token: token);
    return Folder.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }
}

class MockFolderService implements FolderService {
  MockFolderService({this.kosong = false, this.gagal = false});

  final bool kosong;
  final bool gagal;

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
