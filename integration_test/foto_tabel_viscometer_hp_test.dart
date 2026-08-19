import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Jalur **FOTO TABEL INI** Viscometer, diuji DI PERANGKAT dengan ML Kit asli.
///
/// ## Kenapa ini perlu, padahal sudah ada test unit & end-to-end
///
/// `test/peta_tabel_foto_test.dart` dan
/// `test/viscometer_foto_tabel_end_to_end_test.dart` menyusun sendiri daftar
/// [TeksTerbaca]-nya — posisi kotak, ejaan, semuanya ditulis test. Itu
/// membuktikan pemetaannya benar, tapi **tidak** membuktikan ML Kit beneran
/// bisa membaca lembarnya.
///
/// Tiga hal yang cuma bisa gagal di sini, dan ketiganya yang bikin fitur ini
/// mentok di lapangan:
///
///  1. **Nomor kolom polos `1`..`5` kebaca sebagai elemen sendiri.** Kepala
///     kolom lembar Rev.3 cuma nomor, dan jalur bawaan mencari `X1`/`Repeat 1`.
///     Kalau ML Kit menggabungkan nomor-nomor itu jadi satu blok (`1 2 3 4 5`),
///     deretnya nggak pernah lengkap dan seluruh tabel batal.
///  2. **Label satuan `cP` dan `°C` kebaca.** Lingkaran derajat itu bentuk
///     tersulit buat ML Kit; kalau salah satu label hilang, seluruh tabel
///     ditolak (penjaga sengaja — lihat `PetaTabelFoto.petakan`).
///  3. **Label baris `100`/`1000`/`60000` kebaca sebagai kolomnya sendiri.**
///     Ini nilai yang tercetak di kertas, bukan `titik_ukur` yang dihitung
///     (99,65 / 1018 / 59003) — selisihnya 1,8 %.
///
/// Jalanin:
///
/// ```
/// flutter test integration_test/foto_tabel_viscometer_hp_test.dart -d <id-perangkat>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late img.Image jepretan;
  late LembarKerja bentuk;
  late TabelHasil tabel;

  setUpAll(() async {
    final png = await rootBundle.load('test/assets/tabel-viscometer-uji.png');
    jepretan = img.decodePng(png.buffer.asUint8List())!;

    final json = await rootBundle.loadString(
      'test/assets/viscometer-bentuk-hasil.json',
    );

    bentuk = LembarKerja.fromJson(jsonDecode(json) as Map<String, dynamic>);
    tabel = bentuk.bagian
        .expand((b) => b.tabel)
        .firstWhere((t) => t.tahap == 'sesudah_adjustment');
  });

  /// Persis yang dikerjakan `_LembarKerjaTabelState._foto()` sesudah OCR.
  HasilPetaTabel petakanSepertiLayar(
    List<TeksTerbaca> terbaca,
    LembarKerjaState isian,
  ) {
    final titik = isian.titikTabel(tabel);

    return const PetaTabelFoto().petakan(
      terbaca: terbaca,
      titikUkur: [for (final t in titik) t.titikUkur],
      pengulangan: tabel.pengulangan,
      fieldPerRepeat: [for (final k in tabel.kolom) k.kode],
      labelField: {for (final k in tabel.kolom) k.kode: k.label},
      labelTercetak: {for (final t in titik) t.titikUkur: t.label},
    );
  }

  testWidgets('ML Kit membaca jangkar yang dibutuhkan pemetaan', (_) async {
    final pembaca = MlKitPembacaHalaman();
    addTearDown(pembaca.tutup);

    final terbaca = await pembaca.baca(jepretan);
    final teks = terbaca.map((t) => t.teks.trim()).toList();

    // Dump mentah — tanpa ini kegagalan di sini cuma bilang "nggak ketemu",
    // dan yang perlu diketahui justru ML Kit membacanya jadi APA.
    debugPrint('=== ML KIT BACA ${terbaca.length} ELEMEN ===');
    for (final t in terbaca) {
      debugPrint(
        'TEKS[${t.teks}] x=${t.kotak.left.toStringAsFixed(0)} '
        'y=${t.kotak.top.toStringAsFixed(0)} '
        'w=${t.kotak.width.toStringAsFixed(0)} '
        'h=${t.kotak.height.toStringAsFixed(0)}',
      );
    }
    debugPrint('=== SELESAI ===');

    // --- yang WAJIB kebaca ---------------------------------------------------
    //
    // Label baris: satu-satunya jangkar baris yang ada. Kalau ini lewat,
    // barisnya nggak punya jalan lain buat dikenali.
    for (final label in ['100', '1000', '60000']) {
      expect(
        teks,
        contains(label),
        reason: 'Label baris `$label` nggak kebaca ML Kit.',
      );
    }

    // Label kolom pembacaan, lima-limanya: ini jangkar kolom yang beneran
    // dipakai lembar ini, karena nomor kepalanya nggak bisa diandalkan (lihat
    // di bawah).
    expect(
      teks.where((t) => t.toLowerCase() == 'cp'),
      hasLength(5),
      reason: 'Jangkar kolom cadangan nggak lengkap.',
    );

    // --- yang TERNYATA nggak bisa diandalkan --------------------------------
    //
    // Dua hal di bawah **sengaja nggak di-assert wajib**, dan itu hasil
    // pengukuran di sini, bukan kelonggaran yang diberikan supaya hijau:
    //
    //  - **Digit tunggal di kepala kolom.** ML Kit melewatkan `3` di jepretan
    //    ini. Digit sendirian tanpa tetangga memang bentuk tersulit buatnya,
    //    dan itu di luar kendali kita — makanya deret nomor cuma dipakai
    //    kalau UTUH, dan kalau bolong jangkarnya diambil dari label `cP`.
    //  - **`°C`.** Kebaca empat dari lima. Yang lewat dilengkapi dari jarak
    //    antar label yang sudah terbaca (`_lengkapiJangkarField`).
    //
    // Yang dijaga: keduanya kebaca CUKUP untuk pemetaan, bukan sempurna.
    final nomorKebaca = ['1', '2', '3', '4', '5'].where(teks.contains).length;
    final suhuKebaca = teks
        .where((t) => RegExp(r'^[°º˚o0]?C$', caseSensitive: false).hasMatch(t))
        .length;

    debugPrint('nomor kepala kebaca: $nomorKebaca/5 · label suhu: $suhuKebaca/5');

    expect(
      suhuKebaca,
      greaterThanOrEqualTo(2),
      reason: 'Label suhu perlu minimal dua buat menyimpulkan jaraknya.',
    );
  });

  testWidgets('foto tabel → 30 sel mendarat di kotak yang benar', (_) async {
    final pembaca = MlKitPembacaHalaman();
    addTearDown(pembaca.tutup);

    final terbaca = await pembaca.baca(jepretan);

    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'hp');
    addTearDown(isian.dispose);

    final hasil = petakanSepertiLayar(terbaca, isian);

    expect(
      hasil.labelKolomKurang,
      isEmpty,
      reason: 'Label sub-kolom hilang: ${hasil.labelKolomKurang}',
    );
    expect(
      hasil.kosong,
      isFalse,
      reason: 'INI yang gagal di lapangan — nol sel dari jepretan yang sah.',
    );
    expect(
      hasil.repeatKetemu,
      containsAll([1, 2, 3, 4, 5]),
      reason: 'Kepala kolom nomor polos nggak kejangkar lengkap.',
    );
    expect(
      hasil.titikKetemu,
      containsAll([99.65, 1018.0, 59003.0]),
      reason: 'Baris 1000 & 60000 cP yang dulu nggak pernah kejangkar.',
    );
    expect(hasil.sel, hasLength(30), reason: '3 titik × 5 Repeat × 2 kolom');

    // Angkanya masuk kotak isian formulir, bukan cuma terpetakan.
    final terisi = isian.terapkanHasilFotoTabel(hasil.sel, tahap: tabel.tahap);
    expect(terisi, 30);

    // Beberapa sel diadu ke angka sesi master yang dirender di gambarnya.
    // Pembacaan dipangkas ke resolusi titik (0,1 cP → satu desimal).
    expect(
      isian.titik[99.65]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '97,3',
    );
    expect(
      isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '919,6',
    );
    expect(
      isian.titik[59003.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '63181,3',
    );
    expect(
      parseAngka(
        isian.titik[59003.0]!.kotak('sesudah_adjustment', 'suhu', 4).text,
      ),
      24.6,
      reason: 'Kolom suhu ketuker sama kolom cP.',
    );
  });
}
