import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// PENJAGA BERKAS BEKU (desain ulang Lab, langkah L0).
///
/// `docs/desain-ulang/BEKU.md`: UI lembar kerja sudah paten — tata letak, warna,
/// ukuran, huruf, keypad, jarak, dan perilakunya tetap persis seperti di `main`.
/// Tes ini menyimpan SHA-256 isi tiap berkas beku. Berkas yang isinya berubah
/// membuat tes merah, sebut berkasnya, dan menunjuk ke BEKU.md.
///
/// Ini separuh penjaga. Separuhnya lagi golden `lembar_kerja_golden_test.dart`
/// (GAMBAR yang dirender berkas beku): berkas yang tidak disentuh pun bisa
/// berubah tampilannya kalau token tema di bawahnya berganti, dan hash tidak
/// melihat itu. Keduanya harus hijau.
///
/// ## Cara menghitung
///
/// Isi berkas dengan CRLF dinormalkan ke LF, lalu SHA-256. Repo memaksa LF lewat
/// `.gitattributes` (`* text=auto eol=lf`), tapi tes ini tetap harus hijau di
/// checkout Windows yang sempat mengubahnya jadi CRLF.
///
/// ## Yang TIDAK di-hash utuh
///
/// `lib/screens/certificate/sertifikat_screen.dart` dan
/// `lib/screens/history/certificate_screen.dart` BEKU hanya SEBAGIAN (area
/// pratinjau PDF — cermin PDF). Sisanya berstatus POLA dan memang akan didesain
/// ulang, jadi hash utuh akan salah merah. Penjaganya golden/tes pratinjau
/// sertifikat, bukan tes ini.
///
/// ## Prosedur BUKA-KUNCI
///
/// Mengubah berkas di tabel ini butuh persetujuan PEMILIK proyek — bukan
/// keputusan engineer atau agen. Kalau disetujui: (1) perbarui hash di PR yang
/// SAMA dan tulis alasannya di deskripsi PR, (2) golden `test/beku/goldens/`
/// tetap harus lolos TANPA diperbarui. Golden yang ikut merah berarti
/// tampilannya berubah, dan itu bukan buka-kunci. Satu-satunya perubahan yang
/// sudah disetujui sebelumnya: membungkus akar layar beku dengan
/// `BekuLembarKerja` (BEKU.md, langkah 5).
///
/// Hash dihitung dari checkout `origin/main` de5ddf4. Kalau berkas di bawah
/// berubah di `main` sebelum PR ini merge (PR lain sempat menyentuhnya), hitung
/// ulang dari `main` terbaru — setelah memastikan perubahannya memang sah.
const Map<String, String> _hashBeku = {
  // ── Lembar kerja (`lib/screens/calibration/`), 17 berkas dari BEKU.md ────────
  'lib/screens/calibration/lembar_kerja_screen.dart':
      '3039aef623d313fa3e1c80b0cee04dda61a3a0cbea90f9bf99085d153c41c9a1',
  'lib/screens/calibration/lembar_kerja_state.dart':
      '6e6005a486d13dfcc002fa339e38d0bee5c3b3054cbdf0e9ed843266c16cc093',
  'lib/screens/calibration/kinerja_lembar.dart':
      '917349ab3dd082f607678d2d526f1c5010b474d1c90c3ca4ff674d9b91b8f2ce',
  'lib/screens/calibration/grid_sensor_state.dart':
      '17492a17174b4fcf1130ae3cfcb5d75c29d0eefd958dfdb5a0ffaf5a998ec420',
  'lib/screens/calibration/titik_sesi_state.dart':
      '17194acb30b57128eec59895be69364decdee956035318715d659b15a5122e2b',
  'lib/screens/calibration/skema_dinamis_screen.dart':
      'ebbfb6fb7b00ee9505e3445a4bd9260f3d98f555d70ed39af0b4706b3f1be45d',
  'lib/screens/calibration/temperatur_indikator_gerbang_screen.dart':
      '4428969cf48a10cc1becfc7a5fd932b8898a1bfd0c0f82b83b24e8f6e639a7b7',
  'lib/screens/calibration/calibration_input_screen.dart':
      'fe0866e4a9f880c89db225745fb8eb0d253c96dc4c1b2e2606c9ea5fe6975d1a',
  'lib/screens/calibration/widgets/lembar_kerja_grid.dart':
      '0a83991529881b82d677f48fe2a49d8ed86a54e9dd979bee10e05593187baebc',
  'lib/screens/calibration/widgets/lembar_kerja_matriks.dart':
      'aa80f4495b4e8542a81a5dd37f0d94aae65399112fed751ab06c740a9c20c152',
  'lib/screens/calibration/widgets/lembar_kerja_tabel.dart':
      '5d4a1a7b3c4653c8a7686f63bd0518063559b8f624c916fbd48e229cc8895e2a',
  'lib/screens/calibration/widgets/lembar_kerja_kartu_baris.dart':
      '0545ba19fa95af8b078c038bcf6d16bc9ee376d19c3ab5a8025becd9249ed1d3',
  'lib/screens/calibration/widgets/keypad_angka.dart':
      'd29dd2b952da2f88fff48b33c060c4f96aceaece18ea4e00ea82c8534e492b4b',
  'lib/screens/calibration/widgets/pengatur_titik.dart':
      '95de051c0a9836b64af165016247870421f54698fed4828c118609f496dfba42',
  'lib/screens/calibration/widgets/pengatur_titik_sesi.dart':
      'e79b5f9fca7b43826ca0e06e39d3258133d86cd288a86338c1c74779adf9695c',
  'lib/screens/calibration/widgets/tanda_lompat.dart':
      '291e8296c69ab0b9e7e47e1b0b4ac4f9156abeb25e1062e6e77046dd41c26003',
  'lib/screens/calibration/widgets/dropdown_gagal.dart':
      '33b3e4236ddcac2660808b81e76418a683027be6646f9086f5c56cf335dd96bc',

  // ── TAMBAHAN di luar BEKU.md ─────────────────────────────────────────────────
  // Tiga berkas ini lahir dari gerbang wajib-cek per sel (#241, setelah BEKU.md
  // ditulis) dan menjadi bagian lembar kerja. Pemilik meminta ikut dibekukan.
  // BEKU.md belum menyebutnya — perbarui daftarnya di sana bila disetujui.
  'lib/screens/calibration/cek_bacaan_kamera.dart':
      'e2c47872294d237f16eb70d950207754b2b4a5ad91578b9612fc237bbe100457',
  'lib/screens/calibration/verifikasi_sel_dicek.dart':
      'df1d6ae1693021357c0c666476d6d22df71fd7a54748f1b8843e6c243d21ac48',
  'lib/screens/calibration/widgets/tanda_cek_sel.dart':
      'b379d160f6f1a2aa6972b4423267f64027d95f30d132defcac981b2ed6df51ab',

  // ── Lainnya (keputusan pemilik sebelumnya) ───────────────────────────────────
  // Cermin sheet PERHITUNGAN Master Olah Data.
  'lib/screens/admin/widgets/tabel_perhitungan.dart':
      'f077889261be2efd45a17abc9f585819b5ef85d870575832f313a908d6c88137',
  // Pratinjau sertifikat (cermin PDF). Dua layar yang menampungnya BEKU hanya
  // sebagian — lihat "Yang TIDAK di-hash utuh" di atas.
  'lib/widgets/sertifikat_pdf_view.dart':
      '6da5781ef9ba2abfdbffe8b31ba60f93af7a04c79fbe919effec901d7ac44269',
  // Onboarding 3D, model 3D, sakelar tema matahari/bulan.
  'lib/screens/auth/onboarding_screen.dart':
      '317e34e6969d874c154da8aba417ffb0c68aa4d4d1487c5e9fbb065b9daea430',
  'lib/widgets/scene3d/alat_3d.dart':
      'e6ebdd7db806fd650e17d554f3fd5d1ffec7def04b70b52825cef3ecffbe4f84',
  'lib/widgets/scene3d/mesh3d.dart':
      '7e4f6307476fe4dfcb0058bebfc743deaec1dd50ec3f46fd168b11f861f0b833',
  'lib/widgets/scene3d/panggung3d.dart':
      'fa6f0f54b41ca25625fcedfa773b4e581456bbf8c0a021dc75c338e3df7d66c6',
  'lib/widgets/scene3d/renderer3d.dart':
      '68b1aa74ceed176ba48d3f5887ba80c62ee1f15a2770c4554a463fd564f7af6f',
  'lib/widgets/sakelar_tema.dart':
      'b87320031926cb6376fb391dbaf78fc2098512a7052f2bb1d4ed56d5b08c8d8c',

  // ── Widget bersama yang DIPAKAI lembar kerja ─────────────────────────────────
  'lib/widgets/app_button.dart':
      'd7ea68c4ef3374a95e027a97f201b36fb613d8668effbc2d355c255cbc0c7b9d',
  'lib/widgets/app_text_field.dart':
      '3b759378faa9975cbb193e3c1066638c89052f805ec9712deffa8bbe409b054d',
  'lib/widgets/sidik_loader.dart':
      '10e5420c500c9a75d4c52eed5d2008ce86d16bd12ec6c5dde88f309bbdb06964',
  'lib/widgets/status_badge.dart':
      '121009fdc9177392622cb12bc0c79b9e4e3a5dc071fb668f628a0f9adb36ad38',
  // Nilai `AppSpacing.*` (217 pemakaian di lembar kerja).
  'lib/core/theme/app_spacing.dart':
      '61f7abaa3870dd70fe53c3aabdc28d7192f7aee818b5581981e87777cb1f0ecd',
};

/// Folder yang seluruh isinya dianggap beku-atau-diputuskan-sengaja: berkas
/// `.dart` BARU di sini yang tidak ada di [_hashBeku] maupun
/// [_sengajaTidakBeku] membuat tes merah, supaya tidak ada berkas lembar kerja
/// baru yang lolos tanpa keputusan "beku atau tidak".
const List<String> _folderDijaga = [
  'lib/screens/calibration',
  'lib/widgets/scene3d',
];

/// Berkas di [_folderDijaga] yang SENGAJA tidak beku, beserta statusnya di
/// `docs/desain-ulang/PETA-LAYAR.md` (hasil bedah 14 Nov 2026).
const Map<String, String> _sengajaTidakBeku = {
  'lib/screens/calibration/category_picker_screen.dart': 'DESAIN 02 Pilih alat',
  'lib/screens/calibration/instrument_picker_screen.dart':
      'DESAIN 02 Pilih alat',
  'lib/screens/calibration/foto_review_screen.dart':
      'DESAIN 04 Cek hasil pindai',
  'lib/screens/calibration/widgets/ringkasan_sebelum_kirim_dialog.dart':
      'DESAIN 05 Ringkasan sebelum kirim',
  'lib/screens/calibration/kamera_pindai_screen.dart': 'TOKEN',
  'lib/screens/calibration/peta_kolom_screen.dart': 'TOKEN',
  'lib/screens/calibration/pindai_formulir_asli_flow.dart': 'TOKEN',
  'lib/screens/calibration/penjaga_draf_lokal.dart': 'LOGIKA (tanpa tampilan)',
  'lib/screens/calibration/ringkasan_sebelum_kirim.dart':
      'LOGIKA (gerbang ButirRingkasan)',
};

/// SHA-256 isi [bytes] dengan CRLF (`\r\n`) dinormalkan ke LF. `\r` yang berdiri
/// sendiri dibiarkan.
String hashTernormalisasi(List<int> bytes) {
  final hasil = BytesBuilder(copy: false);
  for (var i = 0; i < bytes.length; i++) {
    final akhirBaris =
        bytes[i] == 0x0D && i + 1 < bytes.length && bytes[i + 1] == 0x0A;
    if (!akhirBaris) hasil.addByte(bytes[i]);
  }

  return sha256.convert(hasil.takeBytes()).toString();
}

String _pesanBerubah(String path, String tersimpan, String sekarang) =>
    '''

BERKAS BEKU BERUBAH: $path
  hash tersimpan : $tersimpan
  hash sekarang  : $sekarang

Berkas ini BEKU: UI lembar kerja sudah paten dan tampilannya tidak boleh
berubah. BACA docs/desain-ulang/BEKU.md dulu. Kalau kamu agen atau engineer
desain ulang dan terasa perlu mengubah berkas ini: BERHENTI dan tanya pemilik.

Prosedur buka-kunci (hanya bila pemilik proyek menyetujui):
  1. Perubahan berkas beku butuh persetujuan PEMILIK, bukan keputusan engineer.
  2. Perbarui hash di test/beku/berkas_beku_test.dart di PR YANG SAMA, dan
     tulis alasannya di deskripsi PR.
  3. Golden test/beku/goldens/ HARUS tetap lolos TANPA diperbarui. Golden yang
     ikut merah berarti tampilannya berubah — itu bukan buka-kunci.
Satu-satunya perubahan yang sudah disetujui sebelumnya: membungkus akar layar
beku dengan BekuLembarKerja (BEKU.md, langkah 5).
''';

String _normal(String path) => path.replaceAll('\\', '/');

void main() {
  group('isi berkas beku tidak berubah', () {
    for (final MapEntry(key: path, value: hashTersimpan) in _hashBeku.entries) {
      test(path, () {
        final berkas = File(path);
        expect(
          berkas.existsSync(),
          isTrue,
          reason:
              'Berkas beku $path tidak ada. Dipindah/dihapus/diganti nama? '
              'Itu juga perubahan berkas beku: baca docs/desain-ulang/BEKU.md.',
        );

        final sekarang = hashTernormalisasi(berkas.readAsBytesSync());
        expect(
          sekarang,
          hashTersimpan,
          reason: _pesanBerubah(path, hashTersimpan, sekarang),
        );
      });
    }
  });

  group('tabel penjaga', () {
    test('semua path di tabel ada, dan tabel tidak kosong', () {
      expect(_hashBeku, isNotEmpty);
      final hilang = [
        for (final path in _hashBeku.keys)
          if (!File(path).existsSync()) path,
      ];
      expect(
        hilang,
        isEmpty,
        reason:
            'Path di test/beku/berkas_beku_test.dart yang tidak ada di disk: '
            '$hilang. Berkas beku dipindah/dihapus? Baca docs/desain-ulang/BEKU.md.',
      );
    });

    test(
      'hash berbentuk SHA-256 hex, dan tidak ada dua berkas berbagi hash',
      () {
        final bentuk = RegExp(r'^[0-9a-f]{64}$');
        for (final MapEntry(key: path, value: hash) in _hashBeku.entries) {
          expect(
            bentuk.hasMatch(hash),
            isTrue,
            reason: 'Hash $path salah bentuk.',
          );
        }
        expect(_hashBeku.values.toSet().length, _hashBeku.length);
      },
    );

    test('berkas yang sengaja tidak beku ada dan tidak ikut di tabel hash', () {
      for (final path in _sengajaTidakBeku.keys) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              '$path ada di _sengajaTidakBeku tapi tidak ada di disk: hapus barisnya.',
        );
        expect(
          _hashBeku.containsKey(path),
          isFalse,
          reason: '$path tidak boleh ada di dua daftar sekaligus.',
        );
      }
    });

    test('tidak ada berkas di folder beku yang lolos tanpa keputusan', () {
      final tidakTercatat = <String>[];
      for (final folder in _folderDijaga) {
        final dir = Directory(folder);
        expect(dir.existsSync(), isTrue, reason: 'Folder $folder tidak ada.');
        for (final e in dir.listSync(recursive: true)) {
          if (e is! File || !e.path.endsWith('.dart')) continue;
          final path = _normal(e.path);
          if (!_hashBeku.containsKey(path) &&
              !_sengajaTidakBeku.containsKey(path)) {
            tidakTercatat.add(path);
          }
        }
      }

      expect(
        tidakTercatat,
        isEmpty,
        reason:
            '\nBerkas baru di folder beku yang belum diputuskan: $tidakTercatat\n'
            'Folder ${_folderDijaga.join(', ')} memuat lembar kerja beku. Baca '
            'docs/desain-ulang/BEKU.md dan PETA-LAYAR.md, lalu masukkan berkasnya '
            'ke _hashBeku (beku) atau _sengajaTidakBeku (dengan statusnya) di '
            'test/beku/berkas_beku_test.dart. Menambah berkas ke daftar beku '
            'butuh persetujuan pemilik.',
      );
    });
  });

  group('hash tahan CRLF', () {
    test('CRLF dan LF menghasilkan hash yang sama', () {
      final lf = 'a\nb\n\nc\n'.codeUnits;
      final crlf = 'a\r\nb\r\n\r\nc\r\n'.codeUnits;
      expect(hashTernormalisasi(crlf), hashTernormalisasi(lf));
    });

    test('perubahan isi tetap ketahuan, termasuk \\r yang berdiri sendiri', () {
      final dasar = hashTernormalisasi('a\nb\n'.codeUnits);
      expect(hashTernormalisasi('a\nc\n'.codeUnits), isNot(dasar));
      expect(hashTernormalisasi('a\rb\n'.codeUnits), isNot(dasar));
    });

    test('berkas kosong dan berakhiran \\r tidak melempar', () {
      expect(hashTernormalisasi(const []), hasLength(64));
      expect(hashTernormalisasi('a\r'.codeUnits), hasLength(64));
    });
  });
}
