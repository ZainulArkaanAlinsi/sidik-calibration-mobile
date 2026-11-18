import '../models/anggota_pelanggan.dart';
import '../models/customer.dart';
import '../models/pindah_alat.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'pengguna_sa_service.dart' show HalamanHasil;

/// Keanggotaan pelanggan di sisi LAB (kontrak
/// `docs/perintah-frontend-super-admin.md` §3).
///
/// Mengundang anggota TIDAK ada di sini: itu tetap `UndanganPelangganService`
/// (+ dialognya) yang sudah ada.
///
/// Tidak ada `organization_id` / `customer_id` di body mana pun — path hanya
/// menunjuk baris, organisasi dari token. Data milik lab lain dijawab 404 dan
/// diteruskan apa adanya sebagai `ApiException`.
abstract class AnggotaPelangganService {
  /// `GET /customers?search=&page=` — paginasi 15.
  Future<HalamanHasil<Customer>> daftarPelanggan(
    String token, {
    String? cari,
    int halaman = 1,
  });

  /// `GET /customers/{customer}` — satu pelanggan LENGKAP dengan hitungan
  /// dan penanda server (kontrak §3.6): dipakai detail untuk menyegarkan
  /// ringkasan sesudah undang / pindah alat.
  Future<Customer> detailPelanggan(String token, int customerId);

  /// `POST /customers/{customer}/pindahkan-alat` dengan `dry_run: true` —
  /// pratinjau yang TIDAK menulis apa pun. [customerId] = PT asal.
  Future<PratinjauPindahAlat> pratinjauPindahAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
  });

  /// Eksekusi pindah alat. [alasan] WAJIB 3-500 karakter (ucapan orang yang
  /// menekan, tidak diisi otomatis); `konfirmasi: true` dikirim di sini.
  /// Galat `kode`: `alat_sudah_pindah` (409), `alat_bukan_milik_pt_asal`,
  /// `pt_tujuan_sama`, `konfirmasi_wajib`.
  Future<HasilPindahAlat> pindahkanAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
    required String alasan,
  });

  /// `GET /customers/{customer}/anggota` — anggota + undangan menunggu + PIC
  /// admin. Tanpa paginasi.
  Future<DataAnggotaPelanggan> ambil(String token, int customerId);

  /// `POST /customers/{customer}/anggota/{anggota}/nonaktifkan`. [alasan]
  /// WAJIB 3–500 karakter dan dikirim apa adanya ke jejak audit: jangan
  /// diisi otomatis. Galat `kode`: `pic_utama_terakhir`, `sudah_nonaktif`.
  Future<AnggotaPelanggan> cabut(
    String token,
    int customerId,
    int anggotaId, {
    required String alasan,
  });

  /// `DELETE /customers/{customer}/undangan/{undangan}`.
  Future<void> batalkanUndangan(String token, int customerId, int undanganId);

  /// `PATCH /customers/{customer}/pic-admin` — [userId] admin aktif lab ini,
  /// atau `null` untuk melepas PIC admin (notifikasi kembali ke semua admin).
  Future<void> setPicAdmin(String token, int customerId, int? userId);
}

class ApiAnggotaPelangganService implements AnggotaPelangganService {
  ApiAnggotaPelangganService(this._api);

  final ApiClient _api;

  @override
  Future<HalamanHasil<Customer>> daftarPelanggan(
    String token, {
    String? cari,
    int halaman = 1,
  }) async {
    final query = <String, String>{
      if (cari != null && cari.trim().isNotEmpty) 'search': cari.trim(),
      if (halaman > 1) 'page': '$halaman',
    };
    final qs = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final json = await _api.get('/customers$qs', token: token);
    final data = json['data'];
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);

    return HalamanHasil(
      items: [
        if (data is List)
          for (final e in data)
            if (e is Map) Customer.fromJson(Map<String, dynamic>.from(e)),
      ],
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<Customer> detailPelanggan(String token, int customerId) async {
    final json = await _api.get('/customers/$customerId', token: token);
    return Customer.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<PratinjauPindahAlat> pratinjauPindahAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
  }) async {
    // Pratinjau tidak menulis apa pun, tetapi tetap POST: tidak diulang
    // otomatis oleh ApiClient (tanpa `client_request_id`).
    final json = await _api.post(
      '/customers/$customerId/pindahkan-alat',
      token: token,
      body: {
        'alat_ids': alatIds,
        'ke_customer_id': keCustomerId,
        'dry_run': true,
      },
    );
    return PratinjauPindahAlat.fromJson(json);
  }

  @override
  Future<HasilPindahAlat> pindahkanAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
    required String alasan,
  }) async {
    // TIDAK diulang otomatis: mengulang eksekusi yang jawabannya hilang bisa
    // memindahkan ulang alat yang sudah dipindah admin lain. `alat_sudah_pindah`
    // (409) di server menutup sisanya.
    final json = await _api.post(
      '/customers/$customerId/pindahkan-alat',
      token: token,
      body: {
        'alat_ids': alatIds,
        'ke_customer_id': keCustomerId,
        'alasan': alasan,
        'konfirmasi': true,
      },
    );
    return HasilPindahAlat.fromJson(json);
  }

  @override
  Future<DataAnggotaPelanggan> ambil(String token, int customerId) async {
    final json = await _api.get('/customers/$customerId/anggota', token: token);
    return DataAnggotaPelanggan.fromJson(json);
  }

  @override
  Future<AnggotaPelanggan> cabut(
    String token,
    int customerId,
    int anggotaId, {
    required String alasan,
  }) async {
    final json = await _api.post(
      '/customers/$customerId/anggota/$anggotaId/nonaktifkan',
      token: token,
      body: {'alasan': alasan},
    );
    return AnggotaPelanggan.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> batalkanUndangan(
    String token,
    int customerId,
    int undanganId,
  ) async {
    await _api.delete(
      '/customers/$customerId/undangan/$undanganId',
      token: token,
    );
  }

  @override
  Future<void> setPicAdmin(String token, int customerId, int? userId) async {
    // `user_id` HARUS ikut terkirim walau null (`present` di server): null =
    // lepas PIC admin. Jadi bukan elemen null-aware.
    await _api.patch(
      '/customers/$customerId/pic-admin',
      token: token,
      body: {'user_id': userId},
    );
  }
}

/// Tiruan in-memory buat test dan mode mock. Meniru penolakan server
/// (`pic_utama_terakhir`, `sudah_nonaktif`, 404) supaya layar teruji.
class MockAnggotaPelangganService implements AnggotaPelangganService {
  MockAnggotaPelangganService({
    List<Customer>? pelanggan,
    DataAnggotaPelanggan? data,
    this.galat,
    this.galatAmbil,
    this.jeda = Duration.zero,
    this.pratinjauTetap,
  }) : _pelanggan = pelanggan ?? contohPelanggan,
       _data = data ?? contohData();

  final List<Customer> _pelanggan;
  DataAnggotaPelanggan _data;

  /// Dilempar oleh SETIAP panggilan.
  final Object? galat;

  /// Dilempar hanya oleh [ambil] (mis. 404 / jaringan).
  final Object? galatAmbil;

  /// Boleh diubah di tengah tes (mis. menunda hanya pratinjau).
  Duration jeda;

  final List<String> catatan = [];

  static const contohPelanggan = <Customer>[
    Customer(
      id: 17,
      nama: 'PT Contoh Makmur',
      alamat: 'Jl. Contoh No. 1',
      contactPerson: 'Budi Santoso',
      telepon: '0812000000',
      email: 'budi@contoh.test',
      jumlahAlat: 12,
      alatCount: 12,
      sertifikatCount: 30,
      anggotaAktifCount: 2,
      undanganMenungguCount: 1,
    ),
    Customer(
      id: 18,
      nama: 'PT Uji Sejahtera',
      alamat: '',
      contactPerson: '',
      telepon: '',
      email: '',
      jumlahAlat: 3,
      alatCount: 3,
      sertifikatCount: 5,
      anggotaAktifCount: 0,
      undanganMenungguCount: 0,
      tanpaAkun: true,
      namaNormalKosong: true,
    ),
  ];

  static DataAnggotaPelanggan contohData() => DataAnggotaPelanggan.fromJson({
    'data': {
      'customer': {'id': 17, 'nama': 'PT Contoh Makmur'},
      'maks_anggota': 50,
      'jumlah_aktif': 2,
      'pic_admin': {
        'id': 4,
        'nama': 'Rina Master Data',
        'email': 'rina@lab.test',
      },
      'anggota': [
        {
          'id': 41,
          'peran': 'pic_utama',
          'status': 'aktif',
          'bergabung_pada': '2026-11-02T03:10:00+00:00',
          'dinonaktifkan_pada': null,
          'dinonaktifkan_oleh': null,
          'pic_utama_terakhir': true,
          'bisa_dicabut': false,
          'orang': {
            'id': 88,
            'nama': 'Budi Santoso',
            'email': 'budi@contoh.test',
            'telepon': '0812000000',
            'jabatan': 'QC Manager',
          },
        },
        {
          'id': 42,
          'peran': 'staf',
          'status': 'aktif',
          'bergabung_pada': '2026-11-03T07:00:00+00:00',
          'dinonaktifkan_pada': null,
          'dinonaktifkan_oleh': null,
          'pic_utama_terakhir': false,
          'bisa_dicabut': true,
          'orang': {
            'id': 91,
            'nama': 'Sari Dewi',
            'email': 'sari@contoh.test',
            'telepon': null,
            'jabatan': null,
          },
        },
        {
          'id': 40,
          'peran': 'staf',
          'status': 'nonaktif',
          'bergabung_pada': '2026-10-20T01:00:00+00:00',
          'dinonaktifkan_pada': '2026-11-10T09:30:00+00:00',
          'dinonaktifkan_oleh': {'id': 4, 'nama': 'Rina Master Data'},
          'pic_utama_terakhir': false,
          'bisa_dicabut': false,
          'orang': {
            'id': 75,
            'nama': 'Andi Lama',
            'email': 'andi@contoh.test',
            'telepon': null,
            'jabatan': null,
          },
        },
      ],
      'undangan_menunggu': [
        {
          'id': 12,
          'email': 'baru@contoh.test',
          'peran': 'staf',
          'kedaluwarsa_pada': '2026-11-25T08:00:00+00:00',
          'dibuat_pada': '2026-11-18T08:00:00+00:00',
          'diundang_oleh': {'id': 4, 'nama': 'Rina Master Data'},
        },
      ],
    },
  });

  Future<void> _awal(String panggilan) async {
    catatan.add(panggilan);
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
  }

  @override
  Future<HalamanHasil<Customer>> daftarPelanggan(
    String token, {
    String? cari,
    int halaman = 1,
  }) async {
    await _awal('daftarPelanggan cari=$cari h=$halaman');
    final kata = (cari ?? '').trim().toLowerCase();
    return HalamanHasil(
      items: _pelanggan
          .where((c) => kata.isEmpty || c.nama.toLowerCase().contains(kata))
          .toList(),
    );
  }

  @override
  Future<Customer> detailPelanggan(String token, int customerId) async {
    await _awal('detailPelanggan $customerId');
    return _pelanggan.firstWhere(
      (c) => c.id == customerId,
      orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
    );
  }

  /// Bila diisi, dipakai apa adanya sebagai jawaban pratinjau.
  final PratinjauPindahAlat? pratinjauTetap;

  /// Galat khusus pratinjau/eksekusi pindah alat (mis. 409), selain [galat].
  Object? galatPratinjau;
  Object? galatPindah;

  /// Isi pratinjau: dari alat yang dipilih, PT tujuan dari daftar.
  @override
  Future<PratinjauPindahAlat> pratinjauPindahAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
  }) async {
    await _awal('pratinjau $customerId -> $keCustomerId $alatIds');
    if (galatPratinjau != null) throw galatPratinjau!;
    if (pratinjauTetap != null) return pratinjauTetap!;
    final tujuan = _pelanggan.firstWhere(
      (c) => c.id == keCustomerId,
      orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
    );
    final asal = _pelanggan.firstWhere((c) => c.id == customerId);
    return PratinjauPindahAlat(
      dari: RingkasPt(
        id: asal.id,
        nama: asal.nama,
        anggotaAktifCount: asal.anggotaAktifCount ?? 0,
      ),
      ke: RingkasPt(
        id: tujuan.id,
        nama: tujuan.nama,
        anggotaAktifCount: tujuan.anggotaAktifCount ?? 2,
      ),
      jumlahAlat: alatIds.length,
      alat: [
        for (final id in alatIds)
          AlatDipindah(
            id: id,
            nama: 'Alat $id',
            nomorSeri: 'SN-$id',
            jumlahSertifikat: id % 3,
          ),
      ],
      sertifikatTerdampak: alatIds.length * 2 + 1,
      sertifikatTerlihatPelanggan: alatIds.length * 2,
      anggotaMulaiMelihat: const [
        OrangTerdampak(id: 41, nama: 'Budi Santoso', email: 'budi@contoh.test'),
      ],
      anggotaBerhentiMelihat: const [],
      paketTerkaitCount: 1,
      peringatan: const [
        PeringatanPindah(kode: 'paket_tidak_dipindah', pesan: 'paket'),
        PeringatanPindah(kode: 'arsip_tidak_dipindah', pesan: 'arsip'),
        PeringatanPindah(kode: 'isi_sertifikat_tetap', pesan: 'isi'),
      ],
    );
  }

  @override
  Future<HasilPindahAlat> pindahkanAlat(
    String token,
    int customerId, {
    required List<int> alatIds,
    required int keCustomerId,
    required String alasan,
  }) async {
    await _awal('pindah $customerId -> $keCustomerId $alatIds "$alasan"');
    if (galatPindah != null) throw galatPindah!;
    final panjang = alasan.trim().length;
    if (panjang < 3 || panjang > 500) {
      throw const ApiException(
        'Alasan harus 3 sampai 500 karakter.',
        status: 422,
        body: {
          'message': 'Alasan harus 3 sampai 500 karakter.',
          'errors': {
            'alasan': ['Alasan harus 3 sampai 500 karakter.'],
          },
        },
      );
    }
    final tujuan = _pelanggan.firstWhere((c) => c.id == keCustomerId);
    final asal = _pelanggan.firstWhere((c) => c.id == customerId);
    return HasilPindahAlat(
      dari: RingkasPt(id: asal.id, nama: asal.nama),
      ke: RingkasPt(id: tujuan.id, nama: tujuan.nama),
      jumlahAlat: alatIds.length,
      sertifikatTerdampak: alatIds.length * 2 + 1,
      sertifikatTerlihatPelanggan: alatIds.length * 2,
    );
  }

  @override
  Future<DataAnggotaPelanggan> ambil(String token, int customerId) async {
    await _awal('ambil $customerId');
    if (galatAmbil != null) throw galatAmbil!;
    return _data;
  }

  @override
  Future<AnggotaPelanggan> cabut(
    String token,
    int customerId,
    int anggotaId, {
    required String alasan,
  }) async {
    await _awal('cabut $anggotaId "$alasan"');
    final panjang = alasan.trim().length;
    if (panjang < 3 || panjang > 500) {
      throw const ApiException(
        'Alasan harus 3 sampai 500 karakter.',
        status: 422,
        body: {
          'message': 'Alasan harus 3 sampai 500 karakter.',
          'errors': {
            'alasan': ['Alasan harus 3 sampai 500 karakter.'],
          },
        },
      );
    }
    final a = _data.anggota.firstWhere(
      (x) => x.id == anggotaId,
      orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
    );
    if (a.picUtamaTerakhir) {
      throw const ApiException(
        'Dia satu-satunya PIC utama aktif.',
        status: 422,
        body: {
          'kode': 'pic_utama_terakhir',
          'message': 'Dia satu-satunya PIC utama aktif.',
        },
      );
    }
    if (!a.aktif) {
      throw const ApiException(
        'Anggota sudah nonaktif.',
        status: 422,
        body: {'kode': 'sudah_nonaktif', 'message': 'Anggota sudah nonaktif.'},
      );
    }
    final baru = AnggotaPelanggan(
      id: a.id,
      peran: a.peran,
      aktif: false,
      bergabungPada: a.bergabungPada,
      dinonaktifkanPada: DateTime(2026, 11, 18, 10, 15),
      dinonaktifkanOleh: const OrangLab(id: 4, nama: 'Rina Master Data'),
      picUtamaTerakhir: false,
      bisaDicabut: false,
      orang: a.orang,
    );
    _data = DataAnggotaPelanggan(
      customerId: _data.customerId,
      customerNama: _data.customerNama,
      maksAnggota: _data.maksAnggota,
      jumlahAktif: _data.jumlahAktif - 1,
      picAdmin: _data.picAdmin,
      anggota: [for (final x in _data.anggota) x.id == a.id ? baru : x],
      undanganMenunggu: _data.undanganMenunggu,
    );
    return baru;
  }

  @override
  Future<void> batalkanUndangan(
    String token,
    int customerId,
    int undanganId,
  ) async {
    await _awal('batalkanUndangan $undanganId');
    _data = DataAnggotaPelanggan(
      customerId: _data.customerId,
      customerNama: _data.customerNama,
      maksAnggota: _data.maksAnggota,
      jumlahAktif: _data.jumlahAktif,
      picAdmin: _data.picAdmin,
      anggota: _data.anggota,
      undanganMenunggu: [
        for (final u in _data.undanganMenunggu)
          if (u.id != undanganId) u,
      ],
    );
  }

  @override
  Future<void> setPicAdmin(String token, int customerId, int? userId) async {
    await _awal('setPicAdmin $userId');
    _data = DataAnggotaPelanggan(
      customerId: _data.customerId,
      customerNama: _data.customerNama,
      maksAnggota: _data.maksAnggota,
      jumlahAktif: _data.jumlahAktif,
      picAdmin: userId == null
          ? null
          : OrangLab(id: userId, nama: 'Admin $userId'),
      anggota: _data.anggota,
      undanganMenunggu: _data.undanganMenunggu,
    );
  }
}
