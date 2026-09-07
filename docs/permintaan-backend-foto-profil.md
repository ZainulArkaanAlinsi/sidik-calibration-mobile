# Permintaan: foto profil disimpan di server — 8 September 2026

Untuk: backend · dari: frontend (mobile)

Satu permintaan saja, kecil, tapi dia yang mengunci satu fitur yang sudah
jadi separuh di mobile.

---

## Keadaan sekarang

Foto profil di aplikasi ini **tidak pernah keluar dari HP pemiliknya**.
Disimpan lokal lewat `SharedPreferences` dengan kunci `avatar.v1.<user_id>`,
dan itu memang disengaja waktu fitur profil dibuat — lihat catatan panjang di
`lib/providers/avatar_provider.dart`:

> Foto profil beda. Dia **nggak punya salinan di server** — belum diunggah di
> fase ini, jadi yang di HP itu satu-satunya.

`User` (`lib/models/user.dart`) juga belum punya field foto sama sekali.

## Akibatnya, dan kenapa baru sekarang kelihatan

Layar **Data Teknisi** sekarang menampilkan kartu per akun lengkap dengan
avatar. Di HP admin, satu-satunya foto yang ada adalah **foto admin itu
sendiri** — foto teknisi lain tidak pernah sampai ke perangkat itu.

Jadi sekarang perilakunya begini, dan ini bukan bug:

| Kartu | Yang tampil |
|---|---|
| Akun sendiri | Foto asli yang dia pilih |
| Akun orang lain | Inisial nama di lingkaran berwarna |

Warnanya diturunkan dari `user.id` supaya tiap orang punya warna tetap —
pengenal seadanya, bukan sekadar abu seragam. Tapi tetap saja: layar yang
tujuannya "kenali siapa teknisimu" isinya huruf, bukan wajah.

Tempat lain yang menunggu hal yang sama: avatar di bilah atas panel desktop
(`desktop_shell.dart`) dan kartu profil (`profile_screen.dart`).

---

## Yang diminta

### 1. Field URL foto di resource user

Ikut di **semua** tempat `user` dikirim — `GET /users`, detail sesi yang
menyertakan teknisi, dan `GET /me`:

```json
{
  "id": 12,
  "nama": "...",
  "email": "...",
  "foto_url": "https://.../storage/avatar/12.jpg"
}
```

`null` kalau belum pernah mengunggah. Mobile sudah siap memperlakukan `null`
sebagai "pakai inisial" — itu jalur yang sekarang dipakai semua orang, jadi
tidak ada yang rusak selama masa peralihan.

**Namanya tolong dikonfirmasi.** `foto_url` cuma usulan supaya ada yang
konkret dibahas; yang penting satu nama dipakai konsisten di semua endpoint.
Kalau backend lebih suka `avatar_url` atau nested `foto: {url, thumb}`,
sebut saja — mobile yang menyesuaikan.

### 2. Endpoint unggah

```
POST /users/{id}/foto      (multipart, field: foto)
```

Mobile sudah punya jalur multipart yang terpakai dan teruji
(`ApiClient.unggahFile` — dipakai Import Excel dan foto OCR), jadi dari sisi
kami ini tinggal memanggil.

Yang perlu diputuskan backend:

- **Siapa yang boleh.** Usul kami: orangnya sendiri, plus admin untuk akun
  mana pun. Tapi ini keputusan kalian — kalau admin tidak boleh mengubah foto
  orang lain, mobile cukup menyembunyikan tombolnya.
- **Batas ukuran & jenis berkas**, supaya mobile bisa menolak lebih dulu di
  HP daripada mengirim 8 MB lewat sinyal lapangan baru ditolak server.
- **Ukuran yang dikembalikan.** Kalau ada versi kecil (mis. 128 px), kartu
  daftar pakai itu; daftar 30 akun yang menarik 30 foto ukuran penuh itu
  mahal di kuota teknisi.

---

## Yang TIDAK diminta

Tidak perlu memindahkan foto yang sudah terlanjur ada di HP orang ke server.
Itu berarti menebak siapa pemilik berkas lama, dan tebakan seperti itu persis
kebocoran yang sudah ditutup `avatar_provider.dart` (foto orang sebelumnya
terpasang sebagai identitas orang berikutnya). Biarkan saja; pemiliknya
memilih ulang sekali, dan sesudah itu ada di server.

---

## Sesudah ini ada, yang berubah di mobile

Kecil, dan sengaja dibikin begitu sejak awal: sumber gambar di `_AvatarAkun`
(`technician_list_screen.dart`). Bentuk kartunya, jalur inisial, dan
penanganan `null`-nya sudah berdiri sekarang dan tidak perlu diubah.
