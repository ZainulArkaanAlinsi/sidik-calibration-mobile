// Katalog keadaan layar CRUD lab buat uji responsif dan harness PNG: tiap entri
// = satu layar dalam satu keadaan (memuat, daftar, kosong, galat, dialog,
// formulir) beserta data tiruannya.
//
// Data sengaja memuat kasus buruk: nama PT/alat/teknisi SANGAT panjang,
// kolom opsional kosong, nomor seri panjang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/arsip_draf.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/order.dart';
import 'package:sidik_calibration/models/order_kelola.dart';
import 'package:sidik_calibration/models/penugasan.dart';
import 'package:sidik_calibration/models/penugasan_kelola.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/crud_lab/arsip_draf_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/kategori_kelola_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/penugasan_kelola_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/penugasan_ubah_screen.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_detail_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_form_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_list_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/pengelolaan_data_screen.dart';
import 'package:sidik_calibration/services/arsip_draf_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kategori_kelola_service.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/penugasan_kelola_service.dart';

import 'crud_uji.dart';
import 'layar_sa_uji.dart' show ketukDi;
import 'super_admin_uji.dart' show namaSangatPanjang;

class KeadaanCrud {
  const KeadaanCrud(
    this.nama,
    this.layar,
    this.lapisan, {
    this.sesudah,
    this.menahan = false,
    this.tinggiBesar = true,
    this.token = tokenAdminCrud,
    this.izin = izinAdminCrud,
  });

  final String nama;
  final Widget Function() layar;
  final LapisanUjiCrud Function() lapisan;

  /// Interaksi sesudah layar tampil (buka dialog/lembar, kirim formulir kosong).
  final Future<void> Function(WidgetTester tester)? sesudah;

  /// [sesudah] dijalankan di permukaan SANGAT tinggi lalu dikembalikan ke
  /// ukuran uji: di layar 320 dp daftar malas tidak membangun tombol yang jauh
  /// di bawah. Hasil akhirnya (dialog terbuka, galat tampil) tetap DIRENDER di
  /// ukuran uji. `false` untuk keadaan yang justru menguji posisi gulir.
  final bool tinggiBesar;

  /// Keadaan "memuat": layanan menunda jawaban; tes menunggu sesudahnya
  /// supaya tidak ada pewaktu yang menggantung.
  final bool menahan;

  final String token;
  final Izin izin;
}

/// Jalankan [KeadaanCrud.sesudah] sesuai aturan `tinggiBesar`.
Future<void> jalankanSesudahCrud(WidgetTester tester, KeadaanCrud k) async {
  final sesudah = k.sesudah;
  if (sesudah == null) return;
  if (!k.tinggiBesar) {
    await sesudah(tester);
    return;
  }
  final asli = tester.view.physicalSize;
  tester.view.physicalSize = Size(asli.width, 8000);
  await tester.pump();
  await sesudah(tester);
  tester.view.physicalSize = asli;
  await tester.pump();
}

const _jedaMemuat = Duration(seconds: 5);

/// Order buruk: PT/alat/teknisi super panjang, kolom opsional kosong.
final ordersBurukCrud = <OrderKalibrasi>[
  OrderKalibrasi(
    id: 801,
    nomor: 'ORD/2026/11/0801',
    status: StatusOrder.diproses,
    namaPelanggan:
        'PT Perusahaan Kalibrasi Industri Nusantara Sejahtera Makmur Abadi '
        'Sentosa Jaya Raya Tbk Cabang Surabaya Timur',
    pelangganId: 3,
    jumlahAlat: 1234,
    tanggalMasuk: DateTime.utc(2026, 11, 2),
    tanggalJanjiSelesai: DateTime.utc(2026, 11, 9),
    catatan: namaSangatPanjang,
    diterimaOleh: namaSangatPanjang,
    items: [
      const OrderItem(
        id: 1,
        alatId: 14,
        namaAlat: namaSangatPanjang,
        serialNumber: 'SN-1234567890-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0987654321',
        teknisiId: 21,
        namaTeknisi: namaSangatPanjang,
        kondisiTerima: 'Layar retak di sudut kanan, tombol daya longgar, '
            'kabel probe terkelupas dekat konektor.',
        kelengkapan: 'Adaptor, probe, kabel data, tas pelindung, manual',
        catatan: 'Prioritas tinggi, pelanggan menunggu laporan.',
      ),
      const OrderItem(id: 2, alatId: 15, namaAlat: 'Timbangan', serialNumber: ''),
    ],
  ),
  OrderKalibrasi(
    id: 802,
    nomor: 'ORD/2026/11/0802',
    status: StatusOrder.baru,
    namaPelanggan: 'CV Singkat',
    pelangganId: 4,
    jumlahAlat: 1,
  ),
  OrderKalibrasi(
    id: 803,
    nomor: 'ORD/2026/10/0803',
    status: StatusOrder.dibatalkan,
    namaPelanggan: '',
    jumlahAlat: 0,
    tanggalMasuk: DateTime.utc(2026, 10, 1),
    tanggalJanjiSelesai: DateTime.utc(2026, 10, 3),
  ),
  OrderKalibrasi(
    id: 804,
    nomor: 'ORD/2026/10/0804',
    status: StatusOrder.selesai,
    namaPelanggan: 'PT Tirta Contoh Mandiri',
    pelangganId: 3,
    jumlahAlat: 2,
    tanggalMasuk: DateTime.utc(2026, 10, 1),
  ),
];

MockOrderKelolaService _orderBuruk({
  Duration jeda = Duration.zero,
  Object? galat,
  List<OrderKalibrasi>? awal,
  Set<int> idBersesi = const {},
}) => MockOrderKelolaService(
  awal: awal ?? ordersBurukCrud,
  jeda: jeda,
  galat: galat,
  idBersesi: idBersesi,
);

LapisanUjiCrud _lapisanOrder({
  Duration jeda = Duration.zero,
  Object? galat,
  List<OrderKalibrasi>? awal,
  Set<int> idBersesi = const {},
}) => LapisanUjiCrud(
  order: _orderBuruk(jeda: jeda, galat: galat, awal: awal, idBersesi: idBersesi),
);

/// Layanan yang menolak `buat` dengan 422 per kolom (bentuk `OrderRequest`).
class _Tolak422 extends MockOrderKelolaService {
  _Tolak422() : super(awal: ordersBurukCrud);

  @override
  Future<OrderKalibrasi> buat(String token, FormOrder form) async {
    throw const ApiException(
      'x',
      status: 422,
      body: {
        'message': 'x',
        'errors': {
          'items.0.equipment_id': [
            'Alat "pH Meter" terdaftar atas nama pelanggan lain, jadi tidak '
                'bisa masuk order pelanggan ini.',
          ],
          'tanggal_janji_selesai': [
            'Tanggal janji selesai tidak boleh lebih awal dari tanggal masuk.',
          ],
        },
      },
    );
  }
}

Future<void> _menuOrder(WidgetTester tester, int id, String aksi) async {
  await ketukDi(tester, find.byKey(Key('menu-order-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(aksi));
  await tester.pumpAndSettle();
}

Future<void> _hapusDialog(WidgetTester tester) async {
  await _menuOrder(tester, 802, 'Hapus');
}

Future<void> _hapusDitolak(WidgetTester tester) async {
  await _menuOrder(tester, 801, 'Hapus');
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _pilihPt(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pt-3')));
  await tester.pumpAndSettle();
}

Future<void> _bukaPemilihPt(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
  await tester.pumpAndSettle();
}

Future<void> _bukaPemilihAlat(WidgetTester tester) async {
  await _pilihPt(tester);
  await ketukDi(tester, find.byKey(const Key('tambah-alat')));
  await tester.pumpAndSettle();
}

Future<void> _formTerisi(WidgetTester tester) async {
  await _bukaPemilihAlat(tester);
  await tester.tap(find.byKey(const Key('alat-14')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('tambah-alat-terpilih')));
  await tester.pumpAndSettle();
}

Future<void> _simpanKosong(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('simpan-order')));
  await tester.pumpAndSettle();
}

Future<void> _simpan422(WidgetTester tester) async {
  await _formTerisi(tester);
  await _simpanKosong(tester);
}

Future<void> _bukaPemilihTeknisi(WidgetTester tester) async {
  await _formTerisi(tester);
  await ketukDi(tester, find.text('Belum dibagi'));
  await tester.pumpAndSettle();
}

/// Penugasan buruk: judul/tim/jenis alat/alasan super panjang, kolom kosong.
final penugasanBurukCrud = <Penugasan>[
  Penugasan(
    id: 61,
    judul:
        'Kalibrasi seluruh peralatan laboratorium mutu dan pengujian kimia '
        'cabang Surabaya Timur untuk akreditasi tahunan',
    tipe: 'grup',
    status: 'aktif',
    tanggalTarget: DateTime(2026, 12, 30),
    terlambat: true,
    persenTuntas: 43,
    dibuatOleh: namaSangatPanjang,
    catatan: namaSangatPanjang,
    teknisi: const [
      AnggotaPenugasan(id: 21, nama: namaSangatPanjang, peran: 'ketua'),
      AnggotaPenugasan(id: 22, nama: 'Eko Prasetyo', peran: 'anggota'),
      AnggotaPenugasan(id: 23, nama: 'Lina Wulandari', peran: 'anggota'),
    ],
    baris: const [
      BarisPenugasan(
        id: 1,
        jenisAlat:
            'Thermohygrometer digital dengan sensor eksternal dan kabel panjang',
        jumlah: 12,
        jumlahSelesai: 5,
      ),
      BarisPenugasan(
        id: 2,
        jenisAlat: 'Timbangan',
        jumlah: 4,
        paket: 'ORD/2026/11/0003',
      ),
    ],
  ),
  const Penugasan(
    id: 62,
    judul: 'Singkat',
    tipe: 'personal',
    status: 'aktif',
    terlambat: false,
    persenTuntas: 0,
    teknisi: [AnggotaPenugasan(id: 21, nama: 'Dedi', peran: 'ketua')],
    baris: [BarisPenugasan(id: 3, jenisAlat: 'pH Meter', jumlah: 2)],
  ),
  Penugasan(
    id: 63,
    judul: 'Penugasan dibatalkan',
    tipe: 'personal',
    status: 'dibatalkan',
    terlambat: false,
    persenTuntas: 20,
    batal: PenugasanBatal(
      alasan: namaSangatPanjang,
      oleh: namaSangatPanjang,
      pada: DateTime.utc(2026, 11, 17, 4),
    ),
    teknisi: const [AnggotaPenugasan(id: 22, nama: 'Eko', peran: 'ketua')],
    baris: const [
      BarisPenugasan(id: 4, jenisAlat: 'Oven', jumlah: 1, jumlahSelesai: 1),
    ],
  ),
  const Penugasan(
    id: 64,
    judul: '',
    tipe: 'personal',
    status: 'selesai',
    terlambat: false,
    persenTuntas: 100,
  ),
];

/// Kategori buruk: nama/kode super panjang, hitungan besar, nonaktif.
final kategoriBurukCrud = <Category>[
  const Category(
    id: 71,
    kode:
        'kategori-dengan-nama-yang-sangat-panjang-sekali-untuk-menguji-tata-letak',
    nama:
        'Kategori Pengukuran dengan Nama yang Sangat Panjang untuk Menguji '
        'Tata Letak Kartu di Layar Sempit',
    jumlahAlat: 12345,
    jumlahKemampuan: 678,
    jumlahTanpaCmc: 9,
  ),
  const Category(id: 72, kode: 'tekanan', nama: 'Tekanan'),
  Category(
    id: 73,
    kode: 'suhu-lama',
    nama: 'Suhu Lama',
    aktif: false,
    nonaktifPada: DateTime.utc(2026, 11, 10, 3),
    jumlahAlat: 3,
  ),
];

/// Draf terarsip buruk: nomor/alat/PT/teknisi/alasan super panjang, kolom kosong.
final arsipBurukCrud = <DrafArsipan>[
  DrafArsipan(
    id: 91,
    nomorSesi: 'KAL/2026/11/0091',
    status: 'draft',
    namaAlat: namaSangatPanjang,
    nomorSeri: 'SN-1234567890-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0987654321',
    namaPelanggan:
        'PT Perusahaan Kalibrasi Industri Nusantara Sejahtera Makmur Abadi',
    namaTeknisi: namaSangatPanjang,
    arsip: JejakArsip(
      alasan: namaSangatPanjang,
      olehNama: namaSangatPanjang,
      pada: DateTime.utc(2026, 11, 18, 3, 20),
    ),
  ),
  const DrafArsipan(id: 92, status: 'draft'),
  const DrafArsipan(
    id: 93,
    nomorSesi: 'KAL/2026/11/0093',
    status: 'draft',
    namaAlat: 'pH Meter',
    arsip: JejakArsip(alasan: 'Salah alat.'),
  ),
];

/// Layanan yang menolak aksi dengan galat bisnis server tertentu.
class _TolakPenugasanUbah extends MockPenugasanKelolaService {
  _TolakPenugasanUbah() : super(awal: penugasanBurukCrud);

  @override
  Future<Penugasan> ubah(String token, int id, FormUbahPenugasan form) async {
    throw const ApiException(
      'x',
      status: 422,
      body: {
        'message': 'x',
        'errors': {
          'item.0.jumlah': ['Jumlahnya kebanyakan, periksa lagi.'],
          'teknisi.1': ['Ada teknisi yang tidak aktif.'],
        },
      },
    );
  }
}

class _TolakBatal extends MockPenugasanKelolaService {
  _TolakBatal() : super(awal: penugasanBurukCrud);

  @override
  Future<Penugasan> batalkan(
    String token,
    int id, {
    required String alasan,
  }) async => throw const ApiException(
    'x',
    status: 422,
    body: {'message': 'x', 'kode': 'penugasan_sudah_selesai'},
  );
}

class _KategoriDipakai extends MockKategoriKelolaService {
  _KategoriDipakai() : super(awal: kategoriBurukCrud);

  @override
  Future<void> hapus(String token, String kode) async =>
      throw const ApiException(
        'x',
        status: 422,
        body: {
          'message': 'x',
          'kode': 'kategori_dipakai',
          'pemakai': {
            'alat': 3,
            'kemampuan': 2,
            'penugasan': 1,
            'metode': 0,
            'rumus': 0,
          },
        },
      );
}

class _PulihkanGagal extends MockArsipDrafService {
  _PulihkanGagal() : super(awal: arsipBurukCrud);

  @override
  Future<HasilArsipDraf> pulihkan(
    String token,
    int id, {
    String? alasan,
  }) async => throw const ApiException(
    'x',
    status: 422,
    body: {'message': 'x', 'kode': 'tidak_diarsipkan'},
  );
}

class _ArsipkanGagal extends MockArsipDrafService {
  @override
  Future<HasilArsipDraf> arsipkan(
    String token,
    int id, {
    required String alasan,
  }) async => throw const ApiException(
    'x',
    status: 422,
    body: {'message': 'x', 'kode': 'bukan_draf', 'status': 'menunggu_approval'},
  );
}

Future<void> _menuPenugasan(WidgetTester tester, int id, String aksi) async {
  await ketukDi(tester, find.byKey(Key('menu-penugasan-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(aksi));
  await tester.pumpAndSettle();
}

Future<void> _batalDialog(WidgetTester tester) =>
    _menuPenugasan(tester, 61, 'Batalkan penugasan');

Future<void> _batalGagal(WidgetTester tester) async {
  await _batalDialog(tester);
  await tester.enterText(find.byKey(const Key('isian-dialog')), 'alasan sah');
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _batalPendek(WidgetTester tester) async {
  await _batalDialog(tester);
  await tester.enterText(find.byKey(const Key('isian-dialog')), 'abc');
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _ubahKosongkan(WidgetTester tester) async {
  // Pada skala huruf besar baris teknisi di luar layar belum dibangun (daftar
  // malas), jadi tiap ketukan menggulir dulu.
  for (final id in const [21, 22, 23]) {
    await ketukDi(tester, find.byKey(Key('teknisi-$id')));
    await tester.pump();
  }
  await ketukDi(tester, find.byKey(const Key('tambah-baris')));
  await tester.pumpAndSettle();
  await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
  await tester.pumpAndSettle();
}

Future<void> _ubah422(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
  await tester.pumpAndSettle();
}

Future<void> _menuKategori(
  WidgetTester tester,
  String kode,
  String aksi,
) async {
  await ketukDi(tester, find.byKey(Key('menu-kategori-$kode')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(aksi));
  await tester.pumpAndSettle();
}

Future<void> _tambahKategori(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('tambah-kategori')));
  await tester.pumpAndSettle();
}

Future<void> _tambahKembar(WidgetTester tester) async {
  await _tambahKategori(tester);
  await tester.enterText(find.byKey(const Key('isian-dialog')), 'suhu lama');
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _ubahNamaKategori(WidgetTester tester) =>
    _menuKategori(tester, 'tekanan', 'Ubah nama');

Future<void> _nonaktifKategori(WidgetTester tester) =>
    _menuKategori(tester, 'tekanan', 'Nonaktifkan');

Future<void> _hapusKategori(WidgetTester tester) =>
    _menuKategori(tester, 'tekanan', 'Hapus');

Future<void> _hapusKategoriDipakai(WidgetTester tester) async {
  await _hapusKategori(tester);
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _pulihkanDialog(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('pulihkan-91')));
  await tester.pumpAndSettle();
}

Future<void> _pulihkanGagal(WidgetTester tester) async {
  await _pulihkanDialog(tester);
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

Future<void> _arsipkanDialog(WidgetTester tester) async {
  await tester.tap(
    find
        .byWidgetPredicate(
          (w) =>
              w is IconButton && (w.tooltip ?? '').startsWith('Arsipkan draf '),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _arsipkanGagal(WidgetTester tester) async {
  await _arsipkanDialog(tester);
  await tester.enterText(
    find.byKey(const Key('isian-dialog')),
    'alasan yang sah',
  );
  await tester.tap(find.byKey(const Key('aksi-dialog')));
  await tester.pumpAndSettle();
}

LapisanUjiCrud _lapisanDraf({ArsipDrafService? arsip}) => LapisanUjiCrud(
  arsipDraf: arsip,
  tambahan: [historyServiceProvider.overrideWithValue(MockHistoryService())],
);

/// Layar yang dijalankan di MATRIKS lebar x skala huruf.
final List<KeadaanCrud> layarMatriksCrud = [
  KeadaanCrud(
    'hub',
    () => const PengelolaanDataScreen(),
    () => LapisanUjiCrud(),
  ),
  KeadaanCrud(
    'order-daftar',
    () => const OrderListScreen(),
    () => _lapisanOrder(),
  ),
  KeadaanCrud(
    'order-detail',
    () => const OrderDetailScreen(orderId: 801),
    () => _lapisanOrder(),
  ),
  KeadaanCrud(
    'order-form-buat',
    () => const OrderFormScreen(),
    () => _lapisanOrder(),
  ),
  KeadaanCrud(
    'order-form-buat-terisi',
    () => const OrderFormScreen(),
    () => _lapisanOrder(),
    sesudah: _formTerisi,
  ),
  KeadaanCrud(
    'order-form-ubah',
    () => const OrderFormScreen(orderId: 801),
    () => _lapisanOrder(),
  ),
  KeadaanCrud(
    'penugasan-papan',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(awal: penugasanBurukCrud),
    ),
  ),
  KeadaanCrud(
    'penugasan-ubah',
    () => PenugasanUbahScreen(penugasan: penugasanBurukCrud.first),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(awal: penugasanBurukCrud),
    ),
  ),
  KeadaanCrud(
    'kategori-daftar',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
  ),
  KeadaanCrud(
    'arsip-draf',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(
      arsipDraf: MockArsipDrafService(awal: arsipBurukCrud),
    ),
  ),
];

/// Keadaan lain (kosong, galat, memuat, dialog, lembar pemilih): diuji di
/// kombinasi ukuran terburuk, dan semuanya dipotret oleh harness PNG.
final List<KeadaanCrud> keadaanLainCrud = [
  KeadaanCrud(
    'order-memuat',
    () => const OrderListScreen(),
    () => _lapisanOrder(jeda: _jedaMemuat),
    menahan: true,
  ),
  KeadaanCrud(
    'order-kosong',
    () => const OrderListScreen(),
    () => _lapisanOrder(awal: const []),
  ),
  KeadaanCrud(
    'order-galat',
    () => const OrderListScreen(),
    () => _lapisanOrder(galat: const KoneksiException('x')),
  ),
  KeadaanCrud(
    'order-terkunci',
    () => const OrderListScreen(),
    () => _lapisanOrder(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
  ),
  KeadaanCrud(
    'order-hapus-dialog',
    () => const OrderListScreen(),
    () => _lapisanOrder(),
    sesudah: _hapusDialog,
  ),
  KeadaanCrud(
    'order-hapus-ditolak',
    () => const OrderListScreen(),
    () => _lapisanOrder(idBersesi: {801}),
    sesudah: _hapusDitolak,
  ),
  KeadaanCrud(
    'order-form-validasi',
    () => const OrderFormScreen(),
    () => _lapisanOrder(),
    sesudah: _simpanKosong,
  ),
  KeadaanCrud(
    'order-form-422',
    () => const OrderFormScreen(),
    () => LapisanUjiCrud(order: _Tolak422()),
    sesudah: _simpan422,
  ),
  KeadaanCrud(
    'order-form-memuat',
    () => const OrderFormScreen(orderId: 801),
    () => _lapisanOrder(jeda: _jedaMemuat),
    menahan: true,
  ),
  KeadaanCrud(
    'order-form-galat',
    () => const OrderFormScreen(orderId: 801),
    () => _lapisanOrder(galat: const KoneksiException('x')),
  ),
  KeadaanCrud(
    'order-pilih-pt',
    () => const OrderFormScreen(),
    () => _lapisanOrder(),
    sesudah: _bukaPemilihPt,
  ),
  KeadaanCrud(
    'order-pilih-alat',
    () => const OrderFormScreen(),
    () => _lapisanOrder(),
    sesudah: _bukaPemilihAlat,
  ),
  KeadaanCrud(
    'order-pilih-teknisi',
    () => const OrderFormScreen(),
    () => LapisanUjiCrud(
      order: _orderBuruk(),
      pengguna: MockPenggunaSaService(),
    ),
    sesudah: _bukaPemilihTeknisi,
  ),
  KeadaanCrud(
    'detail-memuat',
    () => const OrderDetailScreen(orderId: 801),
    () => _lapisanOrder(jeda: _jedaMemuat),
    menahan: true,
  ),
  // ----------------------------------------------------------- penugasan
  KeadaanCrud(
    'penugasan-memuat',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(jeda: _jedaMemuat),
    ),
    menahan: true,
  ),
  KeadaanCrud(
    'penugasan-kosong',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(penugasan: MockPenugasanKelolaService(awal: const [])),
  ),
  KeadaanCrud(
    'penugasan-galat',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(galat: const KoneksiException('x')),
    ),
  ),
  KeadaanCrud(
    'penugasan-terkunci',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
  ),
  KeadaanCrud(
    'penugasan-batal-dialog',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(awal: penugasanBurukCrud),
    ),
    sesudah: _batalDialog,
  ),
  KeadaanCrud(
    'penugasan-batal-pendek',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(awal: penugasanBurukCrud),
    ),
    sesudah: _batalPendek,
  ),
  KeadaanCrud(
    'penugasan-batal-ditolak',
    () => const PenugasanKelolaScreen(),
    () => LapisanUjiCrud(penugasan: _TolakBatal()),
    sesudah: _batalGagal,
  ),
  KeadaanCrud(
    'penugasan-ubah-validasi',
    () => PenugasanUbahScreen(penugasan: penugasanBurukCrud.first),
    () => LapisanUjiCrud(
      penugasan: MockPenugasanKelolaService(awal: penugasanBurukCrud),
    ),
    sesudah: _ubahKosongkan,
  ),
  KeadaanCrud(
    'penugasan-ubah-422',
    () => PenugasanUbahScreen(penugasan: penugasanBurukCrud.first),
    () => LapisanUjiCrud(penugasan: _TolakPenugasanUbah()),
    sesudah: _ubah422,
  ),
  // ------------------------------------------------------------ kategori
  KeadaanCrud(
    'kategori-memuat',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(kategori: MockKategoriKelolaService(jeda: _jedaMemuat)),
    menahan: true,
  ),
  KeadaanCrud(
    'kategori-kosong',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(kategori: MockKategoriKelolaService(awal: const [])),
  ),
  KeadaanCrud(
    'kategori-galat',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(galat: const KoneksiException('x')),
    ),
  ),
  KeadaanCrud(
    'kategori-terkunci',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
  ),
  KeadaanCrud(
    'kategori-tambah-dialog',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
    sesudah: _tambahKategori,
  ),
  KeadaanCrud(
    'kategori-tambah-kembar',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
    sesudah: _tambahKembar,
  ),
  KeadaanCrud(
    'kategori-ubah-dialog',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
    sesudah: _ubahNamaKategori,
  ),
  KeadaanCrud(
    'kategori-nonaktif-dialog',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
    sesudah: _nonaktifKategori,
  ),
  KeadaanCrud(
    'kategori-hapus-dialog',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(
      kategori: MockKategoriKelolaService(awal: kategoriBurukCrud),
    ),
    sesudah: _hapusKategori,
  ),
  KeadaanCrud(
    'kategori-hapus-dipakai',
    () => const KategoriKelolaScreen(),
    () => LapisanUjiCrud(kategori: _KategoriDipakai()),
    sesudah: _hapusKategoriDipakai,
  ),
  // ---------------------------------------------------------- arsip draf
  KeadaanCrud(
    'arsip-memuat',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(arsipDraf: MockArsipDrafService(jeda: _jedaMemuat)),
    menahan: true,
  ),
  KeadaanCrud(
    'arsip-kosong',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(arsipDraf: MockArsipDrafService(awal: const [])),
  ),
  KeadaanCrud(
    'arsip-galat',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(
      arsipDraf: MockArsipDrafService(galat: const KoneksiException('x')),
    ),
  ),
  KeadaanCrud(
    'arsip-terkunci',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
  ),
  KeadaanCrud(
    'arsip-pulihkan-dialog',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(arsipDraf: MockArsipDrafService(awal: arsipBurukCrud)),
    sesudah: _pulihkanDialog,
  ),
  KeadaanCrud(
    'arsip-pulihkan-gagal',
    () => const ArsipDrafScreen(),
    () => LapisanUjiCrud(arsipDraf: _PulihkanGagal()),
    sesudah: _pulihkanGagal,
  ),
  // -------------------------------------- LAYAR LAMA: kartu Draf + Arsipkan
  KeadaanCrud(
    'draf-kartu-arsipkan',
    () => const DrafScreen(),
    () => _lapisanDraf(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
  ),
  KeadaanCrud(
    'draf-arsipkan-dialog',
    () => const DrafScreen(),
    () => _lapisanDraf(),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
    sesudah: _arsipkanDialog,
  ),
  KeadaanCrud(
    'draf-arsipkan-gagal',
    () => const DrafScreen(),
    () => _lapisanDraf(arsip: _ArsipkanGagal()),
    token: tokenTeknisiCrud,
    izin: izinTeknisiCrud,
    sesudah: _arsipkanGagal,
  ),
];
