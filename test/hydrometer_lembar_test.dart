import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetrik.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Hydrometer (alat ke-33, kelompok Volumetrik) — bentuk ASLI server
/// (digenerate ke `contoh_lembar_kerja_volumetrik.dart`) disuapkan ke parser dan
/// penyusun payload.
///
/// Yang dijaga PAYLOAD-nya, bukan tampilan. TIDS, Timbangan, Micrometer, dan
/// Anak Timbangan sama-sama lembar yang kegambar rapi tapi berangkat tanpa kunci
/// yang dibaca server — nol titik terhitung, tanpa error di kedua sisi.
///
/// Di alat INI akibatnya paling mahal dari kelimanya: tidak ada satu pun angka
/// di sertifikat Hydrometer yang pernah diketik manusia. Kolom `Actual Value`
/// lahir dari metode Cuckow di server, jadi kalau deret massa atau deret suhu
/// berangkat kosong (atau tertukar), yang terbit bukan lembar kosong melainkan
/// densitas yang kelihatan wajar di nominal yang salah.
void main() {
  LembarKerjaState isianDari(Map<String, dynamic> bentuk) {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentuk),
      clientRequestId: 'uji-hydrometer',
    );

    isian.alat = const EquipmentLookup(
      id: 33,
      namaAlat: 'Hydrometer Alla France L50',
      serialNumber: '350015',
      kategori: 'volumetrik',
      status: 'aktif',
      satuan: 'g/ml',
      rangeMax: 0.65,
      resolusi: 0.0005,
    );

    return isian;
  }

  TabelHasil tabel(LembarKerjaState isian, String bagian, [int i = 0]) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == bagian).tabel[i];

  test('mode mock tidak jatuh ke lembar pH', () async {
    final layanan = MockLembarKerjaService();
    final bentuk = await layanan.ambilBentuk('mock-token-1', profil: 'hydrometer');

    expect(
      bentuk.judul.toLowerCase(),
      isNot(contains('ph')),
      reason: 'hydrometer jatuh ke lembar pH',
    );
    expect(bentuk.judul, contains('Hydrometer'));
    expect(bentuk.kodeDokumen, 'SIDIK-FM-CAL-0533_Rev.2');
  });

  test('dua tabel Measurement terkirim dengan kunci deretnya masing-masing', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final massa = tabel(isian, 'hasil', 0);
    final suhu = tabel(isian, 'hasil', 1);

    // Angka master `Master Olah Data Hydrometer 0.600-0.650`, titik skala
    // pertama — dan diketik BERKOMA, karena itu yang ditampilkan keyboard angka
    // HP Indonesia.
    final barisMassa = isian.barisTabel(massa);
    final titikMassa = isian.titikUntukBaris(barisMassa, 0, massa)!;
    // Kotak `Point of Calibration` DIKETIK teknisi — barisnya lahir dengan
    // `titik_ukur: null`, sama seperti kelima tabel Flowmeter.
    titikMassa.titikCtl.text = '0,610';
    const bacaan = ['21,2727', '21,2726', '21,2856'];
    for (var r = 0; r < bacaan.length; r++) {
      titikMassa.kotak(massa.kunciTabel, 'pembacaan', r).text = bacaan[r];
    }

    final barisSuhu = isian.barisTabel(suhu);
    final titikSuhu = isian.titikUntukBaris(barisSuhu, 0, suhu)!;
    titikSuhu.titikCtl.text = '0,610';
    for (var r = 0; r < 3; r++) {
      titikSuhu.kotak(suhu.kunciTabel, 'pembacaan', r).text = '20,6';
    }

    final json = isian
        .toSubmission(draft: true)
        .measurements
        .map((m) => m.toJson())
        .toList();

    final titik = json.firstWhere((m) => m.containsKey('hydro_massa'));

    // KEDUA deret di SATU `measurements[i]`. Terpisah jadi dua entri, server
    // menolak keduanya sebagai titik yang tidak sinkron.
    expect(
      titik.containsKey('hydro_suhu'),
      isTrue,
      reason: 'deret suhu mestinya menempel di titik yang sama dengan deret massa',
    );
    expect(
      (titik['hydro_massa'] as List).whereType<double>().toList(),
      [21.2727, 21.2726, 21.2856],
      reason: 'koma mestinya dibaca sebagai koma DESIMAL, bukan dibuang',
    );
    expect(
      (titik['hydro_suhu'] as List).whereType<double>().toList(),
      [20.6, 20.6, 20.6],
    );
  });

  /// Ketiga tabel lembar ini ber-`tahap` sama, dan barisnya lahir tanpa
  /// `titik_ukur` — jadi `kunciBaris` jatuh ke `nomor`, yang sama-sama 1 di
  /// ketiganya. Tanpa `offset_kunci` yang berbeda mereka berbagi satu
  /// `Map<double, TitikState>`: angka yang diketik di tabel massa muncul di
  /// kotak suhu, dan yang terkirim salah satunya saja. Nol error di kedua sisi.
  test('kotak massa, suhu, dan diameter stem tidak berbagi kotak isian', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final massa = tabel(isian, 'hasil', 0);
    final suhu = tabel(isian, 'hasil', 1);
    final stem = tabel(isian, 'pre_condition', 0);

    final tMassa = isian.titikUntukBaris(isian.barisTabel(massa), 0, massa)!;
    final tSuhu = isian.titikUntukBaris(isian.barisTabel(suhu), 0, suhu)!;
    final tStem = isian.titikUntukBaris(isian.barisTabel(stem), 0, stem)!;

    tMassa.kotak(massa.kunciTabel, 'pembacaan', 0).text = '21,2727';

    expect(tSuhu.kotak(suhu.kunciTabel, 'pembacaan', 0).text, isEmpty,
        reason: 'kotak suhu ikut terisi — kunci barisnya bentrok dengan tabel massa');
    expect(tStem.kotak(stem.kunciTabel, 'pembacaan', 0).text, isEmpty,
        reason: 'kotak diameter stem ikut terisi — kunci barisnya bentrok');

    expect(massa.offsetKunci, isNotNull);
    expect(suhu.offsetKunci, isNotNull);
    expect(stem.offsetKunci, isNotNull);
    expect(
      {massa.offsetKunci, suhu.offsetKunci, stem.offsetKunci},
      hasLength(3),
      reason: 'ketiga tabel harus punya offset_kunci yang berbeda',
    );
  });

  /// Titik yang ditambah teknisi hidup di SATU daftar milik seluruh lembar
  /// (`titikKustom`), jadi dua tabel yang sama-sama `titik_bisa_diubah: true`
  /// tumbuh berbarengan. Kalau salah satunya `false`, tabel suhu berhenti di
  /// tiga baris bawaan sementara tabel massa tumbuh — dan baris massa ke-4
  /// sampai ke server tanpa pasangan suhunya, lalu ditolak.
  test('menambah titik menumbuhkan KEDUA tabel bersamaan', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final massa = tabel(isian, 'hasil', 0);
    final suhu = tabel(isian, 'hasil', 1);

    expect(massa.titikBisaDiubah, isTrue);
    expect(suhu.titikBisaDiubah, isTrue,
        reason: 'tabel suhu harus ikut bisa diubah, kalau tidak dia tertinggal');

    isian.aturTitik([0.610, 0.625, 0.650, 0.675]);

    expect(isian.barisTabel(massa), hasLength(4));
    expect(
      isian.barisTabel(suhu),
      hasLength(4),
      reason: 'tabel suhu tidak ikut tumbuh — titik keempat bakal berangkat tanpa suhu',
    );
  });

  /// Kotak `Sl` cuma muncul kalau toggle beban tambahan menyala. Itu yang
  /// membuat "kosong karena tidak perlu" tidak tertukar dengan "kosong karena
  /// lupa" — dan bedanya bukan kerapian: rumus varian yang salah memulangkan
  /// densitas yang tampak wajar dan meleset beberapa persen.
  test('kotak Sl bergantung pada toggle beban tambahan', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final pre = isian.bentuk.bagian.firstWhere((b) => b.kode == 'pre_condition');

    final toggle = pre.field.firstWhere(
      (f) => f.kode == 'spesifikasi_alat.hydrometer.pakai_beban_tambahan',
    );
    final sl = pre.field.firstWhere(
      (f) => f.kode == 'spesifikasi_alat.hydrometer.beban_tambahan',
    );

    // DROPDOWN, bukan tipe karangan. `TipeField.fromApi` cuma mengenal tujuh
    // tipe dan yang tak dikenal jatuh ke `TipeField.teks` TANPA error — teknisi
    // bakal melihat kotak ketikan bebas untuk pertanyaan yang menentukan rumus
    // mana yang dipakai, dan apa pun yang diketik dibaca server sebagai
    // "tidak".
    expect(toggle.tipe, TipeField.pilihan);
    expect(
      [for (final p in toggle.pilihan) p.nilai],
      ['ya', 'tidak'],
    );
    expect(sl.tampilKalau, isNotNull,
        reason: 'kotak Sl mestinya bergantung pada pilihan varian, bukan selalu tampil');
    expect(sl.tampilKalau!.kode, toggle.kode);
    expect(sl.tampilKalau!.nilai, ['ya']);
  });

  /// Tanpa tekanan udara tidak ada densitas udara, dan tanpa densitas udara
  /// tidak ada satu pun suku rumus Cuckow yang bisa dihitung. Kertas
  /// `SIDIK-FM-CAL-0533_Rev.2` tidak mencetak kotaknya — lihat
  /// `docs/pertanyaan-lab-hydrometer.md` §9 di repo API — jadi kalau lembar HP
  /// ikut kehilangan kotaknya, sesinya tidak akan pernah bisa diterbitkan.
  test('lembar punya kotak tekanan udara (hPa)', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final identitas = isian.bentuk.bagian.firstWhere(
      (b) => b.kode == 'identitas_alat',
    );

    final kode = [for (final f in identitas.field) f.kode];

    expect(kode, contains('tekanan_awal'));
    expect(kode, contains('tekanan_akhir'));
    expect(
      identitas.field.firstWhere((f) => f.kode == 'tekanan_awal').satuan,
      'hPa',
      reason: 'satuannya WAJIB hPa — rumus densitas udara membacanya sebagai hPa',
    );
  });

  /// `tr` dropdown, bukan teks bebas: salah ketik menggeser SELURUH koreksi
  /// tanpa gejala. Daftarnya dari catatan master (`PERHITUNGAN!AE39`).
  test('suhu acuan alat (tr) dropdown 15 / 20 / 27,5', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final pre = isian.bentuk.bagian.firstWhere((b) => b.kode == 'pre_condition');
    final tr = pre.field.firstWhere(
      (f) => f.kode == 'spesifikasi_alat.hydrometer.suhu_acuan_alat',
    );

    expect(tr.tipe, TipeField.pilihan);
    expect(
      [for (final p in tr.pilihan) p.nilai],
      containsAll(<String>['15', '20', '27.5']),
    );
  });
}
