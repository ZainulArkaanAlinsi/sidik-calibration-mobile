---
name: sidik-fe-test-generator
description: Generate widget/unit test Flutter ala sidik-calibration-mobile — file flat di test/, nama deskriptif domain, MockService/ProviderScope override, angka acuan disalin dari sumber nyata (Excel master/kontrak API). Pakai saat user minta bikin test, nambah test coverage, atau sebelum bilang fitur FE selesai.
---

# Sidik FE Test Generator

Rekan `sidik-test-verifier` di backend, versi Flutter. Bedanya: di sini gak
ada gate MySQL — gate-nya "angka test harus disalin dari sumber nyata"
(workbook master lab / `docs/kontrak-api.md`), bukan dikarang biar hijau.

## Konvensi Struktur

- Test FLAT di `test/*_test.dart` — TIDAK ada subfolder `Feature`/`Unit`
  seperti backend Laravel. Nama file deskriptif domain, contoh:
  `certificate_desimal_per_titik_test.dart`,
  `equipment_resolusi_rentang_test.dart`.
- `group()` per skenario, `test()` per kasus — nama dalam Bahasa Indonesia,
  jelasin PERILAKU yang diuji bukan nama fungsi (`'titik resolusi halus
  tetap 2 desimal'`, bukan `'test desimalEfektif'`).
- Widget test yang butuh state Riverpod bungkus dengan `ProviderScope` +
  `overrides:` ke provider service versi `Mock*Service` — jangan panggil
  `ApiClient` asli di test.

## Sumber Angka Acuan — WAJIB, bukan opsional

Kalau test menguji kalkulasi/format tampil (desimal, satuan, U95%, dst),
angka `expect(...)` HARUS disalin dari sumber nyata, dan komentar di atas
`test()`/`group()` sebutkan sumbernya persis:
- Workbook master Excel lab (`Master Olah Data_<Alat>.xlsm`, sebut nomor
  job/sertifikat kalau ada, contoh `0189-CAL-624`).
- `docs/kontrak-api.md` untuk bentuk/nama field respons API.
- Sertifikat yang SUDAH TERBIT, kalau test soal "snapshot lama tidak boleh
  berubah" (lihat pola di `certificate_desimal_per_titik_test.dart`).

Angka yang "keliatan masuk akal" tapi gak disalin dari sumber itu DITOLAK —
itu justru pola yang bikin bug lolos (nilai matematis benar, tapi beda
bentuk dari yang dipegang pelanggan).

## Yang Wajib Dicover, Bukan Cuma Happy Path

- **Alat beda resolusi/satuan campur** — kalau nambah test buat fitur yang
  dipakai lintas alat (kalibrasi, sertifikat), sertakan minimal satu kasus
  alat dengan resolusi ganjil (Turbidimeter 0,01/0,1/1 tergantung rentang)
  dan satu kasus satuan campur (Conductivity) kalau relevan.
- **Snapshot lama vs data baru** — kalau field baru punya default/fallback
  (mis. `desimal` per titik null → pakai `desimal` sertifikat), test DUA
  jalur: yang ngirim field baru, dan yang belum (data lama).
- **Jalur gagal jaringan** — service test pakai `MockXxxService(gagal:
  true)` buat mastiin error dilempar rapi, bukan cuma jalur sukses.

## Format Output
- Nama file & lokasi (`test/<nama>_test.dart`)
- Sumber angka acuan (workbook/kontrak/sertifikat) disebut eksplisit
- Kasus: normal + edge (resolusi/satuan beda) + snapshot lama + gagal jaringan

## Guidelines
- Jangan generate test lalu berhenti — jalankan `flutter test` beneran,
  laporkan hasil aslinya, bukan asumsi hijau.
- Test golden angka boleh nunjuk `[[sidik-fe-presisi-sertifikat]]` kalau
  yang diuji soal preview vs bentuk cetak PDF.
