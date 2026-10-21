import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/inti/penimpaan.dart';

/// Token Studio ditolak `/me`, `/me/permissions`, `/logout` (rute lab). Yang
/// dikunci: produksi (`penimpaanStudio` + `penimpaanSesiStudio`) memakai
/// `/studio/me` dan `/studio/logout`, dan tidak pernah menyentuh rute lab itu.
void main() {
  late HttpServer server;
  late List<String> jalurMasuk;
  late ProviderContainer wadah;

  setUp(() async {
    HttpOverrides.global = null;
    jalurMasuk = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      final jalur = req.uri.path.replaceFirst('/api', '');
      jalurMasuk.add('${req.method} $jalur');

      final (status, badan) = switch (jalur) {
        '/health' => (200, {'status': 'ok'}),
        '/studio/me' => (
          200,
          {
            'data': {
              'user': {
                'id': 7,
                'employee_id': 'SDK-0007',
                'nama': 'Pemilik Studio',
                'email': 'pemilik@sidik.test',
                'role': 'super_admin',
                'status': 'aktif',
              },
              'izin': {
                'role': 'studio',
                'boleh': ['workbook.lihat', 'data-acuan.lihat'],
                'batasan': <String, dynamic>{},
              },
            },
          },
        ),
        '/studio/logout' => (200, {'message': 'Berhasil keluar.'}),
        _ => (
          403,
          {
            'kode': 'bukan_aplikasi_ini',
            'message': 'Token ini bukan buat lab.',
          },
        ),
      };
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(badan));
      await req.response.close();
    });

    wadah = ProviderContainer(
      overrides: [
        ...penimpaanStudio,
        ...penimpaanSesiStudio,
        alamatServerStudioProvider.overrideWithValue(
          'http://127.0.0.1:${server.port}/api',
        ),
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('tok')),
      ],
    );
  });

  tearDown(() async {
    wadah.dispose();
    await server.close(force: true);
  });

  test(
    'sesi pulih, izin, dan keluar lewat /studio/*, bukan rute lab',
    () async {
      final akun = await wadah.read(authProvider.future);
      expect(akun?.email, 'pemilik@sidik.test');

      final izin = await wadah.read(izinProvider.future);
      expect(izin.boleh, {'workbook.lihat', 'data-acuan.lihat'});

      await wadah.read(authProvider.notifier).logout();

      expect(jalurMasuk.where((j) => !j.endsWith('/health')), [
        'GET /studio/me',
        'GET /studio/me',
        'POST /studio/logout',
      ]);
      expect(
        jalurMasuk.any((j) => j.endsWith(' /me') || j.contains('/me/')),
        isFalse,
      );
      expect(
        jalurMasuk.any((j) => j.endsWith('/logout') && !j.contains('studio')),
        isFalse,
      );
    },
  );
}
