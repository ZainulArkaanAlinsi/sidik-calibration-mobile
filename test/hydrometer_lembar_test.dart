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

  /// Kelima slot titik dikirim SEJAK AWAL, dan yang tidak diisi gugur sendiri.
  ///
  /// Lembar ini tidak bisa memakai `titik_bisa_diubah`: panel `PengaturTitik`
  /// cuma dirender kalau `baris.every((b) => b.titikDitentukan)`, sementara
  /// semua baris di sini `titik_ukur: null` — memang harus, karena `Point of
  /// Calibration` diketik teknisi. Dua kunci itu saling meniadakan, dan tidak
  /// ada satu pun yang memberi tahu: kontraknya bilang titiknya bisa ditambah,
  /// panelnya tidak pernah muncul, dan lembarnya mentok di tiga baris bawaan.
  /// Hydrometer bertanda lima skala cuma bisa dikalibrasi tiga titik.
  ///
  /// Jadi barisnya dikirim sebanyak `TITIK_MAKS` dan `titik_bisa_diubah`
  /// dimatikan. Yang menjaga lembarnya tidak berangkat dengan dua titik kosong:
  /// `TitikState.siapKirim`, yang membuang baris tanpa `Point of Calibration`.
  test('lima slot titik dikirim, yang tidak diisi gugur dari payload', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final massa = tabel(isian, 'hasil', 0);
    final suhu = tabel(isian, 'hasil', 1);

    expect(massa.titikBisaDiubah, isFalse,
        reason: 'panel PengaturTitik nggak akan pernah muncul di lembar ini — '
            'kuncinya cuma janji yang nggak pernah ditepati');
    expect(suhu.titikBisaDiubah, isFalse,
        reason: 'kedua tabel harus sama, kalau nggak jumlah barisnya bisa menyimpang');

    expect(isian.barisTabel(massa), hasLength(5));
    expect(isian.barisTabel(suhu), hasLength(5),
        reason: 'tabel suhu harus punya slot sebanyak tabel massa');

    // Teknisi cuma mengisi TIGA dari lima, seperti kedua master contoh.
    final barisMassa = isian.barisTabel(massa);
    final barisSuhu = isian.barisTabel(suhu);

    for (var i = 0; i < 3; i++) {
      final tm = isian.titikUntukBaris(barisMassa, i, massa)!;
      tm.titikCtl.text = ['0,610', '0,625', '0,650'][i];
      for (var r = 0; r < 3; r++) {
        tm.kotak(massa.kunciTabel, 'pembacaan', r).text = '21,2727';
      }

      final ts = isian.titikUntukBaris(barisSuhu, i, suhu)!;
      ts.titikCtl.text = ['0,610', '0,625', '0,650'][i];
      for (var r = 0; r < 3; r++) {
        ts.kotak(suhu.kunciTabel, 'pembacaan', r).text = '20,6';
      }
    }

    final titik = isian
        .toSubmission(draft: true)
        .measurements
        .map((m) => m.toJson())
        .where((m) => m.containsKey('hydro_massa'))
        .toList();

    expect(
      titik,
      hasLength(3),
      reason: 'dua slot yang dibiarkan kosong ikut berangkat — server bakal '
          'melihat titik tanpa satu pun pembacaan',
    );
  });

  /// Baris yang ANGKANYA terisi tapi `Point of Calibration`-nya kosong TIDAK
  /// berangkat.
  ///
  /// Beda dari test "lima slot" di atas, yang barisnya sama sekali tidak
  /// disentuh — itu gugur karena `isi.isEmpty`, bukan karena `siapKirim`, jadi
  /// dia tetap hijau walau `siapKirim` dihapus seluruhnya. Yang diuji DI SINI
  /// mekanismenya.
  ///
  /// Tanpa saringan itu: `titik_ukur: null` bikin `BarisTabelHasil` jatuh ke
  /// `json['nomor']` (1..5) sebagai `titikUkur`, jadi barisnya berangkat dengan
  /// `titik_ukur: 4.0` — nomor baris yang menyamar jadi set point. Server
  /// menerimanya (`required|numeric` lolos) dan menghitung densitas pada
  /// nominal **4,0 g/ml**. Nol error di kedua sisi.
  ///
  /// Lembar ini yang paling kena justru karena slotnya sengaja dilebihkan jadi
  /// lima: ada dua slot yang normal dibiarkan kosong, dan teknisi yang mengetik
  /// angkanya duluan sebelum mengisi `Point of Calibration` masuk persis ke
  /// jalur ini.
  test('baris berangka tanpa Point of Calibration tidak ikut terkirim', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final massa = tabel(isian, 'hasil', 0);
    final suhu = tabel(isian, 'hasil', 1);

    final barisMassa = isian.barisTabel(massa);
    final barisSuhu = isian.barisTabel(suhu);

    // Titik 1 diisi LENGKAP berikut Point of Calibration-nya.
    final tm0 = isian.titikUntukBaris(barisMassa, 0, massa)!;
    tm0.titikCtl.text = '0,610';
    for (var r = 0; r < 3; r++) {
      tm0.kotak(massa.kunciTabel, 'pembacaan', r).text = '21,2727';
    }
    final ts0 = isian.titikUntukBaris(barisSuhu, 0, suhu)!;
    ts0.titikCtl.text = '0,610';
    for (var r = 0; r < 3; r++) {
      ts0.kotak(suhu.kunciTabel, 'pembacaan', r).text = '20,6';
    }

    // Titik 4 — angkanya diketik duluan, Point of Calibration DIBIARKAN kosong.
    final tm3 = isian.titikUntukBaris(barisMassa, 3, massa)!;
    for (var r = 0; r < 3; r++) {
      tm3.kotak(massa.kunciTabel, 'pembacaan', r).text = '25,4602';
    }
    final ts3 = isian.titikUntukBaris(barisSuhu, 3, suhu)!;
    for (var r = 0; r < 3; r++) {
      ts3.kotak(suhu.kunciTabel, 'pembacaan', r).text = '20,7';
    }

    final json = isian
        .toSubmission(draft: true)
        .measurements
        .map((m) => m.toJson())
        .where((m) => m.containsKey('hydro_massa'))
        .toList();

    expect(
      json,
      hasLength(1),
      reason: 'baris tanpa Point of Calibration ikut berangkat — set point-nya '
          'bakal jadi NOMOR BARIS, dan server ngitung densitas di nominal itu',
    );
    expect(json.single['titik_ukur'], closeTo(0.610, 1e-9));
  });

  /// Tabel "D Stem" TIDAK boleh menahan pengiriman.
  ///
  /// Dia ada di `pre_condition` dan menyatakan `simpan_ke:
  /// spesifikasi_alat.hydrometer.diameter_stem` — bukan titik ukur, cuma blok
  /// spesifikasi yang kebetulan digambar sebagai tabel. Barisnya `titik_ukur:
  /// null` (jadi `titikDitentukan == false`), ketiga selnya terisi, dan kotak
  /// set point kirinya memang dibiarkan kosong karena nggak ada angka yang
  /// masuk akal di situ.
  ///
  /// Tanpa pengecualian di `titikTanpaSetPoint`, penjaga pra-kirim menahan
  /// SELURUH sesi dengan pesan "Set Point kosong: D Stem", dan satu-satunya
  /// jalan keluar teknisi mengetik angka karangan di kotak yang nggak dibaca
  /// siapa pun. Lembar Hydrometer jadi nggak bisa dikirim sama sekali.
  test('tabel D Stem tidak menahan pengiriman walau set point-nya kosong', () {
    final isian = isianDari(contohBentukLembarKerjaHydrometer());
    final stem = tabel(isian, 'pre_condition', 0);

    // Teknisi mengisi ketiga ukuran diameter, dan MEMBIARKAN kotak set point
    // kiri tabel itu kosong — persis yang terjadi di lapangan.
    final tStem = isian.titikUntukBaris(isian.barisTabel(stem), 0, stem)!;
    for (var r = 0; r < 3; r++) {
      tStem.kotak(stem.kunciTabel, 'pembacaan', r).text = ['0,708', '0,710', '0,709'][r];
    }

    expect(
      isian.titikTanpaSetPoint.map((t) => t.label),
      isEmpty,
      reason: 'baris D Stem ikut ketahan penjaga pra-kirim — lembarnya nggak '
          'akan pernah bisa dikirim',
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
