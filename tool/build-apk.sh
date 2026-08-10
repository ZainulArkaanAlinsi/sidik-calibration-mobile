#!/usr/bin/env bash
#
# Bikin APK yang bisa dipasang permanen di HP — buat uji coba di lokasi,
# tanpa laptop, tanpa `flutter run`, tanpa adb nyantol terus.
#
#   ./tool/build-apk.sh https://sidik-calibration-api.onrender.com
#
# Hasilnya DUA berkas, dan itu disengaja:
#
#   sidik-cloud.apk   → nembak server Render lewat internet (paket data HP).
#                       Ini yang dipakai kalau wifi lokasi mati.
#   sidik-lokal.apk   → nembak 127.0.0.1:8000, yaitu laptop lewat relay adb.
#                       Cadangan kalau di lokasi ternyata NGGAK ada internet
#                       sama sekali; jalan lewat kabel USB, tanpa jaringan.
#
# Kenapa dua berkas dan bukan satu yang bisa ganti alamat: API_BASE_URL itu
# `String.fromEnvironment`, ketanam waktu compile (lihat lib/core/config/
# app_config.dart). Di build release nilainya beku — nggak bisa diganti dari
# dalam app. Itu memang disengaja biar mock/alamat dev nggak kebawa diam-diam
# ke APK produksi, dan konsekuensinya ya begini: mau dua alamat, ya dua build.

set -euo pipefail

cd "$(dirname "$0")/.."

BASE="${1:-}"

if [ -z "$BASE" ]; then
    echo "pakai: ./tool/build-apk.sh <url-server>" >&2
    echo "contoh: ./tool/build-apk.sh https://sidik-calibration-api.onrender.com" >&2
    exit 64
fi

# Dipotong biar nggak jadi ".../api/api" kalau URL-nya udah kebawa /api, dan
# nggak jadi "...com//api" kalau kelebihan garis miring.
BASE="${BASE%/}"
BASE="${BASE%/api}"

case "$BASE" in
    https://*) ;;
    http://*)
        echo "!! URL-nya http polos, bukan https." >&2
        echo "   Android 9+ nolak HTTP polos ke host yang nggak terdaftar di" >&2
        echo "   android/app/src/main/res/xml/network_security_config.xml, dan" >&2
        echo "   gagalnya muncul sebagai CLEARTEXT_NOT_PERMITTED — kelihatan" >&2
        echo "   persis kayak server mati padahal servernya hidup." >&2
        exit 1
        ;;
    *)
        echo "!! URL harus diawali https://" >&2
        exit 1
        ;;
esac

# Dicek sekarang, selagi masih di depan laptop. Kalau server lagi ketiduran
# (paket gratis Render nidurin service yang nganggur ~15 menit), permintaan
# pertama ini sekaligus yang mbangunin — jadi jangan kaget kalau lama.
echo "→ ngecek ${BASE}/api/health ..."
if curl -fsS --max-time 90 "${BASE}/api/health" >/dev/null 2>&1; then
    echo "  server jawab."
else
    echo "!! Server nggak jawab di ${BASE}/api/health" >&2
    echo "   Build-nya tetap diterusin, tapi cek dulu di Render: service-nya" >&2
    echo "   hidup? deploy terakhirnya sukses? APK yang nunjuk ke server mati" >&2
    echo "   kelihatannya persis kayak app-nya yang rusak." >&2
fi

OUT="build/apk-rilis"
mkdir -p "$OUT"

echo
echo "→ [1/2] APK cloud · ${BASE}/api"
flutter build apk --release \
    --dart-define=APP_ENV=prod \
    --dart-define=API_BASE_URL="${BASE}/api"
cp build/app/outputs/flutter-apk/app-release.apk "${OUT}/sidik-cloud.apk"

echo
echo "→ [2/2] APK lokal cadangan · http://127.0.0.1:8000/api (lewat relay adb)"
flutter build apk --release \
    --dart-define=APP_ENV=dev \
    --dart-define=API_BASE_URL="http://127.0.0.1:8000/api"
cp build/app/outputs/flutter-apk/app-release.apk "${OUT}/sidik-lokal.apk"

echo
echo "Selesai:"
ls -lh "${OUT}"/*.apk | awk '{print "  " $9 "  (" $5 ")"}'
cat <<'CATATAN'

Pasang ke HP:
  adb install -r build/apk-rilis/sidik-cloud.apk

Kalau kepakai yang cadangan, relay-nya harus dipasang dulu tiap HP kesambung
(dan backend-nya hidup di laptop):
  adb reverse tcp:8000 tcp:8000

Catatan signing: android/app/build.gradle.kts masih nandatangani build release
pakai kunci DEBUG (ada TODO-nya di sana). APK-nya tetap kepasang dan jalan
normal, cuma dua akibatnya:
  · kunci debug beda-beda tiap laptop, jadi APK dari laptop lain nggak bisa
    nimpa yang udah kepasang — harus uninstall dulu, dan itu ngehapus data
    login di HP-nya;
  · nggak layak buat sebaran resmi ke pelanggan.
Buat uji coba internal masih aman. Sebelum diserahin ke lab, bikin keystore
rilis sendiri.
CATATAN
