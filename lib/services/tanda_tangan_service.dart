import 'dart:typed_data'; 

import '../models/tanda_tangan.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Tanda tangan yang dicetak di sertifikat — **admin doang**.
///
/// Teknisi & viewer kena `403` di keempat endpoint, **termasuk pratinjaunya**.
abstract class TandaTanganService {
  /// Keadaan sekarang: udah ada tanda tangannya belum, dan posisinya di mana.
  Future<TandaTanganInfo> info(String token);

  /// Byte PNG-nya. `null` = belum ada yang diunggah.
  Future<Uint8List?> gambar(String token);

  /// Unggah PNG baru. **JPG ditolak backend `422`** — JPG nggak punya latar
  /// transparan, jadi kecetak sebagai kotak putih yang nutupin garis tanda
  /// tangan & nama di bawahnya. Pesan `422`-nya udah nyebut alasan lengkap,
  /// jadi tampilkan apa adanya, jangan diganti "format tidak didukung".
  Future<TandaTanganInfo> unggah(String token, String filePath);

  Future<void> hapus(String token);

  Future<TandaTanganInfo> setPosisi(String token, TandaTanganPosisi posisi);
}

class ApiTandaTanganService implements TandaTanganService {
  ApiTandaTanganService(this._api);

  final ApiClient _api;

  static const _path = '/organization/tanda-tangan';

  @override
  Future<TandaTanganInfo> info(String token) async {
    // Penandanya nempel di objek organisasi, bukan endpoint sendiri —
    // hemat satu request waktu layar dibuka.
    final json = await _api.get('/organization', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return TandaTanganInfo.fromJson(data);
  }

  @override
  Future<Uint8List?> gambar(String token) =>
      _api.ambilBytes(_path, token: token);

  @override
  Future<TandaTanganInfo> unggah(String token, String filePath) async {
    final json = await _api.unggahFile(
      _path,
      field: 'tanda_tangan',
      filePath: filePath,
      token: token,
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return TandaTanganInfo.fromJson(data);
  }

  @override
  Future<void> hapus(String token) => _api.delete(_path, token: token);

  @override
  Future<TandaTanganInfo> setPosisi(
    String token,
    TandaTanganPosisi posisi,
  ) async {
    final json = await _api.patch(
      '$_path/posisi',
      token: token,
      body: posisi.toJson(),
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return TandaTanganInfo.fromJson(data);
  }
}

/// Versi in-memory buat mode mock & widget test.
///
/// Nyimpen perubahannya beneran, jadi test bisa mastiin geser/simpan
/// nyampe ke tempat yang bener.
class MockTandaTanganService implements TandaTanganService {
  MockTandaTanganService({this.gagalUnggah = false, bool adaTtd = false})
    : _punya = adaTtd;

  /// Meniru penolakan `422` waktu yang diunggah bukan PNG.
  final bool gagalUnggah;

  bool _punya;
  TandaTanganPosisi _posisi = const TandaTanganPosisi();

  @override
  Future<TandaTanganInfo> info(String token) async =>
      TandaTanganInfo(punyaTandaTangan: _punya, posisi: _posisi);

  @override
  Future<Uint8List?> gambar(String token) async {
    if (!_punya) return null;
    return _pngSatuPiksel;
  }

  @override
  Future<TandaTanganInfo> unggah(String token, String filePath) async {
    if (gagalUnggah) {
      throw ApiException(
        'Tanda tangan harus PNG. JPG nggak punya latar transparan, jadi '
        'kecetak sebagai kotak putih yang nutupin garis tanda tangan.',
        status: 422,
        body: const {},
      );
    }
    _punya = true;
    return TandaTanganInfo(punyaTandaTangan: true, posisi: _posisi);
  }

  @override
  Future<void> hapus(String token) async {
    _punya = false;
  }

  @override
  Future<TandaTanganInfo> setPosisi(
    String token,
    TandaTanganPosisi posisi,
  ) async {
    _posisi = posisi;
    return TandaTanganInfo(punyaTandaTangan: _punya, posisi: _posisi);
  }
}

/// PNG 1x1 transparan — cukup buat `Image.memory` di test tanpa nyeret
/// berkas gambar beneran ke dalam repo.
final Uint8List _pngSatuPiksel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
