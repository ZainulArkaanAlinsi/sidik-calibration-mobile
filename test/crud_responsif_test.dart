import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/order.dart';
import 'package:sidik_calibration/screens/crud_lab/order_detail_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_form_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_list_screen.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';

import 'support/crud_uji.dart';
import 'support/layar_crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart'
    show aturLayar, muatFontSa, namaSangatPanjang, selesaikan;

/// Layar CRUD lab di SEMUA ukuran perangkat Android: HP kecil sampai tablet,
/// huruf sistem 1,0/1,3/2,0, terang/gelap, portrait/landscape, papan ketik,
/// area aman, teks sangat panjang, data kosong, daftar besar.
///
/// "Lulus" = tidak ada `RenderFlex overflow` atau galat render lain (di
/// flutter_test galat itu menggagalkan tes). Aplikasi sungguhan menjepit skala
/// huruf ke 1,3× (`batasSkalaHuruf` di app.dart); skala 2,0× diuji TANPA
/// jepitan supaya layar tidak pecah walau jepitannya suatu hari dilonggarkan.
///
/// Ukuran (dp): 320x640 HP kecil · 360x740 · 392x852 · 600x960 tablet kecil ·
/// 840x600 tablet besar/landscape.
void main() {
  setUpAll(muatFontSa);

  const ukuran = <(String, double, double)>[
    ('320', 320, 640),
    ('360', 360, 740),
    ('392', 392, 852),
    ('600', 600, 960),
    ('840', 840, 600),
  ];
  const skala = <double>[1.0, 1.3, 2.0];

  Future<void> tampilkan(
    WidgetTester tester,
    KeadaanCrud k, {
    required double lebar,
    required double tinggi,
    required double skalaHuruf,
    bool gelap = false,
  }) async {
    aturLayar(tester, lebar, tinggi);
    await tester.pumpWidget(
      bungkusCrud(
        k.layar(),
        lapisan: k.lapisan(),
        token: k.token,
        izin: k.izin,
        skalaHuruf: skalaHuruf,
        gelap: gelap,
      ),
    );
    await selesaikan(tester);
    if (k.sesudah != null) {
      await jalankanSesudahCrud(tester, k);
      await selesaikan(tester);
    }
    if (k.menahan) {
      await tester.pump(const Duration(seconds: 6));
      await selesaikan(tester);
    }
  }

  group('matriks lebar x skala huruf (terang)', () {
    for (final k in layarMatriksCrud) {
      for (final (kode, lebar, tinggi) in ukuran) {
        for (final s in skala) {
          testWidgets('${k.nama} @ $kode dp x $s', (tester) async {
            await tampilkan(
              tester,
              k,
              lebar: lebar,
              tinggi: tinggi,
              skalaHuruf: s,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('mode gelap, huruf 1,3×', () {
    for (final k in [...layarMatriksCrud, ...keadaanLainCrud]) {
      for (final (kode, lebar, tinggi) in [ukuran[0], ukuran[2], ukuran[4]]) {
        testWidgets('${k.nama} @ $kode dp gelap', (tester) async {
          await tampilkan(
            tester,
            k,
            lebar: lebar,
            tinggi: tinggi,
            skalaHuruf: 1.3,
            gelap: true,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('kosong, galat, memuat, dialog di kombinasi terburuk', () {
    const kombinasi = <(String, double, double, double)>[
      ('320 x 2,0', 320, 640, 2.0),
      ('320 x 1,3', 320, 640, 1.3),
      ('392 x 1,0', 392, 852, 1.0),
      ('840 x 1,0 landscape', 840, 600, 1.0),
      ('800 x 360 landscape HP, 1,3', 800, 360, 1.3),
    ];
    for (final k in keadaanLainCrud) {
      for (final (nama, lebar, tinggi, s) in kombinasi) {
        testWidgets('${k.nama} @ $nama', (tester) async {
          await tampilkan(
            tester,
            k,
            lebar: lebar,
            tinggi: tinggi,
            skalaHuruf: s,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('landscape HP (800 x 360): tombol aksi tetap terjangkau', () {
    for (final k in layarMatriksCrud) {
      testWidgets(k.nama, (tester) async {
        await tampilkan(tester, k, lebar: 800, tinggi: 360, skalaHuruf: 1.3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('formulir order: tombol Simpan bisa digulir ke layar', (
      tester,
    ) async {
      aturLayar(tester, 800, 360);
      await tester.pumpWidget(
        bungkusCrud(const OrderFormScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);
      final tombol = find.text('Simpan');
      await tester.scrollUntilVisible(
        tombol,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final kotak = tester.getRect(tombol);
      expect(kotak.bottom, lessThanOrEqualTo(360));
      expect(kotak.top, greaterThanOrEqualTo(0));
    });
  });

  group('area aman (notch, bilah gestur)', () {
    for (final k in layarMatriksCrud) {
      testWidgets('${k.nama}: tidak ada luapan dengan inset sistem', (
        tester,
      ) async {
        aturLayar(tester, 392, 852);
        tester.view.padding = const FakeViewPadding(
          top: 48,
          bottom: 34,
          left: 0,
          right: 0,
        );
        tester.view.viewPadding = const FakeViewPadding(
          top: 48,
          bottom: 34,
          left: 0,
          right: 0,
        );
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          bungkusCrud(k.layar(), lapisan: k.lapisan(), skalaHuruf: 1.3),
        );
        await selesaikan(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Order: tombol Buat di atas bilah gestur, bukan di bawahnya',
      (tester) async {
        aturLayar(tester, 392, 852);
        tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(bungkusCrud(const OrderListScreen()));
        await selesaikan(tester);

        final tombol = tester.getRect(find.text('Buat order'));
        expect(tombol.bottom, lessThanOrEqualTo(852 - 34));
      },
    );
  });

  group('papan ketik terbuka', () {
    Future<void> bukaKeyboard(WidgetTester tester, double tinggi) async {
      tester.view.viewInsets = FakeViewPadding(bottom: tinggi);
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('Formulir order: Simpan bisa digulir di atas papan ketik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(
        bungkusCrud(const OrderFormScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);

      await tester.scrollUntilVisible(
        find.text('Simpan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Simpan')).bottom,
        lessThanOrEqualTo(740 - 300 + 1),
      );
    });

    testWidgets('Kolom catatan aktif tidak tertutup papan ketik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(bungkusCrud(const OrderFormScreen()));
      await selesaikan(tester);

      final kolom = find.byKey(const Key('isi-catatan'));
      await ketukDi(tester, kolom);
      await tester.showKeyboard(kolom);
      await tester.pumpAndSettle();
      expect(tester.getRect(kolom).bottom, lessThanOrEqualTo(740 - 300 + 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Daftar order: tombol Buat disembunyikan saat mengetik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(bungkusCrud(const OrderListScreen()));
      await selesaikan(tester);
      expect(find.text('Buat order'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dialog hapus dengan papan ketik: tombol tetap terjangkau', (
      tester,
    ) async {
      aturLayar(tester, 320, 640);
      await bukaKeyboard(tester, 280);
      await tester.pumpWidget(
        bungkusCrud(const OrderListScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);
      await ketukDi(tester, find.byKey(const Key('menu-order-302')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pemilih PT dengan papan ketik: kolom cari dan hasil terlihat', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(bungkusCrud(const OrderFormScreen()));
      await selesaikan(tester);
      await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
      await tester.pumpAndSettle();

      final cari = find.byKey(const Key('cari-sheet'));
      expect(cari, findsOneWidget);
      expect(tester.getRect(cari).bottom, lessThanOrEqualTo(740 - 300));
      expect(find.byKey(const Key('pt-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('teks sangat panjang dan data kosong', () {
    testWidgets('kartu order: nama PT/nomor panjang dipangkas, bukan meluap', (
      tester,
    ) async {
      aturLayar(tester, 320, 800);
      await tester.pumpWidget(
        bungkusCrud(
          const OrderListScreen(),
          lapisan: LapisanUjiCrud(
            order: MockOrderKelolaService(awal: ordersBurukCrud),
          ),
          skalaHuruf: 1.3,
        ),
      );
      await selesaikan(tester);
      expect(tester.takeException(), isNull);

      final teks = find.descendant(
        of: find.byType(Card),
        matching: find.byType(Text),
      );
      for (var i = 0; i < teks.evaluate().length; i++) {
        final r = tester.getRect(teks.at(i));
        expect(r.right, lessThanOrEqualTo(320 + 0.5), reason: 'teks ke-$i');
      }
    });

    testWidgets('order tanpa nama PT: tampil strip, bukan kosong', (
      tester,
    ) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(
        bungkusCrud(
          const OrderListScreen(),
          lapisan: LapisanUjiCrud(
            order: MockOrderKelolaService(awal: ordersBurukCrud),
          ),
        ),
      );
      await selesaikan(tester);
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('detail: catatan, kondisi, dan nama alat panjang tidak meluap', (
      tester,
    ) async {
      aturLayar(tester, 320, 800);
      await tester.pumpWidget(
        bungkusCrud(
          const OrderDetailScreen(orderId: 801),
          lapisan: LapisanUjiCrud(
            order: MockOrderKelolaService(awal: ordersBurukCrud),
          ),
          skalaHuruf: 2.0,
        ),
      );
      await selesaikan(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(namaSangatPanjang), findsWidgets);
    });
  });

  group('daftar besar dibangun malas', () {
    testWidgets('500 order dalam satu halaman: hanya yang terlihat dibangun', (
      tester,
    ) async {
      aturLayar(tester, 392, 852);
      final banyak = [
        for (var i = 0; i < 500; i++)
          OrderKalibrasi(
            id: 2000 + i,
            nomor: 'ORD/2026/12/${i.toString().padLeft(4, '0')}',
            status: 'baru',
            namaPelanggan: 'PT Nomor $i',
            jumlahAlat: 1,
          ),
      ];
      await tester.pumpWidget(
        bungkusCrud(
          const OrderListScreen(),
          lapisan: LapisanUjiCrud(
            order: MockOrderKelolaService(awal: banyak, ukuranHalaman: 500),
          ),
        ),
      );
      await selesaikan(tester);

      expect(find.byType(Card).evaluate().length, lessThan(30));
      expect(find.text('ORD/2026/12/0000'), findsOneWidget);
      expect(find.text('ORD/2026/12/0499'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -30000));
      await tester.pumpAndSettle();
      expect(find.text('ORD/2026/12/0000'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('aksesibilitas', () {
    for (final k in layarMatriksCrud) {
      testWidgets('${k.nama}: target sentuh >= 48 dp dan berlabel', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tampilkan(tester, k, lebar: 392, tinggi: 852, skalaHuruf: 1.0);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('Order: ⋮ berlabel nomor order untuk pembaca layar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(bungkusCrud(const OrderListScreen()));
      await selesaikan(tester);
      expect(
        find.byTooltip('Aksi untuk ORD/2026/11/0003'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
