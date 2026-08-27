#!/usr/bin/env bash
#
# Membuktikan laptop ini sama dengan mesin lain — bukan cuma kodenya.
#
#   ./tool/cek-sinkron.sh
#
# Kenapa ada skrip ini: `git status` bersih cuma bilang tidak ada perubahan yang
# belum di-commit. Itu tidak menjawab pertanyaan yang sebenarnya — apakah mesin
# ini menghasilkan build dan hasil test yang sama seperti mesin sebelah. Yang
# paling sering bikin melenceng justru versi Flutter, karena beda minor saja
# sudah cukup mengubah perilaku analyzer.
#
# Jalankan skrip yang sama di dua mesin. Kalau dua-duanya melaporkan hash commit
# yang sama dan nol masalah, dua mesin itu identik sejauh yang bisa dijamin.
#
# Jalan di macOS dan di Git Bash (Windows). Sengaja tidak pakai fitur bash 4 —
# bash bawaan macOS masih 3.2.

set -uo pipefail

cd "$(dirname "$0")/.."

# Disamakan dengan kelima workflow di .github/workflows/. Kalau di sana naik,
# baris ini ikut naik — kalau tidak, skrip ini malah jadi sumber kebingungan
# baru.
FLUTTER_DIPATOK="3.44.6"
JML_GOLDEN_SEHARUSNYA=18

MASALAH=0
CATATAN=0

ok()      { printf '  \033[32m✓\033[0m %s\n' "$1"; }
masalah() { printf '  \033[31m✗\033[0m %s\n' "$1"; MASALAH=$((MASALAH + 1)); }
catatan() { printf '  \033[33m·\033[0m %s\n' "$1"; CATATAN=$((CATATAN + 1)); }
bagian()  { printf '\n\033[1m[%s]\033[0m\n' "$1"; }

printf '\033[1m=== Cek sinkron — sidik-calibration-mobile ===\033[0m\n'

# ---------------------------------------------------------------- git
bagian "git"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  masalah "bukan repo git — clone ulang dari GitHub"
  exit 1
fi

# Diambil dulu supaya perbandingan di bawah melawan keadaan GitHub sekarang,
# bukan salinan origin/main yang sudah basi berhari-hari.
if git fetch origin main --quiet 2>/dev/null; then
  ok "berhasil fetch origin/main"
else
  catatan "tidak bisa fetch (offline?) — perbandingan di bawah pakai data lokal"
fi

if [ -z "$(git status --porcelain)" ]; then
  ok "working tree bersih"
else
  masalah "ada perubahan yang belum di-commit:"
  git status --short | sed 's/^/      /'
fi

HEAD_SHA=$(git rev-parse --short HEAD)
MAIN_SHA=$(git rev-parse --short origin/main 2>/dev/null || echo '?')

if [ "$HEAD_SHA" = "$MAIN_SHA" ]; then
  ok "HEAD = origin/main ($HEAD_SHA)"
else
  DIBELAKANG=$(git rev-list --count "HEAD..origin/main" 2>/dev/null || echo '?')
  DIDEPAN=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo '?')
  [ "$DIBELAKANG" != "0" ] && masalah "ketinggalan $DIBELAKANG commit dari origin/main → git pull origin main"
  [ "$DIDEPAN" != "0" ] && masalah "$DIDEPAN commit belum di-push → git push origin $(git rev-parse --abbrev-ref HEAD)"
fi

# ----------------------------------------------------------------- toolchain
bagian "toolchain"

if command -v flutter >/dev/null 2>&1; then
  VERSI=$(flutter --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ "$VERSI" = "$FLUTTER_DIPATOK" ]; then
    ok "Flutter $VERSI (persis seperti CI)"
  else
    # Sengaja dituntut sama PERSIS, bukan "minimal". Yang dicari bukan Flutter
    # yang cukup baru, tapi Flutter yang menghasilkan hasil analyze & test yang
    # sama dengan mesin sebelah dan dengan CI.
    masalah "Flutter ${VERSI:-?} — CI memakai $FLUTTER_DIPATOK, harus sama persis"
  fi
else
  masalah "Flutter belum terpasang (butuh $FLUTTER_DIPATOK)"
fi

if [ -d .dart_tool ]; then
  ok ".dart_tool/ ada — flutter pub get sudah dijalankan"
else
  masalah ".dart_tool/ kosong → flutter pub get"
fi

# adb cuma dipakai mode `hp`. Mode `mock` dan desktop jalan tanpa ini, jadi
# ketiadaannya bukan kegagalan.
if command -v adb >/dev/null 2>&1; then
  ok "adb ada — ./tool/dev.sh hp bisa dipakai"
else
  catatan "adb tidak ada di PATH — ./tool/dev.sh hp belum bisa (pasang Android SDK Platform-Tools)"
fi

# ------------------------------------------------------------------- golden
bagian "golden test"

JML_GOLDEN=$(ls -1 test/screenshots/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$JML_GOLDEN" -eq "$JML_GOLDEN_SEHARUSNYA" ]; then
  ok "test/screenshots/ — $JML_GOLDEN golden lengkap"
else
  masalah "test/screenshots/ berisi $JML_GOLDEN golden, seharusnya $JML_GOLDEN_SEHARUSNYA"
fi

# Peringatan ini muncul justru saat semuanya sehat, karena di sinilah satu
# perintah bisa merusak mesin sebelah. Lihat docs/sinkron-laptop-windows.md §5.
case "$(uname -s)" in
  Darwin) ok "di macOS — ini platform acuan golden, --update-goldens boleh di sini" ;;
  *)      catatan "BUKAN macOS — golden lolos dengan ambang longgar (15%). JANGAN jalankan --update-goldens di sini" ;;
esac

# -------------------------------------------------- berkas opsional
bagian "berkas opsional (tidak bikin aplikasi gagal)"

if [ -f android/app/google-services.json ]; then
  ok "android/app/google-services.json — notifikasi push aktif"
else
  catatan "google-services.json belum ada — build tetap jalan, cuma push yang mati"
fi

JML_PDF=$(ls -1 SIDIK-FM-*.pdf SIDIK-IK-*.pdf 2>/dev/null | wc -l | tr -d ' ')
if [ "$JML_PDF" -gt 0 ]; then
  ok "$JML_PDF lembar kerja resmi (SIDIK-FM/IK-*.pdf)"
else
  catatan "lembar kerja resmi PT Sidik belum disalin — dibutuhkan buat permintaan 6"
fi

if [ -d Project-PT-Sidik ]; then
  ok "Project-PT-Sidik/ — vault Obsidian ada"
else
  catatan "Project-PT-Sidik/ belum disalin (vault Obsidian, rujukan saja)"
fi

# -------------------------------------------------------------------- hasil
printf '\n'
if [ "$MASALAH" -eq 0 ]; then
  printf '\033[32m\033[1mSama.\033[0m commit %s · %s catatan opsional\n' "$HEAD_SHA" "$CATATAN"
  printf 'Jalankan skrip ini juga di mesin sebelah — kalau hash commitnya sama, dua mesin itu identik.\n'
  exit 0
else
  printf '\033[31m\033[1mBelum sama — %s masalah.\033[0m Perbaiki yang bertanda ✗ di atas, lalu jalankan lagi.\n' "$MASALAH"
  exit 1
fi
