#!/usr/bin/env bash
#
# Jalanin app tanpa pernah ngetik IP laptop manual.
#
#   ./tool/dev.sh mac      → macOS desktop, nembak localhost
#   ./tool/dev.sh windows  → desktop Windows, nembak localhost
#   ./tool/dev.sh hp       → HP fisik lewat adb (port di-relay, tanpa IP sama sekali)
#   ./tool/dev.sh mock     → tanpa server sama sekali
#
# Kenapa ada skrip ini: IP LAN laptop ganti tiap pindah wifi, jadi
# --dart-define=API_BASE_URL harus diedit terus.
#
# Jalan keluarnya BUKAN mendeteksi IP itu lebih pintar, tapi tidak memakai IP
# sama sekali. `adb reverse` bikin port di HP nembus ke laptop, jadi dari sisi
# app alamatnya selalu 127.0.0.1 — nilai yang tidak mungkin basi, tidak peduli
# lagi di wifi mana, atau bahkan lewat USB tanpa wifi.
#
# Ini sekaligus lolos dari android/app/src/main/res/xml/network_security_config.xml:
# Android 9+ cuma ngasih HTTP polos ke alamat yang terdaftar di situ, dan
# 127.0.0.1 permanen ada di daftar. IP LAN tidak, dan tiap ganti wifi berkas itu
# harus diedit juga — gagalnya muncul sebagai CLEARTEXT_NOT_PERMITTED, yang
# nyamar jadi "backend mati".
#
# Kalau API_URL sudah diisi (mis. URL Cloudflare Tunnel — lihat
# docs/tunnel-cloudflare.md), nilai itu yang dipakai dan relay dilewati.
#
#   API_URL=https://api-dev.contoh.id/api ./tool/dev.sh hp

set -euo pipefail

MODE="${1:-}"
PORT="${PORT:-8000}"

usage() {
  echo "pakai: ./tool/dev.sh {mac|windows|hp|mock}" >&2
  exit 64
}

# Backend selalu diadu ke 127.0.0.1 — buat HP pun, karena yang menerima
# sambungan hasil relay adalah laptop ini juga.
#
# Pakai /dev/tcp bawaan bash, bukan `nc`. Alasannya: flag timeout netcat beda
# per-sistem — `-G` cuma ada di BSD/macOS, dan Git Bash di Windows malah nggak
# bawa `nc` sama sekali. Efeknya di Windows cek ini SELALU gagal, dan skripnya
# nolak jalan sambil bilang "backend tidak menjawab" padahal backendnya hidup —
# salah tuduh yang mahal, karena yang dicurigai jadi repo sebelah.
#
# Nggak perlu timeout: sambungan ke 127.0.0.1 langsung ketahuan diterima atau
# ditolak, nggak ada perjalanan jaringan yang bisa nggantung.
cek_backend() {
  if ! (exec 3<>"/dev/tcp/127.0.0.1/${PORT}") 2>/dev/null; then
    echo "!! Backend tidak menjawab di 127.0.0.1:${PORT}" >&2
    echo "   Di repo sidik-calibration-api jalankan:" >&2
    echo "     php artisan serve --port=${PORT}" >&2
    echo "   (Tidak perlu --host=0.0.0.0 lagi: relay adb yang nganterin, bukan" >&2
    echo "    wifi, jadi bind default 127.0.0.1 sudah cukup.)" >&2
    exit 1
  fi
}

# ID device android dari adb, supaya tidak perlu copy-paste nama transport
# yang berubah tiap pairing ulang.
device_android() {
  adb devices | awk '$2=="device"{print $1; exit}'
}

case "$MODE" in
  mac)
    URL="${API_URL:-http://127.0.0.1:${PORT}/api}"
    [ -n "${API_URL:-}" ] || cek_backend
    echo "→ macOS · ${URL}"
    exec flutter run -d macos \
      --dart-define=APP_ENV=dev \
      --dart-define=API_BASE_URL="$URL"
    ;;

  # Kembaran persis mode `mac`, beda cuma target device-nya. Ditulis terpisah
  # dan bukan dideteksi dari `uname`, karena satu-satunya yang tau mau jalan di
  # mana itu orangnya — di Windows yang punya WSL, tebakan otomatis malah salah.
  windows)
    URL="${API_URL:-http://127.0.0.1:${PORT}/api}"
    [ -n "${API_URL:-}" ] || cek_backend
    echo "→ Windows · ${URL}"
    exec flutter run -d windows \
      --dart-define=APP_ENV=dev \
      --dart-define=API_BASE_URL="$URL"
    ;;

  hp)
    DEV="$(device_android)"
    if [ -z "$DEV" ]; then
      echo "!! Tidak ada HP terhubung." >&2
      echo "   Nyalakan Wireless debugging di HP, lalu:" >&2
      echo "     ADB_MDNS_OPENSCREEN=1 adb start-server && adb devices" >&2
      echo "   HP yang pernah dipasangkan biasanya nyambung sendiri lewat mDNS." >&2
      echo "   Kalau belum pernah: adb pair <ip>:<port-pairing> <kode>" >&2
      echo "   (port pairing beda dari port connect, dan kodenya cepat hangus)" >&2
      exit 1
    fi

    if [ -n "${API_URL:-}" ]; then
      URL="$API_URL"
    else
      cek_backend
      # Relay-nya dipasang ulang tiap run: `adb reverse` hilang begitu HP
      # lepas dari adb, dan itu sering terjadi tanpa disadari di wireless
      # debugging.
      if ! adb -s "$DEV" reverse "tcp:${PORT}" "tcp:${PORT}" >/dev/null; then
        echo "!! Gagal masang relay port ke HP (adb reverse)." >&2
        echo "   Coba: adb kill-server && ADB_MDNS_OPENSCREEN=1 adb start-server" >&2
        echo "   Kalau HP-nya lewat wifi dan tetap gagal, colok USB — reverse" >&2
        echo "   lebih tahan banting di USB." >&2
        exit 1
      fi
      URL="http://127.0.0.1:${PORT}/api"
    fi

    echo "→ HP ${DEV} · ${URL}"
    exec flutter run -d "$DEV" \
      --dart-define=APP_ENV=dev \
      --dart-define=API_BASE_URL="$URL"
    ;;

  mock)
    echo "→ mock (tanpa server)"
    exec flutter run --dart-define=USE_MOCK=true
    ;;

  *)
    usage
    ;;
esac
