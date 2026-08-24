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

  /// Saklar UI pindai lembar. Default **false** — dua tombolnya
  /// (`PINDAI LEMBAR KERJA` di atas tabel & `FOTO TABEL INI` di tiap tabel)
  /// nggak digambar sama sekali, di SEMUA lembar kerja.
  ///
  /// Nyalain lagi tanpa nyentuh kode: `--dart-define=PINDAI_LEMBAR=true`.
  ///
  /// **Disembunyiin, bukan dihapus.** Yang di belakang dua tombol itu mesin
  /// geometri di HP (`services/pindai_lembar.dart` — 477 baris deteksi marker
  /// + warp perspektif Dart murni) plus layar review per sel; dua-duanya mahal
  /// dibangun ulang dan Gelombang 5 bakal makai lagi. Jadi yang dicabut cuma
  /// pintunya, ruangannya dibiarin utuh.
  ///
  /// Sengaja `const bool.fromEnvironment` kayak [useMock]: di build release
  /// nilainya ke-hardcode waktu compile, jadi jalur yang geometrinya belum
  /// diverifikasi nggak mungkin nyala diam-diam di APK teknisi.
  static const bool pindaiLembarAktif = bool.fromEnvironment('PINDAI_LEMBAR');

  /// Kunci app Reverb (protokol Pusher) buat realtime sync (spec poin 12D).
  /// **Kosong = realtime nonaktif** — app tetap jalan normal, cuma nggak ada
  /// push; data ketarik seperti biasa waktu layar dibuka. Diisi lewat
  /// `--dart-define=REVERB_APP_KEY=...` begitu server Reverb dinyalain.
  static const String reverbAppKey = String.fromEnvironment('REVERB_APP_KEY');

  static const String _reverbHostOverride = String.fromEnvironment('REVERB_HOST');

  /// Port websocket Reverb (default 8080).
  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );

  /// TLS (wss) buat websocket. Default false (dev pakai ws).
  static const bool reverbTls = bool.fromEnvironment('REVERB_TLS');

  /// Host websocket. Default = host dari [apiBaseUrl] (server yang sama).
  static String get reverbHost => _reverbHostOverride.isNotEmpty
      ? _reverbHostOverride
      : Uri.parse(apiBaseUrl).host;

  /// Realtime hidup kalau ada kunci Reverb & bukan mode mock.
  static bool get realtimeAktif => reverbAppKey.isNotEmpty && !useMock;

  /// URL websocket Reverb (protokol Pusher, protocol 7).
  static String get reverbWsUrl {
    final skema = reverbTls ? 'wss' : 'ws';
    return '$skema://$reverbHost:$reverbPort/app/$reverbAppKey'
        '?protocol=7&client=flutter&version=1.0.0';
  }

  /// Endpoint otorisasi channel privat (Echo `authEndpoint`).
  static String get broadcastingAuthUrl => '$apiBaseUrl/broadcasting/auth';

  static AppEnv get env => switch (_rawEnv) {
    'prod' => AppEnv.prod,
    'staging' => AppEnv.staging,
    _ => AppEnv.dev,
  };

  static bool get isProd => env == AppEnv.prod;

  static String get envLabel => env.name.toUpperCase();
}
