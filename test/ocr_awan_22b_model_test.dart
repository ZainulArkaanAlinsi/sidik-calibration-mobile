import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Tambahan model untuk kontrak 22B (`POST /ocr/sel-awan`): kode galat baru,
/// `sisa_sel_lembar`, dan `tipe` baris templat.
void main() {
  GalatOcrAwan? petakan(int status, Map<String, dynamic> body) =>
      GalatOcrAwan.dariRespons(ApiException('x', status: status, body: body));

  group('kode galat 22B', () {
    final kasus = <String, JenisGalatOcrAwan>{
      'batas_sel_per_lembar': JenisGalatOcrAwan.jatahHabis,
      'terlalu_sering': JenisGalatOcrAwan.terlaluSering,
      'permintaan_tidak_valid': JenisGalatOcrAwan.permintaanDitolak,
      'templat_tidak_dikenal': JenisGalatOcrAwan.permintaanDitolak,
      'tidak_ada_potongan_valid': JenisGalatOcrAwan.tidakAdaPotongan,
      'sesi_tidak_ditemukan': JenisGalatOcrAwan.sesiBermasalah,
      'bukan_sesi_anda': JenisGalatOcrAwan.sesiBermasalah,
    };

    kasus.forEach((kode, jenis) {
      test('$kode -> ${jenis.name}, jalur manual tetap terbuka', () {
        final g = petakan(422, {'kode': kode, 'fallback_manual': true});

        expect(g, isNotNull);
        expect(g!.jenis, jenis);
        expect(g.fallbackManual, isTrue);
        expect(g.bolehUlangOtomatis, isFalse);
      });
    });

    test('kode baru yang belum dikenal + fallback_manual -> lainnya', () {
      final g = petakan(503, {
        'kode': 'kode_masa_depan',
        'fallback_manual': true,
      });

      expect(g!.jenis, JenisGalatOcrAwan.lainnya);
    });

    test('tanpa kode dan tanpa fallback_manual bukan galat OCR awan', () {
      expect(petakan(401, {'message': 'Unauthenticated.'}), isNull);
      expect(petakan(500, const {}), isNull);
    });
  });

  group('MetaOcrAwan', () {
    test('sisa_sel_lembar dibaca; hilang -> null', () {
      expect(MetaOcrAwan.dariJson({'sisa_sel_lembar': 120}).sisaSelLembar, 120);
      expect(
        MetaOcrAwan.dariJson({'sisa_sel_lembar': 120.0}).sisaSelLembar,
        120,
      );
      expect(MetaOcrAwan.dariJson(const {}).sisaSelLembar, isNull);
      expect(MetaOcrAwan.dariJson(null).sisaSelLembar, isNull);
    });
  });

  group('BarisTemplate.tipe', () {
    Map<String, dynamic> baris(Object? tipe) => {
      'baris_ke': 1,
      'titik_ukur': 4,
      'label': 'pH 4',
      'tipe': ?tipe,
    };

    test('angka dan jam dibaca apa adanya', () {
      expect(BarisTemplate.fromJson(baris('angka')).tipe, 'angka');
      expect(BarisTemplate.fromJson(baris('jam')).tipe, 'jam');
    });

    test('hilang atau bukan teks -> null (gagal tertutup, bukan angka)', () {
      expect(BarisTemplate.fromJson(baris(null)).tipe, isNull);
      expect(BarisTemplate.fromJson(baris(5)).tipe, isNull);
    });
  });
}
