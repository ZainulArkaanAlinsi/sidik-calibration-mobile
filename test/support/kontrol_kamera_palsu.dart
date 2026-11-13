import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sidik_calibration/services/kamera_pindai.dart';
import 'package:sidik_calibration/services/petunjuk_kamera.dart';

/// Kamera TIRUAN untuk test layar kamera (plugin `camera` tidak jalan di
/// host). Dipakai `kamera_pindai_screen_test.dart` (kontrak perilaku) dan
/// `kamera_pindai_desain_test.dart` (render & ketangguhan tata letak).
class KontrolKameraPalsu implements KontrolKamera {
  KontrolKameraPalsu({
    this.punyaSenter = true,
    this.senterMenolak = false,
    this.bisaContoh = true,
    this.contoh = const [],
    this.jepretGalat,
    this.warnaPratinjau = const Color(0xFF223344),
    File? foto,
  }) : foto = foto ?? File('${Directory.systemTemp.path}/jepretan-palsu.jpg');

  bool punyaSenter;
  final bool senterMenolak;
  @override
  final bool bisaContoh;
  final List<FrameLuma?> contoh;
  final Object? jepretGalat;
  final File foto;

  /// Warna isi pratinjau tiruan — putih untuk menguji kontras teks di atas
  /// kertas terang.
  final Color warnaPratinjau;

  bool nyala = false;
  int jumlahLepas = 0;
  int jumlahContoh = 0;
  int jumlahJepret = 0;
  final aturSenterDipanggil = <bool>[];
  final titikFokus = <Offset>[];

  @override
  Widget bangunPratinjau(BuildContext context, {Widget? lapisan}) {
    final ukuran = MediaQuery.sizeOf(context);

    // Seperti `CameraPreview` asli: rasionya mengikuti orientasi layar.
    return AspectRatio(
      aspectRatio: ukuran.width > ukuran.height ? 16 / 9 : 9 / 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            key: const ValueKey('pratinjau-palsu'),
            color: warnaPratinjau,
          ),
          ?lapisan,
        ],
      ),
    );
  }

  @override
  bool get senterTersedia => punyaSenter;

  @override
  bool get senterNyala => nyala;

  @override
  Future<bool> aturSenter(bool nilai) async {
    aturSenterDipanggil.add(nilai);
    if (senterMenolak && nilai) {
      punyaSenter = false;

      return false;
    }
    nyala = nilai;

    return true;
  }

  @override
  Future<void> fokusDi(Offset titik) async => titikFokus.add(titik);

  @override
  Future<FrameLuma?> ambilContoh() async {
    jumlahContoh++;
    if (contoh.isEmpty) return null;

    return contoh[(jumlahContoh - 1).clamp(0, contoh.length - 1)];
  }

  @override
  Future<File> jepret() async {
    jumlahJepret++;
    if (jepretGalat != null) throw jepretGalat!;

    return foto;
  }

  @override
  Future<void> lepas() async => jumlahLepas++;
}

const _lebar = 320;
const _tinggi = 240;

/// Frame sintetis 320×240 dari fungsi luma per piksel.
FrameLuma frameSintetis(int Function(int x, int y) isi) {
  final bita = Uint8List(_lebar * _tinggi);
  for (var y = 0; y < _tinggi; y++) {
    for (var x = 0; x < _lebar; x++) {
      bita[y * _lebar + x] = isi(x, y);
    }
  }

  return FrameLuma(
    bita: bita,
    lebar: _lebar,
    tinggi: _tinggi,
    barisBita: _lebar,
  );
}

/// Seluruh frame satu nilai luma.
FrameLuma frameRata(int nilai) => frameSintetis((x, y) => nilai);

/// Kertas rata (tanpa garis) di alas gelap, utuh di dalam bingkai: terang,
/// tak tersentuh tepi, tapi tak punya tepi tajam → "buram".
FrameLuma frameBuram() => frameSintetis(
  (x, y) => x >= 40 && x < 280 && y >= 30 && y < 210 ? 200 : 20,
);

/// Kertas berkotak garis hitam yang melewati tepi kiri bingkai → "halaman
/// terpotong".
FrameLuma frameTerpotong() => frameSintetis((x, y) {
  if (x >= 280 || y < 10 || y >= 230) return 20;

  return x % 12 == 0 || y % 12 == 0 ? 10 : 210;
});

/// Kertas berkotak garis hitam di atas alas gelap, utuh di dalam bingkai,
/// tajam dan merata: tidak ada saran.
FrameLuma frameBagus({int kertas = 210}) => frameSintetis((x, y) {
  if (x < 40 || x >= 280 || y < 10 || y >= 230) return 20;

  return x % 12 == 0 || y % 12 == 0 ? 10 : kertas;
});

/// Kertas yang agak gelap (di bawah kecerahan baik, di atas ambang senter).
FrameLuma frameAgakGelap() => frameBagus(kertas: 70);

/// Pita bayangan tajam melintang di tengah kertas.
FrameLuma frameBayangan() => frameSintetis((x, y) {
  if (x < 40 || x >= 280 || y < 10 || y >= 230) return 20;
  if (y >= 100 && y < 140) return x % 12 == 0 ? 10 : 40;

  return x % 12 == 0 || y % 12 == 0 ? 10 : 210;
});

/// [frameBagus] yang tersapu mendatar (HP bergerak): garis tegak lenyap,
/// garis mendatar tetap tajam.
FrameLuma frameGerak({int kernel = 9}) {
  final asli = frameBagus();
  final bita = Uint8List(_lebar * _tinggi);
  for (var y = 0; y < _tinggi; y++) {
    for (var x = 0; x < _lebar; x++) {
      var jumlah = 0;
      for (var d = 0; d < kernel; d++) {
        final xs = (x + d - kernel ~/ 2).clamp(0, _lebar - 1);
        jumlah += asli.luma(xs, y);
      }
      bita[y * _lebar + x] = jumlah ~/ kernel;
    }
  }

  return FrameLuma(
    bita: bita,
    lebar: _lebar,
    tinggi: _tinggi,
    barisBita: _lebar,
  );
}
