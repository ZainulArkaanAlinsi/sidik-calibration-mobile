<#
.SYNOPSIS
  Membuat test/fixtures/excel_general_text.json dari EXCEL ASLI (COM).

.DESCRIPTION
  Kebenaran tampilan format angka "General" Excel untuk grid Studio
  (lib/widget/grid/format_general.dart). Skrip ini:
    - membuka Excel tersembunyi (Visible = false, DisplayAlerts = false),
    - membuat workbook BARU (tidak pernah disimpan), gaya Normal = Calibri 11,
    - mengisi angka SINTETIS (bukan data pelanggan) di beberapa lebar kolom
      (dan beberapa ukuran font di lembar kedua),
    - membaca Range.Text (teks tampil, termasuk ####) dan Range.Formula
      (isi bilah rumus) per sel,
    - menulis fixture JSON beserta versi Excel, DPI layar, dan lebar kolom.
  Excel selalu ditutup (Close tanpa simpan + Quit + ReleaseComObject) di blok
  finally.

  Fixture JANGAN disunting tangan: jalankan ulang skrip ini.

.EXAMPLE
  powershell -NoProfile -File tool/excel_general_fixture.ps1   (dari studio/)
#>
param(
  [string]$Keluar = (Join-Path $PSScriptRoot '..\test\fixtures\excel_general_text.json')
)

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

function Angka([string]$s) { [double]::Parse($s, $inv) }
function G17([double]$d) { $d.ToString('G17', $inv) }
function Lepas($o) {
  if ($o -ne $null) {
    try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } catch {}
  }
}

# ── nilai uji: (ekspresi, nilai double) ─────────────────────────────────────
$nilai = New-Object System.Collections.Generic.List[object]
function Tambah([string]$ekspresi, [double]$d) {
  $nilai.Add([pscustomobject]@{ ekspresi = $ekspresi; n = $d })
}

# Kasus pilihan (hasil hitung double di PowerShell = IEEE 754 yang sama
# dengan Dart & PHP).
Tambah '1/3' (1.0 / 3.0)
Tambah '2/3' (2.0 / 3.0)
Tambah '-1/3' (-1.0 / 3.0)
Tambah '1/7' (1.0 / 7.0)
Tambah '22/7' (22.0 / 7.0)
Tambah '0.1+0.2' (0.1 + 0.2)
Tambah 'pi' ([math]::PI)
Tambah 'e' ([math]::E)
Tambah 'sqrt(2)*1000' ([math]::Sqrt(2.0) * 1000.0)
foreach ($s in @(
    '0', '100', '-0.5', '0.5', '1', '-1', '10', '0.1', '0.01', '0.001',
    '0.0001', '0.00001', '0.000001', '0.000012345', '1.234E-5', '9.99999E-10',
    '1E-15', '1E-100', '1E+20', '1.5E+300', '123.456', '-123.456',
    '123456.789012345678', '-123456.789012345678', '1234567.891',
    '12345678', '123456789', '1234567890', '12345678901', '123456789012',
    '-12345678901', '-123456789012', '999999999999999', '1E+15',
    '9.99999', '99.99999', '999999.5', '9999999.5', '0.99999999',
    '0.999999999999', '99999999999', '999999999999', '0.050', '20.0004',
    '0.0010', '-0.000012345', '25.4', '1.0001', '7.5E-8', '-9.87654321E+15',
    # Pembulatan setengah: nilai biner di bawah/di atas desimalnya.
    '0.15', '0.25', '0.35', '0.45', '1.005', '2.675', '1.45', '0.125',
    '-0.15', '-2.675', '1234.5', '0.0005', '9.995', '0.045', '8.345',
    '1.0005', '4.35', '0.285', '9.9E+99', '-1E-100', '100000.4', '120000.4'
  )) { Tambah $s (Angka $s) }

# Sapuan pangkat: mantisa x 10^e, e = -25..25 (aturan pindah ke notasi
# ilmiah, batas panjang General, dan bentuk bilah rumus).
foreach ($m in @('1', '1.5', '1.2345', '1.23456789012345', '-4.56789')) {
  for ($e = -25; $e -le 25; $e++) {
    $s = "{0}E{1}" -f $m, $e
    Tambah $s (Angka $s)
  }
}

# Lebar kolom (karakter, seperti kotak "Column Width" Excel). Lembar 1 =
# font Calibri 11 (gaya Normal).
$lebar = @(1, 2, 3, 4, 4.6, 4.9, 5, 5.5, 6, 7, 7.6, 8, 8.43, 9, 10, 10.5,
  11, 12, 13, 15, 20, 30)

# Lembar 2: ukuran/tebal font sel lain (lebar kolom tetap satuan font Normal).
$fontUji = @(
  @{ ukuran = 8; tebal = $false }, @{ ukuran = 10; tebal = $false },
  @{ ukuran = 12; tebal = $false }, @{ ukuran = 14; tebal = $false },
  @{ ukuran = 16; tebal = $false }, @{ ukuran = 11; tebal = $true }
)
$lebarFont = @(5, 8.43, 11, 15)
$nilaiFont = @('1/3', '-1/3', 'pi', '123456.789012345678', '0.000012345',
  '12345678901', '-12345678901', '1E-100', '0.0001', '1234567.891')

# Isi lembar [ws] dengan [vals] di kolom-kolom [spek] (lebar, ukuran, tebal),
# lalu baca Text tiap sel. Formula & Value2 dibaca dari kolom pertama.
function IsiDanBaca($ws, $vals, $spek) {
  $jumlah = $vals.Count
  $k = $spek.Count
  $data = New-Object 'object[,]' $jumlah, $k
  for ($i = 0; $i -lt $jumlah; $i++) {
    for ($j = 0; $j -lt $k; $j++) { $data[$i, $j] = $vals[$i].n }
  }
  $a = $ws.Cells.Item(1, 1)
  $b = $ws.Cells.Item($jumlah, $k)
  $r = $ws.Range($a, $b)
  $r.NumberFormat = 'General'
  $r.Value2 = $data
  Lepas $r; Lepas $a; Lepas $b

  $kolom = New-Object System.Collections.Generic.List[object]
  for ($j = 0; $j -lt $k; $j++) {
    $c = $ws.Columns.Item($j + 1)
    if ($spek[$j].ukuran -ne $null) {
      # Font hanya di sel data (bukan seluruh kolom: Excel menyesuaikan
      # lebar kolom berlebar bawaan bila font kolomnya diganti).
      $a = $ws.Cells.Item(1, $j + 1)
      $b = $ws.Cells.Item($jumlah, $j + 1)
      $r = $ws.Range($a, $b)
      $f = $r.Font
      $f.Size = [double]$spek[$j].ukuran
      $f.Bold = [bool]$spek[$j].tebal
      Lepas $f; Lepas $r; Lepas $a; Lepas $b
    }
    $c.ColumnWidth = [double]$spek[$j].lebar
    $kolom.Add([pscustomobject]@{
      kunci = $spek[$j].kunci
      diminta = [double]$spek[$j].lebar
      column_width = [double]$c.ColumnWidth
      lebar_pt = [double]$c.Width
      ukuran = $spek[$j].ukuran
      tebal = $spek[$j].tebal
    })
    Lepas $c
  }

  $baris = New-Object System.Collections.Generic.List[object]
  for ($i = 0; $i -lt $jumlah; $i++) {
    $teks = [ordered]@{}
    $rumus = $null
    $simpan = $null
    for ($j = 0; $j -lt $k; $j++) {
      $sel = $ws.Cells.Item($i + 1, $j + 1)
      $teks[$spek[$j].kunci] = [string]$sel.Text
      if ($j -eq 0) {
        $rumus = [string]$sel.Formula
        $simpan = [double]$sel.Value2
      }
      Lepas $sel
    }
    $baris.Add([pscustomobject]@{
      ekspresi = $vals[$i].ekspresi
      n = $vals[$i].n
      tersimpan = $simpan
      bilah_rumus = $rumus
      teks = $teks
    })
  }
  return [pscustomobject]@{ kolom = $kolom; baris = $baris }
}

$xl = $null; $wb = $null; $ws = $null; $ws2 = $null
try {
  $xl = New-Object -ComObject Excel.Application
  $xl.Visible = $false
  $xl.DisplayAlerts = $false
  $xl.ScreenUpdating = $false

  $wb = $xl.Workbooks.Add()
  # Satuan lebar kolom = MDW font gaya Normal: setel Calibri 11 (Excel 365
  # baru memakai Aptos Narrow sebagai bawaan).
  $normal = $wb.Styles.Item('Normal')
  $normal.Font.Name = 'Calibri'
  $normal.Font.Size = 11
  Lepas $normal

  $ws = $wb.Worksheets.Item(1)
  $spek = @()
  foreach ($l in $lebar) {
    $spek += @{ lebar = $l; ukuran = $null; tebal = $null; kunci = $l.ToString($inv) }
  }
  $utama = IsiDanBaca $ws $nilai $spek

  $ws2 = $wb.Worksheets.Add()
  $valsFont = @($nilai | Where-Object { $nilaiFont -contains $_.ekspresi })
  $spek = @()
  foreach ($f in $fontUji) {
    foreach ($l in $lebarFont) {
      $kunci = '{0}{1}@{2}' -f $f.ukuran, $(if ($f.tebal) { 'b' } else { '' }), $l.ToString($inv)
      $spek += @{ lebar = $l; ukuran = $f.ukuran; tebal = $f.tebal; kunci = $kunci }
    }
  }
  $font = IsiDanBaca $ws2 $valsFont $spek

  $exe = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe').'(default)'
  $versiBerkas = (Get-Item $exe).VersionInfo.FileVersion
  $dpi = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI
  $meta = [ordered]@{
    excel_version = [string]$xl.Version
    excel_build = [string]$xl.Build
    excel_file_version = [string]$versiBerkas
    dpi_layar = $dpi
    font_normal = 'Calibri 11'
    zoom = 100
    pemisah_desimal = [string]$xl.DecimalSeparator
    dibuat = (Get-Date).ToString('yyyy-MM-dd', $inv)
  }
}

finally {
  if ($wb -ne $null) { try { $wb.Close($false) } catch {} }
  if ($xl -ne $null) { try { $xl.Quit() } catch {} }
  foreach ($o in @($ws2, $ws, $wb, $xl)) { Lepas $o }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}

# ── Lebar glif Calibri (GDI TextRenderer) untuk anggaran karakter General:
# digit '0', tanda minus '-', dan pagar '#', pada font berukuran pt*dpi/72 px.
#  - calibri_gdi_96dpi: 6..24 pt pada 96 dpi (= 1 px Excel per dp Studio) —
#    tabel konstanta format_general.dart (test mencocokkannya).
#  - calibri_gdi_excel: pada dpi yang DIPAKAI Excel saat fixture dibuat
#    (meta.dpi_excel). Excel 365 di layar 150 % kadang menghitung lebar kolom
#    pada 144 dpi, kadang 96 dpi (terlihat dari Width kolom); test algoritma
#    memakai metrik dpi itu.
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$bmp = New-Object System.Drawing.Bitmap 10, 10
$g = [System.Drawing.Graphics]::FromImage($bmp)
$flags = [System.Windows.Forms.TextFormatFlags]::NoPadding
$batas = New-Object System.Drawing.Size 4000, 400
function UkurCalibri([double]$dpi, [int]$pt, [bool]$tebal) {
  $gaya = if ($tebal) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  $fGdi = New-Object System.Drawing.Font('Calibri', [single]($pt * $dpi / 72.0), $gaya, [System.Drawing.GraphicsUnit]::Pixel)
  try {
    $w = @{}
    foreach ($c in @('0', '-', '#')) {
      $w[$c] = [System.Windows.Forms.TextRenderer]::MeasureText($g, ($c * 10), $fGdi, $batas, $flags).Width / 10.0
    }
    [pscustomobject]@{ pt = $pt; tebal = $tebal; digit = $w['0']; minus = $w['-']; pagar = $w['#'] }
  }
  finally { $fGdi.Dispose() }
}
$calibri = New-Object System.Collections.Generic.List[object]
$calibriExcel = New-Object System.Collections.Generic.List[object]
try {
  foreach ($tebal in @($false, $true)) {
    for ($pt = 6; $pt -le 24; $pt++) { $calibri.Add((UkurCalibri 96 $pt $tebal)) }
  }
  # dpi Excel: pt per karakter lebar kolom (kolom 30 vs 20) x dpi/72 = MDW.
  $k20 = $utama.kolom | Where-Object { $_.kunci -eq '20' }
  $k30 = $utama.kolom | Where-Object { $_.kunci -eq '30' }
  $ptPerKarakter = ($k30.lebar_pt - $k20.lebar_pt) / ($k30.column_width - $k20.column_width)
  $dpiExcel = $null
  foreach ($calon in @(96, [double]$dpi)) {
    $mdw = (UkurCalibri $calon 11 $false).digit
    if ([math]::Abs($ptPerKarakter * $calon / 72.0 - $mdw) -lt 0.05) { $dpiExcel = $calon }
  }
  if ($dpiExcel -eq $null) { throw "dpi Excel tidak dikenali (pt/karakter = $ptPerKarakter)" }
  foreach ($f in $fontUji) { $calibriExcel.Add((UkurCalibri $dpiExcel $f.ukuran $f.tebal)) }
  if (-not ($fontUji | Where-Object { $_.ukuran -eq 11 -and -not $_.tebal })) {
    $calibriExcel.Add((UkurCalibri $dpiExcel 11 $false))
  }
  $meta['dpi_excel'] = $dpiExcel
  $meta['mdw_excel_px'] = ($calibriExcel | Where-Object { $_.pt -eq 11 -and -not $_.tebal } | Select-Object -First 1).digit
}
finally { $g.Dispose(); $bmp.Dispose() }

# ── JSON ditulis sendiri: `n` dengan 17 digit (G17) supaya dibaca kembali
# PERSIS sama oleh jsonDecode Dart.
function Teks($s) {
  if ($s -eq $null) { return 'null' }
  '"' + ([string]$s -replace '\\', '\\' -replace '"', '\"') + '"'
}
function Nilai($v) {
  if ($v -eq $null) { return 'null' }
  if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
  if ($v -is [string]) { return (Teks $v) }
  return (G17 ([double]$v))
}
function JsonKolom($kolom) {
  $bagian = @()
  foreach ($c in $kolom) {
    $bagian += ('    {{"kunci": {0}, "diminta": {1}, "column_width": {2}, "lebar_pt": {3}, "ukuran": {4}, "tebal": {5}}}' -f `
        (Teks $c.kunci), (Nilai $c.diminta), (Nilai $c.column_width), (Nilai $c.lebar_pt), (Nilai $c.ukuran), (Nilai $c.tebal))
  }
  $bagian -join ",`r`n"
}
function JsonBaris($baris) {
  $bagian = @()
  foreach ($b in $baris) {
    $t = @()
    foreach ($kv in $b.teks.GetEnumerator()) { $t += ('{0}: {1}' -f (Teks $kv.Key), (Teks $kv.Value)) }
    $bagian += ('    {{"ekspresi": {0}, "n": {1}, "tersimpan": {2}, "bilah_rumus": {3}, "teks": {{{4}}}}}' -f `
        (Teks $b.ekspresi), (G17 $b.n), (Nilai $b.tersimpan), (Teks $b.bilah_rumus), ($t -join ', '))
  }
  $bagian -join ",`r`n"
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('{')
[void]$sb.AppendLine('  "_catatan": "Dibuat tool/excel_general_fixture.ps1 dari Excel asli lewat COM (Range.Text & Range.Formula). Angka sintetis. JANGAN disunting tangan.",')
$bagian = @()
foreach ($kv in $meta.GetEnumerator()) { $bagian += ('"{0}": {1}' -f $kv.Key, (Nilai $kv.Value)) }
[void]$sb.AppendLine('  "meta": {' + ($bagian -join ', ') + '},')
[void]$sb.AppendLine('  "kolom": [')
[void]$sb.AppendLine((JsonKolom $utama.kolom))
[void]$sb.AppendLine('  ],')
[void]$sb.AppendLine('  "kasus": [')
[void]$sb.AppendLine((JsonBaris $utama.baris))
[void]$sb.AppendLine('  ],')
[void]$sb.AppendLine('  "kolom_font": [')
[void]$sb.AppendLine((JsonKolom $font.kolom))
[void]$sb.AppendLine('  ],')
[void]$sb.AppendLine('  "kasus_font": [')
[void]$sb.AppendLine((JsonBaris $font.baris))
[void]$sb.AppendLine('  ],')
function JsonCalibri($daftar) {
  $bagian = @()
  foreach ($c in $daftar) {
    $bagian += ('    {{"pt": {0}, "tebal": {1}, "digit": {2}, "minus": {3}, "pagar": {4}}}' -f `
        $c.pt, (Nilai $c.tebal), (Nilai $c.digit), (Nilai $c.minus), (Nilai $c.pagar))
  }
  $bagian -join ",`r`n"
}
[void]$sb.AppendLine('  "calibri_gdi_96dpi": [')
[void]$sb.AppendLine((JsonCalibri $calibri))
[void]$sb.AppendLine('  ],')
[void]$sb.AppendLine('  "calibri_gdi_excel": [')
[void]$sb.AppendLine((JsonCalibri $calibriExcel))
[void]$sb.AppendLine('  ]')
[void]$sb.AppendLine('}')

$dir = Split-Path -Parent $Keluar
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($Keluar), $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Output ("{0} kasus x {1} lebar + {2} kasus font x {3} kolom -> {4}" -f `
    $utama.baris.Count, $utama.kolom.Count, $font.baris.Count, $font.kolom.Count, $Keluar)
