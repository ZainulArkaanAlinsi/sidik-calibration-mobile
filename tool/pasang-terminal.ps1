#Requires -Version 5.1
<#
.SYNOPSIS
    Bikin prompt terminal jadi enak dibaca di Windows (PowerShell).

.DESCRIPTION
    Kenapa ada skrip ini: prompt bawaan cuma nampilin path. Tiga hal yang paling
    sering bikin salah langkah di project ini justru tidak kelihatan sama sekali —
    lagi di branch apa, kerjaan yang belum di-commit, dan versi Flutter yang lagi
    aktif. Yang terakhir itu yang mahal: CI mematok 3.44.6 (lihat
    docs/sinkron-laptop-windows.md), dan mesin yang versinya beda menghasilkan
    "hijau di CI, merah di laptop".

    Mesinnya oh-my-posh (github.com/JanDeDobbeleer/oh-my-posh) — satu binary Go,
    satu berkas tema JSON, dan dia yang bikin baris prompt buat shell apa pun.
    Temanya ada di tool/terminal/sidik.omp.json, warnanya diambil dari palet yang
    sama dengan aplikasinya (lib/core/theme/app_colors.dart).

    Temanya DISALIN ke ~\.config\oh-my-posh\, bukan dibaca langsung dari repo,
    supaya prompt tetap hidup di folder mana pun — termasuk waktu repo ini lagi
    dipindah atau belum di-clone. Buat ngoprek temanya sendiri, pakai -Tautan.

    Ini pasangan Windows dari tool/pasang-terminal.sh. Kalau kamu pakai Git Bash
    atau WSL, jalankan yang .sh — bukan yang ini.

.PARAMETER TanpaFont
    Lewati pemasangan Nerd Font.

.PARAMETER Tautan
    Symlink ke tema di repo, bukan menyalin (butuh Developer Mode / admin).

.PARAMETER Cabut
    Balikin seperti semula.

.EXAMPLE
    .\tool\pasang-terminal.ps1
.EXAMPLE
    .\tool\pasang-terminal.ps1 -Cabut
#>
[CmdletBinding()]
param(
    [switch]$TanpaFont,
    [switch]$Tautan,
    [switch]$Cabut
)

$ErrorActionPreference = 'Stop'

# Penanda blok. Dipakai buat nemu & ganti blok lama, supaya skrip ini bisa
# dijalanin berkali-kali tanpa numpuk baris di profil.
$Mulai = '# >>> oh-my-posh (sidik) >>>'
$Akhir = '# <<< oh-my-posh (sidik) <<<'

function Write-Ok      { param($t) Write-Host "  " -NoNewline; Write-Host "OK" -ForegroundColor Green -NoNewline; Write-Host " $t" }
function Write-Info    { param($t) Write-Host "  " -NoNewline; Write-Host "--" -ForegroundColor Yellow -NoNewline; Write-Host " $t" }
function Write-Gagal   { param($t) Write-Host "  " -NoNewline; Write-Host "!!" -ForegroundColor Red -NoNewline; Write-Host " $t" }
function Write-Bagian  { param($t) Write-Host ""; Write-Host "[$t]" -ForegroundColor White }

$RepoRoot  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TemaAsal  = Join-Path $RepoRoot 'tool\terminal\sidik.omp.json'
$TujuanDir = Join-Path $HOME '.config\oh-my-posh'
$Tema      = Join-Path $TujuanDir 'sidik.omp.json'
$Profil    = $PROFILE.CurrentUserCurrentHost

Write-Host "=== Prompt terminal - sidik-calibration-mobile ===" -ForegroundColor White

# Buang blok lama dari profil. Dipakai dua-duanya: waktu cabut, dan waktu pasang
# ulang (supaya tidak dobel).
function Remove-BlokSidik {
    if (-not (Test-Path $Profil)) { return }
    $isi = Get-Content $Profil -ErrorAction SilentlyContinue
    if ($null -eq $isi) { return }
    if (-not ($isi -contains $Mulai)) { return }

    $baru = New-Object System.Collections.Generic.List[string]
    $didalam = $false
    foreach ($baris in $isi) {
        if ($baris -eq $Mulai) { $didalam = $true; continue }
        if ($baris -eq $Akhir) { $didalam = $false; continue }
        if (-not $didalam) { $baru.Add($baris) }
    }
    Set-Content -Path $Profil -Value $baru -Encoding UTF8
}

# ------------------------------------------------------------------ cabut
if ($Cabut) {
    Write-Bagian 'cabut'
    Remove-BlokSidik
    Write-Ok "blok oh-my-posh dihapus dari $Profil"
    if (Test-Path $Tema) { Remove-Item $Tema -Force; Write-Ok "tema dihapus dari $Tema" }
    Write-Info 'binary oh-my-posh & font-nya sengaja dibiarkan - dipakai project lain juga.'
    Write-Info 'Buka terminal baru buat lihat hasilnya.'
    return
}

# ------------------------------------------------------------------ binary
Write-Bagian 'oh-my-posh'

function Update-PathDariRegistry {
    # winget menaruh oh-my-posh di PATH lewat registry, tapi sesi PowerShell yang
    # lagi jalan tidak ikut baru. Tanpa ini, langkah berikutnya gagal dengan
    # "command not found" padahal pemasangannya berhasil.
    $mesin = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user  = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($mesin, $user | Where-Object { $_ }) -join ';'
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Ok "sudah terpasang - $(oh-my-posh version)"
}
elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Info 'memasang lewat winget...'
    winget install JanDeDobbeleer.OhMyPosh --source winget --accept-source-agreements --accept-package-agreements
    Update-PathDariRegistry
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Ok "terpasang - $(oh-my-posh version)"
    } else {
        Write-Gagal 'winget selesai tapi oh-my-posh belum kebaca. Tutup & buka lagi PowerShell, jalankan skrip ini sekali lagi.'
        return
    }
}
else {
    Write-Info 'winget tidak ada - memasang lewat skrip resmi...'
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
        Update-PathDariRegistry
        Write-Ok "terpasang - $(oh-my-posh version)"
    } catch {
        Write-Gagal "pemasangan gagal: $($_.Exception.Message)"
        Write-Info 'Coba manual: https://ohmyposh.dev/docs/installation/windows'
        return
    }
}

# ------------------------------------------------------------------ tema
Write-Bagian 'tema'

if (-not (Test-Path $TemaAsal)) {
    Write-Gagal "tema tidak ketemu: $TemaAsal"
    Write-Info 'Jalankan skrip ini dari dalam repo sidik-calibration-mobile.'
    return
}

New-Item -ItemType Directory -Force -Path $TujuanDir | Out-Null
if (Test-Path $Tema) { Remove-Item $Tema -Force }

if ($Tautan) {
    try {
        New-Item -ItemType SymbolicLink -Path $Tema -Target $TemaAsal -ErrorAction Stop | Out-Null
        Write-Ok 'tema di-symlink ke repo - perubahan di repo langsung kepakai'
        Write-Info 'prompt bakal rusak kalau repo ini dipindah/dihapus. Jalankan ulang tanpa -Tautan buat balik aman.'
    } catch {
        # Symlink di Windows butuh Developer Mode atau admin. Kalau ditolak,
        # jangan gagal total - salin saja, hasil akhirnya tetap prompt yang jalan.
        Copy-Item $TemaAsal $Tema -Force
        Write-Info 'symlink ditolak Windows (butuh Developer Mode) - tema disalin biasa.'
        Write-Ok "tema disalin ke $Tema"
    }
} else {
    Copy-Item $TemaAsal $Tema -Force
    Write-Ok "tema disalin ke $Tema"
    Write-Info 'kalau temanya diubah di repo, jalankan skrip ini lagi biar salinannya ikut baru.'
}

# ------------------------------------------------------------------ font
Write-Bagian 'font'

# Prompt-nya pakai glyph Nerd Font (ikon folder, cabang git, logo Flutter).
# Tanpa font yang benar, glyph itu muncul jadi kotak kosong - tampilannya rusak
# walau konfignya betul. Ini penyebab nomor satu "kok jelek?".
if ($TanpaFont) {
    Write-Info 'dilewati (-TanpaFont). Pastikan terminalmu sudah pakai Nerd Font.'
}
else {
    $adaNerd = $false
    try {
        $adaNerd = @(Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts" `
                        -Filter '*Nerd*' -ErrorAction SilentlyContinue).Count -gt 0
    } catch { $adaNerd = $false }

    if ($adaNerd) {
        Write-Ok 'Nerd Font sudah ada di sistem'
    } else {
        Write-Info 'memasang MesloLGM Nerd Font...'
        try {
            oh-my-posh font install meslo
            Write-Ok 'font terpasang'
        } catch {
            Write-Info 'pemasangan otomatis gagal - pasang manual dari nerdfonts.com'
        }
        Write-Info "SETELAH ini: set font Windows Terminal ke 'MesloLGM Nerd Font' (lihat docs/terminal-cantik.md)"
    }
}

# ------------------------------------------------------------------ profil
Write-Bagian 'profil PowerShell'

Remove-BlokSidik   # buang blok lama dulu, biar tidak dobel waktu dijalanin ulang

$dirProfil = Split-Path -Parent $Profil
if (-not (Test-Path $dirProfil)) { New-Item -ItemType Directory -Force -Path $dirProfil | Out-Null }
if (-not (Test-Path $Profil))    { New-Item -ItemType File -Force -Path $Profil | Out-Null }

$blok = @(
    ''
    $Mulai
    '# Ditulis oleh tool/pasang-terminal.ps1. Jangan diedit tangan -'
    '# jalankan ulang skripnya, atau -Cabut buat menghapus.'
    'if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {'
    "    oh-my-posh init pwsh --config `"$Tema`" | Invoke-Expression"
    '}'
    $Akhir
)
Add-Content -Path $Profil -Value $blok -Encoding UTF8
Write-Ok "blok init ditulis ke $Profil"

# ------------------------------------------------------------------ tutup
Write-Bagian 'selesai'
Write-Info 'Buka PowerShell BARU buat lihat hasilnya.'
Write-Info 'Kalau ikonnya masih kotak-kotak, font terminalnya belum diganti -'
Write-Info 'langkahnya per-aplikasi ada di docs/terminal-cantik.md'
Write-Host ""
