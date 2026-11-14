# POLA — cara menyusun layar yang belum punya artboard

46 berkas berstatus POLA (lihat `PETA-LAYAR.md`). Susun ulang dengan pola di
bawah, memakai komponen dan token yang sama. Jangan mengarang bentuk baru.

## Kerangka layar
- Latar `latar` #F3F7FB, margin 16, jarak antar-blok 12, antar-bagian 24.
- **Kepala tab** (layar dari dock): logo 30 × 42 + "SIDIK Lab" 16/800 + peran 12,
  lonceng 48 putih (lencana koral), tombol menu 48 navy (admin/super admin).
- **Kepala anak** (layar yang di-push): tombol kembali bulat 48 putih + judul
  20/26·800 + opsional nomor mono 12 di bawahnya + opsional satu aksi kanan
  (tombol bulat 48 primer untuk "tambah", atau tombol pil 44).
- Dock hanya di layar tab. Layar anak tanpa dock.
- Isi bergulir; tombol utama layar menempel di bawah (padding bawah 16 + tepi sistem).

## Daftar (contoh: M2 Standar acuan)
Kolom cari 56 → chip saring 44 (jumlah di bulatan 32) → banner bila ada
peringatan → kartu 24 radius, min 72–104 tinggi: ubin visual/ikon 48–56 kabut,
judul 16/800, nomor mono 12, keterangan 13, stempel di kanan HANYA untuk
pengecualian (lewat jadwal, segera habis, FAIL, belum dibuka). Daftar padat
(>20 baris) memakai panel putih dengan baris 72 dan pemisah, bukan kartu
terpisah. Tambah = tombol bulat 48 primer di kepala.

## Formulir (contoh: M3 Buat akun teknisi)
Kalimat penjelas 14 → satu kartu putih radius 28 padding 18 berisi isian 56
(label di atas 14/700) → pilihan 2–3 opsi = segmen pil → isian yang tidak bisa
diubah = keadaan mati. Bawah: Batal (sekunder) + aksi (primer, 2× lebih lebar).
Galat ditampilkan di isian yang salah + toast galat hanya untuk galat server.

## Detail (contoh: A5 Periksa sesi)
Kartu identitas putih radius 28 dengan lingkaran kabut + visual alat →
pil fakta (kabut) → blok isi (panel) → temuan/riwayat → bilah aksi menempel di
bawah: sekunder kiri, bahaya, primer penuh di bawahnya.

## Riwayat (contoh: M5 Riwayat perubahan)
Garis waktu: simpul 12 primer, garis 2 `garis`; waktu 12 tinta2 → kalimat 15
dengan pelaku tebal → diff: lama (koral tipis, coret) → baru (hijau).

## Ringkasan angka (contoh: A1)
Hero langit dengan satu angka 56/800 + satu tombol navy; ubin KPI 2 kolom
(min 112, radius 24, angka 36/800); grafik batang radius 10, hari ini primer.

## Kosong, galat, memuat
Lihat `ELEMEN.md`. Setiap daftar wajib punya keempat keadaan: memuat, kosong,
galat, tanpa koneksi (data terakhir tetap tampil + banner).

## Bahasa tampilan (app Lab)
Ikuti `lib/l10n/app_id.arb` yang ada (nada santai: "kamu", "nggak"). Jangan
menulis teks baru langsung di widget: tambahkan kunci l10n. Istilah status tetap
dari pemetaan yang ada ("Menunggu approval", "Tidak memenuhi toleransi").
