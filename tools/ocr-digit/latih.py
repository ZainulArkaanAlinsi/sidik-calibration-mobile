"""Latih pengenal angka sel, lalu ekspor ke TFLite buat ditanam di aplikasi.

    python3 latih.py --sintetis --epoch 8
    python3 latih.py --dari /path/ke/contoh_sel --epoch 30

## Bentuk modelnya, dan kenapa

**CTC, bukan klasifikasi per digit.** Sel lembar kerja berisi angka
multi-digit yang ditulis rapat; memisahkannya jadi karakter satu-satu itu
justru bagian yang paling sulit dan paling sering gagal. CTC membuat
pemisahan tidak pernah perlu dilakukan: modelnya membaca seluruh sel jadi
urutan, dan yang dilatih justru menyelaraskan urutan itu sendiri.

**Konvolusi saja, tanpa LSTM.** Dua alasan yang saling menguatkan: LSTM
sering rewel waktu dikonversi ke TFLite (dan kegagalannya muncul di ujung,
sesudah semuanya kelihatan jalan), dan model konvolusi murni jauh lebih
ringan di HP teknisi. Yang hilang cuma konteks jarak jauh, dan angka enam
karakter tidak membutuhkannya.

## Yang SENGAJA ikut disimpan bersama modelnya

`meta.json` memuat `asal_data`. Model yang dilatih dari data sintetis
ditandai `sintetis`, dan sisi aplikasi menolak memakainya kecuali dinyalakan
eksplisit.

Itu bukan kerapian. Model bootstrap yang diam-diam sampai ke tangan teknisi
lebih berbahaya daripada tidak ada model sama sekali: angkanya kelihatan
wajar, tidak ada yang merah, dan tidak seorang pun tahu itu tebakan dari
digit MNIST.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import keras
import numpy as np
import tensorflow as tf

from data_sel import (
    ALFABET,
    BLANK,
    KELAS,
    LEBAR,
    TINGGI,
    ContohLatih,
    SumberAsli,
    SumberSintetis,
    ke_indeks,
    pecahkan,
)

def bangun_model() -> keras.Model:
    """CNN yang memampatkan tinggi jadi 1 dan menyisakan lebar sebagai waktu.

    Tinggi 32 → 1: dipangkas 32→16→8→4 lewat tiga pooling, lalu 4→1.
    Lebar 160 → 80 langkah waktu — cuma pooling pertama yang memangkas lebar,
    sisanya tegak saja. Enam karakter di 80 langkah itu ruang yang lega buat
    CTC menyelaraskan.
    """
    masuk = keras.Input(shape=(TINGGI, LEBAR, 1), name="citra_sel")

    x = masuk
    for filter_ in (32, 64, 128):
        x = keras.layers.Conv2D(filter_, 3, padding="same", activation="relu")(x)
        x = keras.layers.BatchNormalization()(x)
        # Pooling TEGAK saja setelah yang pertama: lebar harus tetap panjang
        # supaya CTC punya cukup langkah waktu buat memisahkan karakter yang
        # tulisannya menempel.
        x = keras.layers.MaxPooling2D((2, 2) if filter_ == 32 else (2, 1))(x)

    x = keras.layers.Conv2D(128, 3, padding="same", activation="relu")(x)
    x = keras.layers.BatchNormalization()(x)
    x = keras.layers.MaxPooling2D((4, 1))(x)

    # (batch, 1, waktu, fitur) → (batch, waktu, fitur)
    x = keras.layers.Reshape((x.shape[2], x.shape[3]))(x)
    x = keras.layers.Dropout(0.25)(x)
    keluar = keras.layers.Dense(KELAS, activation="softmax", name="urutan")(x)

    return keras.Model(masuk, keluar, name="pengenal_angka_sel")


class ModelCtc(keras.Model):
    """Pembungkus yang menghitung CTC loss di dalam `train_step`.

    Dibungkus, bukan dipakai sebagai `loss=`, karena CTC butuh panjang label
    per contoh — dan itu tidak muat di antarmuka `loss(y_true, y_pred)` biasa.
    """

    def __init__(self, inti: keras.Model) -> None:
        super().__init__()
        self.inti = inti

        # WAJIB lewat pelacak, bukan cuma dikembalikan dari `train_step`.
        # Keras mengambil angka per-epoch dari `get_metrics_result()`, BUKAN
        # dari dict yang dikembalikan train_step — jadi tanpa pelacak ini
        # `fit` melaporkan `loss: 0.0000e+00` sepanjang latihan meski modelnya
        # benar-benar belajar. Itu bukan cuma jelek dilihat: loss satu-satunya
        # tanda apakah latihan menyatu, dan angka nol palsu bikin orang yang
        # melatih dari data asli buta total.
        self._pelacak_rugi = keras.metrics.Mean(name="loss")

    @property
    def metrics(self):
        # Didaftarkan supaya Keras mereset-nya tiap awal epoch.
        return [self._pelacak_rugi]

    def call(self, x, training=False):
        return self.inti(x, training=training)

    def _rugi(self, label, panjang_label, ramalan):
        panjang_masuk = tf.fill(
            (tf.shape(ramalan)[0],), tf.shape(ramalan)[1]
        )

        # `ctc_loss` mendokumentasikan `output` sebagai LOGIT, dan di dalamnya
        # TensorFlow memang menerapkan log_softmax lagi. Mengirim log(peluang)
        # ke situ kelihatan seperti salah — tapi tidak: log_softmax(log p) =
        # log p - log(Σp), dan Σp = 1 karena keluaran model sudah softmax.
        # Jadi hasilnya persis sama.
        #
        # Softmax-nya sengaja ditinggal DI DALAM model, bukan dipindah ke sini:
        # sisi aplikasi butuh peluang buat ambang keyakinan yang mengosongkan
        # sel waktu ragu. Kalau modelnya mengeluarkan logit mentah, tiap
        # pemakainya harus ingat menormalkan sendiri.
        return tf.reduce_mean(
            keras.ops.ctc_loss(
                target=label,
                output=keras.ops.log(ramalan + 1e-8),
                target_length=panjang_label,
                output_length=panjang_masuk,
                mask_index=BLANK,
            )
        )

    def train_step(self, data):
        citra, (label, panjang) = data

        with tf.GradientTape() as tape:
            rugi = self._rugi(label, panjang, self(citra, training=True))

        self.optimizer.apply_gradients(
            zip(tape.gradient(rugi, self.trainable_variables), self.trainable_variables)
        )

        self._pelacak_rugi.update_state(rugi)

        return {"loss": self._pelacak_rugi.result()}

    def test_step(self, data):
        citra, (label, panjang) = data

        self._pelacak_rugi.update_state(
            self._rugi(label, panjang, self(citra, training=False))
        )

        return {"loss": self._pelacak_rugi.result()}


def _siapkan(contoh: list[ContohLatih]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    citra = np.stack([c.citra for c in contoh])[..., None].astype("float32")

    indeks = [ke_indeks(c.teks) for c in contoh]
    panjang = np.array([len(i) for i in indeks], dtype="int32")

    # Dipadding dengan BLANK, bukan 0: `0` itu karakter sah (`"0"`), dan
    # memakainya sebagai padding bikin CTC melihat nol palsu di ekor tiap
    # label — modelnya belajar menempelkan nol yang tidak pernah ditulis.
    lebar = int(panjang.max())
    padded = np.full((len(indeks), lebar), BLANK, dtype="int32")

    for i, urut in enumerate(indeks):
        padded[i, : len(urut)] = urut

    return citra, padded, panjang


def nilai(model: keras.Model, contoh: list[ContohLatih]) -> dict[str, float]:
    """Ukur dengan angka yang berarti buat kalibrasi, bukan cuma loss.

    `sama_persis` yang menentukan: sel kalibrasi itu benar atau salah, nggak
    ada nilai tengah. Angka yang 90% mirip tetap angka yang salah.
    """
    citra = np.stack([c.citra for c in contoh])[..., None].astype("float32")
    tebakan = pecahkan(model.predict(citra, verbose=0))

    persis = sum(a == b.teks for a, b in zip(tebakan, contoh))

    return {
        "sama_persis": persis / len(contoh),
        "jumlah": len(contoh),
    }


def ekspor_tflite(inti: keras.Model, keluar: Path, asal: str, skor: dict) -> None:
    keluar.mkdir(parents=True, exist_ok=True)

    konv = tf.lite.TFLiteConverter.from_keras_model(inti)
    konv.optimizations = [tf.lite.Optimize.DEFAULT]

    (keluar / "pengenal_angka.tflite").write_bytes(konv.convert())

    (keluar / "meta.json").write_text(
        json.dumps(
            {
                "alfabet": ALFABET,
                "blank": BLANK,
                "tinggi": TINGGI,
                "lebar": LEBAR,
                # Dibaca aplikasi. Model `sintetis` DITOLAK kecuali dinyalakan
                # eksplisit — lihat docblock modul ini.
                "asal_data": asal,
                "skor": skor,
            },
            indent=2,
        )
    )


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--sintetis", action="store_true", help="latih dari MNIST rangkaian")
    p.add_argument("--dari", type=str, help="folder simpanan contoh dari HP")
    p.add_argument("--epoch", type=int, default=8)
    p.add_argument("--jumlah", type=int, default=20000, help="contoh sintetis")
    p.add_argument("--keluar", type=str, default="keluaran")
    a = p.parse_args()

    # Tanpa ini keluarannya ke-buffer waktu dialirkan ke berkas/pipa, dan
    # latihan yang makan puluhan menit diam TOTAL sampai selesai — nggak ada
    # cara tahu dia belajar, mandek, atau bakal keburu dibunuh timeout.
    sys.stdout.reconfigure(line_buffering=True)

    if bool(a.sintetis) == bool(a.dari):
        p.error("pilih SALAH SATU: --sintetis atau --dari")

    if a.sintetis:
        asal = SumberSintetis.asal

        # Dua sumber terpisah, masing-masing dari belahan MNIST-nya sendiri —
        # bukan satu kumpulan yang dibelah 90/10. Lihat docblock SumberSintetis.
        latih = SumberSintetis(seed=7, bagian="latih").ambil(a.jumlah)
        uji = SumberSintetis(seed=99, bagian="uji").ambil(max(1, a.jumlah // 10))

        print(f"Data SINTETIS: {len(latih)} latih / {len(uji)} uji — BUKAN buat produksi.")
    else:
        sumber = SumberAsli(a.dari)
        contoh, lewat = sumber.muat()
        asal = sumber.asal
        print(f"Data ASLI: {len(contoh)} contoh. Dilewat: {lewat}")

        if not contoh:
            raise SystemExit("Nggak ada contoh yang bisa dipakai.")

        random.Random(7).shuffle(contoh)
        batas = max(1, int(len(contoh) * 0.9))
        latih, uji = contoh[:batas], contoh[batas:]

    inti = bangun_model()
    model = ModelCtc(inti)
    model.compile(optimizer=keras.optimizers.Adam(1e-3))

    cx, cl, cp = _siapkan(latih)
    ux, ul, up = _siapkan(uji)

    model.fit(
        tf.data.Dataset.from_tensor_slices((cx, (cl, cp))).batch(64),
        validation_data=tf.data.Dataset.from_tensor_slices((ux, (ul, up))).batch(64),
        epochs=a.epoch,
        verbose=2,
    )

    skor = nilai(inti, uji)
    print(f"\nSama persis di data uji: {skor['sama_persis']:.1%} dari {skor['jumlah']}")

    ekspor_tflite(inti, Path(a.keluar), asal, skor)
    print(f"Model ditulis ke {a.keluar}/ (asal_data={asal})")


if __name__ == "__main__":
    main()
