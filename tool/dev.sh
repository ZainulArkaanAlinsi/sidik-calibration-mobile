#!/usr/bin/env bash
#
# Jalanin app tanpa pernah ngetik IP laptop manual.
#
#   ./tool/dev.sh mac    → macOS desktop, nembak localhost
#   ./tool/dev.sh hp     → HP fisik lewat adb (IP LAN laptop dideteksi otomatis)
#   ./tool/dev.sh mock   → tanpa server sama sekali
#
# Kenapa ada skrip ini: IP LAN laptop ganti tiap pindah wifi, jadi
# --dart-define=API_BASE_URL harus diedit terus. Di sini IP-nya dibaca dari
# interface yang aktif, bukan ditulis di file yang lama-lama basi.
#
# Kalau API_URL sudah diisi (mis. URL Cloudflare Tunnel — lihat
# docs/tunnel-cloudflare.md), nilai itu yang dipakai dan deteksi IP dilewati.
# Saat itu HP tidak perlu sewifi sama laptop lagi:
#
#   API_URL=https://api-dev.contoh.id/api ./tool/dev.sh hp

set -euo pipefail

MODE="${1:-}"
PORT="${PORT:-8000}"

usage() {
  echo "pakai: ./tool/dev.sh {mac|hp|mock}" >&2
  exit 64
}

# IP LAN laptop, dibaca dari interface yang benar-benar punya route ke luar.
# `route get` ikut wifi/ethernet mana pun yang lagi aktif, jadi tidak perlu
# nebak en0 vs en1.
ip_lan() {
  local iface
  iface="$(route -n get default 2>/dev/null | awk '/interface: /{print $2; exit}')"
  [ -n "$iface" ] && ipconfig getifaddr "$iface" 2>/dev/null
}

# Backend harus bind 0.0.0.0, bukan 127.0.0.1 — kalau tidak, HP tidak akan
# pernah nyampe walaupun wifi-nya benar. Ini beda yang paling sering bikin
# salah sangka "server mati".
cek_backend() {
  local host="$1"
  if ! nc -z -G 3 "$host" "$PORT" 2>/dev/null; then
    echo "!! Backend tidak menjawab di ${host}:${PORT}" >&2
    echo "   Di repo sidik-calibration-api jalankan:" >&2
    echo "     php artisan serve --host=0.0.0.0 --port=${PORT}" >&2
    echo "   (--host=0.0.0.0 wajib. Default artisan cuma 127.0.0.1 dan itu" >&2
    echo "    tidak kelihatan dari HP.)" >&2
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
    [ -n "${API_URL:-}" ] || cek_backend 127.0.0.1
    echo "→ macOS · ${URL}"
    exec flutter run -d macos \
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
      LAN="$(ip_lan)"
      if [ -z "$LAN" ]; then
        echo "!! IP LAN laptop tidak terbaca — tidak ada koneksi jaringan aktif?" >&2
        exit 1
      fi
      cek_backend "$LAN"
      URL="http://${LAN}:${PORT}/api"
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
