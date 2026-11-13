import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/pemindai_token.dart';

/// Gerbang desain Lab, bagian 1: TOKEN-ONLY dengan ratchet DUA ARAH.
///
/// Warna, ukuran huruf, radius, dan tinggi tombol harus datang dari token
/// (`lib/core/theme/`), bukan ditulis langsung di layar. Pelanggaran yang sudah
/// ada TIDAK diperbaiki sekaligus (itu pekerjaan paket-paket redesain), jadi
/// jumlahnya dibekukan per berkas di `token_only_baseline.json`:
///
/// - berkas BARU yang punya pelanggaran  -> tes gagal,
/// - hitungan di berkas lama NAIK        -> tes gagal,
/// - hitungan di berkas lama TURUN       -> tes gagal juga, dengan pesan
///   "turunkan baseline berkas X ke N". Sisa angka di baseline adalah ruang
///   kosong yang bisa dipakai PR lain untuk menyelipkan pelanggaran baru.
///
/// Kategori dijelaskan di `PemindaiToken.kategori`. Folder `lib/core/theme/`
/// bebas dari kategori warna (di sanalah warna ditulis), tetapi TIDAK bebas dari
/// huruf, radius, dan tinggi tombol.
///
/// ## Kalau tes ini merah
///
/// Pakai token: `SidikMaterial.of(context)`, `Theme.of(context).colorScheme`,
/// `BentukLab`, `UkuranLab`, atau skala `textTheme`. Jangan menaikkan baseline.
/// Kalau pelanggaran berkurang, turunkan baseline:
///
///     SIDIK_TULIS_BASELINE=1 flutter test test/tema/token_only_test.dart
///
/// Perintah itu menolak menulis bila ada hitungan yang naik atau berkas baru
/// (kategori yang belum ada di baseline dibekukan apa adanya, sekali).
/// Menaikkan baseline lewat suntingan tangan harus disebut di deskripsi PR dan
/// diperiksa peninjau: tes tidak bisa membandingkan dengan `origin/main`.
void main() {
  const berkasBaseline = 'test/tema/token_only_baseline.json';
  const catatan =
      'Baseline ratchet token-only (dua arah). Hanya boleh MENGECIL; hitungan '
      'turun wajib menurunkan baseline. Kenaikan harus disebut di PR. Lihat '
      'test/tema/token_only_test.dart dan docs/standar-kualitas-desain.md.';

  Map<String, int> hitung(String s, {String jalur = 'lib/screens/x.dart'}) =>
      PemindaiToken.hitung(s, jalur: jalur);

  group('evaluasi ekspresi angka', () {
    test('angka murni dan aritmetika', () {
      expect(PemindaiToken.evaluasi('11'), 11);
      expect(PemindaiToken.evaluasi(' 9 * 1.0 '), 9);
      expect(PemindaiToken.evaluasi('(14 * 0.8)'), closeTo(11.2, 1e-9));
      expect(PemindaiToken.evaluasi('-3 + 5'), 2);
      expect(PemindaiToken.evaluasi('10 / 4'), 2.5);
    });

    test('yang bukan angka murni menghasilkan null', () {
      for (final s in [
        'x',
        '11 * skala',
        'a ? 1 : 2',
        'BentukLab.sel',
        '',
        '(1',
      ]) {
        expect(PemindaiToken.evaluasi(s), isNull, reason: s);
      }
    });
  });

  group('pemindai: tiap pola terdeteksi pada potongan kode contoh', () {
    test('hex mentah dan Color(0x dihitung, komentar tidak', () {
      final h = hitung('''
// catatan lama (#585E67) dan Color(0xFF123456)
/// doc 0xFFAABBCC
const a = Color(0xFF123456);
const b = Color(
  0xFFAABBCC,
);
final s = 'sama saja #A81B33';
final t = 'dengan alpha #A81B33CC';
''');
      expect(
        h['color_0x'],
        2,
        reason: 'Color( dan Color(\\n 0x sama-sama kena',
      );
      expect(h['hex_mentah'], 4, reason: 'dua 0x + #RRGGBB + #RRGGBBAA');
    });

    test('konstruktor warna lain: fromARGB, fromRGBO, from(, desimal, HSL', () {
      final h = hitung('''
const a = Color.fromARGB(255, 1, 2, 3);
const b = Color.fromRGBO(1, 2, 3, 1);
const c = Color.from(alpha: 1, red: 0, green: 0, blue: 0);
const d = Color(4278190080);
final e = HSLColor.fromAHSL(1, 0, 0, 0.5).toColor();
final f = HSVColor.fromAHSV(1, 0, 0, 0.5);
const g = CupertinoColors.systemRed;
''');
      expect(h['warna_konstruktor'], 7);
      expect(h['color_0x'], 0, reason: 'bukan Color(0x');
    });

    test('yang bukan konstruktor warna mentah tidak dihitung', () {
      final h = hitung('''
final a = Color.lerp(x, y, 0.5);
final b = Color.alphaBlend(x, y);
final c = Color(int.parse(teks));
final d = Color(kode);
''');
      expect(h['warna_konstruktor'], 0);
    });

    test('// di dalam string bukan komentar', () {
      final h = hitung(r'''
final url = 'https://contoh.id/a'; const c = Colors.red;
''');
      expect(h['colors_mentah'], 1);
    });

    test('Colors.transparent boleh, warna lain tidak', () {
      final h = hitung(
        'a(Colors.transparent); b(Colors.white); c(Colors.black.withValues())',
      );
      expect(h['colors_mentah'], 2);
    });

    test('fontSize di bawah 12: literal, ekspresi, dan variabel literal', () {
      final h = hitung('''
const kecil = 9;
const besar = 14;
TextStyle(fontSize: 11),
TextStyle(fontSize: 11.5, color: x),
TextStyle(fontSize: 8.5),
TextStyle(fontSize: 9 * 1.0),
TextStyle(fontSize: (14 * 0.8)),
TextStyle(fontSize: kecil),
TextStyle(fontSize: 12),
TextStyle(fontSize: 14),
TextStyle(fontSize: besar),
TextStyle(fontSize: 11 * skala),
TextStyle(fontSize: ukuran),
''');
      // 11, 11.5, 8.5, 9*1.0, 14*0.8=11.2, kecil
      expect(h['fontsize_kecil'], 6);
    });

    test('radius angka: literal, ekspresi murni, variabel literal', () {
      final h = hitung('''
const r = 7;
BorderRadius.circular(8),
const BorderRadius.all(Radius.circular(10.5)),
Radius.circular(999),
BorderRadius.circular(3 * 2),
BorderRadius.circular(r),
BorderRadius.circular(BentukLab.kontrol),
BorderRadius.circular(radius),
''');
      expect(h['radius_literal'], 5);
      expect(h['radius_ekspresi'], 0);
    });

    test('radius ekspresi campuran dihitung terpisah', () {
      final h = hitung('''
BorderRadius.circular(radius + 4),
BorderRadius.circular(AppSpacing.radiusLg + 4),
BorderRadius.circular(radius <= 12 ? radius : 8),
Radius.circular(r * 2),
BorderRadius.circular(radius),
BorderRadius.circular(BentukLab.kontrol),
BorderRadius.circular(SidikMaterial.sudutKertas),
''');
      expect(h['radius_ekspresi'], 4);
      expect(h['radius_literal'], 0);
    });

    test('tinggi tombol di bawah 48: minimumSize, fixedSize, SizedBox', () {
      final h = hitung('''
a: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
b: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 40))),
c: styleFrom(minimumSize: Size.fromHeight(42)),
d: styleFrom(minimumSize: const Size.square(32)),
e: styleFrom(fixedSize: Size(100, 36)),
f: SizedBox(height: 40, child: FilledButton(onPressed: x, child: y)),
g: SizedBox(width: 100, height: 44, child: AppButton(label: 'a')),
''');
      expect(h['tinggi_tombol_kecil'], 7);
    });

    test('tinggi tombol yang sah atau tak terbukti tidak dihitung', () {
      final h = hitung('''
a: styleFrom(minimumSize: const Size(0, 48)),
b: styleFrom(minimumSize: Size.fromHeight(tinggi)),
c: styleFrom(minimumSize: Size(0, UkuranLab.aksi)),
d: SizedBox(height: 56, child: FilledButton(onPressed: x, child: y)),
e: SizedBox(height: 40, child: Text('bukan tombol')),
f: AppBar(preferredSize: Size.fromHeight(28)),
g: styleFrom(minimumSize: Size.fromHeight(tinggiUtama)),
''');
      expect(h['tinggi_tombol_kecil'], 0);
    });

    test('folder sumber token bebas warna, tapi tidak bebas yang lain', () {
      final h = hitung(
        'const a = Color(0xFF111827); x(Colors.white); '
        'const b = Color.fromARGB(1, 2, 3, 4); '
        'TextStyle(fontSize: 10); BorderRadius.circular(7); '
        'BorderRadius.circular(radius + 2); '
        'styleFrom(minimumSize: Size(0, 40));',
        jalur: 'lib/core/theme/palet_lab.dart',
      );
      expect(h['hex_mentah'], 0);
      expect(h['color_0x'], 0);
      expect(h['warna_konstruktor'], 0);
      expect(h['colors_mentah'], 0);
      expect(h['fontsize_kecil'], 1);
      expect(h['radius_literal'], 1);
      expect(h['radius_ekspresi'], 1);
      expect(h['tinggi_tombol_kecil'], 1);
    });
  });

  group('cakupan pemindai dipatok', () {
    test('daftar berkas yang dilewati sama persis dengan yang diharapkan', () {
      // Menambah entri ke `PemindaiToken.dilewati` harus mengubah tes ini juga,
      // jadi tidak bisa menyempitkan gerbang tanpa terlihat di diff.
      expect(PemindaiToken.dilewati.keys.toSet(), {'lib/l10n/', '.g.dart'});
      for (final e in PemindaiToken.dilewati.entries) {
        expect(
          e.value.length,
          greaterThanOrEqualTo(20),
          reason: 'alasan melewati ${e.key} harus tertulis',
        );
      }
    });

    test('jumlah berkas yang dipindai tidak menyusut', () {
      final hasil = PemindaiToken.pindai();
      expect(
        hasil.dipindai.length,
        greaterThanOrEqualTo(400),
        reason:
            'lib/ punya >400 berkas Dart; angka kecil berarti pemindai rusak',
      );
      expect(hasil.dipindai, contains('lib/screens/auth/login_screen.dart'));
      expect(hasil.dipindai, contains('lib/widgets/sidik/sidik_tombol.dart'));
      expect(hasil.dipindai, contains('lib/core/theme/sidik_theme.dart'));
    });

    test('tiap berkas di baseline yang masih ada ikut terpindai', () {
      final dipindai = PemindaiToken.pindai().dipindai.toSet();
      final baseline = PemindaiToken.dariJson(
        File(berkasBaseline).readAsStringSync(),
      );
      for (final k in PemindaiToken.kategori) {
        for (final jalur in baseline.hitungan[k]?.keys ?? const <String>[]) {
          if (File(jalur).existsSync()) {
            expect(
              dipindai,
              contains(jalur),
              reason: '[$k] $jalur tak dipindai',
            );
          }
        }
      }
    });

    test('ringkasan baseline konsisten dengan isinya', () {
      final baseline = PemindaiToken.dariJson(
        File(berkasBaseline).readAsStringSync(),
      );
      expect(baseline.berkasDipindai, isNotNull);
      expect(baseline.berkasDipindai, greaterThanOrEqualTo(400));
      for (final k in PemindaiToken.kategori) {
        final jumlah = (baseline.hitungan[k] ?? const <String, int>{}).values
            .fold<int>(0, (a, b) => a + b);
        expect(
          baseline.total[k],
          jumlah,
          reason: '_ringkasan.total[$k] tidak sama dengan jumlah entri',
        );
      }
    });
  });

  test('ratchet dua arah: tidak naik, tidak ada berkas baru, tidak ada sisa', () {
    final pindai = PemindaiToken.pindai();
    final sekarang = pindai.hitungan;
    final tulis = Platform.environment['SIDIK_TULIS_BASELINE'] == '1';
    final berkas = File(berkasBaseline);

    if (!berkas.existsSync()) {
      expect(
        tulis,
        isTrue,
        reason:
            'baseline $berkasBaseline tidak ada. Buat sekali dengan '
            'SIDIK_TULIS_BASELINE=1.',
      );
      berkas.writeAsStringSync(PemindaiToken.keJson(pindai, catatan: catatan));
      return;
    }

    final baseline = PemindaiToken.dariJson(berkas.readAsStringSync());
    final kategoriBaru = [
      for (final k in PemindaiToken.kategori)
        if (!baseline.hitungan.containsKey(k)) k,
    ];
    final naik = <String>[];
    final baru = <String>[];
    final sisa = <String>[];

    for (final k in PemindaiToken.kategori) {
      final dulu = baseline.hitungan[k];
      if (dulu == null) continue; // kategori baru: dibekukan lewat tulis
      for (final e in sekarang[k]!.entries) {
        final d = dulu[e.key];
        if (d == null) {
          baru.add('[$k] ${e.key}: ${e.value} pelanggaran di berkas baru');
        } else if (e.value > d) {
          naik.add('[$k] ${e.key}: $d -> ${e.value}');
        } else if (e.value < d) {
          sisa.add(
            '[$k] turunkan baseline berkas ${e.key} ke ${e.value} (dulu $d)',
          );
        }
      }
      for (final e in dulu.entries) {
        if (!sekarang[k]!.containsKey(e.key)) {
          sisa.add(
            '[$k] turunkan baseline berkas ${e.key} ke 0 (dulu ${e.value}; '
            'hapus entrinya)',
          );
        }
      }
    }

    if (tulis) {
      expect(
        [...naik, ...baru],
        isEmpty,
        reason:
            'baseline TIDAK ditulis: ada pelanggaran yang naik atau berkas '
            'baru. Baseline hanya boleh mengecil.',
      );
      berkas.writeAsStringSync(PemindaiToken.keJson(pindai, catatan: catatan));
      if (kategoriBaru.isNotEmpty) {
        // ignore: avoid_print
        print('Kategori baru dibekukan sebagai utang: $kategoriBaru');
      }
      return;
    }

    expect(
      kategoriBaru,
      isEmpty,
      reason:
          'Kategori $kategoriBaru belum ada di baseline. Bekukan dengan '
          'SIDIK_TULIS_BASELINE=1 dan jelaskan di PR.',
    );
    expect(
      baru,
      isEmpty,
      reason:
          'Berkas baru memakai nilai mentah. Pakai token (SidikMaterial, '
          'colorScheme, BentukLab, UkuranLab, textTheme):\n${baru.join('\n')}',
    );
    expect(
      naik,
      isEmpty,
      reason:
          'Pelanggaran token NAIK. Pakai token, jangan menaikkan baseline:\n'
          '${naik.join('\n')}',
    );
    expect(
      sisa,
      isEmpty,
      reason:
          'Pelanggaran berkurang tetapi baseline belum diturunkan (sisa angka '
          'bisa dipakai PR lain untuk menyelipkan pelanggaran baru). Jalankan '
          'SIDIK_TULIS_BASELINE=1 flutter test '
          'test/tema/token_only_test.dart:\n${sisa.join('\n')}',
    );
  });
}
