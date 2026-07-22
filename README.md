# PT Sidik Kalibrasi — Mobile

Aplikasi mobile (Flutter, satu APK) untuk kalibrasi alat ukur & sertifikat digital — teknisi dan admin pakai app yang sama, dibedakan lewat role. Dikembangkan selama program magang di PT Sidik, dikerjakan berdua.

## Tech Stack
- **Framework**: Flutter 3.41 (Dart 3.11)
- **State management**: Riverpod (`flutter_riverpod`) — lihat [Keputusan Teknis](#keputusan-teknis)
- **OCR**: Google ML Kit Text Recognition (menyusul, minggu 5)
- **Backend**: Laravel, repo terpisah [`sidik-calibration-api`](https://github.com/ZainulArkaanAlinsi/sidik-calibration-api) (PIC: @raihannazhiif)

## Setup Lokal

```bash
git clone <url-repo>
cd asmo_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Pastikan `flutter doctor` bersih (tanpa silang merah) sebelum run pertama kali.

### Konfigurasi environment
Tidak ada URL yang di-hardcode. Semua lewat `--dart-define` (lihat `lib/core/config/app_config.dart`):

| Key | Default | Keterangan |
| --- | --- | --- |
| `APP_ENV` | `dev` | `dev` / `staging` / `prod` |
| `API_BASE_URL` | `http://10.0.2.2:8000/api` | `10.0.2.2` = localhost laptop dilihat dari emulator Android, jadi nyambung ke `php artisan serve` |

Kalau test di HP fisik, ganti ke IP LAN laptop, misal `--dart-define=API_BASE_URL=http://192.168.1.10:8000/api`.

## Perintah Harian

```bash
flutter analyze   # wajib bersih sebelum commit
flutter test      # unit + widget test
flutter run       # jalanin app
```

## Struktur Folder

```
lib/
├── main.dart          # entrypoint: ProviderScope + SidikApp
├── app.dart           # MaterialApp (tema + halaman awal)
├── core/
│   └── config/        # AppConfig (environment, base URL)
├── providers/         # Riverpod providers
├── screens/           # 1 folder per fitur (startup, auth, dashboard, ...)
├── models/            # menyusul
├── services/          # api_service, auth_service, ocr_service — menyusul
└── widgets/           # komponen reusable — menyusul
```

Folder `models/`, `services/`, dan `widgets/` sengaja belum dibuat — nyusul pas fiturnya masuk, biar repo nggak penuh folder kosong.

## Keputusan Teknis

**State management: Riverpod** (bukan Provider / Bloc / GetX).
- Provider (`package:provider`) ketergantungan sama `BuildContext`, ribet dipakai di service layer & flow OCR yang banyak async.
- Bloc kebanyakan boilerplate buat tim 2 orang dengan tenggat 2-3 bulan.
- Riverpod: compile-safe, gampang di-override waktu test (lihat `test/widget_test.dart`), dan `AsyncValue` cocok buat state loading/error API + kamera yang bakal banyak dipakai nanti.

## Prinsip Desain
- Bottom nav sama buat semua role — yang beda cuma isi tab **Profil** (admin dapat menu tambahan; disembunyikan total dari non-admin, bukan sekadar disabled)
- Hasil scan kamera **wajib direview & dikonfirmasi** sebelum tersimpan — tombol lanjut disabled sampai semua field lengkap
- Input manual selalu tersedia sebagai fallback, OCR cuma mempercepat
- UI konsisten pakai design system dari awal — target akhirnya app ini mungkin ditawarkan ke perusahaan lain

## Git Workflow
`main` / `develop` / `feature/nama-fitur`, Conventional Commits, PR wajib direview.

## Status Project
Rencana harian & progress lengkap ada di vault Obsidian `Project-PT-Sidik/`.
