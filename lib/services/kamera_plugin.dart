import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'kamera_pindai.dart';
import 'petunjuk_kamera.dart';

/// Resolusi kamera sendiri.
///
/// `ultraHigh` = 3840×2160 (16:9), BUKAN `max`. Di Android (CameraX) `max`
/// memilih ukuran tertinggi termasuk mode resolusi-tinggi sensor (50–200 MP di
/// banyak HP): JPEG sebesar itu didekode utuh oleh `decodeFotoDiIsolate` dan
/// membuat HP murah kehabisan memori — persis alasan batas 4200 px
/// (`batasSisiFotoAsli`) ada. 3840 px sisi panjang selalu di bawah batas itu,
/// dan untuk halaman penuh setara ±13 px/mm; kanvas perataan hanya ±8,5 px/mm.
const resolusiKameraPindai = ResolutionPreset.ultraHigh;

/// Kode `CameraException` plugin `camera` untuk izin kamera ditolak/dibatasi:
/// `CameraAccessDenied` (Android & iOS), `CameraAccessDeniedWithoutPrompt` dan
/// `CameraAccessRestricted` (iOS), serta `AudioAccess*` (tidak mungkin di sini
/// karena audio mati, tetap dipetakan sama).
SebabKameraGagal petakanKodeGalatKamera(String code) {
  if (code.startsWith('CameraAccess') || code.startsWith('AudioAccess')) {
    return SebabKameraGagal.izinDitolak;
  }
  if (code == 'cameraNotFound' || code == 'CameraNotFound') {
    return SebabKameraGagal.tidakAda;
  }

  return SebabKameraGagal.gagalMulai;
}

/// Frame plugin → [FrameLuma] (plane terang saja), atau `null` untuk format
/// yang tidak dikenal. Dipisah dari plugin supaya bisa diuji di host.
FrameLuma? frameLumaDari({
  required ImageFormatGroup format,
  required Uint8List bita,
  required int lebar,
  required int tinggi,
  required int barisBita,
}) {
  switch (format) {
    case ImageFormatGroup.yuv420:
    case ImageFormatGroup.nv21:
      // Plane pertama = Y (NV21: satu plane, Y di depan).
      return FrameLuma(
        bita: bita,
        lebar: lebar,
        tinggi: tinggi,
        barisBita: barisBita,
      );
    case ImageFormatGroup.bgra8888:
      return FrameLuma(
        bita: bita,
        lebar: lebar,
        tinggi: tinggi,
        barisBita: barisBita,
        langkahPiksel: 4,
        awal: 1,
      );
    default:
      return null;
  }
}

/// [KontrolKamera] di atas plugin `camera` resmi (flutter.dev). Satu-satunya
/// berkas yang mengimpor `package:camera`; sengaja tipis karena tidak bisa
/// dijalankan di host — logika yang bisa diuji ada di fungsi publik di atas.
class KontrolKameraPlugin implements KontrolKamera {
  KontrolKameraPlugin._(this._c)
    : _senterTersedia =
          _c.description.lensDirection == CameraLensDirection.back;

  final CameraController _c;
  bool _senterTersedia;
  bool _senterNyala = false;
  bool _terlepas = false;

  /// Buka kamera belakang. Melempar [KameraGagal].
  ///
  /// [daftarKamera] dan [bangunKontroler] hanya untuk test (plugin tidak jalan
  /// di host); bawaannya plugin asli.
  static Future<KontrolKamera> buka({
    ResolutionPreset resolusi = resolusiKameraPindai,
    @visibleForTesting Future<List<CameraDescription>> Function()? daftarKamera,
    @visibleForTesting
    CameraController Function(CameraDescription, ResolutionPreset)?
    bangunKontroler,
  }) async {
    final List<CameraDescription> daftar;
    try {
      daftar = await (daftarKamera ?? availableCameras)();
    } on CameraException catch (e) {
      throw KameraGagal(petakanKodeGalatKamera(e.code), e);
    }
    if (daftar.isEmpty) throw const KameraGagal(SebabKameraGagal.tidakAda);

    final kamera = daftar.firstWhere(
      (d) => d.lensDirection == CameraLensDirection.back,
      orElse: () => daftar.first,
    );

    final c =
        bangunKontroler?.call(kamera, resolusi) ??
        CameraController(
          kamera,
          resolusi,
          // Audio MATI: tidak ada rekaman, dan izin mikrofon tidak pernah
          // diminta.
          enableAudio: false,
          imageFormatGroup: Platform.isIOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420,
        );

    try {
      await c.initialize();
    } on CameraException catch (e) {
      await _lepasDiam(c);
      throw KameraGagal(petakanKodeGalatKamera(e.code), e);
    } catch (e) {
      await _lepasDiam(c);
      throw KameraGagal(SebabKameraGagal.gagalMulai, e);
    }

    await _flashMati(c);

    return KontrolKameraPlugin._(c);
  }

  /// Mode flash awal dipasang MATI. Bawaan plugin di iOS (`camera_avfoundation`
  /// 0.11.1: `flashMode = hasFlash ? .auto : .off`) adalah `.auto`, yang dipakai
  /// `takePicture`: strobe bisa menyala sendiri di ruang gelap tanpa tanda
  /// apa pun. Senter (torch) hanya lewat [aturSenter], atas ketukan teknisi.
  /// Gagal dipasang tidak menggagalkan pembukaan kamera.
  static Future<void> _flashMati(CameraController c) async {
    try {
      await c.setFlashMode(FlashMode.off);
    } catch (e) {
      debugPrint('KontrolKameraPlugin: flash awal tak bisa dimatikan: $e');
    }
  }

  static Future<void> _lepasDiam(CameraController c) async {
    try {
      await c.dispose();
    } catch (_) {
      // Sedang gagal membuka; galat lepas tidak menambah informasi.
    }
  }

  @override
  Widget bangunPratinjau(BuildContext context, {Widget? lapisan}) =>
      CameraPreview(_c, child: lapisan);

  @override
  bool get senterTersedia => _senterTersedia;

  @override
  bool get senterNyala => _senterNyala;

  /// Plugin tidak membuka `hasFlashUnit`. iOS melempar `CameraException` bila
  /// HP tak punya senter; Android (CameraX) MENELAN galat itu dan hanya
  /// mengirimnya ke aliran galat kamera, yang dicerminkan ke
  /// `value.errorDescription`. Maka sesudah menyalakan, satu putaran event
  /// diberikan lalu `hasError` diperiksa. Artinya: tablet tanpa senter baru
  /// ketahuan saat tombol ditekan (lalu tombolnya disembunyikan).
  @override
  Future<bool> aturSenter(bool nyala) async {
    if (!_senterTersedia) return false;

    try {
      await _c.setFlashMode(nyala ? FlashMode.torch : FlashMode.off);
      if (nyala) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (_c.value.hasError) {
          throw StateError(_c.value.errorDescription ?? '');
        }
      }
    } catch (e) {
      debugPrint('KontrolKameraPlugin: senter gagal: $e');
      if (nyala) {
        _senterTersedia = false;
        _senterNyala = false;
        try {
          await _c.setFlashMode(FlashMode.off);
        } catch (_) {
          // Sudah gagal; tidak ada yang bisa dilakukan lagi.
        }
      }

      return false;
    }

    _senterNyala = nyala;

    return true;
  }

  @override
  Future<void> fokusDi(Offset titik) async {
    final p = Offset(titik.dx.clamp(0.0, 1.0), titik.dy.clamp(0.0, 1.0));
    try {
      await _c.setFocusPoint(p);
    } catch (e) {
      debugPrint('KontrolKameraPlugin: titik fokus tidak didukung: $e');
    }
    try {
      await _c.setExposurePoint(p);
    } catch (e) {
      debugPrint('KontrolKameraPlugin: titik eksposur tidak didukung: $e');
    }
  }

  @override
  bool get bisaContoh => _c.supportsImageStreaming();

  @override
  Future<FrameLuma?> ambilContoh() async {
    final selesai = Completer<FrameLuma?>();

    await _c.startImageStream((CameraImage gambar) {
      // Frame kedua dst. yang masih sempat datang sebelum aliran berhenti
      // dibuang tanpa disentuh.
      if (selesai.isCompleted || gambar.planes.isEmpty) return;
      final p = gambar.planes.first;
      selesai.complete(
        frameLumaDari(
          format: gambar.format.group,
          bita: p.bytes,
          lebar: gambar.width,
          tinggi: gambar.height,
          barisBita: p.bytesPerRow,
        ),
      );
    });

    try {
      return await selesai.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } finally {
      if (_c.value.isStreamingImages) await _c.stopImageStream();
    }
  }

  @override
  Future<File> jepret() async {
    final foto = await _c.takePicture();
    final asli = File(foto.path);

    // Nama sendiri di folder yang sama (cache app), supaya sapuan berkas
    // pindai lama bisa menghapusnya kalau proses mati sebelum terbaca.
    // Pindah nama saja — bita JPEG tidak disentuh.
    try {
      return await asli.rename(
        '${asli.parent.path}${Platform.pathSeparator}$awalanBerkasKamera'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
    } on FileSystemException {
      return asli;
    }
  }

  @override
  Future<void> lepas() async {
    if (_terlepas) return;
    _terlepas = true;
    _senterNyala = false;
    await _lepasDiam(_c);
  }
}
