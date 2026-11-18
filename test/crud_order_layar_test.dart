import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/order.dart';
import 'package:sidik_calibration/models/order_kelola.dart';
import 'package:sidik_calibration/screens/crud_lab/order_detail_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_form_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/order_list_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/pengelolaan_data_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';

import 'support/crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart' show aturLayar, selesaikan;

/// Layar kelola Order: daftar, detail, form buat/ubah, hapus, dan gerbang izin.
///
/// Bentuk data dari `OrderResource` (lihat `crud_order_service_test.dart`);
/// aturan 422 dari `OrderRequest`/`OrderController` di repo API.

class _Bergalat extends MockOrderKelolaService {
  _Bergalat({super.awal, this.galatBuat, this.galatHapus});

  /// Dilempar `buat` (mis. 422 dari server) sekali pun datanya valid di klien.
  final Object? galatBuat;
  final Object? galatHapus;
  bool putusDaftar = false;

  @override
  Future<HalamanHasil<OrderKalibrasi>> daftar(
    String token, {
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    if (putusDaftar) throw const KoneksiException('putus');
    return super.daftar(token, status: status, cari: cari, halaman: halaman);
  }

  @override
  Future<OrderKalibrasi> buat(String token, FormOrder form) async {
    if (galatBuat != null) throw galatBuat!;
    return super.buat(token, form);
  }

  @override
  Future<void> hapus(String token, int id) async {
    if (galatHapus != null) throw galatHapus!;
    return super.hapus(token, id);
  }
}

Future<void> _buka(
  WidgetTester tester,
  Widget layar, {
  LapisanUjiCrud? lapisan,
  String token = tokenAdminCrud,
  Izin izin = izinAdminCrud,
  double lebar = 392,
  double tinggi = 852,
}) async {
  aturLayar(tester, lebar, tinggi);
  await tester.pumpWidget(
    bungkusCrud(layar, lapisan: lapisan, token: token, izin: izin),
  );
  await selesaikan(tester);
}

Future<void> _menu(WidgetTester tester, int id, String aksi) async {
  await ketukDi(tester, find.byKey(Key('menu-order-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(aksi));
  await tester.pumpAndSettle();
}

/// Isi form BUAT sampai siap simpan: PT Tirta (id 3) + satu alat (id 14).
Future<void> _isiFormBuat(WidgetTester tester) async {
  await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pt-3')));
  await tester.pumpAndSettle();
  await ketukDi(tester, find.byKey(const Key('tambah-alat')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('alat-14')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('tambah-alat-terpilih')));
  await tester.pumpAndSettle();
}

void main() {
  group('daftar order', () {
    testWidgets('admin: kartu berisi nomor, status, PT, jumlah alat, tanggal', (
      tester,
    ) async {
      await _buka(tester, const OrderListScreen());

      expect(find.text('ORD/2026/11/0003'), findsOneWidget);
      expect(find.text('PT Tirta Contoh Mandiri'), findsWidgets);
      expect(find.text('Diproses'), findsWidgets);
      expect(find.textContaining('2 alat'), findsOneWidget);
      expect(find.textContaining('Masuk 16 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('buat-order')), findsOneWidget);
      expect(find.byKey(const Key('menu-order-301')), findsOneWidget);
    });

    testWidgets('super admin mendapat semua aksi yang sama', (tester) async {
      await _buka(
        tester,
        const OrderListScreen(),
        token: tokenSuperAdminCrud,
        izin: izinSuperAdminCrud,
      );

      expect(find.byKey(const Key('buat-order')), findsOneWidget);
      expect(find.byKey(const Key('menu-order-301')), findsOneWidget);
    });

    for (final (nama, token, izin) in [
      ('teknisi', tokenTeknisiCrud, izinTeknisiCrud),
      ('viewer', 'mock-token-3', izinViewerCrud),
    ]) {
      testWidgets('$nama: terkunci, tanpa tombol dan tanpa data', (tester) async {
        final lapisan = LapisanUjiCrud(order: MockOrderKelolaService());
        await _buka(
          tester,
          const OrderListScreen(),
          lapisan: lapisan,
          token: token,
          izin: izin,
        );

        expect(
          find.text('Akun Anda tidak punya izin untuk bagian ini.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('buat-order')), findsNothing);
        expect(find.byKey(const Key('menu-order-301')), findsNothing);
        expect(find.text('ORD/2026/11/0003'), findsNothing);
      });
    }

    testWidgets('kosong: kalimat kosong, bukan layar putih', (tester) async {
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: MockOrderKelolaService(awal: const [])),
      );

      expect(find.text('Belum ada order.'), findsOneWidget);
      expect(find.byKey(const Key('buat-order')), findsOneWidget);
    });

    testWidgets('pencarian tanpa hasil memakai kalimat yang berbeda', (
      tester,
    ) async {
      await _buka(tester, const OrderListScreen());
      await tester.enterText(find.byKey(const Key('cari-order')), 'tidak-ada');
      await tester.pump(const Duration(milliseconds: 450));
      await selesaikan(tester);

      expect(
        find.text('Tidak ada order yang cocok dengan pencarian ini.'),
        findsOneWidget,
      );
    });

    testWidgets('galat: kalimat + Coba lagi yang benar-benar memuat ulang', (
      tester,
    ) async {
      final layanan = _Bergalat()..putusDaftar = true;
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      expect(find.text('Daftar order belum bisa dimuat.'), findsOneWidget);

      layanan.putusDaftar = false;
      await tester.tap(find.text('Coba lagi'));
      await selesaikan(tester);

      expect(find.text('Daftar order belum bisa dimuat.'), findsNothing);
      expect(find.text('ORD/2026/11/0003'), findsOneWidget);
    });

    testWidgets('saringan status memanggil server dengan status itu', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await tester.tap(find.byKey(const Key('saring-selesai')));
      await selesaikan(tester);

      expect(layanan.catatan.last, contains('status=selesai'));
      expect(find.text('ORD/2026/10/0009'), findsOneWidget);
      expect(find.text('ORD/2026/11/0003'), findsNothing);
    });

    testWidgets('banyak halaman: tombol muat lebih banyak menambah daftar', (
      tester,
    ) async {
      final banyak = [
        for (var i = 0; i < 20; i++)
          OrderKalibrasi(
            id: 700 + i,
            nomor: 'ORD/2026/09/${(i + 1).toString().padLeft(4, '0')}',
            status: 'baru',
            namaPelanggan: 'PT Banyak $i',
            jumlahAlat: 1,
          ),
      ];
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(
          order: MockOrderKelolaService(awal: banyak, ukuranHalaman: 8),
        ),
      );

      expect(find.text('ORD/2026/09/0001'), findsOneWidget);
      await ketukDi(tester, find.text('Muat lebih banyak'));
      await selesaikan(tester);

      await tester.scrollUntilVisible(
        find.text('ORD/2026/09/0012'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ORD/2026/09/0012'), findsOneWidget);
    });
  });

  group('hapus order (konfirmasi tegas)', () {
    testWidgets('batal: order tetap, tidak ada panggilan hapus', (tester) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await _menu(tester, 302, 'Hapus');
      expect(find.text('Hapus order ORD/2026/11/0002?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(layanan.catatan.where((c) => c.startsWith('hapus')), isEmpty);
      expect(find.text('ORD/2026/11/0002'), findsOneWidget);
    });

    testWidgets('konfirmasi: order terhapus, daftar diambil ulang', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await _menu(tester, 302, 'Hapus');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(layanan.catatan, contains('hapus 302'));
      expect(find.text('ORD/2026/11/0002'), findsNothing);
      expect(find.text('Order dihapus.'), findsOneWidget);
    });

    testWidgets(
      'order bersesi ditolak server: dialog TETAP terbuka dengan alasan yang jelas',
      (tester) async {
        final layanan = MockOrderKelolaService(idBersesi: {301});
        await _buka(
          tester,
          const OrderListScreen(),
          lapisan: LapisanUjiCrud(order: layanan),
        );

        await _menu(tester, 301, 'Hapus');
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('galat-dialog')), findsOneWidget);
        expect(
          find.textContaining('tidak bisa dihapus. Ubah statusnya menjadi Dibatalkan'),
          findsWidgets,
        );
        // Dialog masih ada dan order masih di daftar.
        expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.text('ORD/2026/11/0003'), findsOneWidget);
      },
    );

    testWidgets('500 dari server: kalimat jelas, bukan angka mentah', (
      tester,
    ) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatHapus: const ApiException('Server Error', status: 500),
      );
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await _menu(tester, 302, 'Hapus');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Server sedang bermasalah'),
        findsOneWidget,
      );
    });

    testWidgets('403 saat hapus: kalimat izin, dialog terbuka', (tester) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatHapus: const ApiException('x', status: 403),
      );
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await _menu(tester, 302, 'Hapus');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.text('Akun Anda tidak boleh melakukan aksi ini.'),
        findsOneWidget,
      );
    });

    testWidgets('404 (sudah dihapus orang lain): kalimat "mungkin sudah berubah"', (
      tester,
    ) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatHapus: const ApiException('x', status: 404),
      );
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      await _menu(tester, 302, 'Hapus');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(find.textContaining('mungkin sudah berubah'), findsOneWidget);
    });
  });

  group('form BUAT order', () {
    // [tinggi] besar bila yang diuji ada di dasar formulir (daftar malas tidak
    // membangun isi yang jauh di luar layar).
    Future<void> bukaForm(
      WidgetTester tester, {
      LapisanUjiCrud? lapisan,
      double tinggi = 852,
    }) async {
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: lapisan,
        tinggi: tinggi,
      );
      await ketukDi(tester, find.byKey(const Key('buat-order')));
      await tester.pumpAndSettle();
    }

    testWidgets('simpan kosong: pelanggan dan alat wajib, tidak menembak server', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await bukaForm(tester, lapisan: LapisanUjiCrud(order: layanan));

      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih pelanggan dulu.'), findsOneWidget);
      expect(find.text('Tambahkan minimal satu alat.'), findsOneWidget);
      expect(layanan.catatan.where((c) => c.startsWith('buat')), isEmpty);
    });

    testWidgets('tambah alat terkunci sampai PT dipilih', (tester) async {
      await bukaForm(tester);

      expect(
        find.text('Pilih pelanggan dulu untuk menambah alat milik PT itu.'),
        findsOneWidget,
      );
      await ketukDi(tester, find.byKey(const Key('tambah-alat')));
      await tester.pumpAndSettle();
      // Tombol nonaktif: pemilih alat tidak terbuka.
      expect(find.byKey(const Key('cari-sheet')), findsNothing);
    });

    testWidgets('alur lengkap: PT → alat milik PT itu → simpan → nomor dari server', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await bukaForm(tester, lapisan: LapisanUjiCrud(order: layanan));
      await _isiFormBuat(tester);

      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      final badan = layanan.badanTerakhir!;
      expect(badan['customer_id'], 3);
      expect((badan['items'] as List).single['equipment_id'], 14);
      expect(badan.containsKey('nomor'), isFalse);
      // Kembali ke daftar dengan kabar nomor dari server.
      expect(find.text('Order ORD/2026/11/0004 dibuat.'), findsOneWidget);
      expect(find.byKey(const Key('simpan-order')), findsNothing);
    });

    testWidgets('pemilih alat hanya menawarkan alat milik PT yang dipilih', (
      tester,
    ) async {
      await bukaForm(tester);
      await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pt-4')));
      await tester.pumpAndSettle();
      await ketukDi(tester, find.byKey(const Key('tambah-alat')));
      await tester.pumpAndSettle();

      // PT 4 memiliki alat 12 dan 13, BUKAN 14 dan 15 milik PT 3.
      expect(find.byKey(const Key('alat-12')), findsOneWidget);
      expect(find.byKey(const Key('alat-13')), findsOneWidget);
      expect(find.byKey(const Key('alat-14')), findsNothing);
    });

    testWidgets('ganti PT mengosongkan alat dan memberi tahu, bukan diam-diam', (
      tester,
    ) async {
      await bukaForm(tester);
      await _isiFormBuat(tester);
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);

      await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pt-4')));
      await tester.pumpAndSettle();

      expect(find.text('pH Meter Mettler Toledo'), findsNothing);
      expect(
        find.text('Daftar alat dikosongkan karena pelanggan diganti.'),
        findsOneWidget,
      );
    });

    testWidgets('422 dari server dipetakan ke baris alat dan kalimat umum', (
      tester,
    ) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatBuat: const ApiException(
          'x',
          status: 422,
          body: {
            'message': 'x',
            'errors': {
              'items.0.equipment_id': [
                'Alat "pH Meter" terdaftar atas nama pelanggan lain.',
              ],
              'tanggal_janji_selesai': [
                'Tanggal janji selesai nggak boleh lebih awal dari tanggal masuk.',
              ],
            },
          },
        ),
      );
      await bukaForm(
        tester,
        lapisan: LapisanUjiCrud(order: layanan),
        tinggi: 2400,
      );
      await _isiFormBuat(tester);
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(
        find.text('Alat "pH Meter" terdaftar atas nama pelanggan lain.'),
        findsOneWidget,
      );
      expect(
        find.text('Tanggal janji selesai nggak boleh lebih awal dari tanggal masuk.'),
        findsOneWidget,
      );
      expect(
        find.text('Order belum tersimpan. Periksa isian yang bertanda galat.'),
        findsOneWidget,
      );
      // Form tetap terbuka dengan isian utuh.
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
    });

    testWidgets('jaringan putus saat buat: peringatan "periksa daftar dulu"', (
      tester,
    ) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatBuat: const KoneksiException('putus'),
      );
      await bukaForm(tester, lapisan: LapisanUjiCrud(order: layanan));
      await _isiFormBuat(tester);
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('periksa daftar sebelum membuatnya lagi'),
        findsOneWidget,
      );
    });

    testWidgets('500 saat buat: kalimat jelas dan isian tidak hilang', (
      tester,
    ) async {
      final layanan = _Bergalat(
        awal: MockOrderKelolaService.contoh,
        galatBuat: const ApiException('Server Error', status: 500),
      );
      await bukaForm(tester, lapisan: LapisanUjiCrud(order: layanan));
      await _isiFormBuat(tester);
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server sedang bermasalah'), findsOneWidget);
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
    });

    testWidgets('catatan > 1000 karakter ditolak di klien', (tester) async {
      final layanan = MockOrderKelolaService();
      await bukaForm(
        tester,
        lapisan: LapisanUjiCrud(order: layanan),
        tinggi: 2400,
      );
      await _isiFormBuat(tester);
      await tester.enterText(find.byKey(const Key('isi-catatan')), 'x' * 1020);
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(find.text('Catatan maksimal 1000 karakter.'), findsOneWidget);
      expect(layanan.catatan.where((c) => c.startsWith('buat')), isEmpty);
    });

    testWidgets('teknisi pada baris alat: pilih lalu terkirim sebagai teknisi_id', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await bukaForm(tester, lapisan: LapisanUjiCrud(order: layanan));
      await _isiFormBuat(tester);

      await ketukDi(tester, find.text('Belum dibagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teknisi-21')));
      await tester.pumpAndSettle();
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(
        (layanan.badanTerakhir!['items'] as List).single['teknisi_id'],
        21,
      );
    });

    testWidgets('PT tidak ditemukan / galat memuat PT: kalimat, bukan kosong', (
      tester,
    ) async {
      await bukaForm(
        tester,
        lapisan: LapisanUjiCrud(pelangganGalat: const KoneksiException('x')),
      );
      await ketukDi(tester, find.byKey(const Key('kotak-pelanggan')));
      await tester.pumpAndSettle();

      expect(find.text('Daftar pelanggan belum bisa dimuat.'), findsOneWidget);
    });
  });

  group('form UBAH order', () {
    testWidgets('memuat detail; PT dikunci; status dikirim, customer_id tidak', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderFormScreen(orderId: 301),
        lapisan: LapisanUjiCrud(order: layanan),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ubah order'), findsWidgets);
      expect(find.text('PT Tirta Contoh Mandiri'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byKey(const Key('status-dibatalkan')), findsOneWidget);

      await ketukDi(tester, find.byKey(const Key('status-dibatalkan')));
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      final badan = layanan.badanTerakhir!;
      expect(badan['status'], 'dibatalkan');
      expect(badan.containsKey('customer_id'), isFalse);
      expect((badan['items'] as List), hasLength(2));
      expect((badan['items'] as List).first['teknisi_id'], 21);
    });

    testWidgets('janji selesai sebelum tanggal masuk ditolak di klien', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService(
        awal: [
          OrderKalibrasi(
            id: 901,
            nomor: 'ORD/2026/11/0099',
            status: 'baru',
            namaPelanggan: 'PT Tirta Contoh Mandiri',
            pelangganId: 3,
            jumlahAlat: 1,
            tanggalMasuk: DateTime.utc(2026, 11, 20),
            tanggalJanjiSelesai: DateTime.utc(2026, 11, 10),
            items: const [
              OrderItem(
                id: 1,
                alatId: 14,
                namaAlat: 'pH Meter',
                serialNumber: 'B1',
              ),
            ],
          ),
        ],
      );
      await _buka(
        tester,
        const OrderFormScreen(orderId: 901),
        lapisan: LapisanUjiCrud(order: layanan),
      );
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(
        find.text('Janji selesai tidak boleh sebelum tanggal masuk.'),
        findsOneWidget,
      );
      expect(layanan.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('membuang semua alat: ditolak di klien (minimal satu)', (
      tester,
    ) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderFormScreen(orderId: 302),
        lapisan: LapisanUjiCrud(order: layanan),
      );
      await ketukDi(tester, find.byKey(const Key('buang-13')));
      await tester.pumpAndSettle();
      await ketukDi(tester, find.byKey(const Key('simpan-order')));
      await tester.pumpAndSettle();

      expect(find.text('Tambahkan minimal satu alat.'), findsOneWidget);
      expect(layanan.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('catatan sesi kalibrasi tampil hanya di mode ubah', (
      tester,
    ) async {
      await _buka(tester, const OrderFormScreen(orderId: 301));
      expect(
        find.textContaining('sudah masuk kalibrasi tetap berada di order'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _buka(tester, const OrderFormScreen());
      expect(
        find.textContaining('sudah masuk kalibrasi tetap berada di order'),
        findsNothing,
      );
    });

    testWidgets('detail gagal dimuat: kalimat + Coba lagi', (tester) async {
      final layanan = _Bergalat(awal: const []);
      await _buka(
        tester,
        const OrderFormScreen(orderId: 301),
        lapisan: LapisanUjiCrud(order: layanan),
      );

      // Order 301 tidak ada di mock kosong → 404.
      expect(find.text('Order ini belum bisa dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('teknisi tidak melihat formulir (gerbang izin di layar)', (
      tester,
    ) async {
      await _buka(
        tester,
        const OrderFormScreen(),
        token: tokenTeknisiCrud,
        izin: izinTeknisiCrud,
      );

      expect(find.byKey(const Key('simpan-order')), findsNothing);
      expect(
        find.text('Akun Anda tidak punya izin untuk bagian ini.'),
        findsOneWidget,
      );
    });
  });

  group('detail order', () {
    testWidgets('menampilkan alat, teknisi, kondisi; admin bisa Ubah dan Hapus', (
      tester,
    ) async {
      await _buka(tester, const OrderDetailScreen(orderId: 301));

      expect(find.text('ORD/2026/11/0003'), findsOneWidget);
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(find.text('Teknisi: Dedi Teknisi'), findsOneWidget);
      expect(find.text('Belum dibagi'), findsOneWidget);
      expect(find.textContaining('Baik, ada goresan di casing.'), findsOneWidget);
      expect(find.byKey(const Key('ubah-order')), findsOneWidget);
      expect(find.byKey(const Key('hapus-order')), findsOneWidget);
    });

    testWidgets('teknisi hanya membaca: tanpa Ubah/Hapus', (tester) async {
      await _buka(
        tester,
        const OrderDetailScreen(orderId: 301),
        token: tokenTeknisiCrud,
        izin: izinTeknisiCrud,
      );

      expect(find.text('ORD/2026/11/0003'), findsOneWidget);
      expect(find.byKey(const Key('ubah-order')), findsNothing);
      expect(find.byKey(const Key('hapus-order')), findsNothing);
    });

    testWidgets('hapus dari detail menutup layar', (tester) async {
      final layanan = MockOrderKelolaService();
      await _buka(
        tester,
        const OrderListScreen(),
        lapisan: LapisanUjiCrud(order: layanan),
      );
      await tester.tap(find.byKey(const Key('kartu-order-302')));
      await tester.pumpAndSettle();
      await ketukDi(tester, find.byKey(const Key('hapus-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(layanan.catatan, contains('hapus 302'));
      expect(find.byKey(const Key('hapus-order')), findsNothing);
      expect(find.text('ORD/2026/11/0002'), findsNothing);
    });
  });

  group('hub pengelolaan data', () {
    testWidgets('admin melihat pintu Order dan bisa membukanya', (tester) async {
      await _buka(tester, const PengelolaanDataScreen());

      expect(find.byKey(const Key('pintu-order')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pintu-order')));
      await tester.pumpAndSettle();
      expect(find.text('ORD/2026/11/0003'), findsOneWidget);
    });

    testWidgets('teknisi: hub terkunci', (tester) async {
      await _buka(
        tester,
        const PengelolaanDataScreen(),
        token: tokenTeknisiCrud,
        izin: izinTeknisiCrud,
      );

      expect(find.byKey(const Key('pintu-order')), findsNothing);
      expect(
        find.text('Akun Anda tidak punya izin untuk bagian ini.'),
        findsOneWidget,
      );
    });
  });
}
