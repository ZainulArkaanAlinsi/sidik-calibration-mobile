#!/usr/bin/env bash
#
# Gagal kalau ada berkas di `lib/` yang tidak di-import, di-export, atau
# di-`part` oleh berkas Dart mana pun.
#
#   ./tool/cek-berkas-yatim.sh
#
# ## Kenapa ada
#
# `flutter analyze` menangkap import dan elemen PRIVAT yang tidak terpakai,
# tapi buta terhadap berkas utuh yang tidak lagi disambung ke mana pun: kelas
# publiknya tetap "dipakai" menurut analyzer selama berkasnya ada. Sapuan
# 17 Sep 2026 menemukan tujuh berkas seperti itu (±1.100 baris) sementara
# analyzer melapor "No issues found" — termasuk layar yang menembak rute yang
# sudah dicabut backend. Kode baru cenderung ditambah di sebelah yang lama,
# bukan menggantikannya; tanpa gerbang, tumpukannya baru ketahuan kalau ada
# yang sengaja menyapu.
#
# ## Yang dihitung "dipakai"
#
# Dirujuk dari lib/, test/, integration_test/, atau tool/ — lewat path relatif,
# `package:sidik_calibration/…`, maupun cabang import bersyarat
# (`if (dart.library.io) '…'`). Berkas yang cuma dipakai test tetap lolos:
# gerbang ini sengaja tidak menilai apakah fiturnya masih diinginkan, karena
# itu keputusan produk, bukan sesuatu yang bisa dibuktikan mesin.
#
# ## Kalau merah
#
# Hapus berkasnya. Kalau berkas itu memang titik masuk yang sah (mis. `main_*`
# baru), tambahkan path-nya ke PENGECUALIAN di bawah beserta alasannya.

set -euo pipefail

# `comm` menuntut kedua masukannya diurutkan dengan aturan yang sama; locale
# runner dan laptop bisa beda.
export LC_ALL=C

cd "$(dirname "$0")/.."

PAKET="sidik_calibration"

PENGECUALIAN=(
  # Titik masuk aplikasi — tidak di-import siapa pun menurut definisinya.
  "lib/main.dart"
)

dirujuk="$(mktemp)"
trap 'rm -f "$dirujuk"' EXIT

# Satu grep untuk semua berkas, satu awk untuk menormalkan path. Versi
# per-import (`realpath` per baris) makan lebih dari dua menit di Git Bash
# Windows, dan pemeriksaan yang lambat berhenti dijalankan orang di laptopnya.
#
# Barisnya: import/export/part, plus baris lanjutan cabang import bersyarat.
find lib test integration_test tool -name '*.dart' -print0 2>/dev/null \
  | xargs -0 grep -HE "^[[:space:]]*(import|export|part)[[:space:]]+['\"]|^[[:space:]]*if[[:space:]]*\(" \
  | awk -v paket="package:$PAKET/" '
      {
        titik = index($0, ":")
        berkas = substr($0, 1, titik - 1)
        baris = substr($0, titik + 1)
        dir = berkas
        sub(/\/[^\/]*$/, "", dir)

        while (match(baris, /["\047][^"\047]+\.dart["\047]/)) {
          uri = substr(baris, RSTART + 1, RLENGTH - 2)
          baris = substr(baris, RSTART + RLENGTH)

          if (uri ~ /^dart:/) continue
          if (index(uri, paket) == 1) { print "lib/" substr(uri, length(paket) + 1); continue }
          if (uri ~ /^package:/) continue

          n = split(dir "/" uri, bagian, "/")
          k = 0
          for (i = 1; i <= n; i++) {
            if (bagian[i] == "." || bagian[i] == "") continue
            if (bagian[i] == "..") { if (k > 0) k--; continue }
            hasil[++k] = bagian[i]
          }
          jalur = hasil[1]
          for (i = 2; i <= k; i++) jalur = jalur "/" hasil[i]
          print jalur
        }
      }' \
  > "$dirujuk"

printf '%s\n' "${PENGECUALIAN[@]}" >> "$dirujuk"
sort -u -o "$dirujuk" "$dirujuk"

mapfile -t yatim < <(
  find lib -name '*.dart' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' \
    ! -path 'lib/l10n/app_localizations*.dart' \
    | sort | comm -23 - "$dirujuk"
)

if [ "${#yatim[@]}" -gt 0 ]; then
  for berkas in "${yatim[@]}"; do
    echo "::error file=$berkas::Tidak di-import berkas Dart mana pun — hapus, atau daftarkan di PENGECUALIAN tool/cek-berkas-yatim.sh kalau memang titik masuk."
  done
  echo "${#yatim[@]} berkas yatim di lib/."
  exit 1
fi

echo "Nol berkas yatim di lib/."
