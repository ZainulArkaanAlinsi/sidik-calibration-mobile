import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/versi_service.dart';

/// Sumber "ada APK Studio yang lebih baru?" untuk Studio di Android.
///
/// ## Kenapa bukan `ApiVersiService` paket bersama apa adanya
///
/// `GET /app/versi-terbaru` TANPA parameter menjawab APK app lapangan
/// (`sidik-kalibrasi-*.apk`, versi `1.0.NNN`). Studio adalah aplikasi lain
/// (`com.ptsidik.studio`, versi `0.1.NNN`): kalau memakai jawaban itu,
/// Studio akan (a) menawari pasang APK app lapangan dan (b) selalu merasa
/// tertinggal karena `0.1.x < 1.0.x`. Karena itu Studio bertanya
/// `?aplikasi=studio` — server memulangkan aset `sidik-studio-<versi>.apk`
/// dari rilis yang sama, dengan `versi` dari NAMA ASET (skema versi Studio),
/// bukan dari tag rilis.
///
/// Versi TERPASANG dibaca lewat [ApiVersiService] paket bersama (mesin
/// `package_info_plus`-nya sudah ada di sana; Studio tidak menambah
/// dependensi), jadi dua sisi perbandingan memakai skema yang sama:
/// `--build-name` APK Studio = nama versi di nama asetnya (`rilis-desktop.yml`
/// job `studio` dan workflow `apk-studio-rilis.yml` menyusun nomor
/// dengan cara yang sama).
///
/// Perilaku gagal sama dengan yang bersama: tidak pernah melempar, `null` =
/// belum tahu / belum ada rilis Studio.
class ApiVersiServiceStudio implements VersiService {
  ApiVersiServiceStudio(this._api, {VersiService? terpasang})
    : _terpasang = terpasang ?? ApiVersiService(_api);

  /// Nilai `?aplikasi=` yang dikenal server untuk Sidik Studio.
  static const String parameterAplikasi = 'studio';

  final ApiClient _api;
  final VersiService _terpasang;

  @override
  Future<String> versiTerpasang() => _terpasang.versiTerpasang();

  @override
  Future<String> buildTerpasang() => _terpasang.buildTerpasang();

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    try {
      // Tanpa token, sama dengan jalur app lapangan: endpoint-nya publik.
      final json = await _api.get(
        '/app/versi-terbaru?aplikasi=$parameterAplikasi',
      );

      return VersiAplikasi.fromJson(json);
    } catch (_) {
      // Pemeriksaan latar: gagal = diam. Lihat `ApiVersiService.versiTerbaru`.
      return null;
    }
  }
}
