"""Latih CNN kecil pengenal KARAKTER tunggal 28x28, ekspor TFLite int8 + meta.json.

    .venv/Scripts/python -I latih_karakter.py --epoch 4
    .venv/Scripts/python -I latih_karakter.py --dari /path/contoh_sel --epoch 10

Masukan model = keluaran ``segmentasi_karakter.dart`` (``KarakterSel.piksel``):
float32 [1, 28, 28, 1] dalam 0..1, tinta terang. Keluaran = softmax 14 kelas
(``data_karakter.KELAS``).

``asal_data`` di meta.json:

- ``publik`` — hanya MNIST + tanda baca sintetis. Aplikasi WAJIB menolak
  memakai model ini untuk mengisi sel (``PembacaDigitTflite``): tulisan
  teknisi bukan MNIST, dan akurasi di set uji publik bukan ramalan akurasi di
  lembar kerja.
- ``asli`` — ada contoh sel terkonfirmasi dari HP (``--dari``). Itu pun belum
  izin pakai: harus lewat mode bayangan dan pengukuran per lembar dulu.

Kuantisasi: int8 penuh di dalam (bobot + aktivasi, representative dataset),
masukan/keluaran float32 supaya pembungkus Dart sederhana. Target < 1 MB.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import time
from pathlib import Path

import sys

import numpy as np

# `python -I` tidak memasukkan folder skrip ke sys.path; modul saudara
# (`data_karakter`) dimuat eksplisit dari folder INI saja.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import data_karakter as dk  # noqa: E402

VERSI = "v0"


def bangun_model(n_kelas: int):
    import keras
    from keras import layers

    return keras.Sequential(
        [
            keras.Input((dk.SISI, dk.SISI, 1)),
            layers.Conv2D(16, 3, padding="same", activation="relu"),
            layers.MaxPooling2D(),
            layers.Conv2D(32, 3, padding="same", activation="relu"),
            layers.MaxPooling2D(),
            layers.Conv2D(64, 3, padding="same", activation="relu"),
            layers.MaxPooling2D(),
            layers.Flatten(),
            layers.Dense(64, activation="relu"),
            layers.Dropout(0.3),
            layers.Dense(n_kelas, activation="softmax"),
        ]
    )


def akurasi_tflite(berkas: bytes, x: np.ndarray, y: np.ndarray) -> float:
    import tensorflow as tf

    it = tf.lite.Interpreter(model_content=berkas)
    it.allocate_tensors()
    masuk, keluar = it.get_input_details()[0], it.get_output_details()[0]
    benar = 0
    for i in range(len(x)):
        it.set_tensor(masuk["index"], x[i : i + 1])
        it.invoke()
        benar += int(np.argmax(it.get_tensor(keluar["index"])[0]) == y[i])
    return benar / len(x)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epoch", type=int, default=4)
    ap.add_argument("--dari", type=Path, help="folder contoh_sel dari HP")
    ap.add_argument("--keluaran", type=Path, default=Path("keluaran"))
    ap.add_argument("--benih", type=int, default=13)
    a = ap.parse_args()

    import tensorflow as tf

    tf.keras.utils.set_random_seed(a.benih)
    t0 = time.time()

    (xl, yl), (xu, yu) = dk.mnist_dinormalkan()
    xbl, ybl = dk.tanda_baca_sintetis(2000, a.benih)
    xbu, ybu = dk.tanda_baca_sintetis(300, a.benih + 1)
    asal = "publik"
    sumber = ["mnist", "tanda_baca_sintetis"]
    dibuang_asli = None

    if a.dari:
        xa, ya, dibuang_asli = dk.karakter_dari_contoh_sel(a.dari)
        if xa is not None:
            xl, yl = np.concatenate([xl, xa]), np.concatenate([yl, ya])
            asal = "asli"
            sumber.append("contoh_sel")

    xl = np.concatenate([xl, xbl]).astype(np.float32)[..., None] / 255.0
    yl = np.concatenate([yl, ybl])
    # Diacak SEBELUM fit: validation_split mengambil EKOR data, dan tanpa acak
    # ekornya seluruhnya tanda baca sintetis (dibuang dari latih, val palsu).
    acak = np.random.default_rng(a.benih).permutation(len(xl))
    xl, yl = xl[acak], yl[acak]
    xu_d = xu.astype(np.float32)[..., None] / 255.0
    xbu = xbu.astype(np.float32)[..., None] / 255.0

    m = bangun_model(len(dk.KELAS))
    m.compile("adam", "sparse_categorical_crossentropy", metrics=["accuracy"])
    m.fit(xl, yl, epochs=a.epoch, batch_size=128, validation_split=0.05, verbose=2)

    def wakil():
        idx = np.random.default_rng(0).choice(len(xl), 300, replace=False)
        for i in idx:
            yield [xl[i : i + 1]]

    conv = tf.lite.TFLiteConverter.from_keras_model(m)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.representative_dataset = wakil
    conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    berkas = conv.convert()

    a.keluaran.mkdir(parents=True, exist_ok=True)
    nama = f"pengenal_karakter_{VERSI}.tflite"
    (a.keluaran / nama).write_bytes(berkas)

    meta = {
        "versi": VERSI,
        "berkas": nama,
        "sha256": hashlib.sha256(berkas).hexdigest(),
        "ukuran_byte": len(berkas),
        "asal_data": asal,
        "sumber_data": sumber,
        "kelas": dk.KELAS,
        "masukan": {"bentuk": [1, dk.SISI, dk.SISI, 1], "tipe": "float32",
                    "skala": "0..1, tinta terang di latar gelap"},
        "keluaran": {"bentuk": [1, len(dk.KELAS)], "tipe": "float32", "isi": "softmax"},
        "kuantisasi": "int8 internal (bobot+aktivasi), I/O float32",
        "akurasi": {
            "mnist_uji_10000_tflite": akurasi_tflite(berkas, xu_d, yu),
            "tanda_baca_sintetis_uji_900_tflite": akurasi_tflite(berkas, xbu, ybu),
        },
        "catatan": "Akurasi set uji PUBLIK, bukan tulisan teknisi. "
        "asal_data=publik -> aplikasi menolak memakai model ini untuk mengisi sel.",
        "contoh_sel_dibuang": dibuang_asli,
        "epoch": a.epoch,
        "detik_latih": round(time.time() - t0, 1),
    }
    (a.keluaran / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
