import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sidik_calibration/providers/foto_kompres_provider.dart';
import 'package:sidik_calibration/providers/layout_provider.dart';
import 'package:sidik_calibration/services/layout/detektor_layout.dart';
import 'package:sidik_calibration/services/layout/detektor_layout_ocrkit.dart';
import 'package:sidik_calibration/services/layout/model_layout.dart';

/// OcrKit palsu: mencatat urutan panggilan.
class _KitPalsu implements PermukaanOcrKit {
  _KitPalsu({this.galatInit = false, this.galatDeteksi = false});

  final bool galatInit;
  final bool galatDeteksi;
  final urutan = <String>[];

  @override
  void init(String modelPath) {
    urutan.add('init:$modelPath');
    if (galatInit) throw StateError('init gagal');
  }

  @override
  LayoutMentah detectLayout(String imagePath, {double confThreshold = 0.5}) {
    urutan.add('detect:$imagePath@$confThreshold');
    if (galatDeteksi) throw StateError('deteksi gagal');

    return (
      lebar: 1000,
      tinggi: 1400,
      durasiMs: 12,
      wilayah: [
        (
          kelas: 'Table',
          skor: 0.9,
          x1: 100.0,
          y1: 200.0,
          x2: 900.0,
          y2: 1200.0,
        ),
        (kelas: 'Title', skor: 0.8, x1: 100.0, y1: 20.0, x2: 900.0, y2: 80.0),
      ],
    );
  }

  @override
  void releaseLayout() => urutan.add('release');
}

class _MesinPalsu implements MesinLayout {
  _MesinPalsu({this.galat});

  final Object? galat;
  int dipanggil = 0;
  String? pathCitra;
  bool citraAdaSaatDeteksi = false;

  @override
  Future<LayoutMentah> deteksi({
    required String modelPath,
    required String imagePath,
    double ambang = 0.5,
  }) async {
    dipanggil++;
    pathCitra = imagePath;
    citraAdaSaatDeteksi = File(imagePath).existsSync();
    if (galat != null) throw galat!;

    return (
      lebar: 1000,
      tinggi: 1400,
      durasiMs: 5,
      wilayah: [
        (
          kelas: 'Table',
          skor: 0.9,
          x1: 100.0,
          y1: 200.0,
          x2: 900.0,
          y2: 1200.0,
        ),
      ],
    );
  }
}

void main() {
  group('deteksiLayoutSinkron: releaseLayout() di finally', () {
    test('urutan init -> deteksi -> release', () {
      final kit = _KitPalsu();
      final hasil = deteksiLayoutSinkron(
        kit,
        modelPath: '/m.onnx',
        imagePath: '/f.jpg',
        ambang: 0.4,
      );

      expect(kit.urutan, ['init:/m.onnx', 'detect:/f.jpg@0.4', 'release']);
      expect(hasil.wilayah.length, 2);
    });

    test('deteksi melempar -> release TETAP dipanggil', () {
      final kit = _KitPalsu(galatDeteksi: true);

      expect(
        () => deteksiLayoutSinkron(kit, modelPath: '/m', imagePath: '/f'),
        throwsStateError,
      );
      expect(kit.urutan.last, 'release');
    });

    test('init melempar -> release TETAP dipanggil, deteksi tak jalan', () {
      final kit = _KitPalsu(galatInit: true);

      expect(
        () => deteksiLayoutSinkron(kit, modelPath: '/m', imagePath: '/f'),
        throwsStateError,
      );
      expect(kit.urutan, ['init:/m', 'release']);
    });
  });

  group('DetektorLayoutOcrKit', () {
    late Directory dir;
    final isi = List<int>.generate(2000, (i) => i % 251);
    late PengelolaModelLayout model;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('detektor-layout-test');
      File('${dir.path}/m.onnx').writeAsBytesSync(isi);
      model = PengelolaModelLayout(
        direktori: () async => dir,
        klien: MockClient(
          (_) async => throw StateError('tak boleh ke jaringan'),
        ),
        spesifikasi: SpesifikasiModelLayout(
          namaBerkas: 'm.onnx',
          url: 'https://contoh.test/m.onnx',
          ukuranByte: isi.length,
          sha256Hex: sha256.convert(isi).toString(),
        ),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    DetektorLayoutOcrKit bikin(MesinLayout mesin, {bool didukung = true}) =>
        DetektorLayoutOcrKit(
          model: model,
          mesin: mesin,
          direktoriSementara: () async => dir,
          platformDidukung: didukung,
        );

    test('foto ditulis sementara, dibaca native, lalu DIHAPUS', () async {
      final mesin = _MesinPalsu();
      final tahap = <TahapLayout>[];
      final hasil = await bikin(mesin).deteksi(
        Uint8List.fromList([1, 2, 3]),
        kemajuan: (t, _) => tahap.add(t),
      );

      expect(mesin.citraAdaSaatDeteksi, isTrue);
      expect(File(mesin.pathCitra!).existsSync(), isFalse);
      expect(hasil.jumlahTabel, 1);
      expect(
        hasil.wilayah.single.kotak,
        const Rect.fromLTRB(100, 200, 900, 1200),
      );
      expect(tahap.last, TahapLayout.mendeteksi);
    });

    test(
      'native melempar -> LayoutGagal(deteksiGagal) dan foto tetap dihapus',
      () async {
        final mesin = _MesinPalsu(galat: StateError('onnx mati'));

        await expectLater(
          bikin(mesin).deteksi(Uint8List.fromList([1])),
          throwsA(
            isA<LayoutGagal>().having(
              (e) => e.sebab,
              'sebab',
              SebabLayoutGagal.deteksiGagal,
            ),
          ),
        );
        expect(File(mesin.pathCitra!).existsSync(), isFalse);
      },
    );

    test('platform tak didukung -> bypass: native TIDAK disentuh', () async {
      final mesin = _MesinPalsu();
      final d = bikin(mesin, didukung: false);

      expect(d.tersedia, isFalse);
      await expectLater(
        d.deteksi(Uint8List.fromList([1])),
        throwsA(
          isA<LayoutGagal>().having(
            (e) => e.sebab,
            'sebab',
            SebabLayoutGagal.platformTakDidukung,
          ),
        ),
      );
      expect(mesin.dipanggil, 0);
    });

    test(
      'DetektorLayoutTakTersedia: tersedia=false & selalu platformTakDidukung',
      () async {
        const d = DetektorLayoutTakTersedia();

        expect(d.tersedia, isFalse);
        await expectLater(d.siapkan(), throwsA(isA<LayoutGagal>()));
        await expectLater(d.deteksi(Uint8List(1)), throwsA(isA<LayoutGagal>()));
      },
    );
  });

  group('provider: bypass platform', () {
    test('bukan Android (Windows/iOS/test) -> DetektorLayoutTakTersedia', () {
      final c = ProviderContainer(
        overrides: [layoutDidukungPlatformProvider.overrideWithValue(false)],
      );
      addTearDown(c.dispose);

      final d = c.read(detektorLayoutProvider);

      expect(d, isA<DetektorLayoutTakTersedia>());
      expect(d.tersedia, isFalse);
    });

    test('Android -> DetektorLayoutOcrKit yang tersedia', () {
      final c = ProviderContainer(
        overrides: [layoutDidukungPlatformProvider.overrideWithValue(true)],
      );
      addTearDown(c.dispose);

      final d = c.read(detektorLayoutProvider);

      expect(d, isA<DetektorLayoutOcrKit>());
      expect(d.tersedia, isTrue);
    });

    test('di bawah flutter test selalu false (tidak bergantung mesin)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(layoutDidukungPlatformProvider), isFalse);
      expect(c.read(kompresNativeTersediaProvider), isFalse);
    });

    test('kompresi: native hanya di Android; Dart murni selalu ada', () {
      for (final android in [true, false]) {
        final c = ProviderContainer(
          overrides: [kompresNativeTersediaProvider.overrideWithValue(android)],
        );
        addTearDown(c.dispose);

        final nama = c.read(fotoKompresProvider).namaMesin;

        expect(nama.last, 'dart-murni');
        expect(nama.contains('flutter_image_compress'), android);
      }
    });
  });

  group('peringatanDariLayout', () {
    HasilLayout hasil(List<WilayahLayout> w) =>
        HasilLayout(wilayah: w, lebar: 1000, tinggi: 1400, durasiMs: 1);
    WilayahLayout tabel(Rect r) =>
        WilayahLayout(kelas: 'Table', skor: 0.9, kotak: r);

    test('null (layout dilewati) -> tanpa petunjuk', () {
      expect(peringatanDariLayout(null), isEmpty);
    });

    test('tanpa tabel -> tabelTakTerdeteksi', () {
      expect(
        peringatanDariLayout(
          hasil([
            const WilayahLayout(
              kelas: 'Text',
              skor: 0.9,
              kotak: Rect.fromLTRB(0, 0, 10, 10),
            ),
          ]),
        ),
        [PeringatanLayout.tabelTakTerdeteksi],
      );
    });

    test('tabel di tengah -> bersih', () {
      expect(
        peringatanDariLayout(
          hasil([tabel(const Rect.fromLTRB(100, 200, 900, 1200))]),
        ),
        isEmpty,
      );
    });

    test('tabel menyentuh tepi (margin 1% sisi pendek) -> tabelTerpotong', () {
      for (final r in const [
        Rect.fromLTRB(5, 200, 900, 1200),
        Rect.fromLTRB(100, 3, 900, 1200),
        Rect.fromLTRB(100, 200, 995, 1200),
        Rect.fromLTRB(100, 200, 900, 1395),
      ]) {
        expect(peringatanDariLayout(hasil([tabel(r)])), [
          PeringatanLayout.tabelTerpotong,
        ], reason: '$r');
      }
    });
  });
}
