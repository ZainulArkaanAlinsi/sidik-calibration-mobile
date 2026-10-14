import 'dart:convert';

import '../core/utils/parse_list.dart';
import '../models/data_acuan.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'data_acuan_contoh_micrometer.dart';

/// Studio Data Acuan (CR-48) — BACA saja (P1, kontrak API §15). Izin tulis
/// (`sunting`/`impor`/`ajukan`/`sahkan`) belum lahir di server, jadi belum ada
/// satu pun method tulis di sini.
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
}
