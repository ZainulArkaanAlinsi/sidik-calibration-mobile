import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/services/mock_store.dart';

/// Penyimpan di memori — niru disk tanpa nyentuh disk beneran.
class PenyimpanPalsu implements PenyimpanMockStore {
  PenyimpanPalsu([this.isi]);

  String? isi;
  int jumlahTulis = 0;

  @override
  Future<String?> baca() async => isi;

  @override
  Future<void> tulis(String data) async {
    isi = data;
    jumlahTulis++;
  }
}

/// Penyimpan yang selalu gagal — niru disk penuh / izin dicabut.
class PenyimpanRusak implements PenyimpanMockStore {
  @override
  Future<String?> baca() async => throw Exception('disk nggak kebaca');

  @override
  Future<void> tulis(String isi) async => throw Exception('disk nggak ketulis');
}

void main() {
  setUp(MockStore.instance.reset);
  tearDown(MockStore.instance.reset);

  group('sesi tes berhenti ilang tiap app ditutup', () {
    /// Ini keluhan aslinya: sesi yang diisi berhari-hari nggak ada waktu app
    /// dibuka lagi. Bukan kehapus — dulu memang nggak pernah disimpan.
    test('sesi yang dikirim kebaca lagi sesudah app "dibuka ulang"', () async {
      final disk = PenyimpanPalsu();

      await MockStore.instance.pulihkan(disk);
      final id = MockStore.instance.tambahSesi(
        namaAlat: 'Chlorine Meter Hanna',
        namaTeknisi: 'Teknisi',
      );
      MockStore.instance.setujui(id);

      // App ditutup & dibuka lagi: store balik kosong, disk-nya tetap.
      MockStore.instance.reset();
      expect(MockStore.instance.sesi, isEmpty);

      await MockStore.instance.pulihkan(disk);

      expect(MockStore.instance.sesi, hasLength(1));
      final sesi = MockStore.instance.sesi.first;
      expect(sesi.namaAlat, 'Chlorine Meter Hanna');
      expect(sesi.status, CalibrationStatus.disetujui);
      expect(sesi.keputusan, Keputusan.pass);
      expect(sesi.certificateId, isNotNull);
    });

    /// Kalau id-nya balik ke 500 tiap buka app, sesi baru bakal nabrak id sesi
    /// lama — dan `setujui`/`tolak` kena baris yang salah tanpa ada error.
    test('id lanjut dari yang tersimpan, bukan mulai ulang', () async {
      final disk = PenyimpanPalsu();

      await MockStore.instance.pulihkan(disk);
      final pertama = MockStore.instance.tambahSesi(
        namaAlat: 'A',
        namaTeknisi: 'T',
      );

      MockStore.instance.reset();
      await MockStore.instance.pulihkan(disk);
      final kedua = MockStore.instance.tambahSesi(
        namaAlat: 'B',
        namaTeknisi: 'T',
      );

      expect(kedua, greaterThan(pertama));
      expect(MockStore.instance.sesi.map((s) => s.id).toSet(), hasLength(2));
    });

    test('catatan penolakan ikut kesimpen', () async {
      final disk = PenyimpanPalsu();

      await MockStore.instance.pulihkan(disk);
      final id = MockStore.instance.tambahSesi(namaAlat: 'A', namaTeknisi: 'T');
      MockStore.instance.tolak(id, 'Buffer 7 cuma 2 bacaan.');

      MockStore.instance.reset();
      await MockStore.instance.pulihkan(disk);

      final sesi = MockStore.instance.sesi.first;
      expect(sesi.status, CalibrationStatus.perluRevisi);
      expect(sesi.catatanRevisi, 'Buffer 7 cuma 2 bacaan.');
    });
  });

  group('nyimpen nggak boleh bikin app mati', () {
    test('disk rusak → app tetap jalan, cuma nggak ada yang kesimpen', () async {
      // Data mock ilang itu nggak enak; app yang nggak mau kebuka gara-gara
      // satu baris JSON rusak jauh lebih buruk.
      await MockStore.instance.pulihkan(PenyimpanRusak());

      expect(MockStore.instance.sesi, isEmpty);
      expect(
        () => MockStore.instance.tambahSesi(namaAlat: 'A', namaTeknisi: 'T'),
        returnsNormally,
      );
    });

    test('isi simpanan cacat dilewat, sisanya tetap kebaca', () async {
      final disk = PenyimpanPalsu(
        '{"sesi":['
        '{"id":1,"nama_alat":"Sehat","nama_teknisi":"T",'
        '"tanggal_kalibrasi":"2026-08-05T10:00:00.000","status":"disetujui"},'
        '{"id":"bukan angka","nama_alat":"Cacat"}'
        '],"id_berikutnya":600,"id_sertifikat_berikutnya":1000}',
      );

      await MockStore.instance.pulihkan(disk);

      expect(MockStore.instance.sesi, hasLength(1));
      expect(MockStore.instance.sesi.first.namaAlat, 'Sehat');
    });

    test('JSON ngawur sama sekali nggak ngelempar', () async {
      await MockStore.instance.pulihkan(PenyimpanPalsu('bukan json'));
      expect(MockStore.instance.sesi, isEmpty);
    });
  });

  group('tanpa penyimpan tetap jalan di memori', () {
    /// Test lain di repo ini manggil MockStore tanpa pernah `pulihkan` —
    /// jangan sampai itu jadi nulis ke disk beneran.
    test('nggak ada penyimpan → nggak ada yang ditulis', () {
      final id = MockStore.instance.tambahSesi(namaAlat: 'A', namaTeknisi: 'T');

      expect(id, 500);
      expect(MockStore.instance.sesi, hasLength(1));
    });

    test('reset ngelupain penyimpan biar test nggak bocor ke test lain', () async {
      final disk = PenyimpanPalsu();
      await MockStore.instance.pulihkan(disk);
      MockStore.instance.tambahSesi(namaAlat: 'A', namaTeknisi: 'T');
      final sebelum = disk.jumlahTulis;

      MockStore.instance.reset();
      MockStore.instance.tambahSesi(namaAlat: 'B', namaTeknisi: 'T');

      expect(disk.jumlahTulis, sebelum, reason: 'nggak nulis lagi sesudah reset');
    });
  });
}
