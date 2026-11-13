import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/calibration/kamera_pindai_screen.dart';
import 'package:sidik_calibration/services/kamera_pindai.dart';
import 'package:sidik_calibration/services/petunjuk_kamera.dart';

import 'support/kontrol_kamera_palsu.dart';

/// Layar kamera sendiri dengan kamera TIRUAN (plugin `camera` tidak jalan di
/// host). Yang diuji: kontrak layar — tombol senter ada/tidak, petunjuk, jepret
/// mengembalikan berkas, kamera dilepas di setiap jalan keluar, dan jalan
/// cadangan (izin ditolak / gagal inisialisasi).

class _Hasil {
  HasilKamera? nilai;
  bool selesai = false;
}

void main() {
  const selang = Duration(milliseconds: 100);

  /// Pasang tombol "buka" yang membuka layar kamera lewat [bukaKameraPindai]
  /// (kontrak yang sama dengan `sumberFotoProvider`), lalu tekan.
  Future<_Hasil> buka(
    WidgetTester tester, {
    required PabrikKontrolKamera pabrik,
    double? rasio,
  }) async {
    final hasil = _Hasil();
    // HP tegak (390×844 dp) — tata letak utama; lanskap/tablet diuji di
    // `kamera_pindai_desain_test.dart`.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  hasil.nilai = await navigatorUntuk(
                    context,
                    pabrik: pabrik,
                    rasio: rasio,
                  );
                  hasil.selesai = true;
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pump(); // rute dipasang + pabrik mulai
    await tester.pump(); // pabrik selesai
    await tester.pump(const Duration(milliseconds: 400)); // transisi

    return hasil;
  }

  /// Pabrik yang selalu memberi [kontrol] yang sama dan menghitung pembukaan.
  ({PabrikKontrolKamera pabrik, List<int> dibuka}) pabrikTetap(
    KontrolKameraPalsu kontrol,
  ) {
    final dibuka = <int>[];

    return (
      pabrik: () async {
        dibuka.add(dibuka.length + 1);

        return kontrol;
      },
      dibuka: dibuka,
    );
  }

  group('senter', () {
    testWidgets('perangkat TANPA senter: tombol disembunyikan', (tester) async {
      final k = KontrolKameraPalsu(punyaSenter: false);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);

      expect(find.byKey(const ValueKey('kamera-jepret')), findsOneWidget);
      expect(find.byKey(const ValueKey('kamera-senter')), findsNothing);
    });

    testWidgets(
      'perangkat dengan senter: tombol ada, menyalakan lalu mematikan',
      (tester) async {
        final k = KontrolKameraPalsu();
        await buka(tester, pabrik: pabrikTetap(k).pabrik);

        final tombol = find.byKey(const ValueKey('kamera-senter'));
        expect(tombol, findsOneWidget);
        expect(find.byTooltip('Nyalakan senter'), findsOneWidget);

        await tester.tap(tombol);
        await tester.pump();
        expect(k.nyala, isTrue);
        expect(find.byTooltip('Matikan senter'), findsOneWidget);

        await tester.tap(tombol);
        await tester.pump();
        expect(k.nyala, isFalse);
        expect(k.aturSenterDipanggil, [true, false]);
      },
    );

    testWidgets('senter menolak dinyalakan: tombol hilang + pesan jelas', (
      tester,
    ) async {
      final k = KontrolKameraPalsu(senterMenolak: true, bisaContoh: false);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);

      await tester.tap(find.byKey(const ValueKey('kamera-senter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('kamera-senter')), findsNothing);
      expect(find.byKey(const ValueKey('kamera-pesan')), findsOneWidget);
      expect(find.textContaining('tidak punya senter'), findsOneWidget);
      expect(k.nyala, isFalse);

      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('kamera-pesan')), findsNothing);
    });
  });

  group('jalan cadangan (kamera sendiri tak bisa dipakai)', () {
    testWidgets(
      'izin ditolak: layar TIDAK menutup sendiri, tampil keadaan izin '
      '(langkah berikutnya + Coba lagi; TANPA jalan ke kamera sistem)',
      (tester) async {
        final hasil = await buka(
          tester,
          pabrik: () async => throw const KameraGagal(
            SebabKameraGagal.izinDitolak,
            'CameraAccessDenied',
          ),
        );
        await tester.pumpAndSettle();

        expect(hasil.selesai, isFalse);
        expect(find.byKey(const ValueKey('kamera-izin')), findsOneWidget);
        expect(find.text('Izin kamera diperlukan'), findsOneWidget);
        expect(
          find.textContaining('Pengaturan HP'),
          findsOneWidget,
          reason: 'langkah berikutnya bila dialog izin tidak muncul lagi',
        );
        final langkah = tester
            .widget<Text>(find.textContaining('Pengaturan HP'))
            .data!;
        // Jalur manual lengkap, urut: Pengaturan → Aplikasi → app → Izin.
        final pos = [
          'Pengaturan HP',
          'Aplikasi',
          'PT Sidik Calibration',
          'Izin.',
        ].map(langkah.indexOf).toList();
        expect(pos, everyElement(greaterThanOrEqualTo(0)), reason: langkah);
        expect(pos, orderedEquals([...pos]..sort()), reason: 'urutan jalur');
        expect(find.byKey(const ValueKey('kamera-coba-lagi')), findsOneWidget);
        expect(
          find.text('Pakai kamera sistem'),
          findsNothing,
          reason: 'image_picker butuh izin yang sama → jalan buntu',
        );
        expect(find.byType(TextButton), findsNothing);
        expect(find.byKey(const ValueKey('kamera-jepret')), findsNothing);
      },
    );

    testWidgets('izin ditolak → "Coba lagi": kamera dibuka ulang dan, bila '
        'kini diizinkan, pratinjau tampil', (tester) async {
      var panggilan = 0;
      final k = KontrolKameraPalsu();
      await buka(
        tester,
        pabrik: () async {
          panggilan++;
          if (panggilan == 1) {
            throw const KameraGagal(SebabKameraGagal.izinDitolak);
          }

          return k;
        },
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kamera-izin')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kamera-coba-lagi')));
      await tester.pump();
      await tester.pump();

      expect(panggilan, 2);
      expect(find.byKey(const ValueKey('kamera-izin')), findsNothing);
      expect(find.byKey(const ValueKey('pratinjau-palsu')), findsOneWidget);
      expect(find.byKey(const ValueKey('kamera-jepret')), findsOneWidget);
    });

    testWidgets('izin ditolak → tombol tutup: KameraDibatalkan', (
      tester,
    ) async {
      final hasil = await buka(
        tester,
        pabrik: () async =>
            throw const KameraGagal(SebabKameraGagal.izinDitolak),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('kamera-tutup')));
      await tester.pumpAndSettle();

      expect(hasil.nilai, isA<KameraDibatalkan>());
    });

    testWidgets('dialog izin tertutup (hanya inactive→resumed): TIDAK memicu '
        'dialog kedua; kembali dari Pengaturan (paused→resumed): dibuka lagi', (
      tester,
    ) async {
      var panggilan = 0;
      await buka(
        tester,
        pabrik: () async {
          panggilan++;
          throw const KameraGagal(SebabKameraGagal.izinDitolak);
        },
      );
      await tester.pumpAndSettle();
      expect(panggilan, 1);

      // Dialog izin sistem: app hanya inactive lalu resumed.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(panggilan, 1, reason: 'jangan menampilkan dialog izin dua kali');

      // Teknisi ke Pengaturan HP (app ke latar) lalu kembali.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(panggilan, 2, reason: 'kembali dari Pengaturan: coba lagi');
    });

    testWidgets('tidak ada kamera: KameraTakBisa(tidakAda)', (tester) async {
      final hasil = await buka(
        tester,
        pabrik: () async => throw const KameraGagal(SebabKameraGagal.tidakAda),
      );
      await tester.pumpAndSettle();

      expect(
        hasil.nilai,
        isA<KameraTakBisa>().having(
          (h) => h.sebab,
          'sebab',
          SebabKameraGagal.tidakAda,
        ),
      );
    });

    testWidgets('galat apa pun saat inisialisasi: KameraTakBisa(gagalMulai)', (
      tester,
    ) async {
      final hasil = await buka(
        tester,
        pabrik: () async => throw StateError('driver kamera mati'),
      );
      await tester.pumpAndSettle();

      expect(
        hasil.nilai,
        isA<KameraTakBisa>().having(
          (h) => h.sebab,
          'sebab',
          SebabKameraGagal.gagalMulai,
        ),
      );
    });

    testWidgets('navigator tidak ada: langsung KameraTakBisa, tanpa crash', (
      tester,
    ) async {
      final hasil = await bukaKameraPindai(
        navigator: null,
        pabrik: () async => throw StateError('tidak boleh dipanggil'),
      );

      expect(hasil, isA<KameraTakBisa>());
    });
  });

  group('petunjuk langsung', () {
    testWidgets('gelap: saran nyalakan senter muncul, jepret TETAP bisa', (
      tester,
    ) async {
      final k = KontrolKameraPalsu(contoh: [frameRata(25)]);
      final hasil = await buka(tester, pabrik: pabrikTetap(k).pabrik);

      // Dua sampel gelap berturut-turut → saran tampil (peredam kedip).
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1300));
      }

      expect(find.byKey(const ValueKey('kamera-petunjuk')), findsOneWidget);
      expect(find.textContaining('Terlalu gelap'), findsOneWidget);
      expect(find.textContaining('Nyalakan senter'), findsWidgets);
      expect(k.nyala, isFalse, reason: 'saran, bukan menyalakan sendiri');

      // Saran tidak memblokir jepret.
      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pumpAndSettle();
      expect(hasil.nilai, isA<KameraFoto>());
    });

    testWidgets(
      'gelap tapi perangkat tanpa senter: tidak menyuruh menyalakan',
      (tester) async {
        final k = KontrolKameraPalsu(
          punyaSenter: false,
          contoh: [frameRata(25)],
        );
        await buka(tester, pabrik: pabrikTetap(k).pabrik);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 1300));
        }

        expect(find.textContaining('Terlalu gelap'), findsNothing);
        expect(find.textContaining('Masih terlalu gelap'), findsOneWidget);
      },
    );

    testWidgets('senter dinyalakan: saran gelap lama dibersihkan', (
      tester,
    ) async {
      final k = KontrolKameraPalsu(contoh: [frameRata(25)]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1300));
      }
      expect(find.byKey(const ValueKey('kamera-petunjuk')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kamera-senter')));
      await tester.pump();

      expect(find.byKey(const ValueKey('kamera-petunjuk')), findsNothing);
    });

    testWidgets('buram: saran "Gambar buram" muncul', (tester) async {
      final k = KontrolKameraPalsu(contoh: [frameBuram()]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1300));
      }

      expect(find.textContaining('Gambar buram'), findsOneWidget);
    });

    testWidgets('frame baik: tidak ada saran', (tester) async {
      final k = KontrolKameraPalsu(contoh: [frameBagus()]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1300));
      }

      expect(k.jumlahContoh, greaterThan(0), reason: 'sampling benar jalan');
      expect(find.byKey(const ValueKey('kamera-petunjuk')), findsNothing);
    });

    testWidgets('platform tanpa aliran frame: tak pernah meminta contoh', (
      tester,
    ) async {
      final k = KontrolKameraPalsu(bisaContoh: false, contoh: [frameRata(25)]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 1300));
      }

      expect(k.jumlahContoh, 0);
      expect(find.byKey(const ValueKey('kamera-petunjuk')), findsNothing);
    });

    testWidgets(
      'contoh frame melempar galat: petunjuk mati, jepret tetap hidup',
      (tester) async {
        final k = _KontrolContohRusak();
        final hasil = await buka(tester, pabrik: () async => k);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 1300));
        }

        expect(k.jumlahContoh, 1, reason: 'tidak dicoba terus-menerus');
        await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
        await tester.pumpAndSettle();
        expect(hasil.nilai, isA<KameraFoto>());
      },
    );
  });

  group('jepret', () {
    testWidgets('mengembalikan jalur berkas dari kamera, lalu kamera dilepas', (
      tester,
    ) async {
      final berkas = File('${Directory.systemTemp.path}/cap-123.jpg');
      final k = KontrolKameraPalsu(foto: berkas);
      final hasil = await buka(tester, pabrik: pabrikTetap(k).pabrik);

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pumpAndSettle();

      final foto = hasil.nilai;
      expect(foto, isA<KameraFoto>());
      expect((foto! as KameraFoto).berkas.path, berkas.path);
      expect(k.jumlahJepret, 1);
      expect(k.jumlahLepas, 1, reason: 'layar ditutup → kamera dilepas');
    });

    testWidgets('jepret gagal: pesan, tetap di layar kamera, bisa coba lagi', (
      tester,
    ) async {
      final k = KontrolKameraPalsu(jepretGalat: StateError('buffer penuh'));
      final hasil = await buka(tester, pabrik: pabrikTetap(k).pabrik);

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasil.selesai, isFalse);
      expect(find.byKey(const ValueKey('kamera-pesan')), findsOneWidget);
      expect(find.textContaining('Foto gagal diambil'), findsOneWidget);
      expect(find.byKey(const ValueKey('kamera-jepret')), findsOneWidget);
      expect(k.jumlahLepas, 0);

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pump();
      expect(k.jumlahJepret, 2, reason: 'tombol tidak terkunci setelah gagal');
    });

    testWidgets('layar ditutup selagi memotret: foto yang terlambat dihapus', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('kamera-terlambat');
      addTearDown(() => dir.deleteSync(recursive: true));
      final berkas = File('${dir.path}/pindai-kamera-1.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final k = _KontrolLambat(berkas);
      final hasil = await buka(tester, pabrik: () async => k);

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pump();
      // Teknisi menutup layar selagi jepretan belum kembali.
      Navigator.of(
        tester.element(find.byKey(const ValueKey('kamera-tutup'))),
      ).pop(const KameraDibatalkan());
      await tester.pumpAndSettle();
      expect(hasil.nilai, isA<KameraDibatalkan>());

      k.selesai.complete();
      await tester.pump(); // lanjutan _jepret jalan, penghapusan dimulai
      // Polling singkat (bukan jeda tetap): penghapusan berkas = I/O nyata.
      for (var i = 0; i < 200 && berkas.existsSync(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }

      expect(berkas.existsSync(), isFalse);
    });
  });

  group('penjaga jepret', () {
    testWidgets('dua ketukan jepret beruntun = SATU foto', (tester) async {
      final berkas = File('${Directory.systemTemp.path}/cap-ganda.jpg');
      final k = _KontrolLambat(berkas);
      final hasil = await buka(tester, pabrik: () async => k);

      final tombol = find.byKey(const ValueKey('kamera-jepret'));
      // Dua ketukan sebelum frame berikutnya: tombol belum sempat dimatikan
      // oleh rebuild, jadi yang menahan ketukan kedua adalah penjaga di
      // `_jepret`.
      await tester.tap(tombol);
      await tester.tap(tombol, warnIfMissed: false);
      await tester.pump();

      expect(k.jumlahJepret, 1, reason: 'ketukan kedua tidak boleh memotret');

      k.selesai.complete();
      await tester.pumpAndSettle();
      expect(k.jumlahJepret, 1);
      expect(hasil.nilai, isA<KameraFoto>());
    });

    testWidgets('selagi memotret, tombol jepret dan senter dimatikan', (
      tester,
    ) async {
      final berkas = File('${Directory.systemTemp.path}/cap-mati.jpg');
      final k = _KontrolLambat(berkas);
      await buka(tester, pabrik: () async => k);

      GestureDetector gestur() => tester.widget<GestureDetector>(
        find.descendant(
          of: find.byKey(const ValueKey('kamera-jepret')),
          matching: find.byType(GestureDetector),
        ),
      );
      IconButton senter() => tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('kamera-senter')),
          matching: find.byType(IconButton),
        ),
      );

      expect(gestur().onTap, isNotNull);
      expect(senter().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pump();

      expect(gestur().onTap, isNull, reason: 'jepret mati selagi memotret');
      expect(senter().onPressed, isNull, reason: 'senter mati selagi memotret');

      k.selesai.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('jepret MENUNGGU contoh frame yang sedang jalan', (
      tester,
    ) async {
      final k = _KontrolContohTertahan();
      final hasil = await buka(tester, pabrik: () async => k);

      await tester.pump(const Duration(milliseconds: 800));
      expect(k.jumlahContoh, 1, reason: 'contoh frame sedang diminta');

      await tester.tap(find.byKey(const ValueKey('kamera-jepret')));
      await tester.pump();
      expect(
        k.jumlahJepret,
        0,
        reason: 'kamera tak boleh memotret selagi aliran frame berjalan',
      );

      k.tahan.complete(null);
      await tester.pumpAndSettle();
      expect(k.jumlahJepret, 1);
      expect(hasil.nilai, isA<KameraFoto>());
    });
  });

  group('contoh frame tak pernah datang', () {
    testWidgets('putaran dihentikan setelah N timeout berturut-turut + saran '
        'netral', (tester) async {
      final k = KontrolKameraPalsu(); // ambilContoh selalu null
      await buka(tester, pabrik: pabrikTetap(k).pabrik);

      for (var i = 0; i < AmbangFotoLembar.contohKosongMaks + 3; i++) {
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(k.jumlahContoh, AmbangFotoLembar.contohKosongMaks);
      expect(find.byKey(const ValueKey('kamera-pesan')), findsOneWidget);
      expect(find.textContaining('Petunjuk otomatis'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(
        k.jumlahContoh,
        AmbangFotoLembar.contohKosongMaks,
        reason: 'tidak memutar start/stop lagi',
      );
    });

    testWidgets('frame yang datang di tengah mengulang hitungan', (
      tester,
    ) async {
      final k = _KontrolContohSelangSeling();
      await buka(tester, pabrik: pabrikTetap(k).pabrik);

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 800));
      }

      expect(k.jumlahContoh, greaterThan(AmbangFotoLembar.contohKosongMaks));
      expect(find.textContaining('Petunjuk otomatis'), findsNothing);
    });
  });

  group('pelepasan sebelum buka ulang', () {
    testWidgets('kembali dari latar: kamera baru dibuka SETELAH yang lama '
        'selesai dilepas', (tester) async {
      final kontrol = <_KontrolLepasTertahan>[];
      Future<KontrolKamera> pabrik() async {
        final k = _KontrolLepasTertahan();
        kontrol.add(k);

        return k;
      }

      await buka(tester, pabrik: pabrik);
      expect(kontrol, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(kontrol.first.jumlahLepas, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(
        kontrol,
        hasLength(1),
        reason: 'pelepasan lama belum selesai: jangan buka kamera baru',
      );

      kontrol.first.tahan.complete();
      await tester.pump();
      await tester.pump();
      expect(kontrol, hasLength(2));
    });
  });

  group('siklus hidup', () {
    testWidgets(
      'tombol tutup: KameraDibatalkan (bukan galat) + kamera dilepas',
      (tester) async {
        final k = KontrolKameraPalsu();
        final hasil = await buka(tester, pabrik: pabrikTetap(k).pabrik);

        await tester.tap(find.byKey(const ValueKey('kamera-tutup')));
        await tester.pumpAndSettle();

        expect(hasil.nilai, isA<KameraDibatalkan>());
        expect(k.jumlahJepret, 0);
        expect(k.jumlahLepas, 1);
      },
    );

    testWidgets('layar dibuang dari luar (tombol kembali): kamera dilepas', (
      tester,
    ) async {
      final k = KontrolKameraPalsu();
      final hasil = await buka(tester, pabrik: pabrikTetap(k).pabrik);

      Navigator.of(
        tester.element(find.byKey(const ValueKey('kamera-jepret'))),
      ).pop();
      await tester.pumpAndSettle();

      expect(hasil.nilai, isA<KameraDibatalkan>(), reason: 'null → batal');
      expect(k.jumlahLepas, 1);
    });

    testWidgets('app ke latar: kamera dilepas; kembali: dibuka LAGI', (
      tester,
    ) async {
      final kontrol = <KontrolKameraPalsu>[];
      Future<KontrolKamera> pabrik() async {
        final k = KontrolKameraPalsu();
        kontrol.add(k);

        return k;
      }

      await buka(tester, pabrik: pabrik);
      expect(kontrol, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(kontrol.first.jumlahLepas, 1, reason: 'dilepas tepat sekali');
      expect(
        find.byKey(const ValueKey('pratinjau-palsu')),
        findsNothing,
        reason: 'pratinjau kamera yang sudah dilepas tidak boleh ditampilkan',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(kontrol, hasLength(2), reason: 'kamera dibuka ulang saat kembali');
      expect(kontrol.last.jumlahLepas, 0);
      expect(find.byKey(const ValueKey('pratinjau-palsu')), findsOneWidget);
    });

    testWidgets('app ke latar saat kamera masih dibuka (dialog izin): dilepas '
        'begitu selesai, dibuka lagi saat kembali', (tester) async {
      final menunggu = <Completer<void>>[];
      final kontrol = <KontrolKameraPalsu>[];
      Future<KontrolKamera> pabrik() {
        final c = Completer<void>();
        menunggu.add(c);

        return c.future.then((_) {
          final k = KontrolKameraPalsu();
          kontrol.add(k);

          return k;
        });
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: KameraPindaiScreen(pabrik: pabrik, selangContoh: selang),
        ),
      );
      await tester.pump();
      expect(menunggu, hasLength(1));

      // Dialog izin muncul → app "inactive" selagi pembukaan masih menunggu.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      menunggu.single.complete();
      await tester.pump();
      await tester.pump();

      expect(kontrol.single.jumlahLepas, 1, reason: 'jangan tahan kamera');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(menunggu, hasLength(2), reason: 'dibuka ulang saat kembali');
    });
  });

  group('ketuk untuk fokus', () {
    testWidgets('titik ketuk dinormalkan 0..1 terhadap pratinjau', (
      tester,
    ) async {
      final k = KontrolKameraPalsu();
      await buka(tester, pabrik: pabrikTetap(k).pabrik);

      final area = tester.getRect(find.byKey(const ValueKey('kamera-sentuh')));
      await tester.tapAt(area.center);
      await tester.pump();
      await tester.tapAt(
        Offset(area.left + area.width * 0.25, area.top + area.height * 0.4),
      );
      await tester.pump();

      expect(k.titikFokus, hasLength(2));
      expect(k.titikFokus[0].dx, closeTo(0.5, 0.01));
      expect(k.titikFokus[0].dy, closeTo(0.5, 0.01));
      expect(k.titikFokus[1].dx, closeTo(0.25, 0.01));
      expect(k.titikFokus[1].dy, closeTo(0.4, 0.01));
      expect(find.byKey(const ValueKey('kamera-cincin-fokus')), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('kamera-cincin-fokus')), findsNothing);
    });
  });

  group('bantuan dan bingkai', () {
    testWidgets('bantuan alas gelap/kontras + seluruh halaman tampil', (
      tester,
    ) async {
      final k = KontrolKameraPalsu();
      await buka(tester, pabrik: pabrikTetap(k).pabrik, rasio: 792 / 612);

      final teks = tester.widget<Text>(
        find.byKey(const ValueKey('kamera-bantuan')),
      );
      expect(teks.data, contains('alas gelap atau kontras'));
      expect(teks.data, contains('seluruh halaman'));
    });

    testWidgets('foto TABEL (tanpa rasio halaman): bantuan & saran terpotong '
        'tidak menyebut "seluruh halaman"', (tester) async {
      final k = KontrolKameraPalsu(contoh: [frameTerpotong()]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 800));
      }

      final bantuan = tester
          .widget<Text>(find.byKey(const ValueKey('kamera-bantuan')))
          .data!;
      expect(bantuan, contains('alas gelap atau kontras'));
      expect(bantuan, contains('seluruh tabel'));
      expect(bantuan, isNot(contains('halaman')));

      final saran = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('kamera-petunjuk')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(saran, contains('Seluruh tabel harus terlihat'));
      expect(saran, isNot(contains('halaman')));
    });

    testWidgets('foto lembar (ada rasio halaman): saran terpotong menyebut '
        '"seluruh halaman"', (tester) async {
      final k = KontrolKameraPalsu(contoh: [frameTerpotong()]);
      await buka(tester, pabrik: pabrikTetap(k).pabrik, rasio: 792 / 612);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 800));
      }

      expect(
        find.textContaining('Seluruh halaman harus terlihat'),
        findsOneWidget,
      );
    });

    test(
      'bingkai mengikuti rasio halaman (potret & lanskap) dan muat di area',
      () {
        const area = Size(300, 600);
        bool muat(Rect r, Size s) =>
            r.left >= 0 &&
            r.top >= 0 &&
            r.right <= s.width &&
            r.bottom <= s.height;

        final a4 = hitungBingkaiPanduan(area, 210 / 297);
        expect(a4.width / a4.height, closeTo(210 / 297, 1e-6));
        expect(a4.width, closeTo(300 * 0.88, 1e-6), reason: 'dibatasi lebar');
        expect(muat(a4, area), isTrue);

        final lanskap = hitungBingkaiPanduan(area, 792 / 612);
        expect(lanskap.width / lanskap.height, closeTo(792 / 612, 1e-6));
        expect(lanskap.height, lessThan(a4.height));
        expect(muat(lanskap, area), isTrue);

        final sangatTinggi = hitungBingkaiPanduan(const Size(600, 300), 0.5);
        expect(
          sangatTinggi.height,
          closeTo(300 * 0.88, 1e-6),
          reason: 'tinggi',
        );
      },
    );

    test('tanpa rasio: bingkai netral (hampir sepenuh area), bukan A4', () {
      const area = Size(300, 600);
      final netral = hitungBingkaiPanduan(area, null);

      expect(netral.width, closeTo(300 * 0.88, 1e-6));
      expect(netral.height, closeTo(600 * 0.88, 1e-6));
      expect(hitungBingkaiPanduan(area, 0), netral);
      expect(hitungBingkaiPanduan(area, double.nan), netral);
    });

    testWidgets('rasio halaman dari templat sampai ke layar', (tester) async {
      final k = KontrolKameraPalsu();
      await buka(tester, pabrik: pabrikTetap(k).pabrik, rasio: 792 / 612);

      final layar = tester.widget<KameraPindaiScreen>(
        find.byType(KameraPindaiScreen),
      );
      expect(layar.rasioKertas, closeTo(792 / 612, 1e-9));
    });
  });
}

/// Pembuka layar untuk harness: sama dengan yang dipakai `sumberFotoProvider`.
Future<HasilKamera> navigatorUntuk(
  BuildContext context, {
  required PabrikKontrolKamera pabrik,
  double? rasio,
}) => bukaKameraPindai(
  navigator: Navigator.of(context),
  pabrik: pabrik,
  rasioKertas: rasio,
  // Isolate tidak jalan di jam palsu test: pengukur sinkron.
  pengukur: (frame) async => UkurFrame.ukur(frame),
);

class _KontrolContohRusak extends KontrolKameraPalsu {
  @override
  Future<FrameLuma?> ambilContoh() async {
    jumlahContoh++;
    throw StateError('aliran frame tidak didukung');
  }
}

/// Contoh frame yang tertahan sampai [tahan] selesai.
class _KontrolContohTertahan extends KontrolKameraPalsu {
  final tahan = Completer<FrameLuma?>();

  @override
  Future<FrameLuma?> ambilContoh() {
    jumlahContoh++;

    return tahan.future;
  }
}

/// Frame datang di putaran genap saja: tidak pernah N kosong berturut-turut.
class _KontrolContohSelangSeling extends KontrolKameraPalsu {
  @override
  Future<FrameLuma?> ambilContoh() async {
    jumlahContoh++;

    return jumlahContoh.isEven ? frameBagus() : null;
  }
}

/// Pelepasan kamera yang tertahan sampai [tahan] selesai.
class _KontrolLepasTertahan extends KontrolKameraPalsu {
  final tahan = Completer<void>();

  @override
  Future<void> lepas() async {
    jumlahLepas++;
    await tahan.future;
  }
}

class _KontrolLambat extends KontrolKameraPalsu {
  _KontrolLambat(File berkas) : super(foto: berkas);

  final selesai = Completer<void>();

  @override
  Future<File> jepret() async {
    jumlahJepret++;
    await selesai.future;

    return foto;
  }
}
