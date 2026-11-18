import '../core/utils/parse_list.dart';
import '../models/equipment_lookup.dart';
import '../models/order.dart';
import '../models/order_kelola.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;
import 'equipment_lookup_service.dart' show daftarAlatMock;
import 'pengguna_sa_service.dart' show HalamanHasil;

/// Kelola order dari aplikasi Lab: daftar berpaginasi, buat, ubah, hapus.
///
/// Rute tulisnya (`POST/PUT/DELETE /orders`) ada di grup `role:admin` server
/// (super admin ikut, K-49-14). Teknisi hanya membaca lewat [OrderService]
/// lama yang TIDAK diubah. Server yang menegakkan; layar hanya menyembunyikan
/// tombol.
///
/// Galat 4xx/5xx dilempar sebagai `ApiException` (badan asli server) — layar
/// yang memetakannya ke kalimat atau kolom.
abstract class OrderKelolaService {
  /// `GET /orders` — 15 per halaman. [status] salah satu [StatusOrder.semua].
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  });

  /// `GET /orders/{id}` — memuat `items`.
  Future<OrderKalibrasi> detail(String token, int id);

  /// `POST /orders` — nomor dibuat server.
  Future<OrderKalibrasi> buat(String token, FormOrder form);

  /// `PUT /orders/{id}` — `items` dikirim lengkap; server mempertahankan baris
  /// yang sudah punya sesi kalibrasi.
  Future<OrderKalibrasi> ubah(String token, int id, FormOrder form);

  /// `DELETE /orders/{id}` — `422` bila alatnya sudah masuk kalibrasi.
  Future<void> hapus(String token, int id);

  /// `GET /equipments?customer_id=` — alat milik satu PT, buat pemilih alat
  /// order (15 per halaman, bisa dicari).
  Future<HalamanHasil<EquipmentLookup>> alatPelanggan(
    String token,
    int pelangganId, {
    String? cari,
    int halaman = 1,
  });
}

String _qs(Map<String, String> q) => q.isEmpty
    ? ''
    : '?${q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

class ApiOrderKelolaService implements OrderKelolaService {
  ApiOrderKelolaService(this._api);

  final ApiClient _api;

  OrderKalibrasi _order(Map<String, dynamic> json) =>
      OrderKalibrasi.fromJson((json['data'] ?? json) as Map<String, dynamic>);

  @override
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    final json = await _api.get(
      '/orders${_qs({
        if (status != null && status.isNotEmpty) 'status': status,
        if (cari != null && cari.trim().isNotEmpty) 'search': cari.trim(),
        if (halaman > 1) 'page': '$halaman',
      })}',
      token: token,
    );
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);
    return HalamanHasil(
      items: parseListAman(
        json['data'] as List<dynamic>? ?? const [],
        OrderKalibrasi.fromJson,
      ),
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<OrderKalibrasi> detail(String token, int id) async =>
      _order(await _api.get('/orders/$id', token: token));

  @override
  Future<OrderKalibrasi> buat(String token, FormOrder form) async {
    // POST tanpa `client_request_id`: TIDAK diulang otomatis oleh ApiClient,
    // jadi sinyal putus-nyambung tidak melahirkan dua order kembar. Bila
    // jawabannya hilang, layar menyuruh cek daftar dulu.
    return _order(
      await _api.post('/orders', token: token, body: form.toJson(buat: true)),
    );
  }

  @override
  Future<OrderKalibrasi> ubah(String token, int id, FormOrder form) async =>
      _order(
        await _api.put(
          '/orders/$id',
          token: token,
          body: form.toJson(buat: false),
        ),
      );

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/orders/$id', token: token);
  }

  @override
  Future<HalamanHasil<EquipmentLookup>> alatPelanggan(
    String token,
    int pelangganId, {
    String? cari,
    int halaman = 1,
  }) async {
    final json = await _api.get(
      '/equipments${_qs({
        'customer_id': '$pelangganId',
        if (cari != null && cari.trim().isNotEmpty) 'search': cari.trim(),
        if (halaman > 1) 'page': '$halaman',
      })}',
      token: token,
    );
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);
    return HalamanHasil(
      items: parseListAman(
        json['data'] as List<dynamic>? ?? const [],
        EquipmentLookup.fromJson,
      ),
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }
}

/// Tiruan in-memory buat test dan mode mock. Meniru aturan server seperlunya:
/// nomor berurut, `items` wajib, hapus ditolak untuk order bersesi, dan alat
/// per PT. Mengisi [catatan] supaya test bisa menegaskan panggilannya.
class MockOrderKelolaService implements OrderKelolaService {
  MockOrderKelolaService({
    List<OrderKalibrasi>? awal,
    this.galat,
    this.ukuranHalaman = 15,
    this.jeda = Duration.zero,
    this.idBersesi = const {},
  }) : _data = [...(awal ?? contoh)];

  /// Bila diisi, dilempar oleh SETIAP panggilan (meniru 403/500/jaringan).
  final Object? galat;
  final int ukuranHalaman;
  final Duration jeda;

  /// Id order yang alatnya sudah punya sesi kalibrasi (hapus → 422).
  final Set<int> idBersesi;

  final List<OrderKalibrasi> _data;

  /// Catatan panggilan buat assert di test.
  final List<String> catatan = [];

  /// Badan terakhir yang "dikirim" (buat/ubah), buat assert bentuk payload.
  Map<String, dynamic>? badanTerakhir;

  static final contoh = <OrderKalibrasi>[
    OrderKalibrasi(
      id: 301,
      nomor: 'ORD/2026/11/0003',
      status: StatusOrder.diproses,
      namaPelanggan: 'PT Tirta Contoh Mandiri',
      pelangganId: 3,
      jumlahAlat: 2,
      tanggalMasuk: DateTime.utc(2026, 11, 16),
      tanggalJanjiSelesai: DateTime.utc(2026, 11, 30),
      catatan: 'Alat dijemput kurir lab.',
      diterimaOleh: 'Rina Master Data',
      items: const [
        OrderItem(
          id: 1,
          alatId: 14,
          namaAlat: 'pH Meter Mettler Toledo',
          serialNumber: 'B628755900',
          teknisiId: 21,
          namaTeknisi: 'Dedi Teknisi',
          kondisiTerima: 'Baik, ada goresan di casing.',
          kelengkapan: 'Adaptor, probe',
        ),
        OrderItem(
          id: 2,
          alatId: 15,
          namaAlat: 'Turbidimeter Hach',
          serialNumber: 'HC-2100Q-114',
        ),
      ],
    ),
    OrderKalibrasi(
      id: 302,
      nomor: 'ORD/2026/11/0002',
      status: StatusOrder.baru,
      namaPelanggan: 'CV Maju Bersama',
      pelangganId: 4,
      jumlahAlat: 1,
      tanggalMasuk: DateTime.utc(2026, 11, 12),
      items: const [
        OrderItem(
          id: 3,
          alatId: 13,
          namaAlat: 'Timbangan Digital Ohaus',
          serialNumber: 'OH-8825-01',
        ),
      ],
    ),
    OrderKalibrasi(
      id: 303,
      nomor: 'ORD/2026/10/0009',
      status: StatusOrder.selesai,
      namaPelanggan: 'PT Tirta Contoh Mandiri',
      pelangganId: 3,
      jumlahAlat: 1,
      tanggalMasuk: DateTime.utc(2026, 10, 20),
      tanggalJanjiSelesai: DateTime.utc(2026, 10, 27),
      items: const [
        OrderItem(
          id: 4,
          alatId: 14,
          namaAlat: 'pH Meter Mettler Toledo',
          serialNumber: 'B628755900',
        ),
      ],
    ),
  ];

  /// Alat contoh per PT (id PT → alat), buat pemilih alat.
  static final alatContoh = <int, List<EquipmentLookup>>{
    3: [
      for (final a in daftarAlatMock)
        if (a.id == 14 || a.id == 15) a,
    ],
    4: [for (final a in daftarAlatMock) if (a.id == 12 || a.id == 13) a],
  };

  Future<void> _awal(String panggilan) async {
    catatan.add(panggilan);
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
  }

  ApiException _galat422(
    String pesan, {
    String? kode,
    Map<String, dynamic>? errors,
  }) => ApiException(
    pesan,
    status: 422,
    body: {'message': pesan, 'kode': ?kode, 'errors': ?errors},
  );

  OrderKalibrasi _cari(int id) => _data.firstWhere(
    (o) => o.id == id,
    orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
  );

  @override
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    await _awal('daftar status=$status cari=$cari h=$halaman');
    final kata = (cari ?? '').trim().toLowerCase();
    final cocok = _data.where((o) {
      if (status != null && o.status != status) return false;
      if (kata.isEmpty) return true;
      return o.nomor.toLowerCase().contains(kata) ||
          o.namaPelanggan.toLowerCase().contains(kata);
    }).toList();
    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final mulai = (halaman - 1) * ukuranHalaman;
    return HalamanHasil(
      items: cocok.skip(mulai).take(ukuranHalaman).toList(),
      halaman: halaman,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<OrderKalibrasi> detail(String token, int id) async {
    await _awal('detail $id');
    return _cari(id);
  }

  Map<String, dynamic>? _periksa(FormOrder form, {required bool buat}) {
    final errors = <String, dynamic>{
      if (form.items.isEmpty)
        'items': ['Minimal satu alat harus didaftarin di order ini.'],
      if (form.tanggalJanjiSelesai != null &&
          form.tanggalJanjiSelesai!.isBefore(form.tanggalMasuk))
        'tanggal_janji_selesai': [
          'Tanggal janji selesai nggak boleh lebih awal dari tanggal masuk.',
        ],
    };
    return errors.isEmpty ? null : errors;
  }

  OrderKalibrasi _bangun(
    int id,
    String nomor,
    FormOrder form, {
    required String status,
  }) {
    final pelanggan = contoh.firstWhere(
      (o) => o.pelangganId == form.pelangganId,
      orElse: () => contoh.first,
    );
    return OrderKalibrasi(
      id: id,
      nomor: nomor,
      status: status,
      namaPelanggan: pelanggan.namaPelanggan,
      pelangganId: form.pelangganId,
      jumlahAlat: form.items.length,
      tanggalMasuk: form.tanggalMasuk,
      tanggalJanjiSelesai: form.tanggalJanjiSelesai,
      catatan: form.catatan.trim().isEmpty ? null : form.catatan.trim(),
      items: [
        for (var i = 0; i < form.items.length; i++)
          OrderItem(
            id: id * 10 + i,
            alatId: form.items[i].alatId,
            namaAlat: form.items[i].namaAlat,
            serialNumber: form.items[i].serialNumber,
            teknisiId: form.items[i].teknisiId,
            namaTeknisi: form.items[i].namaTeknisi,
            kondisiTerima: form.items[i].kondisiTerima,
            kelengkapan: form.items[i].kelengkapan,
            catatan: form.items[i].catatan,
          ),
      ],
    );
  }

  @override
  Future<OrderKalibrasi> buat(String token, FormOrder form) async {
    await _awal('buat pt=${form.pelangganId}');
    badanTerakhir = form.toJson(buat: true);
    final errors = _periksa(form, buat: true);
    if (errors != null) {
      throw _galat422('Data yang dikirim nggak valid.', errors: errors);
    }
    final id = _data.fold<int>(0, (m, o) => o.id > m ? o.id : m) + 1;
    final baru = _bangun(
      id,
      'ORD/2026/11/${(_data.length + 1).toString().padLeft(4, '0')}',
      form,
      status: StatusOrder.baru,
    );
    _data.insert(0, baru);
    return baru;
  }

  @override
  Future<OrderKalibrasi> ubah(String token, int id, FormOrder form) async {
    await _awal('ubah $id');
    badanTerakhir = form.toJson(buat: false);
    final lama = _cari(id);
    final errors = _periksa(form, buat: false);
    if (errors != null) {
      throw _galat422('Data yang dikirim nggak valid.', errors: errors);
    }
    final baru = _bangun(
      id,
      lama.nomor,
      form,
      status: form.status ?? lama.status,
    );
    _data[_data.indexWhere((o) => o.id == id)] = baru;
    return baru;
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _awal('hapus $id');
    _cari(id);
    if (idBersesi.contains(id)) {
      throw _galat422(
        'Order ini alatnya udah masuk kalibrasi. Ubah statusnya jadi '
        '"dibatalkan" biar riwayatnya nggak putus.',
      );
    }
    _data.removeWhere((o) => o.id == id);
  }

  @override
  Future<HalamanHasil<EquipmentLookup>> alatPelanggan(
    String token,
    int pelangganId, {
    String? cari,
    int halaman = 1,
  }) async {
    await _awal('alat pt=$pelangganId cari=$cari h=$halaman');
    final kata = (cari ?? '').trim().toLowerCase();
    final cocok = (alatContoh[pelangganId] ?? const <EquipmentLookup>[])
        .where(
          (a) =>
              kata.isEmpty ||
              a.namaAlat.toLowerCase().contains(kata) ||
              a.serialNumber.toLowerCase().contains(kata),
        )
        .toList();
    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final mulai = (halaman - 1) * ukuranHalaman;
    return HalamanHasil(
      items: cocok.skip(mulai).take(ukuranHalaman).toList(),
      halaman: halaman,
      halamanTerakhir: terakhir,
    );
  }
}
