import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/ocr_angka/pelari_tflite.dart';

/// `PelariTfliteIsolate` memakai isolate SUNGGUHAN, tetapi interpreternya
/// tiruan murni Dart (tidak ada pustaka native di mesin test). Yang diuji
/// adalah protokol pekerja: urutan, galat per sel, batas waktu, penutupan.
///
/// Penanda di sel pertama masukan memilih perilaku tiruan:
/// [_penandaGalat] melempar, [_penandaLambat] tidur 600 ms,
/// [_penandaSangatLambat] tidur 3 detik, [_penandaMati] mematikan isolate
/// pekerja seketika.
///
/// Tes berwaktu memakai jarak lebar (batas 100 ms lawan tidur 3 detik, ambang
/// lulus 2 detik): suite penuh pernah berjalan 5× lebih lambat karena mesin
/// dipakai agen lain, dan tes yang selisihnya 100 ms jadi flake.
const _penandaGalat = -99.0;
const _penandaLambat = -77.0;
const _penandaSangatLambat = -66.0;
const _penandaMati = -55.0;

const _kontrakSah = KontrakTensor(
  bentukMasukan: [1, 48, 320, 3],
  tipeMasukan: 'float32',
  bentukKeluaran: [1, 40, 438],
  tipeKeluaran: 'float32',
);

class _InterpreterTiruan implements InterpreterMentah {
  _InterpreterTiruan(this.thread);

  final int thread;

  @override
  KontrakTensor get kontrak => _kontrakSah;

  @override
  Float32List jalankan(Float32List masukan) {
    if (masukan[0] == _penandaGalat) throw StateError('sel rusak');
    if (masukan[0] == _penandaMati) Isolate.exit();
    if (masukan[0] == _penandaLambat) {
      sleep(const Duration(milliseconds: 600));
    }
    if (masukan[0] == _penandaSangatLambat) {
      sleep(const Duration(seconds: 3));
    }

    final keluar = Float32List(40 * 438);
    keluar[0] = masukan[0];
    keluar[1] = masukan.length.toDouble();
    keluar[2] = thread.toDouble();

    return keluar;
  }

  @override
  void tutup() {}
}

/// Dipanggil DI DALAM isolate pekerja, jadi harus fungsi tingkat-atas.
/// Byte pertama model 1 = pabrik gagal, 2 = kontrak salah, 3 = memuat lambat.
InterpreterMentah _pabrikTiruan(Uint8List model, int thread) {
  if (model.isNotEmpty && model[0] == 1) {
    throw StateError('model rusak');
  }
  if (model.isNotEmpty && model[0] == 3) {
    sleep(const Duration(seconds: 3));
  }
  if (model.isNotEmpty && model[0] == 2) return _InterpreterSalah();

  return _InterpreterTiruan(thread);
}

class _InterpreterSalah extends _InterpreterTiruan {
  _InterpreterSalah() : super(0);

  @override
  KontrakTensor get kontrak => const KontrakTensor(
    bentukMasukan: [1, 3, 48, 320],
    tipeMasukan: 'float32',
    bentukKeluaran: [1, 40, 438],
    tipeKeluaran: 'float32',
  );
}

Float32List _masukan(double penanda) =>
    Float32List(1 * 48 * 320 * 3)..[0] = penanda;

void main() {
  Future<PelariTfliteIsolate> mulai({
    int model = 0,
    int thread = 3,
    Duration batas = const Duration(seconds: 20),
    Duration batasMuat = const Duration(seconds: 20),
    Duration batasTutup = const Duration(seconds: 5),
  }) => PelariTfliteIsolate.mulai(
    Uint8List.fromList([model, 0, 0, 0]),
    pabrik: _pabrikTiruan,
    thread: thread,
    batasWaktu: batas,
    batasMuat: batasMuat,
    batasTutup: batasTutup,
  );

  test('memuat di pekerja, melaporkan kontrak, dan menjalankan sel', () async {
    final p = await mulai(thread: 3);
    addTearDown(p.tutup);

    expect(p.kontrak.bentukMasukan, [1, 48, 320, 3]);
    expect(p.kontrak.tipeMasukan, 'float32');
    expect(p.kontrak.bentukKeluaran, [1, 40, 438]);

    final k = await p.jalankan(_masukan(5));
    expect(k.length, 40 * 438);
    expect(k[0], 5.0);
    expect(k[1], 46080.0, reason: 'masukan sampai utuh ke pekerja');
    expect(k[2], 3.0, reason: 'jumlah thread diteruskan ke pabrik');
  });

  test(
    'panggilan bersamaan dilayani berurutan dan tiap jawaban milik peminta',
    () async {
      final p = await mulai();
      addTearDown(p.tutup);

      final hasil = await Future.wait([
        for (var i = 1; i <= 12; i++) p.jalankan(_masukan(i.toDouble())),
      ]);

      expect([for (final k in hasil) k[0]], [for (var i = 1; i <= 12; i++) i]);
    },
  );

  test(
    'pabrik gagal -> StateError dengan sebabnya, tanpa menggantung',
    () async {
      await expectLater(
        mulai(model: 1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'pesan',
            contains('model rusak'),
          ),
        ),
      );
    },
  );

  test(
    'galat satu sel menjadi galat biasa; pekerja tetap hidup untuk sel berikutnya',
    () async {
      final p = await mulai();
      addTearDown(p.tutup);

      await expectLater(
        p.jalankan(_masukan(_penandaGalat)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'pesan',
            contains('sel rusak'),
          ),
        ),
      );

      final k = await p.jalankan(_masukan(8));
      expect(k[0], 8.0);
    },
  );

  test(
    'melewati batas waktu -> TimeoutException (tidak menggantung)',
    () async {
      final p = await mulai(batas: const Duration(milliseconds: 150));
      addTearDown(p.tutup);

      await expectLater(
        p.jalankan(_masukan(_penandaLambat)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('tutup menyelesaikan sel yang sedang berjalan dulu', () async {
    final p = await mulai();

    final berjalan = p.jalankan(_masukan(_penandaLambat));
    await p.tutup();

    expect((await berjalan)[0], _penandaLambat);
  });

  test('tutup aman diulang; sesudahnya menolak pakai', () async {
    final p = await mulai(batasTutup: const Duration(seconds: 20));

    final jam = Stopwatch()..start();
    await p.tutup();
    await p.tutup();
    expect(
      jam.elapsedMilliseconds,
      lessThan(10000),
      reason: 'pekerja menjawab penutupan, bukan menunggu batas 20 detik',
    );

    await expectLater(p.jalankan(_masukan(1)), throwsStateError);
  });

  test(
    'pekerja MATI: sel yang menunggu gagal, ditandai mati, sel berikutnya gagal SEKETIKA',
    () async {
      // Batas waktu sel sengaja panjang (3 s): tanpa penanda mati, sel kedua
      // mengirim ke port mati dan baru gagal sesudah batas itu.
      final p = await mulai(batas: const Duration(seconds: 10));
      addTearDown(p.tutup);
      expect(p.mati, isFalse);

      await expectLater(p.jalankan(_masukan(_penandaMati)), throwsStateError);
      expect(p.mati, isTrue);

      final jam = Stopwatch()..start();
      await expectLater(
        p.jalankan(_masukan(1)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'pesan',
            contains('sudah mati'),
          ),
        ),
      );
      expect(
        jam.elapsedMilliseconds,
        lessThan(5000),
        reason: 'gagal seketika, bukan menunggu batas waktu 10 detik',
      );
    },
  );

  test('tutup() pada pekerja yang sudah mati tidak menunggu ack', () async {
    final p = await mulai(batasTutup: const Duration(seconds: 12));
    await expectLater(p.jalankan(_masukan(_penandaMati)), throwsStateError);
    expect(p.mati, isTrue);

    final jam = Stopwatch()..start();
    await p.tutup();

    expect(
      jam.elapsedMilliseconds,
      lessThan(6000),
      reason: 'pekerja mati tidak bisa mengakui; jangan menunggu 12 detik',
    );
  });

  test(
    'tutup() menyerah menunggu ack sesudah batasTutup; sel yang menggantung digagalkan',
    () async {
      final p = await mulai(batasTutup: const Duration(milliseconds: 100));

      // Pekerja sibuk 3 detik, jadi ack penutupan datang jauh sesudah 100 ms.
      final berjalan = expectLater(
        p.jalankan(_masukan(_penandaSangatLambat)),
        throwsStateError,
      );
      final jam = Stopwatch()..start();
      await p.tutup();

      expect(
        jam.elapsedMilliseconds,
        lessThan(2000),
        reason: 'berhenti menunggu ack di batasTutup (100 ms), bukan 3 detik',
      );
      await berjalan;
    },
  );

  test(
    'memuat melewati batasMuat -> StateError dan isolate dibuang (tidak menggantung)',
    () async {
      final jam = Stopwatch()..start();

      await expectLater(
        mulai(model: 3, batasMuat: const Duration(milliseconds: 150)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'pesan',
            contains('tidak selesai dimuat'),
          ),
        ),
      );
      expect(
        jam.elapsedMilliseconds,
        lessThan(2000),
        reason: 'berhenti di batasMuat (150 ms), bukan menunggu pabrik 3 detik',
      );
    },
  );

  test(
    'kontrak yang dilaporkan pekerja sampai apa adanya (diperiksa sesi)',
    () async {
      final p = await mulai(model: 2);
      addTearDown(p.tutup);

      expect(p.kontrak.bentukMasukan, [1, 3, 48, 320]);
    },
  );
}
