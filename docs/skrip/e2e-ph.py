"""Uji rantai penuh pH: input teknisi -> perhitungan -> approve admin -> sertifikat PDF.

Dijalankan lawan API yang beneran hidup, bukan mock. Tiap mata rantai dicetak
statusnya biar kelihatan persis di mana putusnya kalau putus.
"""

import json
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/api"


def panggil(method, path, token=None, body=None, raw=False):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            isi = r.read()
            return r.status, (isi if raw else json.loads(isi or b"{}"))
    except urllib.error.HTTPError as e:
        isi = e.read()
        try:
            return e.code, json.loads(isi or b"{}")
        except json.JSONDecodeError:
            return e.code, {"_mentah": isi[:400].decode(errors="replace")}


def login(identifier):
    kode, res = panggil("POST", "/login", body={"identifier": identifier, "password": "rahasia123"})
    assert kode == 200, f"login {identifier} gagal: {kode} {res}"
    return res["data"]["token"]


def langkah(no, judul):
    print(f"\n{'=' * 62}\nLANGKAH {no}: {judul}\n{'=' * 62}")


gagal = []

langkah(1, "Login teknisi & admin")
tek = login("SDK-0002")
adm = login("SDK-0001")
print("  teknisi & admin dapat token")

langkah(2, "Cari alat & buffer pH (id DICARI, bukan dipatok)")
# Dulu `equipment_id: 5` & `standard_id: 2/3/4` dipatok apa adanya. Begitu
# database diseed ulang atau ada yang nambah standar, id itu nunjuk barang
# lain — dan skripnya tetap "jalan", cuma ngalibrasi pakai standar yang salah.
# Kejadian beneran: 5 Agt 2026 id 2/3/4 udah jadi TH-2/TH-3, bukan buffer pH.
kode, res = panggil("GET", "/equipments?search=pH", tek)
alat = next((e for e in res.get("data", []) if "pH" in (e.get("nama_alat") or "")), None)
assert alat, "alat pH nggak ketemu di database"
print(f"  alat #{alat['id']} {alat.get('nama_alat')} sn={alat.get('serial_number')}")

kode, res = panggil("GET", "/standards", tek)
semua_std = res.get("data", [])


kadaluarsa = []


def cari_std(nama):
    s = next((x for x in semua_std if x.get("nama") == nama), None)
    assert s, f"standar '{nama}' nggak ada di master"
    berlaku = s.get("masih_berlaku")
    tanda = "" if berlaku is not False else "  <-- KADALUARSA"
    print(f"  standar #{s['id']} {s['nama']} U95={s.get('ketidakpastian')}"
          f" berlaku_sampai={s.get('berlaku_sampai')}{tanda}")
    if berlaku is False:
        kadaluarsa.append(f"{s['nama']} (sampai {s.get('berlaku_sampai')})")
    return s["id"]


buf4 = cari_std("pH Buffer Solution 4")
buf7 = cari_std("pH Buffer Solution 7")
buf10 = cari_std("pH Buffer Solution 10")
thermo = next((x for x in semua_std if (x.get("nama") or "").startswith("TH-")), None)
print("  thermohygro:", (thermo or {}).get("nama", "(nggak ada)"))

# Backend nolak 422 kalau standarnya kadaluarsa — ketertelusurannya putus, dan
# itu BENER. Diberhentiin di sini dengan sebab yang kebaca, bukan dibiarin mati
# di POST dengan 422 mentah yang kelihatan kayak bug kode.
if kadaluarsa:
    sys.exit(
        "BERHENTI: standar acuan kadaluarsa, rantai pH nggak bisa jalan.\n"
        "  " + "\n  ".join(kadaluarsa) + "\n\n"
        "  Ini kondisi DATA LAB, bukan bug: sertifikat kalibratornya beneran\n"
        "  udah lewat masa berlaku. Pilihannya:\n"
        "    - lab kalibrasi ulang buffernya, lalu perbarui `berlaku_sampai`, ATAU\n"
        "    - buat demo/dev: samain `PhMeterSeeder` sama `TurbidimeterSeeder` &\n"
        "      `ChlorineSeeder` yang pakai `now()->addYear()`.\n"
        "  Angka U95-nya tetap yang asli; yang dipanjangin cuma masa berlakunya."
    )

langkah(3, "Teknisi kirim lembar kerja pH (3 titik x 3 pembacaan)")
payload = {
    "client_request_id": str(uuid.uuid4()),
    "equipment_id": alat["id"],
    "standard_id": buf7,
    "thermohygro_standard_id": (thermo or {}).get("id"),
    "tanggal_kalibrasi": "2026-07-29",
    "tanggal_terima": "2026-07-28",
    "input_method": "manual",
    "lokasi": "lab",
    "suhu_ruang": 19.83,
    "kelembaban": 47.05,
    "suhu_awal": 19.8,
    "suhu_akhir": 19.9,
    "kelembaban_awal": 47.0,
    "kelembaban_akhir": 47.1,
    "catatan_teknisi": "Uji rantai penuh otomatis.",
    "standar_dicek": [
        {"standard_id": buf4, "dipakai": True},
        {"standard_id": buf7, "dipakai": True},
        {"standard_id": buf10, "dipakai": True},
    ],
    "measurements": [
        {"titik_ukur": 4.00, "satuan": "pH", "standard_id": buf4,
         "pembacaan": [4.01, 4.02, 4.00], "suhu": [19.8, 19.8, 19.9]},
        {"titik_ukur": 7.00, "satuan": "pH", "standard_id": buf7,
         "pembacaan": [7.02, 7.01, 7.03], "suhu": [19.8, 19.8, 19.9]},
        {"titik_ukur": 10.00, "satuan": "pH", "standard_id": buf10,
         "pembacaan": [10.03, 10.02, 10.04], "suhu": [19.8, 19.8, 19.9]},
    ],
}
kode, res = panggil("POST", "/calibrations", tek, payload)
print("  POST /calibrations ->", kode)
if kode not in (200, 201):
    print("  ISI:", json.dumps(res, indent=2)[:1500])
    sys.exit("BERHENTI: sesi gagal dibuat.")
sesi = res.get("data", res)
sid = sesi["id"]
print(f"  sesi #{sid} {sesi.get('nomor_sesi')} status={sesi.get('status')}")

langkah(4, "Cek hitungan ketidakpastian tersimpan")
kode, res = panggil("GET", f"/calibrations/{sid}", tek)
print("  GET /calibrations/{id} ->", kode)
d = res.get("data", res)
titik = d.get("titik") or []
print(f"  jumlah titik: {len(titik)}")
for t in titik:
    print(f"    titik {t.get('titik_ukur')}: rata2={t.get('rata_rata')} error={t.get('error')} "
          f"U95={t.get('ketidakpastian_diperluas')} k={t.get('faktor_cakupan_k')} -> {t.get('keputusan')}")
if not titik:
    gagal.append("titik ukur tidak terhitung")
if any(t.get("ketidakpastian_diperluas") in (None, 0) for t in titik):
    gagal.append("ada titik tanpa U95%")
print("  hasil penentu:", json.dumps(d.get("hasil")))
print("  status standar:", (d.get("status_standar") or {}).get("ringkasan"))

langkah(5, "Admin buka lembar perhitungan")
kode, res = panggil("GET", f"/calibrations/{sid}/perhitungan", adm)
print("  GET /perhitungan ->", kode)
if kode != 200:
    gagal.append(f"/perhitungan {kode}")
    print("  ISI:", json.dumps(res, indent=2)[:800])
else:
    p = res.get("data", res)
    print("  kunci:", ", ".join(list(p.keys())[:12]))

langkah(6, "Admin cek validasi sebelum approve")
kode, res = panggil("GET", f"/calibrations/{sid}/validasi", adm)
print("  GET /validasi ->", kode)
print("  ", json.dumps(res.get("data", res))[:600])

langkah(7, "Admin setujui sesi (peringatan nahan SEKALI, lalu dilanjut sadar)")
kode, res = panggil("POST", f"/calibrations/{sid}/approve", adm, {})
print("  POST /approve ->", kode)

# 422 + `butuh_konfirmasi` itu PERILAKU BENER, bukan kegagalan: backend nahan
# sekali kalau ada temuan tingkat peringatan, dan admin mesti lanjut secara
# sadar. Layar admin nampilin ini sebagai dialog; skrip ini niru langkahnya.
if kode == 422 and res.get("butuh_konfirmasi"):
    for t in (res.get("validasi") or {}).get("temuan", []):
        if t.get("tingkat") == "peringatan":
            print(f"    peringatan: {t.get('kode')}")
    print("  -> backend minta konfirmasi; kirim ulang abaikan_peringatan=true")
    kode, res = panggil(
        "POST", f"/calibrations/{sid}/approve", adm, {"abaikan_peringatan": True}
    )
    print("  POST /approve (konfirmasi) ->", kode)

if kode not in (200, 201):
    print("  ISI:", json.dumps(res, indent=2)[:1200])
    gagal.append(f"approve {kode}")
else:
    print("  status sesi:", (res.get("data") or {}).get("status"))

langkah(8, "Tunggu antrean menerbitkan sertifikat")
sert = None
for i in range(30):
    kode, res = panggil("GET", f"/calibrations/{sid}", adm)
    sert = (res.get("data") or {}).get("sertifikat")
    if sert and sert.get("status"):
        print(f"  detik {i}: sertifikat {sert.get('nomor')} status={sert.get('status')} pdf={bool(sert.get('pdf_url'))}")
        if sert.get("status") == "terbit":
            break
    else:
        print(f"  detik {i}: belum ada sertifikat")
    time.sleep(2)
if not sert or sert.get("status") != "terbit":
    gagal.append("sertifikat tidak terbit")

langkah(9, "Unduh PDF sertifikat")
if sert and sert.get("id"):
    kode, isi = panggil("GET", f"/certificates/{sert['id']}/download", adm, raw=True)
    print("  GET /download ->", kode)
    if kode == 200 and isinstance(isi, bytes):
        print(f"  ukuran PDF: {len(isi)} byte, header: {isi[:5]!r}")
        if not isi.startswith(b"%PDF"):
            gagal.append("berkas unduhan bukan PDF")
        else:
            open(sys.argv[2] if len(sys.argv) > 2 else "sertifikat-e2e.pdf", "wb").write(isi)
            print("  PDF tersimpan.")
    else:
        gagal.append(f"download {kode}")
        print("  ISI:", str(isi)[:500])
    print("  QR:", sert.get("qr_payload"))
else:
    gagal.append("tidak ada sertifikat untuk diunduh")

print("\n" + "=" * 62)
print("HASIL:", "SEMUA MATA RANTAI TERSAMBUNG" if not gagal else "PUTUS DI: " + "; ".join(gagal))
print("=" * 62)
sys.exit(1 if gagal else 0)
