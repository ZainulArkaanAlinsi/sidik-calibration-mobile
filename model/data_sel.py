"""Sumber data latih pengenal angka sel — yang ASLI maupun yang bootstrap.

## Dua sumber, dan bedanya menentukan

`SumberAsli` membaca simpanan `SimpananContohSel` yang dikumpulkan aplikasi:
potongan sel sungguhan berikut angka yang diketik teknisi. Itu satu-satunya
data yang boleh melahirkan model yang dipakai di lapangan.

`SumberSintetis` merangkai digit MNIST jadi angka bergaya lembar kerja
(`9000,5`). Dia ada BUKAN untuk melatih model produksi, melainkan supaya
seluruh pipeline — bentuk masukan, pelatihan, ekspor TFLite, pembacaan di
HP — bisa dibuktikan jalan SEBELUM satu pun foto asli ada.

Bedanya dicatat di metadata model (`asal_data`), dan sisi aplikasi menolak
memakai model bertanda `sintetis` kecuali dinyalakan eksplisit. Model bootstrap
yang diam-diam sampai ke tangan teknisi jauh lebih berbahaya daripada tidak
ada model sama sekali: angkanya kelihatan wajar, dan tidak ada yang tahu itu
tebakan.

## Kenapa MNIST dirangkai, bukan dipakai apa adanya

MNIST itu digit TUNGGAL yang terisolasi. Sel lembar kerja berisi angka
multi-digit dengan koma desimal, ditulis rapat di kotak sempit. Model yang
dilatih pada digit tunggal tidak pernah melihat masalah yang sebenarnya —
yaitu memisahkan angka yang saling menempel.

Merangkainya tidak membuat datanya jadi asli. Yang didapat cuma bentuk
persoalan yang benar.
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

# Huruf yang boleh muncul di sel angka kalibrasi.
#
# Koma, bukan titik: teknisi menulis `25,3` dan formulir menyimpannya begitu.
# Minus ikut karena penyimpangan bisa negatif.
ALFABET = "0123456789,-"

# Tinggi masukan model. Dipaku supaya potongan sebesar apa pun mendarat di
# bentuk yang sama; lebarnya juga dipaku karena TFLite paling lancar dengan
# bentuk tetap.
TINGGI = 32
LEBAR = 160


@dataclass
class ContohLatih:
    """Satu pasang (citra sel, angka yang benar)."""

    citra: np.ndarray  # (TINGGI, LEBAR) float32 0..1
    teks: str


def ke_indeks(teks: str) -> list[int]:
    """Teks jadi urutan indeks alfabet. Huruf asing dibuang, bukan dipaksa.

    Dipaksa jadi indeks lain, satu karakter aneh mengubah seluruh label dan
    modelnya belajar dari contoh yang salah tanpa ada yang tahu.
    """
    return [ALFABET.index(c) for c in teks if c in ALFABET]


def dari_indeks(indeks) -> str:
    return "".join(ALFABET[i] for i in indeks if 0 <= i < len(ALFABET))


# Kelas keluaran model: tiap huruf alfabet, plus satu "blank" milik CTC.
#
# Blank-nya ditaruh di INDEKS TERAKHIR, bukan 0. Kalau di 0, dia bentrok dengan
# `"0"` yang karakter sah — dan TensorFlow juga cuma melewati jalur tanpa remap
# waktu blank-nya persis di `jumlah_kelas - 1`.
BLANK = len(ALFABET)
KELAS = len(ALFABET) + 1


def pecahkan(ramalan) -> list[str]:
    """Keluaran model → teks, lewat penguraian CTC greedy.

    Dua aturan CTC yang gampang salah, dan dua-duanya dijaga uji_pecahkan.py:
    langkah kembar BERURUTAN dilebur jadi satu (`[1,1]` → `"1"`), tapi blank di
    antaranya membatalkan peleburan itu (`[1,blank,1]` → `"11"`). Tanpa aturan
    kedua, angka seperti `11` mustahil dibaca.
    """
    hasil = []

    for baris in ramalan:
        urut, sebelumnya = [], -1

        for t in baris.argmax(axis=-1):
            if t != sebelumnya and t != BLANK:
                urut.append(int(t))
            sebelumnya = int(t)

        hasil.append(dari_indeks(urut))

    return hasil


def _muat_ke_kanvas(potongan: np.ndarray) -> np.ndarray:
    """Taruh potongan ke kanvas [TINGGI, LEBAR] tanpa merusak rasio.

    Diregangkan paksa, angka `1` yang kurus jadi selebar `8` dan modelnya
    kehilangan petunjuk bentuk yang paling murah.
    """
    t, l = potongan.shape
    skala = min(TINGGI / t, LEBAR / l)

    baru_t = max(1, int(round(t * skala)))
    baru_l = max(1, int(round(l * skala)))

    kecil = np.asarray(
        Image.fromarray((potongan * 255).astype(np.uint8)).resize(
            (baru_l, baru_t), Image.BILINEAR
        ),
        dtype=np.float32,
    ) / 255.0

    kanvas = np.zeros((TINGGI, LEBAR), dtype=np.float32)
    atas = (TINGGI - baru_t) // 2
    kiri = (LEBAR - baru_l) // 2
    kanvas[atas : atas + baru_t, kiri : kiri + baru_l] = kecil

    return kanvas


class SumberSintetis:
    """Angka bergaya lembar kerja, dirangkai dari digit MNIST.

    BUKAN pengganti data asli — lihat docblock modul.
    """

    asal = "sintetis"

    def __init__(self, seed: int = 0, bagian: str = "latih") -> None:
        """`bagian` memilih belahan MNIST yang goresannya diambil.

        Data uji WAJIB diambil dari belahan `uji`. Kalau dua-duanya menimba
        dari belahan yang sama, glifnya beririsan: 20 ribu angka × ~3,5
        karakter itu ~70 ribu tarikan dari 60 ribu gambar, jadi goresan yang
        sama pasti muncul di latih maupun uji. Rangkaiannya memang beda, tapi
        tulisannya tidak — dan skornya jadi mengaku lebih pintar dari
        sebenarnya.
        """
        import tensorflow as tf

        latih, uji = tf.keras.datasets.mnist.load_data()
        citra, label = {"latih": latih, "uji": uji}[bagian]

        self._per_digit = {d: citra[label == d] for d in range(10)}
        self._koma = self._bikin_koma()
        self._acak = random.Random(seed)
        self._np = np.random.default_rng(seed)

    @staticmethod
    def _bikin_koma() -> np.ndarray:
        """Koma digambar, bukan diambil dari MNIST — MNIST cuma punya digit."""
        k = np.zeros((28, 14), dtype=np.float32)
        k[18:24, 5:9] = 1.0  # badan koma
        k[23:27, 3:7] = 1.0  # ekornya menjuntai ke kiri bawah

        return k

    def _digit(self, d: int) -> np.ndarray:
        kumpulan = self._per_digit[d]

        return kumpulan[self._acak.randrange(len(kumpulan))].astype(np.float32) / 255.0

    def _angka_acak(self) -> str:
        """Bentuk angka yang wajar di lembar kalibrasi.

        Bukan digit acak sepanjang acak: yang dilatih harus melihat sebaran
        yang mirip kertasnya — mayoritas berkoma satu-dua desimal.
        """
        utuh = self._acak.randint(1, 4)
        desimal = self._acak.choice([0, 1, 1, 2])

        teks = "".join(str(self._acak.randrange(10)) for _ in range(utuh))

        if desimal:
            teks += "," + "".join(
                str(self._acak.randrange(10)) for _ in range(desimal)
            )

        if self._acak.random() < 0.05:
            teks = "-" + teks

        return teks

    def _rangkai(self, teks: str) -> np.ndarray:
        potongan = []

        for c in teks:
            if c.isdigit():
                potongan.append(self._digit(int(c)))
            elif c == ",":
                potongan.append(self._koma)
            elif c == "-":
                m = np.zeros((28, 20), dtype=np.float32)
                m[13:16, 3:17] = 1.0
                potongan.append(m)

        # Tumpang tindih kecil antar karakter — tulisan tangan memang rapat,
        # dan model yang cuma pernah melihat karakter terpisah rapi gagal
        # persis di kasus yang paling sering.
        tindih = self._acak.randint(0, 4)
        lebar = sum(p.shape[1] for p in potongan) - tindih * (len(potongan) - 1)

        kanvas = np.zeros((28, max(1, lebar)), dtype=np.float32)
        x = 0

        for p in potongan:
            ujung = min(kanvas.shape[1], x + p.shape[1])
            kanvas[:, x:ujung] = np.maximum(kanvas[:, x:ujung], p[:, : ujung - x])
            x += p.shape[1] - tindih

        return kanvas

    def _kotori(self, citra: np.ndarray) -> np.ndarray:
        """Derau ringan — foto kertas tidak pernah sebersih MNIST."""
        citra = citra + self._np.normal(0, 0.06, citra.shape).astype(np.float32)

        return np.clip(citra, 0.0, 1.0)

    def ambil(self, jumlah: int) -> list[ContohLatih]:
        hasil = []

        for _ in range(jumlah):
            teks = self._angka_acak()
            citra = self._kotori(_muat_ke_kanvas(self._rangkai(teks)))
            hasil.append(ContohLatih(citra=citra, teks=teks))

        return hasil


class SumberAsli:
    """Simpanan contoh yang dikumpulkan aplikasi di HP teknisi.

    Bentuknya persis yang ditulis `SimpananContohSel`: berkas PNG per sel plus
    `indeks.jsonl` yang memuat labelnya.

    Baris indeks yang rusak atau berkas yang hilang DIHITUNG, bukan dilewat
    diam-diam — data latih yang menyusut sendiri bikin model lebih jelek tanpa
    ada yang tahu kenapa.
    """

    asal = "asli"

    def __init__(self, folder: str | Path) -> None:
        self.folder = Path(folder)

    def muat(self) -> tuple[list[ContohLatih], dict[str, int]]:
        indeks = self.folder / "indeks.jsonl"

        if not indeks.exists():
            raise FileNotFoundError(f"Nggak ada indeks di {indeks}")

        hasil: list[ContohLatih] = []
        lewat = {"baris_rusak": 0, "berkas_hilang": 0, "label_asing": 0}

        for baris in indeks.read_text().splitlines():
            if not baris.strip():
                continue

            try:
                j = json.loads(baris)
                nama, label = j["berkas"], j["label"]
            except (json.JSONDecodeError, KeyError, TypeError):
                lewat["baris_rusak"] += 1
                continue

            berkas = self.folder / nama

            if not berkas.exists():
                lewat["berkas_hilang"] += 1
                continue

            # Label yang memuat huruf di luar alfabet dibuang UTUH, bukan
            # dipangkas: `25.3` yang berkoma titik itu label yang salah
            # bentuk, dan melatihnya sebagai `253` mengajarkan kesalahan.
            if not label or any(c not in ALFABET for c in label):
                lewat["label_asing"] += 1
                continue

            abu = np.asarray(
                Image.open(berkas).convert("L"), dtype=np.float32
            ) / 255.0

            # Dibalik: tulisan di kertas itu GELAP di atas terang, sementara
            # model dilatih dengan goresan TERANG di atas gelap (seperti
            # MNIST). Tanpa ini model melihat negatif dari yang dia pelajari.
            hasil.append(
                ContohLatih(citra=_muat_ke_kanvas(1.0 - abu), teks=label)
            )

        return hasil, lewat
