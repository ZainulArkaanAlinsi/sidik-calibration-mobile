/// Contoh data acuan Micrometer untuk `MockDataAcuanService`.
///
/// **Dicetak mesin dari kode server, BUKAN diketik tangan** (9 Okt 2026, worktree
/// API `feat/studio-data-acuan`):
///
///  - [contohIsiMicrometerV1] = `json_decode(JsonKanonik::dariTeks(
///    database/data/tabel-standar-micrometer.json))` di-encode ulang dengan
///    `JSON_PRESERVE_ZERO_FRACTION` — persis `isi` yang dikirim
///    `GET /data-acuan/versi/{id}` untuk versi 1 hasil `acuan:impor-awal`.
///    Kunci terurut kanonik; `20.0` tetap `20.0`, `200` tetap `200`.
///  - [contohSha256MicrometerV1] = `JsonKanonik::sha256` atas isi yang sama
///    (kontrak §15: `ba1fa153…f585`). Kanonik ulang isi di atas memberi hash
///    yang sama — dicek waktu dicetak.
///  - [contohSkemaMicrometer] = `MicrometerProfile::skemaAcuan()`.
///
/// Disimpan sebagai TEKS JSON lalu di-`jsonDecode`, bukan literal `Map` Dart:
/// begitu mock memakai literal, tipe angka ikut aturan inferensi Dart (bukan
/// aturan JSON) dan mock berhenti meniru apa yang benar-benar diterima HP.
///
/// Kalau tabel di server berubah, cetak ulang dari sana — jangan sunting
/// angkanya di sini.
library;

const contohSha256MicrometerV1 =
    'ba1fa153808d125a2ff1e54ca3589e25c723b59ccb23a68df7372862ef56f585';

const contohIsiMicrometerV1 = r'''
{
  "_digenerate_oleh": "docs/skrip/gen-tabel-standar-micrometer.py",
  "_sumber": "Master_Olah_Data_Micrometer_{025,2550,5075,75100}mm.xlsm (sheet Standar_GB & DATABASE) — keempat workbook memuat tabel balok ukur yang IDENTIK, sudah diadu oleh skrip generator ini.",
  "balok_ukur": {
    "1.0": 1.00011,
    "1.1": 1.09989,
    "1.2": 1.20012,
    "1.3": 1.30009,
    "1.5": 1.49996,
    "1.6": 1.5999,
    "1.7": 1.70013,
    "1.8": 1.80011,
    "1.9": 1.90009,
    "100.0": 100.00012,
    "101.6": 101.60026,
    "11.0": 11.00014,
    "13.0": 13.00014,
    "14.0": 14.00009,
    "16.0": 16.0001,
    "17.0": 16.99988,
    "19.0": 19.00011,
    "2.5": 2.50014,
    "200.0": 200.00017,
    "21.0": 20.99987,
    "40.0": 40.00014,
    "5.0": 5.00009,
    "50.0": 49.9999,
    "6.0": 6.00016,
    "60.0": 60.00012,
    "7.5": 7.49989,
    "70.0": 69.99991,
    "75.0": 74.9999,
    "76.2": 76.2002,
    "80.0": 80.00013,
    "9.0": 8.99991,
    "90.0": 90.00015
  },
  "cmc": [
    {
      "balok_pra_evaluasi_mm": [
        20.0,
        5.0
      ],
      "judul_rentang": "0-25 mm",
      "kapasitas_maks_mm": 25.0,
      "kapasitas_min_mm": 0.0,
      "kode": "A",
      "kode_dokumen": "SIDIK-FM-CAL-0522.A_Rev.1",
      "label": "CMC 0-25mm",
      "titik": [
        {
          "nominal_cetak_mm": 0.0,
          "tumpukan_mm": []
        },
        {
          "nominal_cetak_mm": 2.5,
          "tumpukan_mm": [
            2.5
          ]
        },
        {
          "nominal_cetak_mm": 5.1,
          "tumpukan_mm": [
            1.1,
            2.5,
            1.5
          ]
        },
        {
          "nominal_cetak_mm": 7.7,
          "tumpukan_mm": [
            1.7,
            6.0
          ]
        },
        {
          "nominal_cetak_mm": 10.3,
          "tumpukan_mm": [
            2.5,
            1.8,
            6.0
          ]
        },
        {
          "nominal_cetak_mm": 12.9,
          "tumpukan_mm": [
            1.9,
            11.0
          ]
        },
        {
          "nominal_cetak_mm": 15.0,
          "tumpukan_mm": [
            6.0,
            9.0
          ]
        },
        {
          "nominal_cetak_mm": 17.6,
          "tumpukan_mm": [
            1.6,
            16.0
          ]
        },
        {
          "nominal_cetak_mm": 20.2,
          "tumpukan_mm": [
            1.2,
            19.0
          ]
        },
        {
          "nominal_cetak_mm": 22.8,
          "tumpukan_mm": [
            1.8,
            21.0
          ]
        },
        {
          "nominal_cetak_mm": 25.0,
          "tumpukan_mm": [
            6.0,
            19.0
          ]
        }
      ],
      "u95_um": 0.83
    },
    {
      "balok_pra_evaluasi_mm": [
        50.0
      ],
      "judul_rentang": "25-50 mm",
      "kapasitas_maks_mm": 50.0,
      "kapasitas_min_mm": 25.0,
      "kode": "B",
      "kode_dokumen": "SIDIK-FM-CAL-0522.B_Rev.1",
      "label": "CMC 25-50mm",
      "titik": [
        {
          "nominal_cetak_mm": 25.0,
          "tumpukan_mm": [
            6.0,
            19.0
          ]
        },
        {
          "nominal_cetak_mm": 27.5,
          "tumpukan_mm": [
            2.5,
            6.0,
            19.0
          ]
        },
        {
          "nominal_cetak_mm": 31.0,
          "tumpukan_mm": [
            14.0,
            17.0
          ]
        },
        {
          "nominal_cetak_mm": 32.7,
          "tumpukan_mm": [
            1.8,
            16.0,
            1.9,
            13.0
          ]
        },
        {
          "nominal_cetak_mm": 35.3,
          "tumpukan_mm": [
            1.3,
            13.0,
            21.0
          ]
        },
        {
          "nominal_cetak_mm": 37.9,
          "tumpukan_mm": [
            1.3,
            19.0,
            1.6,
            16.0
          ]
        },
        {
          "nominal_cetak_mm": 40.0,
          "tumpukan_mm": [
            40.0
          ]
        },
        {
          "nominal_cetak_mm": 42.6,
          "tumpukan_mm": [
            1.1,
            21.0,
            1.5,
            19.0
          ]
        },
        {
          "nominal_cetak_mm": 45.2,
          "tumpukan_mm": [
            1.1,
            40.0,
            1.6,
            2.5
          ]
        },
        {
          "nominal_cetak_mm": 47.8,
          "tumpukan_mm": [
            1.8,
            6.0,
            40.0
          ]
        },
        {
          "nominal_cetak_mm": 50.0,
          "tumpukan_mm": [
            50.0
          ]
        }
      ],
      "u95_um": 0.87
    },
    {
      "balok_pra_evaluasi_mm": [
        75.0
      ],
      "judul_rentang": "50-75 mm",
      "kapasitas_maks_mm": 75.0,
      "kapasitas_min_mm": 50.0,
      "kode": "C",
      "kode_dokumen": "SIDIK-FM-CAL-0522.C_Rev.1",
      "label": "CMC 50-75mm",
      "titik": [
        {
          "nominal_cetak_mm": 50.0,
          "tumpukan_mm": [
            50.0
          ]
        },
        {
          "nominal_cetak_mm": 52.5,
          "tumpukan_mm": [
            2.5,
            50.0
          ]
        },
        {
          "nominal_cetak_mm": 51.0,
          "tumpukan_mm": [
            1.5,
            6.0,
            1.6,
            40.0,
            1.9
          ]
        },
        {
          "nominal_cetak_mm": 57.7,
          "tumpukan_mm": [
            1.7,
            6.0,
            50.0
          ]
        },
        {
          "nominal_cetak_mm": 60.3,
          "tumpukan_mm": [
            1.3,
            9.0,
            50.0
          ]
        },
        {
          "nominal_cetak_mm": 62.9,
          "tumpukan_mm": [
            1.7,
            7.5,
            1.8,
            50.0,
            1.9
          ]
        },
        {
          "nominal_cetak_mm": 65.0,
          "tumpukan_mm": [
            1.1,
            11.0,
            1.2,
            50.0,
            1.7
          ]
        },
        {
          "nominal_cetak_mm": 67.6,
          "tumpukan_mm": [
            1.5,
            2.5,
            1.7,
            60.0,
            1.9
          ]
        },
        {
          "nominal_cetak_mm": 70.2,
          "tumpukan_mm": [
            1.2,
            60.0,
            1.5,
            7.5
          ]
        },
        {
          "nominal_cetak_mm": 72.8,
          "tumpukan_mm": [
            1.2,
            1.6,
            70.0
          ]
        },
        {
          "nominal_cetak_mm": 75.0,
          "tumpukan_mm": [
            75.0
          ]
        }
      ],
      "u95_um": 0.91
    },
    {
      "balok_pra_evaluasi_mm": [
        100.0
      ],
      "judul_rentang": "75-100 mm",
      "kapasitas_maks_mm": 100.0,
      "kapasitas_min_mm": 75.0,
      "kode": "D",
      "kode_dokumen": "SIDIK-FM-CAL-0522.D_Rev.1",
      "label": "CMC 75-100mm",
      "titik": [
        {
          "nominal_cetak_mm": 75.0,
          "tumpukan_mm": [
            75.0
          ]
        },
        {
          "nominal_cetak_mm": 77.5,
          "tumpukan_mm": [
            7.5,
            70.0
          ]
        },
        {
          "nominal_cetak_mm": 80.1,
          "tumpukan_mm": [
            1.1,
            9.0,
            70.0
          ]
        },
        {
          "nominal_cetak_mm": 82.7,
          "tumpukan_mm": [
            1.8,
            70.0,
            1.9,
            9.0
          ]
        },
        {
          "nominal_cetak_mm": 85.3,
          "tumpukan_mm": [
            1.3,
            80.0,
            1.5,
            2.5
          ]
        },
        {
          "nominal_cetak_mm": 87.9,
          "tumpukan_mm": [
            1.7,
            2.5,
            1.8,
            80.0,
            1.9
          ]
        },
        {
          "nominal_cetak_mm": 90.0,
          "tumpukan_mm": [
            90.0
          ]
        },
        {
          "nominal_cetak_mm": 92.6,
          "tumpukan_mm": [
            1.1,
            1.5,
            90.0
          ]
        },
        {
          "nominal_cetak_mm": 95.2,
          "tumpukan_mm": [
            1.2,
            90.0,
            1.5,
            2.5
          ]
        },
        {
          "nominal_cetak_mm": 97.8,
          "tumpukan_mm": [
            1.6,
            2.5,
            1.8,
            90.0,
            1.9
          ]
        },
        {
          "nominal_cetak_mm": 100.0,
          "tumpukan_mm": [
            100.0
          ]
        }
      ],
      "u95_um": 0.91
    }
  ],
  "ketidakpastian_balok_um": {
    "aturan": [
      {
        "maks": 10.0,
        "u": 0.12
      },
      {
        "maks": 21.0,
        "u": 0.14
      },
      {
        "maks": 50.0,
        "u": 0.25
      },
      {
        "maks": 100.0,
        "u": 0.26
      }
    ],
    "lainnya": 0.0,
    "persis": {
      "101.6": 0.26,
      "200": 0.73
    }
  },
  "konstanta": {
    "delta_alpha_per_c": 1.0e-5,
    "drift_a_um": 0.02,
    "drift_b_um_per_mm": 0.00025,
    "geometri_um": 0.5,
    "suhu_acuan_c": 20.0,
    "vi_type_b": 200,
    "wringing_um": 0.111803398875
  },
  "standar": {
    "merk_tipe": "Metrology/GB-9122-0",
    "nama": "Gauge Block Standard",
    "seri": "160006",
    "tanggal_kalibrasi": "2024-01-24",
    "traceability": "LK-410-IDN"
  }
}
''';

const contohSkemaMicrometer = r'''
{
  "skema_versi": 1,
  "sumber_json": "tabel-standar-micrometer.json",
  "lembar": [
    {
      "kode": "standar",
      "label": "Identitas standar balok ukur",
      "jalur": "standar",
      "jenis": "objek",
      "kunci": null,
      "kolom": [
        {
          "kode": "nama",
          "label": "Nama",
          "tipe": "teks",
          "satuan": null,
          "asal": "DATABASE!S13",
          "perlu_konfirmasi": false
        },
        {
          "kode": "merk_tipe",
          "label": "Merk/tipe",
          "tipe": "teks",
          "satuan": null,
          "asal": "DATABASE!T13",
          "perlu_konfirmasi": false
        },
        {
          "kode": "seri",
          "label": "Nomor seri",
          "tipe": "teks",
          "satuan": null,
          "asal": "DATABASE!U13",
          "perlu_konfirmasi": false
        },
        {
          "kode": "traceability",
          "label": "Ketertelusuran",
          "tipe": "teks",
          "satuan": null,
          "asal": "DATABASE!V13",
          "perlu_konfirmasi": false
        },
        {
          "kode": "tanggal_kalibrasi",
          "label": "Tanggal kalibrasi standar",
          "tipe": "tanggal",
          "satuan": null,
          "asal": "DATABASE!W13",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "balok_ukur",
      "label": "Balok ukur — nilai terkoreksi",
      "jalur": "balok_ukur",
      "jenis": "baris",
      "kunci": "nominal_mm",
      "kolom": [
        {
          "kode": "nominal_mm",
          "label": "Nominal",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": "Standar_GB!Q10:Q132",
          "perlu_konfirmasi": false
        },
        {
          "kode": "nilai_terkoreksi_mm",
          "label": "Nilai terkoreksi",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": "Standar_GB!R10:R132",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": true
    },
    {
      "kode": "ketidakpastian_balok_tangga",
      "label": "Ketidakpastian balok ukur — tangga nominal",
      "jalur": "ketidakpastian_balok_um/aturan",
      "jenis": "daftar",
      "kunci": null,
      "kolom": [
        {
          "kode": "maks",
          "label": "Nominal maksimum",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": "PERHITUNGAN!H23",
          "perlu_konfirmasi": false
        },
        {
          "kode": "u",
          "label": "Ketidakpastian",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": "PERHITUNGAN!H23",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "ketidakpastian_balok_khusus",
      "label": "Ketidakpastian balok ukur — nominal khusus",
      "jalur": "ketidakpastian_balok_um/persis",
      "jenis": "baris",
      "kunci": "nominal_mm",
      "kolom": [
        {
          "kode": "nominal_mm",
          "label": "Nominal",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": "PERHITUNGAN!H23",
          "perlu_konfirmasi": false
        },
        {
          "kode": "u_um",
          "label": "Ketidakpastian",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": "PERHITUNGAN!H23",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "ketidakpastian_balok_lainnya",
      "label": "Ketidakpastian balok ukur — di luar tangga",
      "jalur": "ketidakpastian_balok_um",
      "jenis": "objek",
      "kunci": null,
      "kolom": [
        {
          "kode": "lainnya",
          "label": "Nominal di luar tangga & daftar khusus",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": "PERHITUNGAN!H23",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "pita_cmc",
      "label": "Pita CMC & varian kertas",
      "jalur": "cmc",
      "jenis": "daftar",
      "kunci": "kode",
      "kolom": [
        {
          "kode": "kode",
          "label": "Kode varian",
          "tipe": "teks",
          "satuan": null,
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "label",
          "label": "Label pita",
          "tipe": "teks",
          "satuan": null,
          "asal": "DATABASE!S5:S8",
          "perlu_konfirmasi": false
        },
        {
          "kode": "kode_dokumen",
          "label": "Nomor formulir",
          "tipe": "teks",
          "satuan": null,
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "judul_rentang",
          "label": "Judul rentang",
          "tipe": "teks",
          "satuan": null,
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "kapasitas_min_mm",
          "label": "Kapasitas minimum",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "kapasitas_maks_mm",
          "label": "Kapasitas maksimum",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": "INPUT DATA!F5",
          "perlu_konfirmasi": false
        },
        {
          "kode": "u95_um",
          "label": "CMC (U95)",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": "DATABASE!T5:T8",
          "perlu_konfirmasi": false
        },
        {
          "kode": "balok_pra_evaluasi_mm",
          "label": "Balok ukur pra-evaluasi",
          "tipe": "daftar_angka",
          "satuan": "mm",
          "asal": "PERHITUNGAN!H22:M22",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "titik_pra_cetak",
      "label": "Titik pra-cetak kertas",
      "jalur": "cmc/*/titik",
      "jenis": "daftar",
      "kunci": null,
      "kolom": [
        {
          "kode": "nominal_cetak_mm",
          "label": "Nominal cetak",
          "tipe": "desimal",
          "satuan": "mm",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "tumpukan_mm",
          "label": "Tumpukan keping",
          "tipe": "daftar_angka",
          "satuan": "mm",
          "asal": "PERHITUNGAN!C31:E63",
          "perlu_konfirmasi": false
        }
      ],
      "boleh_tambah_baris": false
    },
    {
      "kode": "konstanta",
      "label": "Konstanta metode",
      "jalur": "konstanta",
      "jenis": "objek",
      "kunci": null,
      "kolom": [
        {
          "kode": "delta_alpha_per_c",
          "label": "Δα koefisien muai",
          "tipe": "desimal",
          "satuan": "/°C",
          "asal": null,
          "perlu_konfirmasi": true
        },
        {
          "kode": "wringing_um",
          "label": "Lapisan wringing",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "geometri_um",
          "label": "Kesalahan geometri",
          "tipe": "desimal",
          "satuan": "µm",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "drift_a_um",
          "label": "Drift — suku tetap",
          "tipe": "desimal",
          "satuan": "µm/tahun",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "drift_b_um_per_mm",
          "label": "Drift — suku per panjang",
          "tipe": "desimal",
          "satuan": "µm/(mm·tahun)",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "suhu_acuan_c",
          "label": "Suhu acuan",
          "tipe": "desimal",
          "satuan": "°C",
          "asal": null,
          "perlu_konfirmasi": false
        },
        {
          "kode": "vi_type_b",
          "label": "Derajat kebebasan Type B",
          "tipe": "bulat",
          "satuan": null,
          "asal": null,
          "perlu_konfirmasi": true
        }
      ],
      "boleh_tambah_baris": false
    }
  ]
}
''';
