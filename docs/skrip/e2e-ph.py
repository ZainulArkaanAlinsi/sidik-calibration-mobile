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

langkah(2, "Teknisi kirim lembar kerja pH (3 titik x 3 pembacaan)")
payload = {
    "client_request_id": str(uuid.uuid4()),
    "equipment_id": 5,
    "standard_id": 3,
    "thermohygro_standard_id": 8,
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
        {"standard_id": 2, "dipakai": True},
        {"standard_id": 3, "dipakai": True},
        {"standard_id": 4, "dipakai": True},
    ],
    "measurements": [
        {"titik_ukur": 4.00, "satuan": "pH", "standard_id": 2,
         "pembacaan": [4.01, 4.02, 4.00], "suhu": [19.8, 19.8, 19.9]},
        {"titik_ukur": 7.00, "satuan": "pH", "standard_id": 3,
         "pembacaan": [7.02, 7.01, 7.03], "suhu": [19.8, 19.8, 19.9]},
        {"titik_ukur": 10.00, "satuan": "pH", "standard_id": 4,
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

langkah(3, "Cek hitungan ketidakpastian tersimpan")
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

langkah(4, "Admin buka lembar perhitungan")
kode, res = panggil("GET", f"/calibrations/{sid}/perhitungan", adm)
print("  GET /perhitungan ->", kode)
if kode != 200:
    gagal.append(f"/perhitungan {kode}")
    print("  ISI:", json.dumps(res, indent=2)[:800])
else:
    p = res.get("data", res)
    print("  kunci:", ", ".join(list(p.keys())[:12]))

langkah(5, "Admin cek validasi sebelum approve")
kode, res = panggil("GET", f"/calibrations/{sid}/validasi", adm)
print("  GET /validasi ->", kode)
print("  ", json.dumps(res.get("data", res))[:600])

langkah(6, "Admin setujui sesi")
kode, res = panggil("POST", f"/calibrations/{sid}/approve", adm, {})
print("  POST /approve ->", kode)
if kode not in (200, 201):
    print("  ISI:", json.dumps(res, indent=2)[:1200])
    gagal.append(f"approve {kode}")
else:
    print("  status sesi:", (res.get("data") or {}).get("status"))

langkah(7, "Tunggu antrean menerbitkan sertifikat")
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

langkah(8, "Unduh PDF sertifikat")
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
