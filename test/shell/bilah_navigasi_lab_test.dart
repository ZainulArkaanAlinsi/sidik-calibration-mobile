// Bilah navigasi bawah Lab (REVISI 16 Nov 2026, R1): `FloatingNavBar` solid.
//
// Menggantikan grup "dock" lama di `dock_laci_test.dart` (pil melayang dengan
// bayangan, label hanya di butir aktif). Yang dikunci:
//  - permukaan putih selebar layar, garis 1 dp di atas, TANPA bayangan dan
//    sudut; tepi sistem di dalam permukaan;
//  - SEMUA butir berlabel; aktif = kapsul kabut 56 x 32 + ikon terisi + kata
//    semibold navy (tidak hanya warna);
//  - satu simpul pembaca layar per butir (label, tombol, `selected`, "Tab n dari
//    m"); sasaran sentuh >= 48; ketuk di seluruh sel;
//  - teknisi: dua butir + Mulai datar 48 di tengah;
//  - label tidak terpotong di 320 dp x huruf 1,3 (lebar alami paragraf <= sel,
//    satu ukuran untuk semua butir, tidak di bawah 12 sp);
//  - papan ketik terbuka menyembunyikan bilah; kurangi gerak: kapsul seketika;
//    cincin fokus di dalam sel.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';

import '../support/uji_biru_awan.dart';

const _admin = <FloatingNavItem>[
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

const _teknisi = <FloatingNavItem>[
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

Widget _mulai([VoidCallback? onTap]) => TombolBulat(
  key: const ValueKey('dock-mulai'),
  ikon: Icons.add,
  label: 'Mulai kalibrasi',
  ukuran: UkuranTombolBulat.mulai,
  ragam: RagamTombolBulat.primer,
  onPressed: onTap ?? () {},
);

Widget _bilahAdmin({int terpilih = 0, ValueChanged<int>? onSelected}) =>
    FloatingNavBar(
      selectedIndex: terpilih,
      onSelected: onSelected ?? (_) {},
      items: _admin,
    );

Widget _bilahTeknisi({int terpilih = 0, ValueChanged<int>? onSelected}) =>
    FloatingNavBar(
      selectedIndex: terpilih,
      onSelected: onSelected ?? (_) {},
      items: _teknisi,
      aksiTengah: _mulai(),
    );

Future<void> _pasang(
  WidgetTester tester,
  Widget bilah, {
  double lebar = 390,
  double skala = 1.0,
  bool gelap = false,
  bool kurangi = false,
  double tepiSistem = 0,
  double papanKetik = 0,
}) async {
  layarUji(tester, lebar: lebar, tinggi: 640);
  tester.view.viewPadding = FakeViewPadding(bottom: tepiSistem);
  tester.view.padding = FakeViewPadding(bottom: tepiSistem);
  tester.view.viewInsets = FakeViewPadding(bottom: papanKetik);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    aplikasiUji(
      kurangi ? kurangiGerak(bilah) : bilah,
      gelap: gelap,
      skala: skala,
      bergulir: false,
      rataBawah: true,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _butir(int i) => find.byKey(ValueKey('dock-butir-$i'));

SidikMaterial _m(WidgetTester tester) =>
    SidikMaterial.of(tester.element(find.byType(FloatingNavBar)));

SemanticsData _semantik(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

Text _label(WidgetTester tester, int i) => tester.widget<Text>(
  find.descendant(of: _butir(i), matching: find.byType(Text)).first,
);

Icon _ikon(WidgetTester tester, int i) => tester.widget<Icon>(
  find.descendant(of: _butir(i), matching: find.byType(Icon)),
);

/// Isi kapsul yang SEDANG tergambar di butir [i].
Color? _isiKapsul(WidgetTester tester, int i) {
  final kotak = tester.widget<AnimatedContainer>(
    find.descendant(of: _butir(i), matching: find.byType(AnimatedContainer)),
  );
  return (kotak.decoration! as BoxDecoration).color;
}

void main() {
  setUpAll(muatFontUji);

  group('bentuk: solid, selebar layar, garis di atas, tanpa bayangan', () {
    testWidgets(
      'permukaan kertas, garis 1 dp kertasTepi di atas, tanpa sudut',
      (tester) async {
        await _pasang(tester, _bilahAdmin());
        final m = _m(tester);

        final dock = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('dock')),
        );
        final dekor = dock.decoration as BoxDecoration;
        final border = dekor.border! as Border;
        expect(border.top.color, m.kertasTepi);
        expect(border.top.width, 1);
        expect(border.bottom, BorderSide.none);
        expect(dekor.borderRadius, isNull, reason: 'tanpa sudut');
        expect(dekor.boxShadow, isNull, reason: 'tanpa bayangan');

        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('dock')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, m.kertas);
        // Selebar layar, menempel di dasar.
        final rect = tester.getRect(find.byKey(const ValueKey('dock')));
        expect(rect.left, 0);
        expect(rect.right, 390);
        expect(rect.bottom, 640);
      },
    );

    testWidgets('tidak ada bayangan di mana pun di dalam bilah (admin, '
        'teknisi + Mulai)', (tester) async {
      for (final bilah in [_bilahAdmin(), _bilahTeknisi()]) {
        await _pasang(tester, bilah);
        for (final d in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(FloatingNavBar),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final dekor = d.decoration;
          if (dekor is BoxDecoration) {
            expect(dekor.boxShadow, anyOf(isNull, isEmpty));
          }
        }
        for (final mat in tester.widgetList<Material>(
          find.descendant(
            of: find.byType(FloatingNavBar),
            matching: find.byType(Material),
          ),
        )) {
          expect(mat.elevation, 0);
        }
      }
    });

    testWidgets('tepi sistem (gesture bar) di DALAM permukaan: tinggi = 64 + '
        'tepi, tidak ada celah di bawah', (tester) async {
      await _pasang(tester, _bilahAdmin(), tepiSistem: 24);
      final rect = tester.getRect(find.byKey(const ValueKey('dock')));
      expect(rect.height, greaterThanOrEqualTo(64 + 24));
      expect(rect.bottom, 640, reason: 'permukaan sampai tepi layar');
      // Butir tidak menyentuh tepi sistem.
      expect(tester.getRect(_butir(0)).bottom, lessThanOrEqualTo(640 - 24));
    });
  });

  group('label: SEMUA butir bertulisan; aktif tidak hanya beda warna', () {
    testWidgets('lima kata tampak, tidak ada yang disembunyikan', (
      tester,
    ) async {
      await _pasang(tester, _bilahAdmin());
      for (var i = 0; i < _admin.length; i++) {
        expect(
          find.descendant(of: _butir(i), matching: find.text(_admin[i].label)),
          findsOneWidget,
          reason: 'label butir $i',
        );
      }
      expect(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'tidak ada label gaib (Opacity 0) lagi',
      );
    });

    testWidgets('terpilih vs tidak: kapsul kabut, ikon terisi, kata semibold '
        'navy; lain ikon garis, kata medium tinta kedua', (tester) async {
      await _pasang(tester, _bilahAdmin(terpilih: 2));
      final m = _m(tester);

      expect(find.byKey(kunciIndikatorBilah), findsOneWidget);
      expect(
        find.descendant(
          of: _butir(2),
          matching: find.byKey(kunciIndikatorBilah),
        ),
        findsOneWidget,
      );
      for (var i = 0; i < _admin.length; i++) {
        final aktif = i == 2;
        expect(
          _isiKapsul(tester, i),
          aktif ? m.biruTipis : Colors.transparent,
          reason: 'kapsul butir $i',
        );
        expect(
          _ikon(tester, i).icon,
          aktif ? _admin[i].activeIcon : _admin[i].icon,
          reason: 'bentuk ikon butir $i',
        );
        expect(
          _ikon(tester, i).color,
          aktif ? m.biruTinta : m.tinta2,
          reason: 'warna ikon butir $i',
        );
        final gaya = _label(tester, i).style!;
        expect(
          gaya.fontWeight,
          aktif ? FontWeight.w600 : FontWeight.w500,
          reason: 'berat kata butir $i',
        );
        expect(
          gaya.color,
          aktif ? m.tinta : m.tinta2,
          reason: 'warna kata butir $i',
        );
      }
      // Kapsul 56 x 32.
      final kapsul = tester.getSize(find.byKey(kunciIndikatorBilah));
      expect(kapsul, const Size(56, 32));
    });
  });

  group('semantik dan sasaran sentuh', () {
    testWidgets('tiap butir bernama, tombol, "Tab n dari 5", satu terpilih', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, _bilahAdmin(terpilih: 1));
      final l10n = l10nUji();

      var terpilih = 0;
      for (var i = 0; i < _admin.length; i++) {
        final d = _semantik(tester, _butir(i));
        expect(d.label, _admin[i].label, reason: 'nama butir $i');
        expect(d.hint, l10n.navLabTabHint(i + 1, 5), reason: 'posisi butir $i');
        expect(d.flagsCollection.isButton, isTrue, reason: 'tombol $i');
        if (d.flagsCollection.isSelected == Tristate.isTrue) terpilih++;
        expect(
          d.flagsCollection.isSelected == Tristate.isTrue,
          i == 1,
          reason: 'selected butir $i',
        );
      }
      expect(terpilih, 1);
      semantik.dispose();
    });

    testWidgets('ketuk di seluruh sel memanggil onSelected dengan indeksnya', (
      tester,
    ) async {
      final dipilih = <int>[];
      await _pasang(tester, _bilahAdmin(onSelected: dipilih.add));

      for (var i = 0; i < _admin.length; i++) {
        final r = tester.getRect(_butir(i));
        // Tengah, tepi kiri dalam, tepi kanan dalam, dan bagian atas sel.
        for (final p in [
          r.center,
          Offset(r.left + 2, r.center.dy),
          Offset(r.right - 2, r.center.dy),
          Offset(r.center.dx, r.top + 2),
        ]) {
          await tester.tapAt(p);
          await tester.pump();
        }
      }
      expect(dipilih, [
        for (var i = 0; i < _admin.length; i++) ...[i, i, i, i],
      ]);
    });

    testWidgets('sasaran sentuh: tiap butir >= 48 x 48 (terang dan gelap)', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      for (final gelap in [false, true]) {
        await _pasang(tester, _bilahAdmin(), gelap: gelap);
        for (var i = 0; i < _admin.length; i++) {
          final s = tester.getSize(_butir(i));
          expect(s.height, greaterThanOrEqualTo(64), reason: 'tinggi butir $i');
          expect(s.width, greaterThanOrEqualTo(48), reason: 'lebar butir $i');
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      semantik.dispose();
    });
  });

  group('teknisi: dua butir + Mulai datar 48 di tengah', () {
    testWidgets('urutan Kalibrasi, Mulai, Profil dari kiri ke kanan', (
      tester,
    ) async {
      await _pasang(tester, _bilahTeknisi());
      final x0 = tester.getCenter(_butir(0)).dx;
      final xm = tester.getCenter(find.byKey(const ValueKey('dock-mulai'))).dx;
      final x1 = tester.getCenter(_butir(1)).dx;
      expect(x0, lessThan(xm));
      expect(xm, lessThan(x1));
      expect(xm, closeTo(195, 1), reason: 'tepat di tengah layar 390');
    });

    testWidgets('Mulai: 48, primer datar, ikon putih; bukan butir tab', (
      tester,
    ) async {
      await _pasang(tester, _bilahTeknisi());
      final m = _m(tester);
      final s = Theme.of(
        tester.element(find.byType(FloatingNavBar)),
      ).colorScheme;

      final mulai = find.byKey(const ValueKey('dock-mulai'));
      expect(tester.getSize(mulai).shortestSide, greaterThanOrEqualTo(48));
      final bundar = find.descendant(
        of: mulai,
        matching: find.byType(DecoratedBox),
      );
      for (final d in tester.widgetList<DecoratedBox>(bundar)) {
        final dekor = d.decoration;
        if (dekor is BoxDecoration) {
          expect(dekor.boxShadow, anyOf(isNull, isEmpty), reason: 'datar');
        }
      }
      final material = tester.widget<Material>(
        find.descendant(of: mulai, matching: find.byType(Material)).first,
      );
      expect(material.color, s.primary);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: mulai, matching: find.byType(Icon)),
            )
            .color,
        s.onPrimary,
      );
      expect(m.biru, s.primary);
      // Hanya dua butir tab (Mulai bukan butir).
      expect(_butir(0), findsOneWidget);
      expect(_butir(1), findsOneWidget);
      expect(_butir(2), findsNothing);
    });

    testWidgets('Profil terpilih: kapsul pindah ke Profil', (tester) async {
      await _pasang(tester, _bilahTeknisi(terpilih: 1));
      final m = _m(tester);
      expect(_isiKapsul(tester, 1), m.biruTipis);
      expect(_isiKapsul(tester, 0), Colors.transparent);
    });
  });

  group('papan ketik, gerak, fokus', () {
    testWidgets('papan ketik terbuka: bilah tidak ada (isian tidak kehilangan '
        'ruang)', (tester) async {
      await _pasang(tester, _bilahAdmin(), papanKetik: 300);
      expect(find.byKey(const ValueKey('dock')), findsNothing);
      expect(tester.getSize(find.byType(FloatingNavBar)).height, 0);
      // Papan ketik menutup: kembali.
      await _pasang(tester, _bilahAdmin());
      expect(find.byKey(const ValueKey('dock')), findsOneWidget);
    });

    testWidgets('kurangi gerak menyala: kapsul beralih seketika', (
      tester,
    ) async {
      await _pasang(tester, _bilahAdmin(), kurangi: true);
      final durasi = tester
          .widget<AnimatedContainer>(find.byKey(kunciIndikatorBilah))
          .duration;
      expect(durasi, Duration.zero);
    });

    testWidgets('Tab memindahkan cincin fokus di DALAM sel; kontras >= 3:1', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _pasang(tester, _bilahAdmin());
      final m = _m(tester);

      expect(find.byKey(kunciCincinFokusBilah), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      final cincin = find.byKey(kunciCincinFokusBilah);
      expect(cincin, findsOneWidget);
      // Di dalam sel yang terfokus (butir 1 setelah dua Tab: tombol pertama
      // yang bisa difokuskan adalah butir 0, kedua butir 1).
      final sel = tester.getRect(_butir(1));
      final r = tester.getRect(cincin);
      expect(r.left, greaterThanOrEqualTo(sel.left));
      expect(r.right, lessThanOrEqualTo(sel.right));
      expect(r.top, greaterThanOrEqualTo(sel.top));
      expect(r.bottom, lessThanOrEqualTo(sel.bottom));
      expect(rasioKontras(m.tinta, m.kertas), greaterThanOrEqualTo(3));
    });
  });

  group('lebar sempit: huruf 1,3 pada 320 dp tanpa kata terpotong', () {
    for (final (nama, bilah, butirAda) in <(String, Widget, int)>[
      ('admin', _bilahAdmin(), 5),
      ('teknisi', _bilahTeknisi(), 2),
    ]) {
      for (final gelap in [false, true]) {
        for (final skala in [1.0, 1.3]) {
          testWidgets(
            '$nama, ${gelap ? 'gelap' : 'terang'}, huruf $skala: lebar alami '
            'kata <= sel, satu ukuran, >= 12 sp, tanpa luapan',
            (tester) async {
              await _pasang(
                tester,
                bilah,
                lebar: 320,
                skala: skala,
                gelap: gelap,
              );
              expect(tester.takeException(), isNull);
              final ukuran = <double>{};
              for (var i = 0; i < butirAda; i++) {
                final teks = find
                    .descendant(of: _butir(i), matching: find.byType(Text))
                    .first;
                final p = tester.renderObject<RenderParagraph>(teks);
                final sel = tester.getSize(_butir(i)).width;
                expect(
                  p.getMaxIntrinsicWidth(double.infinity),
                  lessThanOrEqualTo(sel),
                  reason: 'kata butir $i lebih lebar dari selnya ($sel)',
                );
                final efektif = p.textScaler.scale(
                  _label(tester, i).style!.fontSize!,
                );
                expect(efektif, greaterThanOrEqualTo(12 - 1e-6));
                ukuran.add(double.parse(efektif.toStringAsFixed(2)));
              }
              expect(ukuran, hasLength(1), reason: 'satu ukuran untuk semua');
            },
          );
        }
      }
    }

    testWidgets('huruf sistem 2,0 dijepit 1,3 di dalam bilah (tanpa luapan)', (
      tester,
    ) async {
      await _pasang(tester, _bilahAdmin(), lebar: 320, skala: 2.0);
      expect(tester.takeException(), isNull);
      final p = tester.renderObject<RenderParagraph>(
        find.descendant(of: _butir(0), matching: find.byType(Text)).first,
      );
      expect(
        p.textScaler.scale(12),
        lessThanOrEqualTo(12 * 1.3 + 1e-6),
        reason: 'bilah memakai paling banyak 1,3x',
      );
    });
  });
}
