import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';

/// No. Identitas / seri per keping Anak Timbangan: terkirim per baris, dan
/// pulih di baris yang benar waktu draft dibuka ulang.
///
/// Keping KEMBAR (2+2 g, 20+20 g) wajib beridentitas supaya terbit, dan sampai
/// 5 Okt 2026 lembar HP tidak punya kotaknya.
void main() {
  const peran = ['at_s1', 'at_t1', 'at_t2', 'at_s2'];

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
    clientRequestId: 'uji-identitas',
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

  void setIdentitas(LembarKerjaState isian, int i, String nilai) {
    final t = tabelHasil(isian).first;
    isian
        .titikUntukBaris(isian.barisTabel(t), i, t)!
        .kotakBarisCtl(t.kunciTabel, 'no_identitas')
        .text = nilai;
  }

  void isiKeping(LembarKerjaState isian, int i, double nominal) {
    final tabel = tabelHasil(isian);
    for (var k = 0; k < tabel.length; k++) {
      final t = tabel[k];
      final ts = isian.titikUntukBaris(isian.barisTabel(t), i, t)!;
      if (k == 0) ts.titikCtl.text = '$nominal';
      for (var r = 0; r < 3; r++) {
        ts.kotak(t.kunciTabel, 'pembacaan', r).text = '$nominal';
      }
    }
  }

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .where((m) => m.containsKey('at_s1'))
      .toList();

  test('tabel S1 punya kotak identitas bertipe teks', () {
    final s1 = tabelHasil(isianBaru()).first;
    final kotak = s1.kolomBaris.where((f) => f.kode == 'no_identitas');

    expect(kotak, hasLength(1));
    expect(kotak.single.tipe, TipeField.teks);
  });

  test('identitas terkirim per keping; baris kosong tidak ikut', () {
    final isian = isianBaru();
    isiKeping(isian, 0, 20);
    isiKeping(isian, 2, 20);
    setIdentitas(isian, 0, '20');
    setIdentitas(isian, 1, 'X-BARIS-KOSONG');
    setIdentitas(isian, 2, '20*');

    final kirim = kiriman(isian);

    expect(kirim, hasLength(2));
    expect(kirim[0]['no_identitas'], '20');
    expect(kirim[1]['no_identitas'], '20*');
  });

  test('identitas yang dikosongkan tetap terkirim sebagai teks kosong', () {
    final isian = isianBaru();
    isiKeping(isian, 0, 100);

    expect(kiriman(isian).single['no_identitas'], '');
  });

  test('draft dibuka ulang: identitas pulih di keping yang benar', () {
    final asal = isianBaru();
    const nominal = [2.0, 2.0, 5.0, 20.0, 20.0];
    const penanda = ['2', '2*', '', 'SN-20-A', 'SN-20-B'];
    for (var i = 0; i < nominal.length; i++) {
      isiKeping(asal, i, nominal[i]);
      setIdentitas(asal, i, penanda[i]);
    }
    final kirimAsal = kiriman(asal);

    // Server: identitas[titik_ke] (CalibrationRequest::identitasKepingDariBaris).
    final mentah = <RawMeasurement>[];
    final identitasServer = <String, String>{};
    var id = 1;
    for (var k = 0; k < kirimAsal.length; k++) {
      final m = kirimAsal[k];
      if ((m['no_identitas'] as String).isNotEmpty) {
        identitasServer['${k + 1}'] = m['no_identitas'] as String;
      }
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

    final detail = IsianTeknisi.fromJson({
      'spesifikasi_alat': {
        'anak_timbangan': {'identitas': identitasServer},
      },
    });

    // Dua urutan pemanggilan — keduanya harus berujung sama.
    for (final spesifikasiDulu in [true, false]) {
      final pulih = isianBaru();
      if (spesifikasiDulu) pulih.muatDariSesi(detail);
      expect(pulih.terapkanPembacaan(mentah), 0);
      if (!spesifikasiDulu) pulih.muatDariSesi(detail);

      expect(
        kiriman(pulih),
        kirimAsal,
        reason: 'identitas pulih di keping yang salah (spesifikasi dulu: $spesifikasiDulu)',
      );
    }
  });
}
