#!/usr/bin/env python3
"""Pindahkan label tombol dari HURUF BESAR ke sentence case — commit TERSENDIRI.

Kenapa terpisah dari reskin: ~300 `find.text('SETUJUI')` di test/ mencocokkan
label kapital. Reskin (warna/material/bentuk) netral terhadap test; pergantian
huruf tidak. Jadi keduanya dipisah supaya kalau test merah, sebabnya jelas.

Yang dilakukan:
  1. test/**.dart — `find.text('SETUJUI')` diganti teks ARB aslinya ('Setujui')
     bila tepat SATU nilai di app_id.arb / app_en.arb yang kapitalnya sama.
     Yang ambigu atau tidak ketemu DILAPORKAN, tidak ditebak.
  2. lib/core/theme/sidik_theme.dart — `.copyWith(foregroundBuilder: _labelTombol)`
     dicabut (label kembali apa adanya).
  3. Melaporkan `toUpperCase()` lain di lib/widgets/ yang mungkin juga
     mengkapitalkan label tombol — diperiksa tangan.

Pemakaian (dari akar repo mobile):
  python3 alat/ke_sentence_case.py           # kering: cuma laporan
  python3 alat/ke_sentence_case.py --tulis   # ubah berkas
Lalu: flutter test  (golden perlu dibuat ulang: flutter test --update-goldens)
"""
import json, pathlib, re, sys

akar = pathlib.Path('.')
tulis = '--tulis' in sys.argv

nilai = {}
for arb in ('lib/l10n/app_id.arb', 'lib/l10n/app_en.arb'):
    for k, v in json.loads((akar / arb).read_text(encoding='utf-8')).items():
        if k.startswith('@') or not isinstance(v, str):
            continue
        nilai.setdefault(v.upper(), set()).add(v)

pola = re.compile(r"find\.text\('([^'a-z]*[A-Z][^'a-z]*)'\)")
ganti, ambigu, hilang = 0, {}, {}
for f in sorted((akar / 'test').rglob('*.dart')):
    s = f.read_text(encoding='utf-8')

    def sulih(m):
        global ganti
        kapital = m.group(1)
        calon = nilai.get(kapital, set())
        # Kode seperti 'PASS', 'FAIL', 'U95' memang kapital di ARB — biarkan.
        if kapital in calon:
            return m.group(0)
        if len(calon) == 1:
            ganti += 1
            return "find.text('%s')" % next(iter(calon)).replace("'", "\\'")
        (ambigu if calon else hilang).setdefault(kapital, set()).add(str(f))
        return m.group(0)

    baru = pola.sub(sulih, s)
    if tulis and baru != s:
        f.write_text(baru, encoding='utf-8')

tema = akar / 'lib/core/theme/sidik_theme.dart'
t = tema.read_text(encoding='utf-8')
jumlah_tema = t.count('.copyWith(foregroundBuilder: _labelTombol)')
if tulis:
    tema.write_text(t.replace('.copyWith(foregroundBuilder: _labelTombol)', ''), encoding='utf-8')

print(f"{'DIUBAH' if tulis else 'AKAN DIUBAH'}: {ganti} find.text di test/, {jumlah_tema} pemasangan _labelTombol di tema")
if ambigu:
    print('\nAMBIGU (lebih dari satu teks ARB) — sunting tangan:')
    for k, fs in sorted(ambigu.items()):
        print(f"  '{k}' -> {sorted(nilai[k])}  di {len(fs)} berkas")
if hilang:
    print('\nTIDAK ADA DI ARB (teks tetap/kode, atau label hardcode) — periksa:')
    for k, fs in sorted(hilang.items()):
        print(f"  '{k}'  di {len(fs)} berkas")
print('\ntoUpperCase() lain di lib/widgets/ — periksa apakah mengkapitalkan label tombol:')
for f in sorted((akar / 'lib/widgets').rglob('*.dart')):
    for i, baris in enumerate(f.read_text(encoding='utf-8').splitlines(), 1):
        if 'toUpperCase()' in baris:
            print(f'  {f}:{i}: {baris.strip()[:90]}')
if tulis:
    print('\nSesudah ini: sunting sisa di atas, hapus _labelTombol yang tak terpakai, lalu flutter test.')
