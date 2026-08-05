import '../models/room.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

abstract class RoomService {
  Future<List<Room>> daftar(String token);
}

/// `GET /api/rooms` — bacanya semua role (teknisi butuh buat dropdown
/// "Ruangan" di lembar kerja), nulisnya admin doang.
class ApiRoomService implements RoomService {
  ApiRoomService(this._api);

  final ApiClient _api;

  @override
  Future<List<Room>> daftar(String token) async {
    final json = await _api.get('/rooms', token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return parseListAman(data, Room.fromJson)
        // Ruangan nonaktif nggak ditawarin buat sesi baru, tapi sengaja nggak
        // dihapus dari model — sesi lama masih nunjuk ke sana.
        .where((r) => r.aktif)
        .toList();
  }
}

class MockRoomService implements RoomService {
  MockRoomService({this.kosong = false, this.gagal = false});

  final bool kosong;

  /// Beda dari [kosong]: "belum ada ruangan kedaftar" itu keadaan sah, "daftar
  /// ruangannya nggak keambil" itu kegagalan — dan layar wajib bedain
  /// dua-duanya. Lihat `DropdownGagal`.
  final bool gagal;

  @override
  Future<List<Room>> daftar(String token) async => gagal
      ? throw Exception('server nggak nyaut')
      : kosong
      ? const []
      : const [
          Room(
            id: 1,
            nama: 'Lab. Uji A',
            kode: 'LAB-A',
            aktif: true,
            suhuMin: 18,
            suhuMax: 25,
            kelembabanMin: 40,
            kelembabanMax: 70,
          ),
          Room(id: 2, nama: 'Lab. Suhu', kode: 'LAB-S', aktif: true),
        ];
}
