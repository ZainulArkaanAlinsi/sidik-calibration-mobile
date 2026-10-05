import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Baris tabel bisa DITAMBAH di lembar yang nominalnya diketik teknisi.
///
/// Laporan lapangan 5 Okt 2026: set anak timbangan 15 keping, kertas cuma
/// sepuluh baris. Kelima keping sisanya tidak punya tempat.
void main() {
  const peran = ['at_s1', 'at_t1', 'at_t2', 'at_s2'];

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
    clientRequestId: 'uji-tambah-baris',
  )..alat = const EquipmentLookup(
      id: 36,
      namaAlat: 'Anak Timbangan',
      serialNumber: 'DEMO-AT-001',
      kategori: 'massa',
      status: 'aktif',
      satuan: 'g',
      rangeMax: 500,
      resolusi: 0.0001,
    );

  List<TabelHasil> tabelHasil(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel;

  void isiKeping(LembarKerjaState isian, int i, double nominal) {
    final tabel = tabelHasil(isian);
    for (var k = 0; k < tabel.length; k++) {
      final t = tabel[k];
      final ts = isian.titikUntukBaris(isian.barisTabel(t), i, t)!;
      if (k == 0) ts.titikCtl.text = '$nominal';
      for (var r = 0; r < 3; r++) {
        ts.kotak(t.kunciTabel, 'pembacaan', r).text =
            '${nominal + (k == 1 || k == 2 ? 0.0001 : 0) + r * 0.00001}';
      }
    }
  }

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .where((m) => m.containsKey('at_s1'))
      .toList();

  test('tombol tambah baris menambah KEEMPAT tabel ABBA sekaligus', () {
    final isian = isianBaru();
    final tabel = tabelHasil(isian);

    expect(isian.barisTabel(tabel.first).length, 10);
    expect(isian.bisaTambahBaris(tabel.last), isTrue);

    isian.tambahBaris(5);

    for (final t in tabel) {
      final baris = isian.barisTabel(t);
      expect(baris.length, 15, reason: 'tabel ${t.kunciTabel} tidak ikut bertambah');
      expect(baris.last.label, 'Keping 15');
      expect(baris.last.titikDitentukan, isFalse);
    }
  });

  test('isian yang sudah diketik tidak hilang waktu baris ditambah', () {
    final isian = isianBaru();
    isiKeping(isian, 0, 100);
    final sebelum = kiriman(isian);

    isian.tambahBaris();

    expect(kiriman(isian), sebelum);
  });

  test('15 keping terkirim, dan draft yang dibuka ulang memulihkan kelimabelasnya', () {
    final asal = isianBaru()..tambahBaris(5);
    const nominal = [
      1.0, 2.0, 2.0, 5.0, 10.0, 20.0, 20.0, 50.0, 100.0, 200.0,
      200.0, 500.0, 0.5, 0.2, 0.1,
    ];
    for (var i = 0; i < nominal.length; i++) {
      isiKeping(asal, i, nominal[i]);
    }

    final kirimAsal = kiriman(asal);
    expect(kirimAsal, hasLength(15));

    // Baris `raw_measurements` persis seperti yang disimpan server
    // (`CalibrationController::susunBlokAnakTimbangan`): keping berurutan.
    final mentah = <RawMeasurement>[];
    var id = 1;
    for (var k = 0; k < kirimAsal.length; k++) {
      final m = kirimAsal[k];
      for (final p in peran) {
        final nilai = (m[p] as List).cast<double>();
        for (var r = 0; r < nilai.length; r++) {
          mentah.add(RawMeasurement(
            id: id++,
            titikKe: k + 1,
            titikUkur: (m['titik_ukur'] as num).toDouble(),
            pembacaanKe: r + 1,
            sensorKe: 1,
            pembacaan: nilai[r],
            peranSensor: p,
            inputSource: 'manual',
            isVerified: true,
          ));
        }
      }
    }

    final pulih = isianBaru();
    final kebuang = pulih.terapkanPembacaan(mentah);

    expect(kebuang, 0, reason: 'keping ke-11 dst. kebuang waktu draft dibuka ulang');
    expect(pulih.barisTabel(tabelHasil(pulih).first).length, 15);
    expect(kiriman(pulih), kirimAsal,
        reason: 'draft yang dibuka ulang mengirim keping yang beda');
  });

  test('lembar bertitik cetak (pH) tidak mendapat tombol tambah baris', () {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uji-ph',
    );

    for (final bagian in isian.bentuk.bagian) {
      for (final t in bagian.tabel) {
        expect(isian.bisaTambahBaris(t), isFalse);
      }
    }
  });
}
