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
# $PROFILE.CurrentUserCurrentHost NAMANYA IKUT NAMA HOST:
#   PowerShell biasa (ConsoleHost)          -> Microsoft.PowerShell_profile.ps1
#   PowerShell Integrated Console di VS Code -> Microsoft.VSCode_profile.ps1
# Jadi blok yang ditulis dari jendela PowerShell biasa TIDAK pernah kebaca di
# terminal VS Code, dan gagalnya senyap: prompt di situ tetap bawaan tanpa satu
# pun pesan error.
#
# profile.ps1 (CurrentUserAllHosts) dibaca SEMUA host, jadi itu yang dipakai.
$Profil = $PROFILE.CurrentUserAllHosts

# Berkas per-host tetap dibersihkan: versi skrip sebelumnya menulis ke situ, dan
# kalau ditinggal, prompt-nya diinisialisasi dua kali.
$DirProfil  = Split-Path -Parent $Profil
$ProfilLama = @(
    $PROFILE.CurrentUserCurrentHost
    Join-Path $DirProfil 'Microsoft.PowerShell_profile.ps1'
    Join-Path $DirProfil 'Microsoft.VSCode_profile.ps1'
) | Where-Object { $_ -and $_ -ne $Profil } | Select-Object -Unique

Write-Host "=== Prompt terminal - sidik-calibration-mobile ===" -ForegroundColor White

# Buang blok bertanda dari SATU berkas. Mengembalikan $true kalau ada yang dibuang.
function Remove-BlokDari {
    param([Parameter(Mandatory)][string]$Berkas)

    if (-not (Test-Path $Berkas)) { return $false }
    $isi = Get-Content $Berkas -ErrorAction SilentlyContinue
    if ($null -eq $isi) { return $false }
    if (-not ($isi -contains $Mulai)) { return $false }

    $baru = New-Object System.Collections.Generic.List[string]
    $didalam = $false
    foreach ($baris in $isi) {
        if ($baris -eq $Mulai) { $didalam = $true; continue }
        if ($baris -eq $Akhir) { $didalam = $false; continue }
        if (-not $didalam) { $baru.Add($baris) }
    }
    Set-Content -Path $Berkas -Value $baru -Encoding UTF8
    return $true
}

# Bersihkan profil semua-host DAN berkas per-host peninggalan versi lama.
# Dipakai waktu cabut maupun waktu pasang ulang (supaya tidak dobel).
function Remove-BlokSidik {
    $dibersihkan = @()
    foreach ($berkas in (@($Profil) + $ProfilLama)) {
        if (Remove-BlokDari -Berkas $berkas) { $dibersihkan += $berkas }
    }
    return $dibersihkan
}

# ------------------------------------------------------------------ cabut
if ($Cabut) {
    Write-Bagian 'cabut'
    $dibersihkan = Remove-BlokSidik
    if ($dibersihkan) {
        foreach ($berkas in $dibersihkan) { Write-Ok "blok oh-my-posh dihapus dari $berkas" }
    } else {
        Write-Info 'tidak ada blok oh-my-posh di profil mana pun - tidak ada yang perlu dicabut'
    }
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
    # Sengaja TIDAK memakai skrip resmi ohmyposh.dev: skrip itu memasang paket
    # MSIX, dan MSIX bisa ditolak Windows dengan 0x80073CF6 /
    # "cannot create the AppContainer profile" — gagal yang tidak ada
    # hubungannya dengan oh-my-posh dan tidak bisa dibetulkan dari sini.
    #
    # Binary mandiri dari GitHub Releases melewati seluruh mesin MSIX: satu
    # berkas .exe, ditaruh di folder milik user, tanpa admin dan tanpa
    # AppContainer.
    Write-Info 'winget tidak ada - mengunduh binary mandiri...'

    $arsitektur = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $namaAset   = "posh-windows-$arsitektur.exe"
    $rilis      = 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download'
    $unduhDari  = "$rilis/$namaAset"
    $unduhSum   = "$rilis/checksums.txt"
    $dirBin     = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin'
    $exe        = Join-Path $dirBin 'oh-my-posh.exe'

    try {
        New-Item -ItemType Directory -Force -Path $dirBin | Out-Null
        # TLS 1.2 dipaksa: Windows PowerShell 5.1 masih default ke SSL3/TLS1,
        # dan GitHub menolaknya — gagalnya muncul sebagai "connection closed".
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $lamaProgres = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'   # tanpa ini unduhan jadi lambat sekali

        # checksums.txt DULUAN, baru binary-nya. Urutannya disengaja: kalau rilis
        # baru terbit persis di tengah dua unduhan ini, yang kepegang checksum
        # LAMA dan binary BARU — dan itu mendarat sebagai "tidak cocok", bukan
        # lolos diam-diam. Jendelanya beberapa detik dan akibatnya cuma gagal
        # palsu yang bisa diulang; kebalikannya jauh lebih mahal.
        #
        # Diunduh ke berkas lalu dibaca, BUKAN diambil dari `.Content`: GitHub
        # menyajikan checksums.txt sebagai `application/octet-stream`, dan untuk
        # tipe itu PowerShell 7 memulangkan `Byte[]`, bukan teks. Regex di bawah
        # jadi mengadu string "52 98 51 ..." dan TIDAK PERNAH cocok — penjaganya
        # berubah jadi penolak SEMUA pemasangan, bukan penolak yang jahat saja.
        # Ketahuan waktu diadu ke berkas rilis sungguhan, bukan waktu dibaca.
        $berkasSum = Join-Path ([System.IO.Path]::GetTempPath()) "posh-checksums-$PID.txt"
        Invoke-WebRequest -Uri $unduhSum -OutFile $berkasSum -UseBasicParsing
        $daftarSum = Get-Content -Path $berkasSum -Raw
        Remove-Item $berkasSum -Force -ErrorAction SilentlyContinue

        Invoke-WebRequest -Uri $unduhDari -OutFile $exe -UseBasicParsing
        $ProgressPreference = $lamaProgres

        # Penjaga pertama: header MZ. Dia TIDAK menggantikan checksum di bawah —
        # gunanya cuma bikin kegagalan yang paling sering jadi kebaca. Yang
        # biasanya mendarat di sini halaman login wifi/proxy yang kesimpan jadi
        # .exe, dan "bukan program Windows" jauh lebih menolong buat yang baca
        # daripada "hash-nya beda".
        $awal = [System.IO.File]::ReadAllBytes($exe)[0..1]
        if (-not ($awal[0] -eq 0x4D -and $awal[1] -eq 0x5A)) {
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
            throw "berkas yang terunduh bukan program Windows yang sah"
        }

        # Penjaga kedua, dan ini yang sebenarnya menjaga: SHA256 diadu ke
        # checksums.txt milik rilis yang sama.
        #
        # Barisnya dicari lewat NAMA berkas, bukan nomor baris — urutan isi
        # checksums.txt bukan janji apa pun. `\*?` ikut ditoleransi karena
        # format sha256sum menandai mode biner dengan bintang.
        $polaSum = '(?m)^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($namaAset) + '\s*$'
        $cocok   = [regex]::Match($daftarSum, $polaSum)

        # GAGAL TERTUTUP. checksums.txt tidak keunduh, atau asetnya tidak
        # terdaftar di situ → pemasangan DIHENTIKAN, bukan diteruskan tanpa
        # verifikasi. Pemeriksaan yang diam-diam berubah jadi "tidak diperiksa"
        # lebih buruk daripada tidak ada pemeriksaan sama sekali: yang pertama
        # terbaca sebagai sudah diverifikasi.
        if (-not $cocok.Success) {
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
            throw "checksum buat $namaAset nggak ada di $unduhSum - pemasangan dihentikan"
        }

        $sumHarap = $cocok.Groups[1].Value.ToLowerInvariant()
        $sumNyata = (Get-FileHash -Path $exe -Algorithm SHA256).Hash.ToLowerInvariant()

        if ($sumNyata -ne $sumHarap) {
            # Berkasnya DIHAPUS, bukan ditinggal. Folder ini sebentar lagi
            # didaftarkan ke PATH, dan .exe yang sudah ditolak nggak boleh
            # nangkring di sana buat kejalan belakangan.
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
            throw "checksum nggak cocok. Harusnya $sumHarap, yang terunduh $sumNyata - berkasnya dihapus"
        }

        Write-Ok "checksum SHA256 cocok - $($sumHarap.Substring(0, 16))..."

        # Daftarkan ke PATH milik user (bukan mesin): tidak butuh admin.
        $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($pathUser -notlike "*$dirBin*") {
            [Environment]::SetEnvironmentVariable('Path', "$dirBin;$pathUser", 'User')
        }
        $env:Path = "$dirBin;$env:Path"

        Write-Ok "terpasang di $dirBin - $(& $exe version)"
    } catch {
        Write-Gagal "pemasangan gagal: $($_.Exception.Message)"
        # Sengaja TIDAK bilang "unduh manual lalu simpan sebagai .exe" begitu
        # saja: kalau yang barusan gagal justru checksum-nya, saran itu menyuruh
        # orang melewati satu-satunya penjagaan yang ada.
        Write-Info 'Kalau yang gagal checksum-nya: bisa jadi rilis baru terbit pas unduhan lagi jalan.'
        Write-Info 'Jalankan skrip ini sekali lagi dulu.'
        Write-Info "Kalau tetap gagal, JANGAN pakai berkas tadi. Unduh $unduhDari dan $unduhSum,"
        Write-Info "cocokkan sendiri (Get-FileHash <berkas> -Algorithm SHA256), baru simpan sebagai $exe"
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

# Buang dulu dari profil semua-host DAN berkas per-host versi lama, supaya
# prompt tidak diinisialisasi dua kali.
$dibersihkan = Remove-BlokSidik
foreach ($berkas in $dibersihkan) {
    if ($berkas -ne $Profil) { Write-Info "blok versi lama dibuang dari $berkas" }
}

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
Write-Info 'Terminal yang sudah terlanjur kebuka (termasuk di VS Code) tidak ikut'
Write-Info 'berubah - profil cuma dibaca waktu shell start. Tutup, buka lagi.'
Write-Info 'Kalau ikonnya masih kotak-kotak, font terminalnya belum diganti -'
Write-Info 'langkahnya per-aplikasi ada di docs/terminal-cantik.md'
Write-Host ""
