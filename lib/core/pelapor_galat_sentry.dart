/// Pelapor galat Sentry, BERPENYARING KERAS (keputusan pemilik 19 Nov 2026).
///
/// ## NONAKTIF kecuali build diberi DSN
///
/// `--dart-define=SENTRY_DSN=...` ([AppConfig.sentryDsn]). Tidak ada DSN di
/// repo. DSN kosong = [nyalakanSentry] pulang `null` SEBELUM menyentuh SDK:
/// tidak ada inisialisasi, tidak ada penangkap, tidak ada panggilan jaringan.
///
/// ## Yang BOLEH dan TIDAK BOLEH keluar dari HP
///
/// Sama dengan jalur Crashlytics (`lib/core/pelapor_galat.dart`): HANYA nama
/// jenis galat ([GalatTersaring]) + jejak tumpukan kode kita + label konteks
/// buatan kode + versi aplikasi. Pesan galat (`toString()`) tidak pernah ikut:
/// bisa membawa bacaan lembar kerja, nama pelanggan/alat/PT, nomor seri, token,
/// atau path berkas. Tiga lapis, supaya satu lapis bocor tidak cukup:
///
///  1. [PelaporGalatSentry.catat] hanya mengirim [GalatTersaring] (jenis saja)
///     dan membuang galat jaringan/4xx biasa ([galatDiabaikanSentry]).
///  2. [terapkanOpsiSentry] mematikan semua yang bisa membawa data pengguna:
///     tangkapan layar, hierarki tampilan, breadcrumb (maksimum 0, termasuk
///     ketuk/teks), badan permintaan HTTP, pengguna/PII bawaan, sesi, replay,
///     performa/tracing, log, laporan klien, daftar paket, ANR, dan penangkap
///     crash native. Penangkap galat milik SDK sendiri (Flutter/async/isolate/
///     `debugPrint`) DICABUT: satu-satunya pintu masuk adalah [catat].
///  3. [saringEventSentry] (`beforeSend`) adalah pagar terakhir: membuang pesan
///     galat, pengguna, request, breadcrumb, extra, tag selain whitelist,
///     konteks perangkat, nama host, dan path absolut dari jejak tumpukan.
///
/// Galat native (Java/NDK/ANR) SENGAJA tidak ditangkap Sentry: `beforeSend`
/// Dart tidak berlaku untuk event native, jadi tidak ada pagar yang menjamin
/// isinya bersih. Crash native tetap dilaporkan Crashlytics.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/auth_service.dart'
    show ApiException, KoneksiException, gagalJaringan;
import 'config/app_config.dart';
import 'pelapor_galat.dart';

/// Jenis galat yang tidak dilaporkan: jaringan putus/lambat dan penolakan
/// server biasa. Dipakai [galatDiabaikanSentry] dan pagar `beforeSend`.
const _jenisDiabaikan = <String>{
  'KoneksiException',
  'SocketException',
  'TimeoutException',
  'HandshakeException',
  'ClientException',
  'HttpException',
  'TlsException',
};

/// `true` untuk galat yang BUKAN bug aplikasi: jaringan (termasuk server yang
/// belum siap, 502/503/504) dan penolakan server berstatus < 500 (401/403/404/
/// 409/422/429 adalah jalur normal, bukan kerusakan).
bool galatDiabaikanSentry(Object galat) {
  if (galat is KoneksiException ||
      galat is SocketException ||
      galat is TimeoutException ||
      galat is HandshakeException ||
      galat is http.ClientException) {
    return true;
  }
  if (galat is ApiException) {
    return galat.status < 500 || gagalJaringan(galat);
  }
  return false;
}

/// Tag yang dibiarkan lewat `beforeSend`. `konteks` = label buatan kode
/// (mis. `pindai:asli-baca`), `jenis` = nama jenis galat.
const _tagDiizinkan = <String>{'konteks', 'jenis'};

/// Integrasi bawaan SDK yang dicabut, dicocokkan lewat NAMA tipenya (sebagian
/// tidak diekspor oleh paket). Semuanya penangkap galat atau pengait global
/// yang akan menangkap galat ASLI (dengan pesannya) atau membaca `debugPrint`.
const _integrasiDicabut = <String>{
  'FlutterErrorIntegration',
  'OnErrorIntegration',
  'IsolateErrorIntegration',
  'RunZonedGuardedIntegration',
  'DebugPrintIntegration',
};

/// Pelapor yang meneruskan galat ke Sentry. Hanya dipasang oleh `main.dart`
/// bila [nyalakanSentry] berhasil.
class PelaporGalatSentry extends PelaporGalat {
  const PelaporGalatSentry();

  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) {
    if (galatDiabaikanSentry(galat)) return;

    final tersaring = GalatTersaring.dari(galat);

    // Tidak ditunggu, dan galat pelapornya sendiri ditelan: laporan yang gagal
    // terkirim tidak boleh menjadi crash kedua.
    try {
      unawaited(
        Sentry.captureException(
          tersaring,
          stackTrace: tumpukan,
          withScope: (scope) {
            scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
            scope.setTag('jenis', tersaring.jenis);
            if (konteks != null) scope.setTag('konteks', konteks);
          },
        ).then<void>((_) {}, onError: (Object _) {}),
      );
    } catch (_) {
      // Sengaja diam.
    }
  }
}

/// Terapkan SEMUA batas privasi ke [o]. Dipisah dari [nyalakanSentry] supaya
/// bisa diuji tanpa menyalakan SDK.
void terapkanOpsiSentry(
  SentryFlutterOptions o, {
  required String dsn,
  required String release,
  required String environment,
}) {
  o
    ..dsn = dsn
    ..release = release
    ..environment = environment
    // Identitas & PII.
    ..sendDefaultPii = false
    ..serverName = ''
    // Hanya galat aplikasi; tidak ada pengait ke jaringan aplikasi.
    ..captureFailedRequests = false
    ..captureNativeFailedRequests = false
    ..recordHttpBreadcrumbs = false
    ..maxRequestBodySize = MaxRequestBodySize.never
    // Breadcrumb: nol, termasuk ketuk, teks, lifecycle, navigasi, `print`.
    ..maxBreadcrumbs = 0
    ..enableUserInteractionBreadcrumbs = false
    ..enableUserInteractionTracing = false
    ..enableAppLifecycleBreadcrumbs = false
    ..enableWindowMetricBreadcrumbs = false
    ..enableBrightnessChangeBreadcrumbs = false
    ..enableTextScaleChangeBreadcrumbs = false
    ..enableMemoryPressureBreadcrumbs = false
    ..enablePrintBreadcrumbs = false
    ..enableAutoNativeBreadcrumbs = false
    // Citra layar dan tampilan.
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..reportViewHierarchyIdentifiers = false
    ..attachThreads = false
    // Performa & tracing: tidak ada.
    ..tracesSampleRate = 0.0
    ..enableAutoPerformanceTracing = false
    ..enableFramesTracking = false
    ..enableTimeToFullDisplayTracing = false
    ..enableNativeTraceSync = false
    // Sesi, laporan klien, daftar paket.
    ..enableAutoSessionTracking = false
    ..sendClientReports = false
    ..reportPackages = false
    // Native: tidak ada penangkap crash/ANR/hang (tidak melewati beforeSend).
    ..enableNativeCrashHandling = false
    ..anrEnabled = false
    ..enableTombstone = false
    ..enableNdkScopeSync = false
    ..enableScopeSync = false
    ..enableWatchdogTerminationTracking = false
    ..enableAppHangTracking = false
    // Pagar terakhir.
    ..beforeSend = saringEventSentry
    ..beforeSendTransaction = ((transaction, hint) => null)
    ..beforeSendFeedback = ((event, hint) => null)
    ..beforeSendLog = ((log, hint) => null)
    ..beforeSendMetric = ((metric, hint) => null)
    ..beforeBreadcrumb = ((breadcrumb, hint) => null);

  // Replay sesi: nol, dan jaringan tidak pernah dipotret.
  o.replay
    ..sessionSampleRate = 0.0
    ..onErrorSampleRate = 0.0
    ..networkCaptureBodies = false;

  // Cabut penangkap galat & pengait global milik SDK: satu-satunya pintu
  // masuk adalah `PelaporGalatSentry.catat` (jenis saja).
  for (final i in List.of(o.integrations)) {
    if (_integrasiDicabut.contains(i.runtimeType.toString())) {
      o.removeIntegration(i);
    }
  }
}

final _pengenal = RegExp(r'^[A-Za-z_][A-Za-z0-9_<>?,. ]{0,80}$');

/// `beforeSend`: pagar terakhir sebelum event masuk transport. Mengembalikan
/// `null` (event dibuang) untuk galat jaringan/4xx, selain itu event yang
/// dibersihkan. Memutasi [event] (di SDK 10.x kolomnya tidak `final`).
SentryEvent? saringEventSentry(SentryEvent event, Hint hint) {
  final galat = event.exceptions;

  if (galat != null &&
      galat.isNotEmpty &&
      galat.every(
        (e) =>
            _jenisDiabaikan.contains(e.type) ||
            (e.type == 'GalatTersaring' && _jenisDiabaikan.contains(e.value)),
      )) {
    return null;
  }

  for (final e in galat ?? const <SentryException>[]) {
    // Nilai (pesan) hanya dipertahankan untuk pembungkus [GalatTersaring],
    // yang isinya memang cuma nama jenis; selain itu dibuang.
    final nilai = e.value;
    e.value =
        e.type == 'GalatTersaring' && nilai != null && _pengenal.hasMatch(nilai)
        ? nilai
        : null;

    final m = e.mechanism;
    if (m != null) {
      e.mechanism = Mechanism(type: m.type, handled: m.handled);
    }

    final frames = e.stackTrace?.frames ?? const <SentryStackFrame>[];
    // Bingkai Dart tidak pernah memuat variabel atau potongan sumber (itu
    // milik native/JS), tetapi kolomnya `final` dan tidak bisa dikosongkan:
    // bila ada yang terisi, seluruh jejak tumpukan dibuang, bukan dilepas.
    if (frames.any(
      (f) =>
          f.vars.isNotEmpty ||
          f.preContext.isNotEmpty ||
          f.postContext.isNotEmpty,
    )) {
      e.stackTrace = null;
      continue;
    }
    for (final f in frames) {
      f
        ..absPath = null
        ..contextLine = null
        ..fileName = _namaBerkasAman(f.fileName);
    }
  }

  // Gambar debug (id build libapp.so) DIPERTAHANKAN supaya jejak rilis bisa
  // disimbolkan; hanya nama/path berkasnya yang dibuang.
  for (final g in event.debugMeta?.images ?? const <DebugImage>[]) {
    g
      ..name = null
      ..debugFile = null
      ..codeFile = null;
  }

  // `extra` sudah usang di SDK, tetapi masih dikirim bila terisi: dikosongkan.
  // ignore: deprecated_member_use
  event.extra = null;

  event
    ..message = null
    ..user = null
    ..request = null
    ..breadcrumbs = null
    ..threads = null
    ..modules = null
    ..serverName = null
    ..transaction = null
    ..culprit = null
    ..dist = null
    ..contexts = Contexts()
    ..tags = {
      for (final t in (event.tags ?? const <String, String>{}).entries)
        if (_tagDiizinkan.contains(t.key)) t.key: t.value,
    };

  return event;
}

/// Nama berkas yang tidak membawa path mesin: `package:`/`dart:` dibiarkan,
/// path lain dipotong jadi nama dasarnya.
String? _namaBerkasAman(String? nama) {
  if (nama == null) return null;
  if (nama.startsWith('package:') || nama.startsWith('dart:')) return nama;
  final potong = nama.split(RegExp(r'[\\/]'));
  return potong.isEmpty ? null : potong.last;
}

/// Penginisialisasi SDK; diganti di tes.
typedef InisialisasiSentry =
    Future<void> Function(FlutterOptionsConfiguration konfigurasi);

/// Nyalakan Sentry. `null` = tidak aktif (tidak ada DSN, platform tidak
/// didukung, atau gagal menyala) dan aplikasi jalan terus tanpa laporan.
///
/// - DSN kosong: kembali SEBELUM menyentuh SDK. Tidak ada jaringan.
/// - Hanya Android/iOS (aplikasi HP); desktop dan web dilewati.
/// - Tidak pernah melempar dan tidak pernah menahan start lebih dari
///   [batasWaktu]: kegagalan Sentry tidak boleh membuat aplikasi tidak bisa
///   dibuka.
/// - [transport] hanya untuk tes (transport palsu: tidak ada pengiriman).
Future<PelaporGalat?> nyalakanSentry({
  String dsn = AppConfig.sentryDsn,
  bool? platformDidukung,
  InisialisasiSentry? inisialisasi,
  Transport? transport,
  String? release,
  Duration batasWaktu = const Duration(seconds: 3),
}) async {
  if (dsn.trim().isEmpty) return null;

  final didukung =
      platformDidukung ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));
  if (!didukung) return null;

  try {
    final rilis = release ?? await _versiAplikasi();

    final init = inisialisasi ?? SentryFlutter.init;
    await init((o) {
      terapkanOpsiSentry(
        o,
        dsn: dsn.trim(),
        release: rilis,
        environment: kReleaseMode
            ? 'release'
            : (kProfileMode ? 'profile' : 'debug'),
      );
      if (transport != null) o.transport = transport;
    }).timeout(batasWaktu);

    return const PelaporGalatSentry();
  } catch (e) {
    // Hanya jenisnya: pesan bisa memuat potongan DSN/URL.
    debugPrint('Sentry nggak nyala: ${e.runtimeType}');
    return null;
  }
}

/// Versi + nomor build yang BENAR-BENAR terpasang (`1.0.820+820`). Rilis CI
/// menimpa keduanya lewat `--build-name`/`--build-number`, jadi pubspec salah.
Future<String> _versiAplikasi() async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
}
