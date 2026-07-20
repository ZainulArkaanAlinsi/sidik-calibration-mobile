import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/api_auth_service.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';

const _baseUrl = 'http://10.0.2.2:8000/api';

/// Bikin service yang nembak HTTP tiruan — jadi kita bisa mastiin bentuk
/// request & penanganan error-nya bener **tanpa perlu server Laravel nyala**.
ApiAuthService _service(
  Future<http.Response> Function(http.Request req) handler,
) {
  return ApiAuthService(
    ApiClient(client: MockClient(handler), baseUrl: _baseUrl),
  );
}

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

final _userAdmin = {
  'id': 1,
  'nama': 'Budi Santoso',
  'email': 'admin@pt-sidik.com',
  'employee_id': 'ASM-0001',
  'role': 'admin',
  'status': 'aktif',
  'department': 'Quality Control',
  'organization_id': 1,
};

void main() {
  group('login', () {
    test('ngirim `identifier` + password ke POST /login, balikin token', () async {
      late http.Request terkirim;

      final service = _service((req) async {
        terkirim = req;
        return _json({
          'data': {'token': '1|JpQDXLhSEz', 'user': _userAdmin},
        }, 200);
      });

      final sesi = await service.login(
        identifier: 'ASM-0001',
        password: 'rahasia123',
      );

      expect(terkirim.url.toString(), '$_baseUrl/login');
      expect(terkirim.method, 'POST');

      final body = jsonDecode(terkirim.body) as Map<String, dynamic>;
      // Kontraknya `identifier`, BUKAN `email` — ini yang paling gampang salah.
      expect(body['identifier'], 'ASM-0001');
      expect(body['password'], 'rahasia123');

      // Token Sanctum bentuknya `1|xxx`, bukan JWT.
      expect(sesi.token, '1|JpQDXLhSEz');
      expect(sesi.user.role, UserRole.admin);
      expect(sesi.user.employeeId, 'ASM-0001');
    });

    test('401 → pesan dari server dipakai apa adanya', () async {
      final service = _service(
        (_) async => _json(
          {'message': 'ID pegawai / email atau password salah.'},
          401,
        ),
      );

      await expectLater(
        service.login(identifier: 'ASM-0001', password: 'salah'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'ID pegawai / email atau password salah.',
          ),
        ),
      );
    });

    test('403 akun pending → pesannya nyampe ke user', () async {
      final service = _service(
        (_) async => _json({
          'message': 'Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya.',
        }, 403),
      );

      await expectLater(
        service.login(identifier: 'ASM-0099', password: 'rahasia123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('belum disetujui admin'),
          ),
        ),
      );
    });

    test('429 rate limit → pesan "tunggu sebentar", bukan error mentah', () async {
      // Backend batesin login 10x/menit. Tanpa penanganan ini, user cuma
      // lihat error teknis yang nggak ngasih tahu harus ngapain.
      final service = _service((_) async => http.Response('', 429));

      await expectLater(
        service.login(identifier: 'ASM-0001', password: 'rahasia123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Tunggu sebentar'),
          ),
        ),
      );
    });

    test('server balikin HTML (bukan JSON) → nggak crash, pesan tetap manusiawi', () async {
      final service = _service(
        (_) async => http.Response('<html>500 error</html>', 500),
      );

      await expectLater(
        service.login(identifier: 'ASM-0001', password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('register', () {
    test('NGGAK ngirim `role` — role ditentukan admin, bukan pendaftar', () async {
      late http.Request terkirim;

      final service = _service((req) async {
        terkirim = req;
        return _json({'message': 'Pendaftaran terkirim.'}, 201);
      });

      await service.register(
        const RegisterData(
          nama: 'Eko Prasetyo',
          employeeId: 'ASM-0099',
          department: 'Kalibrasi',
          email: 'eko@pt-sidik.com',
          password: 'rahasia123',
        ),
      );

      final body = jsonDecode(terkirim.body) as Map<String, dynamic>;
      expect(terkirim.url.toString(), '$_baseUrl/register');
      expect(body['employee_id'], 'ASM-0099');
      expect(
        body.containsKey('role'),
        isFalse,
        reason: 'kalau client bisa ngirim role, orang bisa daftar jadi admin',
      );
    });
  });

  group('me & logout', () {
    test('token dikirim sebagai Bearer di header', () async {
      late http.Request terkirim;

      final service = _service((req) async {
        terkirim = req;
        return _json({'data': _userAdmin}, 200);
      });

      final user = await service.me('1|JpQDXLhSEz');

      expect(terkirim.headers['Authorization'], 'Bearer 1|JpQDXLhSEz');
      expect(user.nama, 'Budi Santoso');
    });

    test('`/me` tanpa bungkus `data` juga diterima', () async {
      final service = _service((_) async => _json(_userAdmin, 200));

      final user = await service.me('1|token');
      expect(user.employeeId, 'ASM-0001');
    });
  });

  group('parsing yang gampang bikin crash', () {
    test('organization_id null → jangan crash (tabel organizations belum ada)', () {
      final user = User.fromJson({
        ..._userAdmin,
        'organization_id': null,
        'department': null,
      });

      expect(user.organizationId, isNull);
      expect(user.department, isNull);
      expect(user.nama, 'Budi Santoso');
    });

    test('status hilang → dianggap aktif, bukan ngunci semua orang', () {
      final json = Map<String, dynamic>.from(_userAdmin)..remove('status');

      expect(User.fromJson(json).status, UserStatus.aktif);
    });
  });
}
