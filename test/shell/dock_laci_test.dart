// Laci menu shell Biru Awan (L6) + shell sungguhan (`MainShell`) dengan bilah
// navigasi solid (REVISI 16 Nov 2026).
//
// Yang dikunci di sini (bukan yang sudah dikunci `adaptive_shell_test`,
// `menu_per_peran_test`, dan `bilah_navigasi_lab_test`):
//  - bilah per peran di shell sungguhan: butir bernama, teknisi dengan Mulai,
//    tinggi bilah tidak menelan badan, kapsul pindah saat tab diganti;
//  - laci untuk empat peran (teknisi tanpa laci): isi dan urutan persis
//    dari switch `peran`, kepala, lencana merah, terpilih, tutup, sasaran >= 48.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
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

// Dock berdiri sendiri (bentuk, label, semantik, sasaran, papan ketik, lebar
// sempit) dites di `bilah_navigasi_lab_test.dart` sejak REVISI 16 Nov 2026
// (bilah solid menggantikan dock pil melayang). Di sini tinggal bantuan untuk
// tes shell sungguhan.

Finder _butir(int i) => find.byKey(ValueKey('dock-butir-$i'));

SemanticsData _semantik(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

SidikMaterial _m(WidgetTester tester) =>
    SidikMaterial.of(tester.element(find.byType(FloatingNavBar)));

/// Isi kapsul yang SEDANG tergambar di butir [i] (bukan target animasi).
Color? _isiKapsul(WidgetTester tester, int i) {
  final kotak = tester.widget<AnimatedContainer>(
    find.descendant(of: _butir(i), matching: find.byType(AnimatedContainer)),
  );
  return (kotak.decoration! as BoxDecoration).color;
}

void main() {
  setUpAll(muatFontUji);

  // ──────────────────────────── shell sungguhan ────────────────────────────

  final l10n = l10nUji();

  group('MainShell: dock per peran', () {
    testWidgets('teknisi: dua butir + Mulai; tanpa laci', (tester) async {
      await _bukaShell(tester, 'mock-token-2');

      final dock = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
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

    // Bilah setinggi isinya (64 + tepi sistem). Pernah salah (dock lama):
    // `Center` tanpa `heightFactor` di dalam `bottomNavigationBar` mengisi
    // SELURUH tinggi layar dan badan tab menjadi setinggi nol.
    for (final (token, nama, tertinggi) in [
      ('mock-token-1', 'admin', 84.0),
      ('mock-token-2', 'teknisi', 84.0),
    ]) {
      testWidgets('$nama: dock tidak menelan badan layar (800 x 600)', (
        tester,
      ) async {
        await _bukaShell(tester, token, lebar: 800, tinggi: 600);

        final dock = tester.getSize(find.byType(FloatingNavBar)).height;
        expect(dock, greaterThanOrEqualTo(64));
        expect(dock, lessThanOrEqualTo(tertinggi));
        final badan = tester.getSize(find.byType(IndexedStack)).height;
        expect(badan, greaterThan(600 - tertinggi - 60));
      });
    }

    testWidgets('ketuk Alat di bilah pindah tab dan menggeser kapsul', (
      tester,
    ) async {
      await _bukaShell(tester, 'mock-token-1');
      final m = _m(tester);

      expect(_isiKapsul(tester, 0), m.biruTipis);
      await tester.tap(find.text(l10n.navEquipment).first);
      await tester.pumpAndSettle();
      expect(_isiKapsul(tester, 1), m.biruTipis);
      expect(_isiKapsul(tester, 0), Colors.transparent);
    });

    testWidgets('kurangi gerak sistem: kapsul pindah pada bingkai berikutnya', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _bukaShell(tester, 'mock-token-1');
      final m = _m(tester);

      await tester.tap(find.text(l10n.navEquipment).first);
      await tester.pump();
      await tester.pump();
      expect(_isiKapsul(tester, 1), m.biruTipis);
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
          {l10n.menuKerjaHarian, l10n.menuArsip, l10n.menuPengaturan}.contains,
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

    testWidgets('panel 320, sudut kanan 16, putih, bayangan tipis; latar redup '
        'navy 42 %', (tester) async {
      await _bukaLaci(tester, 'mock-token-1');
      final m = _m(tester);

      expect(tester.getSize(find.byType(Drawer)).width, 320);
      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, m.kertas);
      expect(
        (drawer.shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(16)),
      );
      // REVISI 16 Nov 2026: elevasi 1 (bawaan Drawer 16).
      expect(drawer.elevation, 1);
      final scaffold = tester.widget<Scaffold>(find.byKey(mainShellKey));
      expect(scaffold.drawerScrimColor, m.tinta.withValues(alpha: 0.42));
    });

    testWidgets('terpilih: tab aktif = kotak kabut + biruTinta 600; lain 500', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(tester, 'mock-token-1');
      final m = _m(tester);

      TextStyle? gaya(String judul) =>
          tester.widget<Text>(judulLaci(judul)).style;

      // Tab aktif = 0 (Dashboard).
      expect(gaya(l10n.navDashboard)?.color, m.biruTinta);
      expect(gaya(l10n.navDashboard)?.fontWeight, FontWeight.w600);
      expect(gaya(l10n.navEquipment)?.color, m.tinta);
      expect(gaya(l10n.navEquipment)?.fontWeight, FontWeight.w500);

      Material pilDi(String judul) => tester.widget<Material>(
        find
            .ancestor(of: judulLaci(judul), matching: find.byType(Material))
            .first,
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

    testWidgets('lencana merah: Antrean, Draf, Jadwal, Notifikasi', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await _bukaLaci(tester, 'mock-token-1');
      final m = SidikMaterial.of(tester.element(find.byType(Drawer)));

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
        // Tampak: kotak merah galat (angka putih) di baris yang sama.
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
        expect((pil.decoration as BoxDecoration).color, m.gagal);
        expect(
          tester.widget<Text>(angka).style!.color,
          m.teksDiGagal,
          reason: 'angka putih di atas merah galat',
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

    testWidgets(
      'angka nol dan lebih dari 99 tidak menampilkan "0"/angka liar',
      (tester) async {
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
      },
    );

    testWidgets('sasaran sentuh: tiap butir laci >= 48 dan seluruh baris '
        'diketuk', (tester) async {
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
      expect(ProviderScope.containerOf(konteks).read(selectedTabProvider), 1);
    });

    for (final (token, nama) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super admin'),
      ('mock-token-3', 'viewer'),
    ]) {
      testWidgets('$nama: 320 dp x huruf 1,3 tanpa luapan di laci dan dock', (
        tester,
      ) async {
        await _bukaLaci(tester, token, lebar: 320, tinggi: 900, skala: 1.3);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(Drawer)).width,
          lessThanOrEqualTo(320),
        );
        await tester.tap(find.byKey(const ValueKey('laci-tutup')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'kurangi gerak: laci terbuka dan menutup tanpa gerak berulang',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _bukaLaci(tester, 'mock-token-1');
        expect(find.byType(Drawer), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('laci-tutup')));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsNothing);
      },
    );
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

Widget _app(String token, {DashboardService? ringkasan, int belumDibaca = 12}) {
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
