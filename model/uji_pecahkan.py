"""Uji penguraian CTC — dijalankan langsung, tanpa pytest dan tanpa TensorFlow.

    python3 uji_pecahkan.py

## Kenapa ini ada, padahal cuma satu fungsi

Waktu model masih mentah, `pecahkan()` mengembalikan string kosong buat semua
sel. Itu SAMA PERSIS dengan yang keluar kalau penguraiannya sendiri rusak —
dan waktu skornya 0%, tidak ada cara membedakan "modelnya belum belajar" dari
"pembacanya salah". Uji ini yang memutus kebingungan itu: selama dia hijau,
0% berarti modelnya, bukan penguraiannya.

Sengaja tanpa impor TensorFlow supaya jalan dalam hitungan detik — itu sebabnya
`pecahkan` dan `BLANK` duduk di `data_sel.py`, bukan di `latih.py`.
"""

from __future__ import annotations

import sys

import numpy as np

from data_sel import BLANK, KELAS, dari_indeks, ke_indeks, pecahkan


def _ramalan(jalur: list[int], langkah: int = 80) -> np.ndarray:
    """Bikin keluaran model palsu yang yakin 100% pada `jalur`, direntangkan."""
    r = np.zeros((langkah, KELAS), dtype=np.float32)

    for t in range(langkah):
        r[t, jalur[t * len(jalur) // langkah]] = 1.0

    return r


KASUS: list[tuple[list[int], str]] = [
    ([1, BLANK, 2, BLANK, 3], "123"),
    ([2, 5, 10, 3], "25,3"),
    ([11, 4, BLANK, 2], "-42"),
    ([BLANK], ""),
    # Dua aturan CTC yang paling gampang salah, dan saling berlawanan:
    ([1, 1], "1"),  # langkah kembar berurutan DILEBUR
    ([1, BLANK, 1], "11"),  # ...tapi blank di antaranya membatalkan peleburan
    # Tanpa aturan kedua, angka `11` mustahil dibaca sama sekali.
    ([9, 9, 9, BLANK, 0, 0], "90"),
]


def main() -> int:
    gagal = 0

    for jalur, benar in KASUS:
        dapat = pecahkan(_ramalan(jalur)[None])[0]

        if dapat != benar:
            gagal += 1
            print(f"GAGAL {jalur} -> {dapat!r}, harusnya {benar!r}")

    for teks in ("0", "9000,5", "-12,75", "25,3"):
        if dari_indeks(ke_indeks(teks)) != teks:
            gagal += 1
            print(f"GAGAL bolak-balik {teks!r}")

    # Huruf di luar alfabet dibuang, bukan dipaksa jadi indeks lain.
    if ke_indeks("25.3") != ke_indeks("253"):
        gagal += 1
        print("GAGAL titik harusnya dibuang")

    print(f"{len(KASUS) + 5} periksa, {gagal} gagal")

    return 1 if gagal else 0


if __name__ == "__main__":
    sys.exit(main())
