import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart'
    show AmbangMutu;
import 'package:sidik_calibration/services/kamera_pindai.dart';
import 'package:sidik_calibration/services/kamera_plugin.dart';
import 'package:sidik_calibration/services/petunjuk_kamera.dart';

import 'support/kontrol_kamera_palsu.dart';

/// Petunjuk langsung layar kamera: pengukur frame, pemilih saran, peredam
/// kedip, dan pemetaan frame/galat plugin — semuanya logika murni, jadi diuji
/// di host dengan frame sintetis. Semua ambang berasal dari SATU konstanta
/// (`AmbangFotoLembar`); test ini mengunci nilainya dan perilaku di sekitar
/// batasnya. Nilainya masih USULAN dari uji rig (perlu dikalibrasi di HP).

const _lebar = 320;
const _tinggi = 240;

/// Frame sintetis. [isi] mengembalikan luma (0..255) per piksel. [pad] byte
/// sisa di tiap baris (rowStride > lebar) diisi 255 — terang — supaya pembaca
/// yang mengabaikan stride langsung salah ukur.
FrameLuma _frame(
  int Function(int x, int y) isi, {
  int pad = 0,
  int langkah = 1,
  int awal = 0,
  int lebar = _lebar,
  int tinggi = _tinggi,
}) {
  final baris = lebar * langkah + pad;
  final bita = Uint8List(baris * tinggi);
  for (var y = 0; y < tinggi; y++) {
    for (var b = lebar * langkah; b < baris; b++) {
      bita[y * baris + b] = 255;
    }
    for (var x = 0; x < lebar; x++) {
      bita[y * baris + x * langkah + awal] = isi(x, y);
    }
  }

  return FrameLuma(
    bita: bita,
    lebar: lebar,
    tinggi: tinggi,
    barisBita: baris,
    langkahPiksel: langkah,
    awal: awal,
  );
}

PetunjukKamera? _saran(
  FrameLuma f, {
  bool senterTersedia = true,
  bool senterNyala = false,
}) => petunjukDari(
  UkurFrame.ukur(f)!,
  senterTersedia: senterTersedia,
  senterNyala: senterNyala,
);

/// `CameraController` tiruan: mencatat urutan panggilan, tanpa plugin native.
class _KontrolerPalsu extends CameraController {
  _KontrolerPalsu(
    CameraDescription deskripsi,
    this.catatan, {
    this.flashMatiGagal = false,
  }) : super(deskripsi, ResolutionPreset.low, enableAudio: false);

  final List<String> catatan;
  final bool flashMatiGagal;

  @override
  Future<void> initialize() async => catatan.add('initialize');

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    catatan.add('flash:${mode.name}');
    if (flashMatiGagal && mode == FlashMode.off) {
      throw CameraException('setFlashModeFailed', 'tiruan');
    }
  }

  @override
  Future<void> dispose() async {
    catatan.add('dispose');
    // Aman di host: `initialize` tiruan tidak membuat `_initializeFuture`,
    // jadi dispose asli tidak menyentuh plugin.
    await super.dispose();
  }
}

const _kameraBelakang = CameraDescription(
  name: '0',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void _samaUkuran(UkuranFrame a, UkuranFrame b) {
  expect(a.kecerahanKertas, b.kecerahanKertas);
  expect(a.glare, b.glare);
  expect(a.ketajaman, b.ketajaman);
  expect(a.anisotropi, b.anisotropi);
  expect(a.bayanganRasio, b.bayanganRasio);
  expect(a.bayanganTergelap, b.bayanganTergelap);
  expect(a.kertasTerlihat, b.kertasTerlihat);
  expect(a.sisiMenyentuhTepi, b.sisiMenyentuhTepi);
}

void main() {
  group('AmbangFotoLembar: nilai awal dari rig terkunci', () {
    test('angka usulan 13 Nov 2026 (ubah SENGAJA, bersama kalibrasi HP)', () {
      expect(AmbangFotoLembar.sisiPanjangAnalisisPx, 1000);
      expect(AmbangFotoLembar.blurBaikMin, 1500);
      expect(AmbangFotoLembar.blurSaranUlangMaks, 600);
      expect(AmbangFotoLembar.gerakRasioMin, 0.25);
      expect(AmbangFotoLembar.tinggiBarisBaikPx, 35);
      expect(AmbangFotoLembar.tinggiBarisTolakPx, 25);
      expect(AmbangFotoLembar.sisiPanjangMinPx, 3300);
      expect(AmbangFotoLembar.kecerahanBaikMin, 100);
      expect(AmbangFotoLembar.kecerahanSaranSenterMaks, 60);
      expect(AmbangFotoLembar.bayanganRasioMin, 0.25);
      expect(AmbangFotoLembar.bayanganTergelapMin, 50);
      expect(AmbangFotoLembar.jenuhMin, 250);
      expect(AmbangFotoLembar.jenuhPorsiMaks, 0.10);
      expect(AmbangFotoLembar.miringKameraMaksDeg, 15);
      expect(AmbangFotoLembar.marginTepi, 0.02);
      expect(AmbangFotoLembar.contohKosongMaks, 3);
    });

    test('urutan wajar: peringatan di antara baik dan tolak', () {
      expect(
        AmbangFotoLembar.blurSaranUlangMaks,
        lessThan(AmbangFotoLembar.blurBaikMin),
      );
      expect(
        AmbangFotoLembar.kecerahanSaranSenterMaks,
        lessThan(AmbangFotoLembar.kecerahanBaikMin),
      );
      expect(
        AmbangFotoLembar.tinggiBarisTolakPx,
        lessThan(AmbangFotoLembar.tinggiBarisBaikPx),
      );
    });

    test('yang SATU dengan gerbang pasca-jepret dipinjam, bukan disalin', () {
      expect(
        AmbangFotoLembar.kecerahanSaranSenterMaks,
        AmbangMutu.kecerahanMin,
        reason: 'saran senter muncul tepat di ambang penolakan "terlalu gelap"',
      );
      expect(
        AmbangFotoLembar.tinggiBarisTolakPx,
        greaterThanOrEqualTo(AmbangMutu.pxPerSelMin),
        reason: 'ambang resolusi rig tidak boleh lebih longgar dari gerbang',
      );
    });

    test('resolusi jepret kamera sendiri memenuhi sisi panjang minimal', () {
      // `ResolutionPreset.ultraHigh` = 3840×2160 (lihat kamera_plugin.dart).
      const sisiUltraHigh = 3840;

      expect(resolusiKameraPindai.name, 'ultraHigh');
      expect(
        sisiUltraHigh,
        greaterThanOrEqualTo(AmbangFotoLembar.sisiPanjangMinPx),
      );
    });
  });

  group('UkurFrame + petunjukDari (frame sintetis)', () {
    test('lembar jelas di alas gelap, utuh di dalam bingkai: tanpa saran', () {
      final u = UkurFrame.ukur(frameBagus())!;

      expect(u.kertasTerlihat, isTrue);
      expect(u.sisiMenyentuhTepi, 0);
      expect(u.ketajaman, greaterThan(AmbangFotoLembar.blurBaikMin));
      expect(u.anisotropi, greaterThan(AmbangFotoLembar.gerakRasioMin));
      expect(
        u.kecerahanKertas,
        greaterThanOrEqualTo(AmbangFotoLembar.kecerahanBaikMin),
      );
      expect(u.glare, 0);
      expect(petunjukDari(u, senterTersedia: true, senterNyala: false), isNull);
    });

    test('gelap + senter belum menyala: saran NYALAKAN SENTER', () {
      expect(_saran(_frame((x, y) => 30)), PetunjukKamera.gelapNyalakanSenter);
    });

    test('gelap tapi senter sudah menyala / tidak ada: cari cahaya lain', () {
      final f = _frame((x, y) => 30);

      expect(
        _saran(f, senterNyala: true),
        PetunjukKamera.gelapTambahCahaya,
        reason: 'senter sudah menyala; menyuruh menyalakannya lagi percuma',
      );
      expect(
        _saran(f, senterTersedia: false),
        PetunjukKamera.gelapTambahCahaya,
        reason: 'tablet tanpa senter tidak boleh disuruh menyalakannya',
      );
    });

    test('kertas agak gelap (60–100): peringatan, bukan saran senter', () {
      final f = frameAgakGelap();
      final u = UkurFrame.ukur(f)!;

      expect(u.kecerahanKertas, inInclusiveRange(60, 99.9));
      expect(_saran(f), PetunjukKamera.agakGelap);
    });

    test('terlalu terang seluruhnya: silau', () {
      expect(_saran(_frame((x, y) => 255)), PetunjukKamera.silau);
    });

    test('pantulan setempat (>10% kertas jenuh): silau', () {
      final f = _frame((x, y) {
        if (x >= 100 && x < 190 && y >= 80 && y < 160) return 255;

        return frameBagus().luma(x, y) == 10 ? 10 : 200;
      });
      final u = UkurFrame.ukur(f)!;

      expect(u.glare, greaterThan(AmbangFotoLembar.jenuhPorsiMaks));
      expect(_saran(f), PetunjukKamera.silau);
    });

    test('pita bayangan tajam di atas kertas: bayangan', () {
      final f = frameBayangan();
      final u = UkurFrame.ukur(f)!;

      expect(u.bayanganRasio, lessThan(AmbangFotoLembar.bayanganRasioMin));
      expect(_saran(f), PetunjukKamera.bayangan);
    });

    test('bayangan lembut (rasio ≥ 0,25 dan terang ≥ 50) tidak dituduh', () {
      final f = _frame((x, y) {
        if (x < 40 || x >= 280 || y < 10 || y >= 230) return 20;
        if (y >= 100 && y < 140) return x % 12 == 0 ? 10 : 120;

        return x % 12 == 0 || y % 12 == 0 ? 10 : 210;
      });
      final u = UkurFrame.ukur(f)!;

      expect(
        u.bayanganRasio,
        greaterThanOrEqualTo(AmbangFotoLembar.bayanganRasioMin),
      );
      expect(_saran(f), isNull);
    });

    test('kertas melewati tepi bingkai: halaman terpotong', () {
      final f = frameTerpotong();
      final u = UkurFrame.ukur(f)!;

      expect(u.sisiMenyentuhTepi, 1, reason: 'hanya tepi kiri tersentuh');
      expect(_saran(f), PetunjukKamera.halamanTerpotong);
    });

    test('margin tepi 2%: kertas 2 px dari kiri (0,6%) menyentuh tepi, '
        '5 px (1,6%) tidak', () {
      FrameLuma kiri(int mulai) => _frame(
        (x, y) => x < mulai || x >= 280 || y < 10 || y >= 230 ? 20 : 210,
      );

      expect(UkurFrame.ukur(kiri(2))!.sisiMenyentuhTepi, 1);
      expect(UkurFrame.ukur(kiri(5))!.sisiMenyentuhTepi, 0);
    });

    test('kertas tanpa tepi keras sama sekali (defokus): buram', () {
      // Kertas rata tanpa garis — variansi Laplacian nol.
      final f = frameBuram();
      final u = UkurFrame.ukur(f)!;

      expect(u.ketajaman, lessThan(AmbangFotoLembar.blurSaranUlangMaks));
      expect(_saran(f), PetunjukKamera.buram);
    });

    test('tersapu mendatar (HP bergerak): buram gerak, garis mendatar masih '
        'tajam sehingga bukan "buram" biasa', () {
      final f = frameGerak();
      final u = UkurFrame.ukur(f)!;

      expect(u.anisotropi, lessThan(AmbangFotoLembar.gerakRasioMin));
      expect(
        u.ketajaman,
        greaterThanOrEqualTo(AmbangFotoLembar.blurSaranUlangMaks),
      );
      expect(_saran(f), PetunjukKamera.buramGerak);
    });

    test('lembar tajam: rasio gradien jauh di atas ambang gerak', () {
      expect(
        UkurFrame.ukur(frameBagus())!.anisotropi,
        greaterThan(AmbangFotoLembar.gerakRasioMin * 2),
      );
    });

    test(
      'stride (rowStride > lebar) dihormati: hasil sama dengan tanpa pad',
      () {
        final polos = UkurFrame.ukur(frameBagus())!;
        final berpad = UkurFrame.ukur(
          _frame((x, y) => frameBagus().luma(x, y), pad: 24),
        )!;

        _samaUkuran(berpad, polos);
      },
    );

    test('BGRA (iOS): kanal hijau dibaca dengan langkah 4 dan awal 1', () {
      final polos = UkurFrame.ukur(frameBagus())!;
      final bgra = UkurFrame.ukur(
        _frame((x, y) => frameBagus().luma(x, y), langkah: 4, awal: 1),
      )!;

      _samaUkuran(bgra, polos);
    });

    test('frame besar diperkecil ke ±1000 px dan tetap dinilai sama', () {
      // Adegan yang sama digambar di 640×480 dan 2560×1920 (garis 4 px di
      // yang besar, 1 px di yang kecil): setelah diperkecil, hasilnya
      // setara dan tetap tanpa saran.
      int adegan(int x, int y, int s) {
        final sx = x ~/ s;
        final sy = y ~/ s;
        final di = sx >= 80 && sx < 560 && sy >= 20 && sy < 460;
        if (!di) return 20;

        return sx % 24 == 0 || sy % 24 == 0 ? 10 : 210;
      }

      final kecil = _frame((x, y) => adegan(x, y, 1), lebar: 640, tinggi: 480);
      final besar = _frame(
        (x, y) => adegan(x, y, 4),
        lebar: 2560,
        tinggi: 1920,
      );

      expect(_saran(kecil), isNull);
      expect(_saran(besar), isNull);
      final a = UkurFrame.ukur(kecil)!;
      final b = UkurFrame.ukur(besar)!;
      expect(b.kecerahanKertas, closeTo(a.kecerahanKertas, 20));
      expect(b.sisiMenyentuhTepi, a.sisiMenyentuhTepi);
      // Tanpa diperkecil, garis 4 px jauh lebih jarang per luas dan variansi
      // Laplacian anjlok (±0,49 dengan perkecilan 1/3 bawaan, ±0,2 tanpa
      // perkecilan): skala yang diukur harus setara.
      final nisbah = b.ketajaman! / a.ketajaman!;
      expect(nisbah, inInclusiveRange(0.35, 3.0), reason: 'nisbah $nisbah');
    });

    test('frame terlalu kecil: tidak diukur', () {
      final kecil = FrameLuma(
        bita: Uint8List(16 * 16),
        lebar: 16,
        tinggi: 16,
        barisBita: 16,
      );

      expect(UkurFrame.ukur(kecil), isNull);
    });

    test(
      'ukurFrameDiIsolate = UkurFrame.ukur (frame bisa dikirim ke isolate)',
      () async {
        for (final f in [frameBagus(), frameGerak(), frameBayangan()]) {
          _samaUkuran((await ukurFrameDiIsolate(f))!, UkurFrame.ukur(f)!);
        }
      },
    );
  });

  group('ambang = AmbangFotoLembar (batas tepat)', () {
    UkuranFrame ukuran({
      double kecerahan = 150,
      double glare = 0,
      double? ketajaman = 5000,
      double? anisotropi = 0.5,
      double? bayanganRasio = 0.9,
      double? bayanganTergelap = 140,
      bool kertas = true,
      int sisi = 0,
    }) => UkuranFrame(
      kecerahanKertas: kecerahan,
      glare: glare,
      ketajaman: ketajaman,
      anisotropi: anisotropi,
      bayanganRasio: bayanganRasio,
      bayanganTergelap: bayanganTergelap,
      kertasTerlihat: kertas,
      sisiMenyentuhTepi: sisi,
    );

    PetunjukKamera? saran(UkuranFrame u) =>
        petunjukDari(u, senterTersedia: true, senterNyala: false);

    test('gelap: < 60 saran senter; 60 ≤ x < 100 peringatan; ≥ 100 baik', () {
      const gelap = AmbangFotoLembar.kecerahanSaranSenterMaks;
      const baik = AmbangFotoLembar.kecerahanBaikMin;

      expect(
        saran(ukuran(kecerahan: gelap - 0.01)),
        PetunjukKamera.gelapNyalakanSenter,
      );
      expect(saran(ukuran(kecerahan: gelap)), PetunjukKamera.agakGelap);
      expect(saran(ukuran(kecerahan: baik - 0.01)), PetunjukKamera.agakGelap);
      expect(saran(ukuran(kecerahan: baik)), isNull);
    });

    test('silau: tepat di 10% lolos, sedikit di atas silau', () {
      expect(saran(ukuran(glare: AmbangFotoLembar.jenuhPorsiMaks)), isNull);
      expect(
        saran(ukuran(glare: AmbangFotoLembar.jenuhPorsiMaks + 0.001)),
        PetunjukKamera.silau,
      );
    });

    test(
      'blur: < 600 saran foto ulang; 600–1500 peringatan (diam); ≥ 1500 baik',
      () {
        const tolak = AmbangFotoLembar.blurSaranUlangMaks;
        const baik = AmbangFotoLembar.blurBaikMin;

        expect(saran(ukuran(ketajaman: tolak - 0.01)), PetunjukKamera.buram);
        expect(saran(ukuran(ketajaman: tolak)), isNull);
        expect(saran(ukuran(ketajaman: (tolak + baik) / 2)), isNull);
        expect(saran(ukuran(ketajaman: baik)), isNull);
      },
    );

    test('blur gerak: tepat di 0,25 lolos, di bawahnya saran', () {
      const batas = AmbangFotoLembar.gerakRasioMin;

      expect(saran(ukuran(anisotropi: batas)), isNull);
      expect(
        saran(ukuran(anisotropi: batas - 0.01)),
        PetunjukKamera.buramGerak,
      );
    });

    test('bayangan: rasio < 0,25 ATAU blok tergelap < 50', () {
      const rasio = AmbangFotoLembar.bayanganRasioMin;
      const gelap = AmbangFotoLembar.bayanganTergelapMin;

      expect(saran(ukuran(bayanganRasio: rasio)), isNull);
      expect(
        saran(ukuran(bayanganRasio: rasio - 0.01)),
        PetunjukKamera.bayangan,
      );
      expect(saran(ukuran(bayanganTergelap: gelap)), isNull);
      expect(
        saran(ukuran(bayanganTergelap: gelap - 0.01)),
        PetunjukKamera.bayangan,
      );
    });

    test('tepi tersentuh (margin 2%): halaman terpotong', () {
      expect(saran(ukuran(sisi: 0)), isNull);
      expect(saran(ukuran(sisi: 1)), PetunjukKamera.halamanTerpotong);
    });

    test('tanpa kertas di bingkai: tak ada saran selain gelap/silau', () {
      expect(
        saran(ukuran(kertas: false, ketajaman: 0, anisotropi: 0, sisi: 4)),
        isNull,
      );
    });

    test(
      'urutan: gelap > silau > bayangan > terpotong > buram > gerak > agak gelap',
      () {
        UkuranFrame semua({
          double kecerahan = 80,
          double glare = 0.5,
          double rasio = 0.1,
          int sisi = 2,
          double tajam = 1,
          double gerak = 0.01,
        }) => ukuran(
          kecerahan: kecerahan,
          glare: glare,
          bayanganRasio: rasio,
          sisi: sisi,
          ketajaman: tajam,
          anisotropi: gerak,
        );

        expect(saran(semua(kecerahan: 10)), PetunjukKamera.gelapNyalakanSenter);
        expect(saran(semua()), PetunjukKamera.silau);
        expect(saran(semua(glare: 0)), PetunjukKamera.bayangan);
        expect(
          saran(semua(glare: 0, rasio: 0.9)),
          PetunjukKamera.halamanTerpotong,
        );
        expect(
          saran(semua(glare: 0, rasio: 0.9, sisi: 0)),
          PetunjukKamera.buram,
        );
        expect(
          saran(semua(glare: 0, rasio: 0.9, sisi: 0, tajam: 5000)),
          PetunjukKamera.buramGerak,
        );
        expect(
          saran(semua(glare: 0, rasio: 0.9, sisi: 0, tajam: 5000, gerak: 0.5)),
          PetunjukKamera.agakGelap,
        );
      },
    );
  });

  group('PenyaringPetunjuk (peredam kedip)', () {
    test('muncul setelah 2 sampel berturut-turut, hilang setelah 2 bersih', () {
      final p = PenyaringPetunjuk();

      expect(p.masukkan(PetunjukKamera.buram), isNull, reason: 'baru 1 sampel');
      expect(p.masukkan(PetunjukKamera.buram), PetunjukKamera.buram);
      expect(
        p.masukkan(null),
        PetunjukKamera.buram,
        reason: 'satu sampel bersih belum cukup menghilangkan saran',
      );
      expect(p.masukkan(null), isNull);
    });

    test('sampel selang-seling tidak membuat saran berkedip', () {
      final p = PenyaringPetunjuk();

      for (var i = 0; i < 6; i++) {
        expect(
          p.masukkan(i.isEven ? PetunjukKamera.silau : null),
          isNull,
          reason: 'tak pernah dua kali berturut-turut',
        );
      }
    });

    test('saran berganti hanya setelah pengganti stabil', () {
      final p = PenyaringPetunjuk();
      p.masukkan(PetunjukKamera.buram);
      p.masukkan(PetunjukKamera.buram);

      expect(p.masukkan(PetunjukKamera.silau), PetunjukKamera.buram);
      expect(p.masukkan(PetunjukKamera.silau), PetunjukKamera.silau);
    });

    test('ulang() melupakan saran lama', () {
      final p = PenyaringPetunjuk();
      p.masukkan(PetunjukKamera.buram);
      p.masukkan(PetunjukKamera.buram);
      p.ulang();

      expect(p.tampil, isNull);
    });
  });

  group('KontrolKameraPlugin.buka (kontroler tiruan)', () {
    Future<KontrolKamera> bukaTiruan(
      List<String> catatan, {
      bool flashMatiGagal = false,
    }) => KontrolKameraPlugin.buka(
      daftarKamera: () async => [_kameraBelakang],
      bangunKontroler: (d, r) =>
          _KontrolerPalsu(d, catatan, flashMatiGagal: flashMatiGagal),
    );

    test('setelah initialize, flash dipasang OFF (bawaan iOS .auto bisa '
        'menyalakan strobe sendiri)', () async {
      final catatan = <String>[];
      final k = await bukaTiruan(catatan);

      expect(catatan, ['initialize', 'flash:off']);
      expect(k.senterNyala, isFalse, reason: 'senter tak menyala sendiri');
    });

    test('jalur senter (torch) tetap utuh', () async {
      final catatan = <String>[];
      final k = await bukaTiruan(catatan);

      expect(await k.aturSenter(true), isTrue);
      expect(k.senterNyala, isTrue);
      expect(catatan.last, 'flash:torch');

      expect(await k.aturSenter(false), isTrue);
      expect(k.senterNyala, isFalse);
      expect(catatan.last, 'flash:off');
    });

    test('flash OFF awal gagal dipasang: kamera tetap terbuka', () async {
      final catatan = <String>[];
      final k = await bukaTiruan(catatan, flashMatiGagal: true);

      expect(k.senterTersedia, isTrue);
      expect(catatan, ['initialize', 'flash:off']);
      expect(catatan, isNot(contains('dispose')));
    });

    test(
      'tanpa kamera: KameraGagal(tidakAda), tanpa kontroler dibuat',
      () async {
        var dibangun = 0;
        await expectLater(
          KontrolKameraPlugin.buka(
            daftarKamera: () async => const [],
            bangunKontroler: (d, r) {
              dibangun++;

              return _KontrolerPalsu(d, <String>[]);
            },
          ),
          throwsA(
            isA<KameraGagal>().having(
              (e) => e.sebab,
              'sebab',
              SebabKameraGagal.tidakAda,
            ),
          ),
        );
        expect(dibangun, 0);
      },
    );
  });

  group('pemetaan plugin (tanpa kamera)', () {
    Uint8List bita() => Uint8List(64);

    test('YUV420 & NV21: plane Y, langkah 1', () {
      for (final g in [ImageFormatGroup.yuv420, ImageFormatGroup.nv21]) {
        final f = frameLumaDari(
          format: g,
          bita: bita(),
          lebar: 8,
          tinggi: 8,
          barisBita: 8,
        )!;

        expect((f.langkahPiksel, f.awal), (1, 0), reason: '$g');
      }
    });

    test('BGRA: kanal hijau (langkah 4, awal 1)', () {
      final f = frameLumaDari(
        format: ImageFormatGroup.bgra8888,
        bita: bita(),
        lebar: 4,
        tinggi: 4,
        barisBita: 16,
      )!;

      expect((f.langkahPiksel, f.awal, f.barisBita), (4, 1, 16));
    });

    test('format lain (JPEG) tidak dipaksa jadi luma', () {
      expect(
        frameLumaDari(
          format: ImageFormatGroup.jpeg,
          bita: bita(),
          lebar: 8,
          tinggi: 8,
          barisBita: 8,
        ),
        isNull,
      );
    });

    test('kode galat plugin → sebab: izin / tidak ada / lainnya', () {
      for (final kode in [
        'CameraAccessDenied',
        'CameraAccessDeniedWithoutPrompt',
        'CameraAccessRestricted',
        'AudioAccessDenied',
      ]) {
        expect(
          petakanKodeGalatKamera(kode),
          SebabKameraGagal.izinDitolak,
          reason: kode,
        );
      }
      expect(
        petakanKodeGalatKamera('cameraNotFound'),
        SebabKameraGagal.tidakAda,
      );
      expect(
        petakanKodeGalatKamera('CameraException'),
        SebabKameraGagal.gagalMulai,
      );
    });
  });
}
