#!/usr/bin/env bash
#
# Bikin kunci penanda tangan APK rilis, sekali seumur aplikasi.
#
#   ./tool/bikin-keystore-rilis.sh
#
# Ini SOP di docs/rilis-tanda-tangan-apk.md yang dijadikan satu perintah —
# bukan jalan pintasnya. Urutan, parameter, dan pembagian Secret/Variable-nya
# sama persis; yang hilang cuma kesempatan salah ketik.
#
# ## Kenapa harus di komputermu sendiri
#
# Kunci ini SATU-SATUNYA benda yang bisa menerbitkan pembaruan buat aplikasi
# yang sudah terpasang di HP teknisi. Hilang = tiap teknisi harus uninstall
# manual lagi dan kehilangan token login serta foto profilnya. Bocor = orang
# lain bisa membangun APK yang Android terima sebagai pembaruan sah.
#
# Karena itu skrip ini menolak jalan di CI, dan kunci privatnya tidak pernah
# dicetak ke layar. Yang naik ke GitHub cuma bentuk base64-nya lewat `gh`,
# langsung dari berkas ke secret, tanpa mampir ke variabel shell.
#
# ## Password TIDAK diterima lewat argumen
#
# Argumen mendarat di riwayat shell DAN di daftar proses (`ps`), yang kebaca
# pengguna lain di mesin yang sama. Skrip ini membiarkan `keytool` bertanya
# sendiri, lalu `gh secret set` membacanya dari stdin.

set -euo pipefail

BERKAS="${BERKAS_KEYSTORE:-sidik-rilis.jks}"
ALIAS="${ALIAS_KUNCI:-sidik-rilis}"

merah() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
hijau() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- penjagaan

if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    merah "!! Skrip ini menolak jalan di CI."
    merah "   Runner dibuang tiap run, jadi kuncinya ikut hilang — dan kunci"
    merah "   yang hilang tidak bisa dibuat ulang. Jalankan di komputermu."
    exit 1
fi

for perlu in keytool gh base64; do
    command -v "$perlu" >/dev/null || {
        merah "!! \`$perlu\` tidak ada di PATH."
        [ "$perlu" = keytool ] && merah "   Dia ikut JDK — pasang Android Studio atau Temurin."
        [ "$perlu" = gh ] && merah "   Pasang GitHub CLI: https://cli.github.com"
        exit 1
    }
done

# Menimpa keystore yang sudah ada = kehilangan kunci lama tanpa peringatan,
# dan itu kegagalan yang baru ketahuan berbulan-bulan kemudian waktu ada
# teknisi menekan Update. Nggak ada flag buat memaksa: kalau memang mau ganti
# kunci, pindahkan berkas lamanya sendiri supaya keputusannya sadar.
#
# Tapi menolak jalan sama sekali juga salah, dan itu bug yang sempat ada di
# sini: langkah cadangan di bawah sengaja menyuruh berhenti lalu menjalankan
# skrip ini lagi, dan jalan ulang itu mendarat persis di baris ini lalu keluar
# dengan status 1 — keystore sudah ada di disk, nol secret terpasang di GitHub,
# dan satu-satunya jalan maju ditutup oleh skripnya sendiri. Persis di titik
# paling genting: kunci sudah lahir tapi belum tercatat di mana pun.
#
# Jadi berkas yang sudah ada artinya LANJUTKAN dari langkah 3, bukan ulangi
# dari langkah 1. Yang dijaga tetap sama — langkah pembuatan kunci dilewati,
# jadi tidak ada jalan menimpa kunci lama tanpa memindahkannya lebih dulu.
LANJUTAN=0
if [ -e "$BERKAS" ]; then
    LANJUTAN=1
fi

gh auth status >/dev/null 2>&1 || {
    merah "!! \`gh\` belum login. Jalankan: gh auth login"
    exit 1
}

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

if [ "$LANJUTAN" -eq 1 ]; then
    info "Melanjutkan pemasangan secret untuk repo: ${REPO}"
    echo "Berkas : ${BERKAS}  (sudah ada — tidak ditulis atau ditimpa)"
    echo "Alias  : ${ALIAS}"
    echo
    echo "Kunci barunya tidak dibuat lagi. Yang dikerjakan cuma langkah 3 dan 4:"
    echo "memasang empat secret dan sidik jarinya ke GitHub."
    echo
    echo "Kalau yang kamu mau justru kunci BARU, batalkan di sini, pindahkan"
    echo "${BERKAS} ke tempat lain dulu, baru jalankan lagi — dan baca bagian"
    echo "\"Kalau kuncinya memang diganti\" di docs/rilis-tanda-tangan-apk.md,"
    echo "ongkosnya SELURUH teknisi uninstall-pasang manual sekali."
else
    info "Kunci akan dibuat untuk repo: ${REPO}"
    echo "Berkas : ${BERKAS}"
    echo "Alias  : ${ALIAS}"
fi
echo
read -r -p "Betul? [y/N] " jawab
# `case`, bukan `${jawab,,}`: ekspansi huruf-kecil itu bash 4+, sementara macOS
# masih mengapalkan bash 3.2 — di situ dia error sintaks, bukan sekadar salah.
case "$jawab" in
    [yY]) ;;
    *) echo "Dibatalkan."; exit 0 ;;
esac

# ------------------------------------------------------------ bikin keystore

if [ "$LANJUTAN" -eq 1 ]; then
    info "1/4 · Dilewati — keystore sudah ada"
    echo "\`${BERKAS}\` tidak ditulis dan tidak ditimpa. Langkah 3 membacanya"
    echo "(buat base64 dan sidik jarinya), tapi isinya tidak berubah."

    # Izin berkasnya tetap dipaksa, meski isinya tidak. Kunci yang dipulihkan
    # dari cadangan hampir selalu mendarat dengan izin bawaan tar/unzip/salin
    # — 644 — dan di mesin yang dipakai lebih dari satu orang itu artinya kunci
    # penanda tangan rilis kebaca pengguna lain. Jalur pembuatan di bawah sudah
    # melakukannya; jalur lanjutan dulu tidak, jadi justru kunci yang paling
    # mungkin salah izin yang paling luput.
    chmod 600 "$BERKAS"
else
    info "1/4 · Membuat keystore"
    echo "Isian yang disarankan (docs/rilis-tanda-tangan-apk.md):"
    echo "  First and last name (CN) : PT Sidik Kalibrasi"
    echo "  Organizational unit      : Rilis"
    echo "  Country code             : ID"
    echo "Password: panjang & acak. Simpan di password manager SEKARANG."
    echo

    # `-validity 10000` ≈ 27 tahun. Sertifikat yang kedaluwarsa menghadirkan
    # persis masalah yang dokumen ini tutup, bertahun kemudian, waktu tidak ada
    # lagi yang ingat sebabnya.
    keytool -genkeypair -v \
        -keystore "$BERKAS" \
        -keyalg RSA -keysize 4096 -validity 10000 \
        -alias "$ALIAS"

    chmod 600 "$BERKAS"
    hijau "✓ ${BERKAS} dibuat (mode 600)."
fi

# ------------------------------------------------------------------ cadangan

info "2/4 · Cadangan — berhenti di sini sampai beneran selesai"
cat <<'CATATAN'
Keystore yang hilang TIDAK BISA dibuat ulang. Tidak ada pemulihan, tidak ada
dukungan yang bisa dimintai. Hilang berarti setiap teknisi harus uninstall
manual lagi, dan semuanya kehilangan token serta foto profilnya lagi.

Salin ke MINIMAL DUA tempat di luar repo — misalnya password manager dan drive
terenkripsi. Passwordnya ikut, di tempat yang sama.
CATATAN
echo
read -r -p "Cadangannya sudah benar-benar tersimpan di dua tempat? [y/N] " cadang
case "$cadang" in [yY]) sudah=1 ;; *) sudah=0 ;; esac
if [ "$sudah" -ne 1 ]; then
    echo
    echo "Oke, berhenti di sini. Keystore-nya sudah ada di ${BERKAS} dan masih utuh."
    echo
    echo "Selesaikan cadangannya, lalu jalankan perintah yang sama lagi:"
    echo
    echo "    $0"
    echo
    echo "Karena ${BERKAS} sudah ada, jalan kedua itu melewati pembuatan kunci"
    echo "dan langsung lanjut ke pemasangan secret. Kunci yang sekarang tidak"
    echo "ditimpa, dan tidak ada kunci baru yang dibuat."
    exit 0
fi

# -------------------------------------------------------------------- secret

info "3/4 · Memeriksa kunci, lalu memasang empat secret ke ${REPO}"

# Pemeriksaan ini berdiri SEBELUM satu pun secret ditulis, dan urutannya bukan
# selera. `[ -e "$BERKAS" ]` di atas menerima berkas apa saja yang kebetulan
# bernama sama: unduhan yang terpotong, salinan cadangan yang gagal separuh,
# berkas lain yang salah nama. Dulu pemeriksaannya jatuh di langkah 4 — sesudah
# unggahan — jadi berkas semacam itu sudah terlanjur menimpa
# ANDROID_KEYSTORE_BASE64 yang tadinya benar, dan rusaknya baru ketahuan
# berbulan kemudian waktu rilis gagal ditandatangani.
#
# Satu `keytool -list` menjawab dua pertanyaan sekaligus: berkasnya keystore
# beneran, dan alias yang dicari memang ada di dalamnya. Hasilnya (sidik jari)
# dipakai lagi di langkah 4, jadi passwordnya cukup diminta sekali di sini.
echo "Password keystore diminta sekarang, untuk membuktikan berkasnya benar"
echo "sebelum ada satu pun secret yang ditimpa."
echo

# Sidik jarinya boleh ditahan di variabel — dia tercetak di tiap APK yang sudah
# terpasang, jadi bukan rahasia. Passwordnya TIDAK, dan tetap tidak: `keytool`
# yang menanyakannya sendiri, dan nilainya tidak pernah mampir ke shell.
SIDIK="$(keytool -list -v -keystore "$BERKAS" -alias "$ALIAS" \
    | grep -m1 'SHA256:' | sed 's/.*SHA256: *//' | tr -d '[:space:]')" || SIDIK=""

if [ -z "$SIDIK" ]; then
    merah "!! \`${BERKAS}\` tidak terbaca sebagai keystore berisi alias \`${ALIAS}\`."
    merah "   Sebabnya salah satu dari: passwordnya salah, berkasnya bukan keystore,"
    merah "   berkasnya rusak/terpotong, atau aliasnya memang beda."
    merah ""
    merah "   Tidak ada secret yang diubah — yang terpasang sekarang masih yang lama."
    merah "   Periksa dulu dengan:"
    merah "     keytool -list -v -keystore ${BERKAS}"
    exit 1
fi
hijau "✓ ${BERKAS} terbaca, alias ${ALIAS} ada."
echo

# macOS tidak punya `-w0`; bawaannya sudah satu baris.
# Diuji dengan MENJALANKANNYA, bukan membaca `--help`: di macOS `base64
# --help` keluar dengan status error dan teksnya beda bentuk, jadi grep ke situ
# memilih cabang yang salah tanpa ada yang tahu sampai secretnya isinya rusak.
if base64 -w0 </dev/null >/dev/null 2>&1; then
    base64 -w0 "$BERKAS" | gh secret set ANDROID_KEYSTORE_BASE64
else
    base64 -i "$BERKAS" | gh secret set ANDROID_KEYSTORE_BASE64
fi
hijau "✓ ANDROID_KEYSTORE_BASE64"

printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS
hijau "✓ ANDROID_KEY_ALIAS (${ALIAS})"

echo
echo "Dua password berikut dibaca tanpa ditampilkan, dan tidak disimpan di mana pun."
gh secret set ANDROID_KEYSTORE_PASSWORD
hijau "✓ ANDROID_KEYSTORE_PASSWORD"
gh secret set ANDROID_KEY_PASSWORD
hijau "✓ ANDROID_KEY_PASSWORD"

# ------------------------------------------------------------------ variable

info "4/4 · Memaku sidik jarinya"
echo "Empat secret di atas menjawab \"ada kunci\". Yang ini menjawab \"kunci yang MANA\"."
echo

# Variable, BUKAN Secret. Sidik jari sertifikat tercetak di tiap APK yang sudah
# terpasang di HP mana pun — menyembunyikannya tidak menambah keamanan, dan
# menyensornya jadi `***` di log bikin tidak kebaca waktu mencari sebab gagal.
printf '%s' "$SIDIK" | gh variable set APK_SHA256
hijau "✓ APK_SHA256 = ${SIDIK}"

# ------------------------------------------------------------------- penutup

info "Selesai — dan satu hal yang harus direncanakan SEBELUM rilis"
cat <<'CATATAN'
Rilis pertama dengan kunci ini TIDAK BISA menimpa APK yang sekarang terpasang
di HP teknisi. Yang sekarang ditandatangani kunci debug acak, jadi Android
menolaknya dengan "App not installed" tanpa menyebut sebab.

Semua teknisi harus uninstall manual SEKALI — dan itu menghapus token login
serta foto profil lokal mereka. Kabari dulu, jangan sampai mereka mengalaminya
tanpa peringatan lalu mengira aplikasinya rusak.

Sesudah itu selesai selamanya: rilis kedua dan seterusnya memakai kunci yang
sama, dan tombol "Update" bekerja seperti seharusnya.

Rilisnya: tab Actions → "APK rilis (nyambung server)" → Run workflow.
CATATAN
