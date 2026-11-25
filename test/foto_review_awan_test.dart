import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/panel_usulan_ocr_awan.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';
import 'package:sidik_calibration/services/saran_ocr_awan.dart';

import 'support/layar_review_awan_contoh.dart';

/// Layar review dengan usulan OCR awan di baliknya (kontrak 22B).
///
/// Yang dibuktikan di sini bukan akurasi awan, tetapi PERILAKU layar:
/// 1. tanpa penerus usulan, layar identik dengan sebelumnya;
/// 2. usulan TIDAK mengisi sel apa pun sampai teknisi memutuskan per sel;
/// 3. sel yang awan lihat kosong/sampah tetap kosong;
/// 4. SETIAP kegagalan jatuh ke jalur lama tanpa crash dan tanpa sel terisi.
void main() {
  late List<BarisReviewFoto> baris;

  setUp(() => baris = barisReviewContoh());

  String kunciBaris(int i) =>
      kunciSelFoto(baris[i].titikUkur, baris[i].repeatNo, baris[i].fieldId);

  Future<void> buka(WidgetTester tester, {PemintaUsulanAwan? minta}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 3200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: FotoReviewScreen(
          baris: baris,
          mintaUsulanAwan: minta,
          kunciServerPerBaris: kunciServerContoh(baris),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Isi keempat kotak sel, urutan kertas.
  List<String> isi(WidgetTester tester) => [
    for (final t in tester.widgetList<TextField>(find.byType(TextField)))
      t.controller!.text,
  ];

  Future<MockOcrAwanSelService> bukaDenganMock(
    WidgetTester tester, {
    MockOcrAwanSelService? mock,
  }) async {
    final service = mock ?? MockOcrAwanSelService(hasil: hasilAwanContoh());
    await buka(tester, minta: pemintaContoh(penjalurContoh(service), baris));

    return service;
  }

  Future<void> ketukMinta(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('minta-usulan-awan')));
    await tester.pumpAndSettle();
  }

  const awal = ['', '7,00', '', ''];

  group('tanpa penerus usulan', () {
    testWidgets('layar tidak punya tombol, keterangan, atau panel awan', (
      tester,
    ) async {
      await buka(tester);

      expect(find.byKey(const ValueKey('minta-usulan-awan')), findsNothing);
      expect(
        find.byKey(const ValueKey('usulan-awan-keterangan')),
        findsNothing,
      );
      expect(find.byType(PanelUsulanOcrAwan), findsNothing);
      expect(find.textContaining('awan'), findsNothing);
      expect(isi(tester), awal);
    });
  });

  group('usulan awan', () {
    testWidgets('tombol + keterangan privasi tampil; belum ada permintaan', (
      tester,
    ) async {
      final service = await bukaDenganMock(tester);

      expect(find.byKey(const ValueKey('minta-usulan-awan')), findsOneWidget);
      expect(find.text('Minta usulan awan'), findsOneWidget);
      expect(
        find.textContaining('Hanya potongan gambar sel angka'),
        findsOneWidget,
      );
      expect(find.byType(PanelUsulanOcrAwan), findsNothing);
      expect(service.permintaan, isEmpty, reason: 'tidak otomatis');
      expect(isi(tester), awal);
    });

    testWidgets('ketukan: satu permintaan 4 potongan, TIDAK ada sel terisi', (
      tester,
    ) async {
      final service = await bukaDenganMock(tester);

      await ketukMinta(tester);

      expect(service.permintaan, [
        [kunciA, kunciB, kunciC, kunciD],
      ]);
      expect(service.konteksDiterima.single.kertas, 'asli');
      expect(service.konteksDiterima.single.templateId, 'ph_meter_0515');

      expect(find.byType(PanelUsulanOcrAwan), findsOneWidget);
      expect(find.byKey(const ValueKey('usulan-$kunciA')), findsOneWidget);
      expect(find.byKey(const ValueKey('usulan-$kunciB')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tanpa-usulan-$kunciC')),
        findsOneWidget,
        reason: 'awan melihat sel kosong: tidak ada usulan',
      );
      expect(
        find.byKey(const ValueKey('tanpa-usulan-$kunciD')),
        findsOneWidget,
        reason: 'awan membaca sampah: tidak ada usulan',
      );

      // Inti aturannya: usulan tiba, kotak sel TIDAK berubah.
      expect(isi(tester), awal);
      // Tombol hilang: satu putaran per layar.
      expect(find.byKey(const ValueKey('minta-usulan-awan')), findsNothing);
    });

    testWidgets('tidak ada "terima semua" dalam bentuk apa pun', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      final terlarang = RegExp(
        r'(terima|pakai|setujui|konfirmasi|isi)\s+semua',
        caseSensitive: false,
      );
      final teks = tester.widgetList<Text>(find.byType(Text));

      expect(
        teks.where((t) => terlarang.hasMatch(t.data ?? '')),
        isEmpty,
        reason: 'Tiap sel diputuskan satu per satu.',
      );
    });

    testWidgets('Pakai mengisi HANYA sel itu dan menandainya sudah dicek', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      final cekB = find.byKey(ValueKey('cek-${kunciBaris(1)}'));
      final sebelum = tester.widget<IconButton>(cekB).tooltip;

      await tester.tap(find.byKey(const ValueKey('usulan-pakai-$kunciB')));
      await tester.pumpAndSettle();

      expect(isi(tester), ['', '7,02', '', ''], reason: 'A, C, D tetap kosong');
      expect(
        tester.widget<IconButton>(cekB).tooltip,
        isNot(sebelum),
        reason: 'sel kuning yang diputuskan = sudah dilihat teknisi',
      );

      await tester.tap(find.byKey(const ValueKey('usulan-pakai-$kunciA')));
      await tester.pumpAndSettle();

      expect(isi(tester), ['4,01', '7,02', '', '']);
    });

    testWidgets('Batalkan setelah Pakai memulihkan isi dan status cek', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      final cekB = find.byKey(ValueKey('cek-${kunciBaris(1)}'));
      final sebelum = tester.widget<IconButton>(cekB).tooltip;

      await tester.tap(find.byKey(const ValueKey('usulan-pakai-$kunciB')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('usulan-kembalikan-$kunciB')));
      await tester.pumpAndSettle();

      expect(isi(tester), awal);
      expect(tester.widget<IconButton>(cekB).tooltip, sebelum);
    });

    testWidgets('Tolak sel yang belum dipakai tidak menyentuh kotaknya', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      await tester.tap(find.byKey(const ValueKey('usulan-tolak-$kunciA')));
      await tester.pumpAndSettle();

      expect(isi(tester), awal);
    });

    testWidgets('Ubah mengisi angka teknisi, bukan angka awan', (tester) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      await tester.tap(find.byKey(const ValueKey('usulan-ubah-$kunciA')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('usulan-isian-$kunciA')),
        '4,05',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('usulan-simpan-$kunciA')));
      await tester.pumpAndSettle();

      expect(isi(tester), ['4,05', '7,00', '', '']);
    });

    testWidgets('teks yang sudah diubah teknisi tidak ditimpa saat Batalkan', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      await tester.tap(find.byKey(const ValueKey('usulan-pakai-$kunciA')));
      await tester.pumpAndSettle();

      // Teknisi mengetik langsung di kotak sel sesudah Pakai.
      await tester.enterText(find.byType(TextField).first, '4,02');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('usulan-kembalikan-$kunciA')));
      await tester.pumpAndSettle();

      expect(isi(tester).first, '4,02');
    });

    testWidgets('tombol Masukkan tetap mati selama sel merah masih kosong', (
      tester,
    ) async {
      await bukaDenganMock(tester);
      await ketukMinta(tester);

      // A dan B diputuskan teknisi. C dan D merah dan tetap kosong: tidak ada
      // jalan pintas dari awan.
      for (final k in [kunciA, kunciB]) {
        await tester.tap(find.byKey(ValueKey('usulan-pakai-$k')));
        await tester.pumpAndSettle();
      }
      expect(isi(tester), ['4,01', '7,02', '', '']);

      final tombol = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Masukkan ke lembar'),
      );

      expect(tombol.onPressed, isNull);
    });
  });

  group('SETIAP kegagalan jatuh ke jalur lama', () {
    GalatOcrAwan coded(int status, String kode) => GalatOcrAwan.dariRespons(
      ApiException(
        'x',
        status: status,
        body: {'kode': kode, 'fallback_manual': true},
      ),
    )!;

    final kasus = <String, Object>{
      '503 fitur_dimatikan': coded(503, 'fitur_dimatikan'),
      '503 ocr_cloud_belum_aktif': coded(503, 'ocr_cloud_belum_aktif'),
      '503 ocr_cloud_belum_disetel': coded(503, 'ocr_cloud_belum_disetel'),
      '401': const ApiException('x', status: 401),
      '403': const ApiException('x', status: 403),
      '422': const ApiException('x', status: 422),
      '429': const ApiException('x', status: 429),
      '502': coded(502, 'ocr_cloud_gagal'),
      '500': const ApiException('x', status: 500),
      'timeout': TimeoutException('lama'),
      'tanpa jaringan': const SocketException('putus'),
      'galat tak dikenal': StateError('bug'),
    };

    kasus.forEach((nama, galat) {
      testWidgets('$nama: pesan tampil, nol sel terisi, bisa lanjut manual', (
        tester,
      ) async {
        final service = await bukaDenganMock(
          tester,
          mock: MockOcrAwanSelService(galat: galat),
        );

        await ketukMinta(tester);

        expect(tester.takeException(), isNull);
        expect(
          service.permintaan,
          hasLength(1),
          reason: 'tanpa ulang otomatis',
        );
        expect(find.byKey(const ValueKey('usulan-awan-gagal')), findsOneWidget);
        expect(find.byType(PanelUsulanOcrAwan), findsNothing);

        // Tidak ada sel yang terisi, dan layar lama tetap berfungsi penuh.
        expect(isi(tester), awal);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Masukkan ke lembar'),
              )
              .onPressed,
          isNull,
          reason: 'sel merah masih wajib diisi tangan',
        );

        // Teknisi tetap bisa mengetik, dan boleh mencoba lagi.
        await tester.enterText(find.byType(TextField).first, '4,00');
        await tester.pumpAndSettle();
        expect(isi(tester).first, '4,00');
        expect(find.byKey(const ValueKey('minta-usulan-awan')), findsOneWidget);
      });
    });

    testWidgets('mencoba lagi sesudah gagal total memakai jatah baru', (
      tester,
    ) async {
      var n = 0;
      final service = MockOcrAwanSelService(
        penjawab: (sel) {
          n++;
          if (n == 1) throw const ApiException('x', status: 429);
          return hasilAwanContoh();
        },
      );
      await bukaDenganMock(tester, mock: service);

      await ketukMinta(tester);
      expect(find.byKey(const ValueKey('usulan-awan-gagal')), findsOneWidget);

      await ketukMinta(tester);
      expect(service.permintaan, hasLength(2));
      expect(find.byType(PanelUsulanOcrAwan), findsOneWidget);
      expect(isi(tester), awal);
    });
  });

  group('layar ditutup saat permintaan berjalan', () {
    testWidgets('permintaan dibatalkan dan tidak ada galat setelahnya', (
      tester,
    ) async {
      final selesai = Completer<HasilSaranAwan>();
      bool Function()? cekBatal;

      await buka(
        tester,
        minta: ({onKemajuan, dibatalkan}) {
          cekBatal = dibatalkan;

          return selesai.future;
        },
      );

      await tester.tap(find.byKey(const ValueKey('minta-usulan-awan')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('usulan-awan-kemajuan')),
        findsOneWidget,
      );
      expect(cekBatal!(), isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(cekBatal!(), isTrue, reason: 'penjalur berhenti antre');

      selesai.complete(
        const HasilSaranAwan(sebabGagal: SebabGagalSaranAwan.jaringan),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('penerus yang melempar tetap dianggap awan tidak tersedia', (
      tester,
    ) async {
      await buka(
        tester,
        minta: ({onKemajuan, dibatalkan}) async => throw StateError('bug'),
      );

      await ketukMinta(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('usulan-awan-gagal')), findsOneWidget);
      expect(isi(tester), awal);
    });
  });
}
