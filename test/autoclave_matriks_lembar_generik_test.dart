import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_matriks.dart';

/// Autoklaf digambar di lembar kerja generik, dan barisnya URUT KERTAS.
///
/// Urutan baris di sini memikul arti yang nggak kelihatan sebagai error kalau
/// salah. Waktu Autoklaf sempat dipaksa masuk bentuk lembar pH (20 Agu 2026),
/// baris kelima di kertas (`Indikator Pressure`) ketemu baris kelima di layar
/// (`Suhu Ruang`): teknisi yang nyalin sambil megang kertas mindahin bacaan
/// manometer ke kolom suhu, dan angka itu jalan terus sampai sertifikat.
///
/// Yang dijaga: kedelapan barisnya lengkap, urut kertas, dan tiap baris tetap
/// nempel ke `kode_data`-nya sendiri.
void main() {
  Map<String, dynamic> bentukJson() => {
    'judul': 'Calibration Worksheet - Autoclave',
    'kode_dokumen': 'SIDIK-FM-CAL-0539_Rev.4',
    'jumlah_pengulangan': 5,
    'satuan': null,
    'bagian': [
      {
        'kode': 'hasil_pengukuran',
        'halaman': 1,
        'judul': 'Calibration Result for Temperature & Pressure',
        'field': [
          {
            'kode': 'set_point',
            'label': 'Set Point',
            'tipe': 'angka',
            'satuan': '°C',
          },
          {
            'kode': 'satuan_tekanan',
            'label': 'Pressure Unit',
            'tipe': 'teks',
          },
        ],
        'matriks': {
          'judul_kolom': 'Pengukuran Berulang UUT Selama Proses Sterilisasi',
          'titik_waktu': [1, 2, 3, 4, 5],
          'baris_waktu': {
            'kode': 'waktu',
            'label': 'Time',
            'tipe': 'jam',
            'format': 'HH:mm:ss',
            'kode_data': 'waktu',
          },
          'baris': [
            {
              'kode': 'disk_1',
              'label': 'Temp. Disk 1',
              'satuan': '°C',
              'kode_data': 'suhu.disk.0',
            },
            {
              'kode': 'disk_2',
              'label': 'Temp. Disk 2',
              'satuan': '°C',
              'kode_data': 'suhu.disk.1',
            },
            {
              'kode': 'disk_3',
              'label': 'Temp. Disk 3',
              'satuan': '°C',
              'kode_data': 'suhu.disk.2',
            },
            {
              'kode': 'indikator_suhu',
              'label': 'Indikator Suhu',
              'satuan': '°C',
              'kode_data': 'suhu.indikator',
            },
            {
              'kode': 'indikator_pressure',
              'label': 'Indikator Pressure',
              'satuan_dari': 'satuan_tekanan',
              'kode_data': 'tekanan.indikator_pressure',
            },
            {
              'kode': 'tekanan_atm_awal',
              'label': 'Tekanan atm awal',
              'satuan_dari': 'satuan_tekanan',
              'kode_data': 'tekanan.tekanan_atm_awal',
            },
            {
              'kode': 'suhu_ruang',
              'label': 'Suhu Ruang',
              'satuan': '°C',
              'kode_data': 'suhu.suhu_ruang',
            },
          ],
        },
        'tabel_tekanan': {
          'label': 'Pressure Disk Logger — hasil unduh (Bar)',
          'di_luar_kertas': true,
          'catatan': 'Nggak ada di kertas: angkanya diunduh dari alat.',
          'kolom': {
            'kode': 'tekanan.pembacaan_standar',
            'label': 'Standar Reading',
            'satuan': 'Bar',
          },
          'pengulangan': [1, 2, 3, 4, 5],
        },
        'field_di_luar_kertas': [
          {
            'kode': 'display_tekanan',
            'label': 'Pressure Display Type',
            'tipe': 'pilihan',
            'di_luar_kertas': true,
            'pilihan': [
              {'nilai': 'Digital', 'label': 'Digital'},
              {'nilai': 'Analog 1', 'label': 'Analog 1'},
            ],
          },
        ],
      },
    ],
  };

  BagianLembarKerja bagian() =>
      LembarKerja.fromJson(bentukJson()).bagian.single;

  test('nama alatnya diarahkan ke profil autoclave', () {
    expect(profilLembarKerjaUntuk('Autoclave'), 'autoclave');
    // Lampiran akreditasi LK-285-IDN no. 48 nulisnya "Autoklaf".
    expect(profilLembarKerjaUntuk('Autoklaf'), 'autoclave');
  });

  test('delapan baris kertas kebaca lengkap dan urut', () {
    final m = bagian().matriks;

    expect(m, isNotNull);
    expect(m!.semuaBaris.map((b) => b.label), [
      'Time',
      'Temp. Disk 1',
      'Temp. Disk 2',
      'Temp. Disk 3',
      'Indikator Suhu',
      'Indikator Pressure',
      'Tekanan atm awal',
      'Suhu Ruang',
    ], reason: 'urutan kertas — baris kelima itu Indikator Pressure');

    // Jalur payload tiap baris ikut dari backend, bukan dihafal layar.
    expect(m.semuaBaris.map((b) => b.kodeData), [
      'waktu',
      'suhu.disk.0',
      'suhu.disk.1',
      'suhu.disk.2',
      'suhu.indikator',
      'tekanan.indikator_pressure',
      'tekanan.tekanan_atm_awal',
      'suhu.suhu_ruang',
    ]);

    expect(m.semuaBaris.first.jam, isTrue, reason: 'Time diisi jam, bukan angka');
    expect(m.titikWaktu, [1, 2, 3, 4, 5]);
  });

  test('blok di luar kertas kebaca berikut alasannya', () {
    final b = bagian();

    expect(b.tabelTambahan, isNotNull);
    expect(b.tabelTambahan!.kodeData, 'tekanan.pembacaan_standar');
    expect(b.tabelTambahan!.diLuarKertas, isTrue);
    expect(b.tabelTambahan!.catatan, isNotNull);
    expect(b.fieldDiLuarKertas.map((f) => f.kode), ['display_tekanan']);
  });

  testWidgets('matriksnya kegambar: delapan baris + blok di luar kertas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bentuk = LembarKerja.fromJson(bentukJson());
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'uji-matriks',
    );
    addTearDown(isian.dispose);

    final b = bentuk.bagian.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaMatriks(
              matriks: b.matriks!,
              isian: isian,
              onBerubah: () {},
              tabelTambahan: b.tabelTambahan,
              setPoint: b.field.first,
            ),
          ),
        ),
      ),
    );

    for (final label in [
      'Time',
      'Temp. Disk 1',
      'Indikator Suhu',
      'Indikator Pressure',
      'Tekanan atm awal',
      'Suhu Ruang',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }

    expect(find.textContaining('Set Point'), findsOneWidget);
    expect(
      find.textContaining('Pressure Disk Logger'),
      findsWidgets,
      reason: 'tanpa baris ini olah data tekanan nggak jalan',
    );

    // Kotak jam punya petunjuk formatnya sendiri — bukan kotak angka biasa.
    expect(find.text('--:--:--'), findsNWidgets(5));
  });

  /// Lebar HP beneran. Layar Autoklaf lama dua kali kena bug ini — kisi
  /// angkanya kelihatan baik-baik saja di 1400 px, dan di 360 px tiap kotak
  /// cuma ~50 dp. Diuji di lebar HP, bukan lebar meja.
  testWidgets('kerender di lebar HP tanpa tata letak yang meluber', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bentuk = LembarKerja.fromJson(bentukJson());
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'uji-hp',
    );
    addTearDown(isian.dispose);

    final b = bentuk.bagian.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaMatriks(
              matriks: b.matriks!,
              isian: isian,
              onBerubah: () {},
              tabelTambahan: b.tabelTambahan,
              setPoint: b.field.first,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Kotak angka wajib cukup lebar buat diketik DAN diperiksa ulang. Angka
    // tekanan di lembar ini berkoma tiga desimal (`1,231`); kotak yang lebih
    // sempit bikin isinya kepotong waktu dibaca lagi sebelum dikirim.
    final lebar = tester
        .getSize(find.byKey(const Key('matriks_tekanan.indikator_pressure_1')))
        .width;

    expect(lebar, greaterThan(60), reason: 'kotak angka kesempitan di HP');
  });

  /// Satuan tekanan ikut kolom `satuan_tekanan` yang lagi kepilih.
  ///
  /// Angka `1,231` di baris Indikator Pressure artinya beda jauh antara Bar,
  /// Psi, dan kPa. Tanpa satuannya tertulis di baris yang lagi diisi, teknisi
  /// nggak punya cara tahu dia lagi nyalin ke satuan mana.
  testWidgets('baris bersatuan_dari nunjukin satuan yang lagi kepilih', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bentuk = LembarKerja.fromJson(bentukJson());
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'uji-satuan',
    );
    addTearDown(isian.dispose);

    isian.teks['satuan_tekanan']!.text = 'Psi';

    final b = bentuk.bagian.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaMatriks(
              matriks: b.matriks!,
              isian: isian,
              onBerubah: () {},
              tabelTambahan: b.tabelTambahan,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Indikator Pressure (Psi)'), findsOneWidget);
    expect(find.text('Tekanan atm awal (Psi)'), findsOneWidget);

    // Label blok di luar kertas SUDAH bawa satuannya dari backend — ditempelin
    // lagi jadi "… (Bar) (Bar)".
    expect(find.text('Pressure Disk Logger — hasil unduh (Bar) (Bar)'),
        findsNothing);
  });

  /// Kolom `pilihan` yang bawa daftar pilihannya sendiri WAJIB kegambar.
  ///
  /// Dulu `_PilihanTetap` cuma kenal tiga kode dan sisanya dirender
  /// `SizedBox.shrink()`. Buat Autoklaf itu artinya `satuan_tekanan` &
  /// `display_tekanan` nggak pernah muncul di layar: teknisi nggak tahu ada
  /// yang harus dipilih, dan angka tekanannya sampai server tanpa satuan.
  test('kolom pilihan berdaftar dapat controller, jadi nilainya ikut kekirim', () {
    final bentuk = LembarKerja.fromJson(bentukJson());
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'uji-pilihan',
    );
    addTearDown(isian.dispose);

    expect(
      isian.teks.containsKey('display_tekanan'),
      isTrue,
      reason: 'kolom pilihan berdaftar butuh controller biar nilainya kekirim',
    );
  });
}
