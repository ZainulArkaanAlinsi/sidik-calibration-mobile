import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/providers/worksheet_vision_provider.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Tombol "foto tabel ini" dulu SELALU manggil kamera, apa pun platformnya.
///
/// Di macOS & Windows itu jaminan gagal: `image_picker` nggak punya
/// implementasi kamera di sana (nggak ada `image_picker_macos`/`_windows` di
/// `pubspec.lock`), dan app macOS-nya juga nggak minta entitlement kamera.
/// Tombolnya kelihatan normal, ditekan, lalu error — tiap kali, dan nol test
/// yang gagal karena semua test nge-override provider-nya pakai mock.
void main() {
  test('desktop dapat pemilih BERKAS, bukan kamera yang nggak ada', () {
    final wadah = ProviderContainer();
    addTearDown(wadah.dispose);

    final sumber = wadah.read(sumberFotoProvider);

    if (Platform.isAndroid || Platform.isIOS) {
      expect(
        sumber,
        isA<KameraSumberFoto>(),
        reason: 'HP punya kamera beneran — jangan diganti pemilih berkas',
      );
    } else {
      expect(
        sumber,
        isA<BerkasSumberFoto>(),
        reason: 'macOS/Windows nggak punya kamera yang bisa dipanggil '
            'image_picker; manggil KameraSumberFoto di sini pasti meledak',
      );
    }
  });

  test('batal milih foto balik null, bukan error', () async {
    // `null` itu "user mundur", BUKAN kegagalan — layar nggak boleh nampilin
    // pesan error buat kasus ini.
    final sumber = MockSumberFoto(dibatalkan: true);
    expect(await sumber.ambil(), isNull);
  });
}
