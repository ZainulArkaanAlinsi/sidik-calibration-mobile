# PETA LAYAR — app Lab (`sidik-calibration-mobile`)

Setiap berkas di `lib/screens/` beserta perlakuannya. Hasil bedah repo 14 Nov 2026.

| Status | Arti | Jumlah |
|---|---|---|
| DESAIN | Ada artboard sendiri; ikuti `LAYAR.md` + `referensi-html/` persis | 27 |
| POLA | Belum ada artboard; susun ulang mengikuti pola di `POLA.md` | 46 |
| TOKEN | Tata letak tetap; hanya warna/huruf/komponen bersama berganti lewat token | 9 |
| BEKU | Tidak boleh berubah sepiksel pun; lihat `BEKU.md` | 19 |
| GANTI / PENSIUN / LOGIKA | lihat keterangan | 4 |

Widget bersama di `lib/widgets/` yang penting:

| Berkas | Perlakuan |
|---|---|
| `floating_nav_bar.dart` | DESAIN dock (01, A1) |
| `app_button.dart`, `app_text_field.dart`, `sidik_loader.dart`, `status_badge.dart` | BEKU (dipakai lembar kerja). Gaya baru dibuat sebagai komponen BARU; layar lain pindah ke komponen baru |
| `scene3d/*`, `sakelar_tema.dart` | BEKU (keputusan pemilik: 3D dan sakelar matahari/bulan tetap) |
| `sertifikat_pdf_view.dart` | BEKU (cermin PDF) |
| `glass_surface.dart`, `liquid_glass.dart`, `kartu_gradien.dart`, `panorama_kartu.dart` | PENSIUN dari layar yang didesain ulang (melanggar "tanpa gradien/kaca"); hapus bila sudah tidak dipakai |
| `stat_card.dart`, `work_chart.dart`, `technician_pulse_panel.dart` | DESAIN ulang mengikuti A1 (ubin KPI, grafik batang) |
| `lapisan_kabar_masuk.dart` | DESAIN: kabar masuk memakai ToastSidik varian navy (E2) |
| `banner_update.dart`, `kabar_server_lambat.dart`, `banner_status_standar.dart`, `dialog_update.dart` | POLA banner/dialog (E2) |
| `skeleton.dart` | POLA keadaan memuat (E2), JANGAN ubah berkasnya bila dipakai lembar kerja: buat yang baru |

## Per berkas

| Berkas | Status | Rujukan |
|---|---|---|
| `admin/antrean_approval_screen.dart` | **DESAIN** | A4 Antrean approval |
| `admin/bandingkan_screen.dart` | **TOKEN** | tabel banding tetap, ganti kepala layar + tombol |
| `admin/import_excel_screen.dart` | **POLA** | Formulir (unggah berkas) + keadaan |
| `admin/perhitungan_screen.dart` | **DESAIN** | A5 Periksa sesi: bingkai, identitas, temuan, bilah aksi |
| `admin/widgets/blok_kondisi.dart` | **DESAIN** | A5: pil kondisi lingkungan |
| `admin/widgets/data_administrasi.dart` | **DESAIN** | A5: kartu identitas + visual alat |
| `admin/widgets/dialog_setujui.dart` | **POLA** | Dialog konfirmasi (E2) |
| `admin/widgets/panel_temuan.dart` | **DESAIN** | A5: daftar temuan dengan stempel |
| `admin/widgets/tabel_perhitungan.dart` | **BEKU** | cermin sheet PERHITUNGAN Master Olah Data |
| `alur/alur_kerja_screen.dart` | **DESAIN** | A6 Alur kerja |
| `arsip/arsip_screen.dart` | **POLA** | Daftar (folder = kartu dengan ikon folder) |
| `arsip/garis_waktu_arsip_screen.dart` | **POLA** | Riwayat (garis waktu M5) |
| `arsip/widgets/kartu_arsip.dart` | **POLA** | Daftar |
| `audit/audit_log_screen.dart` | **DESAIN** | M5 Riwayat perubahan |
| `auth/auth_gate.dart` | **TOKEN** | tanpa tampilan sendiri |
| `auth/forgot_password_screen.dart` | **POLA** | Formulir, kepala seperti E0 Masuk |
| `auth/login_screen.dart` | **DESAIN** | E0 Masuk |
| `auth/onboarding_screen.dart` | **BEKU** | onboarding 3D (keputusan pemilik) |
| `auth/splash_screen.dart` | **DESAIN** | E1 Splash (timeline sekali jalan tetap) |
| `auth/widgets/auth_brand_header.dart` | **DESAIN** | E0: hero langit + logo |
| `auth/widgets/neu.dart` | **PENSIUN** | gaya Meja Kerja Lab lama; layar yang didesain ulang berhenti memakainya, berkas dihapus di langkah bersih-bersih bila tak dipakai lagi |
| `calibration/calibration_input_screen.dart` | **BEKU** | lembar kerja: langkah data alat |
| `calibration/category_picker_screen.dart` | **DESAIN** | 02 Pilih alat (chip kelompok) |
| `calibration/foto_review_screen.dart` | **DESAIN** | 04 Cek hasil pindai |
| `calibration/grid_sensor_state.dart` | **BEKU** | lembar kerja |
| `calibration/instrument_picker_screen.dart` | **DESAIN** | 02 Pilih alat (grid ubin) |
| `calibration/kamera_pindai_screen.dart` | **TOKEN** | jendela kamera tetap; tombol dan teks ikut token |
| `calibration/kinerja_lembar.dart` | **BEKU** | lembar kerja |
| `calibration/lembar_kerja_screen.dart` | **BEKU** | lembar kerja (hanya boleh dibungkus TemaBeku di akar) |
| `calibration/lembar_kerja_state.dart` | **BEKU** | lembar kerja |
| `calibration/penjaga_draf_lokal.dart` | **LOGIKA** | tidak ada tampilan |
| `calibration/peta_kolom_screen.dart` | **TOKEN** | alat bantu pindai |
| `calibration/pindai_formulir_asli_flow.dart` | **TOKEN** | alur pindai |
| `calibration/ringkasan_sebelum_kirim.dart` | **LOGIKA** | gerbang ButirRingkasan, jangan diubah |
| `calibration/skema_dinamis_screen.dart` | **BEKU** | lembar kerja |
| `calibration/temperatur_indikator_gerbang_screen.dart` | **BEKU** | lembar kerja |
| `calibration/titik_sesi_state.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/dropdown_gagal.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/keypad_angka.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/lembar_kerja_grid.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/lembar_kerja_kartu_baris.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/lembar_kerja_matriks.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/lembar_kerja_tabel.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/pengatur_titik.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/pengatur_titik_sesi.dart` | **BEKU** | lembar kerja |
| `calibration/widgets/ringkasan_sebelum_kirim_dialog.dart` | **DESAIN** | 05 Ringkasan sebelum kirim |
| `calibration/widgets/tanda_lompat.dart` | **BEKU** | lembar kerja |
| `certificate/batal_sertifikat_dialog.dart` | **POLA** | Dialog bahaya (E2) |
| `certificate/info_dokumen_sertifikat.dart` | **POLA** | Detail |
| `certificate/revisi_sertifikat_screen.dart` | **POLA** | Formulir |
| `certificate/sertifikat_screen.dart` | **POLA** | Detail; area pratinjau PDF BEKU (cermin PDF) |
| `certificate/sertifikat_sukses_sheet.dart` | **POLA** | Lembar bawah sukses (E2) |
| `certificate/tarik_sertifikat_dialog.dart` | **POLA** | Dialog bahaya (E2) |
| `dashboard/beranda_super_admin.dart` | **DESAIN** | A2 Beranda super admin |
| `dashboard/dashboard_screen.dart` | **DESAIN** | A1 Beranda admin; viewer = versi tanpa aksi |
| `dashboard/device_overview_screen.dart` | **POLA** | Daftar (visual alat) |
| `dashboard/ringkasan_screen.dart` | **POLA** | KPI + grafik dari A1 |
| `data_acuan/alur_versi_acuan_screen.dart` | **DESAIN** | M4 Versi data acuan |
| `data_acuan/banding_acuan_screen.dart` | **TOKEN** | tabel banding tetap |
| `data_acuan/daftar_paket_acuan_screen.dart` | **POLA** | Daftar |
| `data_acuan/garis_waktu_acuan_screen.dart` | **POLA** | Riwayat (M5) |
| `data_acuan/paket_alur_acuan_screen.dart` | **DESAIN** | M4 (daftar paket = kartu versi aktif) |
| `data_acuan/riwayat_sel_acuan_screen.dart` | **POLA** | Riwayat (M5, dengan diff lama → baru) |
| `data_acuan/simulasi_versi_acuan_screen.dart` | **POLA** | Detail + temuan seperti A5 |
| `data_acuan/studio_acuan_screen.dart` | **TOKEN** | grid gaya Studio tetap |
| `data_acuan/widgets/grid_acuan.dart` | **TOKEN** | grid |
| `data_acuan/widgets/hak_alur_acuan.dart` | **POLA** | Banner info (E2) |
| `data_acuan/widgets/keadaan_acuan.dart` | **POLA** | Keadaan kosong/galat (E2) |
| `design_system/design_system_screen.dart` | **GANTI** | jadi galeri komponen Biru Awan (khusus pengembang) |
| `draf/draf_screen.dart` | **POLA** | Daftar dengan kartu draf dari 01 |
| `equipment/equipment_form_screen.dart` | **POLA** | Formulir |
| `equipment/equipment_list_screen.dart` | **POLA** | Daftar dengan visual alat |
| `equipment/pelanggan_baru_screen.dart` | **POLA** | Formulir |
| `history/calibration_detail_screen.dart` | **POLA** | Detail; hasil per titik memakai kartu 05 |
| `history/certificate_screen.dart` | **POLA** | Detail; pratinjau PDF BEKU |
| `history/history_screen.dart` | **POLA** | Daftar dengan baris terkirim dari 01 |
| `history/kirim_email_screen.dart` | **POLA** | Formulir |
| `history/widgets/riwayat_persetujuan_card.dart` | **POLA** | Riwayat |
| `jatuh_tempo/dialog_ubah_jatuh_tempo.dart` | **POLA** | Lembar bawah (A8) |
| `jatuh_tempo/layar_jatuh_tempo.dart` | **DESAIN** | A8 Jadwal kalibrasi ulang |
| `notification/notification_screen.dart` | **POLA** | Daftar (baris 72, titik belum dibaca) |
| `pelacakan/pelacakan_screen.dart` | **POLA** | Daftar + jejak tahap |
| `pelacakan/telusuri_sertifikat_screen.dart` | **POLA** | Cari + Detail |
| `penugasan/penugasan_buat_screen.dart` | **POLA** | Formulir |
| `penugasan/penugasan_screen.dart` | **DESAIN** | A7 Penugasan |
| `profile/profile_screen.dart` | **DESAIN** | 06 Profil |
| `settings/buat_teknisi_screen.dart` | **DESAIN** | M3 Formulir buat akun teknisi |
| `settings/customer_form_screen.dart` | **POLA** | Formulir |
| `settings/customer_list_screen.dart` | **POLA** | Daftar (M2) |
| `settings/kelola_lab_screen.dart` | **DESAIN** | M1 Kelola lab |
| `settings/logo_organisasi_screen.dart` | **POLA** | Formulir (unggah gambar) |
| `settings/metode_list_screen.dart` | **POLA** | Daftar (M2) |
| `settings/organization_screen.dart` | **POLA** | Formulir |
| `settings/ruangan_list_screen.dart` | **POLA** | Daftar (M2) |
| `settings/rumus_list_screen.dart` | **POLA** | Daftar (M2) |
| `settings/rumus_versi_screen.dart` | **POLA** | Versi seperti M4 |
| `settings/standard_form_screen.dart` | **POLA** | Formulir |
| `settings/standard_list_screen.dart` | **DESAIN** | M2 Standar acuan |
| `settings/tanda_tangan_screen.dart` | **POLA** | Formulir; kanvas tanda tangan TOKEN |
| `settings/technician_list_screen.dart` | **POLA** | Daftar (M2, avatar ganti visual) |
| `settings/ukur_ocr_screen.dart` | **TOKEN** | alat pengembang |
| `settings/undang_anggota_dialog.dart` | **POLA** | Lembar bawah formulir |
| `shell/desktop_shell.dart` | **DESAIN** | D1 Layar lebar |
| `shell/main_shell.dart` | **DESAIN** | dock (01, A1) + laci menu A3 |
| `teknisi/kalibrasi_teknisi_screen.dart` | **DESAIN** | 01 Kalibrasi |
