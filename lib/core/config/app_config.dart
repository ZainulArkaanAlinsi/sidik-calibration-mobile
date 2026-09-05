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

  /// Saklar UI pindai lembar. Default **true** sejak 25 Agt 2026 — dua
  /// tombolnya (`PINDAI LEMBAR KERJA` di atas tabel & `FOTO TABEL INI` di tiap
  /// tabel) digambar di SEMUA lembar kerja.
  ///
  /// Bawaannya pernah `false`: permintaan 3 minta UI pindai dicabut "untuk
  /// sekarang", lalu pemilik proyek membalik keputusan itu. Waktu dicabut yang
  /// dilakukan cuma menutup pintunya — mesin geometri di HP
  /// (`services/pindai_lembar.dart` — 477 baris deteksi marker + warp
  /// perspektif Dart murni) dan layar review per sel dibiarkan utuh, jadi
  /// menyalakannya kembali memang cukup membalik satu nilai ini.
  ///
  /// **Yang nyala nggak sama dengan yang bisa dipakai**, dan bedanya penting.
  /// Dua tombol itu MESIN YANG BEDA, bukan dua tampilan dari satu jalur:
  ///
  ///  - `PINDAI LEMBAR KERJA` — OCR template lokal. Butuh **lembar bermarker**
  ///    yang dicetak dari `ocr:cetak-lembar`, dan mengisi SELURUH tabel dalam
  ///    satu jepretan. Ketujuh belas profil sudah punya berkas geometri, tapi
  ///    file yang ada belum tentu boleh dipakai: gerbangnya `terverifikasi`,
  ///    dan per 26 Agt 2026 baru **6 dari 17** yang true — keenamnya lembar
  ///    kimia. Sisanya tombolnya digambar tapi MATI, berikut alasannya. Itu
  ///    perilaku yang memang dirancang begitu; lihat `TemplateLembarKerja`.
  ///  - `FOTO TABEL INI` — ML Kit, **sepenuhnya di perangkat** (lihat
  ///    `services/pembaca_halaman.dart`). Diarahkan ke formulir LAMA lab yang
  ///    nggak bermarker, satu jepretan per tabel, dan jangkarnya tulisan yang
  ///    memang tercetak di kertas (titik ukur + kepala kolom pengulangan).
  ///    Jadi dia NGGAK butuh lembar bermarker maupun `terverifikasi`.
  ///
  /// ### Tiga bentuk kertas, tiga jangkar baris yang beda
  ///
  /// Tombol kedua itu satu nama buat tiga jalur, dan yang membedakan **apa yang
  /// menjangkar barisnya**:
  ///
  ///  1. **Titik ukur × Repeat** (13 lembar) — baris dijangkar NILAI standar
  ///     yang tercetak di kolom kiri. Digerbangi `pindai_foto.didukung` dari
  ///     server, dan dua penanda bentuk yang menyertainya cuma sanggup
  ///     menggambarkan bentuk ini.
  ///  2. **Grid sensor** (kelima Enclosure) — baris dijangkar NOMOR TERMOKOPEL
  ///     yang sudah diketik teknisi; sumbu ketiganya (set point) datang dari
  ///     blok tempat tombolnya ditekan, bukan dari citra. Tombolnya di
  ///     `LembarKerjaGrid`, satu per blok.
  ///  3. **Matriks** (Autoklaf) — baris dijangkar TULISAN nama besaran
  ///     (`Temp. Disk 1`, `Indikator Pressure`) di kolom kiri. Tombolnya di
  ///     `LembarKerjaMatriks`.
  ///
  /// Dua yang terakhir SENGAJA nggak membaca `pindai_foto.didukung`: penanda
  /// itu `false` buat mereka, dan itu benar — kertasnya memang nggak muat di
  /// bentuk titik × Repeat. Yang menggerbanginya keberadaan grid/matriksnya
  /// sendiri, plus saklar ini.
  ///
  /// **Yang masih belum punya jalur kamera cuma TIDS**, dan yang menahan bukan
  /// pemetanya: baris lembarnya sendiri belum sampai ke layar (K18 — lihat
  /// `test/tids_baris_tanpa_titik_test.dart`).
  ///
  /// Jalur AI Vision **cloud** yang dulu memberi makan tombol kedua sudah
  /// dicabut; jangan baca "FOTO TABEL INI" sebagai jalur cloud.
  ///
  /// Tetap `bool.fromEnvironment` supaya bisa DIMATIKAN lagi tanpa ganti kode
  /// (`--dart-define=PINDAI_LEMBAR=false`) — saklarnya masih saklar, cuma
  /// posisi bawaannya yang pindah.
  static const bool pindaiLembarAktif = bool.fromEnvironment(
    'PINDAI_LEMBAR',
    defaultValue: true,
  );

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
