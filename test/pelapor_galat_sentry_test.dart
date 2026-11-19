import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/core/pelapor_galat.dart';
import 'package:sidik_calibration/core/pelapor_galat_sentry.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Sentry berpenyaring KERAS (keputusan pemilik 19 Nov 2026).
///
/// Yang dijaga: (1) tanpa DSN tidak ada apa pun yang berjalan, (2) tiap opsi
/// yang bisa membawa data pengguna mati, (3) `beforeSend` membuang semua isi
/// berisiko dari event yang sengaja dibuat "berbahaya", dan (4) hasil akhir
/// yang sampai ke transport tidak memuat pesan galat. Tidak ada pengiriman:
/// transport palsu, tanpa jaringan.
///
/// Kalimat berbahaya di bawah rekaan test (nama PT/alat, nomor seri, email,
/// token, path mesin, bacaan lembar) — bukan data pelanggan sungguhan.
const _dsnUji = 'https://kunciuji123@o0.ingest.sentry.io/1';

const _berbahaya = <String>[
  'zainul@sidik.id',
  'Bearer abc123token',
  'PT Contoh Mandiri',
  'SN-12345-X',
  '12,5',
  r'C:\Users\USER',
  'Pixel Zainul',
  'LAPTOP-ZAINUL',
  '10.0.0.5',
  'rahasia-lembar',
];

/// Tidak boleh ada koneksi jaringan sama sekali selama tes ini berjalan.
class _TanpaJaringan extends HttpOverrides {
  int dibuat = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    dibuat++;
    throw StateError('Tidak boleh ada jaringan.');
  }
}

class _TransportPalsu implements Transport {
  _TransportPalsu(this.opsi);

  final SentryOptions opsi;
  final isi = <String>[];
  final _pertama = Completer<void>();

  Future<void> get adaKiriman => _pertama.future;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bita = <int>[];
    await for (final b in envelope.envelopeStream(opsi)) {
      bita.addAll(b);
    }
    isi.add(utf8.decode(bita, allowMalformed: true));
    if (!_pertama.isCompleted) _pertama.complete();
    return envelope.header.eventId;
  }
}

SentryEvent _eventBerbahaya() => SentryEvent(
  release: '1.0.820+820',
  environment: 'release',
  serverName: 'LAPTOP-ZAINUL',
  message: SentryMessage('Gagal baca sel PT Contoh Mandiri SN-12345-X'),
  exceptions: [
    SentryException(
      type: 'FormatException',
      value: 'Invalid number "12,5" untuk zainul@sidik.id',
      mechanism: Mechanism(type: 'generic', handled: true),
      stackTrace: SentryStackTrace(
        frames: [
          SentryStackFrame(
            absPath: r'C:\Users\USER\proj\lib\baca.dart',
            fileName: r'C:\Users\USER\proj\lib\baca.dart',
            function: 'bacaAngka',
            lineNo: 12,
            colNo: 4,
            contextLine: 'final nilai = double.parse("12,5");',
            inApp: true,
            package: 'sidik_calibration',
          ),
          SentryStackFrame(
            fileName: 'package:sidik_calibration/services/x.dart',
            function: 'Kelas.metode',
            lineNo: 7,
          ),
        ],
      ),
    ),
  ],
  user: SentryUser(
    id: '42',
    email: 'zainul@sidik.id',
    username: 'zainul',
    ipAddress: '10.0.0.5',
  ),
  request: SentryRequest(
    url: 'https://api.sidik.id/api/calibrations/30?token=Bearer abc123token',
    data: {'nilai': '12,5', 'pt': 'PT Contoh Mandiri'},
    headers: {'Authorization': 'Bearer abc123token'},
  ),
  breadcrumbs: [
    Breadcrumb(message: 'ketuk "Setujui PT Contoh Mandiri" rahasia-lembar'),
  ],
  contexts: Contexts(
    device: SentryDevice(name: 'Pixel Zainul', model: 'Pixel 8'),
  ),
  tags: {'konteks': 'pindai:uji', 'nama_pt': 'PT Contoh Mandiri'},
  // ignore: deprecated_member_use
  extra: {'lembar': '12,5 rahasia-lembar'},
  modules: {'paket': 'SN-12345-X'},
  transaction: 'Setujui PT Contoh Mandiri',
  culprit: 'rahasia-lembar',
);

SentryFlutterOptions _opsi() {
  final o = SentryFlutterOptions();
  terapkanOpsiSentry(
    o,
    dsn: _dsnUji,
    release: '1.0.820+820',
    environment: 'release',
  );
  return o;
}

void main() {
  group('tanpa DSN: nonaktif total', () {
    test(
      'DSN kosong atau spasi: null, SDK tidak disentuh, nol jaringan',
      () async {
        final jaringan = _TanpaJaringan();
        final lama = HttpOverrides.current;
        HttpOverrides.global = jaringan;
        addTearDown(() => HttpOverrides.global = lama);

        var panggilan = 0;
        Future<void> mata(FlutterOptionsConfiguration _) async => panggilan++;

        for (final dsn in ['', '   ', '\n']) {
          expect(
            await nyalakanSentry(
              dsn: dsn,
              platformDidukung: true,
              // Rilis diberikan supaya satu-satunya alasan kembali `null`
              // adalah DSN kosong (bukan PackageInfo yang tak ada di uji).
              release: '1.0.820+820',
              inisialisasi: mata,
            ),
            isNull,
            reason: 'dsn="$dsn"',
          );
        }

        expect(panggilan, 0, reason: 'SDK tidak boleh diinisialisasi');
        expect(jaringan.dibuat, 0, reason: 'tidak boleh ada klien HTTP');
      },
    );

    test(
      'bawaan build: AppConfig.sentryDsn kosong (tidak ada DSN di repo)',
      () {
        expect(AppConfig.sentryDsn, isEmpty);
      },
    );

    test('tidak ada DSN tertulis di sumber, manifest, atau pubspec', () {
      // Bentuk DSN: https://<kunci>@<org>.ingest.sentry.io/<proyek>
      final pola = RegExp(r'https?://[0-9a-f]{16,}@[\w.-]*sentry[\w.-]*/\d+');
      final berkas = <File>[
        File('pubspec.yaml'),
        for (final d in ['lib', 'android/app/src', 'ios/Runner', 'web'])
          if (Directory(d).existsSync())
            ...Directory(d)
                .listSync(recursive: true)
                .whereType<File>()
                .where(
                  (f) => RegExp(
                    r'\.(dart|xml|kts?|gradle|plist|json|html|properties)$',
                  ).hasMatch(f.path),
                ),
      ];
      expect(berkas, isNotEmpty);
      for (final f in berkas) {
        expect(
          pola.hasMatch(f.readAsStringSync()),
          isFalse,
          reason: 'DSN tertulis di ${f.path}',
        );
      }
    });

    test(
      'platform tidak didukung (desktop/web): null, SDK tidak disentuh',
      () async {
        var panggilan = 0;
        final hasil = await nyalakanSentry(
          dsn: _dsnUji,
          platformDidukung: false,
          release: '1.0.820+820',
          inisialisasi: (_) async => panggilan++,
        );

        expect(hasil, isNull);
        expect(panggilan, 0);
      },
    );

    test(
      'SDK gagal menyala: null, tidak melempar, start tidak tertahan',
      () async {
        final hasil = await nyalakanSentry(
          dsn: _dsnUji,
          platformDidukung: true,
          release: '1.0.820+820',
          inisialisasi: (_) async => throw StateError('rusak $_dsnUji'),
        );
        expect(hasil, isNull);

        final lambat = await nyalakanSentry(
          dsn: _dsnUji,
          platformDidukung: true,
          release: '1.0.820+820',
          batasWaktu: const Duration(milliseconds: 30),
          inisialisasi: (_) => Completer<void>().future,
        );
        expect(lambat, isNull);
      },
    );
  });

  group('opsi privasi KERAS', () {
    late SentryFlutterOptions o;
    setUp(() => o = _opsi());

    test('identitas: versi aplikasi (+build) sebagai rilis, tanpa PII', () {
      expect(o.dsn, _dsnUji);
      expect(o.release, '1.0.820+820');
      expect(o.environment, 'release');
      expect(o.sendDefaultPii, isFalse);
      expect(o.serverName, isEmpty);
    });

    test('tangkapan layar, hierarki tampilan, thread: mati', () {
      expect(o.attachScreenshot, isFalse);
      expect(o.attachViewHierarchy, isFalse);
      expect(o.reportViewHierarchyIdentifiers, isFalse);
      expect(o.attachThreads, isFalse);
    });

    test(
      'breadcrumb: nol, termasuk ketuk dan teks, dan callback membuangnya',
      () {
        expect(o.maxBreadcrumbs, 0);
        expect(o.enableUserInteractionBreadcrumbs, isFalse);
        expect(o.enableUserInteractionTracing, isFalse);
        expect(o.enablePrintBreadcrumbs, isFalse);
        expect(o.enableAppLifecycleBreadcrumbs, isFalse);
        expect(o.enableAutoNativeBreadcrumbs, isFalse);
        expect(
          o.beforeBreadcrumb!(Breadcrumb(message: 'ketuk'), Hint()),
          isNull,
        );
      },
    );

    test('tanpa badan atau kegagalan permintaan HTTP', () {
      expect(o.maxRequestBodySize, MaxRequestBodySize.never);
      expect(o.captureFailedRequests, isFalse);
      expect(o.captureNativeFailedRequests, isFalse);
      expect(o.recordHttpBreadcrumbs, isFalse);
      expect(o.replay.networkCaptureBodies, isFalse);
    });

    test(
      'tanpa performa/tracing: sampel nol dan semua transaksi dibuang',
      () async {
        expect(o.tracesSampleRate, 0.0);
        expect(o.enableAutoPerformanceTracing, isFalse);
        expect(o.enableFramesTracking, isFalse);
        expect(o.enableTimeToFullDisplayTracing, isFalse);
        expect(o.replay.sessionSampleRate, 0.0);
        expect(o.replay.onErrorSampleRate, 0.0);
      },
    );

    test('callback pembuang: transaksi, log, metrik, umpan balik', () async {
      expect(o.beforeSendTransaction, isNotNull);
      expect(o.beforeSendLog, isNotNull);
      expect(o.beforeSendMetric, isNotNull);
      expect(o.beforeSendFeedback, isNotNull);
      expect(await o.beforeSendLog!(_log(), Hint()), isNull);
    });

    test('sesi, laporan klien, daftar paket: mati', () {
      expect(o.enableAutoSessionTracking, isFalse);
      expect(o.sendClientReports, isFalse);
      expect(o.reportPackages, isFalse);
    });

    test('native: tanpa penangkap crash, ANR, hang, atau sinkron scope', () {
      expect(o.enableNativeCrashHandling, isFalse);
      expect(o.anrEnabled, isFalse);
      expect(o.enableTombstone, isFalse);
      expect(o.enableNdkScopeSync, isFalse);
      expect(o.enableScopeSync, isFalse);
      expect(o.enableWatchdogTerminationTracking, isFalse);
      expect(o.enableAppHangTracking, isFalse);
    });

    test('beforeSend terpasang ke saringEventSentry', () {
      expect(o.beforeSend, same(saringEventSentry));
    });

    test('penangkap galat milik SDK dicabut, integrasi lain dibiarkan', () {
      final x = SentryFlutterOptions();
      final onError = OnErrorIntegration();
      final lain = _IntegrasiLain();
      x
        ..addIntegration(onError)
        ..addIntegration(FlutterErrorIntegration())
        ..addIntegration(DebugPrintIntegration())
        ..addIntegration(lain);

      terapkanOpsiSentry(x, dsn: _dsnUji, release: 'r', environment: 'e');

      expect(x.integrations, [lain]);
    });
  });

  group('beforeSend (pagar terakhir)', () {
    test('event berbahaya: tidak ada satu pun isi berisiko yang tersisa', () {
      final event = saringEventSentry(_eventBerbahaya(), Hint())!;
      final json = jsonEncode(event.toJson());

      for (final s in _berbahaya) {
        expect(json, isNot(contains(s)), reason: 'bocor: $s\n$json');
      }
    });

    test('yang berguna tetap ada: jenis, fungsi, baris, rilis, konteks', () {
      final event = saringEventSentry(_eventBerbahaya(), Hint())!;
      final e = event.exceptions!.single;
      final f = e.stackTrace!.frames;

      expect(e.type, 'FormatException');
      expect(e.value, isNull);
      expect(f.first.function, 'bacaAngka');
      expect(f.first.lineNo, 12);
      expect(f.first.fileName, 'baca.dart');
      expect(f.first.absPath, isNull);
      expect(f.first.contextLine, isNull);
      expect(f.last.fileName, 'package:sidik_calibration/services/x.dart');
      expect(event.release, '1.0.820+820');
      expect(event.environment, 'release');
      expect(event.tags, {'konteks': 'pindai:uji'});
    });

    test(
      'kolom pengguna, request, breadcrumb, extra, konteks, host dikosongkan',
      () {
        final event = saringEventSentry(_eventBerbahaya(), Hint())!;

        expect(event.user, isNull);
        expect(event.request, isNull);
        expect(event.breadcrumbs, isNull);
        expect(event.message, isNull);
        expect(event.serverName, isNull);
        expect(event.modules, isNull);
        expect(event.transaction, isNull);
        expect(event.culprit, isNull);
        expect(event.contexts.device, isNull);
        // ignore: deprecated_member_use
        expect(event.extra, isNull);
      },
    );

    test(
      'pembungkus GalatTersaring: nama jenis dipertahankan, pesan tidak',
      () {
        SentryEvent bungkus(String nilai) => SentryEvent(
          exceptions: [SentryException(type: 'GalatTersaring', value: nilai)],
        );

        expect(
          saringEventSentry(
            bungkus('FormatException'),
            Hint(),
          )!.exceptions!.single.value,
          'FormatException',
        );
        expect(
          saringEventSentry(
            bungkus('Invalid number "12,5" rahasia-lembar'),
            Hint(),
          )!.exceptions!.single.value,
          isNull,
        );
      },
    );

    test('galat jaringan: event dibuang seluruhnya', () {
      for (final jenis in [
        'KoneksiException',
        'SocketException',
        'TimeoutException',
        'HandshakeException',
        'ClientException',
      ]) {
        final langsung = SentryEvent(
          exceptions: [SentryException(type: jenis, value: 'x')],
        );
        final terbungkus = SentryEvent(
          exceptions: [SentryException(type: 'GalatTersaring', value: jenis)],
        );

        expect(saringEventSentry(langsung, Hint()), isNull, reason: jenis);
        expect(saringEventSentry(terbungkus, Hint()), isNull, reason: jenis);
      }
    });

    test(
      'bingkai berisi variabel/sumber: jejak tumpukan dibuang, bukan dilepas',
      () {
        final event = SentryEvent(
          exceptions: [
            SentryException(
              type: 'StateError',
              value: null,
              stackTrace: SentryStackTrace(
                frames: [
                  SentryStackFrame(
                    function: 'f',
                    vars: {'token': 'Bearer abc123token'},
                    preContext: ['final rahasia = "rahasia-lembar";'],
                  ),
                ],
              ),
            ),
          ],
        );

        final hasil = saringEventSentry(event, Hint())!;

        expect(hasil.exceptions!.single.stackTrace, isNull);
        expect(jsonEncode(hasil.toJson()), isNot(contains('rahasia-lembar')));
        expect(jsonEncode(hasil.toJson()), isNot(contains('abc123token')));
      },
    );

    test('nama gambar debug dibuang, id build dipertahankan (simbolisasi)', () {
      final event = SentryEvent(
        exceptions: [SentryException(type: 'StateError', value: null)],
        debugMeta: DebugMeta(
          images: [
            DebugImage(
              type: 'elf',
              debugId: 'abcdef0123456789',
              codeFile: '/data/app/~~rahasia-lembar==/libapp.so',
              debugFile: '/data/app/~~rahasia-lembar==/libapp.so',
              name: '/data/app/~~rahasia-lembar==/libapp.so',
            ),
          ],
        ),
      );

      final hasil = saringEventSentry(event, Hint())!;
      final g = hasil.debugMeta!.images.single;

      expect(g.debugId, 'abcdef0123456789');
      expect(g.codeFile, isNull);
      expect(g.debugFile, isNull);
      expect(g.name, isNull);
    });
  });

  group('galatDiabaikanSentry', () {
    test('jaringan dan penolakan server biasa tidak dilaporkan', () {
      expect(galatDiabaikanSentry(const KoneksiException('x')), isTrue);
      expect(galatDiabaikanSentry(const SocketException('x')), isTrue);
      expect(galatDiabaikanSentry(TimeoutException('x')), isTrue);
      expect(galatDiabaikanSentry(http.ClientException('x')), isTrue);
      for (final s in [400, 401, 403, 404, 409, 422, 429, 502, 503, 504]) {
        expect(
          galatDiabaikanSentry(ApiException('x', status: s)),
          isTrue,
          reason: '$s',
        );
      }
    });

    test('bug sungguhan dan 500 tetap dilaporkan', () {
      expect(galatDiabaikanSentry(ApiException('x', status: 500)), isFalse);
      expect(galatDiabaikanSentry(StateError('x')), isFalse);
      expect(galatDiabaikanSentry(const FormatException('x')), isFalse);
      expect(galatDiabaikanSentry(TypeError()), isFalse);
    });
  });

  group('ujung ke ujung dengan transport palsu (tanpa jaringan)', () {
    late _TransportPalsu transport;

    Future<PelaporGalat> nyalakan({bool tanpaBeforeSend = false}) async {
      final opsi = SentryFlutterOptions();
      transport = _TransportPalsu(opsi);
      final pelapor = await nyalakanSentry(
        dsn: _dsnUji,
        platformDidukung: true,
        release: '1.0.820+820',
        transport: transport,
        // SDK inti, tanpa integrasi Flutter/native (tidak ada di host uji).
        // ignore: invalid_use_of_internal_member
        inisialisasi: (konfigurasi) => Sentry.init(
          (o) {
            konfigurasi(o as SentryFlutterOptions);
            // Untuk menguji LAPIS 1 sendirian: pagar beforeSend dicopot.
            if (tanpaBeforeSend) o.beforeSend = null;
          },
          // ignore: invalid_use_of_internal_member
          options: opsi,
        ),
      );
      expect(pelapor, isA<PelaporGalatSentry>());
      return pelapor!;
    }

    tearDown(() async {
      await Sentry.close();
    });

    test('galat dengan pesan berisiko: yang sampai ke transport hanya jenis '
        '+ jejak + konteks', () async {
      final pelapor = await nyalakan();

      pelapor.catat(
        const FormatException(
          'Invalid number "12,5" untuk PT Contoh Mandiri SN-12345-X '
          'zainul@sidik.id Bearer abc123token',
        ),
        StackTrace.current,
        konteks: 'pindai:uji',
      );
      await transport.adaKiriman.timeout(const Duration(seconds: 5));

      expect(transport.isi, hasLength(1));
      final badan = transport.isi.single;
      for (final s in _berbahaya) {
        expect(badan, isNot(contains(s)), reason: 'bocor: $s');
      }
      expect(badan, contains('FormatException'));
      expect(badan, contains('pindai:uji'));
      expect(badan, contains('1.0.820+820'));
    });

    test('lapis 1 berdiri sendiri: walau beforeSend dicopot, pesan galat tidak '
        'ikut (hanya GalatTersaring yang dikirim)', () async {
      final pelapor = await nyalakan(tanpaBeforeSend: true);

      pelapor.catat(
        const FormatException(
          'Invalid number "12,5" untuk PT Contoh Mandiri SN-12345-X '
          'zainul@sidik.id Bearer abc123token rahasia-lembar',
        ),
        StackTrace.current,
        konteks: 'pindai:uji',
      );
      await transport.adaKiriman.timeout(const Duration(seconds: 5));

      final badan = transport.isi.single;
      for (final s in [
        'PT Contoh Mandiri',
        'SN-12345-X',
        'zainul@sidik.id',
        'abc123token',
        'rahasia-lembar',
      ]) {
        expect(badan, isNot(contains(s)), reason: 'bocor: $s');
      }
      expect(badan, contains('FormatException'));
    });

    test('galat jaringan dan 4xx tidak pernah sampai ke transport', () async {
      final pelapor = await nyalakan();

      pelapor
        ..catat(const KoneksiException('putus'), null, konteks: 'a')
        ..catat(const SocketException('putus'), null, konteks: 'b')
        ..catat(ApiException('tak ada', status: 404), null, konteks: 'c')
        ..catat(ApiException('validasi', status: 422), null, konteks: 'd')
        ..catat(ApiException('belum siap', status: 503), null, konteks: 'e')
        // Satu galat nyata sebagai penanda urutan: bila yang di atas bocor,
        // envelopenya datang lebih dulu dan jumlahnya lebih dari satu.
        ..catat(StateError('bug sungguhan'), StackTrace.current, konteks: 'f');
      await transport.adaKiriman.timeout(const Duration(seconds: 5));

      expect(transport.isi, hasLength(1));
      expect(transport.isi.single, contains('StateError'));
      expect(transport.isi.single, isNot(contains('bug sungguhan')));
    });

    test('catat tidak pernah melempar walau SDK sudah ditutup', () async {
      final pelapor = await nyalakan();
      await Sentry.close();

      expect(
        () => pelapor.catat(StateError('x'), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('PelaporGalatGabungan', () {
    test('meneruskan ke semua tujuan; galat satu tujuan tidak menghentikan '
        'yang lain', () {
      final a = _PelaporRekam();
      final rusak = _PelaporRusak();
      final b = _PelaporRekam();

      PelaporGalatGabungan([
        a,
        rusak,
        b,
      ]).catat(StateError('x'), null, konteks: 'k', fatal: true);

      expect(a.konteks, ['k']);
      expect(b.konteks, ['k']);
      expect(b.fatal, [true]);
    });

    test(
      'gabungkanPelapor: nol -> null, satu -> itu sendiri, dua -> gabungan',
      () {
        final a = _PelaporRekam();
        final b = _PelaporRekam();

        expect(gabungkanPelapor([null, null]), isNull);
        expect(gabungkanPelapor([null, a]), same(a));
        expect(gabungkanPelapor([a, b]), isA<PelaporGalatGabungan>());
      },
    );
  });
}

SentryLog _log() => SentryLog(
  timestamp: DateTime.utc(2026, 11, 19),
  traceId: SentryId.newId(),
  level: SentryLogLevel.info,
  body: 'rahasia-lembar',
  attributes: const {},
);

// Pengganti integrasi bawaan SDK yang tidak diekspor paketnya; dicocokkan
// lewat NAMA tipenya, jadi kelas uji ini sengaja memakai nama yang sama.
class FlutterErrorIntegration extends Integration<SentryOptions> {
  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {}
}

class DebugPrintIntegration extends Integration<SentryOptions> {
  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {}
}

class _IntegrasiLain extends Integration<SentryOptions> {
  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {}
}

class _PelaporRekam extends PelaporGalat {
  final konteks = <String?>[];
  final fatal = <bool>[];

  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) {
    this.konteks.add(konteks);
    this.fatal.add(fatal);
  }
}

class _PelaporRusak extends PelaporGalat {
  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) => throw StateError('pelapor rusak');
}
