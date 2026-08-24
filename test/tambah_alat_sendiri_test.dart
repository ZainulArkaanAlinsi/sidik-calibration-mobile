import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// TEKNISI NAMBAH NAMA ALAT SENDIRI, tanpa nunggu admin.
///
/// Keadaan sebelum ini: daftar di layar pilih alat murni dari server, dan
/// kalau alat pelanggan nggak ada di situ jalurnya buntu — teknisi udah
/// berdiri di depan alatnya, dan sesinya nggak jadi hari itu.
///
/// Tiga hal yang dijaga berkas ini, dan ketiganya pernah jadi cara fitur
/// beginian gagal:
///
///  1. **Tawarannya muncul pas orangnya sadar.** Teknisi baru tau alatnya
///     nggak ada justru sesudah nyari — jadi tombolnya nongol di hasil cari
///     yang kosong, bawa kata yang barusan dia ketik. Nyuruh ngetik ulang nama
///     yang masih kelihatan di kolom cari itu cara paling cepat bikin orang
///     nyerah dan nelepon admin.
///  2. **Nama kembar dijawab jujur.** "Gagal" doang bikin teknisi nyoba lagi
///     pakai "pH Meter 2" sampai ada yang nyangkut — dan daftar kemampuan lab
///     jadi kembar tiga.
///  3. **Peringatan CMC-nya kelihatan SEBELUM disimpan.** Alat yang lahir dari
///     sini nggak punya lantai CMC, jadi U yang terbit bisa lebih kecil
///     daripada yang diakreditasi TANPA satu pun error. Kalau kalimat itu baru
///     muncul sesudah sertifikatnya terbit, yang bisa dilakuin teknisi cuma
///     nyesel.
void main() {
  const analitik = Category(
    kode: 'instrumen-analitik',
    nama: 'Instrumen Analitik',
    satuan: 'pH',
  );

  group('layanan mock — alat baru beneran nyangkut di daftar', () {
    test('sesudah ditambah, `detail` mulangin alatnya', () async {
      final svc = MockCategoryService();

      final baru = await svc.tambahKemampuan(
        'token',
        'instrumen-analitik',
        'Anemometer',
      );

      final isi = await svc.detail('token', 'instrumen-analitik');

      expect(isi.kemampuan.map((k) => k.namaAlat), contains('Anemometer'));
      // Dua penanda yang dituturkan backend buat baris yang lahir dari
      // teknisi: nggak punya lantai CMC, dan nggak punya lembar kerja khusus.
      expect(baru.tanpaCmc, isTrue);
      expect(baru.profil, isNull);
    });

    test('nggak nyampur ke kategori lain', () async {
      final svc = MockCategoryService();

      await svc.tambahKemampuan('token', 'instrumen-analitik', 'Anemometer');
      final panjang = await svc.detail('token', 'panjang');

      expect(panjang.kemampuan.map((k) => k.namaAlat), isNot(contains('Anemometer')));
    });

    test('nama kembar ditolak — beda huruf besar & spasi tetap kembar', () async {
      final svc = MockCategoryService();

      // "pH Meter" udah ada di lampiran akreditasi. Tiga ejaan di bawah ini
      // satu alat yang sama buat orang yang megang, jadi ketiganya mesti
      // ditolak — backend bandinginnya juga nggak peka huruf.
      for (final nama in ['pH Meter', 'ph meter', 'PH  METER ']) {
        expect(
          () => svc.tambahKemampuan('token', 'instrumen-analitik', nama),
          throwsA(isA<NamaAlatKembarException>()),
          reason: nama,
        );
      }
    });
  });

  group('layanan API — 422 nama kembar dibedain dari gagal lain', () {
    ApiCategoryService layanan(_ServerPalsu server) =>
        ApiCategoryService(ApiClient(client: server, baseUrl: 'http://uji/api'));

    test('201 mulangin baris kemampuan apa adanya', () async {
      final server = _ServerPalsu(
        201,
        '{"data":{"nama_alat":"Anemometer","tanpa_cmc":true,"profil":null}}',
      );

      final baru = await layanan(
        server,
      ).tambahKemampuan('token', 'instrumen-analitik', 'Anemometer');

      expect(baru.namaAlat, 'Anemometer');
      expect(baru.tanpaCmc, isTrue);
      expect(server.jalur, '/api/categories/instrumen-analitik/kemampuan');
      expect(server.kiriman, contains('"nama_alat":"Anemometer"'));
    });

    test('422 + `errors.nama_alat` = nama kembar', () async {
      final server = _ServerPalsu(
        422,
        '{"message":"Data tidak valid","errors":{"nama_alat":["sudah dipakai"]}}',
      );

      await expectLater(
        layanan(server).tambahKemampuan('token', 'instrumen-analitik', 'pH Meter'),
        throwsA(
          isA<NamaAlatKembarException>().having(
            (e) => e.namaAlat,
            'namaAlat',
            'pH Meter',
          ),
        ),
      );
    });

    test('422 yang BUKAN soal nama alat nggak dipalsuin jadi "udah ada"', () async {
      // Kalau semua 422 dianggap kembar, teknisi disuruh nyari kartu yang
      // nggak akan pernah dia temuin — sementara sebab aslinya (mis. batas
      // percobaan) nggak pernah kelihatan.
      final server = _ServerPalsu(422, '{"message":"Kebanyakan percobaan."}');

      await expectLater(
        layanan(server).tambahKemampuan('token', 'instrumen-analitik', 'Anemometer'),
        throwsA(isA<ApiException>()),
      );
    });

    test('server lama yang belum punya endpoint-nya (404) diterusin apa adanya', () async {
      final server = _ServerPalsu(404, '{"message":"Data nggak ketemu."}');

      await expectLater(
        layanan(server).tambahKemampuan('token', 'instrumen-analitik', 'Anemometer'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('layar pilih alat', () {
    late MockCategoryService layanan;

    Widget app(Category kategori) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        categoryServiceProvider.overrideWithValue(layanan),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstrumentPickerScreen(kategori: kategori),
      ),
    );

    setUp(() => layanan = MockCategoryService());

    /// Kotak tambah alat + peringatannya lebih tinggi dari layar 800x600
    /// bawaan. Isinya digulir, jadi teks tetap ada di pohon — tapi tombolnya
    /// nggak bisa diketuk kalau nggak kegambar.
    void layarTinggi(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('hasil cari kosong nawarin nambah PAKAI kata yang diketik', (
      tester,
    ) async {
      layarTinggi(tester);
      await tester.pumpWidget(app(analitik));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anemometer');
      await tester.pumpAndSettle();

      expect(find.text('Nggak ketemu jenis alat yang cocok.'), findsOneWidget);
      expect(
        find.text('Tambah "Anemometer" sebagai alat baru'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tambah "Anemometer" sebagai alat baru'));
      await tester.pumpAndSettle();

      // Nama yang diketik kebawa masuk — nggak ada yang perlu diketik ulang.
      final kolom = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(kolom.controller?.text, 'Anemometer');
    });

    testWidgets('peringatan CMC-nya nongol SEBELUM tombol simpan dipencet', (
      tester,
    ) async {
      layarTinggi(tester);
      await tester.pumpWidget(app(analitik));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anemometer');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah "Anemometer" sebagai alat baru'));
      await tester.pumpAndSettle();

      expect(find.text('Baca dulu sebelum disimpan'), findsOneWidget);

      // Yang dijaga bukan cuma "ada tulisan peringatan", tapi ISINYA: angka
      // yang terbit bisa lebih KECIL dari yang diakreditasi, dan nggak ada
      // error yang bunyi. Dua kalimat itu yang bikin peringatannya berguna.
      final peringatan = tester
          .widget<Text>(
            find.textContaining('belum punya angka batas dari lampiran akreditasi'),
          )
          .data!;
      expect(peringatan, contains('lebih KECIL'));
      expect(peringatan, contains('Nggak ada error yang bunyi'));

      // Bukan penghalang: tombol simpannya tetap hidup.
      final simpan = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'SIMPAN & PAKAI'),
      );
      expect(simpan.onPressed, isNotNull);
    });

    testWidgets('sesudah disimpan, alatnya LANGSUNG ada di daftar', (
      tester,
    ) async {
      layarTinggi(tester);
      await tester.pumpWidget(app(analitik));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Anemometer');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah "Anemometer" sebagai alat baru'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIMPAN & PAKAI'));
      await tester.pumpAndSettle();

      // Kotaknya nutup sendiri, saringan carinya dikosongin, dan kartunya ada
      // di daftar — tanpa teknisi keluar-masuk layar.
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('"Anemometer" udah masuk daftar — langsung bisa dipilih.'),
        findsOneWidget,
      );
      expect(find.text('Anemometer'), findsOneWidget);
      // Alat lama tetap di tempatnya — yang nambah satu, bukan ngeganti daftar.
      expect(find.text('pH Meter'), findsOneWidget);

      // Dan penandanya kebawa: alat ini nggak punya lantai CMC, dan itu
      // kelihatan di kartunya buat siapa pun yang mbukanya nanti.
      expect(find.text('Belum ada rentang CMC'), findsOneWidget);
    });

    testWidgets('nama kembar tampil sebagai kalimat yang bisa dibaca', (
      tester,
    ) async {
      layarTinggi(tester);
      await tester.pumpWidget(app(analitik));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Zzz');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah "Zzz" sebagai alat baru'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ph meter',
      );
      await tester.tap(find.text('SIMPAN & PAKAI'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '"ph meter" udah ada di kategori ini. Tutup kotak ini terus cari di daftarnya.',
        ),
        findsOneWidget,
      );
      // Kotaknya TETAP kebuka: nama yang udah diketik nggak ilang, dan
      // teknisi bisa langsung mbenerin atau nutup buat nyari kartunya.
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('kategori kecil tanpa kolom cari tetap punya jalan nambah', (
      tester,
    ) async {
      // "Panjang" cuma 2 alat di mock, jadi kolom carinya nggak digambar sama
      // sekali (`_ambangCari`). Tanpa tombol di ekor daftar, kategori kecil
      // nggak punya satu pun jalan masuk ke fitur ini.
      layarTinggi(tester);
      await tester.pumpWidget(
        app(const Category(kode: 'panjang', nama: 'Panjang', satuan: 'mm')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Alatnya nggak ada di daftar? Tambah sendiri.'), findsOneWidget);
    });

    testWidgets('kategori yang KOSONG nggak buntu lagi', (tester) async {
      // Kategori tanpa satu pun baris kemampuan dulu cuma nampilin kalimat
      // "belum punya data kemampuan kalibrasi" dan nol tombol — teknisi mentok
      // di situ dan sesinya nggak jadi hari itu.
      layarTinggi(tester);
      await tester.pumpWidget(
        app(const Category(kode: 'massa', nama: 'Massa', satuan: 'g')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Kategori ini belum punya data kemampuan kalibrasi.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Alatnya nggak ada di daftar? Tambah sendiri.'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Timbangan Digital',
      );
      await tester.tap(find.text('SIMPAN & PAKAI'));
      await tester.pumpAndSettle();

      expect(find.text('Timbangan Digital'), findsOneWidget);
    });

    testWidgets('nama kosong ditahan di kotaknya, nggak dikirim ke server', (
      tester,
    ) async {
      layarTinggi(tester);
      await tester.pumpWidget(
        app(const Category(kode: 'panjang', nama: 'Panjang', satuan: 'mm')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alatnya nggak ada di daftar? Tambah sendiri.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIMPAN & PAKAI'));
      await tester.pumpAndSettle();

      expect(find.text('Nama alatnya diisi dulu.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}

/// Server yang jawabannya ditentuin test, plus nyatet apa yang dikirim.
class _ServerPalsu extends http.BaseClient {
  _ServerPalsu(this.status, this.badan);

  final int status;
  final String badan;

  String? jalur;
  String? kiriman;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    jalur = request.url.path;
    kiriman = request is http.Request ? request.body : null;

    return http.StreamedResponse(
      Stream.value(utf8.encode(badan)),
      status,
    );
  }
}
