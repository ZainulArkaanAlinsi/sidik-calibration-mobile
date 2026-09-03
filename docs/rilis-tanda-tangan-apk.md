# Kunci penanda tangan APK rilis

Status: **belum dipasang** — workflow "APK rilis (nyambung server)" gagal di
detik pertama sampai keempat secret **dan** satu variable di bawah ada. Itu
disengaja; alasannya di bagian terakhir.

Lima hal yang harus dipasang, dan lima-limanya wajib:

| Nama | Jenis | Menjawab |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Secret | keystore-nya sendiri |
| `ANDROID_KEYSTORE_PASSWORD` | Secret | password keystore |
| `ANDROID_KEY_ALIAS` | Secret | alias kunci di dalamnya |
| `ANDROID_KEY_PASSWORD` | Secret | password kunci |
| `APK_SHA256` | **Variable** | kunci yang mana — lihat "Patok sidik jarinya" |

## Kenapa aplikasi ini butuh kunci yang tetap

Aplikasi ini **tidak diedarkan lewat Play Store**. Dia mengunduh penggantinya
sendiri lalu memanggil pemasang Android — `AndroidManifest.xml` mendeklarasikan
`REQUEST_INSTALL_PACKAGES` untuk itu, dan `lib/services/pengunduh_apk.dart` +
`penyiap_update.dart` yang mengerjakannya.

Android hanya mengizinkan pemasangan di atas aplikasi yang sudah ada kalau
**sertifikat penanda tangannya sama persis**. Beda sedikit pun ditolak, dan
pesannya cuma "App not installed" tanpa menyebut sebab.

Sampai sebelum ini, blok `release` di `android/app/build.gradle.kts` masih
memakai TODO bawaan Flutter:

```kotlin
// TODO: Add your own signing config for the release build.
signingConfig = signingConfigs.getByName("debug")
```

Runner CI mulai dari VM bersih tiap run, dan Android Gradle Plugin membuat
`debug.keystore` **baru** di situ. Alias dan passwordnya memang selalu sama
(`androiddebugkey` / `android`), tapi **key material-nya acak tiap kali
dibuat** — jadi tiap rilis bersertifikat berbeda dari rilis sebelumnya.

Akibatnya berantai:

1. Teknisi menekan "Update" di aplikasi.
2. APK baru terunduh (itu jalan normal).
3. Pemasang Android menolaknya: konflik signature.
4. Buat teknisi itu tampak seperti aplikasinya rusak.
5. Satu-satunya jalan keluar: uninstall manual — yang **menghapus token login
   di secure storage dan foto profil lokalnya**, karena dua-duanya milik
   aplikasi yang dihapus.

Seluruh nilai fitur update-sendiri batal, dan yang tersisa cuma melatih teknisi
bahwa tombol itu tidak bisa dipercaya.

## Ongkos sekali di awal — baca ini sebelum rilis pertama

Perbaikan ini **tidak bisa menyelamatkan pemasangan yang sudah ada**. APK yang
sekarang terpasang di HP teknisi ditandatangani kunci debug acak; rilis pertama
yang memakai kunci produksi bersertifikat berbeda dari itu juga, jadi Android
tetap menolaknya.

Jadi rilis pertama sesudah perubahan ini **wajib disertai instruksi uninstall
manual**, sekali, untuk semua teknisi. Kabari mereka bahwa token login dan foto
profilnya ikut terhapus dan perlu dipasang ulang.

Sesudah itu selesai selamanya: rilis kedua dan seterusnya memakai kunci yang
sama, dan "Update" bekerja seperti seharusnya.

Ini bukan alasan menunda. Menunda berarti setiap rilis berikutnya menambah satu
uninstall lagi, bukan mengurangi.

## Bikin keystore-nya

Sekali seumur aplikasi. Jalankan di komputer yang kamu pegang sendiri, **bukan
di CI**:

```bash
keytool -genkeypair -v \
  -keystore sidik-rilis.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias sidik-rilis
```

Yang ditanyakan:

| Isian | Saran |
|---|---|
| Keystore password | Panjang & acak. Simpan di password manager. |
| Key password | Boleh sama dengan keystore password. |
| First and last name (CN) | `PT Sidik Kalibrasi` |
| Organizational unit | `Rilis` |
| Country code | `ID` |

`-validity 10000` ≈ 27 tahun. Bukan berlebihan: sertifikat yang kedaluwarsa
menghadirkan persis masalah yang dokumen ini tutup, bertahun-tahun kemudian,
waktu tidak ada lagi yang ingat sebabnya.

## Simpan cadangannya SEBELUM lanjut

**Keystore yang hilang tidak bisa dibuat ulang.** Tidak ada pemulihan, tidak
ada dukungan yang bisa dimintai — kunci itu satu-satunya benda di dunia yang
bisa menerbitkan pembaruan untuk aplikasi yang sudah terpasang. Hilang berarti
setiap teknisi harus uninstall manual lagi, dan semuanya kehilangan token serta
foto profilnya lagi.

Taruh salinannya di minimal dua tempat di luar repo, misalnya password manager
dan drive terenkripsi. `.gitignore` sudah memblokir `*.jks`, `*.keystore`, dan
`android/key.properties` supaya tidak ada yang ter-commit tidak sengaja — repo
ini publik.

## Pasang keempat secretnya

```bash
base64 -w0 sidik-rilis.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS       # sidik-rilis
gh secret set ANDROID_KEY_PASSWORD
```

Di macOS `base64 -w0` tidak ada; pakai `base64 -i sidik-rilis.jks` saja
(bawaannya sudah satu baris).

Keempatnya **Secret**, bukan Variable — beda dari `API_BASE_URL`. Alasannya
sama dengan `FIREBASE_SERVICE_ACCOUNT`: nilainya tidak ikut tertanam ke dalam
APK, dan bocornya berarti orang lain bisa membangun APK yang Android terima
sebagai pembaruan sah aplikasi ini.

## Patok sidik jarinya — langkah kelima, dan bukan opsional

Empat secret di atas menjawab *"ada kunci"*. Yang belum dijawab: **kunci yang
MANA.**

Secret keystore bisa tergantikan tanpa ada yang menyadarinya — keystore hilang
lalu dibuat lagi, satu orang memasang punyanya sendiri, `gh secret set` salah
repo. Semua kunci itu sah: bukan debug, lolos `apksigner`, APK-nya terbit
dengan tenang. Yang gagal baru teknisi di lapangan, dan gagalnya permanen.

Ambil sidik jarinya dari keystore yang tadi dibuat:

```bash
keytool -list -v -keystore sidik-rilis.jks -alias sidik-rilis | grep 'SHA256:'
# SHA256: 3F:2A:...:0C
```

Lalu patok sebagai **repository variable** (bukan secret):

```bash
gh variable set APK_SHA256    # tempel nilai SHA256 di atas
```

**Variable, bukan Secret.** Sidik jari sertifikat tercetak di tiap APK yang
sudah terpasang di HP mana pun — menyembunyikannya tidak menambah keamanan apa
pun, dan menyensornya jadi `***` di log justru bikin tidak kebaca waktu mencari
sebab kegagalan. Alasan yang sama dengan `API_BASE_URL`.

Titik dua dan huruf besarnya boleh ikut. Workflow menormalkan kedua bentuk
sebelum membandingkan, karena `keytool` menulisnya `3F:2A:…` sementara
`apksigner` menulisnya `3f2a…` — dan penjagaan yang menolak nilai yang benar
adalah penjagaan yang akan dimatikan orang berikutnya.

### Kalau kuncinya memang diganti

Ganti `APK_SHA256` **dalam commit/aksi yang sama** dengan penggantian keystore-
nya. Kalau CI menggagalkan rilis karena sidik jarinya beda, jawab dulu yang
mana dari dua ini sebelum menyentuh variable-nya:

- **Keystore-nya tergantikan tanpa disengaja** → jangan perbarui variable-nya.
  Kembalikan keystore aslinya dari cadangan; rilis ini memang tidak boleh
  terbit.
- **Kuncinya sengaja diganti** → perbarui variable-nya, dan sadari ongkosnya:
  seluruh teknisi harus uninstall-pasang manual sekali, sama seperti "Ongkos
  sekali di awal" di atas.

Yang tidak boleh: memperbarui `APK_SHA256` supaya CI-nya hijau, tanpa tahu
kenapa dia berubah. Itu mematikan penjagaannya sambil kelihatan seperti
memperbaikinya.

## Build lokal

`android/key.properties` tidak ada di checkout bersih, dan itu **sengaja**:
`flutter run --release` serta `flutter build apk --release` di laptop jatuh ke
kunci debug dan tetap jalan. Persis yang dilindungi TODO bawaan Flutter.

Konsekuensinya: **APK hasil build lokal tidak bisa dipasang di atas rilis CI**,
dan sebaliknya. Itu bukan bug — itu yang mencegah APK coba-coba menimpa
aplikasi yang dipakai teknisi.

Kalau memang perlu membangun APK bertanda tangan produksi di laptop, bikin
`android/key.properties`:

```properties
storeFile=/jalur/mutlak/ke/sidik-rilis.jks
storePassword=...
keyAlias=sidik-rilis
keyPassword=...
```

Jalur relatif diselesaikan terhadap `android/`, bukan `android/app/`.

## Paket mock tidak ikut ditandatangani

`build-tes-mock.yml` juga menjalankan `flutter build apk --release`, dan dia
**tidak** dipasangi kunci produksi. Itu keputusan, bukan kelalaian: paket mock
berisi data palsu, dan kalau dia bertanda tangan produksi, Android akan dengan
senang hati memasangnya menimpa aplikasi asli di HP teknisi.

## Kenapa workflow rilisnya GAGAL kalau kuncinya belum ada

Dua langkah Firebase di workflow yang sama dilewat dengan catatan kalau
secretnya belum dipasang, karena absennya adalah keadaan yang sah — APK-nya
jalan penuh, cuma push notification yang mati.

Kunci penanda tangan berbeda, dan bedanya menentukan: APK tanpa kunci produksi
**kelihatan baik-baik saja**. Dia terbit, terpasang, dipakai — dan baru gagal
berminggu-minggu kemudian, di tangan teknisi, waktu dia menekan "Update".
Kegagalan yang tidak meninggalkan satu pun error di CI.

Jadi penjagaannya ikut pola `API_BASE_URL`: gagal di detik pertama, dengan
sebab yang kebaca. Lebih baik tidak ada rilis sama sekali daripada rilis yang
mengajari teknisi bahwa tombol "Update" itu rusak.

## Verifikasi otomatis tiap rilis

Punya secretnya tidak sama dengan secret itu benar-benar dipakai. `key.properties`
yang salah jalur, satu properti yang kosong, atau blok signing yang tidak
tersambung ke `buildTypes` — ketiganya menghasilkan APK yang tetap terbit dan
tetap terpasang.

Karena itu ada langkah **"Pastiin APK-nya ditandatangani kunci rilis yang
benar"** sesudah build. Dia menjalankan `apksigner verify --print-certs`, lalu
menggagalkan run kalau salah satu dari dua ini kena:

| Yang diperiksa | Yang ketangkep |
|---|---|
| Penanda tangannya bukan `CN=Android Debug` | rantai `key.properties` → `signingConfigs` → `buildTypes` yang putus |
| Sidik jarinya sama persis dengan `APK_SHA256` | kunci rilis LAIN yang sah — lolos pemeriksaan pertama tanpa gejala |

Baris kedua yang menutup lubangnya. Menolak kunci debug cuma menutup satu kunci
salah; keystore pengganti yang sah lolos begitu saja, dan semua tandanya
kelihatan benar sampai teknisi menekan "Update".

Perbandingannya **dikerjakan CI, bukan mata**. Sebelumnya angkanya cuma dicetak
ke ringkasan run dengan catatan "harus sama dengan rilis sebelumnya" — dan
penjagaan yang bergantung pada ada yang ingat membacanya adalah penjagaan yang
sudah gagal, cuma belum ketahuan kapan.

Rilis yang sidik jarinya tidak cocok berhenti **sebelum** langkah penerbitan:
GitHub Release dan Firebase App Distribution dua-duanya di bawah langkah ini,
jadi APK yang salah kunci tidak pernah sampai ke tangan siapa pun.

Memeriksa manual dua APK yang sudah terbit tetap bisa, dan rumusnya sama:

```bash
apksigner verify --print-certs sidik-kalibrasi-1.0.41.apk | grep SHA-256
apksigner verify --print-certs sidik-kalibrasi-1.0.42.apk | grep SHA-256
```

Sama = update-sendiri jalan. Beda = tidak.

## Rujukan

- Temuan aslinya: BUG-017 di `sidik-calibration-api/docs/audit-bug-2026-09-02.md`
- Firebase & halaman unduh: [`deploy-firebase.md`](deploy-firebase.md)
