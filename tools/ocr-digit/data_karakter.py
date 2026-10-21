"""Data untuk pengenal KARAKTER tunggal 28x28 (keluaran segmentasi di HP).

Kelas (urutan = indeks keluaran model, jangan diubah tanpa menaikkan versi):

    0 1 2 3 4 5 6 7 8 9 , . - coretan

Sumber:

- ``mnist``  — digit MNIST lewat ``keras.datasets.mnist`` (lisensi: lihat
  README; tidak dinyatakan tegas di halaman aslinya).
- ``tanda_baca_sintetis`` — koma, titik, minus DIGAMBAR program ini. Tidak ada
  set publik untuk tanda baca tulisan tangan yang dinormalkan seperti
  ``segmentasi_karakter.dart``.
- ``coretan`` — KOSONG. Kelasnya disediakan supaya bentuk keluaran model tidak
  berubah saat data coretan asli masuk (TODO(ATURAN-0541-1)).
- ``contoh_sel`` — contoh terkonfirmasi dari HP (format ``SimpananContohSel``:
  ``indeks.jsonl`` + ``sel_*.jpg|png``). Dipotong per karakter dengan port
  sederhana segmentasi Dart; sel yang jumlah karakternya tidak cocok dengan
  labelnya DIBUANG, bukan ditebak penjajarannya.

Normalisasi sama dengan ``_keMnist`` di Dart: tinta terang (255) di latar
gelap, dimuat ke 20x20 dengan rasio tetap, di tengah kanvas 28x28.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np

KELAS = [str(d) for d in range(10)] + [",", ".", "-", "coretan"]
SISI = 28
ISI = 20


def ke_mnist(tinta: np.ndarray) -> np.ndarray:
    """Matriks tinta (0..255, terang = tinta) bebas ukuran -> 28x28 uint8."""
    from PIL import Image

    ys, xs = np.nonzero(tinta > 0)
    if len(xs) == 0:
        return np.zeros((SISI, SISI), np.uint8)
    pot = tinta[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    h, w = pot.shape
    s = ISI / max(h, w)
    lb, tg = max(1, min(ISI, round(w * s))), max(1, min(ISI, round(h * s)))
    kecil = np.asarray(
        Image.fromarray(pot.astype(np.uint8)).resize((lb, tg), Image.BOX)
    )
    out = np.zeros((SISI, SISI), np.uint8)
    ox, oy = (SISI - lb) // 2, (SISI - tg) // 2
    out[oy : oy + tg, ox : ox + lb] = kecil
    return out


def mnist_dinormalkan():
    """MNIST (latih, uji) dinormalkan ulang ke bentuk Dart (bukan 20x20 asli
    MNIST yang dipusatkan menurut pusat massa)."""
    import keras

    (xl, yl), (xu, yu) = keras.datasets.mnist.load_data()
    norm = lambda x: np.stack([ke_mnist(c) for c in x])  # noqa: E731
    return (norm(xl), yl.astype(np.int64)), (norm(xu), yu.astype(np.int64))


def tanda_baca_sintetis(n_per_kelas: int, benih: int):
    """Koma, titik, minus bergaya goresan pena, SUDAH dinormalkan ke-MNIST."""
    from PIL import Image, ImageDraw

    rng = np.random.default_rng(benih)
    x, y = [], []
    for kelas in (",", ".", "-"):
        idx = KELAS.index(kelas)
        for _ in range(n_per_kelas):
            c = Image.new("L", (40, 40), 0)
            d = ImageDraw.Draw(c)
            tebal = int(rng.integers(3, 8))
            if kelas == ".":
                r = rng.uniform(2.0, 4.5)
                ex = rng.uniform(0.8, 1.3)
                d.ellipse((20 - r * ex, 20 - r, 20 + r * ex, 20 + r), fill=255)
            elif kelas == ",":
                r = rng.uniform(2.0, 4.0)
                d.ellipse((18 - r, 14 - r, 18 + r, 14 + r), fill=255)
                ujung = (18 + rng.uniform(-6, 1), 14 + rng.uniform(8, 16))
                d.line([(18, 14), ujung], fill=255, width=tebal)
            else:
                pj = rng.uniform(10, 26)
                miring = rng.uniform(-3, 3)
                d.line(
                    [(20 - pj / 2, 20 - miring), (20 + pj / 2, 20 + miring)],
                    fill=255,
                    width=tebal,
                )
            x.append(ke_mnist(np.asarray(c)))
            y.append(idx)
    return np.stack(x), np.asarray(y, np.int64)


# ---- contoh sel terkonfirmasi dari HP ----------------------------------------


@dataclass
class ContohSel:
    berkas: Path
    label: str
    lembar: str


def muat_contoh_sel(folder: Path) -> list[ContohSel]:
    """Baca ``indeks.jsonl`` milik ``SimpananContohSel``. Baris rusak dilewati."""
    keluar = []
    indeks = folder / "indeks.jsonl"
    if not indeks.exists():
        return keluar
    for baris in indeks.read_text(encoding="utf-8").splitlines():
        try:
            j = json.loads(baris)
            keluar.append(ContohSel(folder / j["berkas"], j["label"], j["lembar"]))
        except (ValueError, KeyError, TypeError):
            continue
    return keluar


def segmentasi(abu: np.ndarray) -> list[np.ndarray]:
    """Port SEDERHANA ``segmentasi_karakter.dart``: biner adaptif, buang garis
    kotak, komponen tersambung, gabung bertumpuk, urut kiri-kanan. Mengembalikan
    matriks tinta per karakter (belum dinormalkan)."""
    h, w = abu.shape
    r = int(np.clip(h // 2, 7, 64))
    integ = np.pad(abu.astype(np.int64).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    ys, xs = np.mgrid[0:h, 0:w]
    y0, y1 = np.clip(ys - r, 0, h - 1), np.clip(ys + r, 0, h - 1)
    x0, x1 = np.clip(xs - r, 0, w - 1), np.clip(xs + r, 0, w - 1)
    jml = integ[y1 + 1, x1 + 1] - integ[y0, x1 + 1] - integ[y1 + 1, x0] + integ[y0, x0]
    rata = jml / ((x1 - x0 + 1) * (y1 - y0 + 1))
    tinta = abu < rata - 12

    for y in np.nonzero(tinta.sum(1) > w * 0.6)[0]:
        tinta[max(0, y - 1) : y + 2, :] = False
    for x in np.nonzero(tinta.sum(0) > h * 0.6)[0]:
        tinta[:, max(0, x - 1) : x + 2] = False

    label = np.zeros((h, w), np.int32)
    komp = []
    luas_min = max(3, int(np.ceil(h * h * 0.0015)))
    for sy, sx in zip(*np.nonzero(tinta)):
        if label[sy, sx]:
            continue
        idn = len(komp) + 1
        tumpuk, titik = [(sy, sx)], []
        label[sy, sx] = idn
        while tumpuk:
            y, x = tumpuk.pop()
            titik.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and tinta[yy, xx] and not label[yy, xx]:
                        label[yy, xx] = idn
                        tumpuk.append((yy, xx))
        if len(titik) >= luas_min:
            komp.append(titik)

    kotak = []
    for t in komp:
        a = np.asarray(t)
        kotak.append([a[:, 1].min(), a[:, 1].max(), a])
    kotak.sort(key=lambda k: k[0])
    gabung = []
    for k in kotak:
        if gabung:
            p = gabung[-1]
            tumpang = min(p[1], k[1]) - k[0] + 1
            if tumpang > min(p[1] - p[0] + 1, k[1] - k[0] + 1) * 0.5:
                p[0], p[1] = min(p[0], k[0]), max(p[1], k[1])
                p[2] = np.concatenate([p[2], k[2]])
                continue
        gabung.append(k)

    keluar = []
    for _, _, a in gabung:
        m = np.zeros((h, w), np.uint8)
        m[a[:, 0], a[:, 1]] = 255
        keluar.append(m)
    return keluar


def karakter_dari_contoh_sel(folder: Path):
    """Contoh sel -> (x 28x28, y kelas). Sel yang jumlah komponennya tidak sama
    dengan jumlah karakter labelnya DIBUANG (dihitung, bukan ditebak)."""
    from PIL import Image

    x, y, dibuang = [], [], 0
    for c in muat_contoh_sel(folder):
        teks = c.label.replace(" ", "")
        if any(ch not in KELAS for ch in teks) or not c.berkas.exists():
            dibuang += 1
            continue
        abu = np.asarray(Image.open(c.berkas).convert("L"))
        kar = segmentasi(abu)
        if len(kar) != len(teks):
            dibuang += 1
            continue
        for m, ch in zip(kar, teks):
            x.append(ke_mnist(m))
            y.append(KELAS.index(ch))
    if not x:
        return None, None, dibuang
    return np.stack(x), np.asarray(y, np.int64), dibuang
