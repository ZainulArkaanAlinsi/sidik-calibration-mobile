// ToastSidik + tampilkanToast (L2): kartu 22, ubin 40, aksi, tutup, satu
// sekaligus, hilang sendiri (galat dan toast beraksi tidak), usap ke atas,
// kurangi gerak, Semantics, cincin fokus >= 3:1, sasaran 48, 320 dp x huruf 1,3.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan.dart';
import 'package:sidik_calibration/core/theme/token_umpan_balik_biru_awan.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/toast_sidik.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _judul = 'Draf tersimpan';
const _isi = 'Disimpan di HP ini.';

/// Layar dengan satu tombol pemicu yang memanggil [aksi] dengan konteks layar.
Widget _pemicu(void Function(BuildContext) aksi) => Builder(
  builder: (context) => Align(
    alignment: Alignment.bottomCenter,
    child: TextButton(
      key: const ValueKey('pemicu'),
      onPressed: () => aksi(context),
      child: const Text('pemicu'),
    ),
  ),
);

Future<void> _tampil(
  WidgetTester tester, {
  JenisToast jenis = JenisToast.sukses,
  String judul = _judul,
  String? isi = _isi,
  String? aksi,
  VoidCallback? onAksi,
  bool gelap = false,
  double skala = 1.0,
  double lebar = 392,
  bool kurangi = false,
}) async {
  layarUji(tester, lebar: lebar, tinggi: 852);
  Widget app = aplikasiUji(
    _pemicu(
      (c) => tampilkanToast(
        c,
        jenis: jenis,
        judul: judul,
        isi: isi,
        aksi: aksi,
        onAksi: onAksi,
      ),
    ),
    gelap: gelap,
    skala: skala,
    bergulir: false,
  );
  if (kurangi) app = kurangiGerak(app);
  await tester.pumpWidget(app);
  await tester.tap(find.byKey(const ValueKey('pemicu')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get _kartu => find.byType(ToastSidik);
Finder get _tutup => find.byType(TombolTutupSidik);

/// Opasitas FadeTransition terdekat di atas kartu (bukan transisi rute).
double _opasitas(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(ToastSidik),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  setUpAll(muatFontUji);

  group('kartu: ukuran, bentuk, token', () {
    testWidgets('lebar layar - 32, 16 dp dari atas, radius 22, ubin 40/14', (
      tester,
    ) async {
      await _tampil(tester, jenis: JenisToast.sukses);
      final r = tester.getRect(_kartu);
      expect(r.left, 16);
      expect(r.top, 16, reason: '16 dp di bawah status bar (di uji: 0)');
      expect(r.width, 392 - 32);
      // Tombol tutup memaksa sasaran 48: 12 + 48 + 12.
      expect(r.height, 72);
      expect(
        r.height,
        greaterThanOrEqualTo(UkuranUmpanBalikBiruAwan.toastTinggiMin),
      );

      final dekor = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(dekor.borderRadius, BorderRadius.circular(22));
      expect(dekor.color, bahan(tester).kertas);
      final bayangan = dekor.boxShadow!.single;
      expect(bayangan.offset, const Offset(0, 12));
      expect(bayangan.blurRadius, 30);
      expect(bayangan.color.a, closeTo(0.16, 0.005));

      final ubin = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius == BorderRadius.circular(14));
      expect(ubin.color, warna(tester).isi(IsiBiruAwan.hijau));
      final ubinUkuran = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.check_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(ubinUkuran, const Size(40, 40));
    });

    testWidgets('lebar maksimum 420 di layar lebar', (tester) async {
      await _tampil(tester, lebar: 800);
      expect(tester.getSize(_kartu).width, 420);
    });

    testWidgets('judul 15/800 tinta, isi 13/18 tinta kedua', (tester) async {
      await _tampil(tester);
      final judul = tester.widget<Text>(find.text(_judul)).style!;
      expect(judul.fontSize, 15);
      expect(judul.fontWeight, FontWeight.w800);
      expect(judul.color, bahan(tester).tinta);
      final isi = tester.widget<Text>(find.text(_isi)).style!;
      expect(isi.fontSize, 13);
      expect(isi.height, closeTo(18 / 13, 0.001));
      expect(isi.color, bahan(tester).tinta2);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('empat jenis: isi ubin dan ikon ($nama)', (tester) async {
        final peta = {
          JenisToast.sukses: (Icons.check_rounded, IsiBiruAwan.hijau),
          JenisToast.info: (Icons.info_outline_rounded, IsiBiruAwan.kabut),
          JenisToast.peringatan: (
            Icons.warning_amber_rounded,
            IsiBiruAwan.kuning,
          ),
          JenisToast.galat: (Icons.close_rounded, IsiBiruAwan.koral),
        };
        for (final e in peta.entries) {
          await _tampil(tester, jenis: e.key, gelap: gelap);
          final w = warna(tester);
          final ubin = find.ancestor(
            of: find.descendant(of: _kartu, matching: find.byIcon(e.value.$1)),
            matching: find.byType(DecoratedBox),
          );
          expect(
            (tester.widget<DecoratedBox>(ubin.first).decoration
                    as BoxDecoration)
                .color,
            w.isi(e.value.$2),
            reason: '${e.key} ($nama)',
          );
          final ikon = tester.widget<Icon>(
            find
                .descendant(of: _kartu, matching: find.byIcon(e.value.$1))
                .first,
          );
          expect(ikon.color, w.tinta(e.value.$2));
          expect(
            rasioKontras(w.tinta(e.value.$2), w.isi(e.value.$2)),
            greaterThanOrEqualTo(4.5),
            reason: 'ikon/${e.key} ($nama)',
          );
          tutupToastSidik();
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
    }
  });

  group('waktu: hilang sendiri, galat dan beraksi tidak', () {
    test('lamaTampil: 4 dtk, peringatan 6 dtk, galat dan beraksi null', () {
      expect(
        ToastSidik.lamaTampil(JenisToast.sukses, beraksi: false),
        const Duration(seconds: 4),
      );
      expect(
        ToastSidik.lamaTampil(JenisToast.info, beraksi: false),
        const Duration(seconds: 4),
      );
      expect(
        ToastSidik.lamaTampil(JenisToast.peringatan, beraksi: false),
        const Duration(seconds: 6),
      );
      expect(ToastSidik.lamaTampil(JenisToast.galat, beraksi: false), isNull);
      for (final j in JenisToast.values) {
        expect(
          ToastSidik.lamaTampil(j, beraksi: true),
          isNull,
          reason: '$j beraksi',
        );
      }
    });

    testWidgets('sukses hilang sendiri tepat setelah 4 detik', (tester) async {
      await _tampil(tester); // 300 ms berlalu sejak pemicu
      await tester.pump(const Duration(milliseconds: 3500)); // 3,8 s
      expect(find.text(_judul), findsOneWidget);
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // 4,1 s: mulai keluar
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_judul), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('peringatan: masih ada di 5,8 dtk, hilang setelah 6 dtk', (
      tester,
    ) async {
      await _tampil(tester, jenis: JenisToast.peringatan);
      await tester.pump(const Duration(milliseconds: 5500)); // 5,8 s
      expect(find.text(_judul), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600)); // 6,4 s
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_judul), findsNothing);
    });

    testWidgets('galat TIDAK hilang sendiri (sampai 5 menit)', (tester) async {
      await _tampil(tester, jenis: JenisToast.galat);
      await tester.pump(const Duration(minutes: 5));
      expect(find.text(_judul), findsOneWidget);
    });

    for (final jenis in [JenisToast.sukses, JenisToast.info]) {
      testWidgets('$jenis beraksi TIDAK hilang sendiri', (tester) async {
        await _tampil(tester, jenis: jenis, aksi: 'Lihat', onAksi: () {});
        await tester.pump(const Duration(minutes: 5));
        expect(find.text(_judul), findsOneWidget);
        expect(find.text('Lihat'), findsOneWidget);
      });
    }

    testWidgets('kurangi gerak: tanpa animasi, hilang tepat di 4 detik', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(
        kurangiGerak(
          aplikasiUji(
            _pemicu(
              (c) => tampilkanToast(c, jenis: JenisToast.sukses, judul: _judul),
            ),
            bergulir: false,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pemicu')));
      await tester.pump(); // SATU frame: sudah di tempat akhir, penuh
      expect(_opasitas(tester), 1.0);
      expect(tester.getRect(_kartu).top, 16);
      await tester.pump(const Duration(milliseconds: 3900)); // 3,9 s
      expect(find.text(_judul), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200)); // 4,1 s
      await tester.pump();
      expect(find.text(_judul), findsNothing);
    });
  });

  group('gerak masuk', () {
    testWidgets('geser turun dan pudar 240 ms; selesai di 300 ms', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          _pemicu(
            (c) => tampilkanToast(c, jenis: JenisToast.sukses, judul: _judul),
          ),
          bergulir: false,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pemicu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final awal = _opasitas(tester);
      expect(awal, inInclusiveRange(0.01, 0.99));
      final atasAwal = tester.getRect(_kartu).top;
      await tester.pump(const Duration(milliseconds: 240));
      expect(_opasitas(tester), 1.0);
      expect(tester.getRect(_kartu).top, greaterThan(atasAwal));
      expect(tester.getRect(_kartu).top, 16);
    });
  });

  group('satu toast sekaligus dan menutup', () {
    testWidgets('yang baru menggantikan yang lama', (tester) async {
      layarUji(tester);
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          _pemicu(
            (c) => tampilkanToast(
              c,
              jenis: JenisToast.galat,
              judul: 'Toast ${++n}',
            ),
          ),
          bergulir: false,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('pemicu')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(_kartu, findsOneWidget, reason: 'setelah toast ke-${i + 1}');
      }
      expect(find.text('Toast 3'), findsOneWidget);
      expect(find.text('Toast 1'), findsNothing);
      expect(find.text('Toast 2'), findsNothing);
    });

    testWidgets('tombol tutup menutup (keluar 160 ms)', (tester) async {
      await _tampil(tester, jenis: JenisToast.galat);
      await tester.tap(_tutup);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_kartu, findsOneWidget, reason: 'masih keluar');
      await tester.pump(const Duration(milliseconds: 120));
      expect(_kartu, findsNothing);
    });

    testWidgets('ketuk di tepi sasaran 48 (di luar gambar 40) juga menutup', (
      tester,
    ) async {
      await _tampil(tester, jenis: JenisToast.galat);
      final sasaran = tester.getRect(_tutup);
      expect(sasaran.size, const Size(48, 48));
      await tester.tapAt(sasaran.centerLeft + const Offset(1.5, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_kartu, findsNothing);
    });

    testWidgets('usap ke atas menutup galat; usap ke bawah tidak', (
      tester,
    ) async {
      await _tampil(tester, jenis: JenisToast.galat);
      await tester.fling(_kartu, const Offset(0, 200), 1500);
      await tester.pumpAndSettle();
      expect(_kartu, findsOneWidget, reason: 'ke bawah diabaikan');
      await tester.fling(_kartu, const Offset(0, -200), 1500);
      await tester.pumpAndSettle();
      expect(_kartu, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aksi dipanggil sekali lalu toast menutup', (tester) async {
      var n = 0;
      await _tampil(
        tester,
        jenis: JenisToast.galat,
        aksi: 'Coba lagi',
        onAksi: () => n++,
      );
      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(n, 1);
      expect(_kartu, findsNothing);
    });

    testWidgets('overlay hilang bersama pohon: tanpa timer atau galat', (
      tester,
    ) async {
      await _tampil(tester); // timer 4 dtk berjalan
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
      // Pemanggilan berikutnya tidak menyentuh entri basi.
      tutupToastSidik();
    });
  });

  group('pembaca layar', () {
    testWidgets(
      'satu simpul "jenis. judul. isi", tombol berlabel, tanpa duplikat',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _tampil(
          tester,
          jenis: JenisToast.galat,
          aksi: 'Coba lagi',
          onAksi: () {},
        );
        final label = find.bySemanticsLabel('Galat. $_judul. $_isi');
        expect(label, findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(_judul)), findsOneWidget);
        final teks = tester.getSemantics(label).getSemanticsData();
        expect(teks.flagsCollection.isButton, isFalse);

        for (final nama in ['Tutup', 'Coba lagi']) {
          final tombol = tester
              .getSemantics(find.bySemanticsLabel(nama))
              .getSemanticsData();
          expect(tombol.flagsCollection.isButton, isTrue, reason: nama);
          expect(tombol.hasAction(SemanticsAction.tap), isTrue, reason: nama);
          expect(semantikAktif(tombol), isTrue, reason: nama);
        }
        handle.dispose();
      },
    );

    testWidgets('pedoman: sasaran >= 48 dan tiap sasaran berlabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _tampil(
        tester,
        jenis: JenisToast.info,
        aksi: 'Lihat',
        onAksi: () {},
      );
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });

    testWidgets('diumumkan lewat SemanticsService (judul dan isi)', (
      tester,
    ) async {
      final pesan = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            m,
          ) async {
            pesan.add(m as Map<Object?, Object?>);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await _tampil(tester);
      final umumkan = pesan.where((m) => m['type'] == 'announce').toList();
      expect(umumkan, hasLength(1));
      expect((umumkan.single['data'] as Map)['message'], '$_judul. $_isi');
    });
  });

  group('cincin fokus di luar gambar, kontras >= 3:1', () {
    Future<void> fokuskan(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        if (find.byKey(kunciCincinFokusUmpanBalik).evaluate().isNotEmpty) {
          return;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
    }

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('tombol tutup: geometri dan kontras ($nama)', (tester) async {
        await _tampil(tester, jenis: JenisToast.galat, gelap: gelap);
        expect(find.byKey(kunciCincinFokusUmpanBalik), findsNothing);
        await fokuskan(tester);
        final cincinFinder = find.byKey(kunciCincinFokusUmpanBalik);
        expect(cincinFinder, findsOneWidget);
        final cincin = tester.getRect(cincinFinder);
        final sasaran = tester.getRect(_tutup);
        final gambar = tester.getRect(find.byIcon(Icons.close_rounded).last);
        expect(cincin.center, gambar.center);
        expect(
          cincin.deflate(AppUkuran.garisTebal).size,
          const Size(40, 40) +
              const Offset(
                2 * UkuranKomponenBiruAwan.jarakCincinFokus,
                2 * UkuranKomponenBiruAwan.jarakCincinFokus,
              ),
          reason: 'sisi dalam cincin 2 dp di luar gambar 40',
        );
        expect(
          sasaran.inflate(0.01).contains(cincin.topLeft) &&
              sasaran.inflate(0.01).contains(cincin.bottomRight),
          isTrue,
          reason: 'cincin di dalam sasaran 48: tidak terpotong',
        );
        final bentuk =
            (tester
                            .widget<DecoratedBox>(
                              find.descendant(
                                of: cincinFinder,
                                matching: find.byType(DecoratedBox),
                              ),
                            )
                            .decoration
                        as ShapeDecoration)
                    .shape
                as OutlinedBorder;
        expect(bentuk.side.width, AppUkuran.garisTebal);
        expect(bentuk.side.color, bahan(tester).tinta);
        expect(
          rasioKontras(bentuk.side.color, bahan(tester).kertas),
          greaterThanOrEqualTo(ambangBukanTeks),
          reason: 'cincin/kartu ($nama)',
        );
        expect(
          tester.getSize(_kartu).height,
          72,
          reason: 'tanpa pengaruh tata letak',
        );
      });

      testWidgets('kabar navy: cincin lawan latar navy ($nama)', (
        tester,
      ) async {
        layarUji(tester);
        await tester.pumpWidget(
          aplikasiUji(
            Align(
              alignment: Alignment.topCenter,
              child: ToastSidik(
                jenis: JenisToast.kabar,
                judul: 'Lembar kerja baru masuk',
                isi: '1 lembar kerja baru',
                aksi: 'Buka',
                onAksi: () {},
                onTutup: () {},
              ),
            ),
            gelap: gelap,
            bergulir: false,
          ),
        );
        await fokuskan(tester);
        final cincinFinder = find.byKey(kunciCincinFokusUmpanBalik);
        expect(cincinFinder, findsOneWidget);
        final u = WarnaUmpanBalikBiruAwan.of(
          tester.element(find.byType(Scaffold)),
        );
        final bentuk =
            (tester
                            .widget<DecoratedBox>(
                              find.descendant(
                                of: cincinFinder,
                                matching: find.byType(DecoratedBox),
                              ),
                            )
                            .decoration
                        as ShapeDecoration)
                    .shape
                as OutlinedBorder;
        expect(
          rasioKontras(bentuk.side.color, u.kabarLatar),
          greaterThanOrEqualTo(ambangBukanTeks),
          reason: 'cincin/kartu kabar ($nama)',
        );
      });
    }

    testWidgets('Enter pada tombol tutup berfokus menutup toast', (
      tester,
    ) async {
      await _tampil(tester, jenis: JenisToast.galat);
      await fokuskan(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_kartu, findsNothing);
    });

    testWidgets('mati: tanpa cincin dan tak bisa ditekan', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          const Align(
            alignment: Alignment.topLeft,
            child: TombolTutupSidik(label: 'Tutup', onPressed: null),
          ),
          bergulir: false,
        ),
      );
      final handle = tester.ensureSemantics();
      final data = tester
          .getSemantics(find.bySemanticsLabel('Tutup'))
          .getSemanticsData();
      expect(semantikAktif(data), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byKey(kunciCincinFokusUmpanBalik), findsNothing);
      handle.dispose();
    });
  });

  group('kabar masuk (navy)', () {
    testWidgets('latar navy, ubin putih berlogo, teks terbalik, ketuk kartu', (
      tester,
    ) async {
      var ketuk = 0;
      var tutup = 0;
      var buka = 0;
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(
          Align(
            alignment: Alignment.topCenter,
            child: ToastSidik(
              jenis: JenisToast.kabar,
              judul: 'Lembar kerja baru masuk',
              isi: '1 lembar kerja baru masuk antrean approval',
              aksi: 'Buka',
              onAksi: () => buka++,
              onTutup: () => tutup++,
              onKetuk: () => ketuk++,
            ),
          ),
          bergulir: false,
        ),
      );
      final u = WarnaUmpanBalikBiruAwan.of(
        tester.element(find.byType(Scaffold)),
      );
      final kotak = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _kartu, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>();
      expect(kotak.first.color, u.kabarLatar);
      expect(kotak.first.color, bahan(tester).tinta, reason: 'navy di terang');
      expect(kotak.any((d) => d.color == u.kabarUbin), isTrue);
      expect(
        tester.widget<Text>(find.text('Lembar kerja baru masuk')).style!.color,
        u.kabarTeks,
      );
      expect(
        tester
            .widget<Text>(
              find.text('1 lembar kerja baru masuk antrean approval'),
            )
            .style!
            .color,
        u.kabarTeksKedua,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(
        rasioKontras(u.kabarTeksKedua, u.kabarLatar),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        rasioKontras(u.kabarAksiTinta, u.kabarAksiIsi),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(find.text('Lembar kerja baru masuk'));
      expect((ketuk, buka, tutup), (1, 0, 0), reason: 'ketuk teks = kartu');
      await tester.tap(find.text('Buka'));
      expect((ketuk, buka, tutup), (1, 1, 0), reason: 'aksi menang');
      await tester.tap(_tutup);
      expect((ketuk, buka, tutup), (1, 1, 1), reason: 'tutup menang');
    });
  });

  group('huruf 1,3 pada 320 dp: tanpa luapan, aksi pindah ke bawah', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('toast beraksi dengan teks panjang ($nama)', (tester) async {
        await _tampil(
          tester,
          jenis: JenisToast.galat,
          judul: 'Gagal mengirim lembar kerja ke server',
          isi:
              'Server menolak lembar kerja ini karena dua sel wajib belum '
              'terisi dan satu standar acuan sudah lewat jadwal. Periksa lalu '
              'kirim ulang.',
          aksi: 'Coba lagi',
          onAksi: () {},
          gelap: gelap,
          skala: 1.3,
          lebar: 320,
        );
        expect(tester.takeException(), isNull);
        final kartu = tester.getRect(_kartu);
        expect(kartu.left, greaterThanOrEqualTo(0));
        expect(kartu.right, lessThanOrEqualTo(320));
        expect(kartu.height, lessThanOrEqualTo(852 * 0.5));
        final pil = tester.getRect(find.byType(PilAksiSidik));
        final judul = tester.getRect(
          find.text('Gagal mengirim lembar kerja ke server'),
        );
        expect(
          pil.top,
          greaterThanOrEqualTo(judul.bottom),
          reason: 'aksi di bawah teks',
        );
        expect(pil.width, greaterThanOrEqualTo(48));
        expect(pil.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets(
      'teks sangat panjang: kartu dibatasi setengah layar dan bergulir',
      (tester) async {
        await _tampil(
          tester,
          jenis: JenisToast.galat,
          isi: List.filled(120, 'kalimat panjang dari server').join(' '),
          skala: 1.3,
          lebar: 320,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_kartu).height, lessThanOrEqualTo(852 * 0.5));
      },
    );

    testWidgets('layar lebar tanpa huruf besar: aksi sebaris dengan teks', (
      tester,
    ) async {
      await _tampil(
        tester,
        jenis: JenisToast.info,
        aksi: 'Lihat',
        onAksi: () {},
      );
      final pil = tester.getRect(find.byType(PilAksiSidik));
      final judul = tester.getRect(find.text(_judul));
      expect(
        pil.top,
        lessThan(judul.bottom),
        reason: 'sebaris, bukan di bawah',
      );
    });
  });
}
