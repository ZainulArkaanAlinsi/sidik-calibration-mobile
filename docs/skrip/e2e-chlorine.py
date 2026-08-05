"""Uji rantai penuh Chlorin Meter: bentuk lembar kerja -> input teknisi ->
perhitungan -> approve admin -> sertifikat PDF.

Dijalankan lawan API yang beneran hidup, bukan mock. Tiap mata rantai dicetak
statusnya biar kelihatan persis di mana putusnya kalau putus.

Beda dari `e2e-ph.py`, dan dua-duanya disengaja:

1. **Id alat & standar dicari, bukan dipatok.** Skrip pH nulis `equipment_id: 5`
   dan `standard_id: 3` apa adanya — begitu database diseed ulang atau ada yang
   nambah alat, skripnya gagal dengan pesan yang nggak nyambung. Di sini semua
   id diresolusi dari nama/serial lewat API.

2. **Bentuk lembar kerjanya ikut diperiksa** (`?profil=chlorine_meter`). Itu
   kontrak yang paling baru dan belum pernah diadu ke backend hidup sama sekali.

3. **CMC per titik diperiksa.** Dua titik chlorine cuma 0,09 apart — lebih rapat
   dari toleransi pencocokan kemampuan di `GumCalculator` (0,1). Pernah bikin
   titik 1,83 kepasang CMC 0,091 punya tetangganya, tanpa satu pun error. Kalau
   itu balik lagi, skrip ini yang teriak duluan.

Pakai:
    python3 docs/skrip/e2e-chlorine.py [BASE_URL] [output.pdf]
    python3 docs/skrip/e2e-chlorine.py http://127.0.0.1:8000/api
"""

import json
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/api"

# Titik & CMC dari lampiran akreditasi LK-285-IDN no. 42 (dan sheet DATABASE
# workbook). BUKAN 0,40/4,00 yang tercetak di lembar kerja Rev.2 — lihat
# docblock `ChlorineProfile` di backend.
TITIK = [
    {"nilai": 1.74, "cmc": 0.091, "standar": "Chlorine Standard Solution 1.74 mg/L"},
    {"nilai": 1.83, "cmc": 0.08, "standar": "Chlorine Standar Cuvettes 1.83 mg/L"},
]

# Pembacaan After Adjustment sesi asli 0189-CAL-624 (INPUT DATA G/I 46-50).
PEMBACAAN = {
    1.74: [1.76, 1.76, 1.76, 1.76, 1.75],
    1.83: [1.86, 1.86, 1.86, 1.86, 1.86],
}
SUHU = [25.7, 25.8, 25.8, 25.8, 25.8]


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
    except urllib.error.URLError as e:
        sys.exit(
            f"BERHENTI: {BASE} nggak kejangkau ({e.reason}).\n"
            "  Cek: `php artisan serve` nyala? bind-nya 0.0.0.0 apa 127.0.0.1?\n"
            "  Lihat catatan 'HP gagal konek != server mati' sebelum nyalahin backend."
        )


def login(identifier):
    kode, res = panggil(
        "POST", "/login", body={"identifier": identifier, "password": "rahasia123"}
    )
    assert kode == 200, f"login {identifier} gagal: {kode} {res}"
    return res["data"]["token"]


def langkah(no, judul):
    print(f"\n{'=' * 62}\nLANGKAH {no}: {judul}\n{'=' * 62}")


def dekat(a, b, toleransi=1e-6):
    return a is not None and b is not None and abs(float(a) - float(b)) <= toleransi


gagal = []

# ─────────────────────────────────────────────────────────────────────────────
langkah(1, "Login teknisi & admin")
tek = login("SDK-0002")
adm = login("SDK-0001")
print("  teknisi & admin dapat token")

# ─────────────────────────────────────────────────────────────────────────────
langkah(2, "Ambil bentuk lembar kerja ?profil=chlorine_meter")
kode, res = panggil("GET", "/calibrations/lembar-kerja?profil=chlorine_meter", tek)
print("  GET /lembar-kerja?profil=chlorine_meter ->", kode)
if kode != 200:
    print("  ISI:", json.dumps(res, indent=2)[:800])
    gagal.append(f"bentuk lembar kerja {kode}")
else:
    bentuk = res.get("data", res)
    print("  kode_dokumen   :", bentuk.get("kode_dokumen"))
    print("  satuan         :", bentuk.get("satuan"))
    print("  larutan_standar:", bentuk.get("larutan_standar"))

    if bentuk.get("kode_dokumen") != "SIDIK-FM-CAL-0531_Rev.2":
        gagal.append(f"kode dokumen bukan 0531 ({bentuk.get('kode_dokumen')})")
    if bentuk.get("satuan") != "mg/L":
        gagal.append(f"satuan bukan mg/L ({bentuk.get('satuan')})")

    titik_backend = [float(x) for x in (bentuk.get("larutan_standar") or [])]
    if titik_backend != [1.74, 1.83]:
        gagal.append(
            f"titik ukur {titik_backend} != [1.74, 1.83] — "
            "backend balik ke angka yang tercetak di form?"
        )

    # Baris STANDARD harus ketaut ke master; kalau `terdaftar: false` artinya
    # standar chlorine-nya belum diseed dan ketertelusurannya bakal kosong.
    uc = next(
        (b for b in bentuk.get("bagian", []) if b.get("kode") == "usage_check"), None
    )
    for baris in (uc or {}).get("baris", []):
        tanda = "OK " if baris.get("terdaftar") else "!! "
        print(f"    {tanda}STANDARD {baris.get('label')}")
    if uc and not any(
        b.get("terdaftar") and "Chlorine" in (b.get("label") or "")
        for b in uc.get("baris", [])
    ):
        gagal.append("standar chlorine nggak ketaut ke master (belum diseed?)")

# ─────────────────────────────────────────────────────────────────────────────
langkah(3, "Cari alat & standar chlorine (id dicari, bukan dipatok)")
kode, res = panggil("GET", "/equipments?search=Chlorine", tek)
daftar = res.get("data", []) if kode == 200 else []
alat = next(
    (e for e in daftar if (e.get("nama_alat_kemampuan") or "").lower() == "chlorin meter"),
    None,
) or next((e for e in daftar if "hlorin" in (e.get("nama_alat") or "")), None)

if not alat:
    print("  GET /equipments?search=Chlorine ->", kode, f"({len(daftar)} hasil)")
    sys.exit(
        "BERHENTI: alat Chlorin Meter nggak ada di database.\n"
        "  Jalanin dulu:\n"
        "    php artisan db:seed --class=ChlorineCapabilitySeeder\n"
        "    php artisan db:seed --class=ChlorineSeeder\n"
        "  Dua-duanya updateOrCreate — nambah, nggak ngehapus apa pun."
    )
print(f"  alat #{alat['id']} {alat.get('nama_alat')} / {alat.get('model')} "
      f"sn={alat.get('serial_number')} kemampuan={alat.get('nama_alat_kemampuan')}")

kode, res = panggil("GET", "/standards", tek)
semua_std = res.get("data", []) if kode == 200 else []
std_id = {}
for t in TITIK:
    cocok = next((s for s in semua_std if s.get("nama") == t["standar"]), None)
    if not cocok:
        gagal.append(f"standar '{t['standar']}' nggak ada di master")
        continue
    std_id[t["nilai"]] = cocok["id"]
    print(f"  standar #{cocok['id']} {cocok['nama']} U95={cocok.get('ketidakpastian')} "
          f"berlaku={cocok.get('masih_berlaku')}")
    if cocok.get("masih_berlaku") is False:
        gagal.append(f"standar '{t['standar']}' kadaluarsa — backend bakal nolak 422")

if len(std_id) < 2:
    sys.exit("BERHENTI: standar chlorine belum lengkap, sesi nggak bisa dibikin.")

thermo = next(
    (s for s in semua_std if s.get("nama") == "TH-4"),
    next((s for s in semua_std if (s.get("nama") or "").startswith("TH-")), None),
)
print("  thermohygro:", (thermo or {}).get("nama", "(nggak ada)"))

# ─────────────────────────────────────────────────────────────────────────────
langkah(4, "Teknisi kirim lembar kerja Chlorine (2 titik x 5 pembacaan)")
payload = {
    "client_request_id": str(uuid.uuid4()),
    "equipment_id": alat["id"],
    "standard_id": std_id[1.74],
    "thermohygro_standard_id": (thermo or {}).get("id"),
    "tanggal_kalibrasi": "2026-08-05",
    "tanggal_terima": "2026-08-04",
    "input_method": "manual",
    "lokasi": "lab",
    # Kondisi lingkungan apa adanya dari sesi asli 0189-CAL-624.
    "suhu_awal": 24.1,
    "suhu_akhir": 23.5,
    "kelembaban_awal": 56,
    "kelembaban_akhir": 55,
    "catatan_teknisi": "Uji rantai penuh otomatis (chlorine).",
    "standar_dicek": [{"standard_id": i, "dipakai": True} for i in std_id.values()],
    "measurements": [
        {
            "titik_ukur": t["nilai"],
            "satuan": "mg/L",
            "standard_id": std_id[t["nilai"]],
            "pembacaan": PEMBACAAN[t["nilai"]],
            "suhu": SUHU,
        }
        for t in TITIK
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

# ─────────────────────────────────────────────────────────────────────────────
langkah(5, "Cek hitungan — TIAP TITIK HARUS DAPAT CMC-NYA SENDIRI")
kode, res = panggil("GET", f"/calibrations/{sid}", tek)
print("  GET /calibrations/{id} ->", kode)
d = res.get("data", res)
titik = d.get("titik") or []
print(f"  jumlah titik: {len(titik)}")

if len(titik) != 2:
    gagal.append(f"titik kehitung {len(titik)}, harusnya 2")

for t in titik:
    nilai = float(t.get("titik_ukur") or 0)
    harap = next((x for x in TITIK if dekat(x["nilai"], nilai, 0.01)), None)
    u95 = t.get("ketidakpastian_diperluas")
    print(f"    titik {nilai}: rata2={t.get('rata_rata')} error={t.get('error')} "
          f"U95={u95} k={t.get('faktor_cakupan_k')} -> {t.get('keputusan')}")

    if u95 in (None, 0):
        gagal.append(f"titik {nilai} nggak punya U95%")
        continue
    if harap is None:
        gagal.append(f"titik {nilai} nggak dikenal")
        continue

    # Ini inti pemeriksaannya. U hitung dua titik ini di bawah CMC, jadi yang
    # dilaporkan HARUS persis CMC titiknya sendiri: 0,091 buat 1,74 dan 0,08
    # buat 1,83. Kalau 1,83 balik 0,091, kemampuannya ketuker sama tetangganya.
    if not dekat(u95, harap["cmc"], 1e-6):
        gagal.append(
            f"titik {nilai}: U95={u95} != CMC {harap['cmc']} — "
            "kemampuan ketuker sama titik sebelah?"
        )

    komponen = [k.get("sumber") for k in (t.get("type_b_components") or [])]
    if "faktor_pengenceran" not in komponen:
        gagal.append(f"titik {nilai}: komponen 'faktor_pengenceran' nggak ada "
                     f"(dapatnya: {komponen}) — profil chlorine kepilih?")

print("  hasil penentu:", json.dumps(d.get("hasil")))

# ─────────────────────────────────────────────────────────────────────────────
langkah(6, "Admin buka lembar perhitungan")
kode, res = panggil("GET", f"/calibrations/{sid}/perhitungan", adm)
print("  GET /perhitungan ->", kode)
if kode != 200:
    gagal.append(f"/perhitungan {kode}")
    print("  ISI:", json.dumps(res, indent=2)[:800])
else:
    p = res.get("data", res)
    print("  kunci:", ", ".join(list(p.keys())[:12]))

langkah(7, "Admin cek validasi sebelum approve")
kode, res = panggil("GET", f"/calibrations/{sid}/validasi", adm)
print("  GET /validasi ->", kode)
print("  ", json.dumps(res.get("data", res))[:600])

langkah(8, "Admin setujui sesi (peringatan nahan SEKALI, lalu dilanjut sadar)")
kode, res = panggil("POST", f"/calibrations/{sid}/approve", adm, {})
print("  POST /approve ->", kode)

# 422 + `butuh_konfirmasi` itu PERILAKU BENER, bukan kegagalan: backend nahan
# sekali kalau ada temuan tingkat peringatan, dan admin mesti lanjut secara
# sadar. Alat chlorine SELALU kena ini — larutan standarnya nggak punya kurva
# suhu di master (sama kayak turbidity), jadi suhu larutan yang dicatat teknisi
# nggak kepakai dan validator ngasih tahu. Layar admin nampilin ini sebagai
# dialog konfirmasi; skrip ini niru langkah yang sama.
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

langkah(9, "Tunggu antrean menerbitkan sertifikat")
sert = None
for i in range(30):
    kode, res = panggil("GET", f"/calibrations/{sid}", adm)
    sert = (res.get("data") or {}).get("sertifikat")
    if sert and sert.get("status"):
        print(f"  detik {i * 2}: sertifikat {sert.get('nomor')} "
              f"status={sert.get('status')} pdf={bool(sert.get('pdf_url'))}")
        if sert.get("status") == "terbit":
            break
    else:
        print(f"  detik {i * 2}: belum ada sertifikat")
    time.sleep(2)
if not sert or sert.get("status") != "terbit":
    gagal.append("sertifikat tidak terbit")

langkah(10, "Unduh PDF sertifikat")
if sert and sert.get("id"):
    kode, isi = panggil("GET", f"/certificates/{sert['id']}/download", adm, raw=True)
    print("  GET /download ->", kode)
    if kode == 200 and isinstance(isi, bytes):
        print(f"  ukuran PDF: {len(isi)} byte, header: {isi[:5]!r}")
        if not isi.startswith(b"%PDF"):
            gagal.append("berkas unduhan bukan PDF")
        else:
            keluaran = sys.argv[2] if len(sys.argv) > 2 else "sertifikat-chlorine-e2e.pdf"
            open(keluaran, "wb").write(isi)
            print(f"  PDF tersimpan di {keluaran}.")
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
