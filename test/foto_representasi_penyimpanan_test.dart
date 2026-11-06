import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

void main() {
  test(
    'decimal20,8 guard compares values, not the number of written digits',
    () {
      for (final teks in [
        '1e-9',
        '0,000000001',
        '-0,000000001',
        '7.03000000000000000001',
        '1000000000000',
        '-1000000000000',
        '999999999999.99999999',
        '100000000000.00000001',
        '100000000000.00001526',
        '999999999999.99987793',
      ]) {
        expect(angkaFotoSah(teks), isFalse, reason: teks);
      }
      for (final teks in [
        '0,00000001',
        '1e-8',
        '7,03',
        '-7,03',
        '7.03000000000000000000',
        '0.00000001000000000',
        '1e3',
        '999999999999',
        '-999999999999',
        '0',
        '-0.000000000',
      ]) {
        expect(angkaFotoSah(teks), isTrue, reason: teks);
      }
      for (final teks in ['', 'NaN', 'Infinity', '1e309', '-', '1..2']) {
        expect(angkaFotoSah(teks), isFalse, reason: teks);
      }
    },
  );

  test(
    'photo entry rejects 1e-9 without zero; correction keeps the original OCR in payload',
    () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final isian =
          LembarKerjaState(bentuk: bentuk, clientRequestId: 'presisi-ocr')
            ..alat = const EquipmentLookup(
              id: 11,
              namaAlat: 'pH Meter',
              serialNumber: 'TEST',
              kategori: 'ph',
              status: 'aktif',
              satuan: 'pH',
            );
      addTearDown(isian.dispose);
      final tabel = bentuk.bagian
          .expand((b) => b.tabel)
          .firstWhere((t) => t.tahap == 'sesudah_adjustment');
      final asli = <SelTabelFoto>[
        (
          titikUkur: 4.0,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: '0,000000001',
          keyakinan: 0.97,
        ),
      ];
      final mesin = bacaanMesinFoto(asli);
      for (final teks in ['100000000000.00001526', '999999999999.99987793']) {
        final jsonLoss = <SelTabelFoto>[
          (
            titikUkur: 4.0,
            repeatNo: 1,
            fieldId: 'pembacaan',
            teks: teks,
            keyakinan: 0.97,
          ),
        ];
        expect(
          isian.terapkanHasilFotoTabel(
            jsonLoss,
            tabel: tabel,
            bacaanMesin: bacaanMesinFoto(jsonLoss),
          ),
          0,
          reason: teks,
        );
        expect(
          isian.titik[4.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
          isEmpty,
          reason: teks,
        );
        expect(jsonLoss.single.teks, teks);
      }
      expect(
        isian.terapkanHasilFotoTabel(asli, tabel: tabel, bacaanMesin: mesin),
        0,
      );
      expect(
        isian.titik[4.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
        isEmpty,
      );
      expect(isian.adaIsianDariFoto, isFalse);
      expect(asli.single.teks, '0,000000001');
      final koreksi = <SelTabelFoto>[
        (
          titikUkur: 4.0,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: '0,00000001',
          keyakinan: 0.97,
        ),
      ];
      expect(
        isian.terapkanHasilFotoTabel(koreksi, tabel: tabel, bacaanMesin: mesin),
        1,
      );
      final payload = isian.toSubmission(draft: true).toJson();
      final baris = (payload['measurements'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['titik_ukur'] == 4.0);
      expect((baris['pembacaan'] as List).first, 0.00000001);
      expect(((baris['ocr'] as List).first as Map)['raw_text'], '0,000000001');
    },
  );
}
