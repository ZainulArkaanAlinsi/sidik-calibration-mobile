import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/klien_http_beridentitas.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';

import '../data/sesi_api_studio.dart';
import 'lingkungan_studio.dart';
import 'sesi_studio.dart';

/// Penimpaan provider paket bersama yang berlaku di SELURUH Studio.
///
/// ## Kopling auth → FCM, dan kenapa ditimpa di sini
///
/// `auth_provider.dart` (paket bersama) mengimpor `pendaftaran_push_provider`,
/// yang memakai `firebase_messaging`. Di app lapangan kopling itu benar: login
/// mendaftarkan token push, logout mencabutnya.
///
/// Studio tidak memakai push sama sekali — tidak ada `Firebase.initializeApp`,
/// tidak ada `google-services.json`, dan akar Studio tidak menonton
/// `pendaftaranPushSyncProvider` (yang ditonton `SidikApp` lapangan). Yang
/// tersisa cuma satu jalur: `AuthController.logout` membaca
/// [sumberTokenPushProvider] untuk mencabut token perangkat. Tanpa penimpaan,
/// di Android jalur itu membangun `FcmSumberTokenPush` → menyentuh
/// `FirebaseMessaging.instance` pada Firebase yang tidak pernah dinyalakan.
/// Gagalnya memang ditelan di sana, tapi "aman karena kebetulan ditelan" bukan
/// keputusan.
///
/// [TanpaTokenPush] adalah implementasi resmi paket bersama untuk keadaan
/// "perangkat ini tidak punya push" (desktop & mode mock memakainya juga):
/// token `null` → tidak ada panggilan pendaftaran maupun pencabutan.
///
/// ## `ApiClient` Studio: identitas klien + pengamat sesi
///
/// Semua layanan paket bersama mengambil `ApiClient` dari [apiClientProvider].
/// Studio menimpanya dengan client yang dibungkus [KlienHttpBeridentitas]:
///  - `X-Klien: sidik-studio` + `X-Versi-Klien: <versi pubspec>` di SETIAP
///    request (FR-STU-003) — JSON, multipart, byte, pemanasan `/health`;
///  - tiap jawaban diamati [amatiResponsStudio]: `401` bertoken → dialog sesi
///    berakhir, `426` → layar versi usang.
///
/// Perilaku app lapangan TIDAK berubah: penimpaan ini hidup di `ProviderScope`
/// Studio saja, dan `ApiClient` sendiri tidak diubah.
///
/// ## Alur versi data acuan: BACA SAJA
///
/// Rute tulis alur (`POST /data-acuan/versi/{v}/ajukan|simulasi|tolak|
/// aktifkan`) ada di grup `aplikasi:internal` server; token Studio (ability
/// `studio`) dijawab `403 bukan_aplikasi_ini` di sana, dan izin Studio
/// (`MatriksIzin::PETA_STUDIO`) tidak membawa `data-acuan.ajukan/simulasi/
/// aktifkan`. Alasannya BR-08: satu akun Studio tidak bisa menjadi orang
/// kedua. [alurAcuanBacaSajaProvider] `true` → layar alur paket bersama
/// menampilkan arahan "lakukan dari aplikasi lab", tanpa tombol.
final List<Override> penimpaanStudio = [
  sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
  alurAcuanBacaSajaProvider.overrideWithValue(true),
  apiClientProvider.overrideWith((ref) {
    final klien = KlienHttpBeridentitas(
      header: headerKlienStudio,
      pengamat: (respons) => amatiResponsStudio(ref, respons),
    );
    ref.onDispose(klien.close);

    return ApiClient(
      baseUrl: ref.watch(alamatServerStudioProvider),
      // Sama dengan app lapangan: server Render gratis tidur sesudah ±15 menit.
      bangunkanDulu: true,
      client: klien,
    );
  }),
];

/// Sesi Studio: `/studio/me` & `/studio/logout`.
///
/// Token Studio (ability `studio`) ditolak rute lab `/me`, `/me/permissions`,
/// `/logout`. [authServiceProvider] dan [izinServiceProvider] ditimpa ke
/// layanan Studio (`data/sesi_api_studio.dart`); izin Studio datang dari
/// `GET /studio/me`. Dipasang `main.dart` SAJA, terpisah dari
/// [penimpaanStudio] supaya widget test yang menimpa layanan auth-nya sendiri
/// tidak menimpa provider yang sama dua kali.
final List<Override> penimpaanSesiStudio = [
  authServiceProvider.overrideWith((ref) {
    if (AppConfig.useMock) return MockAuthService();
    return ApiAuthServiceStudio(ref.watch(apiClientProvider));
  }),
  izinServiceProvider.overrideWith((ref) {
    if (AppConfig.useMock) return MockIzinService();
    return ApiIzinServiceStudio(ref.watch(apiClientProvider));
  }),
];
