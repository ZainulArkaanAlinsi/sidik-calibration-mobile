# Kunci penanda tangan APK rilis

Status: **belum dipasang** — workflow "APK rilis (nyambung server)" gagal di
detik pertama sampai keempat secret di bawah ada. Itu disengaja; alasannya di
bagian terakhir.

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

Karena itu ada langkah **"Pastiin APK-nya bukan ditandatangani kunci debug"**
sesudah build. Dia menjalankan `apksigner verify --print-certs`, menggagalkan
run kalau penanda tangannya `CN=Android Debug`, dan menulis sidik jari SHA-256
ke ringkasan run.

Angka itu yang dibandingkan antar rilis:

```bash
apksigner verify --print-certs sidik-kalibrasi-1.0.41.apk | grep SHA-256
apksigner verify --print-certs sidik-kalibrasi-1.0.42.apk | grep SHA-256
```

Sama = update-sendiri jalan. Beda = tidak. Sekarang tercatat sendiri tiap rilis,
jadi tidak ada yang perlu ingat memeriksanya.

## Rujukan

- Temuan aslinya: BUG-017 di `sidik-calibration-api/docs/audit-bug-2026-09-02.md`
- Firebase & halaman unduh: [`deploy-firebase.md`](deploy-firebase.md)
