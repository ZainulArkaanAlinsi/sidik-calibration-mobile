import '../models/koreksi_pelanggan.dart' show FotoPelanggan;
import '../models/permintaan_pelanggan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Permintaan kalibrasi pelanggan, sisi LAB (`/api/permintaan-pelanggan`,
/// kontrak §3 `docs/perintah-frontend-permintaan.md` di repo API).
///
/// Pemilik pintunya **admin**: baca + terima/tolak/balas. Super admin hanya
/// membaca (tulis dijawab 403 sampai K4 turun); teknisi & viewer 403 di semua
/// rute. Menu & tombol sudah disembunyikan di layar; server tetap penjaganya.
abstract class PermintaanService {
  /// [status] `null` = semua. `status=baru` diurut paling lama menunggu di
  /// atas (server); selain itu terbaru di atas.
  Future<HalamanPermintaan> daftar(
    String token, {
    String? status,
    int? pelangganId,
    String? cari,
    int perPage = 50,
  });

  Future<PermintaanPelanggan> detail(String token, int id);

  /// Melempar [GalatPermintaan] untuk 422 — kunci `errors`-nya dipakai layar
  /// Terima untuk menandai alat mana yang bermasalah.
  Future<PermintaanPelanggan> terima(
    String token,
    int id, {
    DateTime? tanggalMasuk,
    DateTime? tanggalJanjiSelesai,
    String? catatan,
    List<LengkapiAlatBaru> alatBaru = const [],
  });

  /// [alasan] 5–1000 karakter, DIBACA PELANGGAN apa adanya.
  Future<PermintaanPelanggan> tolak(String token, int id, String alasan);

  Future<UtasPermintaan> pesan(String token, int id);

  Future<PesanPermintaan> kirimPesan(String token, int id, String isi);

  /// Jadwalkan teknisi untuk permintaan `diterima` + `diambil_lab`
  /// (`POST /permintaan-pelanggan/{id}/jadwal`, kontrak A5). [jadwalPada]
  /// dikirim sebagai cap waktu ISO-8601 Zulu. 422 → [GalatPermintaan].
  Future<PermintaanPelanggan> jadwalkan(
    String token,
    int id, {
    required DateTime jadwalPada,
    String? lokasi,
    String? catatan,
  });

  /// Tandai alat sudah tiba di lab (`POST …/alat-tiba`, tanpa badan). 422
  /// → [GalatPermintaan] kalau sudah ditandai / bukan `diterima`.
  Future<PermintaanPelanggan> alatTiba(String token, int id);
}

/// Cap waktu ISO-8601 Zulu tanpa pecahan detik (`2026-10-01T02:15:00Z`),
/// bentuk yang dipakai kontrak di semua cap waktu.
String capWaktuZulu(DateTime t) {
  final u = t.toUtc();
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${d2(u.month)}-${d2(u.day)}'
      'T${d2(u.hour)}:${d2(u.minute)}:${d2(u.second)}Z';
}

class ApiPermintaanService implements PermintaanService {
  ApiPermintaanService(this._api);

  final ApiClient _api;

  static String _tgl(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 422 jadi [GalatPermintaan] supaya layar bisa membaca `errors` per kunci;
  /// status lain (403/404/429) dilempar apa adanya dengan pesan server.
  Future<Map<String, dynamic>> _tulis(
    Future<Map<String, dynamic>> Function() kirim,
  ) async {
    try {
      return await kirim();
    } on ApiException catch (e) {
      if (e.status == 422) throw GalatPermintaan.dariBody(e.message, e.body);
      rethrow;
    }
  }

  @override
  Future<HalamanPermintaan> daftar(
    String token, {
    String? status,
    int? pelangganId,
    String? cari,
    int perPage = 50,
  }) async {
    final q = <String>[
      if (status != null && status.isNotEmpty)
        'status=${Uri.encodeQueryComponent(status)}',
      if (pelangganId != null) 'customer_id=$pelangganId',
      if (cari != null && cari.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(cari.trim())}',
      'per_page=$perPage',
    ];
    final json = await _api.get(
      '/permintaan-pelanggan?${q.join('&')}',
      token: token,
    );
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    return HalamanPermintaan(
      items: [
        for (final d in (json['data'] as List<dynamic>? ?? const []))
          if (d is Map<String, dynamic>) PermintaanPelanggan.fromJson(d),
      ],
      total: (meta['total'] as num?)?.toInt() ?? 0,
      jumlahBaru: (meta['jumlah_baru'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PermintaanPelanggan> detail(String token, int id) async {
    final json = await _api.get('/permintaan-pelanggan/$id', token: token);
    return PermintaanPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<PermintaanPelanggan> terima(
    String token,
    int id, {
    DateTime? tanggalMasuk,
    DateTime? tanggalJanjiSelesai,
    String? catatan,
    List<LengkapiAlatBaru> alatBaru = const [],
  }) async {
    final json = await _tulis(
      () => _api.post(
        '/permintaan-pelanggan/$id/terima',
        token: token,
        body: {
          if (tanggalMasuk != null) 'tanggal_masuk': _tgl(tanggalMasuk),
          if (tanggalJanjiSelesai != null)
            'tanggal_janji_selesai': _tgl(tanggalJanjiSelesai),
          if (catatan != null && catatan.trim().isNotEmpty)
            'catatan': catatan.trim(),
          if (alatBaru.isNotEmpty)
            'alat_baru': [for (final a in alatBaru) a.toJson()],
        },
      ),
    );
    return PermintaanPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<PermintaanPelanggan> tolak(String token, int id, String alasan) async {
    final json = await _tulis(
      () => _api.post(
        '/permintaan-pelanggan/$id/tolak',
        token: token,
        body: {'alasan': alasan.trim()},
      ),
    );
    return PermintaanPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<UtasPermintaan> pesan(String token, int id) async {
    final json = await _api.get(
      '/permintaan-pelanggan/$id/pesan?per_page=100',
      token: token,
    );
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    return UtasPermintaan(
      pesan: [
        for (final d in (json['data'] as List<dynamic>? ?? const []))
          if (d is Map<String, dynamic>) PesanPermintaan.fromJson(d),
      ],
      terbuka: meta['percakapan_terbuka'] != false,
    );
  }

  @override
  Future<PesanPermintaan> kirimPesan(String token, int id, String isi) async {
    final json = await _tulis(
      () => _api.post(
        '/permintaan-pelanggan/$id/pesan',
        token: token,
        body: {'isi': isi.trim()},
      ),
    );
    return PesanPermintaan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<PermintaanPelanggan> jadwalkan(
    String token,
    int id, {
    required DateTime jadwalPada,
    String? lokasi,
    String? catatan,
  }) async {
    final json = await _tulis(
      () => _api.post(
        '/permintaan-pelanggan/$id/jadwal',
        token: token,
        body: {
          'jadwal_pada': capWaktuZulu(jadwalPada),
          if (lokasi != null && lokasi.trim().isNotEmpty)
            'lokasi': lokasi.trim(),
          if (catatan != null && catatan.trim().isNotEmpty)
            'catatan': catatan.trim(),
        },
      ),
    );
    return PermintaanPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<PermintaanPelanggan> alatTiba(String token, int id) async {
    final json = await _tulis(
      () => _api.post('/permintaan-pelanggan/$id/alat-tiba', token: token),
    );
    return PermintaanPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }
}

/// Mock untuk `--dart-define=USE_MOCK=true` & test widget.
///
/// [serialBentrok] meniru 422 "nomor seri sudah dipakai alat lain di lab ini"
/// (kontrak §3.3): nomor seri yang ada di himpunan ini ditolak.
class MockPermintaanService implements PermintaanService {
  MockPermintaanService({
    List<PermintaanPelanggan>? awal,
    Map<int, List<PesanPermintaan>>? pesan,
    this.serialBentrok = const {'BENTROK-01'},
    this.gagal = false,
  }) : _data = List.of(awal ?? contoh),
       _pesan = {
         for (final e in (pesan ?? contohPesan).entries) e.key: [...e.value],
       };

  final Set<String> serialBentrok;
  final bool gagal;
  final List<PermintaanPelanggan> _data;
  final Map<int, List<PesanPermintaan>> _pesan;

  /// Nomor seri & permintaan terakhir yang diterima, untuk diperiksa test.
  final List<List<LengkapiAlatBaru>> diterimaDengan = [];
  final List<String> ditolakDengan = [];

  static final contoh = <PermintaanPelanggan>[
    PermintaanPelanggan(
      id: 12,
      nomor: 'PMT/2026/09/0012',
      status: StatusPermintaan.baru,
      pelangganId: 7,
      pelangganNama: 'PT Tirta Mandiri Laboratorium',
      pemohonNama: 'Budi Santoso',
      pemohonEmail: 'budi@tirtamandiri.co.id',
      pemohonTelepon: '+62 812 0000 1234',
      metode: MetodePengantaran.diantarSendiri,
      tanggalDari: DateTime(2026, 10, 5),
      tanggalSampai: DateTime(2026, 10, 9),
      catatan: 'Tolong diprioritaskan.',
      jumlahAlat: 2,
      jumlahPesan: 2,
      dibuatPada: DateTime(2026, 9, 28, 9, 11),
      alat: const [
        AlatPermintaan(
          id: 31,
          equipmentId: 88,
          baru: false,
          namaAlat: 'Timbangan Ohaus PX224',
          merk: 'Ohaus',
          model: 'PX224',
          serialNumber: 'C3349',
        ),
        AlatPermintaan(
          id: 32,
          baru: true,
          namaAlat: 'pH Meter',
          merk: 'Hanna',
          model: 'HI2211',
          noIdentifikasi: 'QC-07',
          rentangMin: 0,
          rentangMaks: 14,
          satuan: 'pH',
          resolusi: 0.01,
          lokasi: 'Lab QC Lantai 2',
          catatan: 'Elektroda diganti Agustus 2026.',
          perluKategori: true,
          perluNomorSeri: true,
        ),
      ],
    ),
    PermintaanPelanggan(
      id: 13,
      nomor: 'PMT/2026/09/0013',
      status: StatusPermintaan.baru,
      pelangganId: 9,
      pelangganNama: 'CV Anugerah Kimia Utama',
      pemohonNama: 'Sari Dewi',
      pemohonEmail: 'sari@anugerahkimia.co.id',
      metode: MetodePengantaran.diambilLab,
      jumlahAlat: 1,
      dibuatPada: DateTime(2026, 9, 30, 14, 2),
      alat: const [
        AlatPermintaan(
          id: 41,
          equipmentId: 91,
          baru: false,
          namaAlat: 'Jangka Sorong Mitutoyo',
          merk: 'Mitutoyo',
          serialNumber: 'MT-500-196-30',
        ),
      ],
    ),
    PermintaanPelanggan(
      id: 9,
      nomor: 'PMT/2026/09/0009',
      status: StatusPermintaan.diterima,
      pelangganId: 7,
      pelangganNama: 'PT Tirta Mandiri Laboratorium',
      pemohonNama: 'Budi Santoso',
      metode: MetodePengantaran.diantarSendiri,
      orderId: 55,
      orderNomor: 'ORD/2026/09/0055',
      diputuskanOleh: 'Hendra Wijaya',
      diputuskanPada: DateTime(2026, 9, 24, 10),
      jumlahAlat: 1,
      dibuatPada: DateTime(2026, 9, 23, 8, 30),
      alat: const [
        AlatPermintaan(
          id: 21,
          equipmentId: 88,
          baru: false,
          namaAlat: 'Timbangan Ohaus PX224',
          serialNumber: 'C3349',
        ),
      ],
    ),
    PermintaanPelanggan(
      id: 8,
      nomor: 'PMT/2026/09/0008',
      status: StatusPermintaan.ditolak,
      pelangganId: 9,
      pelangganNama: 'CV Anugerah Kimia Utama',
      pemohonNama: 'Sari Dewi',
      metode: MetodePengantaran.diambilLab,
      alasanPenolakan: 'Nomor seri alat sudah terdaftar atas perusahaan lain.',
      diputuskanOleh: 'Hendra Wijaya',
      diputuskanPada: DateTime(2026, 9, 22, 16),
      jumlahAlat: 1,
      dibuatPada: DateTime(2026, 9, 22, 9),
      alat: const [
        AlatPermintaan(
          id: 11,
          baru: true,
          namaAlat: 'Termometer Digital',
          serialNumber: 'TD-77',
        ),
      ],
    ),
  ];

  static final contohPesan = <int, List<PesanPermintaan>>{
    12: [
      PesanPermintaan(
        id: 5,
        dariLab: false,
        namaPengirim: 'Budi Santoso',
        isi: 'Apakah pH meter bisa dikalibrasi di tempat kami?',
        dibuatPada: DateTime(2026, 9, 28, 9, 20),
      ),
      PesanPermintaan(
        id: 6,
        dariLab: true,
        namaPengirim: 'Sari (admin)',
        isi: 'Bisa, tapi mohon dibawa ke lab ya pak.',
        dibuatPada: DateTime(2026, 9, 28, 10),
      ),
    ],
  };

  /// Permintaan yang sudah diterima dengan perjalanan alatnya (kontrak A5).
  /// Tidak ikut [contoh] supaya hitungan tab & golden lama tidak bergeser;
  /// dipakai lewat `MockPermintaanService(awal: contohPerjalanan)`.
  ///
  /// #14 diantar sendiri (resi + foto pelat nama), #15 diambil lab (belum
  /// dijadwalkan), #16 diambil lab yang sudah dijadwalkan.
  static final contohPerjalanan = <PermintaanPelanggan>[
    PermintaanPelanggan(
      id: 14,
      nomor: 'PMT/2026/09/0014',
      status: StatusPermintaan.diterima,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      pemohonNama: 'Budi',
      metode: MetodePengantaran.diantarSendiri,
      orderId: 56,
      orderNomor: 'ORD/2026/09/0056',
      diputuskanOleh: 'Hendra Wijaya',
      diputuskanPada: DateTime.utc(2026, 9, 29, 3),
      jumlahAlat: 2,
      dibuatPada: DateTime.utc(2026, 9, 28, 2),
      tahap: TahapPermintaan.dalamPengiriman,
      tahapLabel: 'Alat dalam pengiriman',
      resi: ResiPermintaan(
        kurir: 'JNE',
        nomor: 'JNE0012345678',
        diisiPada: DateTime.utc(2026, 9, 30, 5),
      ),
      progres: const ProgresPermintaan(selesai: 0, total: 2),
      alat: const [
        AlatPermintaan(
          id: 61,
          equipmentId: 88,
          baru: false,
          namaAlat: 'Timbangan Ohaus PX224',
          merk: 'Ohaus',
          serialNumber: 'C3349',
        ),
        AlatPermintaan(
          id: 62,
          baru: true,
          namaAlat: 'pH Meter',
          merk: 'Hanna',
          model: 'HI2211',
          serialNumber: 'HI2211-0419',
          foto: [FotoPelanggan(id: 5), FotoPelanggan(id: 6)],
        ),
      ],
    ),
    PermintaanPelanggan(
      id: 15,
      nomor: 'PMT/2026/09/0015',
      status: StatusPermintaan.diterima,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      pemohonNama: 'Sari',
      metode: MetodePengantaran.diambilLab,
      orderId: 57,
      orderNomor: 'ORD/2026/09/0057',
      jumlahAlat: 1,
      dibuatPada: DateTime.utc(2026, 9, 29, 2),
      tahap: TahapPermintaan.menungguJadwal,
      tahapLabel: 'Menunggu jadwal teknisi',
      progres: const ProgresPermintaan(selesai: 0, total: 1),
      alat: const [
        AlatPermintaan(
          id: 71,
          equipmentId: 91,
          baru: false,
          namaAlat: 'Jangka Sorong Mitutoyo',
          serialNumber: 'MT-500-196-30',
        ),
      ],
    ),
    PermintaanPelanggan(
      id: 16,
      nomor: 'PMT/2026/09/0016',
      status: StatusPermintaan.diterima,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      pemohonNama: 'Sari',
      metode: MetodePengantaran.diambilLab,
      orderId: 58,
      orderNomor: 'ORD/2026/09/0058',
      jumlahAlat: 3,
      dibuatPada: DateTime.utc(2026, 9, 27, 2),
      tahap: TahapPermintaan.teknisiDijadwalkan,
      tahapLabel: 'Teknisi dijadwalkan',
      jadwal: JadwalPermintaan(
        pada: DateTime.utc(2026, 10, 5, 2),
        lokasi: 'Gudang QC, Jl. Contoh Raya 10, Bandung',
        catatan: 'Bawa dokumen serah terima.',
      ),
      progres: const ProgresPermintaan(selesai: 1, total: 3),
      alat: const [
        AlatPermintaan(
          id: 81,
          equipmentId: 92,
          baru: false,
          namaAlat: 'Termometer Digital',
          serialNumber: 'TD-77',
        ),
      ],
    ),
  ];

  /// Isi terakhir yang dikirim ke `jadwalkan`, untuk diperiksa test.
  final List<({int id, DateTime jadwalPada, String? lokasi, String? catatan})>
  dijadwalkanDengan = [];
  final List<int> alatTibaDitandai = [];

  @override
  Future<PermintaanPelanggan> jadwalkan(
    String token,
    int id, {
    required DateTime jadwalPada,
    String? lokasi,
    String? catatan,
  }) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    if (!p.bisaDijadwalkan) {
      throw const GalatPermintaan(
        'Permintaan ini tidak bisa dijadwalkan.',
        errors: {
          'status': ['Hanya permintaan diterima yang diambil lab.'],
        },
      );
    }
    dijadwalkanDengan.add((
      id: id,
      jadwalPada: jadwalPada,
      lokasi: lokasi,
      catatan: catatan,
    ));
    final baru = p.salin(
      jadwal: JadwalPermintaan(
        pada: jadwalPada.toUtc(),
        lokasi: lokasi,
        catatan: catatan,
      ),
      tahap: TahapPermintaan.teknisiDijadwalkan,
      tahapLabel: 'Teknisi dijadwalkan',
    );
    _data[_data.indexOf(p)] = baru;
    return baru;
  }

  @override
  Future<PermintaanPelanggan> alatTiba(String token, int id) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    if (!p.bisaDitandaiTiba) {
      throw const GalatPermintaan(
        'Alat sudah ditandai tiba.',
        errors: {
          'status': ['Alat sudah ditandai tiba.'],
        },
      );
    }
    alatTibaDitandai.add(id);
    final baru = p.salin(
      alatTibaPada: DateTime.utc(2026, 10, 1, 3),
      tahap: TahapPermintaan.alatDiLab,
      tahapLabel: 'Alat di lab',
    );
    _data[_data.indexOf(p)] = baru;
    return baru;
  }

  void _cekGagal() {
    if (gagal) throw Exception('server nggak nyaut');
  }

  int _indeks(int id) {
    final i = _data.indexWhere((p) => p.id == id);
    if (i == -1) throw const AuthException('Data nggak ketemu.');
    return i;
  }

  @override
  Future<HalamanPermintaan> daftar(
    String token, {
    String? status,
    int? pelangganId,
    String? cari,
    int perPage = 50,
  }) async {
    _cekGagal();
    final q = cari?.trim().toLowerCase() ?? '';
    final hasil = [
      for (final p in _data)
        if ((status == null || status.isEmpty || p.status.kode == status) &&
            (pelangganId == null || p.pelangganId == pelangganId) &&
            (q.isEmpty ||
                p.nomor.toLowerCase().contains(q) ||
                (p.pelangganNama ?? '').toLowerCase().contains(q)))
          p,
    ];
    return HalamanPermintaan(
      items: hasil,
      total: hasil.length,
      jumlahBaru: _data.where((p) => p.status == StatusPermintaan.baru).length,
    );
  }

  @override
  Future<PermintaanPelanggan> detail(String token, int id) async {
    _cekGagal();
    return _data[_indeks(id)];
  }

  @override
  Future<PermintaanPelanggan> terima(
    String token,
    int id, {
    DateTime? tanggalMasuk,
    DateTime? tanggalJanjiSelesai,
    String? catatan,
    List<LengkapiAlatBaru> alatBaru = const [],
  }) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    if (p.status != StatusPermintaan.baru) {
      throw GalatPermintaan(
        'Permintaan ini sudah diputuskan.',
        errors: {
          'status': [
            'Permintaan ini tidak bisa diputuskan: statusnya sudah '
                '"${p.status.kode}".',
          ],
        },
      );
    }

    final errors = <String, List<String>>{};
    for (final a in p.alat.where((a) => a.baru)) {
      final isi = alatBaru.where((e) => e.itemId == a.id).firstOrNull;
      final serial = (isi?.serialNumber?.trim().isNotEmpty ?? false)
          ? isi!.serialNumber!.trim()
          : a.serialNumber;
      if (isi == null && a.perluKategori) {
        errors['alat_baru.${a.id}.equipment_category_id'] = [
          'Kategori wajib dipilih.',
        ];
      }
      if (a.perluNomorSeri && (serial == null || serial.isEmpty)) {
        errors['alat_baru.${a.id}.serial_number'] = ['Nomor seri wajib diisi.'];
      } else if (serial != null && serialBentrok.contains(serial)) {
        errors['alat_baru.${a.id}.serial_number'] = [
          'Nomor seri sudah dipakai alat lain di lab ini.',
        ];
      }
    }
    if (errors.isNotEmpty) {
      throw GalatPermintaan('Data yang dikirim nggak valid.', errors: errors);
    }

    diterimaDengan.add(alatBaru);
    final baru = PermintaanPelanggan(
      id: p.id,
      nomor: p.nomor,
      status: StatusPermintaan.diterima,
      pelangganId: p.pelangganId,
      pelangganNama: p.pelangganNama,
      pemohonNama: p.pemohonNama,
      pemohonEmail: p.pemohonEmail,
      pemohonTelepon: p.pemohonTelepon,
      metode: p.metode,
      tanggalDari: p.tanggalDari,
      tanggalSampai: p.tanggalSampai,
      catatan: p.catatan,
      orderId: 900 + p.id,
      orderNomor: 'ORD/2026/10/0${900 + p.id}',
      jumlahAlat: p.jumlahAlat,
      jumlahPesan: p.jumlahPesan,
      alat: p.alat,
      dibuatPada: p.dibuatPada,
    );
    _data[_data.indexOf(p)] = baru;
    return baru;
  }

  @override
  Future<PermintaanPelanggan> tolak(String token, int id, String alasan) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    if (alasan.trim().length < 5) {
      throw const GalatPermintaan(
        'Data yang dikirim nggak valid.',
        errors: {
          'alasan': ['Alasan minimal 5 karakter.'],
        },
      );
    }
    ditolakDengan.add(alasan.trim());
    final baru = PermintaanPelanggan(
      id: p.id,
      nomor: p.nomor,
      status: StatusPermintaan.ditolak,
      pelangganId: p.pelangganId,
      pelangganNama: p.pelangganNama,
      pemohonNama: p.pemohonNama,
      metode: p.metode,
      alasanPenolakan: alasan.trim(),
      jumlahAlat: p.jumlahAlat,
      jumlahPesan: p.jumlahPesan,
      alat: p.alat,
      dibuatPada: p.dibuatPada,
    );
    _data[_data.indexOf(p)] = baru;
    return baru;
  }

  @override
  Future<UtasPermintaan> pesan(String token, int id) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    return UtasPermintaan(
      pesan: List.of(_pesan[id] ?? const []),
      terbuka:
          p.status == StatusPermintaan.baru ||
          p.status == StatusPermintaan.diterima,
    );
  }

  @override
  Future<PesanPermintaan> kirimPesan(String token, int id, String isi) async {
    _cekGagal();
    final p = _data[_indeks(id)];
    if (p.status == StatusPermintaan.ditolak ||
        p.status == StatusPermintaan.dibatalkan) {
      throw const GalatPermintaan(
        'Percakapan ini sudah ditutup.',
        errors: {
          'isi': ['Percakapan ini sudah ditutup karena permintaannya ditolak.'],
        },
      );
    }
    final baru = PesanPermintaan(
      id: 100 + (_pesan[id]?.length ?? 0),
      dariLab: true,
      namaPengirim: 'Saya (admin)',
      isi: isi.trim(),
      dibuatPada: DateTime(2026, 10, 1, 9),
    );
    (_pesan[id] ??= []).add(baru);
    return baru;
  }
}
