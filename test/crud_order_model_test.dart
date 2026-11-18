import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/order.dart';
import 'package:sidik_calibration/models/order_kelola.dart';

/// Model Order untuk kelola order (`OrderResource` / `OrderItemResource` di
/// repo API, dibaca 18 Nov 2026) dan bentuk kiriman `POST/PUT /orders`
/// (`OrderRequest`).
///
/// SUMBER bentuk JSON: `app/Http/Resources/OrderResource.php` dan
/// `OrderItemResource.php`. Tanggal ditulis server dengan
/// `toIso8601ZuluString()` pada zona aplikasi `Asia/Jakarta`, jadi
/// "16 Nov 2026" tiba sebagai `2026-11-15T17:00:00Z`.
const _order = <String, dynamic>{
  'id': 301,
  'nomor': 'ORD/2026/11/0003',
  'status': 'diproses',
  'tanggal_masuk': '2026-11-15T17:00:00Z',
  'tanggal_janji_selesai': '2026-11-29T17:00:00Z',
  'catatan': 'Alat dijemput kurir lab.',
  'pelanggan': {'id': 3, 'nama': 'PT Tirta Contoh Mandiri'},
  'diterima_oleh': {'id': 11, 'nama': 'Rina Master Data'},
  'jumlah_alat': 2,
  'items': [
    {
      'id': 1,
      'teknisi': {'id': 21, 'nama': 'Dedi Teknisi'},
      'kondisi_terima': 'Baik',
      'kelengkapan': 'Adaptor',
      'catatan': null,
      'alat': {
        'id': 14,
        'nama_alat': 'pH Meter Mettler Toledo',
        'serial_number': 'B628755900',
        'rentang_ukur': '0–14 pH',
      },
    },
    {
      'id': 2,
      'teknisi': null,
      'kondisi_terima': null,
      'kelengkapan': null,
      'catatan': null,
      'alat': {'id': 15, 'nama_alat': 'Turbidimeter Hach', 'serial_number': 'X'},
    },
  ],
};

void main() {
  group('OrderKalibrasi (field tambahan, aditif)', () {
    test('membaca pelanggan.id dan penerima dari respons server', () {
      final o = OrderKalibrasi.fromJson(_order);

      expect(o.id, 301);
      expect(o.nomor, 'ORD/2026/11/0003');
      expect(o.pelangganId, 3);
      expect(o.namaPelanggan, 'PT Tirta Contoh Mandiri');
      expect(o.diterimaOleh, 'Rina Master Data');
      expect(o.jumlahAlat, 2);
    });

    test('daftar tanpa diterima_oleh/pelanggan.id tidak melempar', () {
      final o = OrderKalibrasi.fromJson({
        'id': 1,
        'nomor': 'ORD/2026/11/0001',
        'status': 'baru',
        'pelanggan': {'nama': 'CV X'},
        'jumlah_alat': 1,
      });

      expect(o.pelangganId, isNull);
      expect(o.diterimaOleh, isNull);
      expect(o.items, isEmpty);
    });

    test('item membawa alat.id dan teknisi (null = belum dibagi)', () {
      final o = OrderKalibrasi.fromJson(_order);

      expect(o.items[0].alatId, 14);
      expect(o.items[0].teknisiId, 21);
      expect(o.items[0].sudahDitugaskan, isTrue);
      expect(o.items[1].alatId, 15);
      expect(o.items[1].sudahDitugaskan, isFalse);
    });
  });

  group('tanggalDariServer', () {
    test('16 Nov 00:00 WIB (15 Nov 17:00Z) tetap 16 Nov, bukan 15', () {
      expect(
        tanggalDariServer(DateTime.parse('2026-11-15T17:00:00Z')),
        DateTime(2026, 11, 16),
      );
    });

    test('tengah malam UTC (data uji) tetap pada tanggal yang sama', () {
      expect(
        tanggalDariServer(DateTime.utc(2026, 11, 16)),
        DateTime(2026, 11, 16),
      );
    });

    test('null tetap null', () => expect(tanggalDariServer(null), isNull));

    test('batas tahun: 31 Des 17:00Z menjadi 1 Jan WIB', () {
      expect(
        tanggalDariServer(DateTime.parse('2026-12-31T17:00:00Z')),
        DateTime(2027, 1, 1),
      );
    });
  });

  group('FormOrder.toJson', () {
    const alat = ItemOrderForm(
      alatId: 14,
      namaAlat: 'pH Meter',
      serialNumber: 'B1',
      teknisiId: 21,
      kondisiTerima: '  Baik  ',
      kelengkapan: '',
      catatan: ' ',
    );

    test('BUAT: customer_id ikut, status tidak, kolom kosong dikirim null', () {
      final badan = FormOrder(
        pelangganId: 3,
        tanggalMasuk: DateTime(2026, 11, 5),
        items: const [alat],
        catatan: '',
        status: StatusOrder.selesai,
      ).toJson(buat: true);

      expect(badan['customer_id'], 3);
      expect(badan.containsKey('status'), isFalse);
      expect(badan['tanggal_masuk'], '2026-11-05');
      expect(badan['tanggal_janji_selesai'], isNull);
      expect(badan['catatan'], isNull);
      expect(badan.containsKey('nomor'), isFalse, reason: 'nomor milik server');
      expect(badan['items'], [
        {
          'equipment_id': 14,
          'teknisi_id': 21,
          'kondisi_terima': 'Baik',
          'kelengkapan': null,
          'catatan': null,
        },
      ]);
    });

    test('UBAH: tanpa customer_id, status ikut, janji null mengosongkan', () {
      final badan = FormOrder(
        pelangganId: 3,
        tanggalMasuk: DateTime(2026, 11, 5),
        tanggalJanjiSelesai: null,
        items: const [alat],
        status: StatusOrder.dibatalkan,
        catatan: ' catatan ',
      ).toJson(buat: false);

      expect(badan.containsKey('customer_id'), isFalse);
      expect(badan['status'], 'dibatalkan');
      expect(badan.containsKey('tanggal_janji_selesai'), isTrue);
      expect(badan['tanggal_janji_selesai'], isNull);
      expect(badan['catatan'], 'catatan');
    });

    test('tanggal ditulis yyyy-MM-dd tanpa bergeser zona', () {
      expect(tanggalKirim(DateTime(2026, 1, 2)), '2026-01-02');
      expect(tanggalKirim(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('daftar status = empat nilai server', () {
      expect(StatusOrder.semua, ['baru', 'diproses', 'selesai', 'dibatalkan']);
    });
  });

  group('ItemOrderForm', () {
    test('dariItem menyalin baris tersimpan, null menjadi teks kosong', () {
      final o = OrderKalibrasi.fromJson(_order);
      final f = ItemOrderForm.dariItem(o.items[1]);

      expect(f.alatId, 15);
      expect(f.teknisiId, isNull);
      expect(f.kondisiTerima, '');
    });

    test('salin(teknisi: ...) bisa MELEPAS teknisi (id null)', () {
      final o = OrderKalibrasi.fromJson(_order);
      final f = ItemOrderForm.dariItem(o.items[0]);
      final lepas = f.salin(teknisi: (id: null, nama: null));

      expect(f.teknisiId, 21);
      expect(lepas.teknisiId, isNull);
      expect(lepas.toJson()['teknisi_id'], isNull);
    });

    test('salin tanpa argumen teknisi MEMPERTAHANKAN teknisi', () {
      final o = OrderKalibrasi.fromJson(_order);
      final f = ItemOrderForm.dariItem(o.items[0]).salin(catatan: 'x');

      expect(f.teknisiId, 21);
      expect(f.catatan, 'x');
    });
  });

  group('orderTerlambat (tanggal WIB, bukan instan UTC)', () {
    OrderKalibrasi order({String status = 'diproses', DateTime? janji}) =>
        OrderKalibrasi(
          id: 1,
          nomor: 'ORD/2026/11/0001',
          status: status,
          namaPelanggan: 'PT X',
          jumlahAlat: 1,
          tanggalJanjiSelesai: janji,
        );

    // Janji "30 Nov 2026" (WIB) tiba dari server sebagai 29 Nov 17:00Z.
    final janji30Nov = DateTime.parse('2026-11-29T17:00:00Z');

    test('sepanjang hari janji (30 Nov) belum terlambat', () {
      expect(
        orderTerlambat(order(janji: janji30Nov), sekarang: DateTime(2026, 11, 30, 23, 59)),
        isFalse,
      );
    });

    test('mulai sehari sesudah janji (1 Des) terlambat', () {
      expect(
        orderTerlambat(order(janji: janji30Nov), sekarang: DateTime(2026, 12, 1, 0, 1)),
        isTrue,
      );
    });

    test('selesai dan dibatalkan tidak pernah terlambat', () {
      final lama = DateTime(2027, 1, 1);
      for (final status in ['selesai', 'dibatalkan']) {
        expect(
          orderTerlambat(order(status: status, janji: janji30Nov), sekarang: lama),
          isFalse,
          reason: status,
        );
      }
    });

    test('tanpa janji tidak terlambat', () {
      expect(orderTerlambat(order(), sekarang: DateTime(2027, 1, 1)), isFalse);
    });
  });
}
