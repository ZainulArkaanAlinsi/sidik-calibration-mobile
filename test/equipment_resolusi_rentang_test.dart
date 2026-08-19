import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment.dart';

/// Blok "Resolusi per titik" (`equipments.resolusi_rentang`) nentuin hal yang
/// nggak kelihatan dari namanya: satuan tiap baris lembar kerja, jumlah desimal
/// yang kecetak di sertifikat, dan style sertifikat Conductivity. Sampai jalur
/// ini kebuka, angkanya cuma bisa diisi lewat panel admin — form alat di HP
/// nggak pernah nerima maupun ngirim baris-barisnya.
///
/// Yang dijaga di sini bukan tampilannya, tapi keutuhan datanya waktu bolak-
/// balik lewat mobile.
void main() {
  group('bentuk baris nggak berubah waktu bolak-balik JSON', () {
    test('baris Conductivity berkunci `titik` tetap berkunci `titik`', () {
      final json = {
        'resolusi_rentang': [
          {'titik': 25, 'satuan': 'µS/cm', 'resolusi': 0.1},
          {'titik': 1412, 'satuan': 'µS/cm', 'resolusi': 1},
          {'titik': 111, 'satuan': 'mS/cm', 'resolusi': 0.01},
        ],
        'id': 11,
        'nama_alat': 'Conductivity Meter',
        'serial_number': 'C12345-COND',
        'kategori': 'instrumen-analitik',
        'status': 'aktif',
      };

      final alat = Equipment.fromJson(json);

      expect(alat.resolusiRentang, hasLength(3));
      expect(alat.resolusiRentang.every((r) => !r.pakaiMaks), isTrue);
      expect(
        alat.toJson()['resolusi_rentang'],
        [
          {'titik': 25.0, 'satuan': 'µS/cm', 'resolusi': 0.1},
          {'titik': 1412.0, 'satuan': 'µS/cm', 'resolusi': 1.0},
          {'titik': 111.0, 'satuan': 'mS/cm', 'resolusi': 0.01},
        ],
      );
    });

    /// Ini yang bikin `maks` harus ada di model. Waktu [ResolusiTitik] cuma
    /// punya `titik`, band Turbidimeter yang lewat sini kebaca `titik: 0` dan
    /// `maks`-nya lenyap — buka form alat, simpan, dan seluruh resolusi
    /// bertingkatnya hilang tanpa satu pun error muncul.
    test('baris Turbidimeter berkunci `maks` nggak berubah jadi `titik`', () {
      final alat = Equipment.fromJson({
        'resolusi_rentang': [
          {'maks': 10, 'resolusi': 0.01},
          {'maks': 100, 'resolusi': 0.1},
          {'maks': null, 'resolusi': 1},
        ],
        'id': 9,
        'nama_alat': 'Turbidimeter',
        'serial_number': 'TB-01',
        'kategori': 'instrumen-analitik',
        'status': 'aktif',
      });

      expect(alat.resolusiRentang.every((r) => r.pakaiMaks), isTrue);
      expect(alat.resolusiRentang.every((r) => r.titik == null), isTrue);

      final kirim = alat.toJson()['resolusi_rentang'] as List<dynamic>;

      expect(kirim.every((r) => !(r as Map).containsKey('titik')), isTrue);
      expect((kirim[0] as Map)['maks'], 10.0);
      // Golongan terakhir: `maks: null` itu nilai yang SAH, bukan baris yang
      // belum diisi. Kuncinya harus tetap kekirim.
      expect((kirim[2] as Map).containsKey('maks'), isTrue);
      expect((kirim[2] as Map)['maks'], isNull);
    });
  });

  test('band kosong tetap kekirim sebagai array kosong, bukan ilang', () {
    const alat = Equipment(
      id: 14,
      namaAlat: 'pH Meter',
      serialNumber: 'B628755900',
      kategori: 'instrumen-analitik',
      status: EquipmentStatus.aktif,
      resolusi: 0.01,
    );

    // Waktu kuncinya dibuang pas kosong, baris terakhir nggak bisa dihapus
    // dari HP: backend baca "nggak nyentuh field ini" (`sometimes`) dan band
    // lamanya balik lagi begitu layarnya di-refresh.
    expect(alat.toJson().containsKey('resolusi_rentang'), isTrue);
    expect(alat.toJson()['resolusi_rentang'], isEmpty);
  });

  test('copyWith nggak ngosongin band', () {
    const alat = Equipment(
      id: 11,
      namaAlat: 'Conductivity Meter',
      serialNumber: 'C12345-COND',
      kategori: 'instrumen-analitik',
      status: EquipmentStatus.aktif,
      resolusiRentang: [
        ResolusiTitik(titik: 25, satuan: 'µS/cm', resolusi: 0.1),
      ],
    );

    expect(alat.copyWith(lokasi: 'Lab. PT. Sidik').resolusiRentang, hasLength(1));
  });

  group('ganti bentuk baris nggak ninggalin kunci lama', () {
    test('titik → ambang: `titik` dibuang', () {
      const baris = ResolusiTitik(titik: 25, satuan: 'µS/cm', resolusi: 0.1);

      final jadiAmbang = baris.salin(pakaiMaks: true, maks: 10);

      // Di backend band ber-`titik` diperiksa DULUAN dan langsung menang, jadi
      // sisa `titik` bikin `maks`-nya nggak pernah kepakai — diam, tanpa error.
      expect(jadiAmbang.titik, isNull);
      expect(jadiAmbang.toJson().containsKey('titik'), isFalse);
      expect(jadiAmbang.toJson()['maks'], 10);
    });

    test('ambang → titik: `maks` dibuang', () {
      const baris = ResolusiTitik(
        maks: 10,
        satuan: 'NTU',
        resolusi: 0.01,
        pakaiMaks: true,
      );

      final jadiTitik = baris.salin(pakaiMaks: false, titik: 1412);

      expect(jadiTitik.maks, isNull);
      expect(jadiTitik.toJson().containsKey('maks'), isFalse);
      expect(jadiTitik.toJson()['titik'], 1412);
    });
  });
}
