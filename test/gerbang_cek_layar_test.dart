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
import 'package:sidik_calibration/screens/calibration/widgets/tanda_cek_sel.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Sel hasil kamera di LAYAR lembar kerja SESUDAH gerbang "wajib dicek" dicabut
/// (keputusan pemilik 27 Nov 2026): sel kamera tetap berwarna kuning ("Perlu
/// dicek") sampai teknisi mengubah angkanya, tetapi TIDAK menahan Kirim. Tidak
/// ada lagi panel jumlah, lembar pemeriksa, tombol konfirmasi/lompat/lewati,
/// maupun pesan "Kirim final ditahan"; Simpan draft tetap bebas; dan tetap
/// tidak ada tombol "terima semua".
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

  // Sisa kunci gerbang lama. Semuanya harus HILANG dari layar (lihat
  // [tanpaGerbang]); yang tersisa hanya lencana kuning di selnya.
  final bilahJumlah = find.byKey(const ValueKey('panel-cek-jumlah'));
  final bilahSelesai = find.byKey(const ValueKey('panel-cek-selesai'));
  final bilahTahan = find.byKey(const ValueKey('panel-cek-tahan'));
  final bukaPemeriksa = find.byKey(const ValueKey('cek-buka-pemeriksa'));
  final jumlahDiLembar = find.byKey(const ValueKey('pemeriksa-cek-jumlah'));
  final selesaiDiLembar = find.byKey(const ValueKey('pemeriksa-cek-selesai'));
  final konfirmasi = find.byKey(const ValueKey('cek-konfirmasi-sel'));
  final lompat = find.byKey(const ValueKey('cek-lompat-sel'));
  final lewati = find.byKey(const ValueKey('cek-lewati-sel'));
  final tutup = find.byKey(const ValueKey('cek-tutup-pemeriksa'));

  /// Lencana kuning "Perlu dicek" yang masih menempel di sel hasil kamera.
  final kuning = find.byWidgetPredicate(
    (w) => w is TandaCekSel && w.status == StatusCekSel.perluCek,
  );

  /// Gerbang lama sudah tidak ada: tidak ada panel jumlah, lembar pemeriksa,
  /// tombol konfirmasi/lompat/lewati, pesan "ditahan", maupun "terima semua".
  void tanpaGerbang() {
    for (final f in [
      bilahJumlah,
      bilahSelesai,
      bilahTahan,
      bukaPemeriksa,
      jumlahDiLembar,
      selesaiDiLembar,
      konfirmasi,
      lompat,
      lewati,
      tutup,
    ]) {
      expect(f, findsNothing);
    }
    expect(find.textContaining('isian bacaan kamera'), findsNothing);
    expect(find.textContaining('Kirim final ditahan'), findsNothing);
    expect(
      find.textContaining(
        RegExp('terima semua|semua sekaligus|accept all', caseSensitive: false),
      ),
      findsNothing,
    );
  }

  /// Tidak ada galat tangkapan (mis. RenderFlex meluap); pesannya lengkap supaya
  /// widget penyebabnya kelihatan.
  void tanpaGalat(WidgetTester tester, String langkah) {
    final e = tester.takeException();
    if (e == null) return;

    fail('$langkah: ${galatRinci ?? e}');
  }

  /// Kotak teks yang isinya [teks] (sel hasil foto, dicari lewat isinya).
  Finder kotakBerisi(String teks) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == teks,
  );

  /// Menggulir daftar lembar sampai kotak berisi [teks] terbangun dan kelihatan
  /// (ListView hanya membangun yang dekat layar; di HP pendek sel terbawah
  /// belum ada di pohon widget).
  Future<void> tampilkan(WidgetTester tester, String teks) async {
    final sel = kotakBerisi(teks);
    if (sel.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        sel,
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(sel);
    await tester.pumpAndSettle();
  }

  testWidgets(
    '3 sel kamera belum diubah: Kirim HIDUP, tidak ada panel gerbang, sel tetap kuning',
    (tester) async {
      final d = await siapkanDraf();
      await pasang(tester, app(d.hp, d.draf));
      await keHalamanTerakhir(tester);

      // Sel kamera tetap ditandai "Perlu dicek", tetapi tidak menahan apa pun.
      expect(kuning, findsNWidgets(3));
      expect(kirimMati(tester), isFalse);
      tanpaGerbang();

      // Menyimpan draf tetap bebas.
      final simpan = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Simpan sebagai draft'),
      );
      expect(simpan.onPressed, isNotNull);
    },
  );

  testWidgets(
    'mengubah angka satu per satu: kuning 3 → 2 → 1 → 0, Kirim hidup di setiap langkah',
    (tester) async {
      final d = await siapkanDraf();
      await pasang(tester, app(d.hp, d.draf));
      await keHalamanTerakhir(tester);

      expect(kuning, findsNWidgets(3));
      expect(kirimMati(tester), isFalse, reason: 'awal: belum ada yang diubah');

      for (final (i, asli) in d.teksSemua.indexed) {
        await tester.enterText(kotakBerisi(asli), '9.${i + 1}1');
        await tester.pumpAndSettle();

        expect(
          kuning,
          findsNWidgets(2 - i),
          reason: 'satu angka diubah = satu sel lepas dari kuning',
        );
        expect(kirimMati(tester), isFalse);
        tanpaGerbang();
      }
    },
  );

  testWidgets(
    'mengubah angka di sel kamera: kuning sel itu lepas, Kirim hidup',
    (tester) async {
      final d = await siapkanDraf();
      await pasang(tester, app(d.hp, d.draf));
      await keHalamanTerakhir(tester);

      final sel = kotakBerisi(d.teks7);
      expect(sel, findsOneWidget);
      expect(
        find.ancestor(of: sel, matching: kuning),
        findsOneWidget,
        reason: 'sebelum diubah: sel itu kuning',
      );

      await tester.enterText(sel, '7.31');
      await tester.pumpAndSettle();

      expect(
        find.ancestor(of: kotakBerisi('7.31'), matching: kuning),
        findsNothing,
        reason: 'sudah diubah teknisi: bukan kuning lagi',
      );
      expect(kuning, findsNWidgets(2), reason: 'dua sel lain tetap kuning');
      expect(kirimMati(tester), isFalse);
      tanpaGerbang();
    },
  );

  testWidgets(
    'tidak ada jalur "lewati"/"konfirmasi": kuning hanya lepas karena angkanya diubah',
    (tester) async {
      final d = await siapkanDraf();
      await pasang(tester, app(d.hp, d.draf));
      await keHalamanTerakhir(tester);

      // Tidak ada tombol untuk menandai sel "sudah dicek" tanpa mengubah angka:
      // tidak ada pemeriksa, lewati, lompat, konfirmasi, maupun "Sudah saya cek".
      tanpaGerbang();
      expect(find.text('Sudah saya cek'), findsNothing);
      expect(find.text('Sudah saya cek, berikutnya'), findsNothing);

      // Menyentuh sel (fokus) tanpa mengubah isinya tidak melepas kuning.
      await tester.tap(kotakBerisi(d.teks7));
      await tester.pumpAndSettle();
      expect(kuning, findsNWidgets(3));
      expect(kirimMati(tester), isFalse);
    },
  );

  testWidgets(
    'Kirim dengan sel kamera masih kuning: tidak ada yang menahan, sel tidak dikonfirmasi diam-diam',
    (tester) async {
      final d = await siapkanDraf();
      final lembar = MockLembarKerjaService();
      await pasang(tester, app(d.hp, d.draf, lembar: lembar));
      await keHalamanTerakhir(tester);
      expect(kuning, findsNWidgets(3));

      final kirim = find.widgetWithText(FilledButton, 'Kirim ke admin');
      await tester.ensureVisible(kirim);
      await tester.tap(kirim);
      await tester.pumpAndSettle();

      // Ringkasan sebelum kirim memuat kekurangan identitas (peringatan), tetapi
      // sel kamera yang belum dicek TIDAK ada di dalamnya dan tidak menahan:
      // "Tetap kirim" hidup.
      final dialog = find.byKey(
        const ValueKey('dialog-ringkasan-sebelum-kirim'),
      );
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('isian bacaan kamera'),
        ),
        findsNothing,
      );
      final tetapKirim = find.byKey(const ValueKey('ringkasan-kirim'));
      expect(tester.widget<FilledButton>(tetapKirim).onPressed, isNotNull);
      expect(lembar.jumlahKirim, 0, reason: 'belum ada yang terkirim');

      await tester.tap(tetapKirim);
      await tester.pumpAndSettle();

      // Satu konfirmasi angka lagi (rata-rata per titik), lalu berangkat.
      expect(find.text('Cek dulu angkanya sebelum dikirim'), findsOneWidget);
      await tester.tap(find.text('Kirim sekarang'));
      await tester.pumpAndSettle();

      expect(lembar.jumlahKirim, 1);
      // Yang berangkat jujur: ketiga sel kamera tercatat MASIH "perlu dicek"
      // (tidak ada yang dikonfirmasi diam-diam oleh tombol Kirim).
      final cek = lembar.payloadTerakhir!['cek_bacaan'] as Map<String, dynamic>;
      expect(cek['perlu_cek'], hasLength(3));
      expect(cek['sudah_dicek'], isEmpty);
    },
  );

  testWidgets(
    'angka dikembalikan ke angka mesin: kuning lagi, Kirim tetap hidup',
    (tester) async {
      final d = await siapkanDraf();
      final lembar = MockLembarKerjaService();
      await pasang(tester, app(d.hp, d.draf, lembar: lembar));
      await keHalamanTerakhir(tester);

      // Ketiga sel diubah: tidak ada yang kuning, Kirim hidup.
      for (final (i, asli) in d.teksSemua.indexed) {
        await tester.enterText(kotakBerisi(asli), '9.${i + 1}1');
      }
      await tester.pumpAndSettle();
      expect(kuning, findsNothing);
      expect(kirimMati(tester), isFalse);

      // Satu sel dikembalikan ke angka mesin: kuning lagi, tetapi tidak ada
      // lagi yang mematikan Kirim.
      await tester.enterText(kotakBerisi('9.11'), d.teksSemua.first);
      await tester.pumpAndSettle();
      expect(kuning, findsOneWidget);
      expect(kirimMati(tester), isFalse);
      tanpaGerbang();

      // Tidak ada yang terkirim sebelum teknisi sendiri menekan Kirim.
      expect(lembar.jumlahKirim, 0);
    },
  );

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

        // Tidak ada panel gerbang, dan tombol Kirim (sasaran sentuh 48 dp)
        // tidak mati.
        tanpaGerbang();
        final kirim = find.widgetWithText(FilledButton, 'Kirim ke admin');
        expect(
          tester.getSize(kirim).height,
          greaterThanOrEqualTo(48),
          reason: 'sasaran sentuh tombol Kirim',
        );
        expect(kirimMati(tester), isFalse);
        tanpaGalat(tester, 'ada tanda');

        // Tiap sel kamera: kuning sampai teknisi mengubah angkanya. Daftar
        // lembar dibangun malas, jadi selnya digulirkan ke layar satu per satu.
        for (final (i, asli) in d.teksSemua.indexed) {
          await tampilkan(tester, asli);
          expect(
            find.ancestor(of: kotakBerisi(asli), matching: kuning),
            findsOneWidget,
            reason: 'sel kamera tetap kuning sebelum diubah',
          );

          await tester.enterText(kotakBerisi(asli), '9.${i + 1}1');
          await tester.pumpAndSettle();
          expect(
            find.ancestor(of: kotakBerisi('9.${i + 1}1'), matching: kuning),
            findsNothing,
            reason: 'sudah diubah teknisi: bukan kuning lagi',
          );
          expect(kirimMati(tester), isFalse);
        }
        expect(kuning, findsNothing);
        tanpaGerbang();
        tanpaGalat(tester, 'semua diubah');
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
