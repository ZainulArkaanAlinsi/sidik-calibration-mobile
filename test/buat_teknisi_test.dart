import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/teknisi.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/technician_provider.dart';
import 'package:sidik_calibration/screens/settings/buat_teknisi_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/user_service.dart';
import 'package:sidik_calibration/widgets/app_text_field.dart';

const _baseUrl = 'http://10.0.2.2:8000/api';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Bentuk `TechnicianResource` di API (`app/Http/Resources/TechnicianResource.php`):
/// `id, nama, employee_id, email, department, status` + `jumlah_kalibrasi`
/// hanya kalau dihitung (tidak ada di jawaban `POST`).
const _jawabanPost = {
  'data': {
    'id': 12,
    'nama': 'Sari Wulandari',
    'employee_id': 'SDK-0010',
    'email': 'sari@pt-sidik.com',
    'department': null,
    'status': 'aktif',
  },
};

/// Hitung berapa kali daftar akun ditarik: bukti `userListProvider` benar-benar
/// dibuang sesudah akun dibuat, bukan kebetulan datanya mirip.
class _UserServiceHitung extends MockUserService {
  int jumlahDaftar = 0;

  @override
  Future<List<User>> daftar(String token, {String? status}) {
    jumlahDaftar++;
    return super.daftar(token, status: status);
  }
}

Widget _app(
  MockTechnicianService service, {
  String token = 'mock-token-1',
  UserService? userService,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      technicianServiceProvider.overrideWithValue(service),
      if (userService != null)
        userServiceProvider.overrideWithValue(userService),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BuatTeknisiScreen(),
    ),
  );
}

/// `MockAuthService` punya jeda 600 ms; `pumpAndSettle` tidak memajukan timer.
/// Layar tinggi supaya seluruh formulir terbangun tanpa digulung.
Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Finder _kolom(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

Future<void> _isi(
  WidgetTester tester, {
  String nama = 'Sari Wulandari',
  String employeeId = 'SDK-0010',
  String email = 'sari@pt-sidik.com',
  String password = 'sandiAwal123',
  String? ulang,
}) async {
  await tester.enterText(_kolom('Nama lengkap'), nama);
  await tester.enterText(_kolom('ID pegawai'), employeeId);
  await tester.enterText(_kolom('Email'), email);
  await tester.enterText(_kolom('Sandi awal'), password);
  await tester.enterText(_kolom('Ulangi sandi awal'), ulang ?? password);
}

Future<void> _kirim(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Buat akun'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buat akun'));
  await tester.pumpAndSettle();
}

void main() {
  group('Teknisi.fromJson', () {
    test('jawaban POST /technicians (tanpa jumlah_kalibrasi)', () {
      final t = Teknisi.fromJson(
        Map<String, dynamic>.from(_jawabanPost['data']! as Map),
      );

      expect(t.id, 12);
      expect(t.nama, 'Sari Wulandari');
      expect(t.employeeId, 'SDK-0010');
      expect(t.email, 'sari@pt-sidik.com');
      expect(t.status, UserStatus.aktif);
      expect(t.department, isNull);
      expect(t.jumlahKalibrasi, isNull);
    });

    test('jumlah_kalibrasi ikut terbaca kalau server menghitungnya', () {
      final t = Teknisi.fromJson({
        'id': 3,
        'nama': 'Eko',
        'employee_id': 'SDK-0002',
        'email': 'eko@pt-sidik.com',
        'department': 'Suhu',
        'status': 'nonaktif',
        'jumlah_kalibrasi': 7,
      });

      expect(t.jumlahKalibrasi, 7);
      expect(t.status, UserStatus.nonaktif);
      expect(t.department, 'Suhu');
    });
  });

  group('ApiTechnicianService', () {
    ApiTechnicianService service(
      Future<http.Response> Function(http.Request) handler,
    ) => ApiTechnicianService(
      ApiClient(client: MockClient(handler), baseUrl: _baseUrl),
    );

    test(
      'POST /technicians: hanya kolom yang diizinkan, tanpa role & status',
      () async {
        late http.Request terkirim;
        final s = service((req) async {
          terkirim = req;
          return _json(_jawabanPost, 201);
        });

        final t = await s.buat(
          'tkn-abc',
          nama: 'Sari Wulandari',
          employeeId: 'SDK-0010',
          email: 'sari@pt-sidik.com',
          password: 'sandiAwal123',
        );

        expect(terkirim.method, 'POST');
        expect(terkirim.url.toString(), '$_baseUrl/technicians');
        expect(terkirim.headers['Authorization'], 'Bearer tkn-abc');

        final body = jsonDecode(terkirim.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {'nama', 'employee_id', 'email', 'password'});
        // `TechnicianRequest` tidak menerima `role`, dan akun buatan admin
        // langsung aktif: keduanya tidak boleh dikirim dari app.
        expect(body.containsKey('role'), isFalse);
        expect(body.containsKey('status'), isFalse);
        expect(body['employee_id'], 'SDK-0010');
        expect(t.id, 12);
      },
    );

    test('departemen ikut dikirim hanya kalau diisi', () async {
      late Map<String, dynamic> body;
      final s = service((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(_jawabanPost, 201);
      });

      await s.buat(
        't',
        nama: 'Sari',
        employeeId: 'SDK-0010',
        email: 'sari@pt-sidik.com',
        password: 'sandiAwal123',
        department: 'Kalibrasi Suhu',
      );

      expect(body['department'], 'Kalibrasi Suhu');
    });

    test(
      '422 dari server: status dan errors per kolom sampai ke pemanggil',
      () async {
        final s = service(
          (req) async => _json({
            'message': 'Email ini sudah terdaftar.',
            'errors': {
              'email': ['Email ini sudah terdaftar.'],
            },
          }, 422),
        );

        await expectLater(
          s.buat(
            't',
            nama: 'Sari',
            employeeId: 'SDK-0010',
            email: 'sari@pt-sidik.com',
            password: 'sandiAwal123',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 422)
                .having(
                  (e) => e.message,
                  'message',
                  'Email ini sudah terdaftar.',
                )
                .having(
                  (e) => (e.body['errors'] as Map)['email'],
                  'errors.email',
                  ['Email ini sudah terdaftar.'],
                ),
          ),
        );
      },
    );

    test('403 untuk non-admin: pesan server dipakai apa adanya', () async {
      final s = service(
        (req) async =>
            _json({'message': 'Kamu nggak punya akses ke sini.'}, 403),
      );

      await expectLater(
        s.buat(
          't',
          nama: 'Sari',
          employeeId: 'SDK-0010',
          email: 'sari@pt-sidik.com',
          password: 'sandiAwal123',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having(
                (e) => e.message,
                'message',
                'Kamu nggak punya akses ke sini.',
              ),
        ),
      );
    });

    test(
      'POST tidak diulang otomatis: satu permintaan, bukan akun kembar',
      () async {
        var panggilan = 0;
        final s = service((req) async {
          panggilan++;
          return _json({'message': 'Server error'}, 503);
        });

        await expectLater(
          s.buat(
            't',
            nama: 'Sari',
            employeeId: 'SDK-0010',
            email: 'sari@pt-sidik.com',
            password: 'sandiAwal123',
          ),
          throwsA(isA<ApiException>()),
        );
        expect(panggilan, 1);
      },
    );
  });

  group('Layar Buat akun teknisi', () {
    // Token mock: 1 admin · 5 super admin (K-49-14: semua aksi admin).
    for (final (token, siapa) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super admin'),
    ]) {
      testWidgets('$siapa melihat formulir', (tester) async {
        await _pasang(tester, _app(MockTechnicianService(), token: token));

        expect(_kolom('Nama lengkap'), findsOneWidget);
        expect(find.text('Buat akun'), findsOneWidget);
        // Tidak ada pilihan role maupun status: server memaksa teknisi + aktif.
        expect(find.byType(DropdownButtonFormField<UserRole>), findsNothing);
      });
    }

    testWidgets('teknisi ditolak di layar (server tetap menjaga 403)', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(MockTechnicianService(), token: 'mock-token-2'),
      );

      expect(
        find.text('Cuma admin yang bisa bikin akun teknisi.'),
        findsOneWidget,
      );
      expect(find.byType(AppTextField), findsNothing);
    });

    testWidgets('formulir kosong ditolak di layar dan TIDAK menembak server', (
      tester,
    ) async {
      final service = MockTechnicianService();
      await _pasang(tester, _app(service));

      await _kirim(tester);

      expect(find.text('Nama wajib diisi.'), findsOneWidget);
      expect(find.text('ID pegawai wajib diisi.'), findsOneWidget);
      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(find.text('Sandi minimal 8 karakter.'), findsOneWidget);
      expect(service.dibuat, isEmpty);
    });

    // `AuthController::login` memperlakukan identifier ber-`@` sebagai EMAIL,
    // jadi ID pegawai ber-`@` tidak akan pernah bisa dipakai login.
    testWidgets(
      'ID pegawai memuat @ ditolak di layar dan TIDAK menembak server',
      (tester) async {
        final service = MockTechnicianService();
        await _pasang(tester, _app(service));

        await _isi(tester, employeeId: 'sari@lab');
        await _kirim(tester);

        expect(
          find.text(
            'ID pegawai tidak boleh memuat @. Saat login, tanda @ dibaca sebagai email.',
          ),
          findsOneWidget,
        );
        expect(service.dibuat, isEmpty);
        // Isian lain tidak hilang.
        expect(
          tester.widget<TextField>(_kolom('Nama lengkap')).controller!.text,
          'Sari Wulandari',
        );

        // Dibetulkan → lolos.
        await _isi(tester, employeeId: 'SDK-0010');
        await _kirim(tester);
        expect(service.dibuat, hasLength(1));
      },
    );

    testWidgets('email ngawur, sandi pendek, dan sandi beda ditolak', (
      tester,
    ) async {
      final service = MockTechnicianService();
      await _pasang(tester, _app(service));

      await _isi(
        tester,
        email: 'bukan-email',
        password: 'pendek',
        ulang: 'pendek',
      );
      await _kirim(tester);
      expect(find.text('Format email belum benar.'), findsOneWidget);
      expect(find.text('Sandi minimal 8 karakter.'), findsOneWidget);

      await _isi(tester, password: 'sandiAwal123', ulang: 'sandiBeda123');
      await _kirim(tester);
      expect(find.text('Kedua sandi belum sama.'), findsOneWidget);
      expect(service.dibuat, isEmpty);
    });

    testWidgets(
      'berhasil: akun dibuat, form dikosongkan, sandi tidak pernah tampil',
      (tester) async {
        final service = MockTechnicianService();
        await _pasang(tester, _app(service));

        await _isi(tester);
        await _kirim(tester);

        expect(service.dibuat, hasLength(1));
        expect(service.dibuat.single.nama, 'Sari Wulandari');
        expect(service.dibuat.single.employeeId, 'SDK-0010');
        expect(service.passwordTerakhir, 'sandiAwal123');

        // Banner konfirmasi menyebut nama + ID pegawai, BUKAN sandi.
        expect(
          find.textContaining(
            'Akun teknisi Sari Wulandari dibuat (ID pegawai SDK-0010)',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('sandiAwal123'), findsNothing);

        // Semua kolom, termasuk kedua kolom sandi, kosong lagi.
        for (final label in [
          'Nama lengkap',
          'ID pegawai',
          'Email',
          'Sandi awal',
          'Ulangi sandi awal',
        ]) {
          expect(
            tester.widget<TextField>(_kolom(label)).controller!.text,
            isEmpty,
            reason: label,
          );
        }
      },
    );

    testWidgets(
      'ID pegawai kembar: 422 dipetakan ke kolomnya, isian tidak hilang',
      (tester) async {
        final service = MockTechnicianService();
        await _pasang(tester, _app(service));

        // SDK-0001 sudah dipakai akun Budi di data contoh.
        await _isi(tester, employeeId: 'SDK-0001');
        await _kirim(tester);

        expect(find.text('ID pegawai ini sudah terdaftar.'), findsOneWidget);
        expect(service.dibuat, isEmpty);
        // Jangan bikin admin mengetik ulang semuanya.
        expect(
          tester.widget<TextField>(_kolom('Nama lengkap')).controller!.text,
          'Sari Wulandari',
        );
        expect(find.textContaining('Akun teknisi'), findsNothing);
      },
    );

    testWidgets('server tak terjangkau: pesan gagal, isian tetap ada', (
      tester,
    ) async {
      final service = MockTechnicianService(gagal: true);
      await _pasang(tester, _app(service));

      await _isi(tester);
      await _kirim(tester);

      expect(find.text('Akun belum dibuat. Coba lagi.'), findsOneWidget);
      expect(
        tester.widget<TextField>(_kolom('Email')).controller!.text,
        'sari@pt-sidik.com',
      );
    });

    testWidgets(
      'daftar akun di Data Teknisi ditarik ulang sesudah akun dibuat',
      (tester) async {
        final users = _UserServiceHitung();
        final service = MockTechnicianService();
        await _pasang(tester, _app(service, userService: users));

        // Daftar akun "sedang dibuka" di tempat lain.
        final wadah = ProviderScope.containerOf(
          tester.element(find.byType(BuatTeknisiScreen)),
        );
        final langganan = wadah.listen(userListProvider, (_, _) {});
        addTearDown(langganan.close);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        final sebelum = users.jumlahDaftar;
        expect(sebelum, greaterThan(0));

        await _isi(tester);
        await _kirim(tester);
        await tester.pumpAndSettle();

        expect(users.jumlahDaftar, greaterThan(sebelum));
      },
    );
  });
}
