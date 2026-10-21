import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/api_auth_service.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/izin_service.dart';

/// Token Studio (ability `studio`) DITOLAK rute lab `/me`, `/me/permissions`,
/// dan `/logout` (`403 bukan_aplikasi_ini`). Kontrak API "Satu akun Studio":
/// Studio memakai `GET /studio/me` dan `POST /studio/logout`. Login tetap
/// `POST /login` (header `X-Klien: sidik-studio` sudah dipasang klien Studio).
class ApiAuthServiceStudio extends ApiAuthService {
  ApiAuthServiceStudio(this._klien) : super(_klien);

  final ApiClient _klien;

  @override
  Future<User> me(String token) async {
    final json = await _klien.get('/studio/me', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String token) async {
    await _klien.post('/studio/logout', token: token);
  }

  /// Studio tidak punya "keluar dari semua perangkat" (`/logout-all` rute lab);
  /// keluar mencabut token yang dipakai saja.
  @override
  Future<int> logoutAll(String token) async {
    await logout(token);

    return 1;
  }
}

/// Izin Studio dari `GET /studio/me` (`data.izin`), bukan `/me/permissions`.
/// Gagal → [Izin.kosong] (alasan sama dengan [ApiIzinService]).
class ApiIzinServiceStudio implements IzinService {
  ApiIzinServiceStudio(this._api);

  final ApiClient _api;

  @override
  Future<Izin> ambil(String token) async {
    try {
      final json = await _api.get('/studio/me', token: token);
      final data = (json['data'] ?? json) as Map<String, dynamic>;

      return Izin.fromJson(data['izin'] as Map<String, dynamic>);
    } catch (_) {
      return Izin.kosong;
    }
  }
}
