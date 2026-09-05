import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tebakan mesin selamat sampai server, walau teknisi mengetik ulang selnya.
///
/// ## Kenapa berkas ini ada
///
/// Teknisi mengoreksi angka hasil foto **di kotak yang sama**. Sebelum ini,
/// begitu dia mengetik ulang, tebakan mesinnya tertimpa dan hilang selamanya —
/// yang sampai server cuma angka akhir.
///
/// Akibatnya bukan "kurang lengkap", tapi **akurasi kamera jadi mustahil
/// dihitung**: tidak ada pembanding, cuma hasil. Yang paling mahal dari
/// ketiadaan itu HIJAU PALSU — sel yang keisi otomatis dengan keyakinan tinggi
/// padahal salah. Itu satu-satunya kegagalan yang tidak ada yang lihat sampai
/// sertifikatnya terbit, dan tanpa pasangan (tebakan, angka final) dia tidak
/// bisa dihitung maupun dibantah.
///
/// Jadi test yang paling menentukan di berkas ini yang PERTAMA: sel yang
/// dikoreksi teknisi. Sel yang dibiarkan apa adanya gampang — yang harus
/// dijaga justru sel yang berubah, karena persis itu yang jadi bukti mesinnya
/// salah.
void main() {
  LembarKerja bentuk() => LembarKerja.fromJson(
    jsonDecode(
          File('test/fixtures/viscometer-bentuk-hasil.json').readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  ({LembarKerjaState isian, TabelHasil tabel}) siapkan() {
    final b = bentuk();

    final isian = LembarKerjaState(
      bentuk: b,
      clientRequestId: 'uji-tebakan-mesin',
    )..alat = const EquipmentLookup(
      // `toSubmission` butuh alat — identitas barangnya, bukan kolom wajib.
      id: 11,
      namaAlat: 'Viscometer',
      serialNumber: 'V12345',
      kategori: 'viskositas',
      status: 'aktif',
      satuan: 'cP',
    );

    return (
      isian: isian,
      tabel: b.bagian
          .expand((x) => x.tabel)
          .firstWhere((t) => t.tahap == 'sesudah_adjustment'),
    );
  }

  SelTabelFoto sel(
    double titikUkur,
    int repeatNo,
    String teks, {
    double? keyakinan,
  }) => (
    titikUkur: titikUkur,
    repeatNo: repeatNo,
    fieldId: 'pembacaan',
    teks: teks,
    keyakinan: keyakinan,
  );

  /// Baris `measurements` buat satu titik ukur. Dicari lewat `titik_ukur`,
  /// bukan indeks: baris yang belum disentuh ikut terkirim, jadi posisinya
  /// bukan sesuatu yang boleh diandalkan test ini.
  Map<String, dynamic> barisKirim(LembarKerjaState isian, double titikUkur) {
    final measurements =
        isian.toSubmission(draft: true).toJson()['measurements']
            as List<dynamic>;

    return measurements.cast<Map<String, dynamic>>().firstWhere(
      (m) => (m['titik_ukur'] as num).toDouble() == titikUkur,
    );
  }

  test('sel yang DIKETIK ULANG teknisi tetap membawa tebakan aslinya', () {
    final s = siapkan();
    addTearDown(s.isian.dispose);

    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 1, '123,4', keyakinan: 0.93)],
      tabel: s.tabel,
    );

    // Teknisi melihat angkanya salah dan membetulkannya di kotak yang sama.
    // Ini jalur yang dulu menghapus buktinya.
    s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '125,7';

    final baris = barisKirim(s.isian, 1018.0);

    expect(
      (baris['pembacaan'] as List<dynamic>)[0],
      125.7,
      reason: 'Yang dikirim tetap angka teknisi — mesin tidak pernah menang.',
    );

    final ocr = (baris['ocr'] as List<dynamic>)[0] as Map<String, dynamic>;

    expect(
      ocr['raw_text'],
      '123,4',
      reason:
          'Tanpa baris ini, tebakan yang KETAHUAN salah justru yang hilang — '
          'padahal itu contoh paling berharga buat mengukur kameranya.',
    );
    expect(ocr['confidence'], 0.93);
  });

  test('deret `ocr` sejajar indeks dengan `pembacaan`, bukan dirapatkan', () {
    final s = siapkan();
    addTearDown(s.isian.dispose);

    // Cuma Repeat 3 yang datang dari foto; Repeat 1 diketik teknisi.
    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 3, '77,7', keyakinan: 0.5)],
      tabel: s.tabel,
    );
    s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '11,1';

    final baris = barisKirim(s.isian, 1018.0);
    final ocr = baris['ocr'] as List<dynamic>;

    expect(
      ocr.length,
      (baris['pembacaan'] as List<dynamic>).length,
      reason: 'Server membaca ocr[i] dengan indeks pembacaan yang sama.',
    );
    expect(
      ocr[0],
      isNull,
      reason: 'Repeat 1 diketik tangan — dia tidak boleh mengaku dari kamera, '
          'karena itu yang menentukan barisnya lahir perlu-verifikasi atau nggak.',
    );
    expect((ocr[2] as Map<String, dynamic>)['raw_text'], '77,7');
  });

  test('lembar yang seluruhnya diketik tangan nggak mengirim kunci `ocr`', () {
    final s = siapkan();
    addTearDown(s.isian.dispose);

    s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '50,0';

    expect(
      barisKirim(s.isian, 1018.0).containsKey('ocr'),
      isFalse,
      reason:
          'Deret null buat tiap titik itu beban tanpa arti — dan kunci yang '
          'muncul tanpa isi bikin pembacanya mengira ada jalur kamera di situ.',
    );
  });

  test('keyakinan yang nggak diketahui dikirim TANPA `confidence`', () {
    final s = siapkan();
    addTearDown(s.isian.dispose);

    // ML Kit cuma menyetel `confidence` di sebagian versi & perangkat.
    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 1, '9,81')],
      tabel: s.tabel,
    );

    final ocr =
        (barisKirim(s.isian, 1018.0)['ocr'] as List<dynamic>)[0]
            as Map<String, dynamic>;

    expect(ocr['raw_text'], '9,81');
    expect(
      ocr.containsKey('confidence'),
      isFalse,
      reason:
          'Yang nggak diketahui dikirim null, bukan diisi angka karangan — '
          'skor karangan persis yang bikin sel salah divonis hijau.',
    );
  });

  test('sel yang akhirnya DIKOSONGKAN teknisi nggak menitip tebakan', () {
    final s = siapkan();
    addTearDown(s.isian.dispose);

    s.isian.terapkanHasilFotoTabel(
      [sel(1018.0, 1, '404', keyakinan: 0.99)],
      tabel: s.tabel,
    );
    s.isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '';

    final baris = barisKirim(s.isian, 1018.0);

    expect((baris['pembacaan'] as List<dynamic>)[0], isNull);
    expect(
      baris.containsKey('ocr'),
      isFalse,
      reason:
          'Tebakan tanpa angka final nggak punya pasangan buat diadu, dan '
          'server juga melewati barisnya — jadi dia cuma jadi angka gantung.',
    );
  });
}
