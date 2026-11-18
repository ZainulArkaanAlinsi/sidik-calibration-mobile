import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/screens/super_admin/ganti_sandi_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_form_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_screen.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';

import 'support/layar_sa_uji.dart';
import 'support/super_admin_uji.dart';

/// Layar pengelolaan Super Admin di SEMUA ukuran perangkat Android: HP kecil
/// sampai tablet, huruf sistem 1,0/1,3/2,0, terang/gelap, portrait/landscape,
/// papan ketik, area aman, teks sangat panjang, data kosong, daftar besar.
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
    KeadaanSa k, {
    required double lebar,
    required double tinggi,
    required double skalaHuruf,
    bool gelap = false,
  }) async {
    aturLayar(tester, lebar, tinggi);
    await tester.pumpWidget(
      bungkusSa(
        k.layar(),
        lapisan: k.lapisan(),
        skalaHuruf: skalaHuruf,
        gelap: gelap,
      ),
    );
    await selesaikan(tester);
    if (k.sesudah != null) {
      await jalankanSesudah(tester, k);
      await selesaikan(tester);
    }
    if (k.menahan) {
      await tester.pump(const Duration(seconds: 6));
      await selesaikan(tester);
    }
  }

  group('matriks lebar x skala huruf (terang)', () {
    for (final k in layarMatriksSa) {
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
    for (final k in [...layarMatriksSa, ...keadaanLainSa]) {
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
    for (final k in keadaanLainSa) {
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
    for (final k in layarMatriksSa) {
      testWidgets(k.nama, (tester) async {
        await tampilkan(tester, k, lebar: 800, tinggi: 360, skalaHuruf: 1.3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('formulir tambah: tombol Buat akun bisa digulir ke layar', (
      tester,
    ) async {
      aturLayar(tester, 800, 360);
      await tester.pumpWidget(
        bungkusSa(const PenggunaFormScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);
      final tombol = find.text('Buat akun');
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
    for (final k in layarMatriksSa) {
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
          bungkusSa(k.layar(), lapisan: k.lapisan(), skalaHuruf: 1.3),
        );
        await selesaikan(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Pengguna: tombol Tambah di atas bilah gestur, bukan di bawahnya',
      (tester) async {
        aturLayar(tester, 392, 852);
        tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(bungkusSa(const PenggunaScreen()));
        await selesaikan(tester);

        final tombol = tester.getRect(find.text('Tambah pengguna'));
        expect(tombol.bottom, lessThanOrEqualTo(852 - 34));
      },
    );
  });

  group('papan ketik terbuka', () {
    Future<void> bukaKeyboard(
      WidgetTester tester,
      double tinggiKeyboard,
    ) async {
      tester.view.viewInsets = FakeViewPadding(bottom: tinggiKeyboard);
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('Ganti sandi: kolom aktif tidak tertutup papan ketik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(bungkusSa(const GantiSandiScreen()));
      await selesaikan(tester);

      final kolom = find.byType(TextField).last;
      await tester.showKeyboard(kolom);
      await tester.pumpAndSettle();
      final kotak = tester.getRect(kolom);
      expect(kotak.bottom, lessThanOrEqualTo(740 - 300 + 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Formulir pengguna: tombol bisa digulir di atas papan ketik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(
        bungkusSa(const PenggunaFormScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);

      await tester.scrollUntilVisible(
        find.text('Buat akun'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Buat akun')).bottom,
        lessThanOrEqualTo(740 - 300 + 1),
      );
    });

    testWidgets('Pengguna: tombol Tambah disembunyikan saat mengetik', (
      tester,
    ) async {
      aturLayar(tester, 360, 740);
      await bukaKeyboard(tester, 300);
      await tester.pumpWidget(bungkusSa(const PenggunaScreen()));
      await selesaikan(tester);
      expect(find.text('Tambah pengguna'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog dengan papan ketik: isian & tombol tetap terjangkau', (
      tester,
    ) async {
      aturLayar(tester, 320, 640);
      await bukaKeyboard(tester, 280);
      await tester.pumpWidget(
        bungkusSa(const PenggunaScreen(), skalaHuruf: 1.3),
      );
      await selesaikan(tester);
      // Papan ketik terbuka menyembunyikan tombol Tambah, tapi ⋮ tetap ada.
      await ketukDi(tester, find.byKey(const Key('menu-21')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nonaktifkan akun'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('isian-dialog')), findsOneWidget);
      expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('teks sangat panjang dan data kosong', () {
    testWidgets('kartu pengguna: nama/email panjang dipangkas, bukan meluap', (
      tester,
    ) async {
      aturLayar(tester, 320, 800);
      await tester.pumpWidget(
        bungkusSa(
          const PenggunaScreen(),
          lapisan: LapisanUjiSa(
            pengguna: MockPenggunaSaService(awal: penggunaBurukSa),
          ),
          skalaHuruf: 1.3,
        ),
      );
      await selesaikan(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(namaSangatPanjang), findsWidgets);
      // Teks DI DALAM kartu tidak melewati lebar layar (deretan chip saringan
      // memang digulir mendatar, jadi tidak ikut diperiksa).
      final teks = find.descendant(
        of: find.byType(Card),
        matching: find.byType(Text),
      );
      for (var i = 0; i < teks.evaluate().length; i++) {
        final r = tester.getRect(teks.at(i));
        expect(r.right, lessThanOrEqualTo(320 + 0.5), reason: 'teks ke-$i');
      }
    });

    testWidgets('akun tanpa departemen/ID pegawai: tampil "Tanpa ID pegawai"', (
      tester,
    ) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(
        bungkusSa(
          const PenggunaScreen(),
          lapisan: LapisanUjiSa(
            pengguna: MockPenggunaSaService(awal: penggunaBurukSa),
          ),
        ),
      );
      await selesaikan(tester);
      expect(find.text('Tanpa ID pegawai'), findsOneWidget);
    });
  });

  group('daftar besar dibangun malas', () {
    testWidgets('500 pengguna (banyak halaman): hanya yang terlihat dibangun', (
      tester,
    ) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(
        bungkusSa(
          const PenggunaScreen(),
          lapisan: LapisanUjiSa(
            pengguna: MockPenggunaSaService(
              awal: penggunaBanyak(500),
              ukuranHalaman: 500,
            ),
          ),
        ),
      );
      await selesaikan(tester);

      expect(find.byType(Card).evaluate().length, lessThan(30));
      expect(find.text('Pengguna Nomor 0'), findsOneWidget);
      expect(find.text('Pengguna Nomor 499'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(find.text('Pengguna Nomor 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('aksesibilitas', () {
    final layarAksesibel = [for (final k in layarMatriksSa) k];

    for (final k in layarAksesibel) {
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

    testWidgets('Pengguna: ⋮ berlabel nama akun untuk pembaca layar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tampilkan(
        tester,
        layarMatriksSa[1],
        lebar: 392,
        tinggi: 852,
        skalaHuruf: 1.0,
      );
      // Tooltip ⋮ = nama aksesibel tombolnya (TalkBack membacanya).
      expect(find.byTooltip('Aksi untuk Dedi Teknisi'), findsOneWidget);
      handle.dispose();
    });
  });
}
