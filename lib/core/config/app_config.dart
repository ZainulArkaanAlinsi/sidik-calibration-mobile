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

  static AppEnv get env => switch (_rawEnv) {
    'prod' => AppEnv.prod,
    'staging' => AppEnv.staging,
    _ => AppEnv.dev,
  };

  static bool get isProd => env == AppEnv.prod;

  static String get envLabel => env.name.toUpperCase();
}
