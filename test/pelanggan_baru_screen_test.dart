import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/perusahaan_direktori.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/pelanggan_baru_screen.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Teknisi mendaftarkan PT yang belum ada di master lab.
///
/// Yang dijaga berkas ini dua hal yang sama-sama nggak kelihatan kalau cuma
/// diadu tampilannya:
///
///  1. **"Direktori belum disetel" nggak boleh kebaca sebagai "PT-nya nggak
///     ada".** Teknisi yang percaya itu mendaftarkan ulang perusahaan yang
///     sebenarnya ada di direktori — nambah kembar justru lewat fitur yang
///     dipasang buat menguranginya.
///  2. **Kembar ditawari jalan keluarnya, bukan cuma ditolak.** Nama yang cuma
///     beda tanda baca lolos unique index yang jalan di teks mentah, dan riwayat
///     kalibrasi satu perusahaan jadi terbelah tanpa ada yang kelihatan salah.
void main() {
  /// Layarnya `ListView` dan tombol daftarkannya jatuh di bawah lipatan begitu
  /// catatan kandidatnya nambah. Diadu di viewport bawaan 800x600, test-nya
  /// merah karena tombolnya nggak dibangun, bukan karena keadaannya salah.
  void layarPanjang(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Penampung hasil yang dibaca SESUDAH layarnya nutup.
  ///
  /// Nilai baliknya nggak bisa dipulangkan langsung dari [buka]: `Navigator.push`
  /// baru selesai waktu layarnya di-pop, jauh sesudah [buka] balik. Diadu di
  /// situ, nilainya SELALU null dan test-nya hijau tanpa memeriksa apa pun.
  final hasil = _Tampung();

  Future<void> buka(
    WidgetTester tester,
    CustomerLookupService service, {
    String kataKunci = '',
  }) async {

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-2'),
          ),
          customerLookupServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                hasil.isi = await Navigator.of(context).push<CustomerLookup>(
                  MaterialPageRoute(
                    builder: (_) => PelangganBaruScreen(kataKunci: kataKunci),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  Finder tombolDaftarkan() =>
      find.widgetWithText(FilledButton, 'DAFTARKAN');

  testWidgets('kata kunci dari sheet ikut kebawa, nggak diketik dua kali', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT Sinar');

    expect(find.text('PT Sinar'), findsOneWidget);
  });

  testWidgets('tombol daftarkan MATI selama nama kosong', (tester) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService());

    expect(tester.widget<FilledButton>(tombolDaftarkan()).onPressed, isNull);
  });

  testWidgets('hasil direktori dipajang lengkap dengan alamatnya', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'Sinar');

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();

    expect(find.text('PT Sinar Rejeki Manufaktur'), findsOneWidget);
    expect(
      find.textContaining('MM2100'),
      findsOneWidget,
      reason: 'Alamatnya yang bikin teknisi bisa membedakan dua PT bernama '
          'mirip — tanpa itu dia memilih dari nama yang nggak membedakan.',
    );
  });

  testWidgets('memilih hasil direktori mengisi nama DAN alamat', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'Sinar');

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    final nama = tester.widgetList<TextField>(find.byType(TextField)).first;
    final alamat = tester.widgetList<TextField>(find.byType(TextField)).last;

    expect(nama.controller?.text, 'PT Sinar Rejeki Manufaktur');
    expect(alamat.controller?.text, contains('MM2100'));
  });

  /// Butir terpenting di berkas ini.
  ///
  /// "Key belum disetel" itu urusan ADMIN. Teknisi di gerbang pabrik nggak bisa
  /// berbuat apa-apa soal itu — dipajang apa adanya, yang dia lihat cuma
  /// aplikasi yang kelihatan rusak di tengah kerjaan, lalu dia berhenti dan
  /// menelepon padahal jalur ketik tangan di bawahnya jalan sempurna.
  testWidgets('DIREKTORI TIADA: tombolnya HILANG, dan nggak ada jargon server', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(
      tester,
      MockCustomerLookupService(direktoriBelumDisetel: true),
      kataKunci: 'Sinar',
    );

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();

    expect(
      find.text('CARI DI DIREKTORI'),
      findsNothing,
      reason: 'Tombol yang tiap ditekan memulangkan hal yang sama itu bukan '
          'pilihan — dia jebakan yang bikin teknisi mengira ada yang rusak.',
    );
    expect(find.textContaining('nggak tersedia di lab ini'), findsOneWidget);

    for (final jargon in ['disetel', 'server', 'API', 'key']) {
      expect(
        find.textContaining(jargon),
        findsNothing,
        reason: 'Kalimat buat teknisi nggak boleh memuat "$jargon" — itu bahasa '
            'orang yang memasang server, bukan orang yang lagi berdiri di depan '
            'pelanggan.',
      );
    }

    expect(
      find.textContaining('Nggak ada perusahaan yang cocok'),
      findsNothing,
      reason: 'Tetap nggak boleh kebaca sebagai "PT-nya nggak ada di direktori" '
          '— itu bikin dia mendaftarkan ulang perusahaan yang sebenarnya ada.',
    );
  });

  /// Direktorinya dipasang, cuma lagi mati — ini SEMENTARA, jadi tombolnya
  /// TETAP ADA. Menyembunyikannya bikin teknisi kehilangan jalur yang lima
  /// menit lagi jalan sendiri.
  testWidgets('DIREKTORI MATI: tombolnya TETAP ada, kalimatnya menawarkan ulang', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(
      tester,
      MockCustomerLookupService(direktoriMati: true),
      kataKunci: 'Sinar',
    );

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();

    expect(find.text('CARI DI DIREKTORI'), findsOneWidget);
    expect(find.textContaining('coba lagi nanti'), findsOneWidget);
  });

  testWidgets('nihil BENERAN tetap bilang nihil — itu keadaan yang sah', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(
      tester,
      MockCustomerLookupService(),
      kataKunci: 'Perusahaan Yang Tidak Ada',
    );

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nggak ada perusahaan yang cocok'), findsOneWidget);
  });

  testWidgets('pelanggan yang terdaftar dipulangkan ke pemanggilnya', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(
      tester,
      MockCustomerLookupService(),
      kataKunci: 'PT Bumi Sentosa',
    );

    await tester.enterText(find.byType(TextField).last, 'Jl. Uji No. 1');
    await tester.pump();
    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(find.byType(PelangganBaruScreen), findsNothing);
    expect(hasil.isi?.nama, 'PT Bumi Sentosa');
    expect(hasil.isi?.alamat, 'Jl. Uji No. 1');
    expect(
      hasil.isi?.id,
      isNotNull,
      reason: 'Yang pulang harus bawa `customers.id` — itu yang dikirim balik '
          'sebagai `pelanggan_id` waktu alatnya disimpan.',
    );
  });

  testWidgets('NAMA MIRIP: kandidatnya dipajang, bukan cuma ditolak', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT. Maju Jaya');

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(find.textContaining('maksudmu yang ini'), findsOneWidget);
    expect(find.text('PT Maju Jaya'), findsOneWidget);
    expect(
      find.text('PERUSAHAAN LAIN — TETAP DAFTARKAN'),
      findsOneWidget,
      reason: 'Dua PT yang beneran beda boleh punya nama mirip, dan teknisi di '
          'lapangan nggak boleh mentok tanpa jalan keluar — itu justru keadaan '
          'yang bikin dia mengarang nama pembeda.',
    );
  });

  testWidgets('memilih kandidat menutup layar tanpa bikin baris baru', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT. Maju Jaya');

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Maju Jaya'));
    await tester.pumpAndSettle();

    expect(find.byType(PelangganBaruScreen), findsNothing);
    expect(
      hasil.isi?.id,
      1,
      reason: 'Yang pulang harus pelanggan yang SUDAH ADA (id 1), bukan baris '
          'baru — itu seluruh guna kandidatnya.',
    );
  });

  testWidgets('NAMA PERSIS SAMA: nggak ada tombol tembus, karena buntu', (
    tester,
  ) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT Maju Jaya');

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(find.textContaining('maksudmu yang ini'), findsOneWidget);
    expect(
      find.text('PERUSAHAAN LAIN — TETAP DAFTARKAN'),
      findsNothing,
      reason: 'Yang menahan di sini unique index di database. Tombolnya cuma '
          'bikin teknisi menabrak penolakan yang sama berkali-kali.',
    );
  });

  testWidgets('tetap daftarkan menembus kemiripan', (tester) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT. Maju Jaya');

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PERUSAHAAN LAIN — TETAP DAFTARKAN'));
    await tester.pumpAndSettle();

    expect(find.byType(PelangganBaruScreen), findsNothing);
    expect(hasil.isi?.nama, 'PT. Maju Jaya');
    expect(
      hasil.isi?.id,
      isNot(1),
      reason: 'Yang pulang baris BARU, bukan `PT Maju Jaya` yang sudah ada.',
    );
  });

  testWidgets('KANDIDAT BASI hilang begitu namanya diganti', (tester) async {
    layarPanjang(tester);
    await buka(tester, MockCustomerLookupService(), kataKunci: 'PT. Maju Jaya');

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();
    expect(find.text('PT Maju Jaya'), findsOneWidget);

    // Teknisi sadar salah orang, lalu mengetik perusahaan yang BEDA.
    await tester.enterText(find.byType(TextField).first, 'PT Sinar Rejeki');
    await tester.pump();

    expect(
      find.text('PT Maju Jaya'),
      findsNothing,
      reason: 'Kandidat dari nama SEBELUMNYA masih bisa diketuk, dan sekali '
          'ketuk layarnya pulang membawa PT Maju Jaya — padahal yang diketik '
          'teknisi sekarang perusahaan lain. Alatnya mendarat di pelanggan '
          'yang salah, tanpa satu pun error.',
    );
    expect(
      find.text('PERUSAHAAN LAIN — TETAP DAFTARKAN'),
      findsNothing,
      reason: 'Tombol tembus yang tertinggal mengirim `tetap_buat: true` buat '
          'nama yang belum pernah diperiksa — kembar lahir tanpa kandidatnya '
          'pernah ditunjukkan.',
    );
  });

  testWidgets('MENYUNTING NAMA sesudah pilih direktori melepas ref-nya', (
    tester,
  ) async {
    layarPanjang(tester);
    final mata = _MataMata();
    await buka(tester, mata, kataKunci: 'Sinar');

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    // Ditimpa perusahaan LAIN. Id tempat yang tadi kepilih sudah nggak nunjuk
    // ke yang mau disimpan.
    await tester.enterText(find.byType(TextField).first, 'PT Lain Sekali');
    await tester.pump();
    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(
      mata.refTerakhir,
      isNull,
      reason: 'Ref yang nempel terus bikin server mencocokkan kembar ke '
          'perusahaan yang salah — dan cocoknya kelihatan meyakinkan.',
    );
  });

  testWidgets('NAMA DIREKTORI BERSPASI tetap bawa ref-nya', (tester) async {
    layarPanjang(tester);
    final mata = _MataMata(namaBerspasi: true);
    await buka(tester, mata, kataKunci: 'Sinar');

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(
      mata.refTerakhir,
      'tempat-sinar-rejeki',
      reason: 'Menyetel `_nama.text` memicu listener-nya SEKETIKA, dan listener '
          'itu mengadu teks ter-trim ke nama direktori yang belum di-trim. '
          'Nama berspasi bikin adunya gagal di detik itu juga, ref-nya lepas, '
          'dan server kehilangan pencocokan tempat yang persis — padahal '
          'teknisi baru saja memilihnya dari direktori.',
    );
  });

  testWidgets('MEMBETULKAN ALAMAT nggak melepas ref-nya', (tester) async {
    layarPanjang(tester);
    final mata = _MataMata();
    await buka(tester, mata, kataKunci: 'Sinar');

    await tester.tap(find.text('CARI DI DIREKTORI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Sinar Rejeki Manufaktur'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Alamat yang dibetulkan');
    await tester.pump();
    await tester.tap(tombolDaftarkan());
    await tester.pumpAndSettle();

    expect(
      mata.refTerakhir,
      'tempat-sinar-rejeki',
      reason: 'Yang dituju ref itu PERUSAHAAN mana, dan alamat cuma '
          'keterangannya — membetulkan alamat nggak mengubah perusahaannya.',
    );
  });
}

/// Mock yang mencatat apa yang beneran dikirim ke server.
///
/// Perlu karena `direktori_ref` nggak kelihatan di layar sama sekali: dia cuma
/// ada di badan request, dan justru di situ salahnya berakibat.
class _MataMata extends MockCustomerLookupService {
  _MataMata({this.namaBerspasi = false});

  /// Menirukan direktori yang memulangkan nama dengan spasi di ujung. Nyata:
  /// nama tempat di direktori diketik manusia, dan spasi ekor itu hal biasa.
  final bool namaBerspasi;

  String? refTerakhir;

  @override
  Future<List<PerusahaanDirektori>> cariDirektori(
    String token, {
    required String search,
  }) async {
    final hasil = await super.cariDirektori(token, search: search);
    if (!namaBerspasi) return hasil;

    return [
      for (final d in hasil)
        PerusahaanDirektori(ref: d.ref, nama: '  ${d.nama}  ', alamat: d.alamat),
    ];
  }

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) {
    refTerakhir = direktoriRef;
    return super.daftarkan(
      token,
      nama: nama,
      alamat: alamat,
      direktoriRef: direktoriRef,
      tetapBuat: tetapBuat,
    );
  }
}

/// Kotak buat nilai balik layar, dibaca sesudah layarnya nutup.
class _Tampung {
  CustomerLookup? isi;
}
