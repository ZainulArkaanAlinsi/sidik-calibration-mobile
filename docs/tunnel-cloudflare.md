# Cloudflare Tunnel — URL API tetap buat development

Status: siap dijalankan, **nunggu domain dibeli** · 9 Agustus 2026

Tujuannya satu: `API_BASE_URL` berhenti berubah tiap sesi. Backend tetap jalan
di laptop (`php artisan serve`), tapi diakses lewat satu URL HTTPS yang tidak
pernah ganti.

Ini **bukan** pengganti VPS produksi di
[`infrastruktur-vps-produksi.md`](infrastruktur-vps-produksi.md). Ini langkah
antara yang gratis dan bisa dipasang hari ini juga.

## Yang beres dan yang tidak

| | |
|---|---|
| ✅ IP LAN laptop ganti tiap pindah wifi | tidak relevan lagi — URL-nya tetap |
| ✅ HP harus sewifi sama laptop | tidak perlu, lewat internet |
| ✅ HTTP polos harus didaftar di `network_security_config.xml` | tidak perlu, HTTPS |
| ✅ HTTPS (kamera & upload butuh ini di web) | otomatis, sertifikat dari Cloudflare |
| ✅ port forwarding / setting router | tidak perlu sama sekali |
| ❌ laptop harus nyala | **iya, tetap.** Laptop mati = API mati |
| ❌ adb pairing HP tiap sesi | **tidak tersentuh.** Itu link debug HP↔laptop, beda urusan |

Poin terakhir penting: tunnel tidak menghapus urusan `adb`. Yang menghapusnya
cuma build release yang dipasang permanen di HP, bukan `flutter run`.

## Prasyarat: domain

Named tunnel butuh domain yang nameserver-nya diarahkan ke Cloudflare. Tanpa
domain, yang tersedia cuma quick tunnel dengan URL `*.trycloudflare.com` yang
**acak tiap restart** — itu tidak menyelesaikan masalah apa pun di sini.

Yang perlu dilakukan sekali:

1. Beli domain. `.my.id` paling murah (~Rp 15–20rb/tahun, di Niagahoster/
   Domainesia), `.com` ~Rp 150rb/tahun. Nama bebas, ini cuma buat development.
2. Daftar akun Cloudflare (gratis), **Add a site**, masukkan domainnya.
3. Cloudflare kasih 2 nameserver. Pasang di panel registrar tempat beli domain,
   ganti nameserver bawaan. Propagasi biasanya 5–30 menit.
4. Tunggu status domain di Cloudflare jadi **Active**.

Selesai itu, sisanya di bawah cuma sekali setup juga.

## Setup tunnel

`cloudflared` sudah terpasang di laptop ini (homebrew, versi 2026.7.3).

```bash
# 1. Login — browser kebuka, pilih domain yang tadi didaftarkan.
#    Hasilnya cert.pem di ~/.cloudflared/
cloudflared tunnel login

# 2. Bikin tunnel. Namanya bebas, dipakai di langkah berikutnya.
cloudflared tunnel create sidik-dev

# 3. Arahkan subdomain ke tunnel. Ganti <domain> dengan domainmu.
#    Cloudflare otomatis bikin record DNS-nya.
cloudflared tunnel route dns sidik-dev api-dev.<domain>
```

Lalu tulis `~/.cloudflared/config.yml`:

```yaml
tunnel: sidik-dev
credentials-file: /Users/nazhiifyudh/.cloudflared/<TUNNEL-ID>.json

ingress:
  - hostname: api-dev.<domain>
    service: http://127.0.0.1:8000
  - service: http_status:404
```

`<TUNNEL-ID>` dicetak waktu `tunnel create`, atau lihat `cloudflared tunnel list`.
Port `8000` disamakan dengan port `php artisan serve`.

Jalankan:

```bash
cloudflared tunnel run sidik-dev
```

Biar nyala sendiri tiap laptop hidup (opsional, tapi ini inti dari "tidak
connect-connect lagi"):

```bash
sudo cloudflared service install
```

## Wajib: bikin Laravel percaya proxy

Di belakang tunnel, TLS diterminasi di Cloudflare — request yang sampai ke
Laravel bentuknya `http://`. Tanpa penyesuaian, `bootstrap/app.php` sekarang
belum punya `trustProxies`, akibatnya:

- URL yang di-generate Laravel (link PDF sertifikat, `next_page_url` pagination)
  keluar sebagai `http://` padahal klien buka lewat `https://` — di HP bisa
  kena blokir cleartext, di web kena mixed content.
- `$request->ip()` isinya IP tunnel, bukan IP klien — rate limit `throttle`
  jadi salah sasaran, semua orang dihitung satu.

Di `sidik-calibration-api`, `bootstrap/app.php`, dalam blok `withMiddleware`:

```php
$middleware->trustProxies(
    at: '*',
    headers: Request::HEADER_X_FORWARDED_FOR
        | Request::HEADER_X_FORWARDED_HOST
        | Request::HEADER_X_FORWARDED_PORT
        | Request::HEADER_X_FORWARDED_PROTO,
);
```

`Illuminate\Http\Request` sudah ke-import di file itu. `at: '*'` aman **selama**
backend cuma bisa dijangkau lewat tunnel — cloudflared connect ke `127.0.0.1`,
tidak ada jalan lain masuk. Kalau nanti pindah VPS yang portnya terbuka ke
publik, ganti `'*'` dengan daftar IP proxy yang jelas.

Lalu di `.env` backend:

```ini
APP_URL=https://api-dev.<domain>
```

## Pakai di aplikasi mobile

`tool/dev.sh` sudah siap menerimanya lewat `API_URL`:

```bash
API_URL=https://api-dev.<domain>/api ./tool/dev.sh hp
API_URL=https://api-dev.<domain>/api ./tool/dev.sh mac
```

Biar tidak diketik terus, taruh di shell profile:

```bash
echo 'export API_URL=https://api-dev.<domain>/api' >> ~/.zshrc
```

Setelah itu `./tool/dev.sh hp` saja sudah cukup, dan relay `adb reverse`
dilewati — alamatnya sudah tetap dari sananya.

## Cek berhasil

```bash
# 422 = endpoint hidup dan validasi jalan (bukan 404/502)
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://api-dev.<domain>/api/login

# health check bawaan Laravel, sudah aktif di bootstrap/app.php
curl -s -o /dev/null -w '%{http_code}\n' https://api-dev.<domain>/up
```

Kalau `502`: tunnel jalan tapi `php artisan serve` mati atau portnya beda.
Kalau `530`/DNS error: domain belum Active di Cloudflare, atau route DNS-nya
belum dibuat.

## Catatan

- **Reverb (websocket)** lewat tunnel bisa — Cloudflare mendukung WebSocket.
  Tambahkan ingress kedua ke `http://127.0.0.1:8080` dengan hostname sendiri
  waktu Reverb mulai dipakai.
- **Jangan taruh data produksi** di belakang tunnel dev. URL-nya publik; yang
  menjaga cuma autentikasi API. Untuk produksi, ikuti
  `infrastruktur-vps-produksi.md`.
- `~/.cloudflared/*.json` dan `cert.pem` itu kredensial. Jangan masuk git.
