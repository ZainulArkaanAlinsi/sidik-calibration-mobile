# 📊 Daily Report — 2026-07-16

**Proyek:** PT Sidik Calibration Mobile (`asmo_mobile`)
**Branch:** `feature/auth-titanium-i18n` → PR [#17](https://github.com/ZainulArkaanAlinsi/sidik-calibration-mobile/pull/17) (base: `develop`)
**Engineer:** Zainul Arkaan

---

## 📈 Metrik Hari Ini

| Metrik | Nilai |
|---|---|
| Commit | 9 |
| File berubah | 50 (9 baru, 41 modifikasi, 0 hapus) |
| Baris | **+3.747 / −868** |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **67 test hijau** (termasuk golden) |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` |

---

## 1. Executive Summary
Fokus penuh di **polish UI/UX mobile + fondasi produk**. Arah desain auth dikunci ke **neumorphism gelap** (revert dari eksperimen Titanium), lalu dirapikan sampai layak produksi: performa diringankan, bug visual dibereskan, dan dua fitur yang tadinya "cuma tampilan" — **reset password** dan **foto profil** — dibikin **fungsional beneran**. Ditutup validasi menyeluruh sampai **build APK Android sukses**. Semua sudah ter-commit & ter-push ke PR #17.

## 2. Features Completed
- **Splash screen** neumorphism senada Login (logo, brand, tagline, loading ring, footer akreditasi).
- **Floating navbar** — pill mengambang + lingkaran aktif naik & geser beranimasi antar tab.
- **Logo resmi PT Sidik** di badge auth, gaya "app-icon" squircle + aksen biru brand.
- **Reset password fungsional** 3 langkah (verif email → set password → selesai); mock ganti password per-akun beneran.
- **Foto profil dari HP** (`image_picker` galeri/kamera) + sheet pilih/hapus, path dipersist per-perangkat.
- **Profile redesign** — header hero banner + avatar overlap + kartu "Info Akun" (acuan gambar #2 & #3).
- **i18n dwibahasa ID/EN** diperluas ke luar auth: dashboard, navbar, tab Alat/Riwayat/Notifikasi.

## 3. Bugs Fixed
- **Navbar overflow 2px + label kepotong** ("Dashboar"/"Notificatio") → tinggi dihitung pas + `FittedBox(scaleDown)`.
- **Border hitam saat field difokus** → `focusedBorder` tema Titanium bocor lewat `InputDecoration.collapsed`; dipaksa `InputBorder.none` semua state.
- **UI berat / nge-lag** → `NeuInset` pakai `MaskFilter.blur` (saveLayer tiap re-paint) diganti gradasi+garis tipis.
- **4 test navbar gagal** → viewport lebih pendek bikin item Profil di luar build-range; helper scroll ditarget ke `Scrollable` ProfileScreen + `ensureVisible`.
- **Test hang 10 menit** → `await setLocale()` nyangkut di `SharedPreferences.getInstance()`; di-mock + pump terbatas.

## 4. Refactoring
- Toolkit `neu.dart` dioptimasi (buang `CustomPaint`+`MaskFilter`, badge jadi variant icon/logo).
- Mock auth: dari 1 password global → **password per-akun** (login/register/reset konsisten).
- `AuthService` interface diperluas (`resetPassword`) + implementasi Mock & Api sejalan.
- Profile didekomposisi jadi widget kecil reusable (`_Header`, `_Avatar`, `_Kartu`, `_BarisInfo`, `_BarisMenu`).
- Test helper diseragamkan (`_scrollProfilKe` / `_tapDiProfil`).

## 5. Documentation
- PR #17 judul + body ditulis ulang sesuai arah final (neumorphism + i18n + logo + navbar).
- Memory notes diupdate (keputusan desain, gotcha test, catatan platform image_picker).
- Komentar kode padat di titik non-obvious.
- Report harian ini (`DAILY_REPORT.md`) + `worklog.csv`.

## 6. Remaining Tasks
- **i18n gelombang 2**: Design System screen, dialog/snackbar sisa, label model (`role.label`, departemen) masih hardcode.
- **Backend nyata**: endpoint `/reset-password`, upload avatar ke server (sekarang lokal per-perangkat).
- **Fitur inti belum digarap**: Alat (mgg 3), Riwayat & Notifikasi (mgg 9) — masih placeholder.
- **QA device asli**: kamera/galeri perlu diuji manual (butuh full rebuild karena ubahan native).
- **Identitas native** masih `asmo_mobile` / "Asmo Mobile" (label & bundle) — belum PT Sidik.

## 7. Next Plan
1. **Merge PR #17** ke `develop` setelah review.
2. **Uji manual APK** di HP: login mock, reset password end-to-end, ambil foto (galeri+kamera), cek navbar/profile.
3. **Sambungkan API asli** (login/register/reset) + rapikan `docs/kontrak-api.md`.
4. **Garap layar Alat** (list + form) sebagai fitur fungsional pertama non-auth.
5. **Rename identitas native** ke PT Sidik (label, bundle id, launcher icon).

---

## 🧾 Rincian Commit

| Commit | Tipe | Judul | +/− |
|---|---|---|---|
| `0755fb9` | feat | Pivot desain auth ke neumorphism gelap + fondasi i18n | +1124/−505 |
| `e90ad18` | feat | Floating pill navbar beranimasi | +242/−38 |
| `6766e1b` | feat | Logo resmi PT Sidik di badge auth | +75/−43 |
| `b60cad3` | perf | Ringankan neumorphism + fix border fokus + logo badge | +106/−122 |
| `afc8407` | feat | Reset password fungsional 3 langkah | +1323/−99 |
| `60c619a` | feat | i18n non-auth + redesign Profile (foto galeri) | +718/−140 |
| `87ba6a4` | fix | Navbar anti-overflow + redesign Profile setia acuan | +412/−253 |
| `0e54a92` | feat | Splash screen neumorphism | +95/−27 |
| `7ff4d93` | chore | Izin foto profil (iOS plist + Android manifest) | +11/−0 |

---
*Generated 2026-07-16 · Claude (Senior SWE mode)*
