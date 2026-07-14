/// Konfigurasi environment aplikasi.
///
/// Nilainya di-inject waktu build lewat `--dart-define`, jadi tidak ada
/// URL/secret yang di-hardcode di source. Contoh:
///
/// ```
/// flutter run --dart-define=APP_ENV=dev \
///             --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
/// ```
library;

enum AppEnv { dev, staging, prod }

class AppConfig {
  const AppConfig._();

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Default `10.0.2.2` = alamat localhost host machine dilihat dari emulator
  /// Android, jadi cocok buat `php artisan serve` yang jalan di laptop.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Saklar mock. Default **false** — app nembak API asli.
  ///
  /// Nyalain kalau backend lagi mati / kamu lagi ngoding UI tanpa server:
  /// `flutter run --dart-define=USE_MOCK=true`
  ///
  /// Sengaja `const bool.fromEnvironment`, bukan variabel biasa: di build
  /// release nilainya ke-hardcode waktu compile, jadi mock **nggak mungkin**
  /// kebawa nyala diam-diam ke APK produksi.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static AppEnv get env => switch (_rawEnv) {
    'prod' => AppEnv.prod,
    'staging' => AppEnv.staging,
    _ => AppEnv.dev,
  };

  static bool get isProd => env == AppEnv.prod;

  static String get envLabel => env.name.toUpperCase();
}
