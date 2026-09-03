# Deploy lewat Firebase — Android, macOS, Windows

## Halaman unduhnya di sini

**https://sidik-kalibrasi.web.app**

Alamat kedua yang sama isinya: `https://sidik-kalibrasi.firebaseapp.com`.
Firebase memberi dua domain untuk satu situs; dua-duanya sah, yang `.web.app`
yang dipakai sehari-hari.

Alamatnya ditulis di sini **apa adanya**, bukan sebagai `<project>.web.app`.
Sebelum ini seluruh dokumen cuma memuat pola itu, jadi satu-satunya cara tahu
alamat aslinya adalah membuka `.firebaserc` dan menyusunnya sendiri — dan orang
yang cuma mau mengunduh aplikasinya tidak punya alasan membuka berkas itu.

Kalau alamatnya berubah, yang menentukan tetap `.firebaserc`
(`projects.default`) — perbarui baris di atas supaya keduanya tidak pernah
bercerita beda.

---

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
| Grup tester `teknisi` | ⚠️ dibuat, **belum ada anggotanya** — APK terkirim ke grup kosong sampai email tester didaftarkan |
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
2. `google-services.json` perlu diunduh **kalau mau notifikasi push**, dan
   cuma itu.

   Kalimat ini dulu berbunyi "tidak perlu diunduh — app ini belum memakai SDK
   Firebase apa pun". Itu benar sampai `firebase_core` &
   `firebase_messaging` masuk; sesudahnya jadi menyesatkan.

   Berkasnya masuk `.gitignore` (repo ini publik), jadi checkout yang bersih
   nggak punya dia. Ambil dari Firebase Console → project `sidik-kalibrasi` →
   Project settings → app `com.ptsidik.kalibrasi` → **Download
   google-services.json**, lalu taruh di `android/app/google-services.json`.

   **Buat build CI, berkasnya dipasang sekali sebagai Secret** — runner
   checkout bersih, jadi dia nggak akan pernah punya berkas ini sendiri:

   ```bash
   gh secret set GOOGLE_SERVICES_JSON < android/app/google-services.json
   ```

   Workflow "APK rilis (nyambung server)" nulis berkasnya sebelum build kalau
   secret itu ada, dan ngeluarin peringatan (bukan gagal) kalau nggak ada.

   > Jangan ketuker sama `FIREBASE_SERVICE_ACCOUNT`. Dua-duanya Firebase, tapi
   > perannya kebalikan: `GOOGLE_SERVICES_JSON` **ikut masuk ke dalam APK** dan
   > yang bikin aplikasinya bisa **menerima** push; `FIREBASE_SERVICE_ACCOUNT`
   > dipakai runner buat **mengirim** rilis ke App Distribution dan **tidak**
   > ikut ke dalam APK. Isi `google-services.json` (app id, project number, api
   > key Android) toh terbawa di setiap APK, jadi bukan rahasia dalam arti
   > sebenarnya — dia Secret cuma karena repo ini publik. Yang satunya rahasia
   > beneran.

   **Tanpa berkas itu build tetap jalan.** `android/app/build.gradle.kts`
   memasang plugin Google Services cuma kalau berkasnya ada, dan
   `_nyalakanFirebase()` di `main.dart` sengaja menelan kegagalan — jadi yang
   hilang cuma notifikasi push, bukan aplikasinya. Kalau plugin itu dipasang
   tanpa syarat, `assembleDebug` gagal total dengan
   `File google-services.json is missing` dan nggak ada yang bisa menjalankan
   aplikasinya sama sekali.

   Tapi perhatikan bentuk kegagalannya: **diam total.** Firebase gagal nyala,
   kegagalannya ditelan, FCM nggak pernah ngasih token, dan nggak ada yang bisa
   didaftarkan — satu-satunya jejaknya `debugPrint` yang nggak kelihatan di APK
   release. Dan yang hilang cuma kabar waktu aplikasi **ketutup total**: selama
   aplikasinya kebuka, websocket Reverb tetap ngabarin. Itu sebabnya gejalanya
   kebaca sebagai "notifikasinya kadang jalan", bukan sebagai satu berkas yang
   nggak ikut ke build.
3. Bangun APK-nya. Cara termudah: jalankan workflow **"APK rilis (nyambung
   server)"** dari tab Actions, lalu unduh artifact-nya. Atau lokal:

   ```bash
   flutter build apk --release \
     --dart-define=APP_ENV=prod \
     --dart-define=API_BASE_URL="https://<nama>.onrender.com/api"
   ```

4. Kirim ke tester — **sekarang otomatis**. Workflow "APK rilis (nyambung
   server)" ngirim sendiri ke grup `teknisi` begitu APK-nya jadi, dengan
   catatan rilis = pesan commit-nya.

   Syaratnya satu, dipasang sekali: service account Firebase sebagai
   **Secret** (bukan Variable — kunci ini nggak ikut ketanam ke APK, beda
   sama `API_BASE_URL`). Firebase Console → Project settings → Service
   accounts → **Generate new private key**, lalu:

   ```bash
   gh secret set FIREBASE_SERVICE_ACCOUNT < kunci-yang-diunduh.json
   ```

   Selama secret itu belum ada, workflow-nya **nggak gagal** — APK-nya tetap
   kebangun dan tetap jadi artifact, cuma langkah kirimnya dilewat dengan
   catatan di ringkasan run. Yang belum dipasang itu keadaan yang sah, bukan
   kesalahan.

   Kalau mau kirim manual (mis. APK hasil build lokal):

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

> **Kunci penanda tangan wajib dipasang dulu — lihat
> [`rilis-tanda-tangan-apk.md`](rilis-tanda-tangan-apk.md).** Workflow "APK
> rilis (nyambung server)" sekarang gagal di detik pertama sampai keempat
> secretnya ada.
>
> Catatan lama di tempat ini menulis bahwa APK-nya "tidak akan bisa di-update
> oleh siapa pun yang tidak punya debug key laptop ini". Itu keliru, dan
> kelirunya ke arah yang meremehkan: debug key laptop tidak pernah terlibat
> sama sekali. Runner CI mulai dari VM bersih tiap run dan membuat
> `debug.keystore` BARU di situ — alias & passwordnya tetap, tapi key
> material-nya acak. Jadi bukan cuma orang lain yang tidak bisa memperbarui;
> **dua rilis CI beruntun pun tidak bisa saling menimpa.**

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

**Sekarang otomatis.** Tiap push ke `main`, workflow "Rilis desktop (nyambung
server)" membangun Windows & macOS, menaruh kedua zip-nya di `public/`, lalu
mendorong situsnya sendiri. Nggak ada langkah tangan sama sekali.

Yang dibutuhkan cuma secret `FIREBASE_SERVICE_ACCOUNT` — secret yang **sama**
dengan yang dipakai jalur APK buat App Distribution, jadi kalau yang itu sudah
jalan, yang ini nggak perlu apa-apa lagi.

Hasilnya **https://sidik-kalibrasi.web.app** — berisi tiga tombol: Android
(link App Distribution), macOS, Windows.

Deploy tangan masih bisa dipakai kalau perlu — mis. mau nguji ubahan
`index.html` tanpa nunggu build desktop selesai:

```bash
firebase deploy --only hosting
```

Tapi hati-hati: itu menerbitkan `public/` **apa adanya**. Kalau zip-nya nggak
ada di folder itu (dan memang nggak ada, karena nggak di-commit), dua tombol
desktopnya jadi 404 sampai push berikutnya membangunnya ulang.

### Kenapa Android nggak ikut ke Hosting

APK-nya jalan lewat App Distribution di `apk-rilis-cloud.yml` — dikirim ke grup
`teknisi`, dan build baru masuk sendiri ke HP yang sudah pasang App Tester.
Nyalin APK ke situs ini cuma bikin dua sumber kebenaran, dan yang satu pasti
ketinggalan.

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

Nomor versi **untuk build CI sudah otomatis, dan sama di ketiga platform**.
Kedua workflow rilis — "APK rilis (nyambung server)" dan "Rilis desktop & web
(nyambung server)" — menyusun nomornya dari sumber yang sama: jumlah commit
(`git rev-list --count HEAD`), angka yang naik sendiri setiap ada yang mendarat
di `main`. Nomornya ikut ditulis di catatan rilis App Distribution
("build 521 · …") supaya bisa diadu waktu teknisi lapor.

Sumbernya jumlah commit, bukan `github.run_number`, karena angka itu
**per-workflow**: dua jalur rilis menghitung sendiri-sendiri, jadi commit yang
sama pernah terbit sebagai `1.0.84` di HP sementara paket Windows dari commit
itu juga tetap bernama `1.0.0`. Jumlah commit sama di mana pun dia dihitung,
jadi APK, Windows, dan macOS dari satu commit selalu bernomor sama — tanpa
kedua workflow perlu saling menunggu.

Konsekuensinya satu, dan sudah dibayar sekali waktu penggantian ini mendarat:
penomorannya melompat dari `1.0.84` ke `1.0.521`. Lompatan itu **naik**, jadi
aman untuk `versionCode` maupun untuk pemberitahuan "ada versi baru" —
perbandingannya numerik per segmen (`bandingkanVersi` di
`lib/models/versi_aplikasi.dart`), bukan teks.

Kedua workflow memasang `fetch-depth: 0` di langkah checkout. Itu **wajib**:
checkout bawaan hanya menarik satu commit, hitungannya jadi 1, dan angka 1
lolos seluruh build tanpa keluhan — yang merah baru HP teknisi. Masing-masing
workflow menjaga dirinya dengan menolak hitungan di bawah 100.

Ini bukan kosmetik. Android menolak memasang APK dengan `versionCode` yang
tidak lebih besar dari yang sudah terpasang, dan gagalnya cuma muncul sebagai
"App not installed" tanpa sebab. App Tester juga mengelompokkan rilis per
versi, jadi build baru bernomor sama nangkring di bawah judul yang sama seperti
yang lama — teknisi melihat "sudah terpasang" lalu tetap memegang versi kemarin.

`version:` di `pubspec.yaml` sengaja dibiarkan di `+2`. Itu membuat build lokal
selalu berangka lebih kecil daripada build CI, jadi APK hasil coba-coba di
laptop tidak bisa menimpa rilis yang dipegang teknisi — kebalikannya yang
berbahaya, dan diam-diam. Kalau memang perlu membagikan build lokal, oper
`--build-number` sendiri dengan angka di atas hitungan commit terakhir
(`git rev-list --count HEAD`).

## Kenapa bukan Flutter Web

Sempat masuk akal: satu build, jalan di Windows, macOS, dan HP lewat browser.
Tapi jalurnya tertutup di kode yang sekarang, bukan cuma butuh waktu lebih:

- Folder `web/` belum ada sama sekali.
- `lib/providers/sumber_foto_provider.dart:24` memakai `Platform` dari
  `dart:io`, yang tidak ada di web — gagal saat kompilasi, bukan saat jalan.
- `google_mlkit_text_recognition` dan `google_mlkit_barcode_scanning` tidak
  punya implementasi web. Seluruh fitur pindai lembar kerja ikut mati.

Jadi web bukan jalan pintas ke desktop; biner asli justru yang lebih dekat.
