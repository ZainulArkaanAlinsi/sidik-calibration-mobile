# Deploy lewat Firebase — Android, macOS, Windows

Status: siap dijalankan, **nunggu `firebase login` + repository variable
`API_BASE_URL`** · 15 Agustus 2026

Tujuannya satu: app-nya bisa dipasang orang lain tanpa laptop developer, di
tiga tempat sekaligus — HP teknisi, Mac, dan PC Windows.

Ini **langkah antara**, bukan pengganti
[`infrastruktur-vps-produksi.md`](infrastruktur-vps-produksi.md). Yang dibahas
di sini cuma cara membagikan aplikasinya. Backend-nya tetap di tempatnya
sekarang.

## Status hari ini

| | |
|---|---|
| Project Firebase `sidik-kalibrasi` | ✅ ada, aktif (`.firebaserc` di repo) |
| Aplikasi Android terdaftar | ✅ App ID di bawah |
| Grup tester `teknisi` | ✅ dibuat, **belum ada anggotanya** |
| Paket **uji offline** (mock) Windows/macOS/Android | ✅ bisa dibagikan sekarang |
| Paket **nyambung server** | ⛔ terhalang — backend belum berdiri |

Yang menghalangi versi nyambung-server cuma satu: layanan Render di
`render.yaml` (repo `sidik-calibration-api`) **belum pernah dideploy**.
`https://sidik-calibration-api.onrender.com/up` tidak menjawab sama sekali —
TCP-nya tersambung tapi nol byte selama 240 detik, dan itu bukan pola cold
start. Tiga run terakhir workflow "APK rilis (nyambung server)" juga semuanya
gagal dalam 8–10 detik di penjagaan `API_BASE_URL`.

Membereskannya butuh akun Aiven + Render dan penempelan rahasia (`APP_KEY`,
password database, `GEMINI_API_KEY`) — langkah yang di
`sidik-calibration-api/docs/deploy-gratis-render.md` memang sudah ditandai
"cuma bisa kamu yang ngerjain". Sesudah layanannya hidup, yang perlu diubah di
sini cuma satu baris:

```bash
gh variable set API_BASE_URL --body "https://<yang-asli>.onrender.com"
```

lalu jalankan ulang kedua workflow rilis.

### Jalan pintas: APK nyambung backend laptop (quick tunnel)

Kalau butuh APK yang beneran membaca data hari ini juga, tanpa nunggu Render,
backend di laptop bisa dibuka ke internet lewat quick tunnel Cloudflare —
gratis, tanpa akun, tanpa domain:

```bash
# terminal 1 — di repo sidik-calibration-api
php artisan serve --port=8000

# terminal 2
cloudflared tunnel --url http://127.0.0.1:8000
# catat URL https://<acak>.trycloudflare.com yang muncul

# terminal 3 — di repo mobile
flutter build apk --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL="https://<acak>.trycloudflare.com/api"
```

Yang harus diterima kalau menempuh jalur ini:

- **URL-nya acak dan mati begitu `cloudflared` berhenti.** Restart tunnel =
  URL baru = APK harus dibangun ulang. Jangan taruh URL ini ke repository
  variable `API_BASE_URL`: build CI berikutnya akan lolos penjagaan lalu
  menghasilkan APK yang menembak alamat yang sudah tidak ada.
- **Laptop harus nyala dan tunnel harus jalan.** Laptop tidur, aplikasi mati.
- **Seluruh backend ikut terbuka, bukan cuma `/api`.** Panel Filament di
  `/admin` ikut bisa dibuka siapa pun yang tahu URL-nya, dan akun hasil seeder
  memakai password `rahasia123` (lihat `database/seeders/DatabaseSeeder.php`).
  Database yang dipakai juga database kerja, bukan database contoh. Karena itu
  tunnel ini untuk uji singkat yang ditunggui, lalu dimatikan — bukan
  ditinggal hidup.

## Firebase bisa apa, dan tidak bisa apa

| Target | Jalur | Catatan |
|---|---|---|
| HP Android | **App Distribution** | Cocok. APK dikirim OTA, tester pasang dari link, build baru masuk sendiri |
| HP iOS | App Distribution | Butuh akun Apple Developer ($99/tahun) + UDID tiap HP didaftarkan. Belum dipakai |
| macOS & Windows | **Hosting**, sebagai halaman unduh | App Distribution **tidak menerima** biner desktop. Hosting di sini perannya turun jadi file server biasa |
| Backend Laravel | — | **Firebase tidak menjalankan PHP.** Hosting cuma file statis, Functions cuma Node/Python |

Poin terakhir yang paling sering salah dikira: memindahkan backend ke Firebase
itu bukan pekerjaan yang lebih kecil, itu pekerjaan yang tidak ada jalurnya.
Backend tetap di Render (lihat `API_BASE_URL` di
`.github/workflows/apk-rilis-cloud.yml`).

## Yang beres dan yang tidak

| | |
|---|---|
| ✅ HP harus dicolok / `adb` tiap sesi | hilang — APK terpasang permanen dari link |
| ✅ Windows butuh laptop Windows | hilang — dibangun di runner `windows-latest` |
| ✅ Pemakai lain harus punya Flutter | hilang — semuanya file jadi |
| ❌ Aplikasi desktop ditandatangani | **tidak.** Gatekeeper & SmartScreen tetap protes, pemakai harus melewatinya manual |
| ❌ Update desktop otomatis | **tidak.** Windows & macOS harus unduh ulang manual. Cuma Android yang dapat update otomatis |
| ❌ Fitur pindai lembar kerja di desktop | **tidak, dan bukan karena deploy.** ML Kit cuma ada di Android/iOS |

## Sekali seumur hidup: siapkan akun

Sudah dijalankan — project `sidik-kalibrasi` (project number `573275146800`)
sudah ada dan jadi project aktif. Buat laptop kedua (mis. Arkaan), yang perlu
cuma:

```bash
firebase login
firebase use sidik-kalibrasi
```

Lalu pasang URL backend sebagai repository variable — **Variable, bukan
Secret**. Secret disensor jadi `***` di log, padahal nilainya tetap ketanam ke
biner lewat `--dart-define`; menyensornya di log tidak menambah aman, cuma
bikin susah waktu mencari sebab error.

```bash
gh variable set API_BASE_URL --body "https://<nama>.onrender.com"
```

Perhatikan: yang diisi **tanpa** `/api` di belakang. Workflow yang menambahkan
sendiri.

## Android — App Distribution

1. Aplikasi Android-nya **sudah didaftarkan** di project `sidik-kalibrasi`:

   | | |
   |---|---|
   | Package name | `com.ptsidik.kalibrasi` |
   | App ID | `1:573275146800:android:6b5ffb7202167a0ccb3bf5` |

   App ID bukan rahasia — nilainya ikut terbawa di dalam setiap APK, jadi aman
   ditulis di repo publik ini. Yang rahasia tetap cuma isi `.env` backend.
2. `google-services.json` **tidak perlu diunduh**. App ini belum memakai SDK
   Firebase apa pun di dalam kodenya — App Distribution cuma menerima APK jadi.
3. Bangun APK-nya. Cara termudah: jalankan workflow **"APK rilis (nyambung
   server)"** dari tab Actions, lalu unduh artifact-nya. Atau lokal:

   ```bash
   flutter build apk --release \
     --dart-define=APP_ENV=prod \
     --dart-define=API_BASE_URL="https://<nama>.onrender.com/api"
   ```

4. Kirim ke tester:

   ```bash
   firebase appdistribution:distribute \
     build/app/outputs/flutter-apk/app-release.apk \
     --app "1:573275146800:android:6b5ffb7202167a0ccb3bf5" \
     --groups "teknisi" \
     --release-notes "uji lapangan spektro"
   ```

5. Daftarkan email tester di Console → App Distribution → **Testers & groups**,
   grup `teknisi`. Mereka dapat email, pasang aplikasi **App Tester**, selesai.

Efek samping yang bagus: begitu APK release terpasang permanen, urusan pairing
`adb` dan bentrok debug keystore hilang dari pemakaian sehari-hari. Yang masih
kena cuma sesi `flutter run`.

> APK release ini masih ditandatangani debug key (lihat
> `android/app/build.gradle.kts`). Cukup untuk uji internal. Sebelum dipasang di
> HP pelanggan, kunci rilis sendiri harus dibuat dulu — kalau tidak, aplikasinya
> tidak akan pernah bisa di-update oleh siapa pun yang tidak punya debug key
> laptop ini.

## macOS & Windows — build

Jalankan workflow **"Rilis desktop (nyambung server)"**
(`.github/workflows/rilis-desktop.yml`) dari tab Actions. Hasilnya dua artifact
zip yang sudah siap pakai: `sidik-windows.zip` dan `sidik-macos.zip`.

Kenapa macOS pun lewat CI, padahal laptopnya Mac: supaya dua platform keluar
dari sumber dan versi Flutter yang sama persis. Kalau satu dibangun di laptop
dan satu di CI, beda perilaku antar platform jadi susah dilacak sebabnya.

Kalau memang mau macOS dibangun lokal:

```bash
flutter build macos --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL="https://<nama>.onrender.com/api"

cd build/macos/Build/Products/Release
ditto -c -k --keepParent PTSidikCalibration.app ~/sidik-macos.zip
```

Pakai `ditto`, jangan `zip` biasa: bundel `.app` isinya symlink dan bit
executable, dan `zip` merusak keduanya — hasilnya tidak bisa dibuka di Mac
tujuan.

### Soal sandbox macOS

`macos/Runner/Release.entitlements` **tidak lagi memakai** `app-sandbox`. Itu
bukan kelalaian, itu syarat supaya build yang dibagikan bisa login sama sekali:
sandbox menuntut `keychain-access-groups`, yang cuma ditegakkan pada aplikasi
bertanda tangan Developer ID. Tanpa itu `flutter_secure_storage` gagal dengan
`errSecMissingEntitlement (-34018)`, dan karena `AsyncValue.guard` di
`auth_provider.dart` menelan exception-nya, di layar itu muncul sebagai "login
gagal" — bukan sebagai error Keychain.

Kalau nanti aplikasinya ditandatangani Developer ID dan dinotarisasi, sandbox
boleh dinyalakan lagi, tapi `keychain-access-groups` harus ikut dipasang.

## Halaman unduh — Hosting

```bash
# taruh dua zip hasil workflow di folder public/
cp ~/Downloads/sidik-windows.zip public/
cp ~/Downloads/sidik-macos.zip   public/

firebase deploy --only hosting
```

Hasilnya satu URL `https://<project>.web.app` berisi tiga tombol: Android
(link App Distribution), macOS, Windows.

Sebelum deploy pertama, buka `public/index.html` dan ganti
`#ganti-link-app-distribution` dengan link undangan tester dari Console.

Isi `public/*.zip` sengaja tidak di-commit (lihat `.gitignore`) — puluhan MB dan
bisa diregenerasi kapan saja dari workflow. Yang di-commit cuma halaman unduhnya.

### Paket uji offline — jalur yang dipakai sekarang

Selama backend belum berdiri, yang dibagikan adalah paket mock: login
`SDK-0001` / `rahasia123`, data contoh yang ikut dibundel, dan nol panggilan
jaringan. Banner di `public/index.html` sudah menyatakan itu; kalau nanti
diganti paket nyambung-server, banner itu harus ikut dicabut supaya halamannya
tidak berbohong.

```bash
gh workflow run "Paket tes (mock, tanpa server)"
gh run watch <run-id> --exit-status

gh run download <run-id> --name sidik-tes-mock-windows --dir /tmp/win
cd /tmp/win && zip -qr ~/sidik-windows.zip . && cd -
cp ~/sidik-windows.zip public/

gh run download <run-id> --name sidik-tes-mock-macos --dir /tmp/mac
cp /tmp/mac/sidik-tes-mock-macos.zip public/sidik-macos.zip

firebase deploy --only hosting
```

Artifact Windows turun sebagai isi folder `Release`, bukan zip — makanya dizip
lagi di sini. Artifact macOS sudah berupa zip buatan `ditto` dari dalam
workflow, jadi tinggal disalin; jangan dibongkar lalu dizip ulang dengan `zip`
biasa, karena itu mengembalikan persis kerusakan symlink yang `ditto` hindari.

## Yang harus diingat setiap rilis

`API_BASE_URL` **ketanam waktu compile**, bukan dibaca waktu jalan. Ganti alamat
backend berarti membangun ulang ketiga platform — tidak ada cara mengubahnya
dari sisi Hosting atau dari sisi aplikasi yang sudah terpasang. Jadi pastikan
URL backend sudah final sebelum mulai membagikan.

Nomor versi di `pubspec.yaml` (`version: 1.0.0+1`) belum pernah dinaikkan. Untuk
Android itu bukan sekadar kosmetik: Android menolak memasang APK dengan
`versionCode` yang tidak lebih besar dari yang sudah terpasang. Naikkan angka
sesudah `+` setiap kali mengirim build baru ke App Distribution.

## Kenapa bukan Flutter Web

Sempat masuk akal: satu build, jalan di Windows, macOS, dan HP lewat browser.
Tapi jalurnya tertutup di kode yang sekarang, bukan cuma butuh waktu lebih:

- Folder `web/` belum ada sama sekali.
- `lib/providers/sumber_foto_provider.dart:24` memakai `Platform` dari
  `dart:io`, yang tidak ada di web — gagal saat kompilasi, bukan saat jalan.
- `google_mlkit_text_recognition` dan `google_mlkit_barcode_scanning` tidak
  punya implementasi web. Seluruh fitur pindai lembar kerja ikut mati.

Jadi web bukan jalan pintas ke desktop; biner asli justru yang lebih dekat.
