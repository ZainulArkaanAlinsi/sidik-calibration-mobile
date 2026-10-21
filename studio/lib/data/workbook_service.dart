import 'dart:convert';
import 'dart:typed_data';

import 'package:sidik_calibration/core/utils/parse_list.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart' show ApiException;

import '../widget/grid/alamat_sel.dart';
import 'workbook_model.dart';

/// Workbook Alat (S1b) — BACA saja. Izin `workbook.lihat`; siapa melihat apa
/// dan isolasi organisasi ditegakkan SERVER (workbook lab lain → 404).
/// `ApiException` dibiarkan lewat apa adanya; layar yang menampilkannya.
abstract class WorkbookService {
  /// `GET /studio/workbook?kode_profil=&cari=`.
  Future<List<WorkbookRingkas>> daftar(
    String token, {
    String? kodeProfil,
    String? cari,
  });

  /// `GET /studio/workbook/{id}` — meta + lembar (+ tata letak).
  Future<WorkbookDetail> detail(String token, int workbookId);

  /// `GET /studio/workbook/{id}/riwayat` (K-49-13) — semua versi jenis yang
  /// sama dengan [workbookId]. Diarsipkan / lab lain → `ApiException` 404.
  /// Server sebelum K-49-13 tidak punya rute ini (404) — hanya dipanggil bila
  /// `jumlah_riwayat` > 0, yang tidak pernah dikirim server lama.
  Future<RiwayatWorkbook> riwayat(String token, int workbookId);

  /// `GET /studio/workbook/{id}/lembar/{lembarId}?baris_dari=&baris_sampai=`
  /// — server membatasi satu halaman maksimal [batasBarisPerPermintaan].
  Future<HalamanSelWorkbook> sel(
    String token, {
    required int workbookId,
    required int lembarId,
    required int barisDari,
    required int barisSampai,
  });

  /// `POST /studio/workbook/{id}/hitung` (Tahap C) — SIMULASI: server
  /// menghitung ulang workbook dengan [edit] (SEMUA edit yang berlaku;
  /// stateless) dan tidak menyimpan apa pun. Gagal = `ApiException` apa
  /// adanya (409 berkas asli tidak ada, 422 edit ditolak, 504 terlalu lama).
  Future<HasilHitung> hitung(
    String token, {
    required int workbookId,
    required List<EditSel> edit,
    DateTime? waktuAcuan,
  });

  /// `GET /studio/workbook/{id}/gambar/{gambarId}` — byte png/jpeg dengan
  /// header auth yang sama. `null` = tidak ada (404).
  Future<Uint8List?> gambar(
    String token, {
    required int workbookId,
    required String gambarId,
  });

  /// `POST /studio/workbook/impor` (K-50-12, multipart) — unggah master
  /// `.xlsm/.xlsx/.csv`. [sandi] hanya dikirim, TIDAK disimpan di mana pun.
  /// [gantikanId] = id workbook yang digantikan master baru ini. `422`
  /// (sandi salah / format tidak dikenal) dilempar sebagai `ApiException`.
  Future<HasilUnggahMaster> unggahMaster(
    String token, {
    required String jalurBerkas,
    required String alasan,
    String? sandi,
    int? gantikanId,
  });
}

/// Batas server per permintaan sel (kontrak: maks 500 baris).
const int batasBarisPerPermintaan = 500;

/// Batas edit per permintaan `/hitung` (kontrak Tahap C).
const int batasEditSimulasi = 300;

/// Batas waktu klien untuk `/hitung`: server memotong di 20 s (504); sisanya
/// jalan bolak-balik + pemanasan server yang tertidur.
const Duration batasWaktuHitung = Duration(seconds: 45);

class ApiWorkbookService implements WorkbookService {
  ApiWorkbookService(this._api);

  final ApiClient _api;

  static Map<String, dynamic> _data(Map<String, dynamic> json) =>
      (json['data'] ?? json) as Map<String, dynamic>;

  @override
  Future<List<WorkbookRingkas>> daftar(
    String token, {
    String? kodeProfil,
    String? cari,
  }) async {
    final kueri = <String, String>{
      if (kodeProfil != null && kodeProfil.isNotEmpty)
        'kode_profil': kodeProfil,
      if (cari != null && cari.trim().isNotEmpty) 'cari': cari.trim(),
    };
    final jalur = Uri(
      path: '/studio/workbook',
      queryParameters: kueri.isEmpty ? null : kueri,
    );
    final json = await _api.get(jalur.toString(), token: token);

    return parseListAman(json['data'], WorkbookRingkas.fromJson);
  }

  @override
  Future<WorkbookDetail> detail(String token, int workbookId) async {
    final json = await _api.get('/studio/workbook/$workbookId', token: token);

    return WorkbookDetail.fromJson(_data(json));
  }

  @override
  Future<RiwayatWorkbook> riwayat(String token, int workbookId) async {
    // `data` di sini LARIK + `kunci_jenis` di sampingnya — tidak di-unwrap.
    final json = await _api.get(
      '/studio/workbook/$workbookId/riwayat',
      token: token,
    );

    return RiwayatWorkbook.fromJson(json);
  }

  @override
  Future<HalamanSelWorkbook> sel(
    String token, {
    required int workbookId,
    required int lembarId,
    required int barisDari,
    required int barisSampai,
  }) async {
    assert(barisSampai - barisDari + 1 <= batasBarisPerPermintaan);
    final json = await _api.get(
      '/studio/workbook/$workbookId/lembar/$lembarId'
      '?baris_dari=$barisDari&baris_sampai=$barisSampai',
      token: token,
    );

    return HalamanSelWorkbook.fromJson(_data(json));
  }

  @override
  Future<HasilHitung> hitung(
    String token, {
    required int workbookId,
    required List<EditSel> edit,
    DateTime? waktuAcuan,
  }) async {
    final json = await _api.post(
      '/studio/workbook/$workbookId/hitung',
      token: token,
      body: {
        'edit': [for (final e in edit) editSelKeJson(e)],
        if (waktuAcuan != null) 'waktu_acuan': waktuAcuan.toIso8601String(),
      },
      timeout: batasWaktuHitung,
    );

    return HasilHitung.fromJson(_data(json));
  }

  @override
  Future<HasilUnggahMaster> unggahMaster(
    String token, {
    required String jalurBerkas,
    required String alasan,
    String? sandi,
    int? gantikanId,
  }) async {
    final json = await _api.unggahFile(
      '/studio/workbook/impor',
      field: 'berkas',
      filePath: jalurBerkas,
      token: token,
      fields: {
        'alasan': alasan,
        if (sandi != null && sandi.isNotEmpty) 'sandi': sandi,
        if (gantikanId != null) 'gantikan': '$gantikanId',
      },
      timeout: const Duration(minutes: 3),
    );
    return HasilUnggahMaster.fromJson(json);
  }

  @override
  Future<Uint8List?> gambar(
    String token, {
    required int workbookId,
    required String gambarId,
  }) => _api.ambilBytes(
    '/studio/workbook/$workbookId/gambar/${Uri.encodeComponent(gambarId)}',
    token: token,
  );
}

/// Tiruan untuk test & mode mock — bentuk JSON kontrak (FORMAT 3, Tahap A)
/// PERSIS, dilewatkan `jsonEncode`/`jsonDecode` seperti jawaban server.
///
/// ## Isi (kecil, realistis)
///
/// 1. **Master Olah Data Micrometer 0-25mm** (`xlsm`, `micrometer`, keluarga
///    Dimensi), empat lembar:
///    - `PERHITUNGAN U95%` — teks & NILAI disalin dari
///      `Project-PT-Sidik/alat-alat-Pt-Sidik/Panjang_CSV/
///      Master_Olah_Data_Micrometer_0-25mm/PERHITUNGAN U95%.csv` (baris 1,
///      4, 6, 7, 8, 14–17, posisi sel asli; ukuran 21 × 38 = ukuran CSV).
///      RUMUS-nya PERAGA: ditulis supaya konsisten dengan nilainya (mis.
///      `=K6/N6` → 0,127/√3 = 0,07332…; `=SUM(AA5:AA13)` = 0,14003… dari
///      kolom AA CSV), BUKAN salinan rumus master. Tata letak (lebar, merge,
///      freeze) dan GAYA (isi, garis, bungkus, vertikal, ukuran) juga peraga.
///      Teks panjang di B8/B14–B17 sengaja tidak digabung: itulah yang
///      meluber di Excel.
///    - `Standar_GB` — TERSEMBUNYI (`true`, kontrak Tahap C), garis kisi MATI, nilai dari
///      `Standar_GB.csv`.
///    - `DATABASE` — BERISI (K-49-12), `tautan_tabel` = `customers`. Yang
///      disalin cuma label kepala kolomnya (`DATABASE.csv` baris 1–3);
///      tidak ada satu pun data pelanggan.
///    - `SERTIFIKAT` — DIKECUALIKAN (jalur impor lama sebelum K-49-12):
///      tanpa sel, panel penanda tabel `certificates`.
/// 2. **Master_Olah_Data_Micrometer_0-25mm** (`csv`, alat yang SAMA dengan
///    no. 1) — RIWAYAT no. 1 (K-49-13, lihat di bawah); lebar kolom
///    perkiraan server.
/// 3. **Master_olda_Height_Gauge_600_mm_2026** (`csv`, BELUM dipetakan —
///    pertanyaan peta workbook no. 5), satu lembar `INPUT DATA` 300 × 26
///    (ukuran CSV-nya; dua halaman sel — halaman kedua kosong), nilai bagian
///    judul & identitas ALAT dari CSV-nya, tata letak kosong (server lama).
///    Bagian identitas pelanggan sengaja tidak disalin.
///
/// ## Jenis master (K-49-13)
///
/// Kunci jenis dibentuk seperti `KunciJenisWorkbook` server: no. 1 & 2 sama
/// (`dimensi:micrometer-0-25mm`) — CSV diimpor lebih dulu (impor #1), lalu
/// `.xlsm` menggantikannya (impor #2, aktif) → CSV jadi riwayat, tidak ikut
/// daftar, dibuka lewat `GET …/riwayat`. No. 3 sendirian
/// (`tanpa-profil:height-gauge-600-mm`). [serverLama] = server sebelum
/// K-49-13: tanpa kunci jenis sama sekali, daftar memuat SEMUA workbook (CSV
/// kembaran tampil di bawah "Sumber lain"), rute riwayat 404. [diarsipkan]
/// meniru `studio:rapikan-workbook --arsipkan`: 404 di semua rute, hilang
/// dari daftar & riwayat.
///
/// Gambar (Tahap C): `PERHITUNGAN U95%` membawa dua gambar PERAGA — png 1×1
/// di K18 (geser 3/2 px, 96 × 48 px) dan EMF di A1 (panel beku; jenis yang
/// tidak digambar Studio).
///
/// Mock TIDAK menghitung apa pun. `/hitung` tiruan hanya MENGGEMAKAN sel yang
/// diedit (diketik seperti kontrak: `""` kosong, angka bertitik desimal,
/// TRUE/FALSE, sisanya teks; gaya & format sel asal ikut), sel lain tidak
/// berubah, dan rumus TIDAK dihitung (sel rumus kosong + galat contoh).
/// Workbook CSV → 409 seperti server. Test yang butuh jawaban lain memasang
/// [jawabanHitung].
class MockWorkbookService implements WorkbookService {
  MockWorkbookService({
    this.gagal = false,
    this.jawabanHitung,
    this.serverLama = false,
  });

  final bool gagal;

  /// Meniru server sebelum K-49-13 (lihat docblock kelas).
  final bool serverLama;

  /// Id yang "diarsipkan" (test): 404 di semua rute, hilang dari daftar &
  /// riwayat. Boleh diisi sesudah layar terbuka (arsip saat dibuka).
  final diarsipkan = <int>{};

  /// Pengganti jawaban `/hitung` (test): kembalikan JSON jawaban server
  /// (`{"data": {...}}`), atau lempar untuk meniru galat. Boleh menunggu
  /// (`Completer`) untuk meniru request yang lama.
  Future<Map<String, Object?>> Function(int workbookId, List<EditSel> edit)?
  jawabanHitung;

  /// Dihitung per jalur supaya test bisa memastikan halaman di-cache.
  final panggilanSel = <String>[];
  int panggilanDaftar = 0;
  int panggilanDetail = 0;
  int panggilanRiwayat = 0;

  /// Isi setiap kiriman `/hitung` (urut).
  final panggilanHitung = <List<EditSel>>[];

  /// Id gambar yang diminta (urut).
  final panggilanGambar = <String>[];

  static const idMicrometer = 1;
  static const idHeightGauge = 2;
  static const idMicrometerCsv = 3;
  static const idLembarU95 = 11;
  static const idLembarStandar = 12;
  static const idLembarDatabase = 13;
  static const idLembarSertifikat = 14;
  static const idLembarInput = 21;
  static const idLembarU95Csv = 31;

  Future<void> _mulai() async {
    await Future<void>.delayed(Duration.zero);
    if (gagal) throw Exception('Gagal memuat workbook.');
  }

  static T _lewatJson<T>(Object peta, T Function(dynamic) urai) =>
      urai(jsonDecode(jsonEncode(peta)));

  static Map<String, dynamic> _tidakAda() => {'message': 'Tidak ditemukan.'};

  static ApiException _tidakDitemukan() =>
      ApiException('Tidak ditemukan.', status: 404, body: _tidakAda());

  /// Workbook yang masih ada di Studio (bukan arsip); `null` = 404.
  Map<String, Object?>? _cari(int id) => diarsipkan.contains(id)
      ? null
      : _workbook.where((w) => w['id'] == id).firstOrNull;

  /// Kunci jenis master (K-49-13) — tidak dikirim server lama.
  static const _kunciJenis = {
    'kunci_jenis',
    'aktif',
    'status',
    'versi',
    'digantikan_oleh_id',
    'jumlah_riwayat',
  };

  @override
  Future<List<WorkbookRingkas>> daftar(
    String token, {
    String? kodeProfil,
    String? cari,
  }) async {
    panggilanDaftar++;
    await _mulai();
    final q = cari?.trim().toLowerCase() ?? '';
    final hasil = [
      for (final w in _workbook)
        // K-49-13: hanya master AKTIF (server lama: semua).
        if ((serverLama || w['aktif'] == true) &&
            !diarsipkan.contains(w['id']) &&
            (kodeProfil == null || w['kode_profil'] == kodeProfil) &&
            (q.isEmpty ||
                '${w['nama']}'.toLowerCase().contains(q) ||
                '${w['kode_profil'] ?? ''}'.toLowerCase().contains(q)))
          _meta(w),
    ];
    return _lewatJson({
      'data': hasil,
    }, (j) => parseListAman((j as Map)['data'], WorkbookRingkas.fromJson));
  }

  @override
  Future<RiwayatWorkbook> riwayat(String token, int workbookId) async {
    panggilanRiwayat++;
    await _mulai();
    // Server lama: rutenya tidak ada.
    final w = serverLama ? null : _cari(workbookId);
    if (w == null) throw _tidakDitemukan();
    final versi =
        [
          for (final v in _workbook)
            if (v['kunci_jenis'] == w['kunci_jenis'] &&
                !diarsipkan.contains(v['id']))
              v,
        ]..sort((a, b) {
          // Seperti server: master aktif dulu, lalu riwayat impor terbaru
          // dulu (urutan impor, bukan kebaruan isi).
          final aktif = (b['aktif'] == true ? 1 : 0).compareTo(
            a['aktif'] == true ? 1 : 0,
          );
          if (aktif != 0) return aktif;
          final v = (b['versi'] as int).compareTo(a['versi'] as int);
          return v != 0 ? v : (b['id'] as int).compareTo(a['id'] as int);
        });
    return _lewatJson({
      'data': [for (final v in versi) _meta(v)],
      'kunci_jenis': w['kunci_jenis'],
    }, (j) => RiwayatWorkbook.fromJson(Map<String, dynamic>.from(j as Map)));
  }

  @override
  Future<WorkbookDetail> detail(String token, int workbookId) async {
    panggilanDetail++;
    await _mulai();
    final w = _cari(workbookId);
    if (w == null) throw _tidakDitemukan();
    return _lewatJson(
      {
        'data': {..._meta(w), 'lembar': w['lembar']},
      },
      (j) => WorkbookDetail.fromJson(
        Map<String, dynamic>.from((j as Map)['data'] as Map),
      ),
    );
  }

  @override
  Future<HalamanSelWorkbook> sel(
    String token, {
    required int workbookId,
    required int lembarId,
    required int barisDari,
    required int barisSampai,
  }) async {
    panggilanSel.add('$workbookId/$lembarId/$barisDari-$barisSampai');
    await _mulai();
    final w = _cari(workbookId);
    final lembar = (w?['lembar'] as List?)
        ?.cast<Map<String, Object?>>()
        .where((l) => l['id'] == lembarId)
        .firstOrNull;
    if (lembar == null) {
      throw ApiException('Tidak ditemukan.', status: 404, body: _tidakAda());
    }
    final semua = _sel[lembarId] ?? const [];
    final halaman = [
      for (final s in semua)
        if ((s['b'] as int) >= barisDari && (s['b'] as int) <= barisSampai) s,
    ];
    return _lewatJson(
      {
        'data': {
          'sel': halaman,
          'baris_dari': barisDari,
          'baris_sampai': barisSampai,
          'jumlah_baris': lembar['jumlah_baris'],
        },
      },
      (j) => HalamanSelWorkbook.fromJson(
        Map<String, dynamic>.from((j as Map)['data'] as Map),
      ),
    );
  }

  @override
  Future<HasilHitung> hitung(
    String token, {
    required int workbookId,
    required List<EditSel> edit,
    DateTime? waktuAcuan,
  }) async {
    panggilanHitung.add(List.unmodifiable(edit));
    await _mulai();
    // Arsip = 404 di `/hitung` juga (riwayat tetap boleh dihitung server).
    if (diarsipkan.contains(workbookId)) throw _tidakDitemukan();
    final kait = jawabanHitung;
    final Map<String, Object?> jawaban;
    if (kait != null) {
      jawaban = await kait(workbookId, edit);
    } else {
      jawaban = _gema(workbookId, edit);
    }
    return _lewatJson(
      jawaban,
      (j) => HasilHitung.fromJson(
        Map<String, dynamic>.from(((j as Map)['data'] ?? j) as Map),
      ),
    );
  }

  /// Jawaban tiruan: sel yang diedit saja, diketik seperti kontrak.
  Map<String, Object?> _gema(int workbookId, List<EditSel> edit) {
    final w = _cari(workbookId);
    if (w == null) {
      throw ApiException('Tidak ditemukan.', status: 404, body: _tidakAda());
    }
    if (w['sumber'] == 'csv') {
      const pesan = 'Workbook ini tidak punya berkas Excel asli di server.';
      throw ApiException(
        pesan,
        status: 409,
        body: {'message': pesan, 'kode': 'berkas_asli_tidak_ada'},
      );
    }
    final idLembar = {
      for (final l in (w['lembar'] as List).cast<Map<String, Object?>>())
        l['id'] as int,
    };
    if (edit.length > batasEditSimulasi ||
        edit.any((e) => !idLembar.contains(e.lembarId))) {
      const pesan = 'Edit tidak sah.';
      throw ApiException(pesan, status: 422, body: {'message': pesan});
    }

    final perLembar = <int, List<Map<String, Object?>>>{};
    final galat = <Map<String, Object?>>[];
    for (final e in edit) {
      final a = e.alamat.a1;
      final asal = (_sel[e.lembarId] ?? const []).where((s) => s['a'] == a);
      final dasar = asal.firstOrNull;
      final f = dasar?['f'] as String?;
      final g = dasar?['g'];
      final isi = e.isi;
      final Map<String, Object?> sel;
      if (isi.isEmpty) {
        sel = {'t': 'kosong', 'n': null, 's': '', 'r': null};
      } else if (isi.startsWith('=')) {
        sel = {'t': 'f', 'n': null, 's': '', 'r': isi};
        galat.add({
          'lembar_id': e.lembarId,
          'a': a,
          'pesan': 'Mode contoh tidak menghitung rumus.',
        });
      } else if (RegExp(
        r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$',
      ).hasMatch(isi.trim())) {
        final n = num.parse(isi.trim());
        sel = {
          't': 'n',
          'n': n,
          's': f == null ? '$n' : _tampil(n, f),
          'r': null,
        };
      } else if (const {'TRUE', 'FALSE'}.contains(isi.toUpperCase())) {
        sel = {'t': 'b', 'n': null, 's': isi.toUpperCase(), 'r': null};
      } else {
        sel = {'t': 's', 'n': null, 's': isi, 'r': null};
      }
      (perLembar[e.lembarId] ??= []).add({
        'a': a,
        'b': e.alamat.baris,
        'k': e.alamat.kolom,
        ...sel,
        'f': f,
        'g': g,
      });
    }
    return {
      'data': {
        'lembar': [
          for (final e in perLembar.entries)
            {'lembar_id': e.key, 'sel': e.value},
        ],
        'jumlah_dihitung': edit.length,
        'durasi_ms': 1,
        'galat': galat,
      },
    };
  }

  @override
  Future<Uint8List?> gambar(
    String token, {
    required int workbookId,
    required String gambarId,
  }) async {
    panggilanGambar.add(gambarId);
    await _mulai();
    final w = _cari(workbookId);
    final g = [
      for (final l in (w?['lembar'] as List? ?? const []))
        ...((l as Map)['gambar'] as List? ?? const []),
    ].cast<Map<String, Object?>>().where((g) => g['id'] == gambarId);
    final ada = g.firstOrNull;
    if (ada == null) return null;
    if (!JenisGambar.dari(ada['jenis']).bisaDigambar) {
      throw ApiException(
        'Jenis gambar tidak didukung.',
        status: 415,
        body: {'jenis': ada['jenis']},
      );
    }
    return Uint8List.fromList(_pngContoh);
  }

  /// Isi setiap unggah master (urut) — sandi ikut dicatat HANYA supaya test
  /// bisa memastikan ia dikirim; tidak ada penyimpanan.
  final panggilanUnggah =
      <({String jalur, String alasan, String? sandi, int? gantikanId})>[];

  /// Galat yang dilempar unggah berikutnya (test); `null` = berhasil.
  Object? galatUnggah;

  @override
  Future<HasilUnggahMaster> unggahMaster(
    String token, {
    required String jalurBerkas,
    required String alasan,
    String? sandi,
    int? gantikanId,
  }) async {
    panggilanUnggah.add((
      jalur: jalurBerkas,
      alasan: alasan,
      sandi: sandi,
      gantikanId: gantikanId,
    ));
    await _mulai();
    final g = galatUnggah;
    if (g != null) throw g;
    return const HasilUnggahMaster(id: 99, nama: 'Master unggahan', versi: 2);
  }

  /// PNG 1 × 1 piksel (abu) — peraga, bukan gambar dari workbook mana pun.
  static final List<int> _pngContoh = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81y'
    'tgAAAABJRU5ErkJggg==',
  );

  Map<String, Object?> _meta(Map<String, Object?> w) => {
    for (final e in w.entries)
      if (e.key != 'lembar' && !(serverLama && _kunciJenis.contains(e.key)))
        e.key: e.value,
  };

  // ─────────────────────────────────────────────────────────── data contoh

  static Map<String, Object?> _lembar({
    required int id,
    required int urutan,
    required String nama,
    required int baris,
    required int kolom,
    required List<Map<String, Object?>> sel,
    Map<String, Object?> tataLetak = const {},
    bool tersembunyi = false,
    bool dikecualikan = false,
    String? alasan,
    String? tautan,
    List<Map<String, Object?>>? gambar,
  }) => {
    'id': id,
    'urutan': urutan,
    'nama': nama,
    'tersembunyi': tersembunyi,
    'dikecualikan': dikecualikan,
    'alasan_dikecualikan': alasan,
    'tautan_tabel': tautan,
    'jumlah_baris': baris,
    'jumlah_kolom': kolom,
    'jumlah_sel': sel.length,
    'jumlah_rumus': sel.where((s) => s['r'] != null).length,
    'tata_letak': tataLetak,
    // Server lama tidak mengirim kunci ini sama sekali.
    'gambar': ?gambar,
  };

  static final List<Map<String, Object?>> _workbook = [
    {
      'id': idMicrometer,
      'nama': 'Master Olah Data Micrometer 0-25mm',
      'kode_profil': 'micrometer',
      'keluarga': 'Dimensi',
      'sumber': 'xlsm',
      'sha256':
          '9c1b6a4f0e2d7c3b5a8f1e4d6c2b9a7f3e5d1c8b4a6f2e9d7c3b5a1f8e4d6c2b',
      'ukuran': 412160,
      'jumlah_lembar': 4,
      // Impor .xlsm menyimpan berkas aslinya (syarat `/hitung` di server).
      'berkas_asli_tersimpan': true,
      'diimpor_pada': '2026-10-13T09:15:00+07:00',
      // K-49-13: menggantikan ekspor CSV-nya (no. 2).
      'kunci_jenis': 'dimensi:micrometer-0-25mm',
      'aktif': true,
      'status': 'aktif',
      'versi': 2,
      'digantikan_oleh_id': null,
      'jumlah_riwayat': 1,
      'lembar': [
        _lembar(
          id: idLembarU95,
          urutan: 1,
          nama: 'PERHITUNGAN U95%',
          baris: 21,
          kolom: 38,
          sel: _selU95,
          tataLetak: {
            'lebar_kolom': {
              'A': 2.7109375,
              'B': 9.140625,
              'C': 9.140625,
              'I': 7.7109375,
              'K': 12.7109375,
              'N': 11.7109375,
              'T': 12.7109375,
              'X': 12.7109375,
              'AA': 12.7109375,
              'AC': 14.7109375,
            },
            'tinggi_baris': {'1': 21.0, '4': 30.0},
            'merge': ['A1:AC1', 'B4:H4', 'B6:H6', 'B7:H7'],
            'freeze': 'C5',
            'kolom_tersembunyi': ['J'],
            'baris_tersembunyi': [2, 3],
            'lebar_kolom_bawaan': 9.140625,
            'tinggi_baris_bawaan': 15.0,
            'garis_kisi': true,
          },
          gambar: const [
            {
              'id': 'u95-png-1',
              'dari': {'kolom': 'K', 'baris': 18, 'dx': 3, 'dy': 2},
              'lebar': 96,
              'tinggi': 48,
              'jenis': 'png',
            },
            {
              'id': 'u95-emf-1',
              'dari': {'kolom': 'A', 'baris': 1, 'dx': 0, 'dy': 0},
              'lebar': 40,
              'tinggi': 24,
              'jenis': 'emf',
            },
          ],
        ),
        _lembar(
          id: idLembarStandar,
          urutan: 2,
          nama: 'Standar_GB',
          tersembunyi: true,
          baris: 133,
          kolom: 26,
          sel: _selStandar,
          tataLetak: {
            'lebar_kolom': {'A': 10.7109375, 'B': 14.7109375},
            'tinggi_baris': {'9': 30.0},
            'merge': <String>[],
            'freeze': null,
            'kolom_tersembunyi': <String>[],
            'baris_tersembunyi': <int>[],
            'garis_kisi': false,
          },
        ),
        _lembar(
          id: idLembarDatabase,
          urutan: 3,
          nama: 'DATABASE',
          baris: 3,
          kolom: 32,
          sel: _selDatabase,
          tautan: 'customers',
          tataLetak: {
            'lebar_kolom': <String, Object?>{},
            'tinggi_baris': <String, Object?>{},
            'merge': <String>[],
            'freeze': null,
            'kolom_tersembunyi': <String>[],
            'baris_tersembunyi': <int>[],
          },
        ),
        _lembar(
          id: idLembarSertifikat,
          urutan: 4,
          nama: 'SERTIFIKAT',
          baris: 0,
          kolom: 0,
          sel: const [],
          dikecualikan: true,
          alasan: 'Impor lama (sebelum K-49-12) — isinya tidak diimpor.',
          tautan: 'certificates',
        ),
      ],
    },
    {
      'id': idMicrometerCsv,
      'nama': 'Master_Olah_Data_Micrometer_0-25mm',
      'kode_profil': 'micrometer',
      'keluarga': 'Dimensi',
      'sumber': 'csv',
      'sha256':
          '2d7c3b5a8f1e4d6c2b9a7f3e5d1c8b4a6f2e9d7c3b5a1f8e4d6c2b9c1b6a4f0e',
      'ukuran': 2240,
      'jumlah_lembar': 1,
      'berkas_asli_tersimpan': false,
      'diimpor_pada': '2026-10-13T09:10:00+07:00',
      // K-49-13: riwayat — digantikan `.xlsm` no. 1.
      'kunci_jenis': 'dimensi:micrometer-0-25mm',
      'aktif': false,
      'status': 'riwayat',
      'versi': 1,
      'digantikan_oleh_id': idMicrometer,
      'jumlah_riwayat': 1,
      'lembar': [
        _lembar(
          id: idLembarU95Csv,
          urutan: 1,
          nama: 'PERHITUNGAN U95%',
          baris: 21,
          kolom: 38,
          sel: _selU95Csv,
          tataLetak: {
            'lebar_kolom': {'A': 30.0, 'K': 20.0, 'N': 20.0, 'T': 20.0},
            'tinggi_baris': <String, Object?>{},
            'merge': <String>[],
            'freeze': null,
            'kolom_tersembunyi': <String>[],
            'baris_tersembunyi': <int>[],
            'lebar_perkiraan': true,
          },
        ),
      ],
    },
    {
      'id': idHeightGauge,
      'nama': 'Master_olda_Height_Gauge_600_mm_2026',
      'kode_profil': null,
      'keluarga': null,
      'sumber': 'csv',
      'sha256':
          '4e7a2c9b1f6d3e8a5c2b7f4d1e9a6c3b8f5d2e7a4c1b9f6d3e8a5c2b7f4d1e9a',
      'ukuran': 9830,
      'jumlah_lembar': 1,
      'berkas_asli_tersimpan': false,
      'diimpor_pada': '2026-10-13T09:12:00+07:00',
      'kunci_jenis': 'tanpa-profil:height-gauge-600-mm',
      'aktif': true,
      'status': 'aktif',
      'versi': 1,
      'digantikan_oleh_id': null,
      'jumlah_riwayat': 0,
      'lembar': [
        // CSV dari server lama: tata letak kosong sama sekali.
        _lembar(
          id: idLembarInput,
          urutan: 1,
          nama: 'INPUT DATA',
          baris: 300,
          kolom: 26,
          sel: _selInput,
        ),
      ],
    },
  ];

  static Map<String, Object?> _s(
    String a,
    Object? nilai, {
    String? r,
    String? f,
    Map<String, Object?>? g,
  }) {
    final alamat = AlamatSel.urai(a)!;
    final angka = nilai is num;
    final kosong = nilai == null;
    return {
      'a': a,
      'b': alamat.baris,
      'k': alamat.kolom,
      't': r != null ? 'f' : (kosong ? 'kosong' : (angka ? 'n' : 's')),
      'n': angka ? nilai : null,
      's': kosong
          ? ''
          : (angka ? (f == null ? '$nilai' : _tampil(nilai, f)) : '$nilai'),
      'r': r,
      'f': f,
      'g': g,
    };
  }

  /// Teks tampil peraga untuk format `0.000…` — server yang membuat `s`
  /// sungguhan; di sini cuma supaya mock tampil seperti Excel.
  static String _tampil(num n, String f) {
    final m = RegExp(r'^0\.(0+)$').firstMatch(f);
    return m == null ? '$n' : n.toStringAsFixed(m.group(1)!.length);
  }

  static const _tipis = {
    'atas': 'thin',
    'kanan': 'thin',
    'bawah': 'thin',
    'kiri': 'thin',
  };
  static const _judul = {'tebal': true, 'isi': '#DDEBF7', 'ukuran': 14};
  static const _kepala = {
    'tebal': true,
    'isi': '#FFF2CC',
    'rata': 'center',
    'vertikal': 'center',
    'border': _tipis,
  };
  static const _tabel = {'border': _tipis};

  /// Anggota sel gabungan selain jangkarnya: kosong tapi BERGAYA, seperti
  /// yang ditulis Excel (`<c r="C4" s="5"/>`) — dari situ garis tepi
  /// gabungan yang utuh berasal.
  static List<Map<String, Object?>> _anggota(
    String rentang,
    Map<String, Object?> g,
  ) {
    final r = RentangSel.urai(rentang)!;
    return [
      for (var b = r.barisAwal; b <= r.barisAkhir; b++)
        for (var k = r.kolomAwal; k <= r.kolomAkhir; k++)
          if (b != r.barisAwal || k != r.kolomAwal)
            _s(AlamatSel(b, k).a1, null, g: g),
    ];
  }

  // `PERHITUNGAN U95%.csv` baris 1, 4, 6, 7, 8, 14–17 (Micrometer 0-25mm).
  static final List<Map<String, Object?>> _selU95 = [
    _s('A1', 'Budget Ketidakpastian Micrometer', g: _judul),
    _s('B4', 'Componen', g: _kepala),
    ..._anggota('B4:H4', _kepala),
    _s('I4', 'Satuan', g: _kepala),
    _s('K4', 'u', g: _kepala),
    _s('N4', 'Disivsor', g: _kepala),
    _s('Q4', 'vi', g: _kepala),
    _s('T4', 'ui', g: _kepala),
    _s('V4', 'ci', g: _kepala),
    _s('X4', 'uici', g: _kepala),
    _s('AA4', '(uici)2', g: _kepala),
    _s('AC4', '( uici )4/ vi', g: {..._kepala, 'bungkus': true}),
    _s('B6', 'Resolusi', g: _tabel),
    ..._anggota('B6:H6', _tabel),
    _s('I6', 'µm', g: _tabel),
    _s('K6', 0.127, f: '0.000', g: _tabel),
    _s('N6', 1.7320508075688772, r: '=SQRT(3)', f: '0.0000', g: _tabel),
    _s('Q6', 200, g: _tabel),
    _s('T6', 0.07332348418708248, r: '=K6/N6', f: '0.00000', g: _tabel),
    _s('V6', 1, g: _tabel),
    _s('X6', 0.07332348418708248, r: '=T6*V6', f: '0.00000', g: _tabel),
    _s('AA6', 0.0053763333333333345, r: '=X6^2', g: _tabel),
    _s('AC6', 1.4452480055555562e-07, r: '=AA6^2/Q6', g: _tabel),
    _s('B7', 'Standard balok ukur', g: _tabel),
    ..._anggota('B7:H7', _tabel),
    _s('I7', 'µm', g: _tabel),
    _s('K7', 0.18439088914585774, f: '0.000', g: _tabel),
    _s('N7', 2, g: _tabel),
    _s('Q7', 200, g: _tabel),
    _s('T7', 0.09219544457292887, r: '=K7/N7', f: '0.00000', g: _tabel),
    _s('V7', 1, g: _tabel),
    _s('X7', 0.09219544457292887, r: '=T7*V7', f: '0.00000', g: _tabel),
    _s('AA7', 0.0085, r: '=X7^2', g: _tabel),
    _s('AC7', 3.6125000000000004e-07, r: '=AA7^2/Q7', g: _tabel),
    _s('B8', 'Perubahan suhu terhadap suhu acuan 200c'),
    _s('I8', '/⁰C'),
    _s('K8', 0.6499999999999986, f: '0.000'),
    _s('N8', 1.7320508075688772, r: '=SQRT(3)', f: '0.0000'),
    _s('Q8', 200),
    _s('T8', 0.3752776749732559, r: '=K8/N8', f: '0.00000'),
    _s('V8', 6.0001600000000005e-05),
    _s('X8', 2.2517260942675316e-05, r: '=T8*V8'),
    _s('AA8', 5.070270403605312e-10, r: '=X8^2'),
    _s('AC8', 1.2853820982837989e-21, r: '=AA8^2/Q8'),
    _s('B14', 'Uc2 (hasil penjumlahan semua elemen pada kolom ui)'),
    _s('AA14', 0.14003804101934456, r: '=SUM(AA5:AA13)'),
    _s('AC14', 4.278844039227562e-05, r: '=SUM(AC5:AC13)'),
    _s('B15', 'Uc (akar kuadrat dari Uc2)'),
    _s('X15', 0.3742165696750273, r: '=SQRT(AA14)', f: '0.0000'),
    _s('AA15', 'Veff', g: {'rata': 'right'}),
    _s('AC15', 458.31660964384776, r: '=X15^4/AC14', f: '0.00'),
    _s('B16', 'k (Faktor cakupan)'),
    _s('X16', 1.9651570982780517, r: '=TINV(0.05,AC15)', f: '0.00'),
    _s('B17', 'U95 (Ketidakpastian Bentangan)', g: {'tebal': true}),
    _s(
      'X17',
      0.735394348190143,
      r: '=X16*X15',
      f: '0.000',
      g: {
        'tebal': true,
        'border': {'atas': 'thin', 'bawah': 'double'},
      },
    ),
    _s('AA17', 'µm'),
  ];

  // CSV dari lembar yang sama: nilai saja, tanpa rumus, format, & gaya.
  static final List<Map<String, Object?>> _selU95Csv = [
    for (final s in _selU95)
      if ((s['b'] as int) <= 7 && s['t'] != 'kosong')
        {
          ...s,
          't': s['n'] != null ? 'n' : 's',
          's': s['n'] != null ? '${s['n']}' : s['s'],
          'r': null,
          'f': null,
          'g': null,
        },
  ];

  // `Standar_GB.csv` baris 1–4 & 9–11 (Micrometer 0-25mm).
  static final List<Map<String, Object?>> _selStandar = [
    _s('A1', 'STANDAR GAUGE BLOCK', g: _judul),
    _s('A2', 'Name :'),
    _s('B2', 'Gauge block standard'),
    _s('A4', 'Merk'),
    _s('B4', 'Metrology'),
    _s('A9', 'Nomor Seri', g: _kepala),
    _s('B9', 'Nominal Gauge Block\n(mm)', g: {..._kepala, 'bungkus': true}),
    _s('C9', 'Koreksi (mm)', g: _kepala),
    _s('D9', 'Koreksi (µm)', g: _kepala),
    _s('E9', 'Nilai UUT(mm)', g: _kepala),
    _s('F9', 'Kerataan Permukaan (µm)', g: _kepala),
    _s('G9', 'U 95% (k=2) (µm)', g: _kepala),
    // Nomor seri berawalan nol: TEKS, bukan angka.
    _s('A11', '07427', g: _tabel),
    _s('B11', 1, g: _tabel),
    _s('C11', 0.00011, g: _tabel),
    _s('D11', 0.11, g: _tabel),
    _s('E11', 1.00011, g: _tabel),
    _s('F11', 0.03, g: _tabel),
    _s('G11', 0.12, g: _tabel),
  ];

  // `DATABASE.csv` baris 1–3: LABEL kepala kolom saja (K-49-12 menampilkan
  // isi lembar ini; data pelanggannya tidak disalin ke kode).
  static final List<Map<String, Object?>> _selDatabase = [
    _s('A1', ' COMMON DATA ', g: {'tebal': true}),
    _s('Q1', 'SPECIFIC DATA', g: {'tebal': true}),
    _s('AC1', 'Reminder Recalibration'),
    _s('AF1', 'TOTAL'),
    _s('AC2', 'Analog'),
    _s('AD2', 2),
    _s('AE2', 'year'),
    _s('AF2', 730),
    _s('R3', 'No'),
    _s('S3', 'Jenis/Rentang'),
    _s('T3', 'CMC (µm)'),
    _s('AC3', 'Digital'),
    _s('AD3', 1),
    _s('AE3', 'year'),
    _s('AF3', 365),
  ];

  // `INPUT DATA.csv` (Height Gauge 600 mm) — judul & identitas ALAT saja.
  static final List<Map<String, Object?>> _selInput = [
    _s('A1', 'PT. SIDIK'),
    _s('D1', 'KALIBRASI\nHEIGHT GAUGE'),
    _s('P1', 'LK-285-IDN'),
    _s('A3', 'Calibrator Standard Status Monitoring :'),
    _s('K3', 'ALL STANDARDS ARE VALID'),
    _s('B8', 'IDENTITAS ALAT'),
    _s('B10', 'Nama Alat'),
    _s('D10', ':'),
    _s('E10', 'Height Gauge'),
    _s('B11', 'Merk'),
    _s('D11', ':'),
    _s('E11', 'Insize'),
    _s('B12', 'Type'),
    _s('D12', ':'),
    _s('E12', 'Digital'),
  ];

  static final Map<int, List<Map<String, Object?>>> _sel = {
    idLembarU95: _selU95,
    idLembarStandar: _selStandar,
    idLembarDatabase: _selDatabase,
    idLembarInput: _selInput,
    idLembarU95Csv: _selU95Csv,
  };
}
