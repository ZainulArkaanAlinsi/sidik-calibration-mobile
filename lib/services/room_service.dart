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

  /// `GET /rooms` itu **berpaginasi** `paginate(15)` yang dipatok di backend —
  /// `per_page` nggak dihormati. Waktu di sini cuma halaman 1 yang dibaca,
  /// ruangan ke-16 dan seterusnya ilang dari dropdown "Ruangan" di lembar
  /// kerja tanpa error apa pun: teknisi cuma nggak nemu ruangannya di daftar,
  /// dan admin nggak punya cara tau ada yang kurang.
  ///
  /// Jadi halamannya diikutin sampai habis — pola yang sama persis kayak
  /// `ApiRuanganService.daftarRuangan` di `ruangan_service.dart`, sengaja
  /// nggak dibikin beda biar dua-duanya nggak melenceng sendiri-sendiri.
  /// Master data ruangan nggak bakal ribuan, jadi ini murah — dan lebih murah
  /// lagi daripada data yang hilang diam-diam.
  ///
  /// Batas 50 halaman dipasang sebagai rem: kalau backend suatu saat balikin
  /// `meta` yang muter, dropdown-nya berhenti, bukan ngeloop selamanya.
  @override
  Future<List<Room>> daftar(String token) async {
    final semua = <Room>[];

    for (var halaman = 1; halaman <= 50; halaman++) {
      // `hanya_aktif=1` bikin SERVER yang nyaring (lihat `RoomController::
      // index`). Bukan cuma hemat byte: ruangan nonaktif yang ikut kekirim
      // makan jatah 15 per halaman, jadi tanpa parameter ini daftar aktifnya
      // kepecah ke lebih banyak halaman daripada yang perlu.
      final json = await _api.get(
        '/rooms?page=$halaman&hanya_aktif=1',
        token: token,
      );

      semua.addAll(
        parseListAman(
          json['data'] as List<dynamic>? ?? const [],
          Room.fromJson,
        ),
      );

      final meta = json['meta'];
      // Nggak ada `meta` = respons belum/nggak dipaginasi. Sekali ambil cukup.
      if (meta is! Map<String, dynamic>) break;

      final kini = (meta['current_page'] as num?)?.toInt() ?? halaman;
      final akhir = (meta['last_page'] as num?)?.toInt() ?? halaman;
      if (kini >= akhir) break;
    }

    return semua
        // Ruangan nonaktif nggak ditawarin buat sesi baru, tapi sengaja nggak
        // dihapus dari model — sesi lama masih nunjuk ke sana.
        //
        // Saringan ini SENGAJA nggak dicabut walau `hanya_aktif=1` di atas
        // udah minta server yang nyaring: server versi lama belum kenal
        // parameter itu dan bakal ngabaikannya DIAM-DIAM — nggak ada 422,
        // nggak ada tanda apa pun, cuma ruangan nonaktif yang nongol lagi di
        // dropdown sesi baru. Sabuk dan bretel: yang satu hemat halaman, yang
        // satu jaga isinya bener di server versi berapa pun.
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
