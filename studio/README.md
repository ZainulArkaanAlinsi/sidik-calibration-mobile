# Sidik Studio

Pusat kendali data & olah data PT Sidik — aplikasi Flutter **terpisah** dari app
lapangan (`com.ptsidik.kalibrasi`), untuk **Windows** dan **tablet Android**.
Rencana: `_agents_workspace/studio-data-acuan/06-rencana-rescope.md` (repo API).

| | Studio | App lapangan |
|---|---|---|
| Android applicationId | `com.ptsidik.studio` | `com.ptsidik.kalibrasi` |
| Windows exe / ProductName | `sidik_studio.exe` / "Sidik Studio" | `sidik_calibration.exe` / "PT Sidik - Kalibrasi" |
| Push (Firebase) | tidak | ya |
| Pembaru Windows | ya — manifest sendiri `versi-studio-windows.json` (rilis-desktop.yml, job `studio`) | ya (`versi-windows-v2.json`) |
| Pembaru APK | tidak | ya |
| OCR / kamera / onboarding | tidak | ya |

Lapisan data (ApiClient, token, auth, izin, data acuan) dan layar data acuan M2
dipakai ulang dari paket akar lewat `sidik_calibration: path: ../`. Server tetap
satu-satunya tempat hitung — Studio tidak menghitung sendiri.

## Menjalankan

```bash
cd studio
flutter pub get
flutter gen-l10n
flutter run -d windows --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Petunjuk akun uji di layar masuk cuma muncul bila `APP_ENV=dev` disebut eksplisit.

## Periksa

```bash
flutter analyze        # dari dalam studio/ — akar repo mengecualikan studio/**
flutter test
```

`pubspec.lock` Studio disemai dari `pubspec.lock` akar supaya versi plugin
bersama identik di dua aplikasi. Setelah akar menaikkan versi, ulangi:
salin `../pubspec.lock` ke sini, lalu `flutter pub get`.

## Struktur

- `lib/main.dart`, `lib/app.dart` — titik masuk & akar (tanpa Firebase; pembaru Windows hanya di build rilis).
- `lib/inti/` — penimpaan provider paket bersama (push → `TanpaTokenPush`),
  lingkungan (`APP_ENV`), mode tema.
- `lib/tema/` — desain sistem Studio: `WarnaStudio` (ThemeExtension),
  `TemaStudio`, font yang dirujuk dari paket (Inter, IBM Plex Mono).
- `lib/inti/sesi_studio.dart` — 401 → dialog sesi berakhir, 426 → layar versi
  usang, keluar + sapuan cache. `inti/penimpaan.dart` memasang header
  `X-Klien: sidik-studio` / `X-Versi-Klien` (= `version:` pubspec, dijaga test)
  lewat `KlienHttpBeridentitas` paket bersama — app lapangan tidak mengirimnya.
- `lib/layar/` — masuk, gerbang, cangkang (sidebar ≥ 1024 meja / rail berlabel /
  rail ikon potret / drawer < 600), seksi, Beranda.
- `lib/widget/bilah_status.dart` — server, koneksi, realtime (`GET /health`),
  pengguna + peran; di tablet dilipat ke menu akun.
- `test/goldens/` — golden cangkang 1280/1138/711 × terang/gelap, dibuat di
  Windows (platform acuan, lihat `test/flutter_test_config.dart`).
- `assets/merek/ikon-studio.png` — tanda merek, sumber yang sama dengan ikon
  peluncur Android & `windows/runner/resources/app_icon.ico`.
