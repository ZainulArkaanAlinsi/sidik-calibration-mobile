import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/koreksi_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/permintaan_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/screens/koreksi/antrean_koreksi_screen.dart';
import 'package:sidik_calibration/screens/pelanggan/pusat_pelanggan_screen.dart';
import 'package:sidik_calibration/screens/pengesahan/antrean_pengesahan_screen.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_screen.dart';
import 'package:sidik_calibration/screens/permintaan/antrean_permintaan_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/koreksi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/pengesahan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
import 'package:sidik_calibration/services/permintaan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/lewati_onboarding.dart';

/// Menu samping per peran (paket 29 Sep 2026).
///
/// ## Kenapa test ini ada
///
/// Menu ini satu-satunya pintu ke layar pengesahan, pelacakan, penugasan, dan
/// Kelola lab — dan isinya DIPILIH per peran di satu `switch`. Salah satu
/// cabang yang tertukar tidak menghasilkan error: teknisi cuma melihat tombol
/// "Pengesahan sertifikat" yang servernya tolak, atau super admin kehilangan
/// satu-satunya jalan ke antrean yang harus dia kerjakan. Server tetap menjaga
/// wewenangnya; yang dijaga di sini adalah bahwa tiap orang MELIHAT pekerjaannya
/// sendiri dan tidak melihat pekerjaan orang lain.
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
Widget _app(String token) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      pakaiPanelDesktopProvider.overrideWithValue(false),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      notificationServiceProvider.overrideWithValue(
        MockNotificationService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
      izinServiceProvider.overrideWithValue(MockIzinService()),
      pengesahanServiceProvider.overrideWithValue(MockPengesahanService()),
      pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
      penugasanServiceProvider.overrideWithValue(MockPenugasanService()),
      permintaanServiceProvider.overrideWithValue(MockPermintaanService()),
      koreksiServiceProvider.overrideWithValue(MockKoreksiService()),
    ],
    child: const SidikApp(),
  );
}

Future<void> _bukaMenu(WidgetTester tester, String token) async {
  // Lebar HP, tapi tinggi: menu admin punya 13 baris dan `ListView` drawer
  // tidak membangun baris di bawah lipatan — tanpa ini "Kelola lab" tidak
  // pernah ada di pohon widget.
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(token));
  // MockAuthService punya jeda 600 ms; pumpAndSettle tidak memajukan timer.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  bukaMenuUtama();
  await tester.pumpAndSettle();
}

Finder _diMenu(String teks) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(teks));

void _ada(List<String> daftar) {
  for (final t in daftar) {
    expect(_diMenu(t), findsWidgets, reason: '"$t" mestinya ada di menu');
  }
}

void _tiada(List<String> daftar) {
  for (final t in daftar) {
    expect(_diMenu(t), findsNothing, reason: '"$t" TIDAK boleh ada di menu');
  }
}

void main() {
  const pengesahan = 'Pengesahan sertifikat';
  const penugasan = 'Penugasan';
  const tugasSaya = 'Tugas saya';
  const pelacakan = 'Pelacakan paket';
  const kelolaLab = 'Kelola lab';
  const pusat = 'Pusat pelanggan';
  const jadwal = 'Jadwal kalibrasi ulang';
  const antreanApproval = 'Antrean Approval';
  const draf = 'Draf';
  const permintaan = 'Permintaan pelanggan';
  const koreksi = 'Koreksi pelanggan';

  testWidgets('super admin: dibuka dari pengesahan, sisanya cuma pantau', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');

    // Judul seksi dicetak gaya etsa (huruf besar).
    _ada([
      pengesahan,
      penugasan,
      pelacakan,
      pusat,
      jadwal,
      permintaan,
      koreksi,
      'PANTAU (BACA SAJA)',
    ]);
    // Kalimat yang menjelaskan kenapa tombol isi-data tidak ada untuknya.
    expect(
      find.textContaining('Mengesahkan sertifikat sebelum terbit'),
      findsOneWidget,
    );
    // Super admin tidak menyetujui sesi dan tidak mengisi lembar kerja.
    _tiada([antreanApproval, draf, kelolaLab, tugasSaya]);
  });

  testWidgets('super admin: menu pengesahan membuka antreannya', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');

    await tester.tap(_diMenu(pengesahan));
    await tester.pumpAndSettle();

    expect(find.byType(AntreanPengesahanScreen), findsOneWidget);
  });

  testWidgets('super admin: menu pusat pelanggan & jadwal membuka layarnya', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');
    await tester.tap(_diMenu(pusat));
    await tester.pumpAndSettle();
    expect(find.byType(PusatPelangganScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    bukaMenuUtama();
    await tester.pumpAndSettle();
    await tester.tap(_diMenu(jadwal));
    await tester.pumpAndSettle();
    expect(find.byType(JadwalKalibrasiScreen), findsOneWidget);
  });

  testWidgets('admin: kerja harian lengkap + satu pintu Kelola lab', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-1');

    _ada([
      antreanApproval,
      pengesahan,
      'Alur Kerja',
      penugasan,
      pelacakan,
      draf,
      kelolaLab,
      pusat,
      jadwal,
      permintaan,
      koreksi,
    ]);
    _tiada([tugasSaya]);
    expect(
      find.textContaining('Mengesahkan sertifikat sebelum terbit'),
      findsNothing,
    );
  });

  testWidgets(
    'teknisi: dibuka dari "Tugas saya", tanpa pengesahan & Kelola lab',
    (tester) async {
      await _bukaMenu(tester, 'mock-token-2');

      _ada([tugasSaya, draf, pelacakan]);
      _tiada([
        pengesahan,
        kelolaLab,
        antreanApproval,
        penugasan,
        pusat,
        jadwal,
        permintaan,
        koreksi,
      ]);
    },
  );

  testWidgets('teknisi: "Tugas saya" membuka penugasan miliknya', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-2');

    await tester.tap(_diMenu(tugasSaya));
    await tester.pumpAndSettle();

    expect(find.byType(PenugasanScreen), findsOneWidget);

    // Tanggal ikut bahasa app. `Intl.defaultLocale` tidak pernah disetel, jadi
    // `DateFormat` tanpa locale dulu mencetak "Target 2 Oct 2026" di layar
    // berbahasa Indonesia (ketahuan dari golden detail penugasan, 30 Sep 2026).
    expect(find.textContaining('Okt 2026'), findsWidgets);
    expect(find.textContaining('Oct 2026'), findsNothing);
  });

  testWidgets('viewer: baca saja, dan dikasih tahu kenapa', (tester) async {
    await _bukaMenu(tester, 'mock-token-3');

    _ada([pelacakan]);
    expect(find.textContaining('Akun ini cuma bisa melihat'), findsOneWidget);
    _tiada([
      pengesahan,
      penugasan,
      tugasSaya,
      draf,
      kelolaLab,
      antreanApproval,
      pusat,
      jadwal,
      permintaan,
      koreksi,
    ]);
  });

  testWidgets('admin: permintaan pelanggan berlencana jumlah yang menunggu', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-1');

    // Dua permintaan `baru` di data tiruan; angkanya dari `meta.jumlah_baru`.
    final lencana = find.descendant(
      of: find.byType(Drawer),
      matching: find.byKey(const ValueKey('lencana-permintaan')),
    );
    expect(lencana, findsOneWidget);
    expect(
      find.descendant(of: lencana, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(_diMenu(permintaan));
    await tester.pumpAndSettle();
    expect(find.byType(AntreanPermintaanScreen), findsOneWidget);
  });

  testWidgets('super admin: permintaan pelanggan bisa dibuka (baca saja)', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');

    await tester.tap(_diMenu(permintaan));
    await tester.pumpAndSettle();
    expect(find.byType(AntreanPermintaanScreen), findsOneWidget);

    // Kartu dibuka → tombol keputusan tidak ada, kalimatnya ada.
    await tester.tap(find.text('PMT/2026/09/0012'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tombol-terima-permintaan')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('catatan-baca-saja-permintaan')),
      findsOneWidget,
    );
  });

  testWidgets('admin: koreksi pelanggan berlencana jumlah yang menunggu', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-1');

    // Dua koreksi `menunggu` di data tiruan; angkanya dari
    // `meta.jumlah.menunggu`.
    final lencana = find.descendant(
      of: find.byType(Drawer),
      matching: find.byKey(const ValueKey('lencana-koreksi')),
    );
    expect(lencana, findsOneWidget);
    expect(
      find.descendant(of: lencana, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(_diMenu(koreksi));
    await tester.pumpAndSettle();
    expect(find.byType(AntreanKoreksiScreen), findsOneWidget);
  });

  testWidgets('super admin: koreksi pelanggan bisa dibuka (baca saja)', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');

    await tester.tap(_diMenu(koreksi));
    await tester.pumpAndSettle();
    expect(find.byType(AntreanKoreksiScreen), findsOneWidget);

    // Kartu dibuka → tombol keputusan tidak ada, kalimatnya ada.
    await tester.tap(find.byKey(const ValueKey('kartu-koreksi-7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsNothing);
    expect(
      find.byKey(const ValueKey('catatan-baca-saja-koreksi')),
      findsOneWidget,
    );
  });
}
