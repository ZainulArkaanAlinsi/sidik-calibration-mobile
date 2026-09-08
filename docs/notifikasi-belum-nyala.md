# Notifikasi HP belum nyala — dan yang kurang bukan kodenya

8 September 2026 · frontend (mobile)

Permintaannya: "kalau ada yang di-reject atau di-approve, notifikasinya muncul
di HP seperti aplikasi lain, bukan cuma di dalam app."

**Seluruh jalur itu sudah dibangun di repo ini.** Yang belum ada dua hal, dan
dua-duanya di luar repo ini. Dokumen ini menyebut keduanya supaya nggak ada
yang menulis ulang kode yang sudah berdiri.

---

## Yang SUDAH ada di mobile

| Bagian | Berkas |
|---|---|
| Ambil token FCM perangkat | `lib/services/fcm_sumber_token_push.dart` |
| Daftarkan token ke backend waktu login, cabut waktu logout | `lib/services/pendaftaran_push.dart`, `lib/providers/pendaftaran_push_provider.dart` |
| Tampilkan notifikasi di bilah notifikasi HP | `lib/services/notifikasi_perangkat.dart` |
| Putuskan mana yang layak diumumkan | `PengabarNotifikasi` di `lib/providers/notifikasi_perangkat_provider.dart` |
| Buka layar tujuan waktu notifikasinya diketuk — termasuk waktu app MATI TOTAL | `lib/services/ketukan_push.dart` |
| Daftar notifikasi di dalam app | `lib/screens/notification/notification_screen.dart` |

Kategorinya juga sudah persis yang ditanyakan
(`lib/models/notification_item.dart`):

- `sesi_menunggu_approval` — buat admin
- `sesi_disetujui`
- `sesi_perlu_revisi` — ini yang muncul waktu ditolak
- `sertifikat_terbit`
- `jatuh_tempo`

Ada dua penjagaan di situ yang sebaiknya jangan dibongkar:

- Admin yang login pagi dengan 20 notifikasi belum dibaca **tidak** dihujani 20
  notifikasi sistem sekaligus. Yang sudah ada waktu menyambung dicatat
  diam-diam sebagai "sudah kelihatan".
- Izin notifikasi diminta waktu pertama menyambung, bukan waktu app pertama
  dibuka — orang yang ditanya sebelum tahu app-nya buat apa nolaknya sambil
  lalu.

---

## Kurang 1 — kunci Reverb belum dipasang (urusan kita sendiri)

Buktinya kelihatan di bilah atas panel desktop: **"Sinkron langsung mati"**.

```dart
// lib/core/config/app_config.dart
static bool get realtimeAktif => reverbAppKey.isNotEmpty && !useMock;
static const String reverbAppKey = String.fromEnvironment('REVERB_APP_KEY');
```

Selama `REVERB_APP_KEY` kosong, websocket-nya nggak pernah menyambung, jadi
`PengabarNotifikasi.umumkan` nggak pernah terpanggil — dan notifikasi sistem
nggak pernah muncul selagi app terbuka. Bukan kodenya yang kurang;
konfigurasinya yang kosong.

Yang perlu dipasang waktu build (dan di repository variable GitHub buat CI,
sejajar dengan `API_BASE_URL` yang sudah ada di situ):

```
--dart-define=REVERB_APP_KEY=<kunci dari server>
--dart-define=REVERB_HOST=<host reverb>
--dart-define=REVERB_PORT=<port>
--dart-define=REVERB_TLS=true
```

Server Reverb-nya sendiri harus jalan, dan endpoint otorisasi channel privat
harus bisa diakses — mobile memakai `$apiBaseUrl/broadcasting/auth`.

---

## Kurang 2 — backend perlu benar-benar MENGIRIM push (urusan backend)

Mobile mendaftarkan token perangkatnya; yang mengirim pesannya server.

Yang perlu dipastikan dari sisi backend:

1. **Token yang didaftarkan mobile beneran disimpan** dan dipakai waktu
   mengirim. Endpoint pendaftarannya sudah dipanggil mobile — tolong
   konfirmasi dia menyimpan ke tabel device token, bukan menerima lalu
   membuang.
2. **Kejadian approve & reject mengirim pesan FCM**, bukan cuma menulis baris
   notifikasi di database. Baris di database bikin lonceng di dalam app
   berangka; yang bikin HP berbunyi waktu app-nya ketutup itu FCM.
3. **Isi pesannya memuat `data` yang sama dengan baris notifikasinya** —
   minimal `kategori` dan `tautan: {tipe, id}`. Itu yang dipakai
   `ketukan_push.dart` buat mendarat di layar yang benar. Tanpa itu
   notifikasinya tetap muncul, tapi diketuk cuma membuka app di halaman depan
   — dan buat orang yang lagi menunggu hasil approval, itu setengah janji.
4. **Siapa yang dikirimi apa.** Usul kami, tapi ini keputusan kalian:
   - `sesi_menunggu_approval` → admin
   - `sesi_disetujui` & `sesi_perlu_revisi` → teknisi pemilik sesinya
   - `sertifikat_terbit` → teknisi pemilik + admin
   - `jatuh_tempo` → admin

---

## Cara memastikan sudah jalan

Sesudah dua hal di atas beres:

1. Buka app di HP, login sebagai teknisi, lalu **tutup app-nya**.
2. Dari akun admin, tolak satu sesi milik teknisi itu.
3. Yang harus terjadi: notifikasi muncul di bilah notifikasi HP walau app-nya
   tertutup, dan diketuk mendarat langsung di sesi yang ditolak — bukan di
   halaman depan.

Kalau notifikasinya muncul cuma waktu app terbuka, yang kurang **kurang 2**
(FCM-nya belum dikirim; yang jalan cuma websocket). Kalau nggak muncul sama
sekali walau app terbuka, yang kurang **kurang 1** (kunci Reverb).
