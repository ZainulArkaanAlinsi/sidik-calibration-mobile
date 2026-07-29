import '../models/arsip.dart';
import '../core/utils/parse_list.dart';
import '../models/calibration_history_item.dart';
import 'api_client.dart';

/// Arsip = file manager di atas data kalibrasi
/// (`docs/permintaan-endpoint.md` → `HANDOFF-FOLDER-ARSIP.md` di backend).
abstract class ArsipService {
  Future<List<ArsipPerusahaan>> daftarPerusahaan(String token, {String? cari});

  /// Buka folder akar perusahaan — backend bikin foldernya kalau belum ada.
  Future<ArsipIsiFolder> bukaPerusahaan(String token, int customerId);

  Future<ArsipIsiFolder> bukaFolder(String token, int folderId);

  Future<void> bikinFolder(String token, {required int parentId, required String nama});

  Future<void> ubahNama(String token, {required int folderId, required String nama});

  Future<void> pindahFolder(String token, {required int folderId, required int parentId});

  Future<void> hapusFolder(String token, int folderId);

  Future<void> pindahBerkas(String token, {required int sesiId, required int folderId});
}

class ApiArsipService implements ArsipService {
  ApiArsipService(this._api);

  final ApiClient _api;

  @override
  Future<List<ArsipPerusahaan>> daftarPerusahaan(String token, {String? cari}) async {
    final query = cari == null || cari.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(cari.trim())}';

    final json = await _api.get('/arsip/perusahaan$query', token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return parseListAman(data, ArsipPerusahaan.fromJson);
  }

  @override
  Future<ArsipIsiFolder> bukaPerusahaan(String token, int customerId) async {
    return ArsipIsiFolder.fromJson(
      await _api.get('/arsip/perusahaan/$customerId/folder', token: token),
    );
  }

  @override
  Future<ArsipIsiFolder> bukaFolder(String token, int folderId) async {
    return ArsipIsiFolder.fromJson(
      await _api.get('/arsip/folders/$folderId', token: token),
    );
  }

  @override
  Future<void> bikinFolder(String token, {required int parentId, required String nama}) {
    return _api.post(
      '/arsip/folders',
      token: token,
      body: {'parent_id': parentId, 'nama': nama},
    );
  }

  @override
  Future<void> ubahNama(String token, {required int folderId, required String nama}) {
    return _api.put('/arsip/folders/$folderId', token: token, body: {'nama': nama});
  }

  @override
  Future<void> pindahFolder(String token, {required int folderId, required int parentId}) {
    return _api.put(
      '/arsip/folders/$folderId/pindah',
      token: token,
      body: {'parent_id': parentId},
    );
  }

  @override
  Future<void> hapusFolder(String token, int folderId) {
    return _api.delete('/arsip/folders/$folderId', token: token);
  }

  @override
  Future<void> pindahBerkas(String token, {required int sesiId, required int folderId}) {
    return _api.put(
      '/arsip/berkas/$sesiId/pindah',
      token: token,
      body: {'folder_id': folderId},
    );
  }
}

/// Data tiruan buat test & mode mock.
class MockArsipService implements ArsipService {
  MockArsipService({this.gagal = false});

  final bool gagal;

  /// Pohon in-memory sederhana: id → (nama, parentId, customerId).
  final Map<int, ArsipFolder> _folder = {
    1: const ArsipFolder(
      id: 1,
      nama: 'PT Tirta Gracia',
      isRoot: true,
      jumlahSubfolder: 1,
      jumlahBerkas: 1,
    ),
    // Folder tahun kebentuk otomatis dari tanggal sertifikat — `sistem`, bukan
    // bikinan admin. Bukan akar, tapi tetap nggak bisa direname/dipindah.
    2: const ArsipFolder(
      id: 2,
      nama: '2026',
      parentId: 1,
      isRoot: false,
      tipe: 'sistem',
      jumlahSubfolder: 0,
      jumlahBerkas: 0,
    ),
  };

  /// Berkas → folder tempatnya sekarang.
  ///
  /// Dipisah dari peta folder biar `pindahBerkas` beneran mindahin di layar,
  /// bukan no-op yang bikin test lulus tanpa ngebuktiin apa-apa.
  final Map<int, int> _berkasDiFolder = {3: 1};

  int _idBerikutnya = 4;

  void _cek() {
    if (gagal) throw Exception('server nggak nyaut');
  }

  @override
  Future<List<ArsipPerusahaan>> daftarPerusahaan(String token, {String? cari}) async {
    _cek();

    const semua = [
      ArsipPerusahaan(
        id: 1,
        nama: 'PT Tirta Gracia',
        alamat: 'Cicalengka, Kab. Bandung',
        jumlahAlat: 2,
        jumlahSertifikat: 1,
      ),
      ArsipPerusahaan(
        id: 2,
        nama: 'PT Contoh Sejahtera',
        alamat: 'Bandung',
        jumlahAlat: 1,
        jumlahSertifikat: 0,
      ),
    ];

    if (cari == null || cari.trim().isEmpty) return semua;

    return semua
        .where((p) => p.nama.toLowerCase().contains(cari.toLowerCase()))
        .toList();
  }

  @override
  Future<ArsipIsiFolder> bukaPerusahaan(String token, int customerId) async {
    _cek();
    return bukaFolder(token, 1);
  }

  @override
  Future<ArsipIsiFolder> bukaFolder(String token, int folderId) async {
    _cek();

    final folder = _folder[folderId]!;

    // Jumlah isi dihitung ulang tiap kali dibaca, bukan disimpen di objeknya —
    // backend asli juga gitu (`withCount`). Kalau di-cache, folder yang baru
    // dikasih subfolder tetap kebaca "kosong" dan tombol Hapus-nya nyala
    // padahal server bakal nolak.
    final anak = [
      for (final f in _folder.values.where((f) => f.parentId == folderId))
        ArsipFolder(
          id: f.id,
          nama: f.nama,
          parentId: f.parentId,
          isRoot: f.isRoot,
          tipe: f.tipe,
          jumlahSubfolder: _folder.values.where((c) => c.parentId == f.id).length,
          jumlahBerkas: _berkasDiFolder.values.where((v) => v == f.id).length,
        ),
    ];

    // Breadcrumb dirangkai dari parentId — sama kayak yang dibalikin backend.
    final crumbs = <ArsipBreadcrumb>[];
    ArsipFolder? kursor = folder;
    while (kursor != null) {
      crumbs.insert(
        0,
        ArsipBreadcrumb(id: kursor.id, nama: kursor.nama, isRoot: kursor.isRoot),
      );
      kursor = kursor.parentId == null ? null : _folder[kursor.parentId];
    }

    return ArsipIsiFolder(
      folderId: folder.id,
      namaFolder: folder.nama,
      isRoot: folder.isRoot,
      namaPerusahaan: 'PT Tirta Gracia',
      breadcrumb: crumbs,
      subfolder: anak,
      berkas: _berkasDiFolder[3] == folder.id
          ? [
              ArsipBerkas(
                id: 3,
                status: CalibrationStatus.disetujui,
                nomorSesi: 'KAL/2026/07/0001',
                namaAlat: 'pH Meter Mettler Toledo',
                namaTeknisi: 'Andi',
                tanggalKalibrasi: DateTime(2026, 7, 20),
                keputusan: Keputusan.pass,
                nomorSertifikat: '012-CAL-524',
                pdfUrl: 'https://contoh/sertifikat.pdf',
              ),
            ]
          : const [],
    );
  }

  @override
  Future<void> bikinFolder(String token, {required int parentId, required String nama}) async {
    _cek();

    final bentrok = _folder.values.any(
      (f) => f.parentId == parentId && f.nama == nama,
    );
    if (bentrok) throw Exception('Di folder ini udah ada folder dengan nama yang sama.');

    final id = _idBerikutnya++;
    _folder[id] = ArsipFolder(
      id: id,
      nama: nama,
      parentId: parentId,
      isRoot: false,
      jumlahSubfolder: 0,
      jumlahBerkas: 0,
    );
  }

  @override
  Future<void> ubahNama(String token, {required int folderId, required String nama}) async {
    _cek();

    final lama = _folder[folderId]!;
    _folder[folderId] = ArsipFolder(
      id: lama.id,
      nama: nama,
      parentId: lama.parentId,
      isRoot: lama.isRoot,
      tipe: lama.tipe,
      jumlahSubfolder: lama.jumlahSubfolder,
      jumlahBerkas: lama.jumlahBerkas,
    );
  }

  @override
  Future<void> pindahFolder(String token, {required int folderId, required int parentId}) async {
    _cek();

    final lama = _folder[folderId]!;

    // Dua penolakan yang sama kayak backend. Ditiru di sini biar UI yang lupa
    // mencegahnya ketahuan pas test, bukan pas dipakai orang.
    if (lama.folderSistem) {
      throw Exception('Folder sistem nggak bisa dipindah.');
    }
    if (_keturunanDari(folderId).contains(parentId)) {
      throw Exception('Folder nggak bisa dipindah ke dalam folder di bawahnya.');
    }

    _folder[folderId] = ArsipFolder(
      id: lama.id,
      nama: lama.nama,
      parentId: parentId,
      isRoot: lama.isRoot,
      tipe: lama.tipe,
      jumlahSubfolder: lama.jumlahSubfolder,
      jumlahBerkas: lama.jumlahBerkas,
    );
  }

  /// Folder itu sendiri + semua anak-cucunya.
  Set<int> _keturunanDari(int folderId) {
    final hasil = {folderId};
    var tumbuh = true;

    while (tumbuh) {
      tumbuh = false;
      for (final f in _folder.values) {
        final induk = f.parentId;
        if (induk != null && hasil.contains(induk) && hasil.add(f.id)) {
          tumbuh = true;
        }
      }
    }

    return hasil;
  }

  @override
  Future<void> hapusFolder(String token, int folderId) async {
    _cek();
    _folder.remove(folderId);
  }

  @override
  Future<void> pindahBerkas(String token, {required int sesiId, required int folderId}) async {
    _cek();
    _berkasDiFolder[sesiId] = folderId;
  }
}
