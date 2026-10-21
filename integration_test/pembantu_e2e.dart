import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pembantu uji E2E app lapangan — dipakai `alur_lapangan_test.dart`.
///
/// Uji E2E menjalankan app lapangan SUNGGUHAN (`main()`) melawan server API
/// lokal sungguhan (SALINAN DB, port 8010). Konfigurasinya lewat
/// `--dart-define` supaya tidak ada akun atau alamat yang tertulis di berkas
/// yang ikut repo:
///
/// | dart-define        | isi                                              |
/// |--------------------|--------------------------------------------------|
/// | `API_BASE_URL`     | server (dibaca `AppConfig` seperti build biasa)  |
/// | `E2E_ID`           | ID pegawai / email akun admin uji                |
/// | `E2E_ID_TEKNISI`   | ID pegawai / email akun teknisi uji              |
/// | `E2E_SANDI`        | sandi kedua akun (fixture lokal, APP_ENV=local)  |
/// | `E2E_POTRET`       | folder tangkapan layar (kosong = folder temp app)|
///
/// Keluaran berbaris `E2E|...` di stdout dibaca runner
/// `sidik-studio-lokal\uji-e2e.ps1` untuk menyusun ringkasan.
const String e2eId = String.fromEnvironment('E2E_ID');
const String e2eIdTeknisi = String.fromEnvironment('E2E_ID_TEKNISI');
const String e2eSandi = String.fromEnvironment('E2E_SANDI');
const String e2ePotret = String.fromEnvironment('E2E_POTRET');

/// Matikan tangkapan layar dalam-app (`layer.toImage`) — untuk emulator yang
/// rapuh terhadap buffer gambar tambahan.
const bool e2ePotretMati = bool.fromEnvironment('E2E_POTRET_MATI');

/// Langkah admin lewat laci menu (Kelola lab, Antrean Approval). Runner
/// emulator mematikannya: emulator Pixel_9_Pro headless mati (host qemu,
/// "bad color buffer handle") tiap laci admin dibuka — 5/5 percobaan 14 Okt,
/// swiftshader maupun guest. Di perangkat fisik biarkan nyala (bawaan).
const bool e2eAdminLaci = bool.fromEnvironment(
  'E2E_ADMIN_LACI',
  defaultValue: true,
);

/// Pencatat langkah: nomor, nama, durasi. Baris `E2E|langkah|...` dipakai
/// runner; galat pertama dicatat dengan nama langkahnya.
class CatatanE2E {
  /// Memasang DENYUT FRAME selama uji: binding live menggambar frame
  /// berikutnya hanya dari frame sebelumnya, dan `pump()` menunggu frame yang
  /// dijadwalkannya. Satu permintaan vsync yang hilang (emulator tersendat,
  /// dialog "System UI isn't responding", jendela Windows sempat tertutup)
  /// memutus rantai itu dan `pump()` menunggu SELAMANYA — terjadi dua kali di
  /// percobaan pertama harness ini (13 Okt 2026). Permintaan frame berkala
  /// menyambung rantainya begitu mesin bisa menggambar lagi; tidak mengubah
  /// apa pun di aplikasi.
  CatatanE2E(this.alur, WidgetTester tester) {
    final denyut = Timer.periodic(
      const Duration(seconds: 2),
      (_) => tester.binding.platformDispatcher.scheduleFrame(),
    );
    addTearDown(denyut.cancel);
  }

  /// Satu langkah yang melewati ini dianggap MACET (bukan lambat): gagal
  /// dengan nama langkahnya, bukan menunggu batas waktu uji 30–40 menit.
  static const batasLangkah = Duration(minutes: 6);

  final String alur;
  int _nomor = 0;
  int _potret = 0;
  bool _macet = false;
  final _jam = Stopwatch()..start();

  int get jumlahLangkah => _nomor;

  Future<T> langkah<T>(
    WidgetTester tester,
    String nama,
    Future<T> Function() isi,
  ) async {
    final no = ++_nomor;
    final sw = Stopwatch()..start();
    // ignore: avoid_print
    print('E2E|mulai|$alur|$no|$nama');
    try {
      final hasil = await isi().timeout(
        batasLangkah,
        onTimeout: () {
          _macet = true;
          throw TestFailure(
            '[$nama] macet > ${batasLangkah.inMinutes} menit tanpa kemajuan '
            '(frame tidak datang: jendela uji tertutup/terminimize, atau '
            'perangkat/emulator tidak merespons)',
          );
        },
      );
      pastikanTanpaGalat(tester, nama);
      // ignore: avoid_print
      print('E2E|langkah|$alur|$no|$nama|LULUS|${sw.elapsedMilliseconds}');
      return hasil;
    } catch (e) {
      // ignore: avoid_print
      print(
        'E2E|langkah|$alur|$no|$nama|GAGAL|${sw.elapsedMilliseconds}|'
        '${'$e'.replaceAll('\n', ' ⏎ ')}',
      );
      // Sesudah macet, `pump` yang lama masih menggantung — memotret akan
      // ikut macet.
      if (!_macet) await potret(tester, 'GAGAL-$nama');
      rethrow;
    }
  }

  void selesai() {
    // ignore: avoid_print
    print('E2E|selesai|$alur|$_nomor|${_jam.elapsedMilliseconds}');
  }

  /// Tangkapan layar dari lapisan akar (tanpa plugin): PNG ke [e2ePotret]
  /// (Windows) atau `<temp aplikasi>/e2e-potret` (Android — ditarik runner
  /// lewat `adb run-as`). Gagal memotret tidak menggagalkan uji.
  Future<void> potret(WidgetTester tester, String nama) async {
    if (e2ePotretMati) return;
    final no = (++_potret).toString().padLeft(2, '0');
    final aman = nama.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    try {
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final lapisan = view.debugLayer;
      if (lapisan is! OffsetLayer) return;
      final gambar = await lapisan.toImage(view.paintBounds);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      gambar.dispose();
      if (data == null) return;
      final folder = Directory(
        e2ePotret.isNotEmpty
            ? e2ePotret
            : '${Directory.systemTemp.path}/e2e-potret',
      )..createSync(recursive: true);
      final berkas = File('${folder.path}/$alur-$no-$aman.png');
      berkas.writeAsBytesSync(data.buffer.asUint8List());
      // ignore: avoid_print
      print('E2E|potret|$alur|${berkas.path}');
    } catch (e) {
      // ignore: avoid_print
      print('E2E|potret-gagal|$alur|$nama|$e');
    }
  }
}

/// Gagal SEKARANG (dengan nama langkah) bila ada FlutterError yang tertunda
/// atau widget galat di layar. Binding uji tetap menggagalkan uji di akhir
/// untuk galat apa pun yang lolos dari pemeriksaan ini.
void pastikanTanpaGalat(WidgetTester tester, String langkah) {
  final galat = tester.takeException();
  if (galat != null) {
    throw TestFailure('[$langkah] FlutterError/exception: $galat');
  }
  if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
    throw TestFailure('[$langkah] ErrorWidget tampil di layar');
  }
}

/// Teks galat yang tidak boleh tampil di layar.
void pastikanTanpaTeks(
  String langkah,
  Iterable<String> teksGalat, {
  Finder? di,
}) {
  for (final t in teksGalat) {
    final f = di == null
        ? find.text(t)
        : find.descendant(of: di, matching: find.text(t));
    if (f.evaluate().isNotEmpty) {
      throw TestFailure('[$langkah] pesan galat tampil: "$t"');
    }
  }
}

/// Pompa frame selama [lama] waktu nyata (binding live).
Future<void> jeda(WidgetTester tester, [int ms = 300]) async {
  final batas = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(batas)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Seperti `pumpAndSettle`, tapi BERBATAS dan tidak melempar: layar app
/// punya indikator yang beranimasi selama memuat, dan `pumpAndSettle` biasa
/// menunggu sampai 10 menit sebelum menyerah.
Future<void> tenang(WidgetTester tester, {int batasMs = 4000}) async {
  final batas = DateTime.now().add(Duration(milliseconds: batasMs));
  await tester.pump(const Duration(milliseconds: 50));
  while (DateTime.now().isBefore(batas) && tester.binding.hasScheduledFrame) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pompa sampai [kondisi] benar; gagal dengan [alasan] sesudah [batas].
Future<void> tunggu(
  WidgetTester tester,
  bool Function() kondisi, {
  required String alasan,
  Duration batas = const Duration(seconds: 60),
}) async {
  final akhir = DateTime.now().add(batas);
  while (!kondisi()) {
    if (DateTime.now().isAfter(akhir)) {
      throw TestFailure(
        'Waktu habis (${batas.inSeconds} s): $alasan. Teks di layar: '
        '${teksTerlihat().take(40).join(' | ')}',
      );
    }
    final galat = tester.takeException();
    if (galat != null) {
      throw TestFailure('Galat saat menunggu "$alasan": $galat');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Teks yang sedang dibangun (untuk pesan gagal).
List<String> teksTerlihat() => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data case final String d when d.trim().isNotEmpty)
      d.trim(),
];

bool ada(Finder f) => f.evaluate().isNotEmpty;

/// Ketuk [f] sesudah ia ADA, bisa ditekan (hit-testable), dan posisinya diam
/// (laci/menu/dialog di emulator bisa masih bergeser waktu diketuk).
Future<void> ketuk(
  WidgetTester tester,
  Finder f, {
  String? alasan,
  Duration batas = const Duration(seconds: 30),
}) async {
  Rect? lalu;
  var diam = 0;
  await tunggu(
    tester,
    () {
      final siap = f.hitTestable();
      if (!ada(siap)) {
        diam = 0;
        return false;
      }
      final kini = tester.getRect(siap.first);
      diam = kini == lalu ? diam + 1 : 0;
      lalu = kini;
      return diam >= 2;
    },
    alasan: alasan ?? 'siap diketuk: $f',
    batas: batas,
  );
  await tester.tap(f.hitTestable().first);
  await tester.pump();
}
