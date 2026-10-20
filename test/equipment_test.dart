import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show categoryServiceProvider;
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/equipment_list_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/app_text_field.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';
import 'support/lewati_onboarding.dart';
import 'support/simpanan_tiruan.dart';

/// Dibungkus `SidikApp` (bukan langsung `EquipmentListScreen`) — layar ini
/// nge-watch `authProvider`, dan kalau dibuka lepas dari `AuthGate`,
/// `MockAuthService.me()`-nya yang berjeda 600ms ninggalin timer nyangkut
/// yang bikin `pumpAndSettle` gagal di akhir test (`!timersPending`). Lewat
/// `SidikApp`, timer itu udah kelar waktu splash, sebelum tab Alat dibuka.
Widget _app({
  String token = 'mock-token-1',
  bool gagal = false,
  Izin izin = Izin.kosong,
}) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(
        MockEquipmentService(gagal: gagal),
      ),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      // Picker pelanggan di form Alat sengaja narik dari `/arsip/perusahaan`
      // (kebuka semua role), BUKAN `/customers` yang admin-only — lihat
      // `ApiCustomerLookupService`.
      customerLookupServiceProvider.overrideWithValue(
        MockCustomerLookupService(),
      ),
    ],
    child: const SidikApp(),
  );
}

/// Form Alat punya ~13 field — lebih panjang dari viewport test standar
/// (800x600), dan `ListView` cuma nge-build item yang deket viewport (sama
/// kasusnya kayak `ph_calibration_input_test.dart`).
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Tap label "Alat" di bottom nav — bukan `find.text('Alat')` polos, soalnya
/// begitu tab-nya aktif AppBar-nya JUGA berjudul "Alat", jadi ada 2 match.
Future<void> _tapTabAlat(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(FloatingNavBar),
      matching: find.text('Alat'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _bukaTabAlat(
  WidgetTester tester, {
  String token = 'mock-token-1',
  Izin izin = Izin.kosong,
}) async {
  // Widget kosong dulu biar `ProviderScope`/container app sebelumnya (kalau
  // ada, dari pemanggilan `_bukaTabAlat` lain di test yang sama) beneran
  // dibuang — tanpa ini Flutter ngereuse elemen `SidikApp` lama, jadi state
  // auth/tab lama (mis. role admin) masih nyangkut walau token-nya diganti.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_app(token: token, izin: izin));
  await tester.pumpAndSettle();
  await _tapTabAlat(tester);
}

/// Layar Alat dibuka LANGSUNG (tanpa shell) — dipakai buat role yang tidak
/// punya tab Alat di navbar HP (teknisi). `MockAuthService` tanpa jeda supaya
/// tidak ada timer nyangkut.
Future<void> _bukaLayarAlat(
  WidgetTester tester, {
  required String token,
  Izin izin = Izin.kosong,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
        categoryServiceProvider.overrideWithValue(MockCategoryService()),
      ],
      child: const MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EquipmentListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pilih pelanggan lewat sheet pencarian.
///
/// Bukan dropdown lagi: daftar pelanggan dipaginasi 15/halaman di server, jadi
/// field-nya buka sheet yang nyari ke server (`?search=`) supaya pelanggan
/// ke-16 dan seterusnya tetap kejangkau.
Future<void> _pilihPelanggan(WidgetTester tester, String nama) async {
  await tester.tap(find.text('Pilih pelanggan'), warnIfMissed: false);
  await tester.pumpAndSettle();

  await tester.tap(find.text(nama).last);
  await tester.pumpAndSettle();
}

/// Kolom input berdasarkan label di atasnya (label-nya dirender HURUF BESAR
/// sebagai `Text` terpisah, bukan `labelText` bawaan `InputDecoration`).
Finder _kolom(WidgetTester tester, String label) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(TextField),
  );
}

void main() {
  pasangSimpananTiruan();

  testWidgets('nampilin daftar alat dengan badge status', (tester) async {
    await _bukaTabAlat(tester);

    expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
    expect(find.text('Timbangan Digital Ohaus'), findsOneWidget);
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();
    await _tapTabAlat(tester);

    expect(find.text('Gagal memuat daftar alat.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('admin bisa lihat tombol tambah & hapus, viewer nggak', (
    tester,
  ) async {
    await _bukaTabAlat(tester);
    expect(find.text('Tambah alat'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    // token-3 = viewer (lihat MockAuthService) — instance app baru dari nol,
    // bukan nyambung dari state token admin di atas.
    await _bukaTabAlat(tester, token: 'mock-token-3');
    expect(find.text('Tambah alat'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  // `DELETE /equipments/{e}` admin & super admin saja di server (teknisi 403),
  // dan `/me/permissions` teknisi tidak lagi memuat `alat.hapus`. Teknisi
  // tidak punya tab Alat di navbar HP, tapi membuka layar yang sama lewat
  // menu Alat di panel desktop — jadi layarnya diuji langsung.
  testWidgets('teknisi tidak lihat Hapus alat (cadangan & jawaban server)', (
    tester,
  ) async {
    // Izin belum dijawab server → cadangan `hakAdmin`, bukan `bisaInput`.
    await _bukaLayarAlat(tester, token: 'mock-token-2');
    expect(find.text('Tambah alat'), findsOneWidget);
    expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Jawaban server persis: teknisi pegang `alat.tambah`, tanpa `alat.hapus`.
    await _bukaLayarAlat(
      tester,
      token: 'mock-token-2',
      izin: const Izin(
        role: UserRole.teknisi,
        boleh: {NamaIzin.alatTambah, NamaIzin.alatUbah},
      ),
    );
    expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('admin & super admin lihat Hapus alat', (tester) async {
    await _bukaLayarAlat(
      tester,
      token: 'mock-token-1',
      izin: const Izin(
        role: UserRole.admin,
        boleh: {NamaIzin.alatTambah, NamaIzin.alatHapus},
      ),
    );
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    await _bukaLayarAlat(tester, token: 'mock-token-5');
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });

  testWidgets('tambah alat baru → muncul di list', (tester) async {
    _perbesarViewport(tester);
    await _bukaTabAlat(tester);

    await tester.tap(find.text('Tambah alat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Termometer Digital Baru',
    );
    await tester.enterText(find.byType(TextField).at(1), 'TD-001');

    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Massa').last);
    await tester.pumpAndSettle();

    await _pilihPelanggan(tester, 'PT Maju Jaya');

    // Toleransi wajib — alat tanpa toleransi nggak bisa dikalibrasi sama
    // sekali, jadi form-nya nahan di sini daripada ditolak server belakangan.
    await tester.enterText(_kolom(tester, 'TOLERANSI'), '0.2');

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Termometer Digital Baru'), findsOneWidget);
  });

  testWidgets('toleransi kosong → ditahan form, nggak dikirim ke server', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await _bukaTabAlat(tester);

    await tester.tap(find.text('Tambah alat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Alat Tanpa Toleransi',
    );
    await tester.enterText(find.byType(TextField).at(1), 'TT-001');

    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Massa').last);
    await tester.pumpAndSettle();

    await _pilihPelanggan(tester, 'PT Maju Jaya');

    // Toleransi sengaja dikosongin.
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Toleransi wajib diisi.'), findsOneWidget);
    expect(
      find.text('Simpan'),
      findsOneWidget,
      reason: 'masih nyangkut di form, bukan udah balik ke list',
    );
  });

  testWidgets(
    'pilih kategori "Panjang" → dropdown Jenis Alat (Kemampuan Kalibrasi) muncul',
    (tester) async {
      _perbesarViewport(tester);
      await _bukaTabAlat(tester);

      await tester.tap(find.text('Tambah alat'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panjang').last);
      await tester.pumpAndSettle();

      // MockCategoryService.detail('panjang') balikin 2 kemampuan — dropdown-nya
      // muncul begitu kategori dipilih, bukan cuma field kosong nggak berguna.
      expect(
        find.text('Pilih jenis alat (opsional, buat CMC akurat)'),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Pilih jenis alat (opsional, buat CMC akurat)'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jangka Sorong').last);
      await tester.pumpAndSettle();

      expect(find.text('Jangka Sorong'), findsWidgets);
    },
  );

  testWidgets('hapus alat → dikonfirmasi dulu, baru ilang dari list', (
    tester,
  ) async {
    await _bukaTabAlat(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Jangka Sorong Mitutoyo'), findsNothing);
  });
}
