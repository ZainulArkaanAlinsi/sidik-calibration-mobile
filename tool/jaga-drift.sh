#!/usr/bin/env bash
#
# Gagal kalau sebuah PR membawa "drift" berkas turunan yang bukan tujuannya.
#
#   ./tool/jaga-drift.sh <BASE> <HEAD>
#
#   BASE  ref dasar PR, mis. origin/main
#   HEAD  ujung PR, mis. SHA commit terakhir
#
# Dipakai `.github/workflows/jaga-drift.yml` di tiap pull request. Boleh dijalankan
# lokal sebelum membuka PR:  ./tool/jaga-drift.sh origin/main HEAD
#
# ## Kenapa ada
#
# `AGENTS.md` punya aturan keras: "Do not commit `pubspec.lock` drift from local
# SDK". Sampai sekarang itu aturan lisan. Tiap `flutter pub get` di mesin yang
# SDK-nya beda minor menulis ulang `pubspec.lock` (dan `generated_plugins.cmake`
# / `GeneratedPluginRegistrant.*`) tanpa ada yang mengubah dependensi, dan
# berkas-berkas itu ikut `git status` seperti perubahan sungguhan. Pada 15 Nov
# 2026 beberapa pembangun yang bekerja di repo ini melaporkan harus memulihkannya
# dari HEAD dengan tangan sebelum commit. Aturan yang hanya dijaga ingatan itu
# tidak punya pagar kalau suatu saat terlewat.
#
# ## Yang dijaga
#
#   R1  `pubspec.lock` berubah tapi `pubspec.yaml` tidak.
#   R2  `studio/pubspec.lock` berubah tapi `studio/pubspec.yaml` tidak.
#   R3  berkas turunan plugin (`generated_plugins.cmake`,
#       `generated_plugin_registrant.*`, `GeneratedPluginRegistrant.swift`)
#       berubah padahal tidak ada `pubspec.yaml` yang berubah.
#   R4  berkas buatan alat yang tidak boleh masuk repo: `.dart_tool/`,
#       `graphify-out/`, `_agents_workspace/` (ditambah atau diubah).
#
# Menghapus berkas selalu boleh (R4 tidak menghukum pembersihan).
#
# ## Kalau memang disengaja (naik SDK, ganti paket, dsb.)
#
# R1-R3 (bukan R4) boleh dilewati dengan satu baris di pesan commit MANA PUN di PR:
#
#     Izinkan-drift: <alasan, tidak boleh kosong>
#
# Baris itu sekaligus jadi catatan KENAPA lockfile berubah. Tanpa alasan, tidak
# berlaku. (Label PR sengaja tidak dipakai: isinya basi saat job dijalankan ulang.)
#
# ## Yang TIDAK dijaga, dan sengaja
#
# Golden PNG tidak diperiksa di sini: `periksa-pr.yml` dan `golden-baru.yml`
# punya jalan resmi (`_testImage.png` dari macOS, atau bot) dan manusia boleh
# meng-commit hasilnya. Menolak PNG di sini akan memblokir jalan resmi itu.
#
# Keluar: 0 bersih (atau dilewati dengan alasan), 1 ada pelanggaran, 2 salah pakai.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "pakai: $0 <BASE> <HEAD>" >&2
  exit 2
fi

base="$1"
head="$2"

# Tiga titik: perubahan PR saja, dihitung dari titik cabang — bukan perbedaan
# base-vs-head yang ikut membawa commit baru di base.
if ! mapfile -t berubah < <(git diff --name-only --diff-filter=AMRCT "${base}...${head}"); then
  echo "jaga-drift: gagal membandingkan ${base}...${head}" >&2
  exit 2
fi

ada() {
  local p="$1" b
  for b in "${berubah[@]:-}"; do
    [ "$b" = "$p" ] && return 0
  done
  return 1
}

ada_awalan() {
  local awalan="$1" b
  for b in "${berubah[@]:-}"; do
    case "$b" in "$awalan"*) return 0 ;; esac
  done
  return 1
}

ada_turunan_plugin() {
  local b
  for b in "${berubah[@]:-}"; do
    case "$(basename "$b")" in
      generated_plugins.cmake | generated_plugin_registrant.* | GeneratedPluginRegistrant.*)
        return 0
        ;;
    esac
  done
  return 1
}

pelanggaran_lockfile=()
pelanggaran_keras=()

if ada pubspec.lock && ! ada pubspec.yaml; then
  pelanggaran_lockfile+=("R1  pubspec.lock berubah tanpa pubspec.yaml")
fi

if ada studio/pubspec.lock && ! ada studio/pubspec.yaml; then
  pelanggaran_lockfile+=("R2  studio/pubspec.lock berubah tanpa studio/pubspec.yaml")
fi

if ada_turunan_plugin && ! ada pubspec.yaml && ! ada studio/pubspec.yaml; then
  pelanggaran_lockfile+=("R3  berkas turunan plugin berubah tanpa ada pubspec.yaml yang berubah")
fi

for terlarang in ".dart_tool/" "graphify-out/" "_agents_workspace/"; do
  if ada_awalan "$terlarang"; then
    pelanggaran_keras+=("R4  berkas di ${terlarang} ditambahkan/diubah (buatan alat, tidak boleh masuk repo)")
  fi
done

# Alasan pelonggaran: baris `Izinkan-drift: <alasan>` di pesan commit mana pun di PR.
# Alasan kosong atau cuma spasi tidak dihitung.
izin=""
if [ "${#pelanggaran_lockfile[@]}" -gt 0 ]; then
  izin="$(git log --format=%B "${base}..${head}" \
    | sed -n 's/^[[:space:]]*Izinkan-drift:[[:space:]]*//p' \
    | grep -m1 -E '[^[:space:]]' || true)"
fi

keluar=0

echo "jaga-drift: ${#berubah[@]} berkas berubah di ${base}...${head}"

if [ "${#pelanggaran_lockfile[@]}" -gt 0 ]; then
  if [ -n "$izin" ]; then
    echo "jaga-drift: dilewati dengan alasan di pesan commit: ${izin}"
    for p in "${pelanggaran_lockfile[@]}"; do echo "  (dilewati) $p"; done
  else
    for p in "${pelanggaran_lockfile[@]}"; do echo "::error::$p"; done
    echo "jaga-drift: biasanya ini hasil \`flutter pub get\` di mesin ber-SDK beda. Pulihkan:" >&2
    echo "  git show ${base}:pubspec.lock > pubspec.lock   # (dan studio/pubspec.lock, generated_plugins.cmake)" >&2
    echo "Kalau memang disengaja, tambah baris di pesan commit: Izinkan-drift: <alasan>" >&2
    keluar=1
  fi
fi

if [ "${#pelanggaran_keras[@]}" -gt 0 ]; then
  for p in "${pelanggaran_keras[@]}"; do echo "::error::$p"; done
  keluar=1
fi

if [ "$keluar" -eq 0 ]; then
  echo "jaga-drift: bersih."
fi

exit "$keluar"
