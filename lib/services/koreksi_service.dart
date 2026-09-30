import 'dart:convert';
import 'dart:typed_data';

import '../models/koreksi_pelanggan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Koreksi dari pelanggan, sisi LAB (`/api/koreksi-pelanggan`, kontrak A4
/// `docs/perintah-frontend-revisi-koreksi.md` di repo API).
///
/// Pemilik pintunya **admin**: baca + terima/tolak. Super admin hanya membaca
/// (tulis dijawab 403); teknisi & viewer 403 di semua rute. Menu & tombol sudah
/// disembunyikan di layar; server tetap penjaganya.
abstract class KoreksiService {
  /// [status] salah satu `menunggu|diterima|ditolak|semua` (bawaan server:
  /// `menunggu`).
  Future<HalamanKoreksi> daftar(
    String token, {
    String status = SaringanKoreksi.menunggu,
    int perPage = 20,
  });

  Future<Koreksi> detail(String token, int id);

  /// [perubahan] (opsional) menimpa nilai yang diminta pelanggan — hanya kunci
  /// yang ada di koreksi itu. [alasan] hanya bermakna untuk jenis sertifikat
  /// (alasan revisi; bawaan server "Koreksi dari pelanggan #id").
  ///
  /// Melempar [GalatAksi] untuk 422.
  Future<Koreksi> terima(
    String token,
    int id, {
    String? tanggapan,
    Map<String, String>? perubahan,
    String? alasan,
  });

  /// [tanggapan] wajib, DIBACA PELANGGAN apa adanya.
  Future<Koreksi> tolak(String token, int id, String tanggapan);

  /// Byte gambar `GET /foto-pelanggan/{id}` — lewat header yang sama seperti
  /// panggilan API lain (bukan URL publik). `null` = 404.
  Future<Uint8List?> foto(String token, int id);
}

class ApiKoreksiService implements KoreksiService {
  ApiKoreksiService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> _tulis(
    Future<Map<String, dynamic>> Function() kirim,
  ) async {
    try {
      return await kirim();
    } on ApiException catch (e) {
      if (e.status == 422) throw GalatAksi.dariBody(e.message, e.body);
      rethrow;
    }
  }

  @override
  Future<HalamanKoreksi> daftar(
    String token, {
    String status = SaringanKoreksi.menunggu,
    int perPage = 20,
  }) async {
    final json = await _api.get(
      '/koreksi-pelanggan?status=${Uri.encodeQueryComponent(status)}'
      '&per_page=$perPage',
      token: token,
    );
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    final jumlah = meta['jumlah'];
    return HalamanKoreksi(
      items: [
        for (final d in (json['data'] as List<dynamic>? ?? const []))
          if (d is Map<String, dynamic>) Koreksi.fromJson(d),
      ],
      total: (meta['total'] as num?)?.toInt() ?? 0,
      jumlahMenunggu: jumlah is Map
          ? (jumlah['menunggu'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  @override
  Future<Koreksi> detail(String token, int id) async {
    final json = await _api.get('/koreksi-pelanggan/$id', token: token);
    return Koreksi.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Koreksi> terima(
    String token,
    int id, {
    String? tanggapan,
    Map<String, String>? perubahan,
    String? alasan,
  }) async {
    final json = await _tulis(
      () => _api.post(
        '/koreksi-pelanggan/$id/terima',
        token: token,
        body: {
          if (tanggapan != null && tanggapan.trim().isNotEmpty)
            'tanggapan': tanggapan.trim(),
          if (perubahan != null && perubahan.isNotEmpty) 'perubahan': perubahan,
          if (alasan != null && alasan.trim().isNotEmpty)
            'alasan': alasan.trim(),
        },
      ),
    );
    return Koreksi.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Koreksi> tolak(String token, int id, String tanggapan) async {
    final json = await _tulis(
      () => _api.post(
        '/koreksi-pelanggan/$id/tolak',
        token: token,
        body: {'tanggapan': tanggapan.trim()},
      ),
    );
    return Koreksi.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Uint8List?> foto(String token, int id) =>
      _api.ambilBytes('/foto-pelanggan/$id', token: token);
}

/// Mock untuk `--dart-define=USE_MOCK=true` & test widget. Data sintetis.
///
/// [serialBentrok] meniru 422 "nomor seri sudah dipakai alat lain"
/// (`errors["perubahan.serial_number"]`).
class MockKoreksiService implements KoreksiService {
  MockKoreksiService({
    List<Koreksi>? awal,
    this.serialBentrok = const {'BENTROK-01'},
    this.gagal = false,
  }) : _data = List.of(awal ?? contoh);

  final Set<String> serialBentrok;
  final bool gagal;
  final List<Koreksi> _data;

  /// Isi terakhir yang dikirim, untuk diperiksa test.
  final List<({int id, String? tanggapan, Map<String, String>? perubahan})>
  diterimaDengan = [];
  final List<({int id, String tanggapan})> ditolakDengan = [];

  static final contoh = <Koreksi>[
    Koreksi(
      id: 7,
      jenis: JenisKoreksi.alat,
      status: StatusKoreksi.menunggu,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      diajukanOleh: 'Budi',
      diajukanPada: DateTime.utc(2026, 10, 1, 2, 15),
      alatId: 12,
      alatNama: 'pH Meter',
      alatSerial: 'HI2211-0491',
      perubahan: const [
        PerubahanKoreksi(
          field: 'serial_number',
          label: 'Nomor seri',
          lama: 'HI2211-0491',
          baru: 'HI2211-0419',
        ),
      ],
      catatan: 'Nomor seri tertukar dua digit.',
      foto: const [FotoPelanggan(id: 5), FotoPelanggan(id: 6)],
    ),
    Koreksi(
      id: 8,
      jenis: JenisKoreksi.sertifikat,
      status: StatusKoreksi.menunggu,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      diajukanOleh: 'Budi',
      diajukanPada: DateTime.utc(2026, 9, 30, 8),
      alatId: 12,
      alatNama: 'pH Meter',
      alatSerial: 'HI2211-0419',
      sertifikatId: 41,
      sertifikatNomor: 'CAL/2026/09/0011',
      perubahan: const [
        PerubahanKoreksi(
          field: 'alamat',
          label: 'Alamat',
          lama: 'Jl. Contoh 1, Bandung',
          baru: 'Jl. Contoh Raya 10, Bandung',
        ),
        PerubahanKoreksi(
          field: 'nomor_seri',
          label: 'Nomor seri',
          lama: 'HI2211-0491',
          baru: 'HI2211-0419',
        ),
      ],
    ),
    Koreksi(
      id: 5,
      jenis: JenisKoreksi.alat,
      status: StatusKoreksi.diterima,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      diajukanOleh: 'Sari',
      diajukanPada: DateTime.utc(2026, 9, 25, 4),
      alatId: 15,
      alatNama: 'Timbangan Analitik',
      alatSerial: 'TA-778',
      perubahan: const [
        PerubahanKoreksi(
          field: 'merk',
          label: 'Merek',
          lama: 'Ohous',
          baru: 'Ohaus',
        ),
      ],
      tanggapan: 'Sudah kami perbaiki.',
      ditinjauOleh: 'Hendra Wijaya',
      ditinjauPada: DateTime.utc(2026, 9, 26, 3),
    ),
    Koreksi(
      id: 4,
      jenis: JenisKoreksi.sertifikat,
      status: StatusKoreksi.diterima,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      diajukanOleh: 'Budi',
      diajukanPada: DateTime.utc(2026, 9, 20, 4),
      alatId: 15,
      alatNama: 'Timbangan Analitik',
      alatSerial: 'TA-778',
      sertifikatId: 30,
      sertifikatNomor: 'CAL/2026/09/0007',
      perubahan: const [
        PerubahanKoreksi(
          field: 'pemilik',
          label: 'Pemilik',
          lama: 'PT Contoh Jay',
          baru: 'PT Contoh Jaya',
        ),
      ],
      tanggapan: 'Revisi sertifikat sudah diterbitkan.',
      ditinjauOleh: 'Hendra Wijaya',
      ditinjauPada: DateTime.utc(2026, 9, 21, 3),
      revisi: const RevisiKoreksi(
        id: 44,
        nomor: 'CAL/2026/09/0007-R1',
        status: 'terbit',
      ),
    ),
    Koreksi(
      id: 3,
      jenis: JenisKoreksi.alat,
      status: StatusKoreksi.ditolak,
      pelangganId: 3,
      pelangganNama: 'PT Contoh Jaya',
      diajukanOleh: 'Sari',
      diajukanPada: DateTime.utc(2026, 9, 18, 4),
      alatId: 12,
      alatNama: 'pH Meter',
      alatSerial: 'HI2211-0419',
      perubahan: const [
        PerubahanKoreksi(
          field: 'range_max',
          label: 'Rentang maks',
          lama: '14',
          baru: '20',
        ),
      ],
      tanggapan: 'Rentang mengikuti spesifikasi pabrik, tidak bisa diubah.',
      ditinjauOleh: 'Hendra Wijaya',
      ditinjauPada: DateTime.utc(2026, 9, 19, 3),
    ),
  ];

  /// PNG 8x8 abu-abu biru — cukup untuk thumbnail di test.
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGOYtmA9VsQwtCQAWkl5QR9f8d0AAAAASUVORK5CYII=',
  );

  /// Byte gambar yang dijawab [foto] — dibuka supaya golden bisa
  /// men-precache-nya (decode gambar jalan di antrean async yang di-pause di
  /// widget test; tanpa precache thumbnail kosong di golden pertama yang
  /// memakainya dan terisi di golden berikutnya, tergantung urutan).
  static Uint8List get pngContoh => _png;

  void _cekGagal() {
    if (gagal) throw Exception('server nggak nyaut');
  }

  int _indeks(int id) {
    final i = _data.indexWhere((k) => k.id == id);
    if (i == -1) throw const AuthException('Data nggak ketemu.');
    return i;
  }

  @override
  Future<HalamanKoreksi> daftar(
    String token, {
    String status = SaringanKoreksi.menunggu,
    int perPage = 20,
  }) async {
    _cekGagal();
    final hasil = [
      for (final k in _data)
        if (status == SaringanKoreksi.semua || k.status.kode == status) k,
    ];
    return HalamanKoreksi(
      items: hasil,
      total: hasil.length,
      jumlahMenunggu: _data
          .where((k) => k.status == StatusKoreksi.menunggu)
          .length,
    );
  }

  @override
  Future<Koreksi> detail(String token, int id) async {
    _cekGagal();
    return _data[_indeks(id)];
  }

  @override
  Future<Koreksi> terima(
    String token,
    int id, {
    String? tanggapan,
    Map<String, String>? perubahan,
    String? alasan,
  }) async {
    _cekGagal();
    final k = _data[_indeks(id)];
    if (!k.status.bisaDiputuskan) {
      throw const GalatAksi('Koreksi ini sudah diputuskan.');
    }

    final errors = <String, List<String>>{};
    for (final e in (perubahan ?? const <String, String>{}).entries) {
      if (!k.perubahan.any((p) => p.field == e.key)) {
        errors['perubahan.${e.key}'] = ['Kunci ini tidak ada di koreksi.'];
      } else if (e.key == 'serial_number' && serialBentrok.contains(e.value)) {
        errors['perubahan.serial_number'] = [
          'Nomor seri sudah dipakai alat lain di lab ini.',
        ];
      }
    }
    if (errors.isNotEmpty) {
      throw GalatAksi('Data yang dikirim nggak valid.', errors: errors);
    }

    diterimaDengan.add((id: id, tanggapan: tanggapan, perubahan: perubahan));
    final baru = k.salin(
      status: StatusKoreksi.diterima,
      tanggapan: tanggapan,
      ditinjauOleh: 'Saya (admin)',
      ditinjauPada: DateTime.utc(2026, 10, 1, 4),
      perubahan: [
        for (final p in k.perubahan)
          PerubahanKoreksi(
            field: p.field,
            label: p.label,
            lama: p.lama,
            baru: perubahan?[p.field] ?? p.baru,
          ),
      ],
      revisi: k.jenis == JenisKoreksi.sertifikat
          ? RevisiKoreksi(
              id: 1000 + id,
              nomor: '${k.sertifikatNomor}-R1',
              status: 'menunggu_generate',
            )
          : null,
    );
    _data[_data.indexOf(k)] = baru;
    return baru;
  }

  @override
  Future<Koreksi> tolak(String token, int id, String tanggapan) async {
    _cekGagal();
    final k = _data[_indeks(id)];
    if (tanggapan.trim().isEmpty) {
      throw const GalatAksi(
        'Data yang dikirim nggak valid.',
        errors: {
          'tanggapan': ['Tanggapan wajib diisi.'],
        },
      );
    }
    ditolakDengan.add((id: id, tanggapan: tanggapan.trim()));
    final baru = k.salin(
      status: StatusKoreksi.ditolak,
      tanggapan: tanggapan.trim(),
      ditinjauOleh: 'Saya (admin)',
      ditinjauPada: DateTime.utc(2026, 10, 1, 4),
    );
    _data[_data.indexOf(k)] = baru;
    return baru;
  }

  @override
  Future<Uint8List?> foto(String token, int id) async {
    _cekGagal();
    return _png;
  }
}
