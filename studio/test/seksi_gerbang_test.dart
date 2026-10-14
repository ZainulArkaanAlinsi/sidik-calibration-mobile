import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';

import 'pembantu/studio_uji.dart';

/// Penjaga gerbang seksi (tinjau S1 saran 4): seksi yang SUDAH dibuka
/// (`tahap == null`) selain Beranda wajib bergerbang izin server. Lupa
/// memasang gerbang waktu mengosongkan `tahap` = test ini merah, dan di
/// aplikasi seksinya tertutup untuk semua orang (gagal tertutup).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final dibuka = [
    for (final s in SeksiStudio.values)
      if (s.tersedia && s != SeksiStudio.beranda) s,
  ];

  test('setiap seksi tersedia selain Beranda menyebut nama izinnya', () {
    expect(dibuka, isNotEmpty);
    for (final s in dibuka) {
      expect(s.namaIzin, isNotNull, reason: '${s.name} tanpa gerbang izin');
    }
    expect(SeksiStudio.beranda.namaIzin, isNull);
  });

  for (final s in dibuka) {
    testWidgets('${s.name}: tanpa "${s.namaIzin}" tidak tampil; dengan '
        'izinnya tampil', (tester) async {
      await pasangUkuran(tester, const Size(1440, 900));

      // Server SUDAH menjawab (izin lain ada) tapi tidak menyebut izin ini.
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          izin: const Izin(role: UserRole.admin, boleh: {'lain.lihat'}),
        ),
      );
      await tenang(tester);
      expect(navigasi(s), findsNothing);
      expect(navigasi(SeksiStudio.beranda), findsOneWidget);

      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          izin: Izin(role: UserRole.viewer, boleh: {s.namaIzin!}),
        ),
      );
      await tenang(tester);
      expect(navigasi(s), findsOneWidget);
    });
  }

  testWidgets('seksi tahap mendatang tetap tampil NONAKTIF tanpa izin apa '
      'pun', (tester) async {
    await pasangUkuran(tester, const Size(1440, 900));
    await tester.pumpWidget(
      studioUji(
        meja: true,
        token: 'mock-token-1',
        izin: const Izin(role: UserRole.viewer, boleh: {'lain.lihat'}),
      ),
    );
    await tenang(tester);
    for (final s in SeksiStudio.values.where((s) => !s.tersedia)) {
      expect(navigasi(s), findsOneWidget, reason: s.name);
    }
  });
}
