import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/screens/jatuh_tempo/layar_jatuh_tempo.dart';
import 'package:sidik_calibration/screens/penugasan/penugasan_screen.dart';
import 'package:sidik_calibration/screens/teknisi/kalibrasi_teknisi_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/penugasan_service.dart';
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
      pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
      penugasanServiceProvider.overrideWithValue(MockPenugasanService()),
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
  // Pengesahan DICABUT 15 Okt 2026 (K-50-07): tidak boleh ada di menu siapa pun.
  const pengesahan = 'Pengesahan sertifikat';
  const penugasan = 'Penugasan';
  const tugasSaya = 'Tugas saya';
  const pelacakan = 'Telusuri No. Sertifikat';
  const kelolaLab = 'Kelola lab';
  const pusat = 'Pusat pelanggan';
  const jadwal = 'Jadwal kalibrasi ulang';
  const antreanApproval = 'Antrean Approval';
  const draf = 'Draf';
  const permintaan = 'Permintaan pelanggan';
  const koreksi = 'Koreksi pelanggan';

  // K-49-14 (15 Okt 2026): super admin = SEMUA menu admin & teknisi dari satu
  // tempat. Yang tetap ditahan server: menyetujui sesi yang dia isi sendiri
  // (K-30-03). Pengesahan dicabut (K-50-07).
  testWidgets('super admin: semua menu admin & teknisi, tanpa pengesahan', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');

    _ada([
      antreanApproval,
      'Alur Kerja',
      penugasan,
      pelacakan,
      draf,
      kelolaLab,
      jadwal,
    ]);
    _tiada([pusat, permintaan, koreksi]);
    // Kalimat yang mengingatkan K-30-03, bukan "baca saja" lagi.
    expect(
      find.textContaining('Semua aksi Master Data & teknisi'),
      findsOneWidget,
    );
    _tiada(['PANTAU (BACA SAJA)', tugasSaya, pengesahan]);
  });

  testWidgets('super admin: menu jadwal membuka layarnya', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-5');
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
      'Alur Kerja',
      penugasan,
      pelacakan,
      draf,
      kelolaLab,
      jadwal,
    ]);
    _tiada([pusat, permintaan, koreksi]);
    _tiada([tugasSaya, pengesahan]);
  });

  testWidgets(
    'teknisi: HP cuma dua tab (Kalibrasi, Profil) dan TANPA menu samping',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app('mock-token-2'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Tidak ada drawer sama sekali: Pengesahan, Kelola lab, Penugasan,
      // Pusat pelanggan, dst. bukan urusan teknisi (K-50-14).
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(KalibrasiTeknisiScreen), findsOneWidget);
      for (final label in ['Dashboard', 'Alat', 'Riwayat', 'Arsip']) {
        expect(find.text(label), findsNothing, reason: 'tab "$label" teknisi');
      }
      expect(find.text('Kalibrasi'), findsWidgets);
      expect(find.text('Profil'), findsOneWidget);
    },
  );

  testWidgets('admin: layar Penugasan — tanggal ikut bahasa app', (
    tester,
  ) async {
    await _bukaMenu(tester, 'mock-token-1');

    await tester.tap(_diMenu(penugasan));
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
}
