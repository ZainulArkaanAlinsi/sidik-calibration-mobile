import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Gerbang "wajib dicek" di LAYAR lembar kerja: tombol Kirim final mati selama
/// ada sel hasil kamera yang belum dicek, alasannya tertulis dengan jumlah,
/// konfirmasi berlaku untuk satu sel, dan tidak ada tombol "terima semua".
///
/// Sel kamera diantar lewat salinan HP (`DrafLokal.isian`) — jalur pemulihan
/// yang sama dengan yang dipakai teknisi sesudah aplikasi dibuka ulang, jadi
/// test ini sekaligus membuktikan penandanya tahan muat ulang.
void main() {
  const userId = 1; // `mock-token-1`

  const alat = EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Mettler Toledo',
    model: 'Five Easy',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA CONTOH MANDIRI',
    pelangganAlamat: 'Jl. Contoh Primer A-10, Kab. Bandung',
  );

  setUp(() => MockStore.instance.reset());

  /// Galat pertama yang ditangkap (mis. RenderFlex meluap), lengkap dengan
  /// widget penyebabnya.
  FlutterErrorDetails? galatRinci;

  /// Salinan HP dengan tiga sel pembacaan hasil foto (4,00 / 7,00 / 10,01).
  Future<
    ({
      SimpananDrafLokalMemori hp,
      DrafLokal draf,
      String teks7,
      List<String> teksSemua,
    })
  >
  siapkanDraf() async {
    final s = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
    )..alat = alat;
    final tabel = s.bentuk.bagian
        .expand((b) => b.tabel)
        .firstWhere((t) => t.tahap == 'sesudah_adjustment');
    s.terapkanHasilFotoTabel([
      for (final (t, v) in [(4.0, '4,01'), (7.0, '7,02'), (10.01, '10,00')])
        (
          titikUkur: t,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: v,
          keyakinan: 0.99,
        ),
    ], tabel: tabel);
    final teks7 = s.titik[7.0]!
        .kotak('sesudah_adjustment', 'pembacaan', 0)
        .text;
    final teksSemua = [
      for (final t in [4.0, 7.0, 10.01])
        s.titik[t]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
    ];

    final draf = DrafLokal(
      userId: userId,
      clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
      profil: 'ph_meter',
      equipmentId: alat.id,
      disimpanPada: DateTime.utc(2026, 11, 13, 6),
      isian: s.salinanLokal(),
    );
    final hp = SimpananDrafLokalMemori();
    await hp.simpan(draf);
    s.dispose();

    return (hp: hp, draf: draf, teks7: teks7, teksSemua: teksSemua);
  }

  Widget app(
    SimpananDrafLokalMemori hp,
    DrafLokal draf, {
    Brightness tema = Brightness.light,
    double skalaHuruf = 1.0,
    MockLembarKerjaService? lembar,
  }) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(
        lembar ?? MockLembarKerjaService(),
      ),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      simpananDrafLokalProvider.overrideWithValue(hp),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      theme: ThemeData(brightness: tema),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(skalaHuruf)),
        child: child!,
      ),
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(authProvider);

          return LembarKerjaScreen(profil: 'ph_meter', drafLokal: draf);
        },
      ),
    ),
  );

  Future<void> pasang(
    WidgetTester tester,
    Widget w, {
    Size ukuran = const Size(1000, 6000),
  }) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    galatRinci = null;
    final lama = FlutterError.onError;
    FlutterError.onError = (d) {
      galatRinci ??= d;
      lama?.call(d);
    };
    addTearDown(() => FlutterError.onError = lama);

    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> keHalamanTerakhir(WidgetTester tester) async {
    final lanjut = find.byIcon(Icons.arrow_forward);
    // Dibatasi: tombol yang tak bisa disentuh harus GAGAL, bukan membuat test
    // berputar selamanya (putaran sinkron tidak pernah kena batas waktu).
    for (var i = 0; i < 4 && lanjut.evaluate().isNotEmpty; i++) {
      await tester.ensureVisible(lanjut);
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
    expect(lanjut, findsNothing, reason: 'sampai di halaman terakhir');
  }

  /// Tombol "Kirim ke admin" di layar: `onPressed == null` = mati.
  bool kirimMati(WidgetTester tester) =>
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Kirim ke admin'),
          )
          .onPressed ==
      null;

  final bilahJumlah = find.byKey(const ValueKey('panel-cek-jumlah'));
  final bilahSelesai = find.byKey(const ValueKey('panel-cek-selesai'));
  final bukaPemeriksa = find.byKey(const ValueKey('cek-buka-pemeriksa'));
  final jumlahDiLembar = find.byKey(const ValueKey('pemeriksa-cek-jumlah'));
  final selesaiDiLembar = find.byKey(const ValueKey('pemeriksa-cek-selesai'));
  final konfirmasi = find.byKey(const ValueKey('cek-konfirmasi-sel'));
  final lompat = find.byKey(const ValueKey('cek-lompat-sel'));
  final lewati = find.byKey(const ValueKey('cek-lewati-sel'));
  final tutup = find.byKey(const ValueKey('cek-tutup-pemeriksa'));

  /// Tidak ada galat tangkapan (mis. RenderFlex meluap); pesannya lengkap supaya
  /// widget penyebabnya kelihatan.
  void tanpaGalat(WidgetTester tester, String langkah) {
    final e = tester.takeException();
    if (e == null) return;

    fail('$langkah: ${galatRinci ?? e}');
  }

  Future<void> bukaLembar(WidgetTester tester) async {
    await tester.tap(bukaPemeriksa);
    await tester.pumpAndSettle();
  }

  testWidgets('3 sel kamera belum dicek: Kirim mati, alasan + jumlah tertulis', (
    tester,
  ) async {
    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);

    expect(find.text('3 isian bacaan kamera belum dicek'), findsOneWidget);
    expect(kirimMati(tester), isTrue);

    // Menyimpan draf tidak ditahan.
    final simpan = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Simpan sebagai draft'),
    );
    expect(simpan.onPressed, isNotNull);

    await bukaLembar(tester);

    // Alasan, tautan lompat, dan konfirmasi per sel ada; "terima semua" tidak.
    expect(find.textContaining('Kirim final ditahan'), findsOneWidget);
    expect(lompat, findsOneWidget);
    expect(konfirmasi, findsOneWidget);
    expect(
      find.textContaining(
        RegExp('terima semua|semua sekaligus|accept all', caseSensitive: false),
      ),
      findsNothing,
    );
  });

  testWidgets('konfirmasi satu per satu: 3 → 2 → 1 → 0, lalu Kirim hidup', (
    tester,
  ) async {
    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);
    await bukaLembar(tester);

    for (final sisa in [2, 1]) {
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(jumlahDiLembar).data,
        '$sisa isian bacaan kamera belum dicek',
        reason: 'satu ketukan = satu sel',
      );
      expect(kirimMati(tester), isTrue);
    }

    await tester.tap(konfirmasi);
    await tester.pumpAndSettle();

    expect(selesaiDiLembar, findsOneWidget);
    expect(konfirmasi, findsNothing);

    await tester.tap(tutup);
    await tester.pumpAndSettle();

    expect(bilahJumlah, findsNothing);
    expect(
      find.text('Semua isian bacaan kamera sudah dicek (3).'),
      findsOneWidget,
    );
    expect(kirimMati(tester), isFalse);
  });

  testWidgets('mengubah angka di sel kamera = sel itu dicek', (tester) async {
    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);

    final sel = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == d.teks7,
    );
    expect(sel, findsOneWidget);

    await tester.enterText(sel, '7.31');
    await tester.pumpAndSettle();

    expect(find.text('2 isian bacaan kamera belum dicek'), findsOneWidget);
    expect(kirimMati(tester), isTrue);
  });

  testWidgets('lewati dulu tidak mengonfirmasi apa pun', (tester) async {
    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);
    await bukaLembar(tester);

    await tester.tap(lewati);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(jumlahDiLembar).data, startsWith('3 isian'));
    expect(kirimMati(tester), isTrue);
  });

  testWidgets('lompat menutup lembar dan tidak mengonfirmasi', (tester) async {
    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);
    await bukaLembar(tester);

    await tester.tap(lompat);
    await tester.pumpAndSettle();

    expect(konfirmasi, findsNothing, reason: 'lembar pemeriksa tertutup');
    expect(find.text('3 isian bacaan kamera belum dicek'), findsOneWidget);
    expect(kirimMati(tester), isTrue);
  });

  testWidgets('tombol Kirim yang basi tidak mengirim apa pun', (tester) async {
    final d = await siapkanDraf();
    final lembar = MockLembarKerjaService();
    await pasang(tester, app(d.hp, d.draf, lembar: lembar));
    await keHalamanTerakhir(tester);

    // Ketiga sel diubah (= dicek): Kirim hidup. Tangkap penangannya.
    for (final (i, asli) in d.teksSemua.indexed) {
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == asli,
        ),
        '9.${i + 1}1',
      );
    }
    await tester.pumpAndSettle();
    expect(kirimMati(tester), isFalse, reason: 'prasyarat: semua dicek');
    final basi = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Kirim ke admin'),
        )
        .onPressed!;

    // Satu sel dikembalikan ke angka mesin: perlu dicek lagi, Kirim mati.
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '9.11',
      ),
      d.teksSemua.first,
    );
    await tester.pumpAndSettle();
    expect(kirimMati(tester), isTrue);

    // Penangan lama (tombol yang sempat hidup) tetap tidak boleh mengirim.
    basi();
    await tester.pumpAndSettle();

    expect(lembar.jumlahKirim, 0);
    expect(
      find.byKey(const ValueKey('dialog-ringkasan-sebelum-kirim')),
      findsOneWidget,
      reason: 'ringkasan menahan sel yang belum dicek',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ringkasan-kirim')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('tanda per sel punya label semantik "Perlu dicek"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    final d = await siapkanDraf();
    await pasang(tester, app(d.hp, d.draf));
    await keHalamanTerakhir(tester);

    expect(find.bySemanticsLabel('Perlu dicek'), findsWidgets);

    // Dilepas DI DALAM test: pemeriksaan akhir test menolak handle yang hidup.
    handle.dispose();
  });

  /// Sesi TANPA bacaan kamera tidak boleh ikut dipotong batas tinggi bilah
  /// bawah: batas itu milik sesi ber-OCR. Bilahnya setinggi isinya, jadi tidak
  /// ada yang perlu digulir (round 1: nol; sempat 10,4 dp di 320 x 568).
  group('sesi tanpa OCR: bilah bawah tidak terpotong', () {
    for (final (nama, ukuran, skala) in [
      ('HP pendek 320 x 568 x huruf 1,3', const Size(320, 568), 1.3),
      ('lanskap 851 x 392', const Size(851, 392), 1.0),
      ('lanskap 851 x 392 x huruf 1,3', const Size(851, 392), 1.3),
    ]) {
      testWidgets(nama, (tester) async {
        final kosong = DrafLokal(
          userId: userId,
          clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a73',
          profil: 'ph_meter',
          equipmentId: alat.id,
          disimpanPada: DateTime.utc(2026, 11, 13, 6),
          isian: const {
            'teks': {'catatan_teknisi': 'diketik tangan'},
          },
        );
        final hp = SimpananDrafLokalMemori();
        await hp.simpan(kosong);

        await pasang(
          tester,
          app(hp, kosong, skalaHuruf: skala),
          ukuran: ukuran,
        );
        await keHalamanTerakhir(tester);

        final gulir = find.descendant(
          of: find.ancestor(
            of: find.text('Simpan sebagai draft'),
            matching: find.byType(SingleChildScrollView),
          ),
          matching: find.byType(Scrollable),
        );
        final posisi = tester.state<ScrollableState>(gulir.first).position;

        expect(
          posisi.maxScrollExtent,
          0,
          reason: 'bilah sesi tanpa OCR harus muat tanpa digulir',
        );
      });
    }
  });

  group('semua keadaan tidak meluap', () {
    for (final (nama, ukuran, skala, tema) in [
      ('HP 392 terang', const Size(392, 850), 1.0, Brightness.light),
      (
        'HP 320 x huruf 1,3 terang',
        const Size(320, 640),
        1.3,
        Brightness.light,
      ),
      (
        'HP pendek 320 x 568 x huruf 1,3',
        const Size(320, 568),
        1.3,
        Brightness.light,
      ),
      ('HP 320 x huruf 1,3 gelap', const Size(320, 640), 1.3, Brightness.dark),
      (
        'tablet 1280 x 800 terang',
        const Size(1280, 800),
        1.0,
        Brightness.light,
      ),
      ('tablet 1280 x 800 gelap', const Size(1280, 800), 1.0, Brightness.dark),
    ]) {
      testWidgets(nama, (tester) async {
        final d = await siapkanDraf();
        await pasang(
          tester,
          app(d.hp, d.draf, tema: tema, skalaHuruf: skala),
          ukuran: ukuran,
        );
        await keHalamanTerakhir(tester);

        // Ada tanda: bilah tahan + tombol pemeriksa 48 dp.
        expect(bilahJumlah, findsOneWidget);
        expect(
          tester.getSize(bukaPemeriksa).height,
          greaterThanOrEqualTo(48),
          reason: 'sasaran sentuh tombol pemeriksa',
        );
        tanpaGalat(tester, 'ada tanda');

        // Lembar pemeriksa: konfirmasi 48 dp, lalu semua dicek.
        await bukaLembar(tester);
        expect(
          tester.getSize(konfirmasi).height,
          greaterThanOrEqualTo(48),
          reason: 'sasaran sentuh konfirmasi',
        );
        tanpaGalat(tester, 'lembar terbuka');

        // Dibatasi: tombol yang tak bisa disentuh harus GAGAL di sini, bukan
        // membuat test berputar selamanya.
        for (var i = 0; i < 3 && konfirmasi.evaluate().isNotEmpty; i++) {
          await tester.tap(konfirmasi);
          await tester.pumpAndSettle();
        }
        expect(selesaiDiLembar, findsOneWidget);
        await tester.tap(tutup);
        await tester.pumpAndSettle();

        expect(bilahSelesai, findsOneWidget);
        tanpaGalat(tester, 'semua dicek');
      });
    }

    testWidgets('tanpa sel kamera: bilah tidak menggambar apa-apa', (
      tester,
    ) async {
      final kosong = DrafLokal(
        userId: userId,
        clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a72',
        profil: 'ph_meter',
        equipmentId: alat.id,
        disimpanPada: DateTime.utc(2026, 11, 13, 6),
        isian: const {
          'teks': {'catatan_teknisi': 'diketik tangan'},
        },
      );
      final hp = SimpananDrafLokalMemori();
      await hp.simpan(kosong);

      await pasang(tester, app(hp, kosong));
      await keHalamanTerakhir(tester);

      expect(bilahJumlah, findsNothing);
      expect(bilahSelesai, findsNothing);
      expect(kirimMati(tester), isFalse);
    });
  });

  test('status sel: tepat tiga keadaan', () {
    expect(StatusCekSel.values, hasLength(3));
  });
}
