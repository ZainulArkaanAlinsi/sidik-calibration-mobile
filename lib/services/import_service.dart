import '../models/import_excel.dart';
import 'api_client.dart';

/// Import Excel buat masa transisi (spesifikasi poin 12C). Admin doang.
abstract class ImportService {
  /// [ujiCoba] `true` = server baca & cocokkan filenya, tapi **semua
  /// perubahannya dibatalin** — dipakai buat nampilin ringkasan sebelum admin
  /// mutusin. `false` = beneran nulis.
  Future<HasilImport> unggah(
    String token, {
    required String filePath,
    required String tipe,
    required bool ujiCoba,
  });
}

class ApiImportService implements ImportService {
  ApiImportService(this._api);

  final ApiClient _api;

  @override
  Future<HasilImport> unggah(
    String token, {
    required String filePath,
    required String tipe,
    required bool ujiCoba,
  }) async {
    final json = await _api.unggahFile(
      '/imports/excel',
      field: 'file',
      filePath: filePath,
      token: token,
      fields: {
        'tipe': tipe,
        // Dikirim eksplisit dua-duanya. Backend default-nya uji coba kalau
        // kuncinya nggak ada — tapi jangan gantung ke default buat sesuatu
        // yang nulis ke master data.
        'uji_coba': ujiCoba ? '1' : '0',
      },
    );

    return HasilImport.fromJson(
      (json['data'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      pesan: json['message'] as String?,
    );
  }
}

class MockImportService implements ImportService {
  MockImportService({this.gagal = false});

  final bool gagal;

  final List<(String tipe, bool ujiCoba)> aksi = [];

  @override
  Future<HasilImport> unggah(
    String token, {
    required String filePath,
    required String tipe,
    required bool ujiCoba,
  }) async {
    if (gagal) throw Exception('File-nya harus .xlsx, .xls, atau .csv.');

    aksi.add((tipe, ujiCoba));

    return HasilImport.fromJson({
      'tipe': tipe,
      'uji_coba': ujiCoba,
      'kolom_terpetakan': {'nama': 'Nama PT', 'alamat': 'Alamat'},
      'kolom_diabaikan': ['Catatan Internal'],
      'ringkasan': {
        'dibaca': 3,
        'dibuat': 2,
        'diperbarui': 1,
        'dilewati': 0,
      },
      'baris': [
        {'baris': 2, 'tindakan': 'dibuat', 'nama': 'PT TIRTA GRACIA'},
        {'baris': 3, 'tindakan': 'dibuat', 'nama': 'PT ANEKA SARANA'},
        {'baris': 4, 'tindakan': 'diperbarui', 'nama': 'PT SIDIK'},
      ],
    }, pesan: ujiCoba ? 'Uji coba selesai.' : 'Import selesai.');
  }
}
