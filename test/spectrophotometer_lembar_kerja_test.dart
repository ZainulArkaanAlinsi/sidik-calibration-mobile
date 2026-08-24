
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';


/// Bentuk lembar kerja Spectrophotometer (alat ke-6, `SIDIK-IK-CAL-0508_Rev.4`)
/// — tiga tabel dalam satu bagian, satuan campur, dan satu bagian yang tampil
/// tapi belum boleh diisi.
///
/// Bentuk mock-nya disalin dari respons ASLI
/// `GET /api/calibrations/lembar-kerja?equipment_id=12` di DB lab, bukan
/// dikarang: titiknya persis yang tercetak di master
/// `Master Olah Data_Spectrofotometer.xlsm`.
void main() {
  group('bentuk lembar kerja', () {
    test('`satuan_campuran` berbentuk DAFTAR tetap kebaca campur', () {
      // Regresi yang paling mahal di alat ini. Conductivity ngirim
      // `satuan_campuran: true`, Spectrophotometer ngirim `["nm", "%T"]` —
      // kunci yang sama, tipe yang beda. Waktu parsernya masih `as bool?`,
      // daftar itu ngelempar TypeError, dan `LembarKerja.fromJson` ada di LUAR
      // jangkauan `parseListAman`: yang gagal bukan satu kolom, tapi seluruh
      // lembar. Layar kalibrasinya kosong sebelum satu baris pun digambar.
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());

      expect(bentuk.satuanCampuran, isTrue);

      final tabel = bentuk.bagianHasil!.tabel;
      final holmium = tabel[0].baris.first;
      final transmitan = tabel[2].baris.first;

      // Satuan diambil PER BARIS, bukan dari `satuan` level lembar yang keisi
      // 'nm' — kalau ketuker, kolom %T kelabel nm.
      expect(bentuk.satuanUntuk(holmium), 'nm');
      expect(bentuk.satuanUntuk(transmitan), '%T');
    });

    test('`satuan_campuran: true` (Conductivity) nggak ikut kebawa rusak', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'satuan': '',
        'satuan_campuran': true,
        'bagian': <dynamic>[],
      });

      expect(bentuk.satuanCampuran, isTrue);
    });

    test('daftar KOSONG artinya nggak campur, bukan campur tanpa satuan', () {
      final bentuk = LembarKerja.fromJson({
        'kode_dokumen': 'X',
        'satuan': 'nm',
        'satuan_campuran': <dynamic>[],
        'bagian': <dynamic>[],
      });

      expect(bentuk.satuanCampuran, isFalse);
    });

    test('tiga tabel, dan kolom pengulangannya dibaca PER TABEL', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;

      expect(tabel, hasLength(3));
      expect([for (final t in tabel) t.baris.length], [10, 9, 5]);

      // Ini yang nggak boleh diambil dari level lembar: `jumlah_pengulangan`
      // di situ 3, sementara blok %T butuh ENAM kolom (master nyetak dua baris
      // X1..X3 per nilai standar, dan `PERHITUNGAN` merata-rata keenamnya).
      expect(bentuk.jumlahPengulangan, 3);
      expect([for (final t in tabel) t.pengulangan.length], [3, 3, 6]);
    });

    test('tiap baris bawa standar & desimalnya sendiri', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;

      // Standar nempel di baris — teknisi NGGAK milih filter per titik.
      // Rentang Holmium (283–641 nm) & Didynium (474–810 nm) tumpang tindih
      // 167 nm, jadi salah pilih nggak kelihatan dari dokumen hasilnya.
      expect(tabel[0].baris.every((b) => b.standardId == 25), isTrue);
      expect(tabel[1].baris.every((b) => b.standardId == 26), isTrue);
      expect(tabel[2].baris.every((b) => b.standardId == 27), isTrue);

      // Desimal beda per kelompok: 2 buat nm, 3 buat %T.
      expect(tabel[0].baris.first.desimal, 2);
      expect(tabel[2].baris.first.desimal, 3);
      // Label nilai standar ditulis kayak di kertas: satu desimal, koma.
      expect(tabel[2].baris.first.label, '0,0');
      expect(tabel[0].baris.first.label, '279,6');
    });

    test('bagian SRE kebaca berstatus & nggak nerima input', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final sre = bentuk.bagian.firstWhere((b) => b.kode == 'sre');

      expect(sre.belumBisaDiisi, isTrue);
      expect(sre.field, isEmpty);
      expect(sre.catatan, contains('#REF!'));
    });
  });

  group('bentuk tabel di layar', () {
    /// Susunan kolomnya wajib sama sama LEMBAR CETAK, bukan sekadar benar
    /// datanya — teknisi ngisi sambil megang kertas yang sama.
    testWidgets('kepala tabel ngikut lembar cetak', (tester) async {
      await _bukaLembar(tester);

      // Dua tabel panjang gelombang: `No.` + `Std Value (λ1)`.
      expect(find.text('No.'), findsNWidgets(2));
      expect(find.text('Std Value (λ1)'), findsNWidgets(2));

      // Blok %T: kolom kirinya `λ (nm)` = 560 yang kegabung buat seluruh
      // tabel, dan kepala nilainya tanpa (λ1).
      expect(find.text('λ (nm)'), findsOneWidget);
      expect(find.text('560'), findsOneWidget);
      expect(find.text('Std Value'), findsOneWidget);

      expect(find.text('Measurement Result'), findsNWidgets(3));
      expect(find.text('X1'), findsNWidgets(3));
      expect(find.text('X3'), findsNWidgets(3));

      // `Repeat n` itu bentuk alat lain — di kertas spektro nggak ada.
      expect(find.text('Repeat 1'), findsNothing);

      // Nilai standar ditulis kayak di kertas: satu desimal, koma, tanpa
      // satuan nempel (satuannya udah kesebut di judul tabel & kepala kolom).
      expect(find.text('279,6'), findsOneWidget);
      expect(find.text('100,0'), findsOneWidget);
      expect(find.text('0,000 %T'), findsNothing);

      // Catatan yang tercetak di bawah tabel Didynium.
      expect(
        find.text('*) Measured at 25°C and with spectral bandwidth 1 nm.'),
        findsOneWidget,
      );
    });

    /// Enam pengulangan %T digambar DUA baris X1..X3 per nilai standar, persis
    /// kertasnya — bukan satu baris enam kolom.
    testWidgets('%T digambar dua baris per nilai standar', (tester) async {
      await _bukaLembar(tester);

      final tabelT = find.byType(LembarKerjaTabel).at(2);
      final kotak = find.descendant(of: tabelT, matching: find.byType(TextField));

      expect(kotak, findsNWidgets(30));

      // Tiga kotak sebaris: kotak ke-1 & ke-4 (baris kedua nilai standar yang
      // sama) beda posisi Y, bukan cuma geser ke kanan.
      final pertama = tester.getTopLeft(kotak.at(0));
      final ketiga = tester.getTopLeft(kotak.at(2));
      final keempat = tester.getTopLeft(kotak.at(3));

      expect(ketiga.dy, pertama.dy, reason: 'X1..X3 sebaris');
      expect(keempat.dy, greaterThan(pertama.dy), reason: 'X4 turun sebaris');
      expect(keempat.dx, pertama.dx, reason: 'X4 balik ke kolom X1');
    });
  });

  group('spesifikasi alat', () {
    /// Rentang ukur / kapasitas / resolusi DIKETIK teknisi, dan yang diketik
    /// beneran kekirim.
    ///
    /// Sebelumnya tiga baris ini `equipment.range_resolusi` bersumber
    /// `otomatis` — kotak mati berisi salinan master alat. Buat alat berskala
    /// DUA (`0–100 %T` dan `200–700 nm`) master cuma bisa jawab separuh, dan
    /// separuh yang salah itu kecetak di sertifikat sebagai Capacity/Graduation.
    testWidgets('spesifikasi alat diketik teknisi & ikut kekirim', (
      tester,
    ) async {
      final service = await _bukaLembar(tester);
      await _pilihAlat(tester);

      // Label ditulis SEKALI, kotaknya dua — persis lembar cetaknya.
      expect(find.text('2. Rentang Ukur'), findsOneWidget);
      expect(find.text('Kapasitas Max.'), findsOneWidget);
      expect(find.text('Resolusi Alat'), findsOneWidget);
      expect(find.text('2. Range/Resolution'), findsNothing);

      // Kotaknya dicari lewat label satuan di dalamnya (`%T` / `nm`), sama
      // kayak yang dilihat teknisi.
      final kotakT = find.widgetWithText(TextField, '%T');
      final kotakNm = find.widgetWithText(TextField, 'nm');

      expect(kotakT, findsNWidgets(3));
      expect(kotakNm, findsNWidgets(2));

      await tester.enterText(kotakT.at(0), '0-100');
      await tester.enterText(kotakNm.at(0), '200-700');
      await tester.enterText(kotakT.at(1), '100');
      await tester.enterText(kotakT.at(2), '0,001');
      await tester.enterText(kotakNm.at(1), '0,01');
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      expect(service.payloadTerakhir!['spesifikasi_alat'], {
        'rentang_ukur_transmitan': '0-100',
        'rentang_ukur_panjang_gelombang': '200-700',
        'kapasitas_maks_transmitan': '100',
        'resolusi_transmitan': '0,001',
        'resolusi_panjang_gelombang': '0,01',
      });
    });
  });

  group('kop lembar', () {
    /// Technician ID ngikut akun yang login, dan lokasi Insitu bawa nama
    /// tempatnya.
    ///
    /// Dua-duanya kecetak di sertifikat: `Technician ID : JO` dan
    /// `Calibration Location : Insitu (PT. LDC)`. Tanpa nama tempat, dokumen
    /// nggak bisa ditelusuri balik ke kunjungan mana.
    testWidgets('technician id otomatis, nama lokasi muncul waktu Insitu', (
      tester,
    ) async {
      final service = await _bukaLembar(tester);
      await _pilihAlat(tester);

      // Inisial datang dari backend (`kode_teknisi` di `/me`), bukan dipotong
      // di layar — MockAuthService ngirim `BS` buat Budi Santoso.
      expect(find.text('Technician ID'), findsOneWidget);
      expect(find.text('BS'), findsOneWidget);

      // Sesi in-lab NGGAK nanyain nama tempat: sertifikatnya bakal nulis
      // `Insitu (…)` buat kerjaan yang nggak pernah keluar gedung.
      expect(find.text('Nama Tempat (Insitu)'), findsNothing);

      await tester.tap(find.text('Inlab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insitu').last);
      await tester.pumpAndSettle();

      expect(find.text('Nama Tempat (Insitu)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Tempat (Insitu)'),
        'PT. LDC',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      expect(service.payloadTerakhir!['lokasi'], 'onsite');
      expect(service.payloadTerakhir!['lokasi_nama'], 'PT. LDC');
    });
  });


  group('pindai lembar kerja', () {
    /// Tombol pindai HARUS ngikut `siap_pindai` dari server.
    ///
    /// Sekarang keenam lembar masih `geometri_belum_diverifikasi`: koordinat
    /// selnya belum diukur dari formulir CETAK asli. Koordinat tebakan berarti
    /// angka mendarat di sel yang salah — persis kegagalan yang mau dicegah
    /// fitur ini. Nyalain paksa "biar bisa dites dulu" cuma bikin teknisi
    /// percaya jalur yang belum boleh dipakai.
    testWidgets('lembar yang belum siap: tombolnya mati + alasannya tampil', (
      tester,
    ) async {
      await _bukaLembar(tester, pindaiAktif: true);

      final tombol = find.widgetWithText(OutlinedButton, 'PINDAI LEMBAR KERJA');

      expect(tombol, findsOneWidget);
      expect(tester.widget<OutlinedButton>(tombol).onPressed, isNull);

      // Alasannya ditampilin APA ADANYA, bukan diterjemahin jadi "fitur belum
      // tersedia": yang bisa nutup cuma lab (cetak ulang formulir + ukur), dan
      // teknisi berhak tahu yang kurang itu apa.
      expect(
        find.textContaining('geometri_belum_diverifikasi'),
        findsOneWidget,
      );
    });

    testWidgets('lembar yang udah siap: tombolnya hidup', (tester) async {
      await _bukaLembar(tester, siapPindai: true, pindaiAktif: true);

      final tombol = find.widgetWithText(OutlinedButton, 'PINDAI LEMBAR KERJA');

      expect(tester.widget<OutlinedButton>(tombol).onPressed, isNotNull);
      expect(find.textContaining('geometri_belum_diverifikasi'), findsNothing);
    });
  });


  group('titik per tabel', () {
    /// Tiga tabel spektro berbagi satu `titik` di state, tapi titiknya
    /// beda-beda (10 nm + 9 nm + 5 %T).
    ///
    /// Yang dulu dijaga di sini: foto satu tabel nggak boleh diadu ke titik
    /// SELURUH lembar — `20,0 %T` gampang nyamar jadi nilai standar nm yang
    /// salah. Jalur fotonya (AI Vision) udah dicabut; pemisahan per tabelnya
    /// tetap dipakai layar & tetap dijaga di bawah.
    test('petunjuk & pemetaan dibatasi ke titik tabelnya', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;
      final state = LembarKerjaState(
        bentuk: bentuk,
        clientRequestId: 'uji-scan',
      );

      // Seluruh lembar 24 titik; tiap tabel cuma bagiannya sendiri.
      expect(state.titikUrut, hasLength(24));
      expect(state.titikTabel(tabel[0]), hasLength(10));
      expect(state.titikTabel(tabel[1]), hasLength(9));
      expect(state.titikTabel(tabel[2]), hasLength(5));

      // Satuannya nggak nyampur: tabel nm nggak kebawa titik %T.
      expect(
        state.titikTabel(tabel[0]).every((t) => t.satuan == 'nm'),
        isTrue,
      );
      expect(
        state.titikTabel(tabel[2]).every((t) => t.satuan == '%T'),
        isTrue,
      );

      // Pesan "x dari y sel" ngitung tabelnya sendiri: blok %T 5 titik × 6
      // pengulangan × 1 kolom = 30, bukan seluruh lembar.
      expect(state.selPerTabelIni(tabel[2]), 30);
      expect(state.selPerTabelIni(tabel[0]), 30);

      state.dispose();
    });
  });

  group('kirim lembar', () {
    /// Bisa nggak lembarnya BENERAN dikirim sesudah diisi?
    ///
    /// Panel pratinjau & tabelnya boleh jadi bener semua, tapi tombol kirim
    /// punya penjaganya sendiri (suhu, pembacaan yang meleset satu orde, isian
    /// yatim) — dan penjaga itu ditulis waktu belum ada alat berkelompok. Yang
    /// dibuktiin di sini: 24 baris terisi lewat, dan yang nyampe service persis
    /// bentuk yang diminta backend.
    testWidgets('24 titik terisi lolos penjaga dan kekirim utuh', (
      tester,
    ) async {
      final service = await _bukaLembar(tester);
      await _pilihAlat(tester);

      final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaSpectro());
      final tabel = bentuk.bagianHasil!.tabel;

      // Diisi PERSIS di nominalnya: penjaga `titikPembacaanJauh` nolak
      // pembacaan yang melesetnya 10x dari nilai titik, dan itu penjaga yang
      // bener — bukan yang mau dites di sini.
      for (var t = 0; t < tabel.length; t++) {
        final kotak = find.descendant(
          of: find.byType(LembarKerjaTabel).at(t),
          matching: find.byType(TextField),
        );
        final kolom = tabel[t].pengulangan.length;

        for (var baris = 0; baris < tabel[t].baris.length; baris++) {
          for (var ulang = 0; ulang < kolom; ulang++) {
            await tester.enterText(
              kotak.at(baris * kolom + ulang),
              '${tabel[t].baris[baris].titikUkur}',
            );
          }
        }
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Dialog konfirmasi angka muncul dulu — kiriman yang nggak disetujui
      // teknisi nggak boleh berangkat.
      expect(find.text('Cek dulu angkanya sebelum dikirim'), findsOneWidget);
      expect(service.jumlahKirim, 0);

      await tester.tap(find.text('Kirim sekarang'));
      await tester.pumpAndSettle();

      final body = service.payloadTerakhir!;
      final measurements = (body['measurements'] as List)
          .cast<Map<String, dynamic>>();

      expect(service.jumlahKirim, 1);
      expect(body['status'], 'menunggu_approval');
      expect(measurements, hasLength(24));

      // Satuan & standar per baris, panjang pembacaan ikut TABELnya: 3 buat
      // panjang gelombang, 6 buat %T.
      final holmium = measurements.firstWhere((m) => m['titik_ukur'] == 279.6);
      final transmitan = measurements.firstWhere((m) => m['titik_ukur'] == 9.9);

      expect(holmium['satuan'], 'nm');
      expect(holmium['standard_id'], 25);
      expect(holmium['pembacaan'], hasLength(3));
      expect(transmitan['satuan'], '%T');
      expect(transmitan['standard_id'], 27);
      expect(transmitan['pembacaan'], hasLength(6));
      expect(
        measurements.every(
          (m) => (m['pembacaan'] as List).every((x) => x != null),
        ),
        isTrue,
        reason: 'nggak ada kotak yang diam-diam nggak kekirim',
      );
    });
  });

  group('layar teknisi', () {
    testWidgets('blok %T dapat ENAM kotak per baris, bukan tiga', (
      tester,
    ) async {
      await _bukaLembar(tester);

      // Tiga tabel di satu bagian: 10 baris × 3 + 9 × 3 + 5 × 6 = 87 kotak.
      // Waktu kolomnya diambil dari `jumlah_pengulangan` level lembar, yang
      // kegambar 72 — tiga kolom terakhir %T ilang dan teknisi nggak punya
      // tempat ngetik separuh datanya.
      expect(
        find.descendant(
          of: find.byType(LembarKerjaTabel),
          matching: find.byType(TextField),
        ),
        findsNWidgets(87),
      );
    });

    testWidgets('blok SRE tampil berlabel, tanpa satu pun kotak isian', (
      tester,
    ) async {
      await _bukaLembar(tester);

      expect(find.text('SRE (STRAY RADIANT ENERGY)'), findsOneWidget);
      expect(find.text('BELUM BISA DIISI'), findsOneWidget);
      // Alasannya ditampilin apa adanya — teknisi nyariin blok ini karena
      // tercetak di lembar kertas yang dia pegang.
      expect(
        find.textContaining('Backend nggak nyetak angka SRE'),
        findsOneWidget,
      );
    });
  });
}

Widget _app(
  MockLembarKerjaService service, {
  bool siapPindai = false,
  bool pindaiAktif = false,
}) => ProviderScope(
  overrides: [
    // UI pindai udah dimatiin di produksi (`AppConfig.pindaiLembarAktif`).
    // Yang nyalain cuma test yang emang nguji alur pindainya.
    pindaiLembarAktifProvider.overrideWithValue(pindaiAktif),
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(service),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    worksheetScanServiceProvider.overrideWithValue(
      MockWorksheetScanService(siapPindai: siapPindai),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LembarKerjaScreen(profil: 'spectrophotometer'),
  ),
);


Future<MockLembarKerjaService> _bukaLembar(
  WidgetTester tester, {
  MockLembarKerjaService? service,
  bool siapPindai = false,
  bool pindaiAktif = false,
}) async {
  // Lembarnya 24 baris × sampai 6 kolom — jauh lebih tinggi dari viewport test
  // standar, dan `ListView` cuma nge-build yang deket layar.
  // Sengaja di BAWAH ambang dua kolom (1100): lembar dua kolom nyusun ulang
  // urutan widget-nya, dan yang diuji di sini isi tabelnya, bukan tata
  // letaknya.
  tester.view.physicalSize = const Size(900, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dipakai = service ?? MockLembarKerjaService();
  await tester.pumpWidget(
    _app(dipakai, siapPindai: siapPindai, pindaiAktif: pindaiAktif),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  return dipakai;
}

Future<void> _pilihAlat(WidgetTester tester) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
  await tester.pumpAndSettle();
}
