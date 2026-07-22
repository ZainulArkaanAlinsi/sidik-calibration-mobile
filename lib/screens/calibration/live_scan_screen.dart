import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../services/worksheet_ocr.dart';

/// Satu angka yang lagi kelihatan di pratinjau, beserta kotaknya **dalam
/// koordinat gambar** (bukan koordinat layar).
class _AngkaHidup {
  const _AngkaHidup({required this.nilai, required this.kotak});

  final double nilai;
  final Rect kotak;
}

/// Scan worksheet dengan **pratinjau kamera langsung** — angka yang kebaca
/// nempel mengambang di atas gambar, jadi teknisi tahu sekarang juga apakah
/// arahnya udah bener, bukan setelah jepret.
///
/// ## Kenapa ini beda dari sekali-jepret
///
/// Foto diam cuma punya satu kesempatan dan **nggak bawa arah sensor**. Foto
/// miring atau kebalik jadi mustahil dibetulin sesudahnya — itu sebab
/// terbesar scan gagal di lapangan. Aliran frame bawa `sensorOrientation`,
/// jadi ML Kit tahu mana atas walau HP-nya dipegang miring.
///
/// Dan karena frame-nya puluhan per detik, teknisi bisa **menggeser sampai
/// angkanya muncul**, bukan menebak lalu kecewa.
class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key, this.jumlahTitik = 3, this.jumlahBaris = 5});

  final int jumlahTitik;
  final int jumlahBaris;

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen>
    with WidgetsBindingObserver {
  CameraController? _kamera;
  final _pengenal = TextRecognizer(script: TextRecognitionScript.latin);

  /// Frame lagi diproses. Tanpa gerbang ini, frame numpuk lebih cepat dari
  /// kemampuan ML Kit dan HP kelas menengah langsung tersendat.
  bool _sibuk = false;

  List<_AngkaHidup> _angka = const [];
  Size _ukuranGambar = Size.zero;

  /// Hasil terbaik sejauh ini. Yang dipakai waktu teknisi nekan "Pakai" —
  /// bukan frame terakhir, karena tangan yang gerak waktu nekan tombol sering
  /// bikin frame terakhir justru yang paling buram.
  HasilTabelOcr? _terbaik;

  String? _galat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mulai();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final kamera = _kamera;
    if (kamera == null || !kamera.value.isInitialized) return;

    // Kamera dilepas waktu app ke belakang — kalau nggak, Android nutup paksa
    // sesinya dan waktu balik lagi pratinjaunya hitam tanpa error.
    if (state == AppLifecycleState.inactive) {
      kamera.dispose();
      _kamera = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _mulai();
    }
  }

  Future<void> _mulai() async {
    try {
      final kamera = await availableCameras();
      if (kamera.isEmpty) {
        setState(() => _galat = 'tanpa-kamera');
        return;
      }

      final belakang = kamera.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => kamera.first,
      );

      final controller = CameraController(
        belakang,
        // Angka kecil di tabel butuh detail; resolusi rendah bikin koma ilang
        // dan `4,04` kebaca `404`.
        ResolutionPreset.high,
        enableAudio: false,
        // ML Kit di Android maunya NV21. Salah format = nggak ada teks yang
        // kebaca sama sekali, tanpa pesan error.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.startImageStream(_prosesFrame);
      setState(() {
        _kamera = controller;
        _galat = null;
      });
    } catch (e) {
      if (mounted) setState(() => _galat = 'gagal-buka');
    }
  }

  Future<void> _prosesFrame(CameraImage frame) async {
    if (_sibuk || !mounted) return;
    _sibuk = true;

    try {
      final input = _keInputImage(frame);
      if (input == null) return;

      final hasil = await _pengenal.processImage(input);
      if (!mounted) return;

      final kotak = <KotakAngka>[];
      final hidup = <_AngkaHidup>[];

      for (final blok in hasil.blocks) {
        for (final baris in blok.lines) {
          for (final elemen in baris.elements) {
            final nilai = TabelWorksheetParser.keAngka(elemen.text);
            if (nilai == null) continue;

            final b = elemen.boundingBox;
            kotak.add(
              KotakAngka(
                nilai: nilai,
                x: b.left + b.width / 2,
                y: b.top + b.height / 2,
              ),
            );
            hidup.add(
              _AngkaHidup(
                nilai: nilai,
                kotak: Rect.fromLTWH(
                  b.left.toDouble(),
                  b.top.toDouble(),
                  b.width.toDouble(),
                  b.height.toDouble(),
                ),
              ),
            );
          }
        }
      }

      // Cuma kandidat isi sel yang dipajang — kop, nomor formulir, dan tahun
      // nggak usah ikut mengambang, cuma bikin layar ramai.
      final kandidat = TabelWorksheetParser.saringKandidat(kotak);
      final nilaiKandidat = kandidat.map((k) => k.nilai).toSet();

      final tabel = TabelWorksheetParser.susun(
        kotak,
        teksMentah: hasil.text,
        jumlahTitik: widget.jumlahTitik,
        jumlahBaris: widget.jumlahBaris,
      );

      setState(() {
        _ukuranGambar = Size(
          frame.width.toDouble(),
          frame.height.toDouble(),
        );
        _angka = hidup
            .where((a) => nilaiKandidat.contains(a.nilai))
            .toList(growable: false);

        // Simpan yang paling penuh, bukan yang paling baru.
        if (tabel != null &&
            tabel.jumlahSelKebaca > (_terbaik?.jumlahSelKebaca ?? 0)) {
          _terbaik = tabel;
        }
      });
    } catch (_) {
      // Frame rusak itu wajar waktu kamera lagi fokus ulang — dilewat aja,
      // frame berikutnya nyusul beberapa milidetik lagi.
    } finally {
      _sibuk = false;
    }
  }

  /// Bungkus frame kamera jadi `InputImage`, **lengkap dengan arah sensor**.
  ///
  /// Ini inti kenapa live view kebal posisi: `sensorOrientation` ngasih tahu
  /// ML Kit mana atas, jadi HP yang dipegang miring atau kebalik tetap kebaca.
  /// Foto diam nggak punya informasi ini.
  InputImage? _keInputImage(CameraImage frame) {
    final controller = _kamera;
    if (controller == null) return null;

    final rotasi = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);
    if (rotasi == null || format == null) return null;

    // NV21 (Android) & BGRA8888 (iOS) sama-sama satu bidang — makanya
    // `imageFormatGroup` di atas dipaksa, bukan dibiarin default YUV420 yang
    // bidangnya tiga.
    if (frame.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: frame.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotasi,
        format: format,
        bytesPerRow: frame.planes.first.bytesPerRow,
      ),
    );
  }

  void _pakai() {
    // Balikin yang terbaik walau belum penuh — sel yang kosong tetap bisa
    // diketik. Nahan hasil sampai sempurna itu yang bikin teknisi mentok.
    Navigator.of(context).pop(_terbaik);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kamera?.dispose();
    _pengenal.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kamera = _kamera;
    final terbaca = _terbaik?.jumlahSelKebaca ?? 0;
    final diharapkan = widget.jumlahBaris * widget.jumlahTitik * 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.phCalibLiveJudul),
      ),
      body: _galat != null
          ? _Galat(
              pesan: _galat == 'tanpa-kamera'
                  ? l10n.phCalibLiveTanpaKamera
                  : l10n.phCalibScanError,
            )
          : kamera == null || !kamera.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(kamera),
                    if (_ukuranGambar != Size.zero)
                      CustomPaint(
                        painter: _PelukisAngka(
                          angka: _angka,
                          ukuranGambar: _ukuranGambar,
                          rotasiSensor:
                              kamera.description.sensorOrientation,
                        ),
                      ),
                    _PanelBawah(
                      terbaca: terbaca,
                      diharapkan: diharapkan,
                      petunjuk: terbaca == 0
                          ? l10n.phCalibLivePetunjuk
                          : l10n.phCalibFotoTabelHasil(terbaca, diharapkan),
                      onPakai: terbaca == 0 ? null : _pakai,
                      labelPakai: l10n.phCalibLivePakai,
                    ),
                  ],
                ),
    );
  }
}

/// Gambar angka yang kebaca, mengambang tepat di atas letak aslinya.
class _PelukisAngka extends CustomPainter {
  _PelukisAngka({
    required this.angka,
    required this.ukuranGambar,
    required this.rotasiSensor,
  });

  final List<_AngkaHidup> angka;
  final Size ukuranGambar;
  final int rotasiSensor;

  @override
  void paint(Canvas canvas, Size size) {
    if (ukuranGambar.isEmpty) return;

    // Sensor HP biasanya lanskap sementara layarnya potret — di rotasi 90°
    // atau 270°, lebar & tinggi gambar ketuker dibanding yang tampil.
    final berputar = rotasiSensor == 90 || rotasiSensor == 270;
    final lebarSumber = berputar ? ukuranGambar.height : ukuranGambar.width;
    final tinggiSumber = berputar ? ukuranGambar.width : ukuranGambar.height;

    final skalaX = size.width / lebarSumber;
    final skalaY = size.height / tinggiSumber;

    final kotakCat = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.success.withValues(alpha: 0.85);

    for (final a in angka) {
      // Kotak dari ML Kit ada di ruang gambar yang UDAH diputar sesuai
      // metadata, jadi tinggal diskalakan.
      final r = Rect.fromLTWH(
        a.kotak.left * skalaX,
        a.kotak.top * skalaY,
        a.kotak.width * skalaX,
        a.kotak.height * skalaY,
      );

      final teks = TextPainter(
        text: TextSpan(
          text: _ringkas(a.nilai),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Label ditaruh PAS di atas angkanya, bukan menutupi — teknisi perlu
      // lihat tulisan aslinya buat mastiin OCR-nya bener.
      final lebarLabel = teks.width + 12;
      final kiri = (r.center.dx - lebarLabel / 2).clamp(
        0.0,
        size.width - lebarLabel,
      );
      final atas = (r.top - teks.height - 10).clamp(0.0, size.height);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(kiri, atas, lebarLabel, teks.height + 4),
          const Radius.circular(6),
        ),
        kotakCat,
      );
      teks.paint(canvas, Offset(kiri + 6, atas + 2));

      // Garis tipis di angka aslinya, biar jelas label itu punya yang mana.
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.success.withValues(alpha: 0.7),
      );
    }
  }

  static String _ringkas(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  bool shouldRepaint(covariant _PelukisAngka old) =>
      old.angka != angka || old.ukuranGambar != ukuranGambar;
}

class _PanelBawah extends StatelessWidget {
  const _PanelBawah({
    required this.terbaca,
    required this.diharapkan,
    required this.petunjuk,
    required this.onPakai,
    required this.labelPakai,
  });

  final int terbaca;
  final int diharapkan;
  final String petunjuk;
  final VoidCallback? onPakai;
  final String labelPakai;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              petunjuk,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPakai,
                icon: const Icon(Icons.check),
                label: Text(labelPakai),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Galat extends StatelessWidget {
  const _Galat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          pesan,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
