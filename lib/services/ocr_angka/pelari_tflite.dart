import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

/// Bentuk dan tipe tensor yang DILAPORKAN model sesudah dimuat. Diperiksa
/// `SesiInferensiTflite` sebelum sel pertama dijalankan.
class KontrakTensor {
  const KontrakTensor({
    required this.bentukMasukan,
    required this.tipeMasukan,
    required this.bentukKeluaran,
    required this.tipeKeluaran,
  });

  final List<int> bentukMasukan;

  /// Nama tipe tensor, huruf kecil (`float32`).
  final String tipeMasukan;
  final List<int> bentukKeluaran;
  final String tipeKeluaran;
}

/// Interpreter satu model, MENTAH: masukan dan keluaran datar `float32`. Jalan
/// di dalam isolate pekerja ([PelariTfliteIsolate]); satu-satunya implementasi
/// nyata ada di `interpreter_mentah_tflite.dart`, test memakai tiruan.
abstract interface class InterpreterMentah {
  KontrakTensor get kontrak;

  /// Salin [masukan] ke tensor masukan, jalankan, lalu SALIN tensor keluaran
  /// ke `Float32List` baru (memori tensor dipakai ulang di panggilan berikut).
  Float32List jalankan(Float32List masukan);

  void tutup();
}

/// Membuat [InterpreterMentah] dari byte model dan jumlah thread CPU. Dipanggil
/// DI DALAM isolate pekerja, jadi harus fungsi tingkat-atas atau `static`
/// (dikirim lewat port).
typedef PabrikInterpreterMentah =
    InterpreterMentah Function(Uint8List model, int thread);

/// Menjalankan model satu per satu di luar isolate UI.
abstract interface class PelariTflite {
  KontrakTensor get kontrak;

  /// Pekerja sudah berhenti tanpa diminta (isolate mati). Pelari yang mati tidak
  /// akan pernah menjawab lagi: `jalankan` langsung gagal dan `tutup` tidak
  /// menunggu. Pemilik yang ingin tetap berjalan harus memuat pelari baru.
  bool get mati;

  /// Jalankan model pada [masukan] (datar, urutan tensor masukan). Panggilan
  /// bersamaan dilayani berurutan.
  Future<Float32List> jalankan(Float32List masukan);

  /// Lepaskan interpreter dan matikan pekerja. Aman dipanggil berulang.
  Future<void> tutup();
}

/// Pesan penutup pekerja memakai id ini; permintaan jalan mulai dari 1.
const _idTutup = 0;

/// [PelariTflite] di atas SATU isolate pekerja yang hidup selama sesi: model
/// dimuat di pekerja (pengurai flatbuffer + alokasi tensor tidak membekukan UI)
/// dan tiap sel dijalankan di sana.
///
/// ## Kenapa bukan `IsolateInterpreter` bawaan paket
///
/// `IsolateInterpreter` (tflite_flutter 0.12.1) punya dua perilaku yang tidak
/// boleh ada di jalur yang hasilnya jadi usulan angka sertifikat:
///
///  - `runForMultipleInputs` DIAM-DIAM kembali bila sedang sibuk
///    (`if (state == loading) return;`), lalu tetap membaca tensor keluaran —
///    panggilan bersamaan mengembalikan keluaran lama/nol tanpa galat;
///  - pekerjanya tanpa `try/catch`: galat satu sel mematikan isolate dan
///    `_wait()` menunggu `idle` selamanya (aplikasi menggantung, bukan jatuh
///    ke ML Kit).
///
/// Di sini tiap permintaan punya id + [Completer], galat pekerja dikirim balik
/// sebagai galat biasa, kematian pekerja menggagalkan semua yang menunggu, dan
/// tiap permintaan dibatasi waktu. Pekerja yang mati ditandai ([mati]); sejak itu
/// `jalankan` gagal seketika, bukan menunggu batas waktu tiap sel.
class PelariTfliteIsolate implements PelariTflite {
  PelariTfliteIsolate._(this._batasWaktu, this._batasMuat, this._batasTutup);

  final Duration _batasWaktu;
  final Duration _batasMuat;
  final Duration _batasTutup;
  final _terima = ReceivePort();
  final _berhenti = ReceivePort();
  final _awal = Completer<List<Object?>>();
  final _menunggu = <int, Completer<Float32List>>{};

  Isolate? _isolate;
  SendPort? _kirim;
  Completer<void>? _ackTutup;
  int _idBerikut = 1;
  bool _tertutup = false;
  bool _mati = false;

  @override
  bool get mati => _mati;

  @override
  late final KontrakTensor kontrak;

  /// Muat model di isolate pekerja. Melempar [StateError] bila model/runtime
  /// gagal dimuat (pustaka native tidak ada, model rusak, memori) atau tidak
  /// selesai dalam [batasMuat] (isolate pekerja dibuang). [batasWaktu] membatasi
  /// tiap sel; [batasTutup] membatasi penantian ack penutupan.
  static Future<PelariTfliteIsolate> mulai(
    Uint8List model, {
    required PabrikInterpreterMentah pabrik,
    int thread = 2,
    Duration batasWaktu = const Duration(seconds: 60),
    Duration batasMuat = const Duration(seconds: 60),
    Duration batasTutup = const Duration(seconds: 5),
  }) async {
    final p = PelariTfliteIsolate._(batasWaktu, batasMuat, batasTutup);
    try {
      await p._spawn(model, thread, pabrik);
    } catch (_) {
      p._buang();
      rethrow;
    }

    return p;
  }

  Future<void> _spawn(
    Uint8List model,
    int thread,
    PabrikInterpreterMentah pabrik,
  ) async {
    _terima.listen(_saatPesan);
    _berhenti.listen((_) => _saatPekerjaBerhenti());

    _isolate = await Isolate.spawn(
      _titikMasukPekerja,
      <Object?>[_terima.sendPort, model, thread, pabrik],
      onExit: _berhenti.sendPort,
      debugName: 'ocr-angka-tflite',
    );

    final awal = await _awal.future.timeout(
      _batasMuat,
      onTimeout: () => throw StateError(
        'model TFLite tidak selesai dimuat dalam ${_batasMuat.inMilliseconds} ms',
      ),
    );
    if (awal.first is! SendPort) {
      throw StateError('model TFLite gagal dimuat: ${awal.last}');
    }

    _kirim = awal[0] as SendPort;
    kontrak = KontrakTensor(
      bentukMasukan: (awal[1] as List).cast<int>(),
      tipeMasukan: awal[2] as String,
      bentukKeluaran: (awal[3] as List).cast<int>(),
      tipeKeluaran: awal[4] as String,
    );
  }

  void _saatPesan(Object? pesan) {
    final p = pesan as List<Object?>;
    if (!_awal.isCompleted) {
      _awal.complete(p);
      return;
    }

    final id = p[0];
    // Pesan awal ('galat', ...) yang tiba sesudah pekerja dianggap berhenti.
    if (id is! int) return;
    if (id == _idTutup) {
      final ack = _ackTutup;
      if (ack != null && !ack.isCompleted) ack.complete();
      return;
    }

    final tunggu = _menunggu.remove(id);
    final isi = p[1];
    if (tunggu == null) return;
    if (isi is Float32List) {
      tunggu.complete(isi);
    } else {
      tunggu.completeError(StateError('$isi'));
    }
  }

  void _saatPekerjaBerhenti() {
    _mati = true;
    final galat = StateError('pekerja TFLite berhenti');
    if (!_awal.isCompleted) _awal.completeError(galat);
    final semua = _menunggu.values.toList();
    _menunggu.clear();
    for (final t in semua) {
      t.completeError(galat);
    }
    final ack = _ackTutup;
    if (ack != null && !ack.isCompleted) ack.complete();
  }

  @override
  Future<Float32List> jalankan(Float32List masukan) {
    final kirim = _kirim;
    if (_mati) {
      // Pekerja sudah tiada: kirim ke port mati tidak pernah dijawab dan tiap
      // sel akan menunggu batas waktu penuh.
      return Future.error(StateError('pekerja TFLite sudah mati'));
    }
    if (_tertutup || kirim == null) {
      return Future.error(StateError('pelari TFLite sudah ditutup'));
    }

    final id = _idBerikut++;
    final tunggu = Completer<Float32List>();
    _menunggu[id] = tunggu;
    kirim.send(<Object?>[id, masukan]);

    return tunggu.future.timeout(
      _batasWaktu,
      onTimeout: () {
        _menunggu.remove(id);
        throw TimeoutException('inferensi TFLite melewati batas waktu');
      },
    );
  }

  @override
  Future<void> tutup() async {
    if (_tertutup) return;
    _tertutup = true;

    final ack = _ackTutup = Completer<void>();
    // Lewat port yang sama dengan permintaan: pekerja menyelesaikan sel yang
    // sedang berjalan dulu, baru menutup. Pekerja yang sudah mati tidak bisa
    // mengakui apa pun, jadi tidak ditunggu.
    if (!_mati && _kirim != null) {
      _kirim!.send(<Object?>[_idTutup, null]);
      await ack.future.timeout(_batasTutup, onTimeout: () {});
    }

    _buang();
  }

  void _buang() {
    _tertutup = true;
    // Peminta yang masih menunggu tidak akan pernah dijawab setelah ini.
    final semua = _menunggu.values.toList();
    _menunggu.clear();
    for (final t in semua) {
      t.completeError(StateError('pelari TFLite ditutup'));
    }
    _isolate?.kill(priority: Isolate.immediate);
    _terima.close();
    _berhenti.close();
  }
}

/// Titik masuk isolate pekerja. [arg]: port balasan, byte model, thread, pabrik.
void _titikMasukPekerja(List<Object?> arg) {
  final balas = arg[0] as SendPort;
  final model = arg[1] as Uint8List;
  final thread = arg[2] as int;
  final pabrik = arg[3] as PabrikInterpreterMentah;

  final InterpreterMentah it;
  final KontrakTensor kontrak;
  try {
    it = pabrik(model, thread);
    kontrak = it.kontrak;
  } catch (e) {
    balas.send(<Object?>['galat', '$e']);
    return;
  }

  final masuk = ReceivePort();
  balas.send(<Object?>[
    masuk.sendPort,
    kontrak.bentukMasukan,
    kontrak.tipeMasukan,
    kontrak.bentukKeluaran,
    kontrak.tipeKeluaran,
  ]);

  masuk.listen((pesan) {
    final p = pesan as List<Object?>;
    final id = p[0] as int;

    if (id == _idTutup) {
      try {
        it.tutup();
      } catch (_) {}
      masuk.close();
      balas.send(<Object?>[_idTutup, null]);
      return;
    }

    try {
      balas.send(<Object?>[id, it.jalankan(p[1] as Float32List)]);
    } catch (e) {
      balas.send(<Object?>[id, 'galat: $e']);
    }
  });
}
