// Dock dan laci shell Biru Awan (L6): `FloatingNavBar` + `MainShell`.
//
// Yang dikunci di sini (bukan yang sudah dikunci `adaptive_shell_test` dan
// `menu_per_peran_test`):
//  - tiap butir dock punya nama pembaca layar, tombol, urutan "Tab n dari m",
//    dan keadaan terpilih yang BENAR-BENAR terbaca (semantik, ikon, isi pil);
//  - dock admin 5 butir / teknisi 2 butir + Mulai di tengah, ukuran sasaran
//    >= 48 (52 / 48 / 60), ketuk di seluruh area butir;
//  - kurangi gerak mematikan animasi pil; skala huruf 1,3 pada lebar 320
//    tanpa luapan (terang dan gelap); cincin fokus papan ketik;
//  - laci untuk empat peran (teknisi tanpa laci): isi dan urutan persis
//    dari switch `peran`, kepala, lencana, terpilih, tutup, sasaran >= 48.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/dashboard_summary.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/navigation_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/screens/calibration/category_picker_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';

import '../support/lewati_onboarding.dart';
import '../support/uji_biru_awan.dart';

// ───────────────────────────── dock, berdiri sendiri ─────────────────────────

const _itemAdmin = <FloatingNavItem>[
  FloatingNavItem(
    icon: Icons.space_dashboard_outlined,
    activeIcon: Icons.space_dashboard,
    label: 'Dashboard',
  ),
  FloatingNavItem(
    icon: Icons.straighten_outlined,
    activeIcon: Icons.straighten,
    label: 'Alat',
  ),
  FloatingNavItem(
    icon: Icons.history_outlined,
    activeIcon: Icons.history,
    label: 'Riwayat',
  ),
  FloatingNavItem(
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder,
    label: 'Arsip',
  ),
  FloatingNavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profil',
  ),
];

const _itemTeknisi = <FloatingNavItem>[
  FloatingNavItem(
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    label: 'Kalibrasi',
  ),
  FloatingNavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profil',
  ),
];

Widget _mulai(VoidCallback onTap) => TombolBulat(
  key: const ValueKey('dock-mulai'),
  ikon: Icons.add,
  label: 'Mulai kalibrasi',
  ukuran: UkuranTombolBulat.mulai,
  ragam: RagamTombolBulat.primer,
  onPressed: onTap,
);

Widget _dockAdmin({int terpilih = 0, ValueChanged<int>? onSelected}) =>
    FloatingNavBar(
      selectedIndex: terpilih,
      onSelected: onSelected ?? (_) {},
      items: _itemAdmin,
    );

Widget _dockTeknisi({
  int terpilih = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onMulai,
}) => FloatingNavBar(
  selectedIndex: terpilih,
  onSelected: onSelected ?? (_) {},
  items: _itemTeknisi,
  ragam: RagamDock.teknisi,
  aksiTengah: _mulai(onMulai ?? () {}),
);

Future<void> _pasang(
  WidgetTester tester,
  Widget dock, {
  double lebar = 390,
  double skala = 1.0,
  bool gelap = false,
  bool kurangi = false,
}) async {
  layarUji(tester, lebar: lebar, tinggi: 640);
  await tester.pumpWidget(
    aplikasiUji(
      kurangi ? kurangiGerak(dock) : dock,
      gelap: gelap,
      skala: skala,
      bergulir: false,
      rataBawah: true,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _butir(int i) => find.byKey(ValueKey('dock-butir-$i'));

SemanticsData _semantik(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

SidikMaterial _m(WidgetTester tester) =>
    SidikMaterial.of(tester.element(find.byType(FloatingNavBar)));

Icon _ikon(WidgetTester tester, int i) => tester.widget<Icon>(
  find.descendant(of: _butir(i), matching: find.byType(Icon)),
);

/// Isi pil yang SEDANG tergambar (bukan target animasi): kotak berhias di dalam
/// `AnimatedContainer` butir.
Color? _isiPil(WidgetTester tester, int i) {
  final kotak = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.descendant(
            of: _butir(i),
            matching: find.byType(AnimatedContainer),
          ),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (kotak.decoration as ShapeDecoration).color;
}

int _jumlahOpacity(WidgetTester tester, int i) => find
    .descendant(of: _butir(i), matching: find.byType(Opacity))
    .evaluate()
    .length;

void main() {
  setUpAll(muatFontUji);

  group('dock admin (A1): lima butir 48', () {
    testWidgets('tiap butir bernama, tombol, "Tab n dari 5", satu terpilih', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, _dockAdmin(terpilih: 2));

      for (var i = 0; i < _itemAdmin.length; i++) {
        final d = _semantik(tester, _butir(i));
        expect(d.label, _itemAdmin[i].label, reason: 'nama butir $i');
        expect(d.hint, 'Tab ${i + 1} dari 5', reason: 'petunjuk butir $i');
        expect(d.flagsCollection.isButton, isTrue, reason: 'butir $i');
        expect(d.hasAction(SemanticsAction.tap), isTrue, reason: 'butir $i');
        expect(
          d.flagsCollection.isSelected,
          i == 2 ? Tristate.isTrue : Tristate.isFalse,
          reason: 'terpilih butir $i',
        );
      }
      semantik.dispose();
    });

    testWidgets('terpilih vs tidak: ikon, warna ikon, dan isi pil', (
      tester,
    ) async {
      await _pasang(tester, _dockAdmin(terpilih: 1));
      final m = _m(tester);

      for (var i = 0; i < _itemAdmin.length; i++) {
        final aktif = i == 1;
        final ikon = _ikon(tester, i);
        expect(
          ikon.icon,
          aktif ? _itemAdmin[i].activeIcon : _itemAdmin[i].icon,
          reason: 'ikon butir $i',
        );
        expect(
          ikon.color,
          aktif ? m.biruTinta : m.tinta2,
          reason: 'warna ikon butir $i',
        );
        expect(
          _isiPil(tester, i),
          aktif ? m.biruTipis : Colors.transparent,
          reason: 'isi pil butir $i',
        );
      }
    });

    testWidgets('label tampak hanya di butir aktif; butir lain tersembunyi', (
      tester,
    ) async {
      await _pasang(tester, _dockAdmin(terpilih: 0));
      final m = _m(tester);

      // Aktif: teks label 14/800 biruTinta, tanpa penyamar Opacity.
      final aktif = tester.widget<Text>(
        find.descendant(of: _butir(0), matching: find.text('Dashboard')),
      );
      expect(aktif.style?.fontSize, 14);
      expect(aktif.style?.fontWeight, FontWeight.w800);
      expect(aktif.style?.color, m.biruTinta);
      expect(_jumlahOpacity(tester, 0), 0);

      // Lain: ada teks (untuk pencarian tes lama) tetapi Opacity 0.
      for (var i = 1; i < _itemAdmin.length; i++) {
        final gaib = tester.widgetList<Opacity>(
          find.descendant(of: _butir(i), matching: find.byType(Opacity)),
        );
        expect(gaib.length, 1, reason: 'butir $i');
        expect(gaib.single.opacity, 0, reason: 'butir $i');
        expect(
          find.descendant(
            of: _butir(i),
            matching: find.text(_itemAdmin[i].label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('ketuk butir memanggil onSelected dengan indeksnya', (
      tester,
    ) async {
      final dipilih = <int>[];
      await _pasang(tester, _dockAdmin(onSelected: dipilih.add));

      for (var i = _itemAdmin.length - 1; i >= 0; i--) {
        await tester.tap(_butir(i));
      }
      expect(dipilih, [4, 3, 2, 1, 0]);

      // Teks label (dipakai tes lama) juga mengetuk butirnya.
      dipilih.clear();
      await tester.tap(find.text('Alat'));
      await tester.tap(find.text('Profil'));
      expect(dipilih, [1, 4]);
    });

    testWidgets('ketuk di seluruh area butir: tepi kiri/kanan pil dan bulat', (
      tester,
    ) async {
      final dipilih = <int>[];
      await _pasang(tester, _dockAdmin(onSelected: dipilih.add));

      final pil = tester.getRect(_butir(0));
      expect(pil.width, greaterThan(48), reason: 'pil aktif memuat label');
      await tester.tapAt(pil.centerLeft + const Offset(10, 0));
      await tester.tapAt(pil.centerRight - const Offset(10, 0));
      expect(dipilih, [0, 0]);

      final bulat = tester.getRect(_butir(3));
      dipilih.clear();
      await tester.tapAt(bulat.center + const Offset(-14, 0));
      await tester.tapAt(bulat.center + const Offset(14, 0));
      await tester.tapAt(bulat.center + const Offset(0, -14));
      await tester.tapAt(bulat.center + const Offset(0, 14));
      expect(dipilih, [3, 3, 3, 3]);
    });

    testWidgets('sasaran sentuh: tinggi tepat 48, lebar >= 48; pedoman Flutter', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, _dockAdmin(terpilih: 2));

      for (var i = 0; i < _itemAdmin.length; i++) {
        final u = tester.getSize(_butir(i));
        expect(u.height, 48, reason: 'tinggi butir $i');
        expect(u.width, greaterThanOrEqualTo(48), reason: 'lebar butir $i');
      }
      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });

    testWidgets('dock putih bersudut 40, melayang 16 dp di atas tepi layar', (
      tester,
    ) async {
      await _pasang(tester, _dockAdmin());
      final m = _m(tester);

      final kotak = tester.widget<DecoratedBox>(
        find
            .ancestor(of: _butir(0), matching: find.byType(DecoratedBox))
            .last,
      );
      final hias = kotak.decoration as BoxDecoration;
      expect(hias.color, m.kertas);
      expect(hias.borderRadius, BorderRadius.circular(40));
      expect(hias.boxShadow, isNotEmpty);

      final dock = tester.getRect(find.byType(FloatingNavBar));
      final isi = tester.getRect(_butir(0));
      expect(
        dock.bottom - isi.bottom,
        greaterThanOrEqualTo(16),
        reason: 'jarak ke tepi bawah >= 16 (bantalan dock + jarak melayang)',
      );
    });
  });

  group('dock teknisi (01): dua butir 52 + Mulai 60 di tengah', () {
    testWidgets('urutan Kalibrasi, Mulai, Profil; tiap satu bernama', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await _pasang(tester, _dockTeknisi(onMulai: () => n++));

      final kal = tester.getRect(_butir(0));
      final mulai = tester.getRect(find.byKey(const ValueKey('dock-mulai')));
      final profil = tester.getRect(_butir(1));
      expect(kal.right, lessThan(mulai.left));
      expect(mulai.right, lessThan(profil.left));
      expect(mulai.size, const Size(60, 60));
      expect(kal.height, 52);
      expect(profil.size, const Size(52, 52));

      expect(_semantik(tester, _butir(0)).label, 'Kalibrasi');
      expect(_semantik(tester, _butir(1)).label, 'Profil');
      expect(_semantik(tester, _butir(0)).hint, 'Tab 1 dari 2');
      final dm = _semantik(
        tester,
        find.byKey(const ValueKey('dock-mulai')),
      );
      expect(dm.label, 'Mulai kalibrasi');
      expect(dm.flagsCollection.isButton, isTrue);

      await tester.tap(find.byKey(const ValueKey('dock-mulai')));
      expect(n, 1);
      semantik.dispose();
    });

    testWidgets('Mulai: primer, ikon putih, bayangan primer; bukan butir tab', (
      tester,
    ) async {
      await _pasang(tester, _dockTeknisi());
      final s = Theme.of(
        tester.element(find.byKey(const ValueKey('dock-mulai'))),
      ).colorScheme;
      final bulat = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('dock-mulai')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(bulat.color, s.primary);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dock-mulai')),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      // Mulai bukan tab: butir tab hanya dua.
      expect(find.byKey(const ValueKey('dock-butir-2')), findsNothing);
    });

    testWidgets('Profil terpilih: pil pindah ke Profil, Kalibrasi jadi bulat', (
      tester,
    ) async {
      await _pasang(tester, _dockTeknisi(terpilih: 1));
      final m = _m(tester);
      expect(_isiPil(tester, 1), m.biruTipis);
      expect(_isiPil(tester, 0), Colors.transparent);
      expect(_ikon(tester, 1).icon, Icons.person);
      expect(_ikon(tester, 0).icon, Icons.assignment_outlined);
      expect(_jumlahOpacity(tester, 1), 0, reason: 'label Profil tampak');
      expect(_jumlahOpacity(tester, 0), 1, reason: 'label Kalibrasi gaib');
    });

    testWidgets('pedoman sentuh Flutter: semua >= 48 dan berlabel', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, _dockTeknisi());
      await periksaPedomanSentuh(tester);
      semantik.dispose();
    });
  });

  group('dock: kurangi gerak', () {
    Future<void> beralih(WidgetTester tester, {required bool kurangi}) async {
      var terpilih = 0;
      late StateSetter ubah;
      layarUji(tester, lebar: 390, tinggi: 640);
      final dock = StatefulBuilder(
        builder: (context, set) {
          ubah = set;
          return _dockAdmin(terpilih: terpilih);
        },
      );
      await tester.pumpWidget(
        aplikasiUji(
          kurangi ? kurangiGerak(dock) : dock,
          bergulir: false,
          rataBawah: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final m = _m(tester);

      ubah(() => terpilih = 3);
      await tester.pump(); // bingkai pertama, 0 ms
      await tester.pump(const Duration(milliseconds: 30));
      final tengah = _isiPil(tester, 3);
      if (kurangi) {
        expect(tengah, m.biruTipis, reason: 'kurangi gerak: langsung final');
      } else {
        expect(
          tengah,
          isNot(m.biruTipis),
          reason: 'tanpa kurangi gerak pil masih beralih (animasi 120 ms)',
        );
      }
      await tester.pumpAndSettle();
      expect(_isiPil(tester, 3), m.biruTipis);
      expect(_isiPil(tester, 0), Colors.transparent);
    }

    testWidgets('menyala: pil berpindah seketika', (tester) async {
      await beralih(tester, kurangi: true);
    });

    testWidgets('mati: pil beralih lewat animasi pendek yang selesai', (
      tester,
    ) async {
      await beralih(tester, kurangi: false);
    });
  });

  group('dock: skala huruf 1,3 pada lebar 320, terang dan gelap', () {
    for (final gelap in [false, true]) {
      for (final terpilih in [0, 4]) {
        testWidgets(
          'admin terpilih $terpilih, ${gelap ? 'gelap' : 'terang'}: tanpa luapan',
          (tester) async {
            final semantik = tester.ensureSemantics();
            await _pasang(
              tester,
              _dockAdmin(terpilih: terpilih),
              lebar: 320,
              skala: 1.3,
              gelap: gelap,
            );
            expect(tester.takeException(), isNull);
            for (var i = 0; i < _itemAdmin.length; i++) {
              final r = tester.getRect(_butir(i));
              expect(r.height, 48, reason: 'butir $i');
              expect(r.width, greaterThanOrEqualTo(48), reason: 'butir $i');
              expect(r.left, greaterThanOrEqualTo(0), reason: 'butir $i');
              expect(r.right, lessThanOrEqualTo(320), reason: 'butir $i');
              // Label boleh dibuang di lebar sempit; namanya tidak.
              expect(
                _semantik(tester, _butir(i)).label,
                _itemAdmin[i].label,
              );
            }
            await periksaPedomanSentuh(tester);
            semantik.dispose();
          },
        );
      }

      testWidgets(
        'teknisi, ${gelap ? 'gelap' : 'terang'}: tanpa luapan, sasaran >= 52',
        (tester) async {
          await _pasang(
            tester,
            _dockTeknisi(),
            lebar: 320,
            skala: 1.3,
            gelap: gelap,
          );
          expect(tester.takeException(), isNull);
          expect(tester.getSize(_butir(0)).height, 52);
          expect(tester.getSize(_butir(1)).width, greaterThanOrEqualTo(52));
          final mulai = tester.getRect(
            find.byKey(const ValueKey('dock-mulai')),
          );
          expect(mulai.right, lessThanOrEqualTo(320));
        },
      );
    }

    testWidgets('lebar 390 skala 1: label butir aktif tampak penuh (admin)', (
      tester,
    ) async {
      await _pasang(tester, _dockAdmin());
      expect(_jumlahOpacity(tester, 0), 0);
      expect(tester.getSize(_butir(0)).width, greaterThan(100));
    });

    testWidgets('label yang tak muat dikecilkan atau dibuang, tidak meluap', (
      tester,
    ) async {
      // Lebar 320, huruf 1,3: label "Dashboard" tidak muat; dock tetap utuh.
      await _pasang(tester, _dockAdmin(), lebar: 320, skala: 1.3);
      expect(tester.takeException(), isNull);
      final dock = tester.getRect(
        find
            .ancestor(of: _butir(0), matching: find.byType(DecoratedBox))
            .last,
      );
      expect(dock.right, lessThanOrEqualTo(320 - 16 + 0.5));
      expect(dock.left, greaterThanOrEqualTo(16 - 0.5));
    });
  });

  group('dock: papan ketik dan kontras', () {
    testWidgets('Tab memindahkan cincin fokus di LUAR butir, kontras >= 3:1', (
      tester,
    ) async {
      await _pasang(tester, _dockAdmin());
      final m = _m(tester);

      Finder cincin(int i) => find.descendant(
        of: _butir(i),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is ShapeDecoration &&
              (w.decoration as ShapeDecoration).shape is StadiumBorder &&
              ((w.decoration as ShapeDecoration).shape as StadiumBorder)
                      .side
                      .width ==
                  2,
        ),
      );

      expect(cincin(0), findsNothing, reason: 'tanpa fokus tidak ada cincin');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(cincin(0), findsOneWidget);
      expect(cincin(1), findsNothing);

      final cincinRect = tester.getRect(cincin(0));
      final butirRect = tester.getRect(_butir(0));
      expect(cincinRect.left, lessThan(butirRect.left));
      expect(cincinRect.right, greaterThan(butirRect.right));
      expect(cincinRect.top, lessThan(butirRect.top));
      expect(cincinRect.bottom, greaterThan(butirRect.bottom));

      final garis =
          ((tester.widget<DecoratedBox>(cincin(0)).decoration
                      as ShapeDecoration)
                  .shape
              as StadiumBorder)
              .side
              .color;
      expect(garis, m.tinta);
      expect(rasioKontras(garis, m.kertas), greaterThanOrEqualTo(3));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(cincin(0), findsNothing);
      expect(cincin(1), findsOneWidget);

      // Enter pada butir terfokus memilihnya.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    });

    for (final gelap in [false, true]) {
      testWidgets('kontras ikon dan label (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        await _pasang(tester, _dockAdmin(), gelap: gelap);
        final m = _m(tester);
        final aktif = _ikon(tester, 0).color!;
        final lain = _ikon(tester, 1).color!;
        expect(
          rasioKontras(aktif, _isiPil(tester, 0)!),
          greaterThanOrEqualTo(4.5),
          reason: 'ikon/label aktif di pil kabut',
        );
        expect(
          rasioKontras(lain, m.kertas),
          greaterThanOrEqualTo(4.5),
          reason: 'ikon butir lain di dock',
        );
      });
    }
  });

  // ──────────────────────────── shell sungguhan ────────────────────────────

  final l10n = l10nUji();

  group('MainShell: dock per peran', () {
    testWidgets('teknisi: dua butir + Mulai; tanpa laci', (tester) async {
      await _bukaShell(tester, 'mock-token-2');

      final dock = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
      expect(dock.ragam, RagamDock.teknisi);
      expect(dock.items.map((i) => i.label), [
        l10n.navKalibrasi,
        l10n.navProfile,
      ]);
      expect(dock.aksiTengah, isNotNull);
      expect(find.byKey(const ValueKey('dock-mulai')), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      bukaMenuUtama();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('Mulai membuka alur Mulai kalibrasi yang sudah ada', (
      tester,
    ) async {
      await _bukaShell(tester, 'mock-token-2');

      await tester.tap(find.byKey(const ValueKey('dock-mulai')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CategoryPickerScreen), findsOneWidget);
    });

    for (final (token, nama) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super admin'),
      ('mock-token-3', 'viewer'),
    ]) {
      testWidgets('$nama: lima butir bernama, tanpa tombol Mulai', (
        tester,
      ) async {
        final semantik = tester.ensureSemantics();
        await _bukaShell(tester, token);

        final dock = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
        expect(dock.ragam, RagamDock.admin);
        expect(dock.aksiTengah, isNull);
        expect(dock.items.map((i) => i.label), [
          l10n.navDashboard,
          l10n.navEquipment,
          l10n.navHistory,
          l10n.profArsip,
          l10n.navProfile,
        ]);
        expect(find.byKey(const ValueKey('dock-mulai')), findsNothing);
        for (var i = 0; i < 5; i++) {
          expect(
            _semantik(tester, _butir(i)).label,
            dock.items[i].label,
            reason: 'nama butir $i',
          );
        }
        semantik.dispose();
      });
    }

    // Dock setinggi isinya. Pernah salah: `Center` tanpa `heightFactor` di
    // dalam `bottomNavigationBar` mengisi SELURUH tinggi layar dan badan tab
    // menjadi setinggi nol (menjatuhkan tes Profil, Alat, dan lainnya).
    for (final (token, nama, tertinggi) in [
      ('mock-token-1', 'admin', 110.0),
      ('mock-token-2', 'teknisi', 122.0),
    ]) {
      testWidgets('$nama: dock tidak menelan badan layar (800 x 600)', (
        tester,
      ) async {
        await _bukaShell(tester, token, lebar: 800, tinggi: 600);

        final dock = tester.getSize(find.byType(FloatingNavBar)).height;
        expect(dock, greaterThan(70));
        expect(dock, lessThanOrEqualTo(tertinggi));
        final badan = tester.getSize(find.byType(IndexedStack)).height;
        expect(badan, greaterThan(600 - tertinggi - 60));
      });
    }

    testWidgets('ketuk Alat di dock pindah tab dan menggeser pil', (
      tester,
    ) async {
      await _bukaShell(tester, 'mock-token-1');
      final m = _m(tester);

      expect(_isiPil(tester, 0), m.biruTipis);
      await tester.tap(find.text(l10n.navEquipment).first);
      await tester.pumpAndSettle();
      expect(_isiPil(tester, 1), m.biruTipis);
      expect(_isiPil(tester, 0), Colors.transparent);
    });

    testWidgets('kurangi gerak sistem: pil pindah pada bingkai berikutnya', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _bukaShell(tester, 'mock-token-1');
      final m = _m(tester);

      await tester.tap(find.text(l10n.navEquipment).first);
      await tester.pump();
      await tester.pump();
      expect(_isiPil(tester, 1), m.biruTipis);
    });
  });

  group('MainShell: laci menu per peran (A3)', () {
    final semuaJudul = <String>{
      l10n.navDashboard,
      l10n.antreanTitle,
      l10n.alurTitle,
      l10n.penugasanJudul,
      l10n.penugasanTugasSaya,
      l10n.telusuriJudul,
      l10n.drafTitle,
      l10n.navHistory,
      l10n.navEquipment,
      l10n.jadwalJudul,
      l10n.profArsip,
      l10n.navNotifications,
      l10n.kelolaJudul,
      l10n.navProfile,
    };

    // Persis switch `peran` di `_MenuUtama` (urutan juga).
    final adminDanSuper = <String>[
      l10n.navDashboard,
      l10n.antreanTitle,
      l10n.alurTitle,
      l10n.penugasanJudul,
      l10n.telusuriJudul,
      l10n.drafTitle,
      l10n.navHistory,
      l10n.navEquipment,
      l10n.jadwalJudul,
      l10n.profArsip,
      l10n.navNotifications,
      l10n.kelolaJudul,
      l10n.navProfile,
    ];
    final viewer = <String>[
      l10n.navDashboard,
      l10n.navHistory,
      l10n.navEquipment,
      l10n.telusuriJudul,
      l10n.profArsip,
      l10n.navNotifications,
      l10n.navProfile,
    ];

    Finder judulLaci(String t) =>
        find.descendant(of: find.byType(Drawer), matching: find.text(t));

    List<String> butirLaci(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Drawer), matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .where(semuaJudul.contains)
        .toList();

    List<String> seksiLaci(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Drawer), matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .where(
          {
            l10n.menuKerjaHarian,
            l10n.menuArsip,
            l10n.menuPengaturan,
          }.contains,
        )
        .toList();

    testWidgets('admin: 13 butir, tiga seksi, urutan dari switch peran', (
      tester,
    ) async {
      await _bukaLaci(tester, 'mock-token-1');
      expect(butirLaci(tester), adminDanSuper);
      expect(seksiLaci(tester), [
        l10n.menuKerjaHarian,
        l10n.menuArsip,
        l10n.menuPengaturan,
      ]);
      // Admin tidak mendapat kalimat catatan super admin/viewer.
      expect(find.text(l10n.menuCatatanSuperAdmin), findsNothing);
      expect(find.text(l10n.menuCatatanViewer), findsNothing);
      expect(find.text(l10n.penugasanTugasSaya), findsNothing);
    });

    testWidgets('super admin: sama dengan admin + kalimat catatannya', (
      tester,
    ) async {
      await _bukaLaci(tester, 'mock-token-5');
      expect(butirLaci(tester), adminDanSuper);
      expect(seksiLaci(tester), [
        l10n.menuKerjaHarian,
        l10n.menuArsip,
        l10n.menuPengaturan,
      ]);
      expect(find.text(l10n.menuCatatanSuperAdmin), findsOneWidget);
      expect(find.text(l10n.menuCatatanViewer), findsNothing);
    });

    testWidgets('viewer: hanya baca (tujuh butir) + kalimat viewer', (
      tester,
    ) async {
      await _bukaLaci(tester, 'mock-token-3');
      expect(butirLaci(tester), viewer);
      expect(seksiLaci(tester), [l10n.menuArsip]);
      expect(find.text(l10n.menuCatatanViewer), findsOneWidget);
      expect(find.text(l10n.menuCatatanSuperAdmin), findsNothing);
      for (final terlarang in [
        l10n.antreanTitle,
        l10n.penugasanJudul,
        l10n.drafTitle,
        l10n.kelolaJudul,
        l10n.jadwalJudul,
      ]) {
        expect(find.text(terlarang), findsNothing, reason: terlarang);
      }
    });

    testWidgets('teknisi: tidak ada laci sama sekali (dua tab sudah semua)', (
      tester,
    ) async {
      await _bukaShell(tester, 'mock-token-2');
      bukaMenuUtama();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('kepala: avatar inisial, nama, stempel peran, tombol tutup', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(tester, 'mock-token-1');

      final laci = find.byType(Drawer);
      expect(
        find.descendant(of: laci, matching: find.text('BS')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: laci, matching: find.text('Budi Santoso')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: laci, matching: find.text('Admin')),
        findsOneWidget,
      );
      final tutup = find.byKey(const ValueKey('laci-tutup'));
      final d = _semantik(tester, tutup);
      expect(d.label, l10n.shellTutupMenu);
      expect(d.flagsCollection.isButton, isTrue);
      expect(tester.getSize(tutup).shortestSide, greaterThanOrEqualTo(48));

      await tester.tap(tutup);
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      semantik.dispose();
    });

    testWidgets('panel 320, sudut kanan 32, putih; latar redup navy 42 %', (
      tester,
    ) async {
      await _bukaLaci(tester, 'mock-token-1');
      final m = _m(tester);

      expect(tester.getSize(find.byType(Drawer)).width, 320);
      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, m.kertas);
      expect(
        (drawer.shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(32)),
      );
      final scaffold = tester.widget<Scaffold>(find.byKey(mainShellKey));
      expect(scaffold.drawerScrimColor, m.tinta.withValues(alpha: 0.42));
    });

    testWidgets('terpilih: tab aktif = pil kabut + biruTinta 800; lain tidak', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(tester, 'mock-token-1');
      final m = _m(tester);

      TextStyle? gaya(String judul) =>
          tester.widget<Text>(judulLaci(judul)).style;

      // Tab aktif = 0 (Dashboard).
      expect(gaya(l10n.navDashboard)?.color, m.biruTinta);
      expect(gaya(l10n.navDashboard)?.fontWeight, FontWeight.w800);
      expect(gaya(l10n.navEquipment)?.color, m.tinta);
      expect(gaya(l10n.navEquipment)?.fontWeight, FontWeight.w600);

      Material pilDi(String judul) => tester.widget<Material>(
        find.ancestor(of: judulLaci(judul), matching: find.byType(Material)).first,
      );
      expect(pilDi(l10n.navDashboard).color, m.biruTipis);
      expect(pilDi(l10n.navEquipment).color, Colors.transparent);

      final aktif = _semantik(tester, judulLaci(l10n.navDashboard));
      expect(aktif.flagsCollection.isSelected, Tristate.isTrue);
      final lain = _semantik(tester, judulLaci(l10n.navEquipment));
      expect(lain.flagsCollection.isSelected, Tristate.isFalse);

      // Pilih Alat dari laci: laci menutup, tab pindah, penanda ikut pindah.
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text(l10n.navEquipment),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      bukaMenuUtama();
      await tester.pumpAndSettle();
      expect(gaya(l10n.navEquipment)?.color, m.biruTinta);
      expect(gaya(l10n.navDashboard)?.color, m.tinta);
      semantik.dispose();
    });

    testWidgets('lencana koral: Antrean, Draf, Jadwal, Notifikasi', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(tester, 'mock-token-1');
      final w = WarnaBiruAwan.of(tester.element(find.byType(Drawer)));

      Finder judul(String t) =>
          find.descendant(of: find.byType(Drawer), matching: find.text(t));
      final harapan = {
        l10n.antreanTitle: 4,
        l10n.drafTitle: 3,
        l10n.jadwalJudul: 6,
        l10n.navNotifications: 12,
      };
      for (final e in harapan.entries) {
        // Pembaca layar: satu butir "judul, jumlah".
        expect(
          find.bySemanticsLabel(l10n.biruAwanChipJumlah(e.key, e.value)),
          findsOneWidget,
          reason: e.key,
        );
        // Tampak: pil koral berisi angka di baris yang sama.
        final baris = find.ancestor(
          of: judul(e.key),
          matching: find.byType(InkWell),
        );
        final angka = find.descendant(
          of: baris,
          matching: find.text('${e.value}'),
        );
        expect(angka, findsOneWidget, reason: e.key);
        final pil = tester.widget<DecoratedBox>(
          find.ancestor(of: angka, matching: find.byType(DecoratedBox)).first,
        );
        expect(
          (pil.decoration as ShapeDecoration).color,
          w.isi(IsiBiruAwan.koral),
        );
      }
      // Butir tanpa angka: hanya judul (tanpa pil angka) dan label polos.
      final riwayat = find.ancestor(
        of: judul(l10n.navHistory),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: riwayat, matching: find.byType(Text)),
        findsOneWidget,
        reason: 'Riwayat tanpa lencana',
      );
      semantik.dispose();
    });

    testWidgets('angka nol dan lebih dari 99 tidak menampilkan "0"/angka liar', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(
        tester,
        'mock-token-1',
        ringkasan: _Hitung(antrean: 0, draf: 0, jadwal: 0),
        belumDibaca: 150,
      );
      expect(find.bySemanticsLabel(l10n.antreanTitle), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('0')),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(Drawer), matching: find.text('99+')),
        findsOneWidget,
      );
      semantik.dispose();
    });

    testWidgets('sasaran sentuh: tiap butir laci >= 48 dan seluruh baris ' 'diketuk', (
      tester,
    ) async {
      await _bukaLaci(tester, 'mock-token-1');
      final baris = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(InkWell),
      );
      expect(baris.evaluate().length, greaterThanOrEqualTo(13));
      var butir = 0;
      for (final e in baris.evaluate()) {
        // Tombol bulat tutup menggambar 44 di dalam sasaran 48 (diperiksa di
        // tes kepala); yang dihitung di sini hanya butir menu.
        var dalamTombol = false;
        e.visitAncestorElements((a) {
          if (a.widget is TombolBulat) dalamTombol = true;
          return !dalamTombol;
        });
        if (dalamTombol) continue;
        butir++;
        final u = (e.renderObject! as RenderBox).size;
        expect(u.height, greaterThanOrEqualTo(48));
      }
      expect(butir, 13);

      // Ketuk tepi kiri baris "Alat" (di atas ikon, bukan di atas teks).
      final alat = find.ancestor(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.text(l10n.navEquipment),
        ),
        matching: find.byType(InkWell),
      );
      final r = tester.getRect(alat);
      await tester.tapAt(r.centerLeft + const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      final konteks = tester.element(find.byType(FloatingNavBar));
      expect(
        ProviderScope.containerOf(konteks).read(selectedTabProvider),
        1,
      );
    });

    for (final (token, nama) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super admin'),
      ('mock-token-3', 'viewer'),
    ]) {
      testWidgets('$nama: 320 dp x huruf 1,3 tanpa luapan di laci dan dock', (
        tester,
      ) async {
        await _bukaLaci(
          tester,
          token,
          lebar: 320,
          tinggi: 900,
          skala: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(Drawer)).width, lessThanOrEqualTo(320));
        await tester.tap(find.byKey(const ValueKey('laci-tutup')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kurangi gerak: laci terbuka dan menutup tanpa gerak berulang', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _bukaLaci(tester, 'mock-token-1');
      expect(find.byType(Drawer), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('laci-tutup')));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
    });
  });
}

// ───────────────────────────── bantuan shell sungguhan ───────────────────────

/// Ringkasan dashboard dengan angka tetap supaya lencana laci bisa dicocokkan.
class _Hitung extends MockDashboardService {
  _Hitung({this.antrean = 4, this.draf = 3, this.jadwal = 6})
    : super(jeda: Duration.zero);

  final int antrean;
  final int draf;
  final int jadwal;

  @override
  Future<DashboardSummary> ambilRingkasan(String token) async =>
      DashboardSummary.fromJson({
        'total_alat': 42,
        'alat_overdue': jadwal,
        'kalibrasi_draft': draf,
        'kalibrasi_selesai': 2,
        'menunggu_approval': antrean,
        'sertifikat_bulan_ini': 12,
        'total_sertifikat': 137,
        'grafik_pekerjaan': <Map<String, dynamic>>[],
      });
}

class _Notif extends MockNotificationService {
  _Notif(this.jumlah) : super(jeda: Duration.zero);

  final int jumlah;

  @override
  Future<int> jumlahBelumDibaca(String token) async => jumlah;
}

Widget _app(
  String token, {
  DashboardService? ringkasan,
  int belumDibaca = 12,
}) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      pakaiPanelDesktopProvider.overrideWithValue(false),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(ringkasan ?? _Hitung()),
      notificationServiceProvider.overrideWithValue(_Notif(belumDibaca)),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
      izinServiceProvider.overrideWithValue(MockIzinService()),
      pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
      penugasanServiceProvider.overrideWithValue(MockPenugasanService()),
    ],
    child: const SidikApp(),
  );
}

Future<void> _bukaShell(
  WidgetTester tester,
  String token, {
  double lebar = 400,
  double tinggi = 1400,
  double skala = 1.0,
  DashboardService? ringkasan,
  int belumDibaca = 12,
}) async {
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  if (skala != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = skala;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    _app(token, ringkasan: ringkasan, belumDibaca: belumDibaca),
  );
  // MockAuthService punya jeda 600 ms; pumpAndSettle tidak memajukan timer.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _bukaLaci(
  WidgetTester tester,
  String token, {
  double lebar = 400,
  double tinggi = 1400,
  double skala = 1.0,
  _Hitung? ringkasan,
  int belumDibaca = 12,
}) async {
  await _bukaShell(
    tester,
    token,
    lebar: lebar,
    tinggi: tinggi,
    skala: skala,
    ringkasan: ringkasan,
    belumDibaca: belumDibaca,
  );
  bukaMenuUtama();
  await tester.pumpAndSettle();
  expect(find.byType(Drawer), findsOneWidget);
}
