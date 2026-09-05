import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show categoryServiceProvider;
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/equipment_form_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'support/simpanan_tiruan.dart';

/// Pencarian PT dari direktori luar, **di kolom pelanggan itu sendiri**.
///
/// Keluhan pemilik proyek yang melahirkan berkas ini: *"ini masih gk ada
/// loh"* — padahal fiturnya sudah terpasang. Yang bikin dia nggak kepakai
/// letaknya: pencarian direktori sembunyi di balik tombol terpisah, di layar
/// lain, tujuh langkah dari kolom yang teknisi sentuh.
///
/// Yang dijaga berkas ini bahwa jalurnya tetap SATU KETUKAN dari kolom
/// pelanggan, dan yang paling gampang hilang diam-diam: **alamatnya ikut
/// terkirim**. Kalau yang tersimpan cuma namanya, blok OWNER di sertifikat
/// kehilangan alamat pelanggan — dan nggak ada satu pun error yang muncul.

class _EquipmentServiceKosong implements EquipmentService {
  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async => const EquipmentPage(items: [], currentPage: 1, lastPage: 1);

  @override
  Future<Equipment> simpan(String token, Equipment data) async => data;

  @override
  Future<Equipment> ubah(String token, Equipment data) async => data;

  @override
  Future<void> hapus(String token, int id) async {}
}

/// Mock yang MENCATAT apa yang dikirim ke `daftarkan`.
///
/// Mengadu tampilannya saja nggak cukup: nama yang benar di layar tetap bisa
/// berangkat ke server tanpa alamat dan tanpa ref direktori, dan dua-duanya
/// hilang tanpa jejak yang kelihatan.
class _LookupPencatat extends MockCustomerLookupService {
  _LookupPencatat({this.tabrakan = false, this.gerbang});

  /// Menirukan server yang menemukan PT mirip → butuh keputusan manusia.
  final bool tabrakan;

  /// Menahan `daftarkan` di tengah jalan, meniru jaringan yang lambat.
  ///
  /// Tanpa ini, ketukan ganda nggak bisa diuji sama sekali: mock yang menjawab
  /// seketika bikin ketukan PERTAMA sudah tuntas dan sheet-nya sudah tertutup
  /// sebelum ketukan kedua sempat mendarat, jadi test-nya hijau bahkan waktu
  /// SELURUH penjagaannya dicopot. Sudah dibuktikan begitu — itu sebabnya
  /// gerbang ini ada.
  final Completer<void>? gerbang;

  String? namaDikirim;
  String? alamatDikirim;
  String? refDikirim;
  int panggilanDaftar = 0;

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) async {
    panggilanDaftar++;
    namaDikirim = nama;
    alamatDikirim = alamat;
    refDikirim = direktoriRef;

    if (gerbang != null) await gerbang!.future;

    if (tabrakan && !tetapBuat) {
      throw const PelangganMiripException(
        pesan: 'Ada pelanggan dengan nama yang mirip.',
        kandidat: [CustomerLookup(id: 1, nama: 'PT Maju Jaya')],
        namaPersisSudahAda: false,
      );
    }

    return CustomerLookup(id: 1000, nama: nama, alamat: alamat);
  }
}

Widget _app(CustomerLookupService lookup) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    equipmentServiceProvider.overrideWithValue(_EquipmentServiceKosong()),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    customerLookupServiceProvider.overrideWithValue(lookup),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const EquipmentFormScreen(),
  ),
);

Future<void> _bukaPemilih(
  WidgetTester tester,
  CustomerLookupService lookup,
) async {
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(lookup));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih pelanggan'));
  await tester.pumpAndSettle();
}

/// Ketik di kolom pencarian, lalu tunggu debounce-nya lewat.
Future<void> _ketik(WidgetTester tester, String kata) async {
  await tester.enterText(find.byType(TextField).last, kata);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  pasangSimpananTiruan();

  testWidgets('master lab nol → hasil direktori muncul TANPA tombol tambahan', (
    tester,
  ) async {
    final lookup = _LookupPencatat();
    await _bukaPemilih(tester, lookup);

    // "Sinar" nggak ada di master lab, tapi ada di direktori.
    await _ketik(tester, 'Sinar');

    // Nggak ada tombol yang ditekan di antara mengetik dan melihat hasil —
    // itu seluruh inti perbaikannya.
    expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
    expect(find.text('PT Sinar Terang Kimia'), findsOneWidget);
    expect(find.text('Hasil direktori'), findsOneWidget);
  });

  /// Atribusi sumbernya ikut dipajang DI SHEET INI juga, bukan cuma di layar
  /// PT baru.
  ///
  /// Dua tempat memajang hasil direktori, dan kewajiban ODbL melekat ke
  /// TEMPAT HASILNYA DIPAJANG — jadi memperbaiki satu layar saja menyisakan
  /// pelanggaran yang sama persis di layar satunya. Sheet ini justru yang
  /// paling sering dilihat teknisi: dia jalur satu-ketukan, sementara layar PT
  /// baru cuma dibuka waktu ada tabrakan nama.
  ///
  /// Kalimatnya datang dari server dan dipajang apa adanya — lihat
  /// `test/atribusi_direktori_test.dart` buat penjagaan bahwa dia nggak boleh
  /// ditulis mati di sisi HP.
  testWidgets('atribusi sumbernya ikut dipajang di sheet pemilih', (
    tester,
  ) async {
    await _bukaPemilih(tester, _LookupPencatat());
    await _ketik(tester, 'Sinar');

    expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
    expect(
      find.text('© OpenStreetMap contributors'),
      findsOneWidget,
      reason: 'Hasil direktori dipajang tanpa menyebut sumbernya — ODbL '
          'mewajibkannya, dan hilangnya nggak ninggalin satu pun error.',
    );
  });

  testWidgets('satu ketukan → nama DAN alamat dua-duanya terkirim', (
    tester,
  ) async {
    final lookup = _LookupPencatat();
    await _bukaPemilih(tester, lookup);
    await _ketik(tester, 'Sinar');

    await tester.tap(find.text('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    expect(lookup.namaDikirim, 'PT Sinar Rejeki Manufaktur');
    // Ini yang paling gampang hilang diam-diam, dan yang dimintakan pemilik
    // proyek: alamatnya ikut, bukan cuma namanya.
    expect(
      lookup.alamatDikirim,
      'Kawasan Industri MM2100 Blok C-3, Cikarang Barat, Bekasi',
    );
    // Ref direktori ikut supaya perusahaan yang sama dipilih dua teknisi bisa
    // dikenali persis, tanpa mengadu ejaan nama.
    expect(lookup.refDikirim, 'tempat-sinar-rejeki');

    // Sheet-nya tutup, dan form Alat langsung terisi.
    expect(find.text('Hasil direktori'), findsNothing);
    expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
  });

  testWidgets('PT direktori tanpa alamat tetap kekirim, alamatnya null', (
    tester,
  ) async {
    final lookup = _LookupPencatat();
    await _bukaPemilih(tester, lookup);
    await _ketik(tester, 'Bumi');

    await tester.tap(find.text('PT Bumi Sentosa'));
    await tester.pumpAndSettle();

    expect(lookup.namaDikirim, 'PT Bumi Sentosa');
    // Nggak semua tempat di direktori punya alamat tertulis. Yang nggak punya
    // tetap boleh didaftarkan — bukan diisi tanda tanya, bukan ditolak.
    expect(lookup.alamatDikirim, isNull);
  });

  testWidgets('master lab yang PUNYA jawaban nggak menembak direktori', (
    tester,
  ) async {
    final lookup = _LookupPencatat();
    await _bukaPemilih(tester, lookup);

    // "Maju" ADA di master lab.
    await _ketik(tester, 'Maju');

    expect(find.text('PT Maju Jaya'), findsOneWidget);
    // Direktori luar itu panggilan mahal ke layanan pihak ketiga. PT yang
    // sudah terdaftar juga HARUS dipilih dari master, bukan didaftarkan ulang
    // dari direktori — kembar di situ membelah riwayat kalibrasi satu
    // perusahaan, dan yang kelihatan di layar cuma separuhnya.
    expect(find.text('Hasil direktori'), findsNothing);
  });

  testWidgets('tabrakan nama diserahkan ke layar PT baru, bawa alamat & ref', (
    tester,
  ) async {
    final lookup = _LookupPencatat(tabrakan: true);
    await _bukaPemilih(tester, lookup);
    await _ketik(tester, 'Sinar');

    await tester.tap(find.text('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    // Keputusan "pakai yang sudah ada" lawan "ini perusahaan lain" butuh
    // manusia, dan layar PT baru sudah punya seluruh tampilannya.
    expect(
      find.text('Sudah ada di daftar — maksudmu yang ini?'),
      findsOneWidget,
    );

    // Yang dibawa ke sana lengkap: kolom alamatnya sudah terisi dari direktori,
    // bukan dikosongkan lalu diketik ulang.
    expect(
      find.text('Kawasan Industri MM2100 Blok C-3, Cikarang Barat, Bekasi'),
      findsWidgets,
    );
  });

  testWidgets('ketukan kedua SELAGI pendaftaran jalan nggak bikin PT kembar', (
    tester,
  ) async {
    final gerbang = Completer<void>();
    final lookup = _LookupPencatat(gerbang: gerbang);
    await _bukaPemilih(tester, lookup);
    await _ketik(tester, 'Sinar');

    final baris = find.text('PT Sinar Rejeki Manufaktur');

    await tester.tap(baris);
    // `pump` sekali saja, BUKAN `pumpAndSettle`: yang mau diuji keadaan waktu
    // pendaftarannya masih menggantung. `pumpAndSettle` bakal menunggu gerbang
    // yang memang sengaja belum dibuka.
    await tester.pump();

    // Ketukan kedua mendarat selagi yang pertama masih di jalan — persis yang
    // terjadi waktu sinyal di pabrik tipis dan teknisi mengira ketukannya
    // nggak masuk.
    await tester.tap(baris, warnIfMissed: false);
    await tester.pump();

    gerbang.complete();
    await tester.pumpAndSettle();

    // Dua baris pelanggan buat satu perusahaan membelah riwayat kalibrasinya,
    // dan yang kelihatan di layar cuma separuhnya.
    expect(lookup.panggilanDaftar, 1);
  });
}
