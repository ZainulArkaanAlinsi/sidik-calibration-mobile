import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Meta-data Sentry di AndroidManifest (paket LAB-UI-2, koreksi privasi).
///
/// Kenapa ada: SDK native Sentry HARUS hidup begitu `SENTRY_DSN` diisi (event
/// Dart dikirim lewat transport native), dan `beforeSend` Dart tidak berlaku
/// untuk event yang lahir di native. sentry-android-core 8.64.0 menyalakan
/// penangkap crash NDK secara bawaan (`io.sentry.ndk.enable` = true) dan
/// Flutter tidak memetakannya. Satu-satunya penutup yang kita pegang adalah
/// meta-data yang dibaca `ManifestMetadataReader` sebelum callback Flutter.
///
/// Nama kunci diperiksa dari bytecode `ManifestMetadataReader` sentry-android-
/// core 8.64.0 (Maven Central). Efek meta-data di perangkat BELUM diuji; tes ini
/// hanya menjaga bahwa penutupnya tidak hilang dan izin tidak bertambah.
String _manifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

Map<String, String> _metaSentry() {
  final pola = RegExp(
    r'<meta-data\s+android:name="(io\.sentry\.[^"]+)"\s+android:value="([^"]*)"\s*/>',
  );
  return {for (final m in pola.allMatches(_manifest())) m[1]!: m[2]!};
}

void main() {
  const diharapkan = <String, String>{
    'io.sentry.ndk.enable': 'false',
    'io.sentry.ndk.scope-sync.enable': 'false',
    'io.sentry.ndk.app-hang.enable': 'false',
    'io.sentry.anr.enable': 'false',
    'io.sentry.tombstone.enable': 'false',
    'io.sentry.uncaught-exception-handler.enable': 'false',
    'io.sentry.auto-session-tracking.enable': 'false',
    'io.sentry.attach-screenshot': 'false',
    'io.sentry.attach-view-hierarchy': 'false',
    'io.sentry.attach-threads': 'false',
    'io.sentry.send-default-pii': 'false',
    'io.sentry.send-client-reports': 'false',
    'io.sentry.max-breadcrumbs': '0',
    'io.sentry.breadcrumbs.activity-lifecycle': 'false',
    'io.sentry.breadcrumbs.app-components': 'false',
    'io.sentry.breadcrumbs.app-lifecycle': 'false',
    'io.sentry.breadcrumbs.network-events': 'false',
    'io.sentry.breadcrumbs.system-events': 'false',
    'io.sentry.breadcrumbs.user-interaction': 'false',
    'io.sentry.logs.enabled': 'false',
    'io.sentry.metrics.enabled': 'false',
  };

  test('penangkap native Sentry ditutup lewat meta-data manifest', () {
    final meta = _metaSentry();

    for (final e in diharapkan.entries) {
      expect(meta[e.key], e.value, reason: '${e.key} harus ${e.value}');
    }
  });

  test('NDK dimatikan eksplisit (bawaan SDK 8.64.0 = menyala)', () {
    expect(_metaSentry()['io.sentry.ndk.enable'], 'false');
  });

  test('tidak ada meta-data Sentry yang MENYALAKAN sesuatu', () {
    // Kunci baru yang ditambah kemudian harus sengaja: tidak boleh ada nilai
    // `true` atau angka selain 0 di blok Sentry.
    final menyala = {
      for (final e in _metaSentry().entries)
        if (e.value != 'false' && e.value != '0') e.key: e.value,
    };

    expect(menyala, isEmpty);
  });

  test('izin Android tidak bertambah (himpunan yang dinyatakan app sendiri)', () {
    final pola = RegExp(r'<uses-permission\s+android:name="([^"]+)"');
    final izin = {for (final m in pola.allMatches(_manifest())) m[1]!};

    // Himpunan di basis OCR-LINEAR (0dac754). Sentry tidak boleh menambah:
    // sentry-android-core hanya menyatakan INTERNET (sudah ada), dan manifest
    // plugin hanya mencabut SentryInitProvider. Manifest HASIL MERGE belum
    // dibangun di sini; cek tersebut ada di build rilis.
    expect(izin, {
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.REQUEST_INSTALL_PACKAGES',
    });
  });

  test('tidak ada DSN atau auto-init di manifest', () {
    final m = _manifest();

    expect(m, isNot(contains('io.sentry.dsn')));
    expect(m, isNot(contains('io.sentry.auto-init')));
  });
}
