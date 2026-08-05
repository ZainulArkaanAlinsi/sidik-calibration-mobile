import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/worksheet_vision.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Lembar kerjanya panjang banget (2 tabel x 3 baris x 5 repeat x 2 kolom =
/// 60 kotak angka doang). `ListView` cuma nge-build yang deket viewport, jadi
/// index widget-nya berubah-ubah tiap discroll — viewport test dibikin raksasa
/// biar seluruh formulir ke-build sekaligus & index-nya stabil.
/// Lebarnya SENGAJA di bawah ambang dua kolom (1100) — ini mode halaman, yang
/// dipakai teknisi di HP. Buat mode dua kolom pakai [_viewportLebar].
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 14000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Layar lebar: lembar kerjanya digambar dua kolom bersebelahan, persis
/// kertasnya.
void _viewportLebar(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 14000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  MockLembarKerjaService service, {
  String profil = 'ph_meter',
  MockStandardService? standar,
  MockRoomService? ruangan,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(
        standar ?? MockStandardService(),
      ),
      roomServiceProvider.overrideWithValue(ruangan ?? MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );
}

/// Buka layar & tunggu semua yang async kelar.
///
/// `pumpAndSettle` doang nggak cukup: `MockAuthService.me()` jeda 600 ms lewat
/// `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame — jadi
/// `pumpAndSettle` balik duluan dan timernya nyangkut. Sama kayak
/// `dashboard_test`.
Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Pilih alat lewat dropdown "Pilih alat" — sesudah ini kolom identitas &
/// pemilik harusnya keisi sendiri.
Future<void> _pilihAlat(
  WidgetTester tester, {
  String alat = 'pH Meter Mettler Toledo · B628755900',
}) async {
  await tester.tap(find.text('Pilih alat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(alat).last);
  await tester.pumpAndSettle();
}

/// Lembar kerjanya sekarang 2 halaman (ngikut kertasnya). Tabel hasil & tombol
/// kirim ada di halaman terakhir, jadi hampir semua test butuh ini dulu.
Future<void> _keHalamanAkhir(WidgetTester tester) async {
  final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
  while (lanjut.evaluate().isNotEmpty) {
    await tester.tap(lanjut);
    await tester.pumpAndSettle();
  }
}

void main() {
  _testRevisi();

  group('bentuk formulir datang dari backend', () {
    testWidgets('bagian & kolom digambar dari respons, bukan di-hardcode', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Halaman 1 ngikut urutan kertas.
      expect(find.text('EQUIPMENT IDENTITY AND CUSTOMER DATA'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('STANDARD'), findsOneWidget);
      expect(find.text('CALIBRATION DATA'), findsOneWidget);
      expect(find.text('SIDIK-FM-CAL-0509_Rev.4'), findsOneWidget);

      // Tabel hasil ada di halaman 2, bukan numpuk di satu layar panjang.
      expect(find.text('Before adjustment Reading'), findsNothing);

      await _keHalamanAkhir(tester);

      expect(find.text('CALIBRATION RESULT'), findsOneWidget);
      expect(find.text('Before adjustment Reading'), findsOneWidget);
      expect(find.text('After adjustment Reading'), findsOneWidget);
    });

    testWidgets('teknisi nggak lihat satu pun kolom administratif', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Backend nggak ngirim kolom ini ke teknisi sama sekali (bukan cuma
      // disembunyiin) — kalau sampai kelihatan, penyaringan per-role bocor.
      expect(find.text('2. Calibration Methode'), findsNothing);
      expect(find.textContaining('Order Number'), findsNothing);

      // Thermohygro SEBALIKNYA: pindah jadi hak teknisi 29 Juli 2026 — dia yang
      // tau unit mana yang kebawa ke lokasi. Dulu kolom ini dibuang backend,
      // jadi teknisi ngisi di HP dan nyampe server jadi null.
      expect(find.text('6. Thermohygro used'), findsOneWidget);
      expect(find.text('TH-2'), findsOneWidget);
      expect(find.text('Insitu'), findsOneWidget);
    });

    testWidgets('kolom otomatis keisi dari alat & jadi read-only', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      await _pilihAlat(tester);

      // Nama alat & rentang tetap READ-ONLY — ketarik dari master, nggak
      // diketik.
      // Pemisah rentangnya en-dash (`–`), bukan hyphen — itu format yang
      // dipakai `EquipmentLookup.rentangTeks` di seluruh layar worksheet.
      expect(find.text('0–14 pH / 0.01 pH'), findsOneWidget);

      // Merk, Type/Model, Serial Number & identitas pemilik keisi dari master
      // juga — TAPI di kotak yang bisa diedit, bukan teks mati. Teknisi mulai
      // dari data yang benar dan cuma nyentuh yang beda sama barang fisiknya.
      final merk = tester.widget<TextField>(
        find.ancestor(
          of: find.text('Mettler Toledo'),
          matching: find.byType(TextField),
        ),
      );
      expect(merk.enabled, isNot(false));
    });
  });

  group('tombol kirim nggak pernah dikunci', () {
    testWidgets('formulir kosong melompong tetap bisa dikirim', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      // Cuma alat yang dipilih. Nol pembacaan, nol kondisi lingkungan.
      await _pilihAlat(tester);

      await _keHalamanAkhir(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['status'], 'menunggu_approval');
    });

    testWidgets('simpan draft kirim status draft', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      expect(service.payloadTerakhir!['status'], 'draft');
    });
  });

  group('sel kosong dikirim sebagai null', () {
    testWidgets('Repeat yang dilewat nggak bikin nomor berikutnya geser', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      // Isi Repeat 1 dan Repeat 3 di tabel After adjustment, titik pH 4 —
      // Repeat 2 sengaja dibiarin kos\ong.
      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Urutan kotak di baris pertama: [r1 pH, r1 °C, r2 pH, r2 °C, r3 pH, ...]
      await tester.enterText(kotak.at(0), '4.00');
      await tester.enterText(kotak.at(1), '22.2');
      await tester.enterText(kotak.at(4), '4.02');
      await tester.enterText(kotak.at(5), '22.1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;
      final titik4 = measurements.firstWhere(
        (m) => (m as Map)['titik_ukur'] == 4.00,
      ) as Map<String, dynamic>;

      // INI aturannya: panjangnya tetap 5, dan yang kosong jadi null di
      // POSISINYA — bukan dibuang sampai Repeat 3 naik jadi Repeat 2.
      expect(titik4['pembacaan'], [4.00, null, 4.02, null, null]);
      expect(titik4['suhu'], [22.2, null, 22.1, null, null]);
    });

    testWidgets('titik yang sama sekali kosong tetap ikut terkirim', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      // Tiga larutan standar tetap ada semua, biar admin lihat kolom mana yang
      // kosong — bukan barisnya ilang dari tabel.
      expect(measurements.length, 3);
      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [4.00, 7.00, 10.01],
      );
      for (final m in measurements) {
        expect((m as Map)['pembacaan'], [null, null, null, null, null]);
      }
    });

    testWidgets('koma desimal diterima, dikirim sebagai titik', (tester) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service));

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);

      final kotak = find.byType(TextField);
      // Formulir kertasnya pakai koma desimal — teknisi ngetik sesuai yang
      // dia lihat, dan itu nggak boleh jadi angka hilang.
      await tester.enterText(kotak.at(0), '21,3');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(service.payloadTerakhir!['suhu_awal'], 21.3);
    });
  });

  group('client_request_id', () {
    testWidgets('retry sesudah sinyal putus bawa UUID yang sama', (
      tester,
    ) async {
      _perbesarViewport(tester);
      // Percobaan pertama gagal (niru sinyal putus pas nunggu respons),
      // percobaan kedua sukses — persis kejadian yang bikin sesi dobel kalau
      // UUID-nya digenerate ulang tiap tap.
      final service = MockLembarKerjaService(gagalKirimSampaiPercobaanKe: 1);
      await _muat(tester, _app(service));

      await _pilihAlat(tester);

      await _keHalamanAkhir(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Gagal → layarnya TETAP kebuka, isian nggak ilang, teknisi bisa coba lagi.
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);

      await _keHalamanAkhir(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      expect(service.jumlahKirim, 2);
      final pertama = service.payload[0]['client_request_id'];
      final kedua = service.payload[1]['client_request_id'];

      expect(pertama, isNotNull);
      expect(kedua, pertama);
    });

    testWidgets('UUID beda antar sesi pengisian yang beda', (tester) async {
      _perbesarViewport(tester);

      final a = MockLembarKerjaService();
      await _muat(tester, _app(a));
      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      // Layar dibuang beneran dulu. Tanpa ini Flutter cuma memperbarui element
      // yang lama (dua-duanya `LembarKerjaScreen` tanpa key), `_FormState`-nya
      // kepakai lagi, dan UUID-nya "kelihatan" sama padahal cuma nggak pernah
      // dibikin ulang.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final b = MockLembarKerjaService();
      await _muat(tester, _app(b));
      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
      await tester.pumpAndSettle();

      // Dua kejadian kalibrasi yang beda harus kebaca beda di server —
      // kalau UUID-nya sama, yang kedua malah dikira retry & dibuang.
      expect(
        b.payloadTerakhir!['client_request_id'],
        isNot(a.payloadTerakhir!['client_request_id']),
      );
    });
  });

  group('gagal muat bentuk formulir', () {
    testWidgets('nampilin pesan + tombol coba lagi, bukan layar kosong', (
      tester,
    ) async {
      await _muat(tester, _app(MockLembarKerjaService(gagal: true)));

      expect(find.text('Gagal memuat bentuk lembar kerja.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  group('layar lebar: dua kolom kayak kertasnya', () {
    testWidgets('kiri & kanan kelihatan sekaligus, tanpa tombol halaman', (
      tester,
    ) async {
      _viewportLebar(tester);
      await _muat(tester, _app(MockLembarKerjaService()));

      // Kiri: identitas & standar. Kanan: hasil kalibrasi. Satu layar, persis
      // formulir cetaknya — teknisi udah hafal peta ini.
      expect(find.text('EQUIPMENT IDENTITY AND CUSTOMER DATA'), findsOneWidget);
      expect(find.text('CALIBRATION RESULT'), findsOneWidget);
      expect(find.text('Before adjustment Reading'), findsOneWidget);

      // Nggak ada yang perlu dibalik halaman — semuanya udah kelihatan.
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
    });
  });

  group('lembar kerja 2 halaman', () {
    test('bagian kebagi ke halaman sesuai kertas', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());

      expect(bentuk.halaman, [1, 2]);

      // Urutan halaman 1 ngikut kertas: identitas → owner → STANDARD →
      // calibration data. Kalau ini kebalik, teknisi ngisi bukan urut lembar.
      expect(
        bentuk.bagianDiHalaman(1).map((b) => b.kode),
        ['identitas_alat', 'pemilik', 'usage_check', 'data_kalibrasi'],
      );
      expect(
        bentuk.bagianDiHalaman(2).map((b) => b.kode),
        ['hasil', 'penutup'],
      );
    });

    test('Env. Condition ada di halaman 2, bareng tabel hasilnya', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final hasil = bentuk.bagianDiHalaman(2).first;

      // Di kertas Env. Condition itu baris pertama blok CALIBRATION RESULT —
      // dicatat waktu ngukur, bukan waktu nyiapin sesi.
      expect(hasil.field.map((f) => f.kode), contains('suhu_awal'));
      expect(hasil.tabel, hasLength(2));
    });

    test('bentuk lama tanpa `halaman` nggak bikin layar kosong', () {
      final bentuk = LembarKerja.fromJson({
        'bagian': [
          {'kode': 'a', 'judul': 'A', 'field': <Map<String, dynamic>>[]},
        ],
      });

      expect(bentuk.halaman, [1]);
      expect(bentuk.bagianDiHalaman(1), hasLength(1));
    });
  });

  group('tabel STANDARD barisnya tercetak', () {
    test('lima baris, bukan seluruh katalog standar lab', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final standar = bentuk.bagian.firstWhere((b) => b.kode == 'usage_check');

      expect(standar.baris.map((b) => b.label), [
        'pH Buffer Solutions 4',
        'pH Buffer Solutions 7',
        'pH Buffer Solutions 10',
        'RTD Sensor/SH1/20',
        'Victor 14+/992613877',
      ]);
    });

    test('standar yang belum kedaftar TETAP jadi baris, tanpa id', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final standar = bentuk.bagian.firstWhere((b) => b.kode == 'usage_check');
      final victor = standar.baris.last;

      // Barisnya hilang jauh lebih bahaya daripada baris yang belum ketaut:
      // teknisi nggak bakal sadar ada standar yang nggak kecatat.
      expect(victor.terdaftar, isFalse);
      expect(victor.standardId, isNull);
    });
  });

  group('Thermohygro used', () {
    test('empat unit tercetak, dikelompokkan Insitu & Inlab', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final field = bentuk.bagian
          .expand((b) => b.field)
          .firstWhere((f) => f.kode == 'thermohygro_standard_id');

      expect(field.sumber, SumberField.masterThermohygro);
      expect(
        field.pilihan.map((p) => (p.label, p.grup)),
        [('TH-2', 'Insitu'), ('TH-6', 'Insitu'), ('TH-7', 'Insitu'), ('TH-4', 'Inlab')],
      );
    });

    test('BUKAN kolom admin lagi — teknisi yang tau unit mana yang kebawa', () {
      final teknisi = LembarKerja.fromJson(contohBentukLembarKerja());

      expect(
        teknisi.bagian.expand((b) => b.field).map((f) => f.kode),
        contains('thermohygro_standard_id'),
      );
    });
  });

  group('model bentuk formulir', () {
    test('kolom bertitik dikenali sebagai turunan, bukan kunci payload', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());
      final identitas = bentuk.bagian.first;

      final namaAlat = identitas.field.firstWhere(
        (f) => f.kode == 'equipment.nama_alat',
      );
      expect(namaAlat.turunan, isTrue);
      expect(namaAlat.sumber.readOnly, isTrue);

      final tanggal = identitas.field.firstWhere(
        (f) => f.kode == 'tanggal_terima',
      );
      expect(tanggal.turunan, isFalse);
    });

    test('tipe kolom yang belum dikenal jatuh ke teks, bukan bikin crash', () {
      final f = FieldLembarKerja.fromJson({
        'kode': 'kolom_baru_rev_5',
        'label': 'Kolom Baru',
        'tipe': 'sesuatu_yang_belum_ada',
      });

      expect(f.tipe, TipeField.teks);
      expect(f.wajib, isFalse);
    });

    test('semua kolom di formulir selalu opsional', () {
      final bentuk = LembarKerja.fromJson(contohBentukLembarKerja());

      for (final bagian in bentuk.bagian) {
        for (final f in bagian.field) {
          expect(f.wajib, isFalse, reason: '${f.kode} nggak boleh wajib');
        }
      }
      expect(bentuk.semuaKolomOpsional, isTrue);
    });

    test('bentuk admin bawa kolom administratif, bentuk teknisi nggak', () {
      final teknisi = LembarKerja.fromJson(contohBentukLembarKerja());
      final admin = LembarKerja.fromJson(
        contohBentukLembarKerja(untukAdmin: true),
      );

      Iterable<String> kode(LembarKerja lk) =>
          lk.bagian.expand((b) => b.field).map((f) => f.kode);

      expect(kode(teknisi), isNot(contains('calibration_method_id')));
      expect(kode(admin), contains('calibration_method_id'));

      // `thermohygro_standard_id` SENGAJA nggak di sini lagi: sejak 29 Juli
      // 2026 dia hak teknisi, bukan kolom administratif. Lihat group
      // "Thermohygro used".
      expect(kode(teknisi), contains('thermohygro_standard_id'));
      expect(admin.untukAdmin, isTrue);
      expect(teknisi.untukAdmin, isFalse);
    });

    test('bentuk backend cacat cuma ngilangin bagian rusak, bukan seluruh form', () {
      // Backend nyampur bagian sehat sama yang cacat: satu bagian tanpa `kode`,
      // satu field tanpa `kode`, satu baris tabel tanpa `titik_ukur`. Sebelum
      // ada jaring _petakanAman, satu cast keras yang gagal ngerontokin SELURUH
      // form jadi layar "gagal muat" — gejala "komponen hilang" di lapangan.
      final rusak = <String, dynamic>{
        'kode_dokumen': 'X',
        'untuk': 'teknisi',
        'bagian': [
          {
            'kode': 'sehat',
            'judul': 'Sehat',
            'field': [
              {'kode': 'a', 'label': 'A', 'tipe': 'teks'},
              {'label': 'tanpa kode'}, // field cacat → dilewat
            ],
          },
          {
            // bagian tanpa `kode` → dilewat, tapi nggak ngebunuh form
            'judul': 'Tanpa kode',
            'field': <Map<String, dynamic>>[],
          },
          {
            'kode': 'hasil',
            'judul': 'Hasil',
            'tabel': [
              {
                'tahap': 'sebelum_adjustment',
                'baris': [
                  {'titik_ukur': 4.0, 'label': '4'},
                  {'label': 'tanpa titik_ukur'}, // baris cacat → dilewat
                ],
                'kolom': [
                  {'kode': 'pembacaan', 'label': 'pH'},
                ],
                'pengulangan': [1, 2],
              },
            ],
          },
        ],
      };

      final bentuk = LembarKerja.fromJson(rusak);

      // Form tetap kebentuk, bukan lempar exception.
      final kodeBagian = bentuk.bagian.map((b) => b.kode).toList();
      expect(kodeBagian, contains('sehat'));
      expect(kodeBagian, contains('hasil'));
      expect(kodeBagian, isNot(contains('Tanpa kode'))); // bagian cacat dilewat

      final sehat = bentuk.bagian.firstWhere((b) => b.kode == 'sehat');
      expect(sehat.field.map((f) => f.kode), ['a']); // field cacat dilewat

      final tabel =
          bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel.first;
      expect(tabel.baris.length, 1); // baris cacat dilewat
      expect(tabel.baris.first.titikUkur, 4.0);
    });
  });

  group('OCR tabel worksheet', () {
    /// `baris` itu **Repeat**, isinya satu angka per larutan standar. Dua sumbu
    /// ini gampang kebalik, dan kalau kebalik angkanya nyasar ke buffer yang
    /// salah tanpa ada yang error — makanya diuji eksplisit.
    HasilEkstraksiTabel contohHasil() => const HasilEkstraksiTabel(
      baris: [
        BarisTabel(ph: [4.01, 7.02, 10.11], suhu: [22.2, 22.3, 22.1]),
        BarisTabel(ph: [4.02, 7.03, 10.12], suhu: [22.2, 22.3, 22.1]),
      ],
      jumlahSelKebaca: 12,
      jumlahSelDiharapkan: 30,
      jumlahAngkaTerdeteksi: 12,
    );

    LembarKerjaState buatState() => LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uuid-test',
    );

    test('angka masuk ke Repeat & larutan standar yang benar', () {
      final isian = buatState();
      final terisi = isian.terapkanHasilEkstraksi(
        contohHasil(),
        tahap: 'sesudah_adjustment',
      );

      // 2 Repeat x 3 titik x 2 kolom (pH & suhu).
      expect(terisi, 12);

      final titik4 = isian.titik[4.00]!;
      final titik10 = isian.titik[10.01]!;

      // Repeat 1 buffer 4 -> 4.01, BUKAN 7.02 (itu buffer 7 di Repeat yang sama).
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4.01');
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 1).text, '4.02');
      expect(titik10.kotak('sesudah_adjustment', 'pembacaan', 0).text, '10.11');
      expect(titik4.kotak('sesudah_adjustment', 'suhu', 0).text, '22.2');
    });

    test('sel yang udah diketik manual NGGAK ketimpa hasil foto', () {
      final isian = buatState();
      final titik4 = isian.titik[4.00]!;

      // Teknisi udah betulin angka ini sendiri.
      titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text = '4.00';

      final terisi = isian.terapkanHasilEkstraksi(
        contohHasil(),
        tahap: 'sesudah_adjustment',
      );

      // Foto boleh dipakai berkali-kali buat nambal yang kurang; yang udah
      // dibetulin manusia harus menang.
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, '4.00');
      expect(terisi, 11, reason: 'satu sel dilewat karena udah keisi');
    });

    test('blok non-tabel keisi dari foto yang sama', () {
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'suhu_awal': NilaiHeader(
              nilai: '22.2',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'catatan_teknisi': NilaiHeader(
              nilai: 'buffer 10 baru dibuka',
              keyakinan: TingkatKeyakinan.rendah,
            ),
          },
          tanggal: {
            'tanggal_terima': NilaiHeader(
              nilai: '23/07/2026',
              keyakinan: TingkatKeyakinan.sedang,
            ),
          },
        ),
      );

      expect(terisi, 3);
      expect(isian.teks['suhu_awal']!.text, '22.2');
      expect(isian.teks['catatan_teknisi']!.text, 'buffer 10 baru dibuka');
      expect(isian.tanggal['tanggal_terima'], DateTime(2026, 7, 23));

      // Cuma yang keyakinannya rendah yang ditandai — nyuruh cek SEMUA kolom
      // sama aja nggak nandain apa-apa.
      expect(
        isian.selRendahKeyakinan.contains(
          LembarKerjaState.kunciField('catatan_teknisi'),
        ),
        isTrue,
      );
      expect(
        isian.selRendahKeyakinan.contains(
          LembarKerjaState.kunciField('suhu_awal'),
        ),
        isFalse,
      );
    });

    test('AI NGGAK BISA nulis serial number / tanda tangan', () {
      // Ini pagar paling penting di seluruh alur foto. Serial number salah satu
      // digit bikin kalibrasi nempel ke instrumen yang salah — itu cacat
      // sertifikat berakreditasi, bukan sekadar bug. Sumbernya wajib DB.
      // Tanda tangan "Checked by" apalagi: itu provenance, bukan data.
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'equipment.serial_number': NilaiHeader(
              nilai: 'B628755900',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'customer.nama': NilaiHeader(
              nilai: 'PT Tirta Gracia',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
            'reviewer.nama': NilaiHeader(
              nilai: 'Budi',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      // Backend boleh nekat ngirim kolom ini; mobile tetap nolak semuanya.
      expect(terisi, 0);
      expect(isian.teks.containsKey('equipment.serial_number'), isFalse);
      expect(isian.teks.containsKey('customer.nama'), isFalse);
      expect(isian.teks.containsKey('reviewer.nama'), isFalse);
    });

    test('kolom non-tabel yang udah diketik manual NGGAK ketimpa', () {
      final isian = buatState();
      isian.teks['suhu_awal']!.text = '23.0';

      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          field: {
            'suhu_awal': NilaiHeader(
              nilai: '22.2',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      expect(terisi, 0);
      expect(isian.teks['suhu_awal']!.text, '23.0');
    });

    test('tanggal_kalibrasi udah keisi hari ini → AI nggak nimpa', () {
      final isian = buatState();
      final sebelum = isian.tanggal['tanggal_kalibrasi'];

      isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          tanggal: {
            'tanggal_kalibrasi': NilaiHeader(
              nilai: '01/01/2020',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          },
        ),
      );

      expect(isian.tanggal['tanggal_kalibrasi'], sebelum);
    });

    test('usage check dari AI SELALU ditandai perlu dicek', () {
      // Centang yang kebalik itu klaim standar mana yang dipakai — alias
      // ketertelusuran. Beda kelas dari salah baca satu angka, jadi keyakinan
      // "high" pun nggak cukup buat ngelolosin tanpa mata manusia.
      final isian = buatState();
      final terisi = isian.terapkanHasilHeader(
        const HasilEkstraksiHeader(
          usageCheck: [
            UsageCheckAi(
              standardId: 3,
              dipakai: true,
              keterangan: 'buffer 4',
              keyakinan: TingkatKeyakinan.tinggi,
            ),
          ],
        ),
      );

      expect(terisi, 1);
      expect(isian.usageCheck[3]!.dipakai, isTrue);
      expect(isian.usageCheck[3]!.keterangan.text, 'buffer 4');
      expect(
        isian.selRendahKeyakinan.contains(LembarKerjaState.kunciUsage(3)),
        isTrue,
      );
    });

    test('foto tabel Before nggak nyentuh tabel After', () {
      final isian = buatState();
      isian.terapkanHasilEkstraksi(contohHasil(), tahap: 'sebelum_adjustment');

      final titik4 = isian.titik[4.00]!;
      expect(titik4.kotak('sebelum_adjustment', 'pembacaan', 0).text, '4.01');
      expect(titik4.kotak('sesudah_adjustment', 'pembacaan', 0).text, isEmpty);
    });

    test('hasil OCR ikut kekirim lewat payload, sel sisanya tetap null', () {
      final isian = buatState()..alat = null;
      isian.terapkanHasilEkstraksi(contohHasil(), tahap: 'sesudah_adjustment');

      final titik4 = isian.titik[4.00]!.toSubmission().toJson();

      // Dua Repeat keisi dari foto, tiga sisanya tetap null di posisinya.
      expect(titik4['pembacaan'], [4.01, 4.02, null, null, null]);
    });
  });

  _testDropdownGagal();
  _testTurbidimeter();
}

/// Tiga dropdown di lembar kerja dulu HILANG tanpa sepatah kata kalau daftarnya
/// gagal diambil. Buat teknisi, kolom yang nggak ada itu nggak bisa dibedain
/// dari kolom yang emang nggak diminta di lembar ini — dia lanjut ngisi,
/// ngirim, dan baru tahu ada yang kurang waktu admin ngembaliin sesinya.
void _testDropdownGagal() {
  group('daftar gagal dimuat → kolomnya bilang, bukan menghilang', () {
    testWidgets('standar acuan per titik: pesan + COBA LAGI', (tester) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(
          MockLembarKerjaService(),
          standar: MockStandardService(gagal: true),
        ),
      );
      await _keHalamanAkhir(tester);

      // Tiga titik pH → tiga dropdown standar per titik, tiga-tiganya wajib
      // ngaku. Ini ketertelusuran: sesi tanpa standar yang ketaut nggak bisa
      // jadi sertifikat berakreditasi.
      expect(find.text('Gagal memuat standar acuan.'), findsNWidgets(3));
      expect(find.text('COBA LAGI'), findsNWidgets(3));
    });

    testWidgets('ruangan: gagal muat beda dari "belum ada ruangan"', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), ruangan: MockRoomService(gagal: true)),
      );

      expect(find.text('Gagal memuat daftar ruangan.'), findsOneWidget);
    });

    testWidgets('daftar sehat → nggak ada pesan gagal yang nyasar', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockLembarKerjaService()));
      await _keHalamanAkhir(tester);

      expect(find.text('Gagal memuat standar acuan.'), findsNothing);
      expect(find.text('Gagal memuat daftar ruangan.'), findsNothing);
    });

    testWidgets('lembar tetap bisa dikirim walau daftarnya gagal', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(
        tester,
        _app(
          service,
          standar: MockStandardService(gagal: true),
          ruangan: MockRoomService(gagal: true),
        ),
      );

      await _pilihAlat(tester);
      await _keHalamanAkhir(tester);
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Aturan lembar kerja nggak berubah: tombol kirim NGGAK PERNAH dikunci.
      // Pesan gagal itu ngasih tahu, bukan ngeblok — kalau sampai ngeblok,
      // teknisi di lapangan kehilangan seluruh isian gara-gara satu daftar
      // yang nggak keambil.
      expect(service.jumlahKirim, 1);
      expect(service.payloadTerakhir!['standard_id'], isNull);
      expect(service.payloadTerakhir!['room_id'], isNull);
    });
  });
}

/// Turbidimeter itu jenis alat KEDUA yang punya lembar kerja sendiri, dan
/// bentuknya beda dari pH di tempat-tempat yang gampang ketuker: satu halaman
/// (bukan dua), titik 1/100/1000 NTU, dan resolusinya beda PER BARIS. Selama
/// ini semua test lembar kerja cuma megang pH, jadi kalau jalur `?profil=`
/// diam-diam balik ke bentuk pH, nggak ada satu pun yang gagal.
void _testTurbidimeter() {
  LembarKerja bentukTurbidi({bool untukAdmin = false}) =>
      LembarKerja.fromJson(contohBentukLembarKerjaTurbidi(untukAdmin: untukAdmin));

  group('Turbidimeter: bentuknya sendiri, bukan pH yang disamar', () {
    test('profil dilempar ke backend → dokumen & titik ukurnya ikut ganti', () async {
      final service = MockLembarKerjaService();

      final turbidi = await service.ambilBentuk('t', profil: 'turbidimeter');
      expect(turbidi.kodeDokumen, 'SIDIK-FM-CAL-0530_Rev.2');
      expect(turbidi.satuan, 'NTU');
      expect(turbidi.larutanStandar, [1.0, 100.0, 1000.0]);
    });

    test('profil kosong tetap dapat pH — bukan error, bukan layar kosong', () async {
      final service = MockLembarKerjaService();

      // Layar lama & tautan yang belum bawa `profil` masih ada di app —
      // `LembarKerjaScreen.profil` default-nya `ph_meter`, dan `ApiLembarKerja
      // Service` malah nggak nempelin query-nya sama sekali kalau kosong.
      // Jadi "tanpa profil" wajib jatuh ke pH, bukan error.
      final tanpaProfil = await service.ambilBentuk('t');
      expect(tanpaProfil.kodeDokumen, 'SIDIK-FM-CAL-0509_Rev.4');
      expect(tanpaProfil.satuan, 'pH');
    });

    test('resolusi beda PER BARIS, bukan satu angka buat seluruh tabel', () {
      final tabel = bentukTurbidi()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Ini inti alat ini: 1 NTU dibaca sampai 0,01, 1000 NTU dibulatin ke
      // satuan. Dipaksa satu angka buat semuanya, titik 100 kecetak `101,00`
      // di sertifikat — cacat angka penting, bukan cuma jelek dilihat.
      expect(tabel.baris.map((b) => b.titikUkur), [1.0, 100.0, 1000.0]);
      expect(tabel.baris.map((b) => b.desimal), [2, 1, 0]);
      expect(tabel.baris.map((b) => b.resolusi), [0.01, 0.1, 1.0]);
    });

    test('pH SEBALIKNYA nggak bawa desimal per baris — resolusinya seragam', () {
      final tabel = LembarKerja.fromJson(contohBentukLembarKerja())
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      // Kalau suatu hari pH ikut bawa `desimal`, yang berubah bukan cuma
      // sertifikatnya — jalur "null = seragam" di [BarisTabelHasil] ikut mati.
      expect(tabel.baris.map((b) => b.desimal), [null, null, null]);
    });

    test('STANDARD-nya larutan turbidity, bukan buffer pH', () {
      final standar =
          bentukTurbidi().bagian.firstWhere((b) => b.kode == 'usage_check');

      expect(standar.baris.map((b) => b.label), [
        'Turbidity Standard 1 NTU',
        'Turbidity Standard 100 NTU',
        'Turbidity Standard 1000 NTU',
        'RTD Sensor/SH1/20',
        'Victor 14+/992613877',
      ]);

      // Aturan yang sama kayak pH: standar yang belum kedaftar TETAP jadi
      // baris, tanpa id.
      expect(standar.baris.last.terdaftar, isFalse);
      expect(standar.baris.last.standardId, isNull);
    });

    test('kolom tabelnya NTU, bukan pH yang lupa diganti', () {
      final tabel = bentukTurbidi()
          .bagian
          .firstWhere((b) => b.kode == 'hasil')
          .tabel
          .first;

      expect(tabel.kolom.map((k) => k.label), ['NTU', '°C']);
      expect(tabel.kolom.first.satuan, 'NTU');
    });

    test('satu halaman, bukan dua kayak pH — kertasnya emang selembar', () {
      expect(bentukTurbidi().halaman, [1]);
      expect(LembarKerja.fromJson(contohBentukLembarKerja()).halaman, [1, 2]);
    });

    test('kolom admin tetap disaring sama kayak pH', () {
      Iterable<String> kode(LembarKerja lk) =>
          lk.bagian.expand((b) => b.field).map((f) => f.kode);

      expect(kode(bentukTurbidi()), isNot(contains('calibration_method_id')));
      expect(
        kode(bentukTurbidi(untukAdmin: true)),
        contains('calibration_method_id'),
      );
    });
  });

  group('Turbidimeter di layar', () {
    testWidgets('tabel hasil langsung kelihatan, nggak ada balik halaman', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'turbidimeter'),
      );

      expect(find.text('SIDIK-FM-CAL-0530_Rev.2'), findsOneWidget);
      expect(find.text('Turbidity Standard 1 NTU'), findsOneWidget);

      // Beda paling kerasa dari pH: nggak ada halaman 2, jadi tombol lanjutnya
      // nggak boleh nongol sama sekali.
      expect(find.text('LANJUT KE HALAMAN BERIKUTNYA'), findsNothing);
      expect(find.text('Before adjustment Reading'), findsOneWidget);
      expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
    });

    testWidgets('tiga titik NTU ikut terkirim, sel kosong tetap null', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await _muat(tester, _app(service, profil: 'turbidimeter'));

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');

      final tabelAfter = find.ancestor(
        of: find.text('After adjustment Reading'),
        matching: find.byType(Column),
      );
      final kotak = find.descendant(
        of: tabelAfter.first,
        matching: find.byType(TextField),
      );

      // Baris pertama = titik 1 NTU. Repeat 1 & 3 diisi, Repeat 2 dilewat.
      await tester.enterText(kotak.at(0), '1,01');
      await tester.enterText(kotak.at(1), '22.2');
      await tester.enterText(kotak.at(4), '0,99');
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      final measurements =
          service.payloadTerakhir!['measurements'] as List<dynamic>;

      expect(
        measurements.map((m) => (m as Map)['titik_ukur']).toList(),
        [1.0, 100.0, 1000.0],
      );

      final titik1 = measurements.first as Map<String, dynamic>;
      expect(titik1['pembacaan'], [1.01, null, 0.99, null, null]);
      expect(titik1['suhu'], [22.2, null, null, null, null]);
      expect(titik1['satuan'], 'NTU');
    });

    testWidgets('sesi baru masuk antrean sebagai Turbidimeter, bukan pH Meter', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockLembarKerjaService(), profil: 'turbidimeter'),
      );

      await _pilihAlat(tester, alat: 'Turbidimeter Hach · HC-2100Q-114');
      await tester.tap(find.text('KIRIM KE ADMIN'));
      await tester.pumpAndSettle();

      // Nama sesi di USE_MOCK dulu dipatok 'pH Meter (sesi baru)' — admin yang
      // nyoba alur turbidimeter offline lihat pH di antrean approval dan nggak
      // punya cara buat sadar itu salah.
      expect(
        MockStore.instance.sesi.first.namaAlat,
        'Turbidimeter Hach (sesi baru)',
      );
    });
  });
}

void _testRevisi() {
  group('revisi: kolom yang ditandai admin', () {
    test('isian teknisi + kode kolom kebaca dari respons sesi', () {
      final isi = IsianTeknisi.fromJson(const {
        'alat_serial_number': 'HN-2211-05',
        'pemilik_nama': 'PT Maju Jaya',
        'suhu_awal': 19.8,
        'revisi_field': ['alat_serial_number', 'suhu_awal'],
      });

      expect(isi.alatSerialNumber, 'HN-2211-05');
      expect(isi.revisiField, {'alat_serial_number', 'suhu_awal'});
    });

    test('formulir keisi ulang dari sesi — teknisi nggak ngetik dari nol', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'alat_serial_number': 'HN-2211-05',
          'alat_merk': 'Hanna',
          'suhu_awal': 19.8,
          'revisi_field': ['alat_serial_number'],
        }),
      );

      expect(state.teks['alat_serial_number']!.text, 'HN-2211-05');
      expect(state.teks['alat_merk']!.text, 'Hanna');
      expect(state.teks['suhu_awal']!.text, '19.8');
      expect(state.revisiField, {'alat_serial_number'});
    });

    test('catatan admin kebaca utuh, bukan cuma kode kolomnya', () {
      final isi = IsianTeknisi.fromJson(const {
        'revisi_field': ['suhu_awal'],
        'catatan_revisi': 'Suhu awal 19,8 nggak masuk rentang IK (20±2). '
            'Ulangi pembacaannya sesudah alatnya settle 15 menit.',
      });

      // Kolom bergaris merah cuma jawab MANA yang salah. Yang bikin teknisi
      // ngerti harus ngapain itu alasannya — dan itu mesti utuh, nggak
      // dipotong kayak di notifikasi.
      expect(isi.catatanRevisi, contains('settle 15 menit'));
    });

    test('catatan admin dibawa ke state, kebaca di layar betulannya', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'revisi_field': ['suhu_awal'],
          'catatan_revisi': 'Ulangi pembacaan suhu awal.',
        }),
      );

      expect(state.catatanRevisi, 'Ulangi pembacaan suhu awal.');
      expect(state.adaRevisi, isTrue);
    });

    test('ditolak dengan catatan TAPI tanpa nandain kolom tetap kelihatan', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // `revisi_field` boleh null di backend — admin sah nolak cuma pakai
      // catatan. Dulu banner-nya digantung ke `revisiField.isNotEmpty`, jadi
      // teknisi dapat lembar yang kelihatan normal padahal udah dikembaliin.
      state.muatDariSesi(
        IsianTeknisi.fromJson(const {
          'catatan_revisi': 'Lembarnya ketuker sama sesi lain, kirim ulang.',
        }),
      );

      expect(state.revisiField, isEmpty);
      expect(state.adaRevisi, isTrue);
    });

    test('sesi normal (nggak ditolak) nggak munculin banner apa pun', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'alat_merk': 'Hanna'}),
      );

      expect(state.adaRevisi, isFalse);
    });

    test('catatan kosong/spasi doang nggak dianggap revisi', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'catatan_revisi': '   '}),
      );

      expect(state.adaRevisi, isFalse);
    });

    test('yang udah diketik teknisi NGGAK ketimpa data lama', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // Layar bisa kebuka duluan & teknisi langsung ngetik sebelum detail
      // sesinya nyampe dari jaringan yang lelet. Kalau data lama nimpa, koreksi
      // teknisi ilang di depan matanya sendiri.
      state.teks['alat_serial_number']!.text = 'HN-BARU-DIKETIK';

      state.muatDariSesi(
        IsianTeknisi.fromJson(const {'alat_serial_number': 'HN-LAMA'}),
      );

      expect(state.teks['alat_serial_number']!.text, 'HN-BARU-DIKETIK');
    });

    test('pilih alat → identitas & pemilik keisi sendiri dari master', () async {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      final daftar = await MockEquipmentLookupService().cari('');
      state.alat = daftar.firstWhere(
        (a) => a.pelangganNama.isNotEmpty,
      );
      state.isiDariAlat();

      // Data master udah ada waktu pelanggannya didaftarin — nyuruh teknisi
      // ngetik ulang di lapangan itu kerja dobel yang bikin salah ketik.
      expect(state.teks['pemilik_nama']!.text, isNotEmpty);
      expect(state.teks['alat_serial_number']!.text, isNotEmpty);
    });

    test('yang udah diketik NGGAK keganti waktu ganti alat', () async {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      // Teknisi baca serial dari badan alat — beda dari master, dan ITU yang
      // sah di dokumen kalibrasi.
      state.teks['alat_serial_number']!.text = 'DIBACA-DARI-ALAT';
      state.alat = (await MockEquipmentLookupService().cari('')).first;
      state.isiDariAlat();

      expect(state.teks['alat_serial_number']!.text, 'DIBACA-DARI-ALAT');
    });

    test('sesi tanpa revisi_field nggak nyorot apa-apa', () {
      final state = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'x',
      );

      state.muatDariSesi(IsianTeknisi.fromJson(const {'alat_merk': 'Hanna'}));

      expect(state.revisiField, isEmpty);
    });
  });
}
