import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/settings/tanda_tangan_screen.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/tanda_tangan_service.dart';
import 'package:sidik_calibration/providers/tanda_tangan_provider.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app({required Izin izin, String token = 'mock-token-1'}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
      tandaTanganServiceProvider.overrideWithValue(MockTandaTanganService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TandaTanganScreen(),
    ),
  );
}

Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('Izin — bentuk respons belum pasti, jadi terima dua-duanya', () {
    test('boleh sebagai daftar', () {
      final izin = Izin.fromJson(const {
        'data': {
          'role': 'teknisi',
          'boleh': ['alat.lihat', 'alat.tambah'],
        },
      });

      expect(izin.role, UserRole.teknisi);
      expect(izin.bolehkah('alat.tambah', cadangan: false), isTrue);
    });

    test('boleh sebagai peta — yang false nggak keitung', () {
      final izin = Izin.fromJson(const {
        'boleh': {'alat.tambah': true, 'alat.hapus': false},
      });

      expect(izin.bolehkah('alat.tambah', cadangan: false), isTrue);
      // `alat.hapus` ada tapi false → bukan berarti "nggak dikenal", tapi
      // di sini tetap jatuh ke cadangan (lihat komentar di `bolehkah`).
      expect(izin.bolehkah('alat.hapus', cadangan: false), isFalse);
    });

    test('batasan kebaca terpisah dari boleh', () {
      // Dua hal beda: `boleh` jawab "layarnya kebuka apa nggak",
      // `batasan` jawab "isinya sebanyak apa".
      final izin = Izin.fromJson(const {
        'boleh': ['kalibrasi.lihat'],
        'batasan': {'kalibrasi': 'sendiri'},
      });

      expect(izin.bolehkah('kalibrasi.lihat', cadangan: false), isTrue);
      expect(izin.batasanUntuk('kalibrasi'), 'sendiri');
    });

    test('respons kosong → semua pertanyaan pakai cadangan', () {
      // Ini yang bikin PR ini aman: kalau bentuk responsnya beda dari tebakan,
      // atau endpointnya belum nyala, perilakunya sama persis kayak sebelum
      // matriks peran dipasang — bukan tombol ilang semua.
      const izin = Izin.kosong;

      expect(izin.bolehkah('apa.aja', cadangan: true), isTrue);
      expect(izin.bolehkah('apa.aja', cadangan: false), isFalse);
    });

    test('izin yang nggak disebut backend jatuh ke cadangan, bukan ditolak',
        () {
      final izin = Izin.fromJson(const {
        'boleh': ['alat.lihat'],
      });

      // Nama izinnya mungkin beda dari tebakan mobile. Nyembunyiin tombol yang
      // sebenarnya boleh lebih ngerepotin daripada nampilin tombol yang nanti
      // ditolak 403 dengan pesan jelas.
      expect(izin.bolehkah('tanda-tangan.kelola', cadangan: true), isTrue);
    });
  });

  group('Layar ngikut matriks peran', () {
    testWidgets('backend bilang BOLEH → layar kebuka walau role bukan admin',
        (tester) async {
      // Inti §2a: yang nentuin backend, bukan aturan hard-coded di mobile.
      // Token ini teknisi, tapi backend ngasih izinnya.
      await _pasang(
        tester,
        _app(
          izin: const Izin(
            role: UserRole.teknisi,
            boleh: {NamaIzin.tandaTanganKelola},
          ),
          token: 'mock-token-2',
        ),
      );

      expect(find.textContaining('Cuma admin'), findsNothing);
    });

    testWidgets('izin nggak disebut → jatuh ke aturan lama (admin boleh)',
        (tester) async {
      await _pasang(
        tester,
        _app(izin: const Izin(role: UserRole.admin, boleh: {'lain.lain'})),
      );

      expect(find.textContaining('Cuma admin'), findsNothing);
    });

    testWidgets('izin nggak disebut + bukan admin → tetap ditolak',
        (tester) async {
      await _pasang(
        tester,
        _app(
          izin: const Izin(role: UserRole.teknisi, boleh: {'lain.lain'}),
          token: 'mock-token-2',
        ),
      );

      expect(find.textContaining('Cuma admin'), findsOneWidget);
    });

    testWidgets('gagal ambil izin nggak ngunci layar buat admin',
        (tester) async {
      await _pasang(tester, _app(izin: Izin.kosong));

      // `ApiIzinService` nelan error jadi `Izin.kosong`. Admin harus tetap
      // bisa kerja — matriks peran itu penyempurnaan, bukan gerbang.
      expect(find.textContaining('Cuma admin'), findsNothing);
    });
  });
}
