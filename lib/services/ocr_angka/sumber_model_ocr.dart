import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;

/// Dari mana `meta.json` dan berkas model dibaca.
abstract interface class SumberModelOcr {
  /// Isi meta, atau `null` bila tidak ada di sumber ini.
  Future<String?> metaJson();

  /// Byte model bernama [berkas] (nama polos, dari meta), atau `null`.
  Future<Uint8List?> model(String berkas);
}

/// Aset yang dibundel di APK (`assets/models/`). Model BELUM dibundel (lihat
/// `assets/models/README.md`), jadi sumber ini biasanya mengembalikan `null`.
class SumberAsetOcr implements SumberModelOcr {
  SumberAsetOcr(
    this.bundle, {
    this.awalan = 'assets/models/',
    this.namaMeta = 'ocr_angka_en.meta.json',
  });

  final AssetBundle bundle;
  final String awalan;
  final String namaMeta;

  @override
  Future<String?> metaJson() =>
      _coba(() => bundle.loadString('$awalan$namaMeta'));

  @override
  Future<Uint8List?> model(String berkas) => _coba(() async {
    final d = await bundle.load('$awalan$berkas');
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  });
}

/// Folder di perangkat (mis. dititipkan lewat adb untuk pengukuran di tablet).
/// Model tidak ikut APK.
class SumberFolderOcr implements SumberModelOcr {
  SumberFolderOcr(this.folder, {this.namaMeta = 'ocr_angka_en.meta.json'});

  final Directory folder;
  final String namaMeta;

  @override
  Future<String?> metaJson() =>
      _coba(() => File('${folder.path}/$namaMeta').readAsString());

  @override
  Future<Uint8List?> model(String berkas) =>
      _coba(() => File('${folder.path}/$berkas').readAsBytes());
}

/// Coba sumber satu per satu; yang pertama punya meta DAN model dipakai.
class SumberBerlapisOcr implements SumberModelOcr {
  SumberBerlapisOcr(this.sumber);

  final List<SumberModelOcr> sumber;

  SumberModelOcr? _terpilih;

  @override
  Future<String?> metaJson() async {
    for (final s in sumber) {
      final m = await s.metaJson();
      if (m != null) {
        _terpilih = s;
        return m;
      }
    }
    return null;
  }

  @override
  Future<Uint8List?> model(String berkas) async {
    return _terpilih?.model(berkas);
  }
}

Future<T?> _coba<T>(Future<T> Function() f) async {
  try {
    return await f();
  } catch (_) {
    return null;
  }
}
