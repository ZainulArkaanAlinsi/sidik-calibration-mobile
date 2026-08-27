import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
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
  /// Disalin apa adanya dari `TidsProfile::bentukLembarKerja()` — tabel
  /// **Pembacaan Alat yang Dikalibrasi**, yang isinya beneran dikirim.
  ///
  /// `tahap`-nya `pembacaan_uut`, BUKAN `sesudah_adjustment`, dan itu bukan
  /// detail: kunci sel di layar diambil dari situ, sementara payloadnya dulu
  /// dirakit dari kunci mati `sesudah_adjustment`. Fixture yang memakai tahap
  /// bawaan bikin seluruh berkas ini hijau di atas lembar yang nggak pernah
  /// ada.
  Map<String, dynamic> tabelTids() => {
    'tahap': 'pembacaan_uut',
    'judul': 'Pembacaan Alat yang Dikalibrasi',
    'simpan_ke': 'measurements[].pembacaan',
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

    test('`titik_ukur` yang ADA tapi bukan angka juga dibuang', () {
      // Cabang ketiga, dan yang paling gampang ketuker sama cabang TIDS.
      //
      //  - `null` yang disengaja → baris TIDS, dipakai.
      //  - kuncinya nggak ada     → baris cacat, dibuang.
      //  - kuncinya ada, isinya bukan angka → JUGA baris cacat.
      //
      // Yang ketiga dulu jatuh ke cabang pertama: barisnya lolos sebagai baris
      // TIDS, kotak `Setpoint`-nya digambar KOSONG, dan set point yang
      // sebenarnya dikirim server hilang tanpa satu pun tanda. Baris yang
      // dibuang setidaknya kelihatan hilang.
      final tabel = TabelHasil.fromJson({
        ...tabelTids(),
        'baris': [
          {'nomor': 1, 'titik_ukur': 4.0, 'label': '4'},
          {'nomor': 2, 'titik_ukur': '121,5', 'label': 'teks, bukan angka'},
          {'nomor': 3, 'titik_ukur': null, 'label': 'null yang disengaja'},
        ],
      });

      expect(tabel.baris.map((b) => b.label).toList(), [
        '4',
        'null yang disengaja',
      ]);
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

    test('ANGKA PEMBACAANNYA ikut terkirim, bukan cuma set point-nya', () {
      // Lubang paling dalam di jalur TIDS, dan yang paling sunyi.
      //
      // Kunci sel tiap tabel itu `TabelHasil.kunciTabel` = `tahap` yang
      // dikirim backend — `pembacaan_uut` buat lembar ini. Payloadnya dulu
      // dirakit dari kunci MATI `sesudah_adjustment`, yang di lembar ini nggak
      // pernah ada. Sembilan belas lembar lain tahapnya memang
      // `sesudah_adjustment`, jadi nggak ada satu pun test yang kena.
      //
      // Yang terjadi bukan error: `measurements` terkirim dengan set point
      // yang benar dan `pembacaan` NULL SEMUA. Lembarnya penuh di layar,
      // tombol kirimnya jalan, kameranya mengisi tiga puluh lima kotak — dan
      // tak satu pun angka itu ada di server.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final baris = isian.barisTabel(tabel);

      isian.titikUntukBaris(baris, 0, tabel)!
        ..titikCtl.text = '121,5'
        ..kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4'
        ..kotak(tabel.kunciTabel, 'pembacaan', 4).text = '121,7';

      final kirim = isian.toSubmission(draft: true).measurements.single;

      expect(
        kirim.pembacaan,
        [121.4, null, null, null, 121.7],
        reason:
            'Sel kosong tetap null DI POSISINYA — nomor Repeat-nya nggak boleh '
            'geser. Yang dijaga di sini angkanya sampai, bukan barisnya ada.',
      );
    });

    test('ringkasan sebelum kirim ngitung kotak yang SAMA', () {
      // Ringkasan yang membaca kotak lain bilang "0 dari 5 terisi" di lembar
      // yang penuh — dan teknisi yang percaya angka itu ngetik ulang semuanya.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      titik.titikCtl.text = '121,5';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 1).text = '121,6';

      expect(isian.ringkasanKirim().first.terisi, 2);
    });

    test('tabel yang `simpan_ke`-nya null NGGAK dipakai jadi kunci', () {
      // Lembar TIDS aslinya punya DUA tabel, dan yang di atas (`Pembacaan
      // Standard`) `simpan_ke`-nya null — dia memang belum punya tempat di
      // server. Kepilih jadi kunci, payloadnya balik lagi dirakit dari kotak
      // yang salah, cuma dari arah sebaliknya.
      final standar = {
        ...tabelTids(),
        'tahap': 'pembacaan_standard',
        'judul': 'Pembacaan Standard',
        'simpan_ke': null,
      };

      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson({
          ...bentukTids(),
          'bagian': [
            {
              'kode': 'hasil',
              'judul': 'Data Kalibrasi',
              'field': <dynamic>[],
              'tabel': [standar, tabelTids()],
            },
          ],
        }),
        clientRequestId: 'uji-tids-dua-tabel',
      )..alat = daftarAlatMock.first;
      addTearDown(isian.dispose);

      expect(isian.kunciTabelPembacaan, 'pembacaan_uut');
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

  /// **Balik lagi ke layar: draf TIDS yang dibuka ulang.**
  ///
  /// Ini lubang yang ketemu waktu review, dan dia lubang KEDUA di jalur yang
  /// sama. Yang pertama: baris TIDS kebuang waktu bentuknya diurai. Yang ini:
  /// barisnya sampai ke layar, angkanya sampai ke server — dan hilang waktu
  /// teknisi membukanya lagi.
  ///
  /// Sebabnya dua sisi yang nggak ketemu. Yang DIKIRIM `titikUkurEfektif`,
  /// angka yang diketik teknisi (`121,5`). Yang dipakai memulihkan
  /// `_titikTerdekat`, yang mencari di `titik` — dan di TIDS kunci `titik` itu
  /// NOMOR BARIS (1..7), karena kertasnya memang nggak mencetak angka. Jadi
  /// `titik[121.5]` nggak pernah ada, tiap baris kehitung `kebuang`, dan
  /// teknisi yang membuka draf-nya lagi — atau yang lembarnya dikembalikan
  /// admin buat dibetulkan — dapat tabel KOSONG.
  ///
  /// Di sesi revisi akibatnya paling mahal: yang dia kirim balik ke admin cuma
  /// sisa yang sempat diketik ulang dari kertas.
  group('pulih balik dari server', () {
    /// Persis bentuk yang dipulangkan server buat satu baris TIDS tersimpan.
    RawMeasurement tersimpan({
      required int id,
      required double titikUkur,
      required int pembacaanKe,
      required double pembacaan,
    }) => RawMeasurement(
      id: id,
      titikKe: 1,
      titikUkur: titikUkur,
      pembacaanKe: pembacaanKe,
      pembacaan: pembacaan,
      inputSource: 'manual',
      isVerified: true,
    );

    test('set point yang dikirim pulih ke kotak Setpoint-nya', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      final kebuang = isian.terapkanPembacaan([
        tersimpan(id: 1, titikUkur: 121.5, pembacaanKe: 1, pembacaan: 121.4),
        tersimpan(id: 2, titikUkur: 121.5, pembacaanKe: 2, pembacaan: 121.6),
        tersimpan(id: 3, titikUkur: 250, pembacaanKe: 1, pembacaan: 249.8),
      ]);

      expect(
        kebuang,
        0,
        reason:
            'Tiga baris tersimpan nggak ketemu tempatnya = draf TIDS yang '
            'dibuka ulang tampil kosong.',
      );

      final baris = isian.barisTabel(isian.bentuk.bagian.single.tabel.single);
      final tabel = isian.bentuk.bagian.single.tabel.single;

      // Dua set point berbeda → dua baris berbeda, urut dari atas.
      //
      // Bertitik, bukan berkoma: `formatAngka` memang begitu, dan jalur
      // pemulihan set point grid Enclosure sudah lama memakai yang sama.
      // `parseAngka` nerima dua-duanya, jadi yang dipulihkan tetap kekirim
      // ulang persis sama — dijaga test bolak-balik di bawah.
      expect(isian.titikUntukBaris(baris, 0, tabel)!.titikCtl.text, '121.5');
      expect(isian.titikUntukBaris(baris, 1, tabel)!.titikCtl.text, '250');
    });

    test('lima pembacaan satu set point mendarat di SATU baris', () {
      // Kalau tiap pembacaan mengambil baris kosong sendiri, tujuh baris habis
      // dimakan dua set point — dan sisanya kebuang.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final kebuang = isian.terapkanPembacaan([
        for (var i = 1; i <= 5; i++)
          tersimpan(
            id: i,
            titikUkur: 121.5,
            pembacaanKe: i,
            pembacaan: 121.0 + i / 10,
          ),
      ]);

      expect(kebuang, 0);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final baris = isian.barisTabel(tabel);
      final terisi = [
        for (var i = 0; i < 7; i++)
          if (isian
              .titikUntukBaris(baris, i, tabel)!
              .titikCtl
              .text
              .trim()
              .isNotEmpty)
            i,
      ];

      expect(terisi, [0], reason: 'satu set point = satu baris');
    });

    test('bolak-balik: yang dikirim sama dengan yang dipulihkan', () {
      // Penjaga yang paling menentukan — dua sisi jalurnya diadu langsung,
      // bukan masing-masing diperiksa sendiri-sendiri.
      final asal = isianTids();
      addTearDown(asal.dispose);

      final tabel = asal.bentuk.bagian.single.tabel.single;
      final baris = asal.barisTabel(tabel);

      asal.titikUntukBaris(baris, 0, tabel)!
        ..titikCtl.text = '121,5'
        ..kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4'
        ..kotak(tabel.kunciTabel, 'pembacaan', 1).text = '121,6';
      asal.titikUntukBaris(baris, 2, tabel)!
        ..titikCtl.text = '250'
        ..kotak(tabel.kunciTabel, 'pembacaan', 0).text = '249,8';

      final kirim = asal.toSubmission(draft: true).measurements;
      expect(kirim, hasLength(2));

      // Lembar yang baru dibuka, disuapi apa yang tadi dikirim.
      final pulih = isianTids();
      addTearDown(pulih.dispose);

      var id = 0;

      final kebuang = pulih.terapkanPembacaan([
        for (final m in kirim)
          for (var i = 0; i < m.pembacaan.length; i++)
            if (m.pembacaan[i] != null)
              tersimpan(
                id: ++id,
                titikUkur: m.titikUkur,
                pembacaanKe: i + 1,
                pembacaan: m.pembacaan[i]!,
              ),
      ]);

      expect(kebuang, 0);

      final lagi = pulih.toSubmission(draft: true).measurements;

      expect(
        lagi.map((m) => m.titikUkur).toList()..sort(),
        [121.5, 250.0],
        reason: 'Yang dipulihkan mesti kekirim ulang persis sama.',
      );

      expect(
        {for (final m in lagi) m.titikUkur: m.pembacaan.take(2).toList()},
        {
          121.5: [121.4, 121.6],
          250.0: [249.8, null],
        },
        reason: 'Angkanya juga, bukan cuma set point-nya.',
      );
    });

    test('lembar biasa nggak ikut kena jalur pemulihan baru', () {
      // Penjaga arah sebaliknya: baris yang set point-nya DITENTUKAN nggak
      // boleh diam-diam nampung pembacaan yang titiknya nggak ada di lembar.
      // Angka nyasar wajib tetap kehitung `kebuang` dan dilaporkan.
      final bentuk = bentukTids();
      final tabel = tabelTids();

      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson({
          ...bentuk,
          'bagian': [
            {
              ...(bentuk['bagian'] as List).first as Map<String, dynamic>,
              'tabel': [
                {
                  ...tabel,
                  'baris': [
                    {'nomor': 1, 'titik_ukur': 100.0, 'label': '100'},
                    {'nomor': 2, 'titik_ukur': 200.0, 'label': '200'},
                  ],
                },
              ],
            },
          ],
        }),
        clientRequestId: 'uji-tids-biasa',
      )..alat = daftarAlatMock.first;
      addTearDown(isian.dispose);

      expect(
        isian.terapkanPembacaan([
          tersimpan(id: 1, titikUkur: 999, pembacaanKe: 1, pembacaan: 999),
        ]),
        1,
      );
    });
  });

  group('penjaga sebelum kirim', () {
    test('baris berangka tapi set point-nya kosong DITAHAN, bukan dibuang', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final baris = isian.barisTabel(tabel);

      // Lima kotak pembacaan diisi, kotak Setpoint-nya dibiarkan kosong.
      final titik = isian.titikUntukBaris(baris, 0, tabel)!;
      for (var i = 0; i < 5; i++) {
        titik.kotak(tabel.kunciTabel, 'pembacaan', i).text = '121,${i + 1}';
      }

      expect(
        isian.titikTanpaSetPoint, hasLength(1),
        reason:
            'Tanpa penjaga ini `siapKirim` membuang SELURUH barisnya — kelima '
            'angka yang sudah diketik ikut hilang, di lembar yang kelihatan '
            'penuh di layar.',
      );

      expect(isian.toSubmission(draft: true).measurements, isEmpty);
    });

    test('set point yang cacat kehitung sama dengan yang kosong', () {
      // Formatter kotaknya sekarang menolak bentuk begini waktu diketik, tapi
      // draf lama bisa tersimpan sebelum itu — dan `parseAngka` pulang null
      // buat dua-duanya.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      titik.titikCtl.text = '-';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4';

      expect(isian.titikTanpaSetPoint, hasLength(1));
    });

    test('baris yang set point-nya beres NGGAK kena penjaga', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      titik.titikCtl.text = '121,5';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4';

      expect(isian.titikTanpaSetPoint, isEmpty);
    });

    test('nomor baris nggak lagi dipakai buat menilai kewajaran angka', () {
      // `adaPembacaanJauhDariTitik` dulu mengadu pembacaan ke [titikUkur] —
      // di TIDS itu nomor barisnya. Set point 121,5 dengan pembacaan 121,5
      // kena rasio 121,5 dan barisnya DITOLAK sebelum kirim: penjaga yang
      // menahan angka sah, persis kebalikan dari gunanya.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      titik.titikCtl.text = '121,5';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 0).text = '121,4';

      expect(isian.titikPembacaanJauh, isEmpty);
    });

    test('tapi angka yang beneran meleset satu orde tetap ketangkep', () {
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      titik.titikCtl.text = '121,5';
      titik.kotak(tabel.kunciTabel, 'pembacaan', 0).text = '1215';

      expect(isian.titikPembacaanJauh, hasLength(1));
    });

    test('set point doang yang diketik tetap kehitung isian', () {
      // `TitikState.adaIsian` yang jadi dasar konfirmasi waktu teknisi menekan
      // back. Nggak ikut membaca `titikCtl`, ketujuh set point yang barusan
      // diketik ilang tanpa satu pun pertanyaan.
      //
      // Diperiksa di level BARIS, bukan lembar: `LembarKerjaState.adaIsian`
      // ikut menghitung alat yang sudah dipilih, jadi dia sudah `true` sebelum
      // teknisi mengetik apa pun dan nggak bisa membuktikan apa-apa di sini.
      final isian = isianTids();
      addTearDown(isian.dispose);

      final tabel = isian.bentuk.bagian.single.tabel.single;
      final titik = isian.titikUntukBaris(isian.barisTabel(tabel), 0, tabel)!;

      expect(titik.adaIsian, isFalse);

      titik.titikCtl.text = '121,5';

      expect(titik.adaIsian, isTrue);
      expect(isian.adaIsian, isTrue);
    });
  });
}
