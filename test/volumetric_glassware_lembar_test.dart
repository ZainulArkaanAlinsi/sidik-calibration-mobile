import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetric_glassware.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Volumetric Glassware (alat ke-34..39) — bentuk ASLI server (digenerate ke
/// `contoh_lembar_kerja_volumetric_glassware.dart`) disuapkan ke parser dan
/// penyusun payload.
///
/// Yang dijaga PAYLOAD-nya. Seperti Hydrometer, tidak ada angka di sertifikat
/// yang pernah diketik manusia: V20 lahir di server dari berat kosong, berat
/// isi, dan suhu air. Deret yang berangkat kosong atau tertukar tidak
/// menghasilkan lembar kosong, melainkan volume yang kelihatan wajar.
void main() {
  LembarKerjaState isianDari(Map<String, dynamic> bentuk) {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentuk),
      clientRequestId: 'uji-volumetric',
    );

    isian.alat = const EquipmentLookup(
      id: 34,
      namaAlat: 'Gelas Ukur 100 mL',
      serialNumber: 'DEMO-VOL-004',
      kategori: 'volume',
      status: 'aktif',
      satuan: 'ml',
      rangeMax: 100,
      resolusi: 1,
    );

    return isian;
  }

  List<TabelHasil> tabelHasil(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel;

  /// Isi satu baris ketiga tabel. [nominalDiSemua] = kotak nominal diketik di
  /// ketiga tabel; `false` = cuma di tabel pertama (berat kosong).
  void isiBaris(
    LembarKerjaState isian,
    int i,
    String nominal,
    List<List<String>> deret, {
    bool nominalDiSemua = true,
  }) {
    final tabel = tabelHasil(isian);
    for (var k = 0; k < tabel.length; k++) {
      final t = tabel[k];
      final ts = isian.titikUntukBaris(isian.barisTabel(t), i, t)!;
      if (k == 0 || nominalDiSemua) ts.titikCtl.text = nominal;
      for (var r = 0; r < 3; r++) {
        ts.kotak(t.kunciTabel, 'pembacaan', r).text = deret[k][r];
      }
    }
  }

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .where((m) => m.containsKey('vol_kosong'))
      .toList();

  test('mode mock keenam alat tidak jatuh ke lembar pH', () async {
    final layanan = MockLembarKerjaService();

    const harap = {
      'labu_ukur': 'SIDIK-FM-CAL-0513_Rev.4',
      'pipet_volume': 'SIDIK-FM-CAL-0513_Rev.4',
      'picnometer': 'SIDIK-FM-CAL-0513_Rev.4',
      'buret': 'SIDIK-FM-CAL-0514_Rev.4',
      'gelas_ukur': 'SIDIK-FM-CAL-0514_Rev.4',
      'pipet_ukur': 'SIDIK-FM-CAL-0514_Rev.4',
    };

    for (final e in harap.entries) {
      final bentuk = await layanan.ambilBentuk('mock-token-1', profil: e.key);
      expect(bentuk.kodeDokumen, e.value, reason: '${e.key} jatuh ke lembar lain');
      expect(bentuk.judul, contains('Volumetric Glassware'));
    }
  });

  test('ketiga deret menempel di SATU measurements[i], koma dibaca desimal', () {
    final isian = isianDari(contohBentukLembarKerjaGelasUkur());

    // Angka master `Graduated_Volumetric_Glassware_2026`, titik 10 mL.
    isiBaris(isian, 0, '10', [
      ['60,234', '60,24', '60,243'],
      ['70,7791', '70,7965', '70,8854'],
      ['25,4', '25,3', '25,4'],
    ]);

    final titik = kiriman(isian).single;

    expect(titik['titik_ukur'], closeTo(10.0, 1e-9));
    expect((titik['vol_kosong'] as List).whereType<double>().toList(), [60.234, 60.24, 60.243]);
    expect((titik['vol_isi'] as List).whereType<double>().toList(), [70.7791, 70.7965, 70.8854]);
    expect((titik['vol_suhu'] as List).whereType<double>().toList(), [25.4, 25.3, 25.4]);
  });

  test('ketiga tabel tidak berbagi kotak isian', () {
    final isian = isianDari(contohBentukLembarKerjaGelasUkur());
    final tabel = tabelHasil(isian);

    expect(tabel, hasLength(3));
    expect({for (final t in tabel) t.offsetKunci}, hasLength(3),
        reason: 'ketiga tabel harus punya offset_kunci yang berbeda');

    final pertama = isian.titikUntukBaris(isian.barisTabel(tabel[0]), 0, tabel[0])!;
    pertama.kotak(tabel[0].kunciTabel, 'pembacaan', 0).text = '60,234';

    for (final t in tabel.skip(1)) {
      final ts = isian.titikUntukBaris(isian.barisTabel(t), 0, t)!;
      expect(ts.kotak(t.kunciTabel, 'pembacaan', 0).text, isEmpty,
          reason: 'kotak ${t.simpanKe} ikut terisi — kunci barisnya bentrok');
    }
  });

  test('Fixed satu slot, Graduated lima slot; yang tidak diisi gugur', () {
    final fixed = isianDari(contohBentukLembarKerjaPipetVolume());
    for (final t in tabelHasil(fixed)) {
      expect(fixed.barisTabel(t), hasLength(1));
      expect(t.titikBisaDiubah, isFalse);
    }

    final graduated = isianDari(contohBentukLembarKerjaBuret());
    for (final t in tabelHasil(graduated)) {
      expect(graduated.barisTabel(t), hasLength(5));
      expect(t.titikBisaDiubah, isFalse);
    }

    // Teknisi mengisi DUA dari lima slot.
    for (var i = 0; i < 2; i++) {
      isiBaris(graduated, i, ['10', '50'][i], [
        ['60,234', '60,24', '60,243'],
        ['70,7791', '70,7965', '70,8854'],
        ['25,4', '25,3', '25,4'],
      ]);
    }

    expect(kiriman(graduated), hasLength(2),
        reason: 'slot yang dibiarkan kosong ikut berangkat');
  });

  /// Nominal cukup diketik di tabel PERTAMA? Kalau penjaga set point menahan
  /// baris tabel kedua & ketiga, teknisi dipaksa mengetik nominal yang sama
  /// tiga kali — dan salah ketik di salah satunya tidak ketahuan.
  test('nominal di tabel pertama saja tidak menahan pengiriman', () {
    final isian = isianDari(contohBentukLembarKerjaGelasUkur());

    isiBaris(
      isian,
      0,
      '10',
      [
        ['60,234', '60,24', '60,243'],
        ['70,7791', '70,7965', '70,8854'],
        ['25,4', '25,3', '25,4'],
      ],
      nominalDiSemua: false,
    );

    expect(
      isian.titikTanpaSetPoint.map((t) => t.label),
      isEmpty,
      reason: 'baris tabel berat isi / suhu ketahan penjaga set point',
    );
    expect(kiriman(isian).single['titik_ukur'], closeTo(10.0, 1e-9));
  });

  /// Arah sebaliknya: pelonggaran di atas tidak boleh kebablasan. Baris yang
  /// angkanya terisi tapi TABEL PERTAMANYA pun tanpa nominal tetap ditahan —
  /// kalau tidak, nomor baris (1..5) berangkat sebagai nominal mL.
  test('tanpa nominal di tabel pertama, baris tetap ditahan', () {
    final isian = isianDari(contohBentukLembarKerjaGelasUkur());

    isiBaris(
      isian,
      0,
      '',
      [
        ['60,234', '60,24', '60,243'],
        ['70,7791', '70,7965', '70,8854'],
        ['25,4', '25,3', '25,4'],
      ],
      nominalDiSemua: false,
    );

    expect(isian.titikTanpaSetPoint, hasLength(3),
        reason: 'ketiga tabel baris itu mestinya ditahan — nominalnya belum ada di mana pun');
  });

  test('blok sesi: kapasitas, kelas A/B, toleransi, neraca per keluarga, tekanan hPa', () {
    Map<String, FieldLembarKerja> fieldIdentitas(Map<String, dynamic> bentuk) {
      final isian = isianDari(bentuk);
      final identitas = isian.bentuk.bagian.firstWhere((b) => b.kode == 'identitas_alat');
      return {for (final f in identitas.field) f.kode: f};
    }

    final fixed = fieldIdentitas(contohBentukLembarKerjaLabuUkur());
    final graduated = fieldIdentitas(contohBentukLembarKerjaGelasUkur());

    for (final f in [fixed, graduated]) {
      expect(f['spesifikasi_alat.volumetric.kapasitas_ml'], isNotNull);
      expect(f['spesifikasi_alat.volumetric.toleransi_ml'], isNotNull);
      expect(f['tekanan_awal']!.satuan, 'hPa');
      expect(f['tekanan_akhir']!.satuan, 'hPa');

      final kelas = f['spesifikasi_alat.volumetric.kelas']!;
      expect(kelas.tipe, TipeField.pilihan);
      expect([for (final p in kelas.pilihan) p.nilai], ['A', 'B']);
    }

    // Resolusi cuma milik alat berskala.
    expect(fixed['spesifikasi_alat.volumetric.resolusi_ml'], isNull);
    expect(graduated['spesifikasi_alat.volumetric.resolusi_ml'], isNotNull);

    // Neraca ketiga beda fisik: Fujitsu di Fixed, Precisa di Graduated.
    List<String> neraca(Map<String, FieldLembarKerja> f) =>
        [for (final p in f['spesifikasi_alat.volumetric.neraca']!.pilihan) p.nilai];
    expect(neraca(fixed), contains('Electronic Balance Fujitsu'));
    expect(neraca(fixed), isNot(contains('Electronic Balance Precisa')));
    expect(neraca(graduated), contains('Electronic Balance Precisa'));
    expect(neraca(graduated), isNot(contains('Electronic Balance Fujitsu')));
  });
}
