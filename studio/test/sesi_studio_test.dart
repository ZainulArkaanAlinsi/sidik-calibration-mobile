import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/studio_acuan_screen.dart';
import 'package:sidik_calibration/services/klien_http_beridentitas.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/inti/sesi_studio.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';
import 'package:sidik_studio/layar/cangkang_studio.dart';
import 'package:sidik_studio/layar/klien_kedaluwarsa_screen.dart';
import 'package:sidik_studio/layar/masuk_screen.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/widget/dialog_sesi_berakhir.dart';

import 'pembantu/studio_uji.dart';

/// ST-T-012: sesi Studio — 401 → dialog di atas layar yang sama (FR-STU-004),
/// keluar menyapu cache (FR-STU-005), izin ditarik ulang saat kembali dari
/// latar (FR-STU-007), dan 426 → layar versi usang (FR-STU-003).
///
/// Sambungan "jawaban HTTP 401/426 → keadaan" diuji terhadap server HTTP
/// sungguhan di `klien_studio_test.dart`; di sini keadaannya dipicu langsung
/// supaya yang diuji perilaku layarnya.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('401 → sesi berakhir', () {
    testWidgets('dialog di atas layar yang sama; masuk ulang → layar & '
        'state-nya tetap, token baru, izin ditarik ulang', (tester) async {
      final auth = AuthHitung();
      final izin = IzinHitung();
      final penyimpanan = _PenyimpananCatat('mock-token-1');
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          auth: auth,
          izinService: izin,
          penyimpanan: penyimpanan,
        ),
      );
      await tenang(tester);

      // Orang sedang bekerja di layar detail, dua tingkat di dalam seksi.
      await bukaSeksi(tester, SeksiStudio.dataAcuan);
      await tester.tap(find.text('Micrometer'));
      await tenang(tester);
      final layarSebelum = _stateLayarDetail(tester);
      final izinSebelum = izin.dipanggil;

      _laporTokenDitolak(tester);
      await tenang(tester);

      expect(find.text('Sesi berakhir, masuk lagi'), findsOneWidget);
      expect(
        find.textContaining('sebagai Budi Santoso (SDK-0001)'),
        findsOneWidget,
      );
      // Di BAWAH dialog layar yang sama masih hidup.
      expect(find.byType(StudioAcuanScreen), findsOneWidget);

      // Tidak bisa disingkirkan dengan mengetuk di luar.
      await tester.tapAt(const Offset(4, 4));
      await tenang(tester);
      expect(find.byType(DialogSesiBerakhir), findsOneWidget);

      // Sandi salah: pesan server di dialog, token lama tidak disentuh.
      await _isiSandiDialog(tester, 'salah');
      expect(
        find.descendant(
          of: find.byType(DialogSesiBerakhir),
          matching: find.text('ID pegawai / email atau password salah.'),
        ),
        findsOneWidget,
      );
      expect(penyimpanan.ditulis, isEmpty);

      await _isiSandiDialog(tester, 'rahasia123');

      expect(find.byType(DialogSesiBerakhir), findsNothing);
      expect(find.byType(MasukStudioScreen), findsNothing);
      expect(find.byType(StudioAcuanScreen), findsOneWidget);
      // State layar yang SAMA (bukan dibangun ulang) → isian ikut selamat.
      expect(identical(_stateLayarDetail(tester), layarSebelum), isTrue);
      // Identitas dikunci ke akun sesi ini.
      expect(auth.identitasLogin, ['SDK-0001', 'SDK-0001']);
      expect(penyimpanan.ditulis, ['mock-token-1']);
      expect(izin.dipanggil, greaterThan(izinSebelum));
      expect(
        wadahDari(tester).read(sesiStudioProvider),
        KeadaanSesiStudio.aktif,
      );
    });

    testWidgets('banyak 401 sekaligus → satu dialog', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-1'));
      await tenang(tester);

      _laporTokenDitolak(tester);
      _laporTokenDitolak(tester);
      await tenang(tester);
      _laporTokenDitolak(tester);
      await tenang(tester);

      expect(find.byType(DialogSesiBerakhir), findsOneWidget);
    });

    testWidgets('"Keluar & ganti akun" → layar masuk, dialog tidak '
        'tertinggal, token dibuang', (tester) async {
      final penyimpanan = _PenyimpananCatat('mock-token-1');
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, penyimpanan: penyimpanan));
      await tenang(tester);

      _laporTokenDitolak(tester);
      await tenang(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Keluar & ganti akun'));
      await tenang(tester);

      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(find.byType(DialogSesiBerakhir), findsNothing);
      expect(await penyimpanan.read(), isNull);
    });

    testWidgets('401 sebelum ada yang masuk (token tersimpan basi) tidak '
        'memunculkan dialog sesudah masuk', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);

      _laporTokenDitolak(tester);
      await tenang(tester);
      await masukLewatLayar(tester, 'SDK-0001', 'rahasia123');

      expect(find.byType(CangkangStudio), findsOneWidget);
      expect(find.byType(DialogSesiBerakhir), findsNothing);
    });

    test('sesudah masuk ulang, 401 atas token LAMA diabaikan — juga yang '
        'baru berangkat sesudahnya (pengulangan 502–504, pemanasan /health); '
        '401 atas token BARU → berakhir', () async {
      final wadah = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
        ],
      );
      addTearDown(wadah.dispose);
      await wadah.read(authProvider.future);
      final sesi = wadah.read(sesiStudioProvider.notifier);

      // Sebelum masuk ulang: penolakan token yang dipakai = sesi berakhir.
      sesi.laporTokenDitolak(sidikToken: sidikTokenBearer('mock-token-1'));
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.berakhir);

      sesi.pulih(tokenBaru: 'token-baru-2');
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.aktif);

      // Request yang header-nya disusun sebelum masuk ulang, berangkat
      // sesudahnya: membawa token lama. Bukan alasan dialog kedua.
      sesi.laporTokenDitolak(sidikToken: sidikTokenBearer('mock-token-1'));
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.aktif);

      sesi.laporTokenDitolak(sidikToken: sidikTokenBearer('token-baru-2'));
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.berakhir);
    });
  });

  group('keluar', () {
    testWidgets('menyapu cache: token dibuang, akun berikutnya tidak melihat '
        'data akun sebelumnya selama datanya sendiri dimuat', (tester) async {
      final layanan = _AcuanBisaDitahan();
      final penyimpanan = _PenyimpananCatat('mock-token-1');
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, penyimpanan: penyimpanan, layanan: layanan),
      );
      await tenang(tester);
      expect(find.text('Micrometer'), findsOneWidget);
      expect(layanan.daftarPaketDipanggil, 1);

      await tester.tap(find.byTooltip('Keluar'));
      await tenang(tester);
      expect(find.byType(MasukStudioScreen), findsOneWidget);
      expect(await penyimpanan.read(), isNull);

      // Akun berikutnya: jawaban servernya ditahan.
      layanan.tahan = Completer<void>();
      await masukLewatLayar(tester, 'SDK-0002', 'rahasia123');

      expect(find.byType(BerandaScreen), findsOneWidget);
      expect(layanan.daftarPaketDipanggil, 2);
      expect(find.text('Micrometer'), findsNothing);
      expect(find.text('Budi Santoso'), findsNothing);

      layanan.tahan!.complete();
      await tenang(tester);
      expect(find.text('Micrometer'), findsOneWidget);
    });
  });

  group('izin & latar', () {
    testWidgets('kembali dari latar → izin ditarik ulang; pindah fokus saja '
        'tidak', (tester) async {
      final izin = IzinHitung();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, token: 'mock-token-1', izinService: izin),
      );
      await tenang(tester);
      final awal = izin.dipanggil;
      expect(awal, greaterThan(0));

      // Jendela kehilangan lalu mendapat fokus lagi (alt-tab di Windows).
      await _siklus(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(izin.dipanggil, awal);

      // Ke latar (Android) / minimize (Windows), lalu kembali.
      await _siklus(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(izin.dipanggil, awal + 1);
    });

    testWidgets('izin yang dicabut saat di latar: seksinya hilang begitu '
        'kembali', (tester) async {
      final izin = IzinHitung();
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(meja: true, token: 'mock-token-1', izinService: izin),
      );
      await tenang(tester);
      expect(navigasi(SeksiStudio.dataAcuan), findsOneWidget);

      izin.izin = const Izin(role: UserRole.admin, boleh: {'lain.lain'});
      await _siklus(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      expect(navigasi(SeksiStudio.dataAcuan), findsNothing);
    });
  });

  group('426 klien kedaluwarsa', () {
    testWidgets('layar versi usang menggantikan layar masuk; coba lagi → '
        'kembali', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);

      wadahDari(tester).read(klienKedaluwarsaProvider.notifier).tandai();
      await tenang(tester);

      expect(find.byType(KlienKedaluwarsaScreen), findsOneWidget);
      expect(find.byType(MasukStudioScreen), findsNothing);
      expect(
        find.text('Versi Studio ini terlalu lama untuk server.'),
        findsOneWidget,
      );
      expect(
        find.text('Studio 0.1.0+1 · server 127.0.0.1:8000'),
        findsOneWidget,
      );

      await tester.tap(find.text('Coba lagi'));
      await tenang(tester);
      expect(find.byType(MasukStudioScreen), findsOneWidget);
    });

    testWidgets('di tengah kerja: cangkang diganti layar versi usang', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(studioUji(meja: true, token: 'mock-token-1'));
      await tenang(tester);

      wadahDari(tester).read(klienKedaluwarsaProvider.notifier).tandai();
      await tenang(tester);

      expect(find.byType(KlienKedaluwarsaScreen), findsOneWidget);
      expect(find.byType(CangkangStudio), findsNothing);
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

void _laporTokenDitolak(WidgetTester tester) => wadahDari(tester)
    .read(sesiStudioProvider.notifier)
    .laporTokenDitolak(sidikToken: sidikTokenBearer('mock-token-1'));

ScaffoldState _stateLayarDetail(WidgetTester tester) => tester.state(
  find
      .descendant(
        of: find.byType(StudioAcuanScreen),
        matching: find.byType(Scaffold),
      )
      .first,
);

Future<void> _isiSandiDialog(WidgetTester tester, String sandi) async {
  final dialog = find.byType(DialogSesiBerakhir);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    sandi,
  );
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, 'Masuk'),
    ),
  );
  await tenang(tester);
}

Future<void> _siklus(
  WidgetTester tester,
  List<AppLifecycleState> urutan,
) async {
  for (final s in urutan) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tenang(tester);
}

class _PenyimpananCatat extends InMemoryTokenStorage {
  _PenyimpananCatat(super.token);

  final ditulis = <String>[];

  @override
  Future<void> write(String token) {
    ditulis.add(token);
    return super.write(token);
  }
}

class _AcuanBisaDitahan extends LayananAcuanHitung {
  Completer<void>? tahan;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) async {
    final hasil = super.daftarPaket(token);
    final t = tahan;
    if (t != null) await t.future;
    return hasil;
  }
}
