import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tebakan mesin di lembar BERPASANGAN selamat sampai payload — dan mendarat
/// di SISI yang benar.
///
/// ## Kenapa sisinya yang paling mahal
///
/// Tiap titik punya dua deret: sisi standar dan sisi UUT. Yang tercetak di
/// sertifikat `Correction` — SELISIH keduanya. Tebakan yang tertukar sisi nggak
/// cuma salah alamat: dia bikin selisih yang diukur bergeser, dan geserannya
/// nggak ngasih gejala apa pun karena kedua angkanya tetap wajar.
///
/// ## Lembar Timer/Stopwatch sengaja dilewati
///
/// Satu penunjukan di sana ditulis di EMPAT kotak (jam/menit/detik/milidetik)
/// dan server menyimpannya sebagai SATU baris milidetik. Empat tebakan nggak
/// punya satu kolom pun buat ditaruh, dan menggabungkannya jadi satu teks
/// berarti mengarang bacaan yang nggak pernah dilihat pengenalnya.
void main() {
  LembarKerja bentuk(String kode) => LembarKerja.fromJson(
    jsonDecode(File('test/fixtures/lembar-kerja-$kode.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  List<TabelHasil> tabelDari(LembarKerja b) => [
    for (final bagian in b.bagian) ...bagian.tabel,
  ];

  LembarKerjaState state(LembarKerja b) =>
      LembarKerjaState(bentuk: b, clientRequestId: 'uji-tebakan-pasangan')
        ..alat = const EquipmentLookup(
          id: 7,
          namaAlat: 'Thermocouple Thermometer',
          serialNumber: 'T-1',
          kategori: 'suhu',
          status: 'aktif',
          satuan: '°C',
        );

  SelTabelFoto sel(TabelHasil t, double titikUkur, String teks, {double? skor}) => (
    titikUkur: titikUkur,
    repeatNo: t.pengulangan.first,
    fieldId: t.kolom.first.kode,
    teks: teks,
    keyakinan: skor,
  );

  double titikBaris(LembarKerjaState s, TabelHasil t, int index) =>
      s.titik[s.kunciBaris(s.barisTabel(t), index, t)]!.titikUkur;

  Map<String, dynamic> barisKirim(LembarKerjaState s) =>
      ((s.toSubmission(draft: true).toJson()['measurements'] as List<dynamic>)
              .first
          as Map<String, dynamic>);

  test('sel yang DIKETIK ULANG teknisi tetap membawa tebakan aslinya', () {
    final b = bentuk('thermocouple');
    final s = state(b);
    addTearDown(s.dispose);

    final standar = tabelDari(b).firstWhere((t) => t.deretStandar);
    final titik = titikBaris(s, standar, 0);
    final kolom = standar.kolom.first.kode;

    expect(
      s.terapkanHasilFotoTabel([sel(standar, titik, '49,7', skor: 0.9)], tabel: standar),
      1,
      reason: 'Prasyarat: selnya memang keisi dari foto.',
    );

    // Teknisi membetulkannya di kotak yang sama.
    s.titik[s.kunciBaris(s.barisTabel(standar), 0, standar)]!
        .kotak(standar.kunciTabel, kolom, 0)
        .text = '49,5';

    final baris = barisKirim(s);

    expect((baris['standar'] as List<dynamic>)[0], 49.5);

    final ocr = (baris['standar_ocr'] as List<dynamic>)[0] as Map<String, dynamic>;
    expect(ocr['raw_text'], '49,7');
    expect(ocr['confidence'], 0.9);
  });

  test('tebakan sisi standar nggak bocor ke deret UUT', () {
    final b = bentuk('thermocouple');
    final s = state(b);
    addTearDown(s.dispose);

    final standar = tabelDari(b).firstWhere((t) => t.deretStandar);
    final uut = tabelDari(b).firstWhere((t) => !t.deretStandar && t.berpasangan);

    s.terapkanHasilFotoTabel(
      [sel(standar, titikBaris(s, standar, 0), '49,7')],
      tabel: standar,
    );
    // Sisi UUT diketik tangan — dia nggak boleh mengaku dari kamera.
    s.titik[s.kunciBaris(s.barisTabel(uut), 0, uut)]!
        .kotak(uut.kunciTabel, uut.kolom.first.kode, 0)
        .text = '49,9';

    final baris = barisKirim(s);

    expect((baris['standar_ocr'] as List<dynamic>)[0], isNotNull);
    expect(
      baris.containsKey('uut_ocr'),
      isFalse,
      reason: 'Selisih dua sisi itu yang tercetak; tebakan yang bocor sisi '
          'menggeser `Correction` tanpa satu pun error.',
    );
  });

  test('lembar yang seluruhnya diketik tangan nggak mengirim kunci ocr', () {
    final b = bentuk('thermocouple');
    final s = state(b);
    addTearDown(s.dispose);

    final standar = tabelDari(b).firstWhere((t) => t.deretStandar);
    s.titik[s.kunciBaris(s.barisTabel(standar), 0, standar)]!
        .kotak(standar.kunciTabel, standar.kolom.first.kode, 0)
        .text = '49,5';

    final baris = barisKirim(s);

    expect(baris.containsKey('standar_ocr'), isFalse);
    expect(baris.containsKey('uut_ocr'), isFalse);
  });

  test('Timer/Stopwatch nggak mengirim kunci ocr — empat kotak, satu baris', () {
    final b = bentuk('timer_stopwatch');
    final s = LembarKerjaState(bentuk: b, clientRequestId: 'uji-waktu')
      ..alat = const EquipmentLookup(
        id: 8,
        namaAlat: 'Stopwatch',
        serialNumber: 'S-1',
        kategori: 'waktu',
        status: 'aktif',
        satuan: 's',
      );
    addTearDown(s.dispose);

    final standar = tabelDari(b).firstWhere((t) => t.deretStandar);

    s.terapkanHasilFotoTabel(
      [sel(standar, titikBaris(s, standar, 0), '12')],
      tabel: standar,
    );

    final measurements =
        s.toSubmission(draft: true).toJson()['measurements'] as List<dynamic>;

    for (final m in measurements.cast<Map<String, dynamic>>()) {
      expect(
        m.containsKey('standar_ocr') || m.containsKey('uut_ocr'),
        isFalse,
        reason: 'Menggabungkan empat tebakan jadi satu teks itu mengarang '
            'bacaan yang nggak pernah dilihat pengenalnya.',
      );
    }
  });
}
