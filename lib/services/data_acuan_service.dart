import 'dart:convert';

import '../core/utils/parse_list.dart';
import '../models/alur_acuan.dart';
import '../models/data_acuan.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'data_acuan_contoh_micrometer.dart';

/// Studio Data Acuan (CR-48) — baca (P1, kontrak API §15) + alur versi
/// lapis 1 (T2.2/T2.3, §54 repo API): ajukan, simulasi, tolak, aktifkan.
///
/// Rute TULIS alur ada di grup `aplikasi:internal` server: token Sidik Studio
/// (satu akun) DITOLAK `403 bukan_aplikasi_ini` — pengaktif harus orang kedua,
/// dan satu akun Studio tidak bisa menjadi orang kedua. Jadi method tulis di
/// bawah hanya berguna dari aplikasi lab; Studio memakai yang baca saja.
///
/// Siapa melihat apa ditegakkan SERVER: teknisi cuma versi `aktif`; versi
/// lain, banding, dan riwayat sel dijawab `404` (bukan 403 — 403 mengakui
/// drafnya ada). `ApiException`-nya dibiarkan lewat apa adanya.
abstract class DataAcuanService {
  /// `GET /data-acuan/paket` — paket lab ini + profil ber-skema yang belum
  /// diimpor (`diimpor: false`).
  Future<List<PaketAcuan>> daftarPaket(String token);

  /// `GET /data-acuan/paket/{kode}` — + `skema`. Paket yang belum diimpor
  /// atau milik lab lain → 404.
  Future<PaketAcuan> paket(String token, String kode);

  /// `GET /data-acuan/paket/{kode}/berlaku?tanggal=&jenis=` (FR-04).
  ///
  /// `versi == null` + `alasan` itu jawaban SAH ("tanggal itu sebelum versi
  /// pertama"), bukan galat. [jenis] `data` (bawaan) atau `bentuk`.
  Future<HasilBerlakuAcuan> berlaku(
    String token,
    String kode,
    DateTime tanggal, {
    String jenis = 'data',
  });

  /// `GET /data-acuan/paket/{kode}/versi` — garis waktu, tanpa `isi`, urut
  /// jenis lalu nomor (FR-28).
  Future<List<VersiAcuan>> garisWaktu(String token, String kode);

  /// `GET /data-acuan/versi/{id}` — metadata + `isi` terurai.
  Future<VersiAcuan> versi(String token, int versiId);

  /// `GET /data-acuan/versi/{lama}/banding/{baru}` (FR-11).
  Future<BandingAcuan> banding(String token, int lamaId, int baruId);

  /// `GET /data-acuan/versi/{versi}/sel/{lembar}/{kunci}/{kolom}/riwayat`
  /// (FR-03, FR-28).
  Future<RiwayatSelAcuan> riwayatSel(
    String token, {
    required int versiId,
    required String lembar,
    required String kunci,
    required String kolom,
  });

  /// `GET /data-acuan/paket/{kode}/alur` — versi data + status + ringkasan
  /// simulasi + `wajib_diakui` + log. Teknisi → 404.
  Future<List<VersiAlurAcuan>> alur(String token, String kode);

  /// `GET /data-acuan/versi/{versi}/simulasi` — laporan simulasi terakhir.
  Future<LaporanSimulasiAcuan> laporanSimulasi(String token, int versiId);

  /// `POST /data-acuan/versi/{versi}/ajukan` `{alasan, rujukan[]}` (admin,
  /// super admin). Draf → diajukan, sha256 dikunci.
  Future<void> ajukan(
    String token,
    int versiId, {
    required String alasan,
    List<RujukanAjuanAcuan> rujukan = const [],
  });

  /// `POST /data-acuan/versi/{versi}/simulasi` (201) — semua sesi profil,
  /// tanpa menulis data lab.
  Future<void> jalankanSimulasi(String token, int versiId);

  /// `POST /data-acuan/versi/{versi}/tolak` `{alasan}` — draf → dibuang,
  /// diajukan → ditolak (super admin).
  Future<void> tolak(String token, int versiId, {required String alasan});

  /// `POST /data-acuan/versi/{versi}/aktifkan` (super admin saja, orang
  /// kedua). [pengakuan] = butir → alasan (≥ 10 karakter).
  Future<void> aktifkan(
    String token,
    int versiId, {
    required DateTime berlakuMulai,
    required String password,
    String? catatan,
    Map<String, String> pengakuan = const {},
  });
}

/// Tanggal sebagai `YYYY-MM-DD` dari komponen kalender lokalnya — bukan lewat
/// `toIso8601String()` (yang ikut zona/UTC pemanggil).
String tanggalIsoAcuan(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

class ApiDataAcuanService implements DataAcuanService {
  ApiDataAcuanService(this._api);

  final ApiClient _api;

  static String _seg(String s) => Uri.encodeComponent(s);

  static Map<String, dynamic> _data(Map<String, dynamic> json) =>
      (json['data'] ?? json) as Map<String, dynamic>;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) async {
    final json = await _api.get('/data-acuan/paket', token: token);

    return parseListAman(json['data'], PaketAcuan.fromJson);
  }

  @override
  Future<PaketAcuan> paket(String token, String kode) async {
    final json = await _api.get(
      '/data-acuan/paket/${_seg(kode)}',
      token: token,
    );

    return PaketAcuan.fromJson(_data(json));
  }

  @override
  Future<HasilBerlakuAcuan> berlaku(
    String token,
    String kode,
    DateTime tanggal, {
    String jenis = 'data',
  }) async {
    final json = await _api.get(
      '/data-acuan/paket/${_seg(kode)}/berlaku'
      '?tanggal=${tanggalIsoAcuan(tanggal)}&jenis=${_seg(jenis)}',
      token: token,
    );

    // Bukan `_data`: `data: null` itu jawaban, dan `alasan` hidup di samping
    // `data`, bukan di dalamnya.
    return HasilBerlakuAcuan.fromJson(json);
  }

  @override
  Future<List<VersiAcuan>> garisWaktu(String token, String kode) async {
    final json = await _api.get(
      '/data-acuan/paket/${_seg(kode)}/versi',
      token: token,
    );

    return parseListAman(json['data'], VersiAcuan.fromJson);
  }

  @override
  Future<VersiAcuan> versi(String token, int versiId) async {
    final json = await _api.get('/data-acuan/versi/$versiId', token: token);

    return VersiAcuan.fromJson(_data(json));
  }

  @override
  Future<BandingAcuan> banding(String token, int lamaId, int baruId) async {
    final json = await _api.get(
      '/data-acuan/versi/$lamaId/banding/$baruId',
      token: token,
    );

    return BandingAcuan.fromJson(_data(json));
  }

  @override
  Future<RiwayatSelAcuan> riwayatSel(
    String token, {
    required int versiId,
    required String lembar,
    required String kunci,
    required String kolom,
  }) async {
    // Tiap segmen di-encode: kunci baris bisa `1:3` (awalan elemen induk) atau
    // `101.6`, dan dia masuk path URL apa adanya.
    final json = await _api.get(
      '/data-acuan/versi/$versiId/sel/${_seg(lembar)}/${_seg(kunci)}/'
      '${_seg(kolom)}/riwayat',
      token: token,
    );

    return RiwayatSelAcuan.fromJson(_data(json));
  }

  @override
  Future<List<VersiAlurAcuan>> alur(String token, String kode) async {
    final json = await _api.get(
      '/data-acuan/paket/${_seg(kode)}/alur',
      token: token,
    );

    return parseListAman(json['data'], VersiAlurAcuan.fromJson);
  }

  @override
  Future<LaporanSimulasiAcuan> laporanSimulasi(
    String token,
    int versiId,
  ) async {
    final json = await _api.get(
      '/data-acuan/versi/$versiId/simulasi',
      token: token,
    );

    return LaporanSimulasiAcuan.fromJson(_data(json));
  }

  @override
  Future<void> ajukan(
    String token,
    int versiId, {
    required String alasan,
    List<RujukanAjuanAcuan> rujukan = const [],
  }) async {
    await _api.post(
      '/data-acuan/versi/$versiId/ajukan',
      token: token,
      body: {
        'alasan': alasan,
        if (rujukan.isNotEmpty)
          'rujukan': [for (final r in rujukan) r.toJson()],
      },
    );
  }

  @override
  Future<void> jalankanSimulasi(String token, int versiId) async {
    await _api.post(
      '/data-acuan/versi/$versiId/simulasi',
      token: token,
      // Simulasi menghitung ulang semua sesi profil — bisa lama.
      timeout: const Duration(minutes: 3),
    );
  }

  @override
  Future<void> tolak(
    String token,
    int versiId, {
    required String alasan,
  }) async {
    await _api.post(
      '/data-acuan/versi/$versiId/tolak',
      token: token,
      body: {'alasan': alasan},
    );
  }

  @override
  Future<void> aktifkan(
    String token,
    int versiId, {
    required DateTime berlakuMulai,
    required String password,
    String? catatan,
    Map<String, String> pengakuan = const {},
  }) async {
    await _api.post(
      '/data-acuan/versi/$versiId/aktifkan',
      token: token,
      body: {
        'berlaku_mulai': tanggalIsoAcuan(berlakuMulai),
        'password': password,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
        if (pengakuan.isNotEmpty) 'pengakuan': pengakuan,
      },
    );
  }
}

/// Tiruan buat test & mode mock — meniru bentuk JSON kontrak §15 PERSIS.
///
/// Isinya keadaan lab yang baru menjalankan `acuan:impor-awal micrometer`:
/// satu paket Micrometer dengan versi 1 `aktif` (isi & sha256 = keluaran kode
/// server, lihat `data_acuan_contoh_micrometer.dart`), plus satu profil ber-
/// skema yang belum diimpor untuk memperlihatkan keadaan "belum diimpor".
/// Server hari ini baru punya skema Micrometer; baris kedua itu peraga
/// keadaan, bukan klaim bahwa skemanya sudah ada.
///
/// Respons dirakit sebagai peta JSON lalu dilewatkan `jsonEncode`/`jsonDecode`
/// sebelum di-parse — jalur yang sama dengan respons API, jadi tipe angka di
/// model sama persis dengan yang diterima dari server.
///
/// Mock TIDAK menghitung angka apa pun. Banding hanya bisa versi 1 dengan
/// dirinya sendiri (nol perubahan); riwayat sel cuma MEMBACA nilai dari isi.
class MockDataAcuanService implements DataAcuanService {
  MockDataAcuanService({
    this.jeda = Duration.zero,
    this.gagal = false,
    this.sebagaiTeknisi = false,
  });

  final Duration jeda;
  final bool gagal;

  /// Niru jawaban server untuk teknisi: kunci draf/terjadwal tidak dikirim,
  /// banding & riwayat sel → 404, alasan `berlaku` generik.
  final bool sebagaiTeknisi;

  static const kodeMicrometer = 'micrometer';
  static const idVersi1 = 1;

  /// Peraga "belum diimpor" (profil nyata di registry server).
  static const kodeBelumDiimpor = 'height_gauge';

  static const _berlakuMulaiV1 = '2024-01-01';
  static const _berkasV1 = 'database/data/tabel-standar-micrometer.json';
  static const _alasanTeknisi =
      'Tidak ada versi aktif yang berlaku pada tanggal itu.';

  Future<void> _mulai() async {
    await Future<void>.delayed(jeda);
    if (gagal) throw Exception('Gagal memuat data acuan.');
  }

  static Map<String, dynamic> _json(Map<String, dynamic> peta) =>
      jsonDecode(jsonEncode(peta)) as Map<String, dynamic>;

  static Never _tidakAda(String pesan) =>
      throw ApiException(pesan, status: 404, body: {'message': pesan});

  static Map<String, dynamic> _ringkasV1() => {
    'id': idVersi1,
    'nomor': 1,
    'status': 'aktif',
    'berlaku_mulai': _berlakuMulaiV1,
    'berlaku_sampai': null,
    'sha256': contohSha256MicrometerV1,
  };

  static Map<String, dynamic> _versiV1({bool denganIsi = false}) => {
    'id': idVersi1,
    'paket': kodeMicrometer,
    'jenis': 'data',
    'nomor': 1,
    'status': 'aktif',
    'skema_versi': 1,
    'dasar_versi_id': null,
    'berlaku_mulai': _berlakuMulaiV1,
    'berlaku_sampai': null,
    'isi_sha256': contohSha256MicrometerV1,
    'alasan': 'Impor awal dari $_berkasV1',
    'rujukan': [
      {
        'jenis': 'berkas_repo',
        'nilai': _berkasV1,
        'catatan': contohSha256MicrometerV1,
      },
    ],
    'catatan_keputusan': null,
    // Versi 1 hasil impor: tidak ada pembuat, pengaju, maupun pengesah.
    // Impor bukan pengesahan — dan mock tidak mengarang persetujuan siapa pun.
    'dibuat_oleh': null,
    'diajukan_oleh': null,
    'diajukan_pada': null,
    'disahkan_oleh': null,
    'disahkan_pada': null,
    'ditolak_oleh': null,
    'ditolak_pada': null,
    'lock_versi': 0,
    'created_at': '2026-10-08T10:00:00+07:00',
    'updated_at': '2026-10-08T10:00:00+07:00',
    if (denganIsi) 'isi': jsonDecode(contohIsiMicrometerV1),
  };

  static Map<String, dynamic> _skema() =>
      jsonDecode(contohSkemaMicrometer) as Map<String, dynamic>;

  Map<String, dynamic> _barisPaket({
    required bool diimpor,
    bool detail = false,
  }) {
    final kode = diimpor ? kodeMicrometer : kodeBelumDiimpor;

    return {
      'kode': kode,
      'nama': diimpor ? 'Micrometer' : 'Height Gauge',
      'skema_versi': 1,
      'diimpor': diimpor,
      'versi_aktif': diimpor ? _ringkasV1() : null,
      // Kunci di bawah TIDAK dikirim ke teknisi — bukan `null`.
      if (!sebagaiTeknisi) 'versi_terjadwal': <Object?>[],
      if (!sebagaiTeknisi) 'jumlah_draf': 0,
      if (detail && !sebagaiTeknisi) 'jumlah_diajukan': 0,
      if (detail) 'skema': _skema(),
    };
  }

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) async {
    await _mulai();

    final json = _json({
      'data': [_barisPaket(diimpor: true), _barisPaket(diimpor: false)],
    });

    return parseListAman(json['data'], PaketAcuan.fromJson);
  }

  @override
  Future<PaketAcuan> paket(String token, String kode) async {
    await _mulai();
    if (kode != kodeMicrometer) _tidakAda('Paket data acuan tidak ditemukan.');

    final json = _json({'data': _barisPaket(diimpor: true, detail: true)});

    return PaketAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<HasilBerlakuAcuan> berlaku(
    String token,
    String kode,
    DateTime tanggal, {
    String jenis = 'data',
  }) async {
    await _mulai();
    if (kode != kodeMicrometer) _tidakAda('Paket data acuan tidak ditemukan.');

    if (jenis != 'data' && jenis != 'bentuk') {
      const pesan = 'Jenis cuma boleh `data` atau `bentuk`.';
      throw const ApiException(pesan, status: 422, body: {'message': pesan});
    }

    final iso = tanggalIsoAcuan(tanggal);

    // Kalimat admin disalin dari `DataAcuanController::alasanTidakBerlaku`.
    String? alasan;
    if (jenis == 'bentuk') {
      alasan = sebagaiTeknisi
          ? _alasanTeknisi
          : 'Paket $kodeMicrometer belum punya versi bentuk berstatus aktif '
                'atau pensiun.';
    } else if (iso.compareTo(_berlakuMulaiV1) < 0) {
      alasan = sebagaiTeknisi
          ? _alasanTeknisi
          : 'Tanggal $iso sebelum versi data pertama berlaku '
                '($_berlakuMulaiV1).';
    }

    final json = _json(
      alasan == null
          ? {'data': _versiV1(), 'alasan': null}
          : {'data': null, 'alasan': alasan},
    );

    return HasilBerlakuAcuan.fromJson(json);
  }

  @override
  Future<List<VersiAcuan>> garisWaktu(String token, String kode) async {
    await _mulai();
    if (kode != kodeMicrometer) _tidakAda('Paket data acuan tidak ditemukan.');

    final json = _json({
      'data': [_versiV1()],
    });

    return parseListAman(json['data'], VersiAcuan.fromJson);
  }

  @override
  Future<VersiAcuan> versi(String token, int versiId) async {
    await _mulai();
    if (versiId != idVersi1) _tidakAda('Data nggak ketemu.');

    final json = _json({'data': _versiV1(denganIsi: true)});

    return VersiAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<BandingAcuan> banding(String token, int lamaId, int baruId) async {
    await _mulai();
    if (sebagaiTeknisi || lamaId != idVersi1 || baruId != idVersi1) {
      _tidakAda('Data nggak ketemu.');
    }

    final lembar = (_skema()['lembar'] as List).cast<Map<String, dynamic>>();

    final json = _json({
      'data': {
        'paket': kodeMicrometer,
        'skema_versi': 1,
        'lama': _ringkasV1(),
        'baru': _ringkasV1(),
        // Satu-satunya pasangan yang ada di mock: versi 1 dengan dirinya
        // sendiri. Semua lembar ikut, tanpa perubahan — persis server.
        'lembar': [
          for (final l in lembar)
            {
              'kode': l['kode'],
              'label': l['label'] ?? l['kode'],
              'sel_berubah': <Object?>[],
              'baris_tambah': <Object?>[],
              'baris_hapus': <Object?>[],
            },
        ],
        'ringkasan': {
          'lembar_berubah': 0,
          'sel_berubah': 0,
          'baris_tambah': 0,
          'baris_hapus': 0,
        },
      },
    });

    return BandingAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<RiwayatSelAcuan> riwayatSel(
    String token, {
    required int versiId,
    required String lembar,
    required String kunci,
    required String kolom,
  }) async {
    await _mulai();
    if (sebagaiTeknisi || versiId != idVersi1) _tidakAda('Data nggak ketemu.');

    final defLembar = (_skema()['lembar'] as List)
        .cast<Map<String, dynamic>>()
        .where((l) => l['kode'] == lembar)
        .firstOrNull;
    if (defLembar == null) _tidakAda('Lembar tidak ada di skema paket ini.');

    final defKolom = (defLembar['kolom'] as List)
        .cast<Map<String, dynamic>>()
        .where((k) => k['kode'] == kolom)
        .firstOrNull;
    if (defKolom == null) _tidakAda('Kolom tidak ada di lembar ini.');

    // Pembaca baris yang SAMA dengan yang dipakai layar Studio — satu port
    // `SelAcuan::baris()`, bukan dua salinan yang bisa menyimpang diam-diam.
    final baris = barisLembarAcuan(
      LembarSkemaAcuan.fromJson(defLembar),
      jsonDecode(contohIsiMicrometerV1),
    )[kunci];
    // Kunci yang tidak ada → 200 dengan `ada: false`, bukan 404 (kontrak).
    final nilai = baris != null && baris.containsKey(kolom)
        ? {'ada': true, 'nilai': baris[kolom]}
        : {'ada': false, 'nilai': null};

    final json = _json({
      'data': {
        'paket': kodeMicrometer,
        'versi': _ringkasV1(),
        'lembar': lembar,
        'kunci': kunci,
        'kolom': defKolom,
        ...nilai,
        'riwayat': [
          {'versi': _ringkasV1(), ...nilai},
        ],
        // Versi 1 lahir dari impor, bukan suntingan — jejaknya kosong.
        'suntingan': <Object?>[],
      },
    });

    return RiwayatSelAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ─── Alur versi (T2.2/T2.3) ────────────────────────────────────────────
  //
  // Keadaan peraga: versi 2 Micrometer = DRAF hasil impor master Studio
  // (bentuk `DrafAcuanMaster::buat`), versi 1 tetap aktif. Transisi meniru
  // `AlurVersiAcuan` (status yang boleh, kode galat, pengakuan wajib), tanpa
  // menghitung angka apa pun. Laporan simulasinya FIXTURE STRUKTUR sintetis
  // (nomor sesi & sertifikat `PERAGA`, angka 0.5 → 0.75), bukan angka lab.

  static const idVersi2 = 2;

  /// Sandi konfirmasi peraga = sandi akun mock (`MockAuthService`).
  static const sandiPeraga = 'rahasia123';

  String _statusV2 = 'draf';
  bool _adaSimulasiV2 = false;
  bool _simulasiKedaluwarsa = false;
  String? _berlakuMulaiV2;
  final List<Map<String, dynamic>> _logV2 = [
    {
      'aksi': 'dibuat',
      'status_dari': null,
      'status_ke': 'draf',
      'isi_sha256': null,
      'user_id': 1,
      'alasan': 'Diekstrak dari master Studio #7.',
      'sumber': {
        'workbook_master_id': 7,
        'workbook_nama': 'Master Olah Data Micrometer 0-25mm',
        'peta_sel': kodeMicrometer,
        'varian': '0-25',
      },
      'rincian': {'sel_berubah': 1},
      'pada': '2026-10-22T09:00:00+07:00',
    },
  ];

  /// Aksi tulis yang diterima (`ajukan:2`, `simulasi:2`, …) — bukti test bahwa
  /// tombol menembak aksi yang benar.
  final List<String> panggilanTulis = [];

  /// Isi terakhir tiap aksi tulis (test).
  final Map<String, Object?> isianTulis = {};

  /// Galat yang dilempar aksi tulis berikutnya (test); `null` = jalan.
  Object? galatTulis;

  /// Keadaan awal versi 2 (test): `draf` (bawaan) atau `diajukan`.
  set statusAwalV2(String status) => _statusV2 = status;

  /// Anggap simulasi sudah dijalankan (test).
  void sudahDisimulasikan({bool kedaluwarsa = false}) {
    _adaSimulasiV2 = true;
    _simulasiKedaluwarsa = kedaluwarsa;
  }

  static const _shaPeragaV2 =
      '0000000000000000000000000000000000000000000000000000000000000002';

  static Map<String, dynamic> _tanpaSimulasi() => {
    'status': 'belum_ada',
    'id': null,
    'isi_sha256': null,
    'dijalankan_oleh': null,
    'selesai': null,
    'ringkasan': null,
    'wajib_diakui': <Object?>[],
  };

  Map<String, dynamic> _simulasiV2() => !_adaSimulasiV2
      ? _tanpaSimulasi()
      : {
          'status': _simulasiKedaluwarsa ? 'kedaluwarsa' : 'terbaru',
          'id': 11,
          'isi_sha256': _shaPeragaV2,
          'dijalankan_oleh': 1,
          'selesai': '2026-10-22T09:30:00+07:00',
          'ringkasan': {
            'sesi_total': 3,
            'sesi_berubah': 1,
            'cetak_berubah': 1,
            'terbit_cetak_berubah': 1,
            'vonis_berubah': 0,
            'sesi_gagal': 0,
            'sumber_acuan_aktif': 'db',
            'catatan_sumber': null,
            'jejak_data': {
              'sesi_jumlah': 3,
              'sesi_terakhir_diubah': '2026-10-21 10:00:00',
              'sertifikat_terbit_jumlah': 1,
            },
            'bersama_antar_varian': 0,
            'master_varian_lain_tidak_sepakat': 0,
          },
          'wajib_diakui': [ButirPengakuanAcuan.terbitCetakBerubah],
        };

  Map<String, dynamic> _versiV2() => {
    'id': idVersi2,
    'paket': kodeMicrometer,
    'jenis': 'data',
    'nomor': 2,
    'status': _statusV2,
    'skema_versi': 1,
    'dasar_versi_id': idVersi1,
    'berlaku_mulai': _berlakuMulaiV2,
    'berlaku_sampai': null,
    'isi_sha256': _statusV2 == 'draf' ? null : _shaPeragaV2,
    'alasan':
        'Diekstrak dari master Studio #7 (Master Olah Data Micrometer '
        '0-25mm) lewat peta sel micrometer.',
    'rujukan': [
      {
        'jenis': 'workbook_master',
        'nilai': '#7 Master Olah Data Micrometer 0-25mm',
        'catatan': 'peraga',
      },
    ],
    'catatan_keputusan': null,
    'dibuat_oleh': 1,
    'diajukan_oleh': _statusV2 == 'draf' ? null : 1,
    'diajukan_pada': null,
    'disahkan_oleh': null,
    'disahkan_pada': null,
    'ditolak_oleh': null,
    'ditolak_pada': null,
    'lock_versi': 0,
    'created_at': '2026-10-22T09:00:00+07:00',
    'updated_at': '2026-10-22T09:00:00+07:00',
  };

  static Never _tolakAlur(
    String kode,
    String pesan, {
    Map<String, dynamic>? rincian,
  }) => throw ApiException(
    pesan,
    status: 422,
    body: {'message': pesan, 'kode': kode, 'rincian': ?rincian},
  );

  Future<void> _mulaiTulis(String aksi, int versiId, Object? isian) async {
    await _mulai();
    if (sebagaiTeknisi) _tidakAda('Data nggak ketemu.');
    panggilanTulis.add('$aksi:$versiId');
    isianTulis[aksi] = isian;
    final g = galatTulis;
    if (g != null) {
      galatTulis = null;
      throw g;
    }
    if (versiId != idVersi2 && versiId != idVersi1) {
      _tidakAda('Data nggak ketemu.');
    }
  }

  void _catatLog(String aksi, String dari, String ke, String? alasan) =>
      _logV2.add({
        'aksi': aksi,
        'status_dari': dari,
        'status_ke': ke,
        'isi_sha256': ke == 'draf' ? null : _shaPeragaV2,
        'user_id': 1,
        'alasan': alasan,
        'sumber': null,
        'rincian': null,
        'pada': '2026-10-22T10:00:00+07:00',
      });

  @override
  Future<List<VersiAlurAcuan>> alur(String token, String kode) async {
    await _mulai();
    if (sebagaiTeknisi || kode != kodeMicrometer) {
      _tidakAda('Paket data acuan tidak ditemukan.');
    }

    final json = _json({
      'data': [
        {..._versiV2(), 'simulasi': _simulasiV2(), 'log': _logV2},
        {..._versiV1(), 'simulasi': _tanpaSimulasi(), 'log': <Object?>[]},
      ],
    });

    return parseListAman(json['data'], VersiAlurAcuan.fromJson);
  }

  static Map<String, dynamic> _sesiTidakBerubah(int id, String nomor) => {
    'sesi_id': id,
    'nomor_sesi': nomor,
    'status_sesi': 'draft',
    'tanggal_kalibrasi': '2026-10-15',
    'sudah_terbit': false,
    'nomor_sertifikat_terbit': <Object?>[],
    'versi_pembanding': 'v1 (#1)',
    'berubah': false,
    'cetak_berubah': false,
    'vonis_berubah': false,
    'selisih': <Object?>[],
    'cetak': <Object?>[],
    'titik_tidak_terhitung': <Object?>[],
    'galat': null,
  };

  @override
  Future<LaporanSimulasiAcuan> laporanSimulasi(
    String token,
    int versiId,
  ) async {
    await _mulai();
    if (sebagaiTeknisi || (versiId != idVersi2 && versiId != idVersi1)) {
      _tidakAda('Data nggak ketemu.');
    }

    final ada = versiId == idVersi2 && _adaSimulasiV2;
    final json = _json({
      'data': {
        ...(versiId == idVersi2 ? _simulasiV2() : _tanpaSimulasi()),
        'laporan': !ada
            ? null
            : {
                'sesi': [
                  {
                    'sesi_id': 101,
                    'nomor_sesi': 'SES-PERAGA-001',
                    'status_sesi': 'approved',
                    'tanggal_kalibrasi': '2026-10-01',
                    'sudah_terbit': true,
                    'nomor_sertifikat_terbit': ['PERAGA/CERT/001'],
                    'versi_pembanding': 'v1 (#1)',
                    'berubah': true,
                    'cetak_berubah': true,
                    'vonis_berubah': false,
                    'selisih': [
                      {
                        'titik': 1,
                        'kolom': 'koreksi',
                        'lama': 0.5,
                        'baru': 0.75,
                        'selisih': 0.25,
                      },
                    ],
                    'cetak': [
                      {
                        'titik': 1,
                        'kolom': 'koreksi',
                        'lama': '0.5',
                        'baru': '0.8',
                      },
                    ],
                    'titik_tidak_terhitung': <Object?>[],
                    'galat': null,
                  },
                  _sesiTidakBerubah(102, 'SES-PERAGA-002'),
                  _sesiTidakBerubah(103, 'SES-PERAGA-003'),
                ],
                'bersama_antar_varian': {
                  'berlaku': true,
                  'varian_draf': '0-25',
                  'berubah': <Object?>[],
                  'master_lain': <Object?>[],
                },
              },
      },
    });

    return LaporanSimulasiAcuan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> ajukan(
    String token,
    int versiId, {
    required String alasan,
    List<RujukanAjuanAcuan> rujukan = const [],
  }) async {
    await _mulaiTulis('ajukan', versiId, {
      'alasan': alasan,
      'rujukan': [for (final r in rujukan) r.toJson()],
    });
    if (versiId != idVersi2 || _statusV2 != 'draf') {
      _tolakAlur(
        'status_tidak_sesuai',
        'Hanya draf yang bisa diajukan. Status sekarang: $_statusV2.',
      );
    }
    _statusV2 = 'diajukan';
    _catatLog('ajukan', 'draf', 'diajukan', alasan);
  }

  @override
  Future<void> jalankanSimulasi(String token, int versiId) async {
    await _mulaiTulis('simulasi', versiId, null);
    if (versiId != idVersi2 ||
        (_statusV2 != 'draf' && _statusV2 != 'diajukan')) {
      _tolakAlur(
        'status_tidak_sesuai',
        'Hanya draf atau versi diajukan yang bisa disimulasikan.',
      );
    }
    _adaSimulasiV2 = true;
    _simulasiKedaluwarsa = false;
    _catatLog('simulasi', _statusV2, _statusV2, null);
  }

  @override
  Future<void> tolak(
    String token,
    int versiId, {
    required String alasan,
  }) async {
    await _mulaiTulis('tolak', versiId, {'alasan': alasan});
    if (versiId != idVersi2 ||
        (_statusV2 != 'draf' && _statusV2 != 'diajukan')) {
      _tolakAlur(
        'status_tidak_sesuai',
        'Hanya draf atau versi diajukan yang bisa ditolak.',
      );
    }
    final dari = _statusV2;
    _statusV2 = dari == 'draf' ? 'dibuang' : 'ditolak';
    _catatLog(dari == 'draf' ? 'buang' : 'tolak', dari, _statusV2, alasan);
  }

  @override
  Future<void> aktifkan(
    String token,
    int versiId, {
    required DateTime berlakuMulai,
    required String password,
    String? catatan,
    Map<String, String> pengakuan = const {},
  }) async {
    final iso = tanggalIsoAcuan(berlakuMulai);
    // Sandi TIDAK dicatat — cuma ada/tidaknya.
    await _mulaiTulis('aktifkan', versiId, {
      'berlaku_mulai': iso,
      'ada_sandi': password.isNotEmpty,
      'catatan': catatan,
      'pengakuan': pengakuan,
    });
    if (password != sandiPeraga) {
      _tolakAlur('konfirmasi_sandi_salah', 'Sandi konfirmasi salah.');
    }
    if (versiId != idVersi2 || _statusV2 != 'diajukan') {
      _tolakAlur(
        'status_tidak_sesuai',
        'Hanya versi yang sudah diajukan yang bisa disahkan.',
      );
    }
    if (iso.compareTo(tanggalIsoAcuan(DateTime.now())) < 0) {
      _tolakAlur(
        'berlaku_mulai_lampau',
        'Tanggal berlaku tidak boleh sebelum hari ini.',
      );
    }
    if (!_adaSimulasiV2) {
      _tolakAlur('simulasi_belum_ada', 'Jalankan simulasi dulu.');
    }
    if (_simulasiKedaluwarsa) {
      _tolakAlur('simulasi_kedaluwarsa', 'Jalankan simulasi ulang.');
    }
    final kurang = [ButirPengakuanAcuan.terbitCetakBerubah]
        .where(
          (b) =>
              (pengakuan[b] ?? '').trim().length <
              ButirPengakuanAcuan.panjangMinimum,
        )
        .toList();
    if (kurang.isNotEmpty) {
      _tolakAlur(
        'pengakuan_wajib',
        'Simulasi menunjukkan hal yang wajib diakui.',
        rincian: {'butir': kurang},
      );
    }
    _statusV2 = 'aktif';
    _berlakuMulaiV2 = iso;
    _catatLog('sahkan', 'diajukan', 'aktif', catatan);
  }
}
