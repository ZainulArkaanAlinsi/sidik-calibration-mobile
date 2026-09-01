import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Tiga alat suhu ber-PASANGAN deret — Thermocouple, Termometer Gelas,
/// Thermohygrometer (alat ke-18, 19, 20).
///
/// Bentuknya dibaca dari BERKAS SUNGGUHAN
/// (`test/fixtures/lembar-kerja-*.json`), hasil `bentukLembarKerja()` di server
/// — bukan mock yang diketik ulang di sini. Mock yang diketik ulang cuma
/// membuktikan layar sepakat dengan dirinya sendiri, dan kontrak yang bergeser
/// di server nggak akan pernah memerahkan test ini.
///
/// Yang dijaga empat hal, dan keempatnya gagal dengan cara yang DIAM:
///
///  1. **Dua tabel saling menimpa.** Kedua tabel ber-`tahap` SAMA
///     (`sesudah_adjustment`) — yang beda `peran`. Dikunci ke tahap, angka
///     deret UUT mendarat di kotak deret standar dan yang kelihatan cuma satu
///     tabel yang isinya berubah sendiri waktu tabel satunya diketik.
///  2. **Set point `50` yang ada di DUA blok Thermohygro.** 50 °C di blok suhu,
///     50 %RH di blok kelembapan. Dikunci ke angka, dua baris itu berbagi satu
///     `TitikState`: barisnya tinggal sembilan (bukan sepuluh) dan baris RH
///     mewarisi satuan °C milik tetangganya.
///  3. **Payload kehilangan satu sisi.** Yang hilang sisi KIRI kolom
///     `Correction` — dan `Correction` tetap terbit, cuma diadu ke nol.
///  4. **Sesi yang dikembalikan admin pulang setengah.** Pembacaan dipulihkan
///     lewat `peran_sensor`; No. Termokopel lewat `sensor_ke`. Nggak pulih,
///     teknisi memilih probe pertama di daftar dan koreksi probe yang terpakai
///     bukan milik probe yang beneran dicelup.
void main() {
  LembarKerja bentuk(String kode) => LembarKerja.fromJson(
    jsonDecode(File('test/fixtures/lembar-kerja-$kode.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  /// Semua tabel lembar, urut seperti digambar.
  List<TabelHasil> tabelDari(LembarKerja b) => [
    for (final bagian in b.bagian) ...bagian.tabel,
  ];

  group('bentuk dari server kebaca', () {
    test(
      'ketiganya berpasangan, dan tiap tabel punya peran + grup sendiri',
      () {
        for (final kode in [
          'thermocouple',
          'thermometer_glass',
          'thermohygro',
        ]) {
          final b = bentuk(kode);
          final tabel = tabelDari(b);

          expect(
            b.berpasangan,
            isTrue,
            reason: '$kode harusnya lembar pasangan',
          );
          expect(tabel.every((t) => t.berpasangan), isTrue, reason: kode);

          // Kunci penyimpanan tiap tabel WAJIB unik. Ini penjaga nomor 1.
          final kunci = tabel.map((t) => t.kunciTabel).toList();
          expect(
            kunci.toSet(),
            hasLength(kunci.length),
            reason: '$kode punya tabel berkunci kembar: $kunci',
          );

          // Tiap peran hadir, dan jumlahnya berpasangan.
          expect(
            tabel.where((t) => t.deretStandar).length,
            tabel.where((t) => t.deretUut).length,
            reason: '$kode: jumlah tabel standar & UUT harus sama',
          );

          for (final t in tabel) {
            expect(t.pengulangan, [
              1,
              2,
              3,
              4,
              5,
            ], reason: '${t.judul} ($kode)');
          }
        }
      },
    );

    test('Thermohygro bawa dua parameter + chamber per baris', () {
      final tabel = tabelDari(bentuk('thermohygro'));

      expect(
        tabel.map((t) => t.parameter).toSet(),
        {'suhu', 'kelembaban'},
        reason: 'Satu lembar, dua besaran — masing-masing punya U95 sendiri.',
      );

      final rhStandar = tabel.firstWhere(
        (t) => t.parameter == 'kelembaban' && t.deretStandar,
      );

      // Chamber ditentukan SERVER dari set point (Biobase ≥ 50 %RH, GEA < 50).
      // Dipilih teknisi, titik 30 %RH bisa memakai homogenitas Biobase (1,8)
      // padahal chamber-nya GEA (0,8) — `uc` naik dari 1,69 ke 2,21.
      expect(rhStandar.chamberPerBaris[30.0], 'gea');
      expect(rhStandar.chamberPerBaris[49.0], 'gea');
      expect(rhStandar.chamberPerBaris[50.0], 'biobase');
      expect(rhStandar.chamberPerBaris[90.0], 'biobase');
    });

    test('Thermocouple & Gelas bukan lembar dua-parameter', () {
      for (final kode in ['thermocouple', 'thermometer_glass']) {
        final tabel = tabelDari(bentuk(kode));
        expect(tabel.every((t) => t.parameter == null), isTrue, reason: kode);
        expect(
          tabel.every((t) => t.chamberPerBaris.isEmpty),
          isTrue,
          reason: kode,
        );
      }
    });
  });

  group('kunci baris', () {
    test('deret standar & UUT berbagi kunci yang SAMA', () {
      final b = bentuk('thermocouple');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final uut = tabel.firstWhere((t) => t.deretUut);

      for (var i = 0; i < state.barisTabel(standar).length; i++) {
        expect(
          state.kunciBaris(state.barisTabel(standar), i, standar),
          state.kunciBaris(state.barisTabel(uut), i, uut),
          reason:
              'Dua deret itu SET POINT YANG SAMA, dibaca bergantian — '
              'kalau kuncinya beda, sisi standar & sisi UUT jadi dua baris '
              'terpisah dan `Correction` diadu ke titik yang salah.',
        );
      }
    });

    test('set point 50 di dua blok Thermohygro nggak saling menelan', () {
      final b = bentuk('thermohygro');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      // 5 titik suhu + 5 titik kelembapan = SEPULUH baris, bukan sembilan.
      // Ini penjaga nomor 2.
      expect(
        state.titik,
        hasLength(10),
        reason:
            'Set point 50 ada di dua blok (50 °C & 50 %RH). Dikunci ke '
            'angka, keduanya berbagi satu baris dan satu titik hilang diam-diam.',
      );

      final satuan = state.titik.values.map((t) => t.satuan).toSet();
      expect(satuan, containsAll(['°C', '%RH']));

      // Baris 50 %RH wajib bersatuan %RH, bukan mewarisi °C tetangganya.
      final limaPuluh = state.titik.values.where((t) => t.titikUkur == 50.0);
      expect(limaPuluh, hasLength(2));
      expect(limaPuluh.map((t) => t.satuan).toSet(), {'°C', '%RH'});
      expect(limaPuluh.map((t) => t.parameter).toSet(), {'suhu', 'kelembaban'});
    });
  });

  group('payload', () {
    /// Tiap angka yang diketik lewat KUNCI SEL YANG DIGAMBAR LAYAR wajib sampai
    /// ke payload — disapu ke ketiga lembar, bukan satu.
    ///
    /// ## Kegagalan yang ditutup test ini
    ///
    /// `toSubmissionPasangan` dulu membaca dua string mati, `'standar'` &
    /// `'uut'`. Thermocouple dan Termometer Gelas kebetulan ber-`grup` persis
    /// itu, jadi keduanya benar. **Thermohygrometer tidak**: lembarnya empat
    /// tabel (`suhu_standar`, `suhu_uut`, `kelembaban_standar`,
    /// `kelembaban_uut`) karena satu lembar memuat dua parameter.
    ///
    /// Terukur sebelum perbaikan: 100 sel diisi, payload berisi **0**. Dan
    /// karena `pasanganKosong` membaca kunci yang sama, tiap titiknya dianggap
    /// belum disentuh lalu DIBUANG — yang berangkat lembar tanpa satu pun
    /// titik. Nol error di kedua sisi.
    ///
    /// Test lamanya nggak menangkapnya, dan itu bagian dari cacatnya: dia
    /// menulis ke `'standar'` juga, jadi menulis dan membaca dari sel hantu
    /// yang SAMA. Test yang mematok kunci nggak bisa melihat kunci yang salah.
    ///
    /// Makanya yang dipakai di sini `tabel.kunciTabel` — sumber yang sama
    /// dengan yang dipakai `_SelAngka` waktu menggambar kotaknya.
    for (final kode in ['thermocouple', 'thermometer_glass', 'thermohygro']) {
      test('$kode: tiap angka yang diketik sampai ke payload', () {
        final b = bentuk(kode);
        final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

        var diketik = 0;

        for (final tabel in tabelDari(b)) {
          if (!tabel.berpasangan) continue;

          final baris = state.barisTabel(tabel);

          for (var i = 0; i < baris.length; i++) {
            final titik = state.titik[state.kunciBaris(baris, i, tabel)];
            if (titik == null) continue;

            for (final kolom in tabel.kolom) {
              for (var r = 0; r < tabel.pengulangan.length; r++) {
                titik.kotak(tabel.kunciTabel, kolom.kode, r).text = '${r + 1}';
                diketik++;
              }
            }
          }
        }

        expect(
          diketik,
          greaterThan(0),
          reason: '$kode nggak punya sel sama sekali',
        );

        var sampai = 0;

        for (final t in state.titik.values) {
          final deret = state.deretPasangan(t.parameter);
          expect(
            deret,
            isNotNull,
            reason: '$kode parameter ${t.parameter} nggak punya deret',
          );

          final payload = t.toSubmissionPasangan(deret!);

          for (final kunci in ['standar', 'uut']) {
            for (final nilai in payload[kunci] as List) {
              if (nilai != null) sampai++;
            }
          }
        }

        expect(
          sampai,
          diketik,
          reason:
              '$kode: $diketik sel diketik teknisi, cuma $sampai yang '
              'sampai ke payload. Kunci sel yang dibaca beda dari yang '
              'digambar — lembarnya penuh di layar dan berangkat kosong.',
        );
      });
    }

    /// Dan titiknya nggak boleh dibuang sebelum dikirim.
    test('thermohygro: nggak ada titik yang dibuang padahal terisi', () {
      final b = bentuk('thermohygro');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      for (final tabel in tabelDari(b)) {
        if (!tabel.berpasangan) continue;
        final baris = state.barisTabel(tabel);
        for (var i = 0; i < baris.length; i++) {
          state.titik[state.kunciBaris(baris, i, tabel)]
                  ?.kotak(tabel.kunciTabel, 'pembacaan', 0)
                  .text =
              '21.5';
        }
      }

      final terkirim = [
        for (final t in state.titik.values)
          if (state.deretPasangan(t.parameter) case final d?)
            if (!t.pasanganKosong(d)) t,
      ];

      expect(
        terkirim,
        hasLength(state.titik.length),
        reason:
            'Sepuluh titik diisi, cuma ${terkirim.length} yang lolos '
            'penyaring. `pasanganKosong` membaca kunci yang salah, jadi '
            'lembar penuh berangkat tanpa satu pun titik.',
      );
    });

    test('dua deret sampai utuh, sel kosong tetap di posisinya', () {
      final b = bentuk('thermocouple');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');
      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final baris = state.barisTabel(standar);

      // Titik pertama sesi master 0513-CAL-1124: 50 °C.
      final kunci = state.kunciBaris(baris, 0, standar);
      final titik = state.titik[kunci]!;

      // Kunci selnya dari TABELNYA, bukan string yang diketik di sini. Test
      // yang mematok kunci menulis & membaca dari sel hantu yang sama, jadi dia
      // hijau justru waktu layar sungguhannya salah — itu yang bikin lembar
      // Thermohygro terkirim kosong berbulan-bulan tanpa ketahuan.
      final uut = tabel.firstWhere((t) => t.deretUut);

      for (var i = 0; i < 5; i++) {
        titik.kotak(standar.kunciTabel, 'pembacaan', i).text = '49.5';
      }
      // Repeat 2 UUT sengaja DIKOSONGKAN — nomor pengulangan sesudahnya nggak
      // boleh geser.
      for (var i = 0; i < 5; i++) {
        if (i == 1) continue;
        titik.kotak(uut.kunciTabel, 'pembacaan', i).text = '49.9';
      }
      titik.noProbeCtl.text = '1';

      final payload = titik.toSubmissionPasangan(
        state.deretPasangan(titik.parameter)!,
      );

      expect(payload['titik_ukur'], 50.0);
      expect(payload['no_probe'], 1);
      expect(payload['standar'], [49.5, 49.5, 49.5, 49.5, 49.5]);
      expect(
        payload['uut'],
        [49.9, null, 49.9, 49.9, 49.9],
        reason:
            'Sel kosong tetap null DI POSISINYA. Dibuang, Repeat 3 naik '
            'jadi Repeat 2 dan seluruh nomor pengulangan geser.',
      );
    });

    test('titik yang belum disentuh nggak ikut dikirim', () {
      final b = bentuk('thermometer_glass');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      bool kosong(TitikState t) =>
          t.pasanganKosong(state.deretPasangan(t.parameter)!);

      expect(
        state.titik.values.every(kosong),
        isTrue,
        reason: 'Lembar baru dibuka: belum ada satu sel pun terisi.',
      );

      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final titik =
          state.titik[state.kunciBaris(state.barisTabel(standar), 0, standar)]!;
      titik.kotak(standar.kunciTabel, 'pembacaan', 0).text = '29.9';

      expect(kosong(titik), isFalse);
      expect(
        state.titik.values.where((t) => !kosong(t)),
        hasLength(1),
        reason:
            'Baris kosong di tengah bikin `titik_ke` sesudahnya geser di '
            'server — jadi yang kosong dibuang, bukan dikirim sebagai deret nol.',
      );
    });

    test('parameter ikut tiap titik Thermohygro', () {
      final b = bentuk('thermohygro');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      // Lewat kunci tabel yang SEBENARNYA (`suhu_standar`, `kelembaban_uut`,
      // …). Dulu di sini tertulis `'standar'`/`'uut'` — kunci yang tidak ada
      // di lembar ini — jadi test menulis ke sel hantu, membacanya kembali dari
      // sel hantu yang sama, dan hijau sementara payload aslinya kosong.
      for (final t in state.titik.values) {
        final d = state.deretPasangan(t.parameter)!;
        for (final kunci in [d.kunciStandar, d.kunciUut]) {
          t.kotak(kunci, 'pembacaan', 0).text = '1';
        }
      }

      final payload = [
        for (final t in state.titik.values)
          if (state.deretPasangan(t.parameter) case final d?)
            if (!t.pasanganKosong(d)) t.toSubmissionPasangan(d),
      ];

      expect(payload, hasLength(10));
      expect(payload.where((m) => m['parameter'] == 'suhu'), hasLength(5));
      expect(
        payload.where((m) => m['parameter'] == 'kelembaban'),
        hasLength(5),
      );
    });
  });

  group('sesi yang dikembalikan admin pulang utuh', () {
    RawMeasurement mentah({
      required double titikUkur,
      required int pembacaanKe,
      required double pembacaan,
      required String peran,
      int? sensorKe,
      String? satuan,
    }) => RawMeasurement(
      id: titikUkur.toInt() * 100 + pembacaanKe + (peran == 'uut' ? 50 : 0),
      titikKe: 1,
      titikUkur: titikUkur,
      pembacaanKe: pembacaanKe,
      pembacaan: pembacaan,
      inputSource: 'manual',
      isVerified: true,
      peranSensor: peran,
      sensorKe: sensorKe,
      satuan: satuan,
    );

    test('pembacaan pulih ke deret yang benar, bukan saling menimpa', () {
      final b = bentuk('thermocouple');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      final kebuang = state.terapkanPembacaan([
        for (var i = 1; i <= 5; i++)
          mentah(
            titikUkur: 50,
            pembacaanKe: i,
            pembacaan: 49.5,
            peran: 'standar',
            sensorKe: 1,
            satuan: '°C',
          ),
        for (var i = 1; i <= 5; i++)
          mentah(
            titikUkur: 50,
            pembacaanKe: i,
            pembacaan: 49.9,
            peran: 'uut',
            satuan: '°C',
          ),
      ]);

      expect(kebuang, 0, reason: 'Nggak boleh ada pembacaan yang hilang.');

      final tabel = tabelDari(b);
      final standar = tabel.firstWhere((t) => t.deretStandar);
      final titik =
          state.titik[state.kunciBaris(state.barisTabel(standar), 0, standar)]!;

      expect(titik.kotak('standar', 'pembacaan', 0).text, '49.5');
      expect(
        titik.kotak('uut', 'pembacaan', 0).text,
        '49.9',
        reason:
            'Deret UUT punya kotaknya SENDIRI — kalau dua deret berbagi '
            'kunci, angka ini menimpa 49,5 dan sisi standar hilang.',
      );

      // No. Termokopel ikut pulih; tanpa itu koreksi probe yang terpakai bukan
      // milik probe yang beneran dicelup.
      expect(titik.noProbe, 1);
    });

    test('50 °C dan 50 %RH Thermohygro pulih ke blok masing-masing', () {
      final b = bentuk('thermohygro');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      final kebuang = state.terapkanPembacaan([
        mentah(
          titikUkur: 50,
          pembacaanKe: 1,
          pembacaan: 54.91,
          peran: 'standar',
          satuan: '°C',
        ),
        mentah(
          titikUkur: 50,
          pembacaanKe: 1,
          pembacaan: 49.4,
          peran: 'standar',
          satuan: '%RH',
        ),
      ]);

      expect(kebuang, 0);

      final suhu = state.titik.values.firstWhere(
        (t) => t.titikUkur == 50 && t.satuan == '°C',
      );
      final rh = state.titik.values.firstWhere(
        (t) => t.titikUkur == 50 && t.satuan == '%RH',
      );

      expect(suhu.kotak('standar', 'pembacaan', 0).text, '54.91');
      expect(
        rh.kotak('standar', 'pembacaan', 0).text,
        '49.4',
        reason:
            'Tanpa satuan sebagai pembeda, angka blok kelembapan mendarat '
            'di baris suhu — bentuknya wajar, tempatnya salah.',
      );
    });

    test('sesi lama tanpa kolom satuan tetap pulih, nggak dibuang', () {
      final b = bentuk('thermocouple');
      final state = LembarKerjaState(bentuk: b, clientRequestId: 'uji');

      // Sesi yang tersimpan sebelum `satuan` ikut dikirim server.
      final kebuang = state.terapkanPembacaan([
        mentah(
          titikUkur: 50,
          pembacaanKe: 1,
          pembacaan: 49.5,
          peran: 'standar',
        ),
      ]);

      expect(
        kebuang,
        0,
        reason:
            'Angka yang mendarat di baris yang benar tapi satuannya nggak '
            'kecatat jauh lebih baik daripada angka yang hilang.',
      );
    });
  });

  group('peran pasangan dipisah dari peran GRID', () {
    test('standar/uut bukan baris grid Enclosure', () {
      final pasangan = RawMeasurement(
        id: 1,
        titikKe: 1,
        titikUkur: 50,
        pembacaanKe: 1,
        pembacaan: 49.5,
        inputSource: 'manual',
        isVerified: true,
        peranSensor: 'standar',
      );

      expect(pasangan.bagianPasangan, isTrue);
      expect(
        pasangan.bagianGrid,
        isFalse,
        reason:
            'Dua-duanya memakai kolom `peran_sensor` yang sama. Nggak '
            'dipisah, tiap pembacaan lembar pasangan masuk jalur pemulihan '
            'GRID, dianggap nggak ketemu barisnya, dan teknisi dapat dua tabel '
            'kosong berikut pesan bahwa sekian pembacaan hilang.',
      );

      final grid = RawMeasurement(
        id: 2,
        titikKe: 1,
        titikUkur: 50,
        pembacaanKe: 1,
        pembacaan: 49.5,
        inputSource: 'manual',
        isVerified: true,
        peranSensor: 'termokopel',
        sensorKe: 1,
      );

      expect(grid.bagianGrid, isTrue);
      expect(grid.bagianPasangan, isFalse);
    });
  });
}
