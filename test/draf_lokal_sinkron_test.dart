import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/pengirim_draf_service.dart';

/// Pengirim antrean draf offline.
///
/// Yang dijaga, sesuai rencana `draf-offline` (14 Okt 2026):
///  - cuma `status: draft` yang pernah dikirim — apa pun isi kirimannya;
///  - kiriman ulang nggak melahirkan sesi kembar (server mendedup
///    `client_request_id`, dan `PUT` penyusul memastikan isinya);
///  - 422 → `perlu_diperbaiki`, nggak diulang; 401 → berhenti;
///  - satu putaran dalam satu waktu.
///
/// Servernya tiruan [_ServerPalsu] yang meniru dua perilaku server asli yang
/// relevan: dedup `client_request_id` (`CalibrationController::replay`) dan
/// `PUT` yang mengganti isi sesi.
void main() {
  const userId = 7;
  const cid = '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71';

  late SimpananDrafLokalMemori simpanan;
  late _ServerPalsu server;
  late int berubah;

  setUp(() {
    simpanan = SimpananDrafLokalMemori();
    server = _ServerPalsu();
    berubah = 0;
  });

  SinkronDrafLokal sinkron({
    String? token = 'tok',
    String? Function()? tokenDari,
    Set<String>? terbuka,
    int akun = userId,
  }) => SinkronDrafLokal(
    simpanan: simpanan,
    pengirim: server,
    userId: akun,
    bacaToken: () async => tokenDari != null ? tokenDari() : token,
    setelahBerubah: () => berubah++,
    terbuka: terbuka,
    dengarSiklusAplikasi: false,
  );

  DrafLokal antre({
    int? sesiId,
    String clientRequestId = cid,
    StatusDrafLokal status = StatusDrafLokal.belumTersinkron,
    Map<String, dynamic>? kiriman,
  }) => DrafLokal(
    userId: userId,
    sesiId: sesiId,
    clientRequestId: clientRequestId,
    profil: 'ph_meter',
    disimpanPada: DateTime.utc(2026, 10, 14, 6, 41),
    status: status,
    dicobaKirim: sesiId == null,
    kiriman:
        kiriman ??
        {
          'client_request_id': clientRequestId,
          'equipment_id': 12,
          'status': 'draft',
          'catatan_teknisi': 'isian terakhir',
        },
    isian: const {},
  );

  test('draf baru: POST dengan client_request_id tersimpan, lalu PUT ke id '
      'yang dipulangkan; salinan HP dibuang', () async {
    await simpanan.simpan(antre());
    final s = sinkron();

    final hasil = await s.jalankan();

    expect(hasil.terkirim, 1);
    expect(server.log.map((p) => p.metode), ['POST', 'PUT']);
    expect(server.log.first.body['client_request_id'], cid);
    expect(server.log.last.id, server.sesi.keys.single);
    expect(await simpanan.daftar(userId), isEmpty);
    expect(berubah, 1, reason: 'Daftar draf nggak disegarkan.');
    s.dispose();
  });

  test('kiriman ulang nggak melahirkan sesi kembar walau POST pertama sudah '
      'sampai server', () async {
    // Percobaan pertama: servernya MENYIMPAN, tapi jawabannya hilang di jalan
    // (timeout). Dari sisi HP itu kegagalan jaringan biasa.
    server.putusSesudahSimpanSekali = true;
    await simpanan.simpan(antre());
    final s = sinkron();

    final pertama = await s.jalankan();
    expect(pertama.gagalJaringan, isTrue);
    expect(server.sesi, hasLength(1), reason: 'Server sudah menyimpan.');

    // Teknisi sempat mengubah isiannya sebelum sinyal balik.
    await simpanan.simpan(
      antre(
        kiriman: {
          'client_request_id': cid,
          'equipment_id': 12,
          'status': 'draft',
          'catatan_teknisi': 'diubah sesudah timeout',
        },
      ),
    );

    final kedua = await s.jalankan();

    expect(kedua.terkirim, 1);
    expect(server.sesi, hasLength(1), reason: 'Sesi kembar lahir.');
    expect(
      server.sesi.values.single['catatan_teknisi'],
      'diubah sesudah timeout',
      reason: 'Replay POST membuang isi baru diam-diam.',
    );
    expect(await simpanan.daftar(userId), isEmpty);
    s.dispose();
  });

  test('POST berhasil tapi PUT penyusulnya putus: salinan pindah ke sesi-<id> '
      'dan percobaan berikutnya cuma PUT', () async {
    server.putusPadaPutKe = 1;
    await simpanan.simpan(antre());
    final s = sinkron();

    await s.jalankan();

    final sisa = await simpanan.daftar(userId);
    expect(sisa.single.kunci, 'sesi-${server.sesi.keys.single}');

    server.log.clear();
    await s.jalankan();

    expect(server.log.map((p) => p.metode), ['PUT']);
    expect(server.sesi, hasLength(1));
    expect(await simpanan.daftar(userId), isEmpty);
    s.dispose();
  });

  test('sesi yang sudah ada: PUT ke id-nya, nggak pernah POST', () async {
    server.sesi[72] = {'status': 'draft'};
    await simpanan.simpan(antre(sesiId: 72));
    final s = sinkron();

    await s.jalankan();

    expect(server.log.map((p) => (p.metode, p.id)), [('PUT', 72)]);
    s.dispose();
  });

  test(
    'antrean NGGAK PERNAH mengirim ke admin, apa pun isi kirimannya',
    () async {
      await simpanan.simpan(
        antre(
          kiriman: {
            'client_request_id': cid,
            'equipment_id': 12,
            'status': 'menunggu_approval',
          },
        ),
      );
      final s = sinkron();

      await s.jalankan();

      expect(server.log, isNotEmpty);
      for (final p in server.log) {
        expect(p.body['status'], 'draft', reason: '${p.metode} ke admin.');
      }
      s.dispose();
    },
  );

  test('422: ditandai perlu_diperbaiki dengan pesan server, dan nggak '
      'dicoba ulang', () async {
    server.tolak422 = true;
    await simpanan.simpan(antre());
    final s = sinkron();

    final hasil = await s.jalankan();

    expect(hasil.ditolak, 1);
    final d = (await simpanan.daftar(userId)).single;
    expect(d.status, StatusDrafLokal.perluDiperbaiki);
    expect(d.pesan, 'The equipment id field is required.');

    server.log.clear();
    await s.jalankan();
    expect(server.log, isEmpty, reason: 'Kiriman yang ditolak diulang.');
    expect(s.adaJadwal, isFalse);
    s.dispose();
  });

  test('401: berhenti sampai login berikutnya', () async {
    server.tolak401 = true;
    await simpanan.simpan(antre());
    final s = sinkron();

    await s.jalankan();
    expect(s.dijeda, isTrue);

    server
      ..tolak401 = false
      ..log.clear();
    await s.jalankan();
    expect(server.log, isEmpty);
    expect(
      (await simpanan.daftar(userId)).single.status,
      StatusDrafLokal.belumTersinkron,
      reason: 'Draf hilang dari antrean gara-gara token kedaluwarsa.',
    );
    s.dispose();
  });

  test('401 berlaku buat token itu saja: token lain (login ulang / resume) '
      'membuka jedanya', () async {
    server.tolak401 = true;
    await simpanan.simpan(antre());
    var token = 'tok-lama';
    final s = sinkron(tokenDari: () => token);

    await s.jalankan();
    expect(s.dijeda, isTrue);

    server
      ..tolak401 = false
      ..log.clear();
    token = 'tok-baru';
    final hasil = await s.jalankan();

    expect(s.dijeda, isFalse);
    expect(hasil.terkirim, 1);
    expect(server.log, isNotEmpty);
    s.dispose();
  });

  // Saran B review draf-offline ronde 2 (15 Okt 2026): token baru yang tiba
  // TANPA provider dibangun ulang harus membuka jeda 401 lewat jadwal biasa —
  // bukan menunggu aplikasi di-resume atau dialog logout memanggil jalankan.
  group('jadwalkan sesudah 401', () {
    test('token berganti tanpa provider dibangun ulang: jadwalkan mengirim '
        'lagi', () async {
      server.tolak401 = true;
      await simpanan.simpan(antre());
      var token = 'tok-lama';
      final s = sinkron(tokenDari: () => token);

      await s.jalankan();
      expect(s.dijeda, isTrue);

      server
        ..tolak401 = false
        ..log.clear();
      token = 'tok-baru';
      s.jadwalkan(jeda: Duration.zero);

      expect(s.adaJadwal, isTrue, reason: 'Jeda 401 menelan jadwalnya.');
      await _tungguSampai(() async => (await simpanan.daftar(userId)).isEmpty);

      expect(server.log.map((p) => p.metode), ['POST', 'PUT']);
      for (final p in server.log) {
        expect(p.body['status'], 'draft');
      }
      expect(s.dijeda, isFalse);
      s.dispose();
    });

    test('token masih yang ditolak: jadwalnya jalan tapi nggak mengirim dan '
        'nggak berputar', () async {
      server.tolak401 = true;
      await simpanan.simpan(antre());
      final s = sinkron(token: 'tok-lama');

      await s.jalankan();
      server.log.clear();

      s.jadwalkan(jeda: Duration.zero);
      await _tungguSampai(() async => !s.adaJadwal);
      // Putaran yang dipicu timer (atau putaran kosong kalau sudah selesai).
      await s.jalankan();

      expect(server.log, isEmpty);
      expect(s.dijeda, isTrue);
      expect(s.adaJadwal, isFalse, reason: 'Timer berputar terus selama 401.');
      expect(
        (await simpanan.daftar(userId)).single.status,
        StatusDrafLokal.belumTersinkron,
      );
      s.dispose();
    });
  });

  // Keputusan review 14 Okt 2026 (K-30-09): draf antre akun lain tetap di HP,
  // tapi NGGAK dikirim pakai token akun yang sedang login.
  test('draf antre akun lain nggak dikirim atas nama akun yang login; '
      'terkirim waktu pemiliknya login lagi', () async {
    await simpanan.simpan(antre());

    final akunLain = sinkron(akun: 9, token: 'tok-akun-9');
    await akunLain.mulai();
    akunLain.dispose();

    expect(server.log, isEmpty, reason: 'Draf akun 7 dikirim pakai token 9.');
    expect(await simpanan.daftar(userId), hasLength(1));

    final pemilik = sinkron(token: 'tok-akun-7');
    await pemilik.mulai();

    expect(server.log.map((p) => p.metode), ['POST', 'PUT']);
    expect(await simpanan.daftar(userId), isEmpty);
    pemilik.dispose();
  });

  group('balapan dengan layar yang menulis ulang salinannya', () {
    test('salinan ditulis ulang SELAMA dikirim: yang baru tetap antre dan '
        'dijadwalkan, bukan dibuang', () async {
      await simpanan.simpan(antre(sesiId: 72));
      server.sesi[72] = {'status': 'draft'};
      server.selamaPut = () => simpanan.simpan(
        antre(sesiId: 72).copyWith(
          disimpanPada: DateTime.utc(2026, 10, 14, 6, 42),
          kiriman: {
            'equipment_id': 12,
            'status': 'draft',
            'catatan_teknisi': 'diketik sambil dikirim',
          },
        ),
      );
      final s = sinkron();

      await s.jalankan();

      final sisa = (await simpanan.daftar(userId)).single;
      expect(sisa.kiriman!['catatan_teknisi'], 'diketik sambil dikirim');
      expect(sisa.status, StatusDrafLokal.belumTersinkron);
      expect(s.adaJadwal, isTrue);

      // Putaran berikutnya mengirim versi terbarunya, lalu baru dibuang.
      server.selamaPut = null;
      await s.jalankan();
      expect(server.sesi[72]!['catatan_teknisi'], 'diketik sambil dikirim');
      expect(await simpanan.daftar(userId), isEmpty);
      s.dispose();
    });

    test(
      'lembarnya DIBUKA di layar selama dikirim: salinannya nggak dibuang',
      () async {
        await simpanan.simpan(antre(sesiId: 72));
        server.sesi[72] = {'status': 'draft'};
        final terbuka = <String>{};
        server.selamaPut = () async => terbuka.add('sesi-72');
        final s = sinkron(terbuka: terbuka);

        await s.jalankan();

        expect(await simpanan.daftar(userId), hasLength(1));
        expect(s.adaJadwal, isTrue);
        s.dispose();
      },
    );

    test('ditolak 422 tapi salinannya sudah berubah: isi baru nggak ditandai '
        'perlu diperbaiki', () async {
      server.tolak422 = true;
      await simpanan.simpan(antre(sesiId: 72));
      server.sebelumPeriksa = () => simpanan.simpan(
        antre(
          sesiId: 72,
        ).copyWith(disimpanPada: DateTime.utc(2026, 10, 14, 6, 42)),
      );
      final s = sinkron();

      await s.jalankan();

      expect(
        (await simpanan.daftar(userId)).single.status,
        StatusDrafLokal.belumTersinkron,
      );
      s.dispose();
    });
  });

  // Saran A review draf-offline ronde 2 (15 Okt 2026): dulu pengirim antrean
  // MEMERIKSA salinannya (`baca`) lalu MENULIS (`hapus` / `simpan`) dalam dua
  // langkah, dan simpan otomatis layar bisa mendarat di antaranya.
  //
  // [_SimpananBerCelah] menyelipkan tulisan layar PERSIS sesudah akses
  // simpanan berikutnya dari pengirim antrean selesai. Dengan periksa & tulis
  // terpisah, itu celahnya; dengan `gantiJikaSama` yang satu operasi, tulisan
  // itu cuma bisa mendarat sesudahnya — dan harus selamat.
  group('tulisan layar yang mendarat di antara periksa dan tulis', () {
    late _SimpananBerCelah berCelah;

    setUp(() => berCelah = _SimpananBerCelah(simpanan));

    SinkronDrafLokal sinkronBerCelah() => SinkronDrafLokal(
      simpanan: berCelah,
      pengirim: server,
      userId: userId,
      bacaToken: () async => 'tok',
      setelahBerubah: () => berubah++,
      dengarSiklusAplikasi: false,
    );

    DrafLokal ketikanBaru({int? sesiId}) => antre(sesiId: sesiId).copyWith(
      disimpanPada: DateTime.utc(2026, 10, 14, 6, 42),
      kiriman: {
        'client_request_id': cid,
        'equipment_id': 12,
        'status': 'draft',
        'catatan_teknisi': 'diketik di celah',
      },
    );

    test('terkirim: salinan nggak ikut dibuang, tetap antre', () async {
      await simpanan.simpan(antre(sesiId: 72));
      server.sesi[72] = {'status': 'draft'};
      server.selamaPut = () async =>
          berCelah.selipkan = () => simpanan.simpan(ketikanBaru(sesiId: 72));
      final s = sinkronBerCelah();

      await s.jalankan();

      final sisa = (await simpanan.daftar(userId)).single;
      expect(sisa.kiriman!['catatan_teknisi'], 'diketik di celah');
      expect(sisa.status, StatusDrafLokal.belumTersinkron);
      expect(s.adaJadwal, isTrue);

      server.selamaPut = null;
      await s.jalankan();
      expect(server.sesi[72]!['catatan_teknisi'], 'diketik di celah');
      expect(await simpanan.daftar(userId), isEmpty);
      s.dispose();
    });

    test('ditolak 422: ketikan baru nggak ditimpa isi lama bertanda '
        'perlu_diperbaiki', () async {
      server.tolak422 = true;
      await simpanan.simpan(antre(sesiId: 72));
      server.sebelumPeriksa = () async =>
          berCelah.selipkan = () => simpanan.simpan(ketikanBaru(sesiId: 72));
      final s = sinkronBerCelah();

      await s.jalankan();

      // Versi yang DIKIRIM memang ditolak; ketikan sesudahnya belum, jadi
      // dia yang tersisa — tetap antre, isinya utuh.
      final sisa = (await simpanan.daftar(userId)).single;
      expect(sisa.kiriman!['catatan_teknisi'], 'diketik di celah');
      expect(sisa.status, StatusDrafLokal.belumTersinkron);
      s.dispose();
    });

    test('POST masuk tapi PUT putus: pindah ke sesi-<id> nggak membuang '
        'ketikan baru di baru-<cid>, dan tetap satu sesi', () async {
      server.putusPadaPutKe = 1;
      await simpanan.simpan(antre());
      server.sebelumPeriksa = () async {
        server.sebelumPeriksa = null;
        berCelah.selipkan = () => simpanan.simpan(ketikanBaru());
      };
      final s = sinkronBerCelah();

      await s.jalankan();

      final baru = await simpanan.baca(userId, 'baru-$cid');
      expect(baru?.kiriman?['catatan_teknisi'], 'diketik di celah');

      await s.jalankan();
      expect(server.sesi, hasLength(1), reason: 'Sesi kembar lahir.');
      expect(server.sesi.values.single['catatan_teknisi'], 'diketik di celah');
      expect(await simpanan.daftar(userId), isEmpty);
      s.dispose();
    });
  });

  test('gagal jaringan: tetap antre dan dijadwalkan ulang', () async {
    server.offline = true;
    await simpanan.simpan(antre());
    final s = sinkron();

    final hasil = await s.jalankan();

    expect(hasil.gagalJaringan, isTrue);
    expect(
      (await simpanan.daftar(userId)).single.status,
      StatusDrafLokal.belumTersinkron,
    );
    expect(s.adaJadwal, isTrue);
    s.dispose();
    expect(s.adaJadwal, isFalse);
  });

  test(
    'simpanan otomatis (belum pernah Simpan Draf) nggak ikut dikirim',
    () async {
      await simpanan.simpan(antre(status: StatusDrafLokal.lokal));
      final s = sinkron();

      await s.jalankan();

      expect(server.log, isEmpty);
      s.dispose();
    },
  );

  test('lembar yang lagi dibuka di layar dilewat', () async {
    await simpanan.simpan(antre());
    final s = sinkron(terbuka: {'baru-$cid'});

    await s.jalankan();

    expect(server.log, isEmpty);
    s.dispose();
  });

  test('cuma satu putaran dalam satu waktu', () async {
    await simpanan.simpan(antre());
    final s = sinkron();

    final a = s.jalankan();
    final b = s.jalankan();
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);

    expect(server.log.where((p) => p.metode == 'POST'), hasLength(1));
    s.dispose();
  });
}

Future<void> _tungguSampai(Future<bool> Function() syarat) async {
  final batas = DateTime.now().add(const Duration(seconds: 5));
  while (!await syarat()) {
    if (DateTime.now().isAfter(batas)) fail('Waktu habis menunggu.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Simpanan yang menyelipkan satu tulisan ([selipkan]) PERSIS sesudah akses
/// berikutnya (selain [daftar]) selesai — meniru simpan otomatis layar yang
/// mendarat di tengah langkah pengirim antrean.
class _SimpananBerCelah implements SimpananDrafLokal {
  _SimpananBerCelah(this.dalam);

  final SimpananDrafLokal dalam;
  Future<void> Function()? selipkan;

  Future<T> _lalu<T>(Future<T> Function() kerja) async {
    final hasil = await kerja();
    final tulisan = selipkan;
    selipkan = null;
    await tulisan?.call();
    return hasil;
  }

  @override
  Future<DrafLokal?> baca(int userId, String kunci) =>
      _lalu(() => dalam.baca(userId, kunci));

  @override
  Future<List<DrafLokal>> daftar(int userId) => dalam.daftar(userId);

  @override
  Future<void> simpan(DrafLokal draf) => _lalu(() => dalam.simpan(draf));

  @override
  Future<void> hapus(int userId, String kunci) =>
      _lalu(() => dalam.hapus(userId, kunci));

  @override
  Future<bool> gantiJikaSama(
    int userId,
    String kunci,
    DateTime disimpanPada, {
    DrafLokal? pengganti,
  }) => _lalu(
    () =>
        dalam.gantiJikaSama(userId, kunci, disimpanPada, pengganti: pengganti),
  );

  @override
  Future<void> buangKedaluwarsa(int userId, {DateTime? sekarang}) =>
      dalam.buangKedaluwarsa(userId, sekarang: sekarang);

  @override
  Future<void> buangAkunLain(int userId, {DateTime? sekarang}) =>
      dalam.buangAkunLain(userId, sekarang: sekarang);
}

/// Server tiruan: dedup `client_request_id` dan `PUT` yang mengganti isi.
class _ServerPalsu implements PengirimDrafService {
  final Map<int, Map<String, dynamic>> sesi = {};
  final Map<String, int> _perCid = {};
  final List<({String metode, int? id, Map<String, dynamic> body})> log = [];
  int _idBerikutnya = 500;
  int _put = 0;

  bool offline = false;
  bool tolak422 = false;
  bool tolak401 = false;
  bool putusSesudahSimpanSekali = false;
  int? putusPadaPutKe;

  /// Dijalankan di tengah `PUT` yang berhasil — meniru layar yang menulis
  /// salinannya selagi pengirim antrean jalan.
  Future<void> Function()? selamaPut;

  /// Dijalankan sebelum penolakan dilempar.
  Future<void> Function()? sebelumPeriksa;

  void _periksa() {
    if (offline) {
      throw const KoneksiException(
        'Nggak bisa nyambung ke server. Cek koneksi kamu.',
      );
    }
    if (tolak401) {
      throw const ApiException('Unauthenticated.', status: 401);
    }
    if (tolak422) {
      throw const ApiException(
        'The equipment id field is required.',
        status: 422,
      );
    }
  }

  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async {
    log.add((metode: 'POST', id: null, body: body));
    _periksa();

    final cid = body['client_request_id'] as String;
    final lama = _perCid[cid];
    // Replay: sesi lama dipulangkan APA ADANYA — isi baru nggak dibaca.
    if (lama != null) {
      return (id: lama, status: sesi[lama]!['status'] as String?);
    }

    final id = _idBerikutnya++;
    _perCid[cid] = id;
    sesi[id] = {...body};

    if (putusSesudahSimpanSekali) {
      putusSesudahSimpanSekali = false;
      throw const KoneksiException('Server nggak nyaut. Coba lagi sebentar.');
    }

    return (id: id, status: body['status'] as String?);
  }

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    log.add((metode: 'PUT', id: id, body: body));
    await sebelumPeriksa?.call();
    _periksa();

    _put++;
    if (putusPadaPutKe == _put) {
      throw const KoneksiException('Server nggak nyaut. Coba lagi sebentar.');
    }

    sesi[id] = {...body};
    await selamaPut?.call();
    return id;
  }
}
