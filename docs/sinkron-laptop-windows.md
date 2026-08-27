# Menyamakan laptop Windows dengan Mac — sisi aplikasi

**Kenapa berkas ini ada.** `git pull` sudah menyamakan kodenya. Yang bikin dua mesin
tetap berbeda adalah hal-hal yang git memang tidak bawa: SDK Flutter beserta
versinya, toolchain Android/desktop, berkas kredensial yang di-`.gitignore`, dan
hasil `flutter pub get`.

Ada satu lagi yang khas Flutter dan sering bikin bingung: **golden test memang
sengaja berperilaku berbeda di Windows.** Itu bukan tanda setupnya salah — dan ada
satu aturan yang kalau dilanggar justru merusak mesin sebelah. Lihat §5.

Sisi backend ada di berkas dengan nama yang sama di repo
[`sidik-calibration-api`](https://github.com/ZainulArkaanAlinsi/sidik-calibration-api).

---

## 1. Yang git bawa vs yang tidak

| Yang dibawa git (otomatis sama) | Yang TIDAK dibawa git |
|---|---|
| Seluruh `lib/`, `test/`, `integration_test/`, `tool/` | SDK Flutter — versinya harus disamakan manual |
| `pubspec.lock` — versi paket dikunci, jadi `pub get` menghasilkan isi yang sama | `.dart_tool/`, `build/` — hasil build |
| 18 golden di `test/screenshots/` | `android/app/google-services.json` — kredensial Firebase |
| Seluruh `docs/`, termasuk `docs/kontrak-api.md` | Vault Obsidian `Project-PT-Sidik/` |
| Konfigurasi Android/iOS/macOS/Windows/Web | `SIDIK-FM-*.pdf`, `SIDIK-IK-*.pdf` — lembar kerja resmi lab |

---

## 2. Versi Flutter — ini yang paling penting

```
Flutter 3.44.6
```

Angka itu bukan saran. Kelima workflow CI (`periksa-pr`, `golden-baru`,
`apk-rilis-cloud`, `build-tes-mock`, `rilis-desktop`) semuanya menyematkan
`FLUTTER_VERSION: 3.44.6`, dengan alasan yang ditulis di `periksa-pr.yml` sendiri:
Flutter beda minor sering mengubah perilaku analyzer, dan mesin yang versinya beda
menghasilkan "hijau di CI, merah di laptop" — kebalikan dari gunanya CI.

> `README.md` masih menyebut Flutter 3.41 di bagian Tech Stack. Yang mengikat adalah
> angka di workflow, karena itu yang benar-benar dijalankan.

Pasang di Windows:

```powershell
winget install Git.Git
winget install Google.AndroidStudio
```

Flutter SDK-nya sendiri diunduh manual supaya versinya bisa dipatok:

1. Ambil `flutter_windows_3.44.6-stable.zip` dari docs.flutter.dev/release/archive
2. Ekstrak ke `C:\src\flutter` — **jangan** ke `C:\Program Files` (butuh hak admin,
   dan `flutter upgrade` jadi gagal)
3. Tambahkan `C:\src\flutter\bin` ke PATH

Untuk bisa `flutter run -d windows` (desktop), pasang juga **Visual Studio 2022
Community** dengan workload *"Desktop development with C++"*. Tanpa itu Flutter
hanya menawarkan Android dan Chrome.

Verifikasi:

```bash
flutter --version    # harus 3.44.6
flutter doctor       # tidak boleh ada silang merah
```

Di Android Studio, buka **SDK Manager** dan pastikan terpasang: Android SDK
Platform-Tools (dapat `adb`), Android SDK Command-line Tools, dan minimal satu
Platform. Lalu sekali saja:

```bash
flutter doctor --android-licenses
```

---

## 3. Clone dan jalankan

Semua perintah di **Git Bash**, bukan CMD — skrip di `tool/` semuanya `.sh`.

```bash
git clone https://github.com/ZainulArkaanAlinsi/sidik-calibration-mobile.git
cd sidik-calibration-mobile

flutter pub get
flutter analyze          # wajib bersih
flutter test
```

Menjalankan aplikasinya:

```bash
./tool/dev.sh mock       # tanpa server sama sekali — paling cepat buat cek layar
./tool/dev.sh windows    # desktop Windows, nembak backend di 127.0.0.1:8000
./tool/dev.sh hp         # HP fisik lewat relay adb, tanpa IP sama sekali
```

`./tool/dev.sh mac` tetap ada dan tetap untuk Mac. Mode `windows` adalah
pasangannya — perilakunya sama persis, cuma `-d windows` alih-alih `-d macos`.

Untuk mode `windows` dan `hp`, backend harus sudah hidup dulu di repo sebelah:

```bash
php artisan serve
```

Skrip akan menolak jalan kalau backendnya belum menjawab, lengkap dengan
perintah yang harus dijalankan — jadi tidak perlu menghafal urutannya.

---

## 4. `google-services.json` — opsional, bukan syarat

Berkas ini di-`.gitignore` karena repo ini publik dan isinya API key Android
proyek Firebase `sidik-kalibrasi`.

**Tanpa berkas ini aplikasinya tetap dibangun dan tetap jalan penuh.** Yang mati
cuma notifikasi push. `android/app/build.gradle.kts` memasang plugin Google
Services hanya kalau berkasnya ada, dan `_nyalakanFirebase()` di `main.dart`
sengaja menelan kegagalannya.

> Komentar di `.gitignore` masih menulis bahwa tanpa berkas ini `flutter build apk`
> gagal di mesin mana pun. Itu memang benar dulu, dan sudah tidak berlaku sejak
> pemasangan pluginnya dibuat bersyarat.

Kalau memang mau push hidup di laptop ini, dua jalan — pilih salah satu:

- salin `android/app/google-services.json` dari Mac ke posisi yang sama, atau
- unduh ulang dari Firebase Console, proyek `sidik-kalibrasi`, aplikasi Android
  dengan package `com.ptsidik.kalibrasi`.

Tidak perlu mengubah apa pun setelah berkasnya ditaruh.

---

## 5. ⚠️ Golden test di Windows — satu aturan yang tidak boleh dilanggar

**Jangan pernah menjalankan `flutter test --update-goldens` di Windows.**

Alasannya ada di `test/flutter_test_config.dart`: 18 golden di `test/screenshots/`
dibuat di macOS. macOS (CoreText) dan Windows (DirectWrite) merasterisasi font
dengan hinting dan anti-aliasing yang berbeda, jadi layar yang identik tetap
menghasilkan piksel yang berbeda — terukur **2,5%–4,3%**.

Repo ini sudah menanganinya: di luar macOS ambang toleransinya dilonggarkan ke 15%,
jadi `flutter test` di Windows **lolos**, dan yang masih dijaga cuma kerusakan parah
(layar blank, salah layar, font gagal dimuat). Regresi layout yang halus bukan
tanggung jawab Windows — itu celah yang disengaja.

Kalau `--update-goldens` dijalankan di sini, PNG-nya ditimpa dengan rasterisasi
Windows. Hasilnya bukan "golden jadi benar", tapi merahnya pindah ke macOS dan ke
CI. Satu perintah, dua mesin rusak.

Kalau memang perlu golden baru atau golden diperbarui tanpa memegang Mac, sudah ada
jalannya: push ke branch selain `main` yang menyentuh `test/screenshot_test.dart`,
lalu workflow **`golden-baru.yml`** membuatkannya di runner macOS dan mengunggah
PNG-nya sebagai artifact.

---

## 6. Membuktikan sudah sama — satu perintah

```bash
./tool/cek-sinkron.sh
```

Yang diperiksa: working tree bersih, `HEAD` sama dengan `origin/main`, tidak ada
commit yang belum di-push, versi Flutter tepat 3.44.6, `.dart_tool/` terpasang,
18 golden lengkap, dan status berkas opsional.

Jalankan skrip yang **sama** di Mac. Kalau dua-duanya melaporkan hash commit yang
sama dan nol masalah, dua mesin itu identik.

---

## 7. Rutinitas harian supaya tetap sama

1. **Mulai kerja:** `git pull origin main`
2. **Setelah pull yang menyentuh `pubspec.yaml`:** `flutter pub get`
3. **Sebelum commit:** `flutter analyze` harus bersih, `flutter test` harus hijau
4. **Selesai kerja:** commit dan push — perubahan yang menginap di satu mesin
   adalah satu-satunya cara dua mesin bisa melenceng tanpa disadari

---

## 8. Bahan rujukan yang harus disalin manual

Tidak diperlukan supaya aplikasinya jalan. Tapi **diperlukan untuk mengerjakan
permintaan 6** (lihat `docs/permintaan-user-7.md` di repo backend), karena tampilan
lembar kerja harus mengikuti tiga PDF resmi itu.

Salin lewat flashdisk / Google Drive — bukan lewat git, karena ini dokumen mutu
lab terakreditasi dan repo ini publik:

| Dari Mac | Isinya |
|---|---|
| `SIDIK-FM-CAL-0505 Rev.3.pdf` | Lembar kerja TITS |
| `SIDIK-FM-CAL-0504 Rev.3.pdf` | Lembar kerja Enclosure |
| `SIDIK-FM-CAL-0506 Rev.4.pdf` | Lembar kerja TIDS |
| `SIDIK-FM-*.pdf` / `SIDIK-IK-*.pdf` lainnya | Formulir & instruksi kerja lab |
| `Project-PT-Sidik/` | Vault Obsidian — rencana harian, referensi teknis |

Taruh di root repo, posisi yang sama seperti di Mac. Semuanya sudah masuk
`.gitignore`, jadi tidak akan ikut ter-commit tanpa sengaja.
