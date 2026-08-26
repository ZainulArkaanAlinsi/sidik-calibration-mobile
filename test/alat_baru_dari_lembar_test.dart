import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';

/// Lembar yang belum punya alat berhenti jadi jalan buntu.
///
/// ## Kegagalan yang ditutup berkas ini
///
/// Dropdown "Pilih alat" disaring ke lembar yang lagi dibuka — dan itu benar:
/// sebelum ada saringan, teknisi yang membuka lembar Refrigerator disodori
/// SELURUH alat lab, dan salah pilih di situ nggak bikin error di mana pun.
/// Sesinya tersimpan, lalu dihitung pakai aturan alat lain.
///
/// Tapi saringan itu bikin kategori yang belum punya satu alat pun jadi BUNTU:
/// dropdown-nya mati ("Belum ada alat."), dan tombol kirim menahan sesi yang
/// alatnya belum dipilih. Lembar Bath persis begitu — bisa dibuka, bisa
/// dibaca, nggak bisa dipakai.
///
/// Yang ditambah jalan keluarnya, bukan saringannya yang dilepas.
void main() {
  group('bekal alat baru dari server', () {
    test('kebaca dari bentuk lembar', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'SIDIK-IK-CAL-0512_Rev.2',
        'judul': 'Calibration Worksheet - Enclosure (Bath)',
        'untuk': 'teknisi',
        'jumlah_pengulangan': 5,
        'bagian': <dynamic>[],
        'alat_baru': {'kategori': 'suhu', 'nama_alat_kemampuan': 'Bath'},
      });

      expect(bentuk.alatBaru, isNotNull);
      expect(bentuk.alatBaru!.kategori, 'suhu');
      expect(bentuk.alatBaru!.namaAlatKemampuan, 'Bath');
    });

    test('server versi lama nggak bikin layarnya rusak', () {
      // Null bukan kesalahan: HP-nya tetap jalan, cuma tombol "Alat baru"
      // nggak digambar. Melempar di sini bikin seluruh lembar gagal dibuka
      // gara-gara satu kunci yang belum ada di server.
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'judul': 'Y',
        'untuk': 'teknisi',
        'jumlah_pengulangan': 5,
        'bagian': <dynamic>[],
      });

      expect(bentuk.alatBaru, isNull);
    });

    test('kategori boleh kosong — teknisi memilih sendiri', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'judul': 'Y',
        'untuk': 'teknisi',
        'jumlah_pengulangan': 5,
        'bagian': <dynamic>[],
        'alat_baru': {'kategori': null, 'nama_alat_kemampuan': 'Bath'},
      });

      expect(bentuk.alatBaru!.kategori, isNull);
      expect(bentuk.alatBaru!.namaAlatKemampuan, 'Bath');
    });
  });

  group('alat yang baru disimpan langsung kepakai', () {
    Equipment alatBaru() => Equipment(
      id: 77,
      namaAlat: 'Water Bath Memmert',
      serialNumber: 'WB-001',
      kategori: 'suhu',
      status: EquipmentStatus.aktif,
      merk: 'Memmert',
      model: 'WNB 14',
      noIdentifikasi: 'LAB-77',
      namaAlatKemampuan: 'Bath',
      satuan: '°C',
      rangeMin: 20,
      rangeMax: 95,
      resolusi: 0.1,
      pelangganNama: 'PT Maju Jaya',
      lokasi: 'Lab PT. Sidik',
      catatan: '',
    );

    test('kolom yang dipakai lembar kerja ikut kebawa', () {
      final lookup = EquipmentLookup.dariEquipment(alatBaru());

      // Kelimanya yang dibaca `isiDariAlat()` buat mengisi kop lembar.
      expect(lookup.id, 77);
      expect(lookup.namaAlat, 'Water Bath Memmert');
      expect(lookup.serialNumber, 'WB-001');
      expect(lookup.merk, 'Memmert');
      expect(lookup.model, 'WNB 14');
      expect(lookup.pelangganNama, 'PT Maju Jaya');
      expect(lookup.satuan, '°C');
    });

    test('cocok sama baris asli dari server begitu daftarnya ditarik ulang', () {
      // Kesetaraan `EquipmentLookup` pakai `id`. Kalau nggak, alat yang barusan
      // dibikin jadi pilihan HANTU: `value`-nya nggak ada di `items`, dan
      // Dropdown Flutter melempar — lembarnya rusak justru sesudah teknisi
      // berhasil mendaftarkan alatnya.
      final dariForm = EquipmentLookup.dariEquipment(alatBaru());

      final dariServer = EquipmentLookup.fromJson({
        'id': 77,
        'nama_alat': 'Water Bath Memmert',
        'serial_number': 'WB-001',
        'kategori': 'suhu',
        'status': 'aktif',
      });

      expect(dariForm, dariServer);
      expect(dariForm.hashCode, dariServer.hashCode);
    });
  });
}
