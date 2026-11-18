import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/anggota_pelanggan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/screens/super_admin/ganti_sandi_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_detail_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_sa_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengelolaan_super_admin_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_form_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pengguna_screen.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/ganti_sandi_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';

import 'support/super_admin_uji.dart';

/// Layar pengelolaan Super Admin: gerbang peran, daftar/kosong/galat, dialog
/// konfirmasi, PIC utama terakhir, cabut anggota, ganti sandi.
///
/// Data = `Mock*Service` bawaan repo, yang bentuknya disalin dari contoh
/// kontrak `docs/perintah-frontend-super-admin.md` (repo API). Tidak ada
/// angka kalibrasi di sini, jadi tidak ada angka acuan workbook.
class _PenggunaBasi extends MockPenggunaSaService {
  _PenggunaBasi(this._galat);
  final ApiException _galat;

  @override
  Future<User> nonaktifkan(String token, int id, {required String alasan}) =>
      Future.error(_galat);
}

class _AnggotaPicTerakhir extends MockAnggotaPelangganService {
  @override
  Future<AnggotaPelanggan> cabut(
    String token,
    int customerId,
    int anggotaId, {
    required String alasan,
  }) => Future.error(
    const ApiException(
      'x',
      status: 422,
      body: {'kode': 'pic_utama_terakhir', 'message': 'x'},
    ),
  );
}

void main() {
  setUpAll(muatFontSa);

  Future<void> pasang(
    WidgetTester tester,
    Widget layar, {
    LapisanUjiSa? lapisan,
    String token = tokenSuperAdmin,
    Izin izin = izinSuperAdmin,
    double lebar = 392,
    double tinggi = 1400,
  }) async {
    aturLayar(tester, lebar, tinggi);
    await tester.pumpWidget(
      bungkusSa(layar, lapisan: lapisan, token: token, izin: izin),
    );
    await selesaikan(tester);
  }

  Future<void> bukaMenu(WidgetTester tester, int id, String aksi) async {
    await tester.tap(find.byKey(Key('menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(aksi));
    await tester.pumpAndSettle();
  }

  Finder dalamDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  group('gerbang peran: satu baris di Kelola lab', () {
    const judul = 'Pengelolaan Super Admin';

    testWidgets('super admin dengan izin server: barisnya ada', (tester) async {
      await pasang(tester, const KelolaLabScreen(), tinggi: 2200);
      expect(find.text(judul), findsOneWidget);
    });

    testWidgets('admin (Master Data): TIDAK ada, walau izin anggota terbuka', (
      tester,
    ) async {
      await pasang(
        tester,
        const KelolaLabScreen(),
        token: tokenAdmin,
        izin: izinAdmin,
        tinggi: 2200,
      );
      expect(find.text(judul), findsNothing);
      // Pintu lama tetap ada: layar lama tidak berubah.
      expect(find.text('Data Teknisi'), findsOneWidget);
    });

    testWidgets('teknisi: TIDAK ada', (tester) async {
      await pasang(
        tester,
        const KelolaLabScreen(),
        token: tokenTeknisi,
        izin: izinTeknisi,
        tinggi: 2200,
      );
      expect(find.text(judul), findsNothing);
    });

    testWidgets(
      'izin server kosong (gagal dimuat): TIDAK ada — aturan peran lama tidak '
      'boleh menyalakan menu baru',
      (tester) async {
        await pasang(
          tester,
          const KelolaLabScreen(),
          izin: Izin.kosong,
          tinggi: 2200,
        );
        expect(find.text(judul), findsNothing);
      },
    );

    testWidgets('mengetuk baris membuka hub', (tester) async {
      await pasang(tester, const KelolaLabScreen(), tinggi: 2200);
      await tester.ensureVisible(find.text(judul));
      await tester.tap(find.text(judul));
      await tester.pumpAndSettle();
      expect(find.byType(PengelolaanSuperAdminScreen), findsOneWidget);
    });
  });

  group('hub Pengelolaan Super Admin', () {
    testWidgets('super admin: tiga pintu, masing-masing membuka layarnya', (
      tester,
    ) async {
      await pasang(tester, const PengelolaanSuperAdminScreen());
      expect(find.text('Pengguna'), findsOneWidget);
      expect(find.text('Pelanggan & anggota'), findsOneWidget);
      expect(find.text('Ganti sandi saya'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pintu-ganti-sandi')));
      await tester.pumpAndSettle();
      expect(find.byType(GantiSandiScreen), findsOneWidget);
    });

    testWidgets('akun tanpa izin yang membuka hub langsung: terkunci', (
      tester,
    ) async {
      await pasang(
        tester,
        const PengelolaanSuperAdminScreen(),
        token: tokenTeknisi,
        izin: izinTeknisi,
      );
      expect(
        find.text('Layar ini hanya untuk akun yang diberi izin oleh server.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pintu-pengguna')), findsNothing);
      expect(find.byKey(const Key('pintu-ganti-sandi')), findsNothing);
    });
  });

  group('Pengguna: daftar', () {
    testWidgets('memuat dulu (kerangka), lalu menampilkan semua peran', (
      tester,
    ) async {
      aturLayar(tester, 392, 1400);
      final lapisan = LapisanUjiSa(
        pengguna: MockPenggunaSaService(jeda: const Duration(seconds: 1)),
      );
      await tester.pumpWidget(
        bungkusSa(const PenggunaScreen(), lapisan: lapisan),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Rina Master Data'), findsNothing);
      expect(find.byType(Card), findsWidgets, reason: 'kerangka kartu');

      await tester.pump(const Duration(seconds: 2));
      await selesaikan(tester);
      expect(find.text('Rina Master Data'), findsOneWidget);
      expect(find.text('Dedi Teknisi'), findsOneWidget);
      expect(find.text('Eko Prasetyo'), findsOneWidget);
      expect(find.text('Lina Wulandari'), findsOneWidget);
    });

    testWidgets('kosong: kalimat saringan tanpa hasil', (tester) async {
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: MockPenggunaSaService(awal: [])),
      );
      expect(
        find.text('Tidak ada pengguna yang cocok dengan saringan ini.'),
        findsOneWidget,
      );
    });

    testWidgets('galat: kalimat gagal + Coba lagi memuat ulang', (
      tester,
    ) async {
      final layanan = MockPenggunaSaService(
        galat: const KoneksiException('Server nggak nyaut.'),
      );
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      expect(find.text('Daftar pengguna belum bisa dimuat.'), findsOneWidget);
      final sebelum = layanan.catatan.length;

      await tester.tap(find.text('Coba lagi'));
      await selesaikan(tester);
      expect(layanan.catatan.length, greaterThan(sebelum));
    });

    testWidgets('saringan peran & status dikirim ke server', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Admin'));
      await selesaikan(tester);
      expect(layanan.catatan.last, contains('peran=admin'));
      expect(find.text('Rina Master Data'), findsOneWidget);
      expect(find.text('Dedi Teknisi'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Semua peran'));
      await selesaikan(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Nonaktif'));
      await selesaikan(tester);
      expect(layanan.catatan.last, contains('status=nonaktif'));
      expect(find.text('Lina Wulandari'), findsOneWidget);
    });

    testWidgets('cari: ditunda 400 ms lalu dikirim sebagai search', (
      tester,
    ) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      final awal = layanan.catatan.length;

      await tester.enterText(find.byKey(const Key('cari-pengguna')), 'dedi');
      await tester.pump(const Duration(milliseconds: 200));
      expect(layanan.catatan.length, awal, reason: 'belum lewat 400 ms');

      await tester.pump(const Duration(milliseconds: 300));
      await selesaikan(tester);
      expect(layanan.catatan.last, contains('cari=dedi'));
      expect(find.text('Dedi Teknisi'), findsOneWidget);
      expect(find.text('Rina Master Data'), findsNothing);
    });

    testWidgets('paginasi: Muat lebih banyak menambah, tidak mengganti', (
      tester,
    ) async {
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(
          pengguna: MockPenggunaSaService(ukuranHalaman: 2),
        ),
      );
      expect(find.text('Rina Master Data'), findsOneWidget);
      expect(find.text('Eko Prasetyo'), findsNothing);

      await tester.ensureVisible(find.text('Muat lebih banyak'));
      await tester.tap(find.text('Muat lebih banyak'));
      await selesaikan(tester);

      expect(find.text('Rina Master Data'), findsOneWidget);
      expect(find.text('Eko Prasetyo'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsNothing);
    });

    testWidgets('daftar tidak punya tombol Hapus di mana pun', (tester) async {
      await pasang(tester, const PenggunaScreen());
      expect(find.textContaining('Hapus'), findsNothing);
      await tester.tap(find.byKey(const Key('menu-21')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hapus'), findsNothing);
    });

    testWidgets('akun tanpa izin melihat pengguna: terkunci', (tester) async {
      await pasang(
        tester,
        const PenggunaScreen(),
        token: tokenTeknisi,
        izin: izinTeknisi,
      );
      expect(
        find.text('Layar ini hanya untuk akun yang diberi izin oleh server.'),
        findsOneWidget,
      );
    });
  });

  group('Pengguna: aksi per peran', () {
    testWidgets('super admin: menu aktif memuat Nonaktifkan; nonaktif memuat '
        'Aktifkan kembali', (tester) async {
      await pasang(tester, const PenggunaScreen());

      await tester.tap(find.byKey(const Key('menu-21')));
      await tester.pumpAndSettle();
      expect(find.text('Ubah data'), findsOneWidget);
      expect(find.text('Setel ulang sandi'), findsOneWidget);
      expect(find.text('Nonaktifkan akun'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu-23')));
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan kembali'), findsOneWidget);
      expect(find.text('Nonaktifkan akun'), findsNothing);
    });

    testWidgets(
      'admin (Master Data): tidak ada Nonaktifkan/Aktifkan, hanya aksi lama',
      (tester) async {
        await pasang(
          tester,
          const PenggunaScreen(),
          token: tokenAdmin,
          izin: izinAdmin,
        );

        await tester.tap(find.byKey(const Key('menu-21')));
        await tester.pumpAndSettle();
        expect(find.text('Ubah data'), findsOneWidget);
        expect(find.text('Setel ulang sandi'), findsOneWidget);
        expect(find.text('Nonaktifkan akun'), findsNothing);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        // Akun nonaktif: menunya kosong → tidak ada tombol ⋮ sama sekali
        // kecuali "Ubah data" (yang selalu ada).
        await tester.tap(find.byKey(const Key('menu-23')));
        await tester.pumpAndSettle();
        expect(find.text('Aktifkan kembali'), findsNothing);
      },
    );

    testWidgets('nonaktifkan: alasan wajib 3-500, tidak memanggil server bila '
        'kosong, sukses menyegarkan daftar', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );

      await bukaMenu(tester, 21, 'Nonaktifkan akun');
      expect(find.text('Nonaktifkan Dedi Teknisi?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 3 karakter.'), findsOneWidget);
      expect(layanan.catatan.any((c) => c.startsWith('nonaktifkan')), isFalse);

      await tester.enterText(find.byKey(const Key('isian-dialog')), 'ab');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 3 karakter.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Resign per 15 Nov',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await selesaikan(tester);

      expect(layanan.catatan, contains('nonaktifkan 21 "Resign per 15 Nov"'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Akun dinonaktifkan.'), findsOneWidget);
    });

    testWidgets('nonaktifkan ditolak server (sudah_nonaktif): dialog tetap '
        'terbuka, alasan tidak hilang, kalimat menyebut jalan keluarnya', (
      tester,
    ) async {
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(
          pengguna: _PenggunaBasi(
            const ApiException(
              'Sudah nonaktif.',
              status: 422,
              body: {'kode': 'sudah_nonaktif', 'message': 'Sudah nonaktif.'},
            ),
          ),
        ),
      );

      await bukaMenu(tester, 21, 'Nonaktifkan akun');
      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Alasan saya yang panjang',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Akun ini sudah nonaktif. Daftar dimuat ulang.'),
        findsOneWidget,
      );
      expect(find.text('Alasan saya yang panjang'), findsOneWidget);
    });

    testWidgets('nonaktifkan 403 (server menolak): pesan server tampil', (
      tester,
    ) async {
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(
          pengguna: _PenggunaBasi(
            const ApiException(
              'Kamu nggak punya akses ke sini.',
              status: 403,
              body: {'message': 'Kamu nggak punya akses ke sini.'},
            ),
          ),
        ),
      );
      await bukaMenu(tester, 21, 'Nonaktifkan akun');
      await tester.enterText(find.byKey(const Key('isian-dialog')), 'abc');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Kamu nggak punya akses ke sini.'), findsOneWidget);
    });

    testWidgets('Batal pada dialog tidak memanggil server', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      await bukaMenu(tester, 21, 'Nonaktifkan akun');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(layanan.catatan.any((c) => c.startsWith('nonaktifkan')), isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('aktifkan kembali: alasan boleh kosong', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      await bukaMenu(tester, 23, 'Aktifkan kembali');
      expect(find.text('Aktifkan kembali Lina Wulandari?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await selesaikan(tester);

      expect(layanan.catatan, contains('aktifkan 23'));
      expect(find.text('Akun diaktifkan kembali.'), findsOneWidget);
    });

    testWidgets('setel ulang sandi: pendek ditolak di layar; sandi tidak '
        'pernah tercatat', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );

      await bukaMenu(tester, 21, 'Setel ulang sandi');
      final kolom = dalamDialog(find.byType(TextField));
      await tester.enterText(kolom, 'pendek');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Sandi minimal 8 karakter.'), findsOneWidget);
      expect(layanan.catatan.any((c) => c.startsWith('setelUlang')), isFalse);

      await tester.enterText(kolom, 'rahasia-baru-88');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await selesaikan(tester);

      expect(layanan.catatan, contains('setelUlangSandi 21'));
      expect(
        layanan.catatan.any((c) => c.contains('rahasia-baru-88')),
        isFalse,
      );
      expect(find.textContaining('rahasia-baru-88'), findsNothing);
      expect(
        find.text('Sandi Dedi Teknisi sudah disetel ulang.'),
        findsOneWidget,
      );
    });

    testWidgets('pendaftar pending: Setujui memilih peran; tombol bernama', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );

      // Tombol bernama: terbaca "Setujui Eko Prasetyo" di pembaca layar.
      expect(find.bySemanticsLabel('Setujui Eko Prasetyo'), findsOneWidget);
      handle.dispose();

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teknisi').last);
      await selesaikan(tester);
      expect(layanan.catatan, contains('setujui 22 teknisi'));

      // Eko kini aktif; Tolak diuji pada pendaftar lain.
    });

    testWidgets(
      'tolak pendaftar: dialog konfirmasi, Batal tidak memanggil server',
      (tester) async {
        final layanan = MockPenggunaSaService();
        await pasang(
          tester,
          const PenggunaScreen(),
          lapisan: LapisanUjiSa(pengguna: layanan),
        );

        await tester.tap(find.text('Tolak'));
        await tester.pumpAndSettle();
        expect(find.text('Tolak Eko Prasetyo?'), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(layanan.catatan.any((c) => c.startsWith('tolak')), isFalse);

        await tester.tap(find.text('Tolak'));
        await tester.pumpAndSettle();
        await tester.tap(dalamDialog(find.text('Tolak')));
        await selesaikan(tester);
        expect(layanan.catatan, contains('tolak 22'));
      },
    );
  });

  group('Pengguna: formulir tambah dan ubah', () {
    Future<void> isi(
      WidgetTester tester, {
      String nama = 'Rina Baru',
      String id = 'SDK-0300',
      String email = 'rina.baru@lab.test',
      String sandi = 'sandiawal-88',
      String ulang = 'sandiawal-88',
    }) async {
      final kolom = find.byType(TextField);
      await tester.enterText(kolom.at(0), nama);
      await tester.enterText(kolom.at(1), id);
      await tester.enterText(kolom.at(2), email);
      await tester.enterText(kolom.at(4), sandi);
      await tester.enterText(kolom.at(5), ulang);
    }

    testWidgets('super admin: dua pilihan peran (Admin & Teknisi)', (
      tester,
    ) async {
      await pasang(tester, const PenggunaFormScreen());
      expect(find.byKey(const Key('peran-admin')), findsOneWidget);
      expect(find.byKey(const Key('peran-teknisi')), findsOneWidget);
    });

    testWidgets(
      'admin (Master Data): hanya Teknisi — tidak bisa membuat admin',
      (tester) async {
        await pasang(
          tester,
          const PenggunaFormScreen(),
          token: tokenAdmin,
          izin: izinAdmin,
        );
        expect(find.byKey(const Key('peran-admin')), findsNothing);
        expect(find.byKey(const Key('peran-teknisi')), findsOneWidget);
      },
    );

    testWidgets('buat admin: lewat POST /users, sandi dikosongkan, pengingat '
        'disampaikan langsung', (tester) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaFormScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      await tester.tap(find.byKey(const Key('peran-admin')));
      await tester.pumpAndSettle();
      await isi(tester);

      await tester.ensureVisible(find.text('Buat akun'));
      await tester.tap(find.text('Buat akun'));
      await selesaikan(tester);

      expect(layanan.catatan, contains('buatAdmin SDK-0300'));
      expect(
        find.textContaining('Sampaikan sandi awalnya langsung ke orangnya'),
        findsOneWidget,
      );
      // Kolom dikosongkan; sandi tidak tampil di mana pun.
      expect(find.textContaining('sandiawal-88'), findsNothing);
      for (final t in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(t.controller?.text ?? '', isEmpty);
      }
    });

    testWidgets('buat teknisi: lewat POST /technicians', (tester) async {
      final teknisi = MockTechnicianService();
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaFormScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan, teknisi: teknisi),
      );
      // Teknisi adalah pilihan bawaan.
      await isi(tester);
      await tester.ensureVisible(find.text('Buat akun'));
      await tester.tap(find.text('Buat akun'));
      await selesaikan(tester);

      expect(teknisi.dibuat.map((t) => t.employeeId), ['SDK-0300']);
      expect(layanan.catatan.any((c) => c.startsWith('buatAdmin')), isFalse);
    });

    testWidgets(
      'validasi layar: kosong dan sandi beda tidak menyentuh server',
      (tester) async {
        final layanan = MockPenggunaSaService();
        await pasang(
          tester,
          const PenggunaFormScreen(),
          lapisan: LapisanUjiSa(pengguna: layanan),
        );

        await tester.ensureVisible(find.text('Buat akun'));
        await tester.tap(find.text('Buat akun'));
        await tester.pumpAndSettle();
        expect(find.text('Nama wajib diisi.'), findsOneWidget);
        expect(find.text('ID pegawai wajib diisi.'), findsOneWidget);
        expect(find.text('Email wajib diisi.'), findsOneWidget);
        expect(find.text('Sandi minimal 8 karakter.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('peran-admin')));
        await isi(tester, ulang: 'beda-sekali-1');
        await tester.ensureVisible(find.text('Buat akun'));
        await tester.tap(find.text('Buat akun'));
        await tester.pumpAndSettle();
        expect(find.text('Kedua sandi belum sama.'), findsOneWidget);
        expect(layanan.catatan.any((c) => c.startsWith('buatAdmin')), isFalse);
      },
    );

    testWidgets('422 server dipetakan ke kolomnya (email kembar)', (
      tester,
    ) async {
      await pasang(tester, const PenggunaFormScreen());
      await tester.tap(find.byKey(const Key('peran-admin')));
      await tester.pumpAndSettle();
      // rina@lab.test sudah dipakai di data contoh.
      await isi(tester, email: 'rina@lab.test');
      await tester.ensureVisible(find.text('Buat akun'));
      await tester.tap(find.text('Buat akun'));
      await selesaikan(tester);

      expect(find.text('Email ini sudah terdaftar.'), findsOneWidget);
    });

    testWidgets('ubah: kolom terisi; tanpa perubahan tidak memanggil server', (
      tester,
    ) async {
      final layanan = MockPenggunaSaService();
      final akun = MockPenggunaSaService.contoh[1];
      await pasang(
        tester,
        PenggunaFormScreen(akun: akun),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      expect(find.text('Dedi Teknisi'), findsOneWidget);
      expect(find.text('dedi@lab.test'), findsOneWidget);
      // Mode ubah tidak punya kolom sandi.
      expect(find.text('SANDI AWAL'), findsNothing);

      await tester.ensureVisible(find.text('Simpan perubahan'));
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada yang diubah.'), findsOneWidget);
      expect(layanan.catatan.any((c) => c.startsWith('ubah')), isFalse);
    });

    testWidgets('ubah: nama diganti → server dipanggil dan layar menutup', (
      tester,
    ) async {
      final layanan = MockPenggunaSaService();
      await pasang(
        tester,
        const PenggunaScreen(),
        lapisan: LapisanUjiSa(pengguna: layanan),
      );
      await bukaMenu(tester, 21, 'Ubah data');
      expect(find.byType(PenggunaFormScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Dedi Kurniawan');
      await tester.ensureVisible(find.text('Simpan perubahan'));
      await tester.tap(find.text('Simpan perubahan'));
      await selesaikan(tester);

      expect(layanan.catatan, contains('ubah 21'));
      expect(find.byType(PenggunaFormScreen), findsNothing);
      expect(find.text('Dedi Kurniawan'), findsOneWidget);
    });
  });

  group('Pelanggan & anggota', () {
    testWidgets('daftar pelanggan → detail anggota', (tester) async {
      await pasang(tester, const PelangganSaScreen());
      expect(find.text('PT Contoh Makmur'), findsOneWidget);
      expect(find.text('PT Uji Sejahtera'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pelanggan-17')));
      await selesaikan(tester);
      expect(find.byType(PelangganDetailScreen), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('daftar pelanggan kosong', (tester) async {
      await pasang(
        tester,
        const PelangganSaScreen(),
        lapisan: LapisanUjiSa(
          anggota: MockAnggotaPelangganService(pelanggan: const []),
        ),
      );
      expect(find.text('Belum ada pelanggan yang cocok.'), findsOneWidget);
    });

    testWidgets('daftar pelanggan galat', (tester) async {
      await pasang(
        tester,
        const PelangganSaScreen(),
        lapisan: LapisanUjiSa(
          anggota: MockAnggotaPelangganService(
            galat: const KoneksiException('x'),
          ),
        ),
      );
      expect(find.text('Daftar pelanggan belum bisa dimuat.'), findsOneWidget);
    });

    Future<void> bukaDetail(
      WidgetTester tester, {
      LapisanUjiSa? lapisan,
      String token = tokenSuperAdmin,
      Izin izin = izinSuperAdmin,
    }) => pasang(
      tester,
      PelangganDetailScreen(
        pelanggan: MockAnggotaPelangganService.contohPelanggan.first,
      ),
      lapisan: lapisan,
      token: token,
      izin: izin,
      tinggi: 2200,
    );

    testWidgets('detail: kuota, PIC admin, anggota, undangan, jejak nonaktif', (
      tester,
    ) async {
      await bukaDetail(tester);

      expect(find.text('2 dari maksimum 50 anggota aktif'), findsOneWidget);
      expect(find.text('Rina Master Data'), findsWidgets);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Sari Dewi'), findsOneWidget);
      expect(find.text('baru@contoh.test'), findsOneWidget);
      expect(
        find.textContaining('Dinonaktifkan 10 Nov 2026 oleh Rina Master Data'),
        findsOneWidget,
      );
      expect(find.text('PIC utama'), findsWidgets);
      expect(find.text('Undang anggota'), findsOneWidget);
    });

    testWidgets('PIC utama terakhir: tidak ada Cabut akses, dijelaskan; staf '
        'aktif punya Cabut akses', (tester) async {
      await bukaDetail(tester);

      expect(find.byKey(const Key('pic-terakhir-41')), findsOneWidget);
      final kartuPic = find.byKey(const Key('anggota-41'));
      expect(
        find.descendant(of: kartuPic, matching: find.text('Cabut akses')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('anggota-42')),
          matching: find.text('Cabut akses'),
        ),
        findsOneWidget,
      );
      // Anggota yang sudah nonaktif tidak bisa dicabut lagi.
      expect(
        find.descendant(
          of: find.byKey(const Key('anggota-40')),
          matching: find.text('Cabut akses'),
        ),
        findsNothing,
      );
    });

    testWidgets('cabut: konfirmasi tegas, alasan wajib, sukses menyegarkan', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await bukaDetail(tester, lapisan: LapisanUjiSa(anggota: layanan));

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('anggota-42')),
          matching: find.text('Cabut akses'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cabut akses Sari Dewi?'), findsOneWidget);
      expect(find.textContaining('PT Contoh Makmur'), findsWidgets);

      // Tanpa alasan: ditolak di layar.
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 3 karakter.'), findsOneWidget);
      expect(layanan.catatan.any((c) => c.startsWith('cabut')), isFalse);

      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Pindah perusahaan',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await selesaikan(tester);

      expect(layanan.catatan, contains('cabut 42 "Pindah perusahaan"'));
      expect(find.text('Akses anggota dicabut.'), findsOneWidget);
      // Daftar diambil ulang dari server: Sari kini nonaktif, tanpa tombol.
      expect(
        find.descendant(
          of: find.byKey(const Key('anggota-42')),
          matching: find.text('Cabut akses'),
        ),
        findsNothing,
      );
      expect(find.text('Nonaktif'), findsWidgets);
    });

    testWidgets(
      'cabut ditolak server (pic_utama_terakhir): kalimat jalan keluar, '
      'dialog tetap terbuka',
      (tester) async {
        await bukaDetail(
          tester,
          lapisan: LapisanUjiSa(anggota: _AnggotaPicTerakhir()),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('anggota-42')),
            matching: find.text('Cabut akses'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('isian-dialog')), 'alasan');
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Dia satu-satunya PIC utama aktif, jadi tidak bisa dicabut. '
            'Undang PIC utama lain dulu.',
          ),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

    testWidgets('Batal pada dialog cabut tidak memanggil server', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await bukaDetail(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('anggota-42')),
          matching: find.text('Cabut akses'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(layanan.catatan.any((c) => c.startsWith('cabut')), isFalse);
    });

    testWidgets('batalkan undangan: konfirmasi, lalu kartu hilang', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await bukaDetail(tester, lapisan: LapisanUjiSa(anggota: layanan));

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('undangan-12')),
          matching: find.text('Batalkan undangan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Batalkan undangan?'), findsOneWidget);
      expect(find.text('Undangan untuk baru@contoh.test.'), findsOneWidget);
      await tester.tap(dalamDialog(find.text('Batalkan undangan')));
      await selesaikan(tester);

      expect(layanan.catatan, contains('batalkanUndangan 12'));
      expect(find.byKey(const Key('undangan-12')), findsNothing);
      expect(find.byKey(const Key('undangan-kosong')), findsOneWidget);
    });

    testWidgets('ubah PIC admin: pilih admin aktif, atau lepas', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await bukaDetail(tester, lapisan: LapisanUjiSa(anggota: layanan));

      await tester.tap(find.text('Ubah PIC admin'));
      await tester.pumpAndSettle();
      // Admin aktif lab dari GET /users?role=admin&status=aktif.
      expect(find.byKey(const Key('pic-11')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pic-11')));
      await selesaikan(tester);
      expect(layanan.catatan, contains('setPicAdmin 11'));
      expect(find.text('PIC admin diperbarui.'), findsOneWidget);

      await tester.tap(find.text('Ubah PIC admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lepas-pic')));
      await selesaikan(tester);
      expect(layanan.catatan, contains('setPicAdmin null'));
    });

    testWidgets('Undang anggota memakai dialog yang sudah ada', (tester) async {
      await bukaDetail(tester);
      await tester.tap(find.text('Undang anggota'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('undang-email')), findsOneWidget);
    });

    testWidgets(
      'data kosong/null: tanpa PIC admin, tanpa anggota, tanpa undangan',
      (tester) async {
        final kosong = DataAnggotaPelanggan.fromJson({
          'data': {
            'customer': {'id': 17, 'nama': 'PT Contoh Makmur'},
            'maks_anggota': 50,
            'jumlah_aktif': 0,
            'pic_admin': null,
            'anggota': [],
            'undangan_menunggu': [],
          },
        });
        await bukaDetail(
          tester,
          lapisan: LapisanUjiSa(
            anggota: MockAnggotaPelangganService(data: kosong),
          ),
        );
        expect(find.byKey(const Key('pic-admin-kosong')), findsOneWidget);
        expect(find.byKey(const Key('anggota-kosong')), findsOneWidget);
        expect(find.byKey(const Key('undangan-kosong')), findsOneWidget);
      },
    );

    testWidgets('404 (milik lab lain/sudah hilang): kalimat + Coba lagi', (
      tester,
    ) async {
      await bukaDetail(
        tester,
        lapisan: LapisanUjiSa(
          anggota: MockAnggotaPelangganService(
            galatAmbil: const ApiException('Data nggak ketemu.', status: 404),
          ),
        ),
      );
      expect(
        find.text(
          'Datanya tidak ditemukan, mungkin sudah berubah. Daftar dimuat ulang.',
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('tanpa izin anggota-pelanggan.lihat: terkunci, server tidak '
        'ditanya soal daftar', (tester) async {
      await bukaDetail(tester, token: tokenTeknisi, izin: izinTeknisi);
      expect(
        find.text('Layar ini hanya untuk akun yang diberi izin oleh server.'),
        findsOneWidget,
      );
      expect(find.text('Budi Santoso'), findsNothing);
    });
  });

  group('Ganti sandi', () {
    Future<void> isiSandi(
      WidgetTester tester,
      String lama,
      String baru,
      String ulang,
    ) async {
      final k = find.byType(TextField);
      await tester.enterText(k.at(0), lama);
      await tester.enterText(k.at(1), baru);
      await tester.enterText(k.at(2), ulang);
    }

    Future<void> kirim(WidgetTester tester) async {
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Ganti sandi'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ganti sandi'));
      await tester.pumpAndSettle();
    }

    testWidgets('kolom kosong dan konfirmasi beda: ditolak di layar', (
      tester,
    ) async {
      final layanan = MockGantiSandiService();
      await pasang(
        tester,
        const GantiSandiScreen(),
        lapisan: LapisanUjiSa(gantiSandi: layanan),
      );

      await kirim(tester);
      expect(find.text('Sandi sekarang wajib diisi.'), findsOneWidget);
      expect(find.text('Sandi baru wajib diisi.'), findsOneWidget);

      await isiSandi(
        tester,
        'sandi-lama-benar',
        'sandi-baru-123',
        'beda-lagi-999',
      );
      await kirim(tester);
      expect(
        find.text('Sandi baru dan pengulangannya belum sama.'),
        findsOneWidget,
      );
      expect(layanan.jumlahPanggilan, 0);
    });

    testWidgets('sandi lama salah (kode sandi_lama_salah): pesan di kolom '
        'sandi lama; semua kolom dikosongkan', (tester) async {
      await pasang(tester, const GantiSandiScreen());
      await isiSandi(
        tester,
        'salah-semua-1',
        'sandi-baru-123',
        'sandi-baru-123',
      );
      await kirim(tester);

      expect(find.text('Sandi lama tidak cocok.'), findsOneWidget);
      for (final t in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(t.controller?.text ?? '', isEmpty);
      }
    });

    testWidgets(
      'sandi baru pendek (errors.sandi[0]): pesan di kolom sandi baru',
      (tester) async {
        await pasang(tester, const GantiSandiScreen());
        await isiSandi(tester, 'sandi-lama-benar', 'pendek', 'pendek');
        await kirim(tester);

        expect(find.text('Sandi baru minimal 10 karakter.'), findsOneWidget);
      },
    );

    testWidgets('sukses: pesan + jumlah perangkat lain; tetap di layar; kolom '
        'kosong', (tester) async {
      final layanan = MockGantiSandiService(sesiDicabut: 2);
      await pasang(
        tester,
        const GantiSandiScreen(),
        lapisan: LapisanUjiSa(gantiSandi: layanan),
      );
      await isiSandi(
        tester,
        'sandi-lama-benar',
        'sandi-baru-123',
        'sandi-baru-123',
      );
      await kirim(tester);

      expect(find.text('Sandi berhasil diganti.'), findsOneWidget);
      expect(find.text('2 perangkat lain telah dikeluarkan.'), findsOneWidget);
      // TIDAK logout: layar yang sama masih terpasang.
      expect(find.byType(GantiSandiScreen), findsOneWidget);
      expect(layanan.jumlahPanggilan, 1);
      for (final t in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(t.controller?.text ?? '', isEmpty);
      }
    });

    testWidgets('sukses tanpa perangkat lain: kalimat tambahan tidak muncul', (
      tester,
    ) async {
      await pasang(
        tester,
        const GantiSandiScreen(),
        lapisan: LapisanUjiSa(
          gantiSandi: MockGantiSandiService(sesiDicabut: 0),
        ),
      );
      await isiSandi(
        tester,
        'sandi-lama-benar',
        'sandi-baru-123',
        'sandi-baru-123',
      );
      await kirim(tester);
      expect(find.text('Sandi berhasil diganti.'), findsOneWidget);
      expect(find.textContaining('perangkat lain'), findsNothing);
    });

    testWidgets('429: pesan server, tombol ditahan sebentar', (tester) async {
      await pasang(
        tester,
        const GantiSandiScreen(),
        lapisan: LapisanUjiSa(
          gantiSandi: MockGantiSandiService(
            galat: const ApiException(
              'Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.',
              status: 429,
              body: {
                'message':
                    'Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.',
              },
            ),
          ),
        ),
      );
      await isiSandi(
        tester,
        'sandi-lama-benar',
        'sandi-baru-123',
        'sandi-baru-123',
      );
      await kirim(tester);

      expect(
        find.text('Kebanyakan percobaan. Tunggu sebentar, terus coba lagi.'),
        findsOneWidget,
      );
      final tombol = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ganti sandi'),
      );
      expect(tombol.onPressed, isNull, reason: 'ditahan setelah 429');

      await tester.pump(const Duration(seconds: 16));
      final lagi = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ganti sandi'),
      );
      expect(lagi.onPressed, isNotNull);
    });

    testWidgets(
      'jaringan putus: pesan koneksi, tanpa membocorkan jenis galat',
      (tester) async {
        await pasang(
          tester,
          const GantiSandiScreen(),
          lapisan: LapisanUjiSa(
            gantiSandi: MockGantiSandiService(
              galat: const KoneksiException('Nggak bisa nyambung ke server.'),
            ),
          ),
        );
        await isiSandi(
          tester,
          'sandi-lama-benar',
          'sandi-baru-123',
          'sandi-baru-123',
        );
        await kirim(tester);
        expect(find.text('Nggak bisa nyambung ke server.'), findsOneWidget);
      },
    );

    testWidgets('dua ketukan beruntun: server dipanggil sekali', (
      tester,
    ) async {
      final layanan = MockGantiSandiService(jeda: const Duration(seconds: 1));
      await pasang(
        tester,
        const GantiSandiScreen(),
        lapisan: LapisanUjiSa(gantiSandi: layanan),
      );
      await isiSandi(
        tester,
        'sandi-lama-benar',
        'sandi-baru-123',
        'sandi-baru-123',
      );
      final tombol = find.widgetWithText(FilledButton, 'Ganti sandi');
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));
      await selesaikan(tester);
      expect(layanan.jumlahPanggilan, 1);
    });

    testWidgets('sandi TIDAK ada di log (debugPrint/FlutterError) dan tidak '
        'tampil di layar', (tester) async {
      final log = <String>[];
      final bawaanPrint = debugPrint;
      final bawaanGalat = FlutterError.onError;
      debugPrint = (String? m, {int? wrapWidth}) => log.add(m ?? '');
      FlutterError.onError = (d) => log.add(d.toString());
      try {
        await pasang(tester, const GantiSandiScreen());
        await isiSandi(
          tester,
          'RAHASIA-LAMA-77',
          'RAHASIA-BARU-88',
          'RAHASIA-BARU-88',
        );
        await kirim(tester);
      } finally {
        // Dipulihkan SEBELUM expect: expect yang gagal dengan handler
        // terpasang membuat tes menggantung sampai batas waktu.
        debugPrint = bawaanPrint;
        FlutterError.onError = bawaanGalat;
      }

      for (final rahasia in ['RAHASIA-LAMA-77', 'RAHASIA-BARU-88']) {
        expect(
          log
              .where((l) => l.contains(rahasia))
              .map((l) => l.length > 160 ? l.substring(0, 160) : l),
          isEmpty,
          reason: rahasia,
        );
        expect(find.textContaining(rahasia), findsNothing, reason: rahasia);
      }
    });

    testWidgets('label semantik tiap kolom (pembaca layar)', (tester) async {
      final handle = tester.ensureSemantics();
      await pasang(tester, const GantiSandiScreen());
      // Label kolom menempel di simpul kotak isiannya (digabung dengan teks
      // bantu di dekatnya), jadi dicari sebagai pola.
      expect(find.bySemanticsLabel(RegExp('Sandi sekarang')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Ulangi sandi baru')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(r'^Sandi baru')), findsWidgets);
      handle.dispose();
    });
  });
}
