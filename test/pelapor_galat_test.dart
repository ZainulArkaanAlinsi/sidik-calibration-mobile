import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/pelapor_galat.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/services/pesan_galat_pindai.dart';

class _PelaporRekam extends PelaporGalat {
  final rekaman = <({Object galat, String? konteks, bool fatal})>[];

  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) => rekaman.add((galat: galat, konteks: konteks, fatal: fatal));
}

void main() {
  late void Function(FlutterErrorDetails)? onErrorAsal;
  late ErrorWidgetBuilder builderAsal;
  late bool Function(Object, StackTrace)? platformAsal;
  late PelaporGalat pelaporAsal;

  setUp(() {
    onErrorAsal = FlutterError.onError;
    builderAsal = ErrorWidget.builder;
    platformAsal =
        TestWidgetsFlutterBinding.instance.platformDispatcher.onError;
    pelaporAsal = pelaporGalat;
  });

  tearDown(() {
    FlutterError.onError = onErrorAsal;
    ErrorWidget.builder = builderAsal;
    TestWidgetsFlutterBinding.instance.platformDispatcher.onError =
        platformAsal;
    pelaporGalat = pelaporAsal;
  });

  test('pesan galat TIDAK ikut ke laporan — cuma jenisnya', () {
    const rahasia = FormatException('bacaan 12,5 milik PT Pelanggan');
    final t = GalatTersaring.dari(rahasia);
    expect(t.toString(), 'FormatException');
    expect(t.toString(), isNot(contains('12,5')));
  });

  test('pelapor diam (debug/desktop) mencetak pesan + tumpukan LENGKAP', () {
    final cetak = <String>[];
    final asal = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => cetak.add(m ?? '');
    try {
      const PelaporGalatDiam().catat(
        StateError('rinci'),
        StackTrace.fromString('#0 fungsiUji'),
        konteks: 'async',
      );
    } finally {
      debugPrint = asal;
    }
    expect(cetak.join(' '), contains('rinci'));
    expect(cetak.join(' '), contains('fungsiUji'));
  });

  test('galat framework & async diteruskan ke pelapor sebagai non-fatal', () {
    final rekam = _PelaporRekam();
    // Penangan sebelumnya ditiru supaya test tidak memicu kegagalan test.
    FlutterError.onError = (_) {};
    pasangPenangkapGalat(pelapor: rekam, kartuRamah: false);

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('x'), library: 'widgets'),
    );
    final ditangani = TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .onError!(StateError('y'), StackTrace.current);

    expect(ditangani, isTrue, reason: 'aplikasi jalan terus');
    expect(rekam.rekaman, hasLength(2));
    expect(rekam.rekaman.every((r) => !r.fatal), isTrue);
    expect(rekam.rekaman.first.konteks, 'flutter:widgets');
    expect(rekam.rekaman.last.konteks, 'async');
  });

  testWidgets('widget yang gagal dibangun tampil sebagai kartu ramah', (
    tester,
  ) async {
    // Penangan & ErrorWidget.builder milik binding test dipulihkan sebelum
    // test selesai (binding memeriksanya); penangan kita memanggilnya duluan, jadi galat build
    // tetap tertangkap `takeException`.
    final onErrorTest = FlutterError.onError;
    final builderTest = ErrorWidget.builder;
    final rekam = _PelaporRekam();
    pasangPenangkapGalat(pelapor: rekam, kartuRamah: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: (_) => throw 'gagal')),
      ),
    );
    FlutterError.onError = onErrorTest;

    expect(tester.takeException(), isNotNull);
    expect(find.text(KartuGalatRamah.pesan), findsOneWidget);
    expect(rekam.rekaman, isNotEmpty);
    ErrorWidget.builder = builderTest;
  });

  test(
    'OutOfMemoryError (lokal / dari isolate) → pesan foto terlalu besar',
    () {
      final l10n = AppLocalizationsId();
      for (final e in <Object>[
        OutOfMemoryError(),
        RemoteError('Out of Memory', ''),
      ]) {
        expect(golongkanGalatPindai(e), GolonganGalatPindai.memoriHabis);
        expect(
          pesanGalatPindai(l10n, e, umum: 'umum'),
          'Foto terlalu besar untuk HP ini, coba foto ulang.',
        );
      }
    },
  );
}
