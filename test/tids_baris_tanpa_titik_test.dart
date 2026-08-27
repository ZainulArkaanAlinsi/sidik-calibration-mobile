import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';

/// Lembar TIDS: tujuh baris `Setpoint` KOSONG, dan tiap baris punya kotaknya
/// sendiri.
///
/// ## Bug yang ditutup berkas ini
///
/// `BarisTabelHasil.fromJson` dulu membaca `(json['titik_ukur'] as num)` —
/// cast KERAS. `TidsProfile` mengirim `titik_ukur: null` di ketujuh barisnya di
/// dua tabel sekaligus (sengaja: kertasnya memang mencetak tujuh baris kosong,
/// angkanya ditulis teknisi di lapangan). Baris ber-null bikin cast itu
/// melempar, `parseListAman` menelan lemparannya, dan barisnya **dilewat
/// diam-diam**.
///
/// Akibatnya lembar TIDS terbuka dengan dua kepala tabel dan **nol kotak
/// isian**, tanpa satu pun error. Kelas kegagalan yang sudah tercatat di repo
/// ini (`CalibrationHistoryItem`: *"draf tanpa tanggal cast-nya melempar,
/// `parseListAman` nelen lemparannya, dan barisnya DILEWAT diam-diam"*) — cuma
/// di tempat yang jauh lebih mahal.
///
/// Nggak ketangkap penjaga mana pun karena `MockLembarKerjaService` **nggak
/// punya bentuk TIDS sama sekali**: satu-satunya sumber bentuk lembar ini
/// server, dan nggak ada test yang menyuapkan bentuk aslinya ke parser.
///
/// ## Kenapa nggak cukup "kasih angka aja biar barisnya muncul"
///
/// `titikUkur` yang dikirim jadi `measurements[].titik_ukur`. Memberi baris
/// ber-null nomor barisnya (1..7) membuat lembarnya punya baris — dan membuat
/// set point sesi terkirim sebagai "1 °C … 7 °C", angka yang nggak pernah
/// diketik siapa pun dan nggak ditolak apa pun. Itu lebih buruk daripada
/// lembar yang jelas kosong.
///
/// Jadi angkanya tetap ada sebagai PENANDA POSISI (baris butuh identitas), dan
/// `TitikState.titikUkurEfektif` yang menentukan apa yang dikirim. Baris yang
/// kotaknya dibiarkan kosong nggak ikut dikirim sama sekali.
///
/// Bentuk layarnya dipilih pemilik lab (27 Agt 2026, K18): **tujuh baris tetap
/// digambar, tiap baris punya kotak `Setpoint` sendiri** — persis kertas
/// `SIDIK-FM-CAL-0506 Rev.4`.
void main() {
  /// Disalin apa adanya dari `TidsProfile::bentukLembarKerja()`.
  Map<String, dynamic> tabelTids() => {
    'tahap': 'pembacaan_standard',
    'judul': 'Pembacaan Standard',
    'satuan': '°C',
    'judul_nilai': 'Setpoint',
    'titik_bisa_diubah': true,
    'baris': [
      for (var i = 1; i <= 7; i++)
        {
          'nomor': i,
          'titik_ukur': null,
          'label': 'Set point $i',
          'satuan': '°C',
        },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  Map<String, dynamic> bentukTids() => {
    'judul': 'Temperatur Indikator dengan Sensor',
    'satuan': '°C',
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'Data Kalibrasi',
        'field': [],
        'tabel': [tabelTids()],
      },
    ],
  };

  /// Alatnya dipilih duluan — `toSubmission` memang menuntutnya, dan yang
  /// diuji di berkas ini set point-nya, bukan penjagaan alat.
  LembarKerjaState isianTids() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(bentukTids()),
    clientRequestId: 'uji-tids',
  )..alat = daftarAlatMock.first;

  group('barisnya sampai ke layar', () {
    test('ketujuh baris TIDS kebaca, bukan kebuang diam-diam', () {
      final tabel = TabelHasil.fromJson(tabelTids());

      expect(
        tabel.baris,
        hasLength(7),
        reason:
            'Baris ber-`titik_ukur: null` kebuang `parseListAman`. Lembar TIDS '
            'terbuka tanpa satu pun kotak isian, tanpa satu pun error.',
      );

      expect(tabel.baris.map((b) => b.label).toList(), [
        'Set point 1', 'Set point 2', 'Set point 3', 'Set point 4',
        'Set point 5', 'Set point 6', 'Set point 7',
      ]);
    });

    test('ketujuhnya dapat penanda sendiri, bukan nol yang kembar', () {
      // Nol buat SEMUA baris bikin tujuh baris berbagi satu penanda: mereka
      // saling menimpa di `titik`, dan `PetaTabelFoto` menolak seluruh tabel
      // yang penanda barisnya kembar.
      final titik = TabelHasil.fromJson(tabelTids()).baris
          .map((b) => b.titikUkur)
          .toList();

      expect(titik.toSet(), hasLength(7), reason: 'ketujuhnya wajib beda');
    });

    test('ketujuhnya ditandai BELUM ditentukan', () {
      final tabel = TabelHasil.fromJson(tabelTids());

      expect(tabel.baris.every((b) => !b.titikDitentukan), isTrue);
    });

    test('baris yang kuncinya NGGAK DIKIRIM tetap dibuang — itu baris cacat', () {
      // Bedanya menentukan, dan ini penjaga yang menjaga bedanya:
      //
      //  - `'titik_ukur': null` → pernyataan sengaja, barisnya dipakai.
      //  - kuncinya nggak ada → bentuk yang rusak, barisnya dibuang sambil
      //    tabel lainnya tetap tampil.
      //
      // Tanpa pemisahan ini, perbaikan TIDS diam-diam menerima bentuk cacat
      // dari mana pun — dan baris tanpa titik ukur di lembar pH nggak punya
      // arti apa-apa.
      final tabel = TabelHasil.fromJson({
        ...tabelTids(),
        'baris': [
          {'titik_ukur': 4.0, 'label': '4'},
          {'label': 'tanpa kunci titik_ukur'},
        ],
      });

      expect(tabel.baris, hasLength(1));
      expect(tabel.baris.single.titikUkur, 4.0);
    });

    test('titik yang memang ada tetap kebaca angkanya & ditandai ditentukan', () {
      // Penjaga arah sebaliknya: jangan sampai perbaikan di atas bikin SEMUA
      // titik jatuh ke penanda posisi.
      final tabel = TabelHasil.fromJson({
        ...tabelTids(),
        'baris': [
          {'titik_ukur': 4.01, 'label': '4,01 pH'},
          {'titik_ukur': 7.0, 'label': '7,00 pH'},
        ],
      });

      expect(tabel.baris.map((b) => b.titikUkur).toList(), [4.01, 7.0]);
      expect(tabel.baris.every((b) => b.titikDitentukan), isTrue);
    });
  });

  group('yang dikirim', () {
    test('baris yang set point-nya kosong NGGAK ikut dikirim', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      expect(
        isian.toSubmission(draft: true).measurements,
        isEmpty,
        reason:
            'Tujuh baris tanpa set point nggak punya identitas buat dihitung. '
            'Dikirim apa adanya, sertifikatnya terbit dengan set point 1..7 °C.',
      );
    });

    test('yang diisi ikut dikirim dengan ANGKA YANG DIKETIK, bukan nomornya', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      final baris = isian.barisTabel(isian.bentuk.bagian.single.tabel.single);
      final tabel = isian.bentuk.bagian.single.tabel.single;

      // Baris ke-1 dan ke-3 diisi; sisanya dibiarkan kosong.
      isian.titikUntukBaris(baris, 0, tabel)!.titikCtl.text = '121,5';
      isian.titikUntukBaris(baris, 2, tabel)!.titikCtl.text = '250';

      final kirim = isian.toSubmission(draft: true).measurements;

      expect(kirim, hasLength(2));
      expect(
        kirim.map((m) => m.titikUkur).toList()..sort(),
        [121.5, 250.0],
        reason:
            'Nomor barisnya (1 & 3) nggak boleh bocor jadi set point — itu '
            'angka yang nggak pernah diketik siapa pun.',
      );
    });

    test('set point yang diketik selamat waktu tabelnya dibangun ulang', () {
      // `_bangunTitik(pertahankanIsian: true)` jalan tiap bentuknya disegarkan.
      // Tanpa kotak Setpoint ikut disalin, angka yang barusan diketik teknisi
      // hilang tanpa satu pun tanda.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      isian
          .titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!
          .titikCtl
          .text = '121,5';

      // Bentuknya disegarkan — jalur yang sama dilewati tiap lembar dimuat
      // ulang atau alatnya diganti.
      isian.gantiBentuk(LembarKerja.fromJson(bentukTids()));

      expect(
        isian.toSubmission(draft: true).measurements.single.titikUkur,
        121.5,
      );
    });
  });

  testWidgets('kolom kiri baris TIDS itu kotak isian, bukan label mati', (
    tester,
  ) async {
    final isian = isianTids();
    addTearDown(isian.dispose);

    final tabel = isian.bentuk.bagian.single.tabel.single;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LembarKerjaTabel(
                tabel: tabel,
                isian: isian,
                onBerubah: () {},
                pindaiAktif: false,
              ),
            ),
          ),
        ),
      ),
    );

    // Tujuh kotak Setpoint + 7×5 kotak pembacaan. Yang dicek di sini cuma
    // bahwa kolom kirinya BISA diketik — sebelum ini dia label mati, dan
    // sebelum itu lagi barisnya nggak ada sama sekali.
    final kotakKiri = isian
        .titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!
        .titikCtl;

    await tester.enterText(find.byWidgetPredicate(
      (w) => w is TextField && identical(w.controller, kotakKiri),
    ), '121,5');

    expect(kotakKiri.text, '121,5');
  });
}
