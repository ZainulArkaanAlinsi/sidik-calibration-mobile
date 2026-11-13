import 'dart:convert';
import 'dart:io';

/// Pemindai "token-only" untuk gerbang desain Lab.
///
/// Menghitung nilai liar (warna, ukuran huruf, radius, tinggi tombol yang
/// ditulis langsung di kode) per berkas di `lib/`. Dipakai
/// `test/tema/token_only_test.dart` untuk pola ratchet DUA ARAH: hitungan
/// dibandingkan dengan baseline, dan tes gagal bila ada berkas BARU, hitungan
/// NAIK, atau hitungan TURUN tanpa baseline ikut diturunkan.
///
/// Komentar dibuang dulu supaya catatan seperti "(#585E67)" di docblock tidak
/// dihitung sebagai pelanggaran.
///
/// Pemindai ini membaca teks, bukan pohon sintaks. Ia menangkap bentuk yang
/// umum (literal, ekspresi angka murni, variabel yang di berkas yang sama
/// diisi literal angka), bukan semua cara menyelipkan angka. Cakupannya
/// dipatok di `token_only_test.dart` (daftar [dilewati], jumlah berkas minimum).
class PemindaiToken {
  const PemindaiToken._();

  /// Kategori yang dijaga, urut seperti di berkas baseline.
  ///
  /// - `hex_mentah`          literal `0xAARRGGBB`/`0xRRGGBB` atau `#RRGGBB(AA)`
  /// - `color_0x`            `Color(0x...)`
  /// - `warna_konstruktor`   `Color.fromARGB/fromRGBO/from(`, `Color(<desimal>)`,
  ///                         `HSLColor`/`HSVColor`, `CupertinoColors`
  /// - `colors_mentah`       `Colors.xxx` selain `transparent`
  /// - `fontsize_kecil`      `fontSize:` yang nilainya < 12, dari literal,
  ///                         ekspresi angka murni (`9 * 1.0`), atau variabel
  ///                         yang di berkas yang sama diisi literal angka
  /// - `radius_literal`      `Radius.circular(...)`/`BorderRadius.circular(...)`
  ///                         dengan angka (literal, ekspresi murni, atau
  ///                         variabel berisi literal)
  /// - `radius_ekspresi`     idem, dengan ekspresi campuran (`radiusLg + 4`,
  ///                         `a ? b : 8`): bukan token dan tak bisa dibuktikan
  ///                         ada di set radius. Nama murni (`radius`,
  ///                         `BentukLab.kontrol`) lolos.
  /// - `tinggi_tombol_kecil` `minimumSize`/`fixedSize` dengan tinggi literal
  ///                         < 48, dan `SizedBox(height: <48, child: <tombol>)`
  static const kategori = <String>[
    'hex_mentah',
    'color_0x',
    'warna_konstruktor',
    'colors_mentah',
    'fontsize_kecil',
    'radius_literal',
    'radius_ekspresi',
    'tinggi_tombol_kecil',
  ];

  /// Kategori warna tidak berlaku di folder sumber token: di sanalah nilai
  /// mentah memang harus ditulis (`PaletLab`, `AppColors`).
  static const _folderSumberToken = 'lib/core/theme/';
  static const _kategoriWarna = {
    'hex_mentah',
    'color_0x',
    'warna_konstruktor',
    'colors_mentah',
  };

  /// Berkas yang TIDAK dipindai, dengan alasannya. Kunci berakhiran `/` = awalan
  /// folder; selain itu = akhiran nama berkas. Menambah entri di sini harus
  /// disertai perubahan di `token_only_test.dart` (daftar yang diharapkan), jadi
  /// tidak bisa terjadi diam-diam.
  static const dilewati = <String, String>{
    'lib/l10n/':
        'dihasilkan `flutter gen-l10n` dari berkas ARB, bukan ditulis tangan',
    '.g.dart': 'dihasilkan build_runner, bukan ditulis tangan',
  };

  static bool dilewatiBerkas(String jalur) => dilewati.keys.any(
    (k) => k.endsWith('/') ? jalur.startsWith(k) : jalur.endsWith(k),
  );

  static final _hex = RegExp(
    r'\b0x[0-9A-Fa-f]{6,8}\b|#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6})\b',
  );
  static final _color0x = RegExp(r'\bColor\(\s*0x');
  static final _warnaKonstruktor = RegExp(
    r'\bColor\.from(?:ARGB|RGBO)?\(|\bColor\(\s*(?!0[xX])\d|\bHS[LV]Color\b|\bCupertinoColors\.',
  );
  static final _colors = RegExp(r'\bColors\.(?!transparent\b)[A-Za-z_]\w*');
  static final _fontSize = RegExp(r'\bfontSize:\s*');
  static final _radius = RegExp(r'Radius\.circular\(');
  static final _ukuranTombol = RegExp(r'\b(?:minimumSize|fixedSize)\s*:\s*');
  static final _sizedBoxTombol = RegExp(
    r'SizedBox\(\s*(?:width:\s*[^,()]+,\s*)?height:\s*(\d+(?:\.\d+)?)\s*,\s*child:\s*(?:const\s+)?(?:FilledButton|OutlinedButton|TextButton|ElevatedButton|IconButton|AppButton|SidikTombol)\b',
  );
  static final _jalurNama = RegExp(r'^[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*$');
  static final _nama = RegExp(r'^[A-Za-z_]\w*$');
  static final _deklarasi = RegExp(
    r'\b(?:const|final)\s+(?:double|num|int)?\s*([A-Za-z_]\w*)\s*=\s*([^;=]+);',
  );

  /// Hitung pelanggaran di [sumber] (isi satu berkas) per kategori.
  static Map<String, int> hitung(String sumber, {String jalur = ''}) {
    final kode = buangKomentar(sumber);
    final diSumberToken = jalur.startsWith(_folderSumberToken);

    // Variabel yang di berkas ini diisi literal angka: nama -> nilai.
    final literal = <String, double>{};
    for (final m in _deklarasi.allMatches(kode)) {
      final v = evaluasi(m.group(2)!);
      if (v != null) literal[m.group(1)!] = v;
    }
    double? nilai(String arg) {
      final a = arg.trim();
      return evaluasi(a) ?? (_nama.hasMatch(a) ? literal[a] : null);
    }

    var fontKecil = 0;
    for (final m in _fontSize.allMatches(kode)) {
      final v = nilai(_nilaiSetelah(kode, m.end));
      if (v != null && v < 12) fontKecil++;
    }

    var radiusAngka = 0;
    var radiusEkspresi = 0;
    for (final m in _radius.allMatches(kode)) {
      final arg = _isiKurung(kode, m.end - 1)?.trim();
      if (arg == null || arg.isEmpty) continue;
      if (nilai(arg) != null) {
        radiusAngka++;
      } else if (!_jalurNama.hasMatch(arg)) {
        radiusEkspresi++;
      }
    }

    var tombolKecil = 0;
    for (final m in _ukuranTombol.allMatches(kode)) {
      final h = _tinggiDariSize(_nilaiSetelah(kode, m.end), nilai);
      if (h != null && h < 48) tombolKecil++;
    }
    for (final m in _sizedBoxTombol.allMatches(kode)) {
      if (double.parse(m.group(1)!) < 48) tombolKecil++;
    }

    final hasil = <String, int>{
      'hex_mentah': _hex.allMatches(kode).length,
      'color_0x': _color0x.allMatches(kode).length,
      'warna_konstruktor': _warnaKonstruktor.allMatches(kode).length,
      'colors_mentah': _colors.allMatches(kode).length,
      'fontsize_kecil': fontKecil,
      'radius_literal': radiusAngka,
      'radius_ekspresi': radiusEkspresi,
      'tinggi_tombol_kecil': tombolKecil,
    };
    if (diSumberToken) {
      for (final k in _kategoriWarna) {
        hasil[k] = 0;
      }
    }
    return hasil;
  }

  /// Tinggi dari `Size(w, h)`, `Size.fromHeight(h)`, atau `Size.square(n)` di
  /// dalam [seg] (boleh dibungkus `WidgetStatePropertyAll(...)`).
  static double? _tinggiDariSize(String seg, double? Function(String) nilai) {
    for (final pola in [
      (RegExp(r'Size\.fromHeight\('), 0),
      (RegExp(r'Size\.square\('), 0),
      (RegExp(r'(?<![\w.])Size\('), 1),
    ]) {
      final m = pola.$1.firstMatch(seg);
      if (m == null) continue;
      final isi = _isiKurung(seg, m.end - 1);
      if (isi == null) return null;
      final bagian = _pisahTingkatNol(isi);
      if (pola.$2 >= bagian.length) return null;
      return nilai(bagian[pola.$2]);
    }
    return null;
  }

  /// Isi tanda kurung yang dibuka pada indeks [buka] (karakter `(`).
  static String? _isiKurung(String s, int buka) {
    var dalam = 0;
    for (var i = buka; i < s.length; i++) {
      final c = s[i];
      if (c == '(') {
        dalam++;
      } else if (c == ')') {
        dalam--;
        if (dalam == 0) return s.substring(buka + 1, i);
      }
    }
    return null;
  }

  /// Nilai argumen bernama yang mulai di [mulai], sampai `,` `)` `}` `]` `;`
  /// di kedalaman nol.
  static String _nilaiSetelah(String s, int mulai) {
    var dalam = 0;
    for (var i = mulai; i < s.length; i++) {
      final c = s[i];
      if (c == '(' || c == '[' || c == '{') {
        dalam++;
      } else if (c == ')' || c == ']' || c == '}') {
        if (dalam == 0) return s.substring(mulai, i);
        dalam--;
      } else if ((c == ',' || c == ';') && dalam == 0) {
        return s.substring(mulai, i);
      }
    }
    return s.substring(mulai);
  }

  static List<String> _pisahTingkatNol(String s) {
    final bagian = <String>[];
    var dalam = 0;
    var awal = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(' || c == '[' || c == '{') dalam++;
      if (c == ')' || c == ']' || c == '}') dalam--;
      if (c == ',' && dalam == 0) {
        bagian.add(s.substring(awal, i));
        awal = i + 1;
      }
    }
    bagian.add(s.substring(awal));
    return bagian;
  }

  /// Hitung ekspresi angka murni (`9 * 1.0`, `(14 * 0.8)`, `-3`). Mengembalikan
  /// `null` bila ada yang bukan angka (nama, pemanggilan, `?:`, dan seterusnya).
  static double? evaluasi(String teks) {
    final s = teks.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;
    var i = 0;
    var gagal = false;

    late double Function() tambah;
    late double Function() kali;
    late double Function() unari;

    unari = () {
      if (i < s.length && (s[i] == '-' || s[i] == '+')) {
        final negatif = s[i++] == '-';
        final v = unari();
        return negatif ? -v : v;
      }
      if (i < s.length && s[i] == '(') {
        i++;
        final v = tambah();
        if (i < s.length && s[i] == ')') {
          i++;
        } else {
          gagal = true;
        }
        return v;
      }
      final m = RegExp(r'\d+(?:\.\d+)?|\.\d+').matchAsPrefix(s, i);
      if (m == null) {
        gagal = true;
        return 0;
      }
      i = m.end;
      return double.parse(m.group(0)!);
    };
    kali = () {
      var v = unari();
      while (i < s.length && (s[i] == '*' || s[i] == '/')) {
        final op = s[i++];
        final r = unari();
        v = op == '*' ? v * r : (r == 0 ? double.nan : v / r);
      }
      return v;
    };
    tambah = () {
      var v = kali();
      while (i < s.length && (s[i] == '+' || s[i] == '-')) {
        final op = s[i++];
        final r = kali();
        v = op == '+' ? v + r : v - r;
      }
      return v;
    };

    final v = tambah();
    if (gagal || i != s.length || v.isNaN) return null;
    return v;
  }

  /// Pindai seluruh `lib/`. Hasil: kategori -> {jalur: hitungan} (hanya berkas
  /// dengan hitungan > 0) dan daftar jalur yang dipindai. Jalur memakai `/`.
  static HasilPindai pindai({String akar = 'lib'}) {
    final hasil = {for (final k in kategori) k: <String, int>{}};
    final dipindai = <String>[];
    final berkas =
        Directory(akar)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in berkas) {
      final jalur = f.path.replaceAll('\\', '/');
      if (dilewatiBerkas(jalur)) continue;
      dipindai.add(jalur);
      final hitungan = hitung(f.readAsStringSync(), jalur: jalur);
      for (final k in kategori) {
        final n = hitungan[k]!;
        if (n > 0) hasil[k]![jalur] = n;
      }
    }
    return HasilPindai(hasil, dipindai);
  }

  /// Serialisasi baseline dengan urutan kunci tetap supaya diff-nya terbaca.
  /// `_ringkasan` memuat jumlah berkas dipindai dan total per kategori: ini
  /// bukan pengaman (bisa diedit tangan), tetapi membuat KENAIKAN baseline
  /// kelihatan di diff dan bisa disebut di PR.
  static String keJson(HasilPindai data, {required String catatan}) {
    final peta = <String, Object>{'_catatan': catatan};
    peta['_ringkasan'] = {
      'berkas_dipindai': data.dipindai.length,
      'total': {
        for (final k in kategori)
          k: (data.hitungan[k] ?? const <String, int>{}).values.fold<int>(
            0,
            (a, b) => a + b,
          ),
      },
    };
    for (final k in kategori) {
      final isi = data.hitungan[k] ?? const <String, int>{};
      final urut = isi.keys.toList()..sort();
      peta[k] = {for (final j in urut) j: isi[j]!};
    }
    return '${const JsonEncoder.withIndent('  ').convert(peta)}\n';
  }

  /// Baca baseline dari JSON. Kategori yang tidak ada di berkas tidak muncul di
  /// hasil (kategori baru yang belum dibekukan). Kunci berawalan `_` metadata.
  static Baseline dariJson(String json) {
    final mentah = jsonDecode(json) as Map<String, dynamic>;
    final ringkasan = (mentah['_ringkasan'] as Map<String, dynamic>?) ?? {};
    return Baseline(
      {
        for (final k in kategori)
          if (mentah[k] != null)
            k: {
              for (final e in (mentah[k] as Map<String, dynamic>).entries)
                e.key: e.value as int,
            },
      },
      berkasDipindai: ringkasan['berkas_dipindai'] as int?,
      total: {
        for (final e
            in ((ringkasan['total'] as Map<String, dynamic>?) ?? {}).entries)
          e.key: e.value as int,
      },
    );
  }

  /// Buang komentar `//`, `///`, dan `/* */` tanpa menyentuh isi string.
  /// Baris baru dipertahankan supaya nomor baris tidak bergeser.
  static String buangKomentar(String s) {
    final out = StringBuffer();
    final n = s.length;
    var i = 0;
    while (i < n) {
      final c = s[i];
      final berikut = i + 1 < n ? s[i + 1] : '';
      if (c == '/' && berikut == '/') {
        while (i < n && s[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && berikut == '*') {
        var dalam = 1;
        i += 2;
        while (i < n && dalam > 0) {
          if (s[i] == '/' && i + 1 < n && s[i + 1] == '*') {
            dalam++;
            i += 2;
          } else if (s[i] == '*' && i + 1 < n && s[i + 1] == '/') {
            dalam--;
            i += 2;
          } else {
            if (s[i] == '\n') out.write('\n');
            i++;
          }
        }
        continue;
      }
      if (c == '\'' || c == '"') {
        final mentah = i > 0 && s[i - 1] == 'r';
        final tiga = s.startsWith(c * 3, i);
        final penutup = tiga ? c * 3 : c;
        out.write(penutup);
        i += penutup.length;
        while (i < n && !s.startsWith(penutup, i)) {
          if (!mentah && s[i] == '\\' && i + 1 < n) {
            out.write(s[i]);
            out.write(s[i + 1]);
            i += 2;
            continue;
          }
          if (!tiga && s[i] == '\n') break; // string satu baris tak berpenutup
          out.write(s[i]);
          i++;
        }
        if (i < n && s.startsWith(penutup, i)) {
          out.write(penutup);
          i += penutup.length;
        }
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }
}

/// Hasil pindai: hitungan per kategori per berkas, dan berkas yang dipindai.
class HasilPindai {
  const HasilPindai(this.hitungan, this.dipindai);
  final Map<String, Map<String, int>> hitungan;
  final List<String> dipindai;
}

/// Baseline yang dibaca dari JSON.
class Baseline {
  const Baseline(this.hitungan, {this.berkasDipindai, this.total = const {}});
  final Map<String, Map<String, int>> hitungan;
  final int? berkasDipindai;
  final Map<String, int> total;
}
