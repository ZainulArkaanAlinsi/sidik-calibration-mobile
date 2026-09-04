#!/usr/bin/env bash
#
# Uji regresi buat `tool/bikin-keystore-rilis.sh`.
#
#   ./tool/uji-bikin-keystore.sh
#
# ## Kenapa ada
#
# Skrip keystore pernah melahirkan bug yang TIDAK menghasilkan error: langkah
# cadangannya menyuruh berhenti lalu menjalankan ulang, sementara penjaga
# "berkas sudah ada" menolak jalan kedua dengan status 1. Dua bagian itu benar
# sendiri-sendiri; salahnya cuma kelihatan kalau dibaca bersama — dan yang kena
# justru orang yang menuruti instruksinya.
#
# Jebakannya mendarat di titik paling genting: kunci sudah lahir di disk, nol
# secret terpasang, jalan maju ditutup. Perilaku semacam itu tidak boleh
# dijaga oleh ingatan siapa pun.
#
# ## Kenapa pakai stub
#
# `keytool` bikin kunci RSA 4096 (lambat), dan `gh` beneran akan MENULIS secret
# ke repo asli. Dua-duanya diganti stub: yang diuji di sini keputusan alur
# skripnya — kapan kunci dibuat, kapan dilewati, apa yang terpasang — bukan
# kebenaran kriptografinya.

set -euo pipefail

AKAR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKRIP="${AKAR}/tool/bikin-keystore-rilis.sh"

merah() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
hijau() { printf '\033[32m%s\033[0m\n' "$*"; }

GAGAL=0
lolos() { hijau "  ✓ $*"; }
tekor() { merah "  ✗ $*"; GAGAL=1; }

RUANG="$(mktemp -d)"
trap 'rm -rf "$RUANG"' EXIT

# ------------------------------------------------------------------- stub

mkdir -p "$RUANG/stub"

cat > "$RUANG/stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
    "auth status") exit 0 ;;
    "repo view") echo "ZainulArkaanAlinsi/sidik-calibration-mobile"; exit 0 ;;
esac
# `read` satu baris, bukan `cat`: dua password terakhir dibaca dari stdin
# skripnya, dan `cat` bakal menelan jawaban yang belum giliran dipakai.
read -r isi || true
echo "$1 $2 $3 panjang=${#isi}" >> "$REKAM"
STUB

cat > "$RUANG/stub/keytool" <<'STUB'
#!/usr/bin/env bash
echo "keytool $1" >> "$REKAM"
if [ "$1" = "-genkeypair" ]; then
    prev=""
    for a in "$@"; do
        [ "$prev" = "-keystore" ] && berkas="$a"
        prev="$a"
    done
    echo "kunci-tiruan-$(date +%s%N)" > "$berkas"
fi
[ "$1" = "-list" ] && echo "         SHA256: AA:BB:CC:DD:EE:FF"
exit 0
STUB

chmod +x "$RUANG/stub/gh" "$RUANG/stub/keytool"
export PATH="$RUANG/stub:$PATH"

# Skrip aslinya menolak jalan di CI, dan uji ini justru ingin menjalankannya
# DI CI. Yang dijaga penjagaan itu — kunci sungguhan lahir di runner yang
# dibuang — tidak terjadi di sini: `keytool`-nya stub, dan yang lahir cuma
# berkas teks di direktori sementara.
unset CI GITHUB_ACTIONS

# ------------------------------------------------------------------ tolong

# Tiap kasus jalan di direktori sendiri supaya sisa kasus sebelumnya tidak
# ikut terbaca — kondisi awal itu justru yang diuji di sini.
jalankan() {
    local nama="$1" jawaban="$2"
    KERJA="$RUANG/$nama"
    mkdir -p "$KERJA"
    export REKAM="$KERJA/rekam.txt"
    : > "$REKAM"
    set +e
    ( cd "$KERJA" && printf '%s' "$jawaban" | bash "$SKRIP" > "$KERJA/keluaran.txt" 2>&1 )
    STATUS=$?
    set -e
}

punya() { grep -q "$1" "$REKAM"; }

# ------------------------------------------------------------------- kasus

echo "Menguji: ${SKRIP}"
echo

echo "1. Jalan pertama — belum ada keystore"
jalankan pertama 'y
y
sandi
sandi
'
[ "$STATUS" -eq 0 ] && lolos "keluar 0" || tekor "keluar $STATUS, harusnya 0"
punya 'keytool -genkeypair' && lolos "kunci dibuat" || tekor "kunci TIDAK dibuat"
[ -f "$KERJA/sidik-rilis.jks" ] && lolos "berkas ada" || tekor "berkas tidak ada"
for n in ANDROID_KEYSTORE_BASE64 ANDROID_KEY_ALIAS ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_PASSWORD; do
    punya "secret set $n" && lolos "$n terpasang" || tekor "$n TIDAK terpasang"
done
punya 'variable set APK_SHA256' && lolos "APK_SHA256 terpasang" || tekor "APK_SHA256 TIDAK terpasang"

echo
echo "2. Jalan kedua — keystore sudah ada (regresi bug jalan-kedua)"
jalankan kedua ''            # cuma buat direktorinya
printf 'kunci-lama' > "$KERJA/sidik-rilis.jks"
CAP_AWAL="$(cat "$KERJA/sidik-rilis.jks")"
jalankan kedua 'y
y
sandi
sandi
'
[ "$STATUS" -eq 0 ] && lolos "keluar 0 (sebelum perbaikan: 1)" || tekor "keluar $STATUS, harusnya 0"
punya 'keytool -genkeypair' && tekor "genkeypair DIPANGGIL — kunci lama ditimpa!" || lolos "genkeypair tidak dipanggil"
[ "$(cat "$KERJA/sidik-rilis.jks")" = "$CAP_AWAL" ] && lolos "isi kunci utuh" || tekor "isi kunci BERUBAH"
punya 'variable set APK_SHA256' && lolos "kelima nilai tetap terpasang" || tekor "APK_SHA256 TIDAK terpasang"

echo
echo "3. Jawab 'n' di langkah cadangan — berhenti, tapi tidak merusak"
jalankan cadangan 'y
n
'
[ "$STATUS" -eq 0 ] && lolos "keluar 0" || tekor "keluar $STATUS, harusnya 0"
[ -f "$KERJA/sidik-rilis.jks" ] && lolos "kunci tetap ada" || tekor "kunci hilang"
punya 'secret set' && tekor "ada secret terpasang, harusnya nol" || lolos "nol secret terpasang"
grep -q 'jalankan perintah yang sama lagi' "$KERJA/keluaran.txt" \
    && lolos "menunjuk cara melanjutkan" || tekor "tidak menunjuk cara melanjutkan"

echo
echo "4. Batal di prompt 'Betul?'"
jalankan batal 'n
'
[ "$STATUS" -eq 0 ] && lolos "keluar 0" || tekor "keluar $STATUS, harusnya 0"
punya 'keytool' && tekor "keytool dipanggil, harusnya tidak" || lolos "keytool tidak dipanggil"
punya 'secret set' && tekor "ada secret terpasang, harusnya nol" || lolos "nol secret terpasang"

echo
echo "5. Penjagaan CI masih berlaku"
KERJA="$RUANG/ci"; mkdir -p "$KERJA"; export REKAM="$KERJA/rekam.txt"; : > "$REKAM"
set +e
( cd "$KERJA" && CI=true bash "$SKRIP" > "$KERJA/keluaran.txt" 2>&1 )
STATUS=$?
set -e
[ "$STATUS" -eq 1 ] && lolos "menolak jalan di CI (keluar 1)" || tekor "keluar $STATUS, harusnya 1"
[ -f "$KERJA/sidik-rilis.jks" ] && tekor "kunci terlanjur dibuat di CI" || lolos "tidak ada kunci dibuat"

echo
if [ "$GAGAL" -eq 0 ]; then
    hijau "Semua kasus lolos."
else
    merah "Ada kasus yang gagal."
fi
exit "$GAGAL"
