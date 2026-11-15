#!/usr/bin/env bash
#
# Uji regresi buat `tool/jaga-drift.sh`.
#
#   ./tool/uji-jaga-drift.sh
#
# Membangun repo git sementara, membuat PR palsu per skenario, lalu memastikan
# `jaga-drift.sh` meloloskan atau menolaknya sesuai aturan R1-R4 dan jalur
# `Izinkan-drift:`. Tidak menyentuh repo ini dan tidak butuh jaringan.

set -uo pipefail

skrip="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jaga-drift.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gagal=0
total=0

git_()  { git -C "$tmp/r" -c user.email=uji@example.test -c user.name=uji -c core.autocrlf=false -c core.safecrlf=false "$@"; }

mulai_repo() {
  rm -rf "$tmp/r"
  mkdir -p "$tmp/r/lib" "$tmp/r/studio" "$tmp/r/windows/flutter"
  git init -q -b main "$tmp/r"
  echo 'name: app'        > "$tmp/r/pubspec.yaml"
  echo 'lock: 1'          > "$tmp/r/pubspec.lock"
  echo 'name: studio'     > "$tmp/r/studio/pubspec.yaml"
  echo 'lock: 1'          > "$tmp/r/studio/pubspec.lock"
  echo 'plugins: 1'       > "$tmp/r/windows/flutter/generated_plugins.cmake"
  echo 'void main() {}'   > "$tmp/r/lib/main.dart"
  git_ add -A
  git_ commit -q -m "dasar"
  git_ checkout -q -b pr
}

# komit <pesan> <berkas>... : ubah tiap berkas lalu commit
komit() {
  local pesan="$1"; shift
  local f
  for f in "$@"; do
    mkdir -p "$tmp/r/$(dirname "$f")"
    echo "ubah $RANDOM" >> "$tmp/r/$f"
  done
  git_ add -A
  git_ commit -q -m "$pesan"
}

# harap <nama> <kode-keluar-harapan>
harap() {
  local nama="$1" harapan="$2" kode
  total=$((total + 1))
  (cd "$tmp/r" && bash "$skrip" main HEAD >"$tmp/keluar.txt" 2>&1)
  kode=$?
  if [ "$kode" -eq "$harapan" ]; then
    echo "ok   - $nama"
  else
    echo "GAGAL - $nama (keluar $kode, seharusnya $harapan)"
    sed 's/^/        /' "$tmp/keluar.txt"
    gagal=$((gagal + 1))
  fi
}

mulai_repo; komit "ubah kode" lib/main.dart
harap "perubahan kode biasa lolos" 0

mulai_repo; komit "lock saja" pubspec.lock
harap "R1: pubspec.lock tanpa pubspec.yaml ditolak" 1

mulai_repo; komit "lock + yaml" pubspec.lock pubspec.yaml
harap "R1: pubspec.lock bersama pubspec.yaml lolos" 0

mulai_repo; komit "studio lock saja" studio/pubspec.lock
harap "R2: studio/pubspec.lock tanpa studio/pubspec.yaml ditolak" 1

mulai_repo; komit "studio lock + yaml" studio/pubspec.lock studio/pubspec.yaml
harap "R2: studio/pubspec.lock bersama studio/pubspec.yaml lolos" 0

mulai_repo; komit "turunan plugin saja" windows/flutter/generated_plugins.cmake
harap "R3: generated_plugins.cmake tanpa pubspec.yaml ditolak" 1

mulai_repo; komit "turunan plugin + yaml" windows/flutter/generated_plugins.cmake pubspec.yaml
harap "R3: generated_plugins.cmake bersama pubspec.yaml lolos" 0

mulai_repo; komit "alat" .dart_tool/x.json
harap "R4: .dart_tool/ ditolak" 1

mulai_repo; komit "alat" graphify-out/g.json
harap "R4: graphify-out/ ditolak" 1

mulai_repo; komit "alat" _agents_workspace/a.md
harap "R4: _agents_workspace/ ditolak" 1

mulai_repo; komit "lock disengaja

Izinkan-drift: naik SDK ke 3.44.6" pubspec.lock
harap "R1: Izinkan-drift dengan alasan melewati" 0

mulai_repo; komit "lock disengaja

Izinkan-drift:    " pubspec.lock
harap "R1: Izinkan-drift tanpa alasan tetap ditolak" 1

mulai_repo; komit "alat tapi minta izin

Izinkan-drift: tolong" .dart_tool/x.json
harap "R4: Izinkan-drift TIDAK melewati berkas buatan alat" 1

mulai_repo; komit "lock" pubspec.lock; komit "kode lain" lib/main.dart
harap "R1: pelanggaran di commit awal tetap terdeteksi" 1

mulai_repo
git_ rm -q pubspec.lock
git_ commit -q -m "hapus lock"
harap "menghapus pubspec.lock tidak dihukum" 0

mulai_repo
(cd "$tmp/r" && bash "$skrip" main >"$tmp/keluar.txt" 2>&1); kode=$?
total=$((total + 1))
if [ "$kode" -eq 2 ]; then echo "ok   - salah pakai (argumen kurang) keluar 2"
else echo "GAGAL - salah pakai keluar $kode, seharusnya 2"; gagal=$((gagal + 1)); fi

echo
echo "${total} skenario, ${gagal} gagal"
[ "$gagal" -eq 0 ]
