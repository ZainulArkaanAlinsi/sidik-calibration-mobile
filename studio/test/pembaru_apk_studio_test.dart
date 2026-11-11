import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';
import 'package:sidik_calibration/services/versi_service.dart';
import 'package:sidik_studio/data/versi_api_studio.dart';
import 'package:sidik_studio/widget/pembaru_apk_studio.dart';

import 'pembantu/studio_uji.dart';

/// Pembaru APK Studio (Android): banner muncul bila ada APK Studio yang lebih
/// baru, hilang bila sama, dan diam bila cek gagal. Skema versinya Studio
/// (`0.1.NNN`), bukan tag app lapangan (`1.0.NNN`).

const _rilis = VersiAplikasi(
  versi: '0.1.200',
  urlUnduh: 'https://contoh/sidik-studio-0.1.200.apk',
  ukuran: 55 * 1024 * 1024,
  build: 200,
  tag: 'v1.0.200+200',
);

/// Tidak pernah mengunduh apa pun: test ini bukan tentang jaringan/berkas.
class _PenyiapPalsu implements PenyiapUpdate {
  @override
  Future<File?> apkSiap(String versi) async => null;

  @override
  Future<bool> siapkan(VersiAplikasi rilis) async => false;
}

/// Menghitung berapa kali server ditanya, dan jawabannya bisa diganti.
class _VersiBerhitung implements VersiService {
  _VersiBerhitung({required this.terpasang, this.terbaru});

  final String terpasang;
  VersiAplikasi? terbaru;
  int panggilan = 0;

  @override
  Future<String> versiTerpasang() async => terpasang;

  @override
  Future<String> buildTerpasang() async => '1';

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    panggilan++;
    return terbaru;
  }
}

/// Mencatat path yang diminta tanpa menyentuh jaringan.
class _ApiPalsu extends ApiClient {
  _ApiPalsu(this.jawaban);

  final Map<String, dynamic> Function() jawaban;
  final List<String> diminta = [];

  @override
  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    diminta.add(path);
    return jawaban();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pasang(
    WidgetTester tester, {
    required VersiService versi,
    bool aktif = true,
    Duration jeda = const Duration(hours: 1),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          versiServiceProvider.overrideWithValue(versi),
          penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu()),
          pembaruApkStudioAktifProvider.overrideWithValue(aktif),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                PembaruApkStudio(jeda: jeda),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('banner', () {
    testWidgets('muncul saat versi di server lebih baru', (tester) async {
      await pasang(
        tester,
        versi: _VersiBerhitung(terpasang: '0.1.150', terbaru: _rilis),
      );

      expect(find.text('Versi 0.1.200 sudah tersedia'), findsOneWidget);
      expect(find.byKey(const Key('banner_update_pasang')), findsOneWidget);
    });

    testWidgets('muncul walau terpasang masih build lokal 0.1.0', (
      tester,
    ) async {
      // APK debug/lokal berversi pubspec 0.1.0: harus ditawari rilis CI.
      await pasang(
        tester,
        versi: _VersiBerhitung(terpasang: '0.1.0', terbaru: _rilis),
      );

      expect(find.text('Versi 0.1.200 sudah tersedia'), findsOneWidget);
    });

    testWidgets('hilang saat versi sama', (tester) async {
      await pasang(
        tester,
        versi: _VersiBerhitung(terpasang: '0.1.200', terbaru: _rilis),
      );

      expect(find.textContaining('sudah tersedia'), findsNothing);
      expect(find.byKey(const Key('banner_update_pasang')), findsNothing);
    });

    testWidgets('hilang saat terpasang lebih baru dari server', (tester) async {
      await pasang(
        tester,
        versi: _VersiBerhitung(terpasang: '0.1.1000', terbaru: _rilis),
      );

      // 0.1.1000 > 0.1.200 secara ANGKA; perbandingan teks akan terbalik.
      expect(find.textContaining('sudah tersedia'), findsNothing);
    });

    testWidgets('diam saat server belum punya APK Studio (null)', (
      tester,
    ) async {
      await pasang(tester, versi: _VersiBerhitung(terpasang: '0.1.1'));

      expect(find.textContaining('sudah tersedia'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('diam saat cek gagal (melempar)', (tester) async {
      await pasang(
        tester,
        versi: MockVersiService(terpasang: '0.1.1', gagal: true),
      );

      expect(find.textContaining('sudah tersedia'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tidak aktif (Windows/desktop): server tidak ditanya', (
      tester,
    ) async {
      final versi = _VersiBerhitung(terpasang: '0.1.1', terbaru: _rilis);

      await pasang(tester, versi: versi, aktif: false);

      expect(versi.panggilan, 0);
      expect(find.textContaining('sudah tersedia'), findsNothing);
    });

    testWidgets('dicek ulang berkala: rilis yang baru terbit ikut muncul', (
      tester,
    ) async {
      final versi = _VersiBerhitung(terpasang: '0.1.150');
      await pasang(tester, versi: versi, jeda: const Duration(minutes: 10));
      expect(versi.panggilan, 1);
      expect(find.textContaining('sudah tersedia'), findsNothing);

      versi.terbaru = _rilis;
      await tester.pump(const Duration(minutes: 10));
      await tester.pump();
      await tester.pump();

      expect(versi.panggilan, 2);
      expect(find.text('Versi 0.1.200 sudah tersedia'), findsOneWidget);
    });
  });

  group('ApiVersiServiceStudio', () {
    test('bertanya ?aplikasi=studio, bukan jalur app lapangan', () async {
      final api = _ApiPalsu(
        () => {
          'tersedia': true,
          'versi': '0.1.200',
          'url_unduh': 'https://contoh/sidik-studio-0.1.200.apk',
          'build': 200,
          'tag': 'v1.0.200+200',
          'ukuran': 100,
        },
      );
      final layanan = ApiVersiServiceStudio(
        api,
        terpasang: _VersiBerhitung(terpasang: '0.1.5'),
      );

      final terbaru = await layanan.versiTerbaru();

      expect(api.diminta, ['/app/versi-terbaru?aplikasi=studio']);
      expect(terbaru?.versi, '0.1.200');
      expect(await layanan.versiTerpasang(), '0.1.5');
      // Skema Studio, bukan tag 1.0.200: tidak boleh tampak "tertinggal"
      // hanya karena 0.1.x < 1.0.x.
      expect(terbaru!.lebihBaruDari('0.1.5'), isTrue);
      expect(terbaru.lebihBaruDari('0.1.200'), isFalse);
    });

    test('tersedia:false dan galat jadi null, tidak melempar', () async {
      final kosong = ApiVersiServiceStudio(
        _ApiPalsu(() => {'tersedia': false}),
        terpasang: _VersiBerhitung(terpasang: '0.1.5'),
      );
      expect(await kosong.versiTerbaru(), isNull);

      final rusak = ApiVersiServiceStudio(
        _ApiPalsu(() => throw Exception('offline')),
        terpasang: _VersiBerhitung(terpasang: '0.1.5'),
      );
      expect(await rusak.versiTerbaru(), isNull);
    });
  });

  group('cangkang', () {
    testWidgets('Android: banner tampil di cangkang Studio', (tester) async {
      await pasangUkuran(tester, const Size(1280, 800));

      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          tambahan: [
            versiServiceProvider.overrideWithValue(
              _VersiBerhitung(terpasang: '0.1.150', terbaru: _rilis),
            ),
            penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu()),
            pembaruApkStudioAktifProvider.overrideWithValue(true),
          ],
        ),
      );
      await tenang(tester);

      expect(find.text('Versi 0.1.200 sudah tersedia'), findsOneWidget);
    });

    testWidgets('Windows/desktop: tidak ada banner APK', (tester) async {
      await pasangUkuran(tester, const Size(1280, 800));

      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          tambahan: [
            versiServiceProvider.overrideWithValue(
              _VersiBerhitung(terpasang: '0.1.150', terbaru: _rilis),
            ),
          ],
        ),
      );
      await tenang(tester);

      expect(find.textContaining('sudah tersedia'), findsNothing);
    });
  });
}
