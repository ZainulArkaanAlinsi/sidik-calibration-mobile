---
name: sidik-fe-scope-akun
description: Jaga data per-akun/per-lab di sidik-calibration-mobile tidak bertahan melewati pergantian akun — aturan ref.watch(authProvider), peta provider yang sudah aman vs yang menggantung ke auto-dispose, dan test ganti akun yang wajib menyertai. Pakai saat bikin atau mengubah provider yang mengambil data dari server, menambah cache lokal, atau menyentuh jalur logout.
---

# Sidik FE Scope Akun (Data Tidak Ikut Pindah Akun)

Rekan mobile dari `sidik-query-organisasi` di `sidik-calibration-api`. Di
backend, batas antar-lab dijaga saringan `organization_id` di tiap query. Di
sini batas yang sama dijaga di satu tempat lain: **apa yang masih tersisa di
memori waktu orang berikutnya login di HP yang sama.**

Satu APK dipakai teknisi dan admin, dan HP lab dipakai gantian. Jadi
"pergantian akun" itu kejadian normal harian, bukan kasus tepi.

## Aturan inti

**Provider yang menyajikan data milik satu akun atau satu lab WAJIB
`ref.watch(authProvider)`.**

Bukan `ref.read`. Bedanya menentukan:

```dart
// SALAH — token-nya benar, tapi nol pemicu rebuild.
final token = await ref.read(tokenStorageProvider).read();

// BENAR — provider ikut lahir ulang tiap keadaan auth bergerak.
ref.watch(authProvider);
final token = await ref.read(tokenStorageProvider).read();
```

`ref.read(tokenStorageProvider)` mengambil token yang berlaku **saat build
dijalankan**, jadi datanya tidak pernah salah akun waktu diambil. Yang hilang
bukan kebenaran datanya — yang hilang **alasan untuk mengambil ulang.** Tanpa
dependensi ke `authProvider`, provider yang sudah punya nilai tidak punya sebab
apa pun untuk membuangnya waktu akunnya ganti.

`lembar_kerja_provider.dart` sudah menuliskan alasannya di tempat: di-`watch`
ke `authProvider` supaya ganti akun (teknisi → admin) mengambil ulang.

## Jaring pengaman yang ada, dan batasnya

Repo ini pakai **flutter_riverpod ^3.3.2**, dan di Riverpod 3 **auto-dispose
adalah default**. Provider yang tidak lagi didengarkan siapa pun dibuang, jadi
begitu pohon widget pindah ke layar login, sebagian besar provider data ikut
mati dan lahir ulang bersih waktu login berikutnya.

Sudah dicek: **tidak ada `keepAlive: true` dan tidak ada `ref.keepAlive()` di
`lib/`.** Jadi hari ini jaring itu utuh.

Tapi jaring ini **bergantung pada timing, bukan pada struktur.** Dia putus
diam-diam kalau salah satu dari ini terjadi:

- ada yang menambah `keepAlive: true` atau `ref.keepAlive()` pada provider data;
- ada widget yang tetap ter-mount melintasi logout dan masih `watch` provider
  itu (shell, scaffold bersama, `ref.listen` di akar);
- provider di-`watch` oleh provider lain yang sendirinya bertahan.

Tidak satu pun dari tiga itu menghasilkan error. Yang berubah cuma: data lab
sebelumnya bertahan satu layar lebih lama daripada seharusnya.

`ref.watch(authProvider)` tidak bergantung pada satu pun dari itu. Karena itu
dia yang jadi aturan, dan auto-dispose cuma dianggap bonus.

## Peta hari ini

**Aman secara struktural — sudah `ref.watch(authProvider)`:**

`dashboard_provider` · `history_provider` · `izin_provider` ·
`lembar_kerja_provider` · `notification_provider`

**Menggantung ke auto-dispose — belum menyentuh `authProvider` sama sekali:**

`arsip_provider` · `calibration_input_provider` · `certificate_provider` ·
`equipment_provider` · `folder_provider` · `kirim_email_provider` ·
`master_data_provider` · `perhitungan_provider` · `ruangan_provider` ·
`rumus_provider` · `tanda_tangan_provider` · `worksheet_scan_provider`

Daftar kedua **bukan daftar bug** — hari ini semuanya benar, karena jaring
auto-dispose masih utuh. Dia daftar tempat yang benarnya kebetulan, bukan
dijamin. Provider baru yang menyajikan data akun sebaiknya lahir langsung di
daftar pertama.

Dua yang memang tidak perlu: `onboarding_provider` dan `versi_provider` —
keduanya milik perangkat, bukan milik akun.

## Jalur logout

`AuthController.logout()` sekarang membuang satu hal saja:

```dart
ref.invalidate(selectedTabProvider);
```

Komentar tepat di atasnya sudah meminta yang berikutnya:

> Nanti pas ada data alat/kalibrasi yang di-cache, provider-nya juga WAJIB
> di-invalidate di sini — biar data user lama nggak kelihatan sama user baru.

Syarat itu **sudah terpenuhi** — `equipment_provider`, `history_provider`,
`calibration_input_provider` dan belasan lainnya sudah ada dan meng-cache data
server. Kalau menambah invalidasi di sana, tambahkan berikut alasannya, dan
jangan hapus komentar itu tanpa mengganti janjinya.

**Jalurnya dua, bukan satu.** `logoutAll()` membuang persis hal yang sama —
`ref.invalidate(selectedTabProvider)` dan tidak lebih. Apa pun yang ditambahkan
ke `logout()` harus ikut ditambahkan ke sana, kalau tidak "keluarkan sesi saya
di semua perangkat" justru meninggalkan lebih banyak sisa daripada logout
biasa.

## Kenapa ini tidak pernah ketahuan sendiri

Sama persis dengan sebabnya di backend: **yang mengetes cuma punya satu akun
yang aktif waktu itu.** Login, klik-klik, semuanya benar. Datanya memang punya
akun itu.

Yang tidak terlihat cuma muncul di urutan yang jarang dikerjakan sengaja:
login A → buka daftar alat → logout → login B → buka daftar alat. Kalau tidak
ada yang menjalankan urutan itu, tidak ada yang tahu.

Itu sebabnya testnya wajib, bukan disarankan.

## Sebelum bilang selesai

1. **Provider baru menyajikan data server?** Ada `ref.watch(authProvider)` di
   `build()`-nya atau tidak.
2. **Menambah `keepAlive`?** Kalau ya, provider itu tidak lagi dilindungi
   auto-dispose — `ref.watch(authProvider)` jadi wajib, bukan pilihan.
3. **Menyimpan ke disk** (SharedPreferences, file, Hive)? Yang tersimpan di
   disk tidak ikut auto-dispose sama sekali. Kuncinya harus memuat identitas
   akun, atau isinya dibuang di `logout()`.
4. **Menyentuh `logout()`?** Pastikan yang ditambahkan ikut alasannya.
5. **Test ganti akun**, lihat bagian berikutnya.

Token sendiri sudah aman — `SecureTokenStorage.clear()` dipanggil di
`logout()`, dan tokennya di Keystore, bukan SharedPreferences. Yang dijaga
berkas ini bukan tokennya, tapi **data yang terlanjur diambil pakai token
itu.**

## Test yang wajib menyertai

Bentuknya ikut `[[sidik-fe-test-generator]]` — `MockService` +
`ProviderScope` override, file flat di `test/`.

Yang diuji **urutan**, bukan satu keadaan:

1. Login akun A, baca provider-nya, pastikan isinya data A.
2. Jalankan `logout()`.
3. Login akun B, baca provider yang sama.
4. Pastikan yang keluar data B — dan bahwa `MockService`-nya **benar-benar
   dipanggil lagi**, bukan cuma kebetulan mirip.

Poin 4 yang paling gampang terlewat: assert isi saja bisa hijau walau
provider-nya tidak pernah lahir ulang, kalau data mock A dan B kebetulan
berbentuk sama. Hitung panggilannya.

## Rujukan

- Backend sejawat: `sidik-query-organisasi` di `sidik-calibration-api`
- Bikin provider/service baru: `[[sidik-fe-service-provider-scaffolder]]`
- Bentuk test: `[[sidik-fe-test-generator]]`
- Review sebelum commit: `[[sidik-fe-code-reviewer]]`
