#!/usr/bin/env bash
#
# Bikin prompt terminal jadi enak dibaca — di mesin mana pun, shell apa pun.
#
#   ./tool/pasang-terminal.sh              # pasang + atur shell yang lagi dipakai
#   ./tool/pasang-terminal.sh --tanpa-font # lewati pemasangan font
#   ./tool/pasang-terminal.sh --tautan     # symlink ke tema di repo (buat ngoprek tema)
#   ./tool/pasang-terminal.sh --cabut      # balikin seperti semula
#
# Kenapa ada skrip ini: prompt bawaan cuma nampilin path. Tiga hal yang paling
# sering bikin salah langkah di project ini justru tidak kelihatan sama sekali —
# lagi di branch apa, kerjaan yang belum di-commit, dan versi Flutter yang lagi
# aktif. Yang terakhir itu yang mahal: CI mematok 3.44.6 (lihat
# docs/sinkron-laptop-windows.md), dan mesin yang versinya beda menghasilkan
# "hijau di CI, merah di laptop".
#
# Mesinnya oh-my-posh (github.com/JanDeDobbeleer/oh-my-posh) — satu binary Go,
# satu berkas tema JSON, dan dia yang bikin baris prompt buat shell apa pun.
# Temanya sendiri ada di tool/terminal/sidik.omp.json, warnanya diambil dari
# palet yang sama dengan aplikasinya (lib/core/theme/app_colors.dart).
#
# Temanya DISALIN ke ~/.config/oh-my-posh/, bukan dibaca langsung dari repo.
# Alasannya: prompt harus tetap hidup di folder mana pun — termasuk waktu repo
# ini lagi di-`git clean`, dipindah, atau belum di-clone di mesin itu. Kalau
# temanya ikut hilang, yang rusak bukan cuma tampilan tapi seluruh prompt.
# Buat ngoprek temanya sendiri, pakai --tautan.
#
# Jalan di macOS dan Linux (bash/zsh/fish). Windows: pakai tool/pasang-terminal.ps1.
# Sengaja tidak pakai fitur bash 4 — bash bawaan macOS masih 3.2.

set -uo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"

TEMA_ASAL="$REPO/tool/terminal/sidik.omp.json"
TUJUAN_DIR="$HOME/.config/oh-my-posh"
TEMA="$TUJUAN_DIR/sidik.omp.json"

# Penanda blok. Dipakai buat nemu & ganti blok lama, supaya skrip ini bisa
# dijalanin berkali-kali tanpa numpuk baris di rc-file.
MULAI="# >>> oh-my-posh (sidik) >>>"
AKHIR="# <<< oh-my-posh (sidik) <<<"

PASANG_FONT=1
PAKAI_TAUTAN=0
CABUT=0

ok()      { printf '  \033[32m✓\033[0m %s\n' "$1"; }
info()    { printf '  \033[33m·\033[0m %s\n' "$1"; }
gagal()   { printf '  \033[31m✗\033[0m %s\n' "$1" >&2; }
bagian()  { printf '\n\033[1m[%s]\033[0m\n' "$1"; }

for arg in "$@"; do
  case "$arg" in
    --tanpa-font) PASANG_FONT=0 ;;
    --tautan)     PAKAI_TAUTAN=1 ;;
    --cabut)      CABUT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
      exit 0 ;;
    *)
      gagal "opsi tidak dikenal: $arg"
      echo "  pakai: ./tool/pasang-terminal.sh [--tanpa-font] [--tautan] [--cabut]" >&2
      exit 64 ;;
  esac
done

printf '\033[1m=== Prompt terminal — sidik-calibration-mobile ===\033[0m\n'

# ------------------------------------------------------------------ shell
# $SHELL itu shell login, bukan yang lagi jalan. Itu justru yang kita mau:
# berkas rc yang diedit harus punya shell yang kebuka tiap hari, bukan punya
# bash yang cuma dipakai buat ngejalanin skrip ini.
SHELL_NAMA="$(basename "${SHELL:-bash}")"
case "$SHELL_NAMA" in
  zsh)  RC="$HOME/.zshrc" ;;
  fish) RC="$HOME/.config/fish/config.fish" ;;
  bash)
    # macOS ngejalanin ~/.bash_profile buat shell login (yang dipakai Terminal
    # .app), Linux ngejalanin ~/.bashrc. Salah pilih = blok-nya nggak pernah
    # kebaca, dan gagalnya senyap.
    if [ "$(uname -s)" = "Darwin" ]; then RC="$HOME/.bash_profile"; else RC="$HOME/.bashrc"; fi ;;
  *)
    gagal "shell '$SHELL_NAMA' belum didukung skrip ini."
    echo "  Dukungan: bash, zsh, fish. Buat shell lain, lihat docs/terminal-cantik.md" >&2
    exit 1 ;;
esac

# ------------------------------------------------------------------ cabut
buang_blok() {
  [ -f "$RC" ] || return 0
  grep -qF "$MULAI" "$RC" || return 0
  # sed rentang penanda: aman walau isi bloknya berubah di versi berikutnya.
  sed "/$(printf '%s' "$MULAI" | sed 's/[][\.*^$\/]/\\&/g')/,/$(printf '%s' "$AKHIR" | sed 's/[][\.*^$\/]/\\&/g')/d" \
    "$RC" > "$RC.tmp-sidik" && mv "$RC.tmp-sidik" "$RC"
}

if [ "$CABUT" -eq 1 ]; then
  bagian "cabut"
  buang_blok
  ok "blok oh-my-posh dihapus dari $RC"
  rm -f "$TEMA" && ok "tema dihapus dari $TEMA"
  info "binary oh-my-posh & font-nya sengaja dibiarkan — dipakai project lain juga."
  info "Buka terminal baru buat lihat hasilnya."
  exit 0
fi

# ------------------------------------------------------------------ binary
bagian "oh-my-posh"

if command -v oh-my-posh >/dev/null 2>&1; then
  ok "sudah terpasang — $(oh-my-posh version 2>/dev/null || echo '?')"
elif command -v brew >/dev/null 2>&1; then
  info "memasang lewat Homebrew..."
  if brew install jandedobbeleer/oh-my-posh/oh-my-posh; then
    ok "terpasang — $(oh-my-posh version 2>/dev/null || echo '?')"
  else
    gagal "brew install gagal."; exit 1
  fi
else
  # Pasang ke ~/.local/bin, bukan /usr/local/bin: tidak butuh sudo, dan tidak
  # nabrak paket yang dipasang package manager.
  info "memasang ke ~/.local/bin (tanpa sudo)..."
  mkdir -p "$HOME/.local/bin"
  if curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"; then
    export PATH="$HOME/.local/bin:$PATH"
    ok "terpasang — $(oh-my-posh version 2>/dev/null || echo '?')"
  else
    gagal "pemasangan gagal. Coba manual: https://ohmyposh.dev/docs/installation/linux"
    exit 1
  fi
fi

# ------------------------------------------------------------------ tema
bagian "tema"

if [ ! -f "$TEMA_ASAL" ]; then
  gagal "tema tidak ketemu: $TEMA_ASAL"
  echo "  Jalankan skrip ini dari dalam repo sidik-calibration-mobile." >&2
  exit 1
fi

mkdir -p "$TUJUAN_DIR"
rm -f "$TEMA"
if [ "$PAKAI_TAUTAN" -eq 1 ]; then
  ln -s "$TEMA_ASAL" "$TEMA"
  ok "tema di-symlink ke repo — perubahan di repo langsung kepakai"
  info "prompt bakal rusak kalau repo ini dipindah/dihapus. Jalankan ulang tanpa --tautan buat balik aman."
else
  cp "$TEMA_ASAL" "$TEMA"
  ok "tema disalin ke $TEMA"
  info "kalau temanya diubah di repo, jalankan skrip ini lagi biar salinannya ikut baru."
fi

# ------------------------------------------------------------------ font
bagian "font"

# Prompt-nya pakai glyph Nerd Font (ikon folder, cabang git, logo Flutter).
# Tanpa font yang benar, glyph itu muncul jadi kotak kosong — tampilannya
# rusak walau konfignya betul. Ini penyebab nomor satu "kok jelek?".
if [ "$PASANG_FONT" -eq 0 ]; then
  info "dilewati (--tanpa-font). Pastikan terminalmu sudah pakai Nerd Font."
elif fc-list 2>/dev/null | grep -qi "nerd font"; then
  ok "Nerd Font sudah ada di sistem"
elif [ "$(uname -s)" = "Darwin" ] && ls ~/Library/Fonts 2>/dev/null | grep -qi "nerd"; then
  ok "Nerd Font sudah ada di ~/Library/Fonts"
else
  info "memasang MesloLGM Nerd Font..."
  if oh-my-posh font install meslo >/dev/null 2>&1; then
    ok "font terpasang"
  else
    info "pemasangan otomatis gagal — pasang manual dari nerdfonts.com"
  fi
  info "SETELAH ini: set font terminalmu ke 'MesloLGM Nerd Font' (lihat docs/terminal-cantik.md)"
fi

# ------------------------------------------------------------------ rc
bagian "$SHELL_NAMA"

buang_blok   # buang blok lama dulu, biar tidak dobel waktu dijalanin ulang
mkdir -p "$(dirname "$RC")"
touch "$RC"

# ~/.local/bin ikut ditulis ke PATH di dalam blok. Kalau binary-nya ada di situ
# tapi PATH-nya belum, tiap shell baru bakal buka dengan error "command not
# found" — yang bikin orang ngira skrip ini gagal.
{
  echo ""
  echo "$MULAI"
  echo "# Ditulis oleh tool/pasang-terminal.sh. Jangan diedit tangan —"
  echo "# jalankan ulang skripnya, atau --cabut buat menghapus."
  if [ "$SHELL_NAMA" = "fish" ]; then
    echo "if test -d \$HOME/.local/bin"
    echo "    fish_add_path \$HOME/.local/bin"
    echo "end"
    echo "if type -q oh-my-posh"
    echo "    oh-my-posh init fish --config \"$TEMA\" | source"
    echo "end"
  else
    echo "[ -d \"\$HOME/.local/bin\" ] && case \":\$PATH:\" in *\":\$HOME/.local/bin:\"*) ;; *) PATH=\"\$HOME/.local/bin:\$PATH\";; esac"
    echo "command -v oh-my-posh >/dev/null 2>&1 && eval \"\$(oh-my-posh init $SHELL_NAMA --config '$TEMA')\""
  fi
  echo "$AKHIR"
} >> "$RC"

ok "blok init ditulis ke $RC"

# ------------------------------------------------------------------ tutup
bagian "selesai"
info "Buka terminal BARU (atau: exec $SHELL_NAMA) buat lihat hasilnya."
info "Kalau ikonnya masih kotak-kotak, font terminalnya belum diganti —"
info "langkahnya per-aplikasi ada di docs/terminal-cantik.md"
echo ""
