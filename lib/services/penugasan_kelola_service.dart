import '../core/utils/parse_list.dart';
import '../models/penugasan.dart';
import '../models/penugasan_kelola.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'pengguna_sa_service.dart' show HalamanHasil;

/// Kelola penugasan dari aplikasi Lab: papan (berpaginasi), ubah, batalkan.
///
/// Kontrak: `docs/perintah-frontend-crud-lengkap.md` §4. Hanya admin dan super
/// admin (`penugasan.ubah` / `penugasan.batalkan`); teknisi tetap hanya
/// melaporkan progres lewat `PenugasanService` lama yang TIDAK diubah. Server
/// yang menegakkan; layar hanya menyembunyikan tombol.
///
/// Galat 4xx/5xx dilempar sebagai `ApiException` (badan asli server: `kode`,
/// `errors`) — layar yang memetakannya ke kalimat.
abstract class PenugasanKelolaService {
  /// `GET /penugasan` — 20 per halaman. [status] `aktif|selesai|dibatalkan`;
  /// `null` = semua.
  Future<HalamanHasil<Penugasan>> daftar(
    String token, {
    String? status,
    int halaman = 1,
  });

  /// `PUT /penugasan/{id}` — pengganti penuh judul/teknisi/item.
  Future<Penugasan> ubah(String token, int id, FormUbahPenugasan form);

  /// `POST /penugasan/{id}/batalkan` — [alasan] 5–400 karakter. Idempoten:
  /// yang sudah dibatalkan dijawab `200` dengan `batal` yang lama.
  Future<Penugasan> batalkan(String token, int id, {required String alasan});
}

class ApiPenugasanKelolaService implements PenugasanKelolaService {
  ApiPenugasanKelolaService(this._api);

  final ApiClient _api;

  Penugasan _penugasan(Map<String, dynamic> json) =>
      Penugasan.fromJson((json['data'] ?? json) as Map<String, dynamic>);

  @override
  Future<HalamanHasil<Penugasan>> daftar(
    String token, {
    String? status,
    int halaman = 1,
  }) async {
    final q = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (halaman > 1) 'page': '$halaman',
    };
    final qs = q.isEmpty
        ? ''
        : '?${q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final json = await _api.get('/penugasan$qs', token: token);
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);
    return HalamanHasil(
      items: parseListAman(
        json['data'] as List<dynamic>? ?? const [],
        Penugasan.fromJson,
      ),
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<Penugasan> ubah(String token, int id, FormUbahPenugasan form) async =>
      _penugasan(
        await _api.put('/penugasan/$id', token: token, body: form.toJson()),
      );

  @override
  Future<Penugasan> batalkan(
    String token,
    int id, {
    required String alasan,
  }) async => _penugasan(
    // POST tanpa `client_request_id`: tidak diulang otomatis. Aman karena
    // server idempoten (yang sudah dibatalkan dijawab 200, tanpa notifikasi
    // kedua), jadi pengguna boleh mengulang sendiri bila jawabannya hilang.
    await _api.post(
      '/penugasan/$id/batalkan',
      token: token,
      body: {'alasan': alasan},
    ),
  );
}

/// Tiruan in-memory buat test dan mode mock. Meniru aturan server seperlunya
/// (status aktif saja, alasan 5–400, baris berprogres tidak boleh dibuang).
class MockPenugasanKelolaService implements PenugasanKelolaService {
  MockPenugasanKelolaService({
    List<Penugasan>? awal,
    this.galat,
    this.ukuranHalaman = 20,
    this.jeda = Duration.zero,
  }) : _data = [...(awal ?? contoh)];

  /// Bila diisi, dilempar oleh SETIAP panggilan (meniru 403/429/jaringan).
  final Object? galat;
  final int ukuranHalaman;
  final Duration jeda;
  final List<Penugasan> _data;

  /// Catatan panggilan buat assert di test.
  final List<String> catatan = [];

  /// Badan terakhir yang "dikirim" (`ubah`), buat assert bentuk payload.
  Map<String, dynamic>? badanTerakhir;

  static final contoh = <Penugasan>[
    Penugasan(
      id: 14,
      judul: 'Kalibrasi minggu ini',
      tipe: 'grup',
      status: 'aktif',
      tanggalTarget: DateTime(2026, 11, 30),
      terlambat: false,
      persenTuntas: 43,
      dibuatOleh: 'Rina Master Data',
      catatan: 'Prioritas PT Tirta.',
      teknisi: const [
        AnggotaPenugasan(id: 21, nama: 'Dedi Teknisi', kode: 'DDT', peran: 'ketua'),
        AnggotaPenugasan(id: 22, nama: 'Eko Prasetyo', kode: 'EKP', peran: 'anggota'),
      ],
      baris: const [
        BarisPenugasan(id: 31, jenisAlat: 'Autoklaf', jumlah: 12, jumlahSelesai: 5),
        BarisPenugasan(id: 32, jenisAlat: 'Timbangan', jumlah: 4, paket: 'ORD/2026/11/0003'),
      ],
    ),
    Penugasan(
      id: 15,
      judul: 'Termometer gudang',
      tipe: 'personal',
      status: 'aktif',
      terlambat: true,
      persenTuntas: 0,
      dibuatOleh: 'Rina Master Data',
      tanggalTarget: DateTime(2026, 11, 10),
      teknisi: const [
        AnggotaPenugasan(id: 21, nama: 'Dedi Teknisi', peran: 'ketua'),
      ],
      baris: const [BarisPenugasan(id: 33, jenisAlat: 'Termometer', jumlah: 3)],
    ),
    Penugasan(
      id: 16,
      judul: 'Pengujian lama',
      tipe: 'personal',
      status: 'dibatalkan',
      terlambat: false,
      persenTuntas: 20,
      dibuatOleh: 'Rina Master Data',
      batal: PenugasanBatal(
        alasan: 'Pelanggan membatalkan pesanan.',
        oleh: 'Sari',
        pada: DateTime.utc(2026, 11, 17, 4),
      ),
      teknisi: const [
        AnggotaPenugasan(id: 22, nama: 'Eko Prasetyo', peran: 'ketua'),
      ],
      baris: const [BarisPenugasan(id: 34, jenisAlat: 'pH Meter', jumlah: 2, jumlahSelesai: 1)],
    ),
    Penugasan(
      id: 17,
      judul: 'Sudah beres',
      tipe: 'personal',
      status: 'selesai',
      terlambat: false,
      persenTuntas: 100,
      teknisi: const [
        AnggotaPenugasan(id: 21, nama: 'Dedi Teknisi', peran: 'ketua'),
      ],
      baris: const [BarisPenugasan(id: 35, jenisAlat: 'Jangka sorong', jumlah: 1, jumlahSelesai: 1)],
    ),
  ];

  Future<void> _awal(String panggilan) async {
    catatan.add(panggilan);
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
  }

  ApiException _galat422(
    String pesan, {
    String? kode,
    Map<String, dynamic>? errors,
    Map<String, dynamic>? tambahan,
  }) => ApiException(
    pesan,
    status: 422,
    body: {'message': pesan, 'kode': ?kode, 'errors': ?errors, ...?tambahan},
  );

  Penugasan _cari(int id) => _data.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
  );

  @override
  Future<HalamanHasil<Penugasan>> daftar(
    String token, {
    String? status,
    int halaman = 1,
  }) async {
    await _awal('daftar status=$status h=$halaman');
    final cocok = _data.where((p) => status == null || p.status == status).toList();
    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final mulai = (halaman - 1) * ukuranHalaman;
    return HalamanHasil(
      items: cocok.skip(mulai).take(ukuranHalaman).toList(),
      halaman: halaman,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<Penugasan> ubah(String token, int id, FormUbahPenugasan form) async {
    await _awal('ubah $id');
    badanTerakhir = form.toJson();
    final lama = _cari(id);
    if (lama.status != 'aktif') {
      throw _galat422(
        'Penugasan ini sudah ${lama.status}.',
        kode: 'penugasan_tidak_aktif',
        tambahan: {'status': lama.status},
      );
    }
    // Baris lama yang tidak disebut: hanya boleh dibuang bila belum berprogres.
    final disebut = {for (final b in form.baris) ?b.id};
    for (final b in lama.baris) {
      if (!disebut.contains(b.id) && b.jumlahSelesai > 0) {
        throw _galat422(
          'Baris yang sudah ada progresnya tidak bisa dibuang.',
          kode: 'item_sudah_dikerjakan',
          errors: {
            'item': ['Baris yang sudah ada progresnya tidak bisa dibuang.'],
          },
        );
      }
    }
    final baru = Penugasan(
      id: id,
      judul: form.judul.trim(),
      tipe: form.teknisi.length > 1 ? 'grup' : 'personal',
      status: 'aktif',
      tanggalTarget: form.tanggalBerubah ? form.tanggalTarget : lama.tanggalTarget,
      terlambat: lama.terlambat,
      persenTuntas: lama.persenTuntas,
      catatan: form.catatanBerubah
          ? (form.catatan.trim().isEmpty ? null : form.catatan.trim())
          : lama.catatan,
      dibuatOleh: lama.dibuatOleh,
      teknisi: [
        for (var i = 0; i < form.teknisi.length; i++)
          AnggotaPenugasan(
            id: form.teknisi[i],
            nama: lama.teknisi
                    .where((t) => t.id == form.teknisi[i])
                    .map((t) => t.nama)
                    .firstOrNull ??
                'Teknisi ${form.teknisi[i]}',
            peran: i == 0 ? 'ketua' : 'anggota',
          ),
      ],
      baris: [
        for (final b in form.baris)
          BarisPenugasan(
            id: b.id,
            jenisAlat: b.jenisAlat.trim(),
            jumlah: b.jumlah,
            jumlahSelesai: b.jumlahSelesai,
            paket: b.paket,
          ),
      ],
    );
    _data[_data.indexWhere((p) => p.id == id)] = baru;
    return baru;
  }

  @override
  Future<Penugasan> batalkan(
    String token,
    int id, {
    required String alasan,
  }) async {
    await _awal('batalkan $id "$alasan"');
    final panjang = alasan.trim().length;
    if (panjang < 5 || panjang > 400) {
      throw _galat422(
        'Alasan harus 5 sampai 400 karakter.',
        errors: {
          'alasan': ['Alasan harus 5 sampai 400 karakter.'],
        },
      );
    }
    final lama = _cari(id);
    if (lama.status == 'dibatalkan') return lama; // idempoten
    if (lama.status == 'selesai') {
      throw _galat422(
        'Penugasan ini sudah selesai.',
        kode: 'penugasan_sudah_selesai',
      );
    }
    final baru = Penugasan(
      id: lama.id,
      judul: lama.judul,
      tipe: lama.tipe,
      status: 'dibatalkan',
      tanggalTarget: lama.tanggalTarget,
      terlambat: false,
      persenTuntas: lama.persenTuntas,
      catatan: lama.catatan,
      dibuatOleh: lama.dibuatOleh,
      batal: PenugasanBatal(
        alasan: alasan.trim(),
        oleh: 'Rina Master Data',
        pada: DateTime.now().toUtc(),
      ),
      teknisi: lama.teknisi,
      baris: lama.baris,
    );
    _data[_data.indexWhere((p) => p.id == id)] = baru;
    return baru;
  }
}
