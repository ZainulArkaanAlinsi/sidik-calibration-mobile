import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/validasi.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Revisi nandain SATU SEL, bukan nyuruh ngulang satu tabel.
///
/// ## Kegagalan yang ditutup berkas ini
///
/// `revisi_field` cuma bisa nunjuk KOLOM identitas — `alat_model`,
/// `pemilik_nama`. Yang paling sering minta dibetulin justru satu ANGKA di
/// tengah tabel pengukuran, di antara puluhan angka yang sudah benar.
///
/// Yang bisa dilakukan admin cuma dua-duanya buruk: nulis prosa ("Titik ke-2
/// Repeat 3 komanya kegeser") dan berharap teknisi nemu kotaknya pakai mata,
/// atau nandain seluruh tabel. Yang kedua itu yang bikin teknisi ngosongin
/// tabel lalu ngetik ulang semuanya — termasuk angka yang sudah benar, yang
/// lalu ngundang salah ketik BARU di sesi revisi.
///
/// Kode selnya dibangun backend (`KodeSelRevisi`), bentuknya
/// `sel:<tahap>:<titik_ukur>:<kolom>:<pembacaan_ke>`.
void main() {
  LembarKerja lembarConductivity() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
    'judul': 'Calibration Worksheet - Conductivity Meter',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan_campuran': true,
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'CALIBRATION RESULT',
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'judul': 'After adjustment Reading',
            'kolom': [
              {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
            ],
            'pengulangan': [1, 2, 3, 4, 5],
            'baris': [
              {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm'},
              {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm'},
              {'titik_ukur': 12880, 'label': '12880', 'satuan': 'µS/cm'},
            ],
          },
        ],
      },
    ],
  });

  LembarKerjaState isianDenganRevisi(Set<String> field) {
    final isian = LembarKerjaState(
      bentuk: lembarConductivity(),
      clientRequestId: 'tes-penanda-sel',
    );

    isian.muatDariSesi(
      IsianTeknisi(
        revisiField: field,
        catatanRevisi: 'Repeat 3 di titik 1412 komanya kegeser.',
      ),
    );

    return isian;
  }

  const tahap = 'sesudah_adjustment';

  test('kode sel nandain kotak yang dimaksud — dan cuma yang itu', () {
    // Repeat 3 (1-based di kertas & di server) = index 2 di layar.
    final isian = isianDenganRevisi({'sel:$tahap:1412:pembacaan:3'});

    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);

    // Tetangga sebelahnya bersih. Ini yang bikin teknisi tau apa yang JANGAN
    // disentuh — sama pentingnya dengan tau apa yang mesti dibetulin.
    expect(isian.tandaSel(1412, tahap, 'pembacaan', 1), TandaSel.tidakAda);
    expect(isian.tandaSel(1412, tahap, 'pembacaan', 3), TandaSel.tidakAda);
    expect(isian.tandaSel(25, tahap, 'pembacaan', 2), TandaSel.tidakAda);
    expect(isian.tandaSel(12880, tahap, 'pembacaan', 2), TandaSel.tidakAda);
  });

  test('beberapa sel sekaligus', () {
    final isian = isianDenganRevisi({
      'sel:$tahap:1412:pembacaan:3',
      'sel:$tahap:25:pembacaan:1',
    });

    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);
    expect(isian.tandaSel(25, tahap, 'pembacaan', 0), TandaSel.revisi);
    expect(isian.selRevisi.length, 2);
  });

  test('titik yang meleset di digit terakhir tetap ketemu barisnya', () {
    // `decimal(20,8)` yang bolak-balik lewat JSON gampang meleset di digit
    // terakhir. Tanpa toleransi, penandanya nyangkut di kunci yang nggak pernah
    // kegambar — dan admin ngira dia udah nandain sesuatu.
    final isian = isianDenganRevisi({'sel:$tahap:1412.00000001:pembacaan:3'});

    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);
  });

  test('permintaan admin menang atas keraguan mesin di sel yang sama', () {
    final isian = isianDenganRevisi({'sel:$tahap:1412:pembacaan:3'});

    isian.selRendahKeyakinan.add(
      LembarKerjaState.kunciSel(1412, tahap, 'pembacaan', 2),
    );

    // Yang satu tebakan mesin, yang satu keputusan orang yang bakal
    // nandatangani sertifikatnya.
    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);
  });

  test('sel yang cuma diragukan mesin tetap kuning', () {
    final isian = isianDenganRevisi(const {});

    isian.selRendahKeyakinan.add(
      LembarKerjaState.kunciSel(25, tahap, 'pembacaan', 0),
    );

    expect(isian.tandaSel(25, tahap, 'pembacaan', 0), TandaSel.keyakinanRendah);
  });

  test('kode kolom biasa tetap jalan & nggak jadi penanda sel', () {
    final isian = isianDenganRevisi({'alat_serial_number'});

    expect(isian.revisiField, contains('alat_serial_number'));
    expect(isian.selRevisi, isEmpty);
    expect(isian.adaRevisi, isTrue);
  });

  /// Versi HP bisa lebih tua dari versi admin yang ngirim. Nolak seluruh lembar
  /// gara-gara satu penanda yang nggak kebaca jauh lebih merugikan daripada
  /// satu kotak yang nggak kesorot — catatan prosanya tetap nyampe.
  for (final rusak in const [
    'sel:$tahap:1412:pembacaan',
    'sel:$tahap:1412:pembacaan:3:4',
    'sel:$tahap:1412:pembacaan:tiga',
    'sel:$tahap:1412:pembacaan:0',
    'sel:$tahap:awal:pembacaan:3',
    'sel::1412:pembacaan:3',
    'sel:$tahap:1412::3',
    'sel:$tahap:99999:pembacaan:3',
  ]) {
    test('kode rusak diabaikan tanpa bikin error: $rusak', () {
      final isian = isianDenganRevisi({rusak});

      expect(isian.selRevisi, isEmpty);
      // Catatannya tetap nyampe — itu yang bikin teknisi ngerti harus ngapain.
      expect(isian.adaRevisi, isTrue);
    });
  }

  test('penanda selamat waktu bentuk lembar diganti ke bentuk alat', () {
    // Ini kejadian di TIAP sesi: layar kebuka dengan bentuk GENERIK, baru
    // sesudah alatnya kebaca backend ngirim bentuk yang disusutin ke alat itu.
    // Barisnya dibangun ulang, dan kuncinya ikut geser — lembar generik
    // Conductivity punya baris varian satuan yang lenyap begitu alatnya kepilih.
    //
    // Tanpa disusun ulang, teknisi lihat lembar revisi tanpa satu pun kotak
    // merah, padahal admin sudah nandain — dan dia balik ke jalan aman:
    // ngosongin tabel, ngetik ulang semuanya.
    final isian = isianDenganRevisi({'sel:$tahap:1412:pembacaan:3'});

    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);

    final disusutkan = LembarKerja.fromJson({
      'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
      'judul': 'Calibration Worksheet - Conductivity Meter',
      'untuk': 'teknisi',
      'jumlah_pengulangan': 5,
      'satuan_campuran': true,
      'bagian': [
        {
          'kode': 'hasil',
          'judul': 'CALIBRATION RESULT',
          'tabel': [
            {
              'tahap': 'sesudah_adjustment',
              'judul': 'After adjustment Reading',
              'kolom': [
                {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
              ],
              'pengulangan': [1, 2, 3, 4, 5],
              'baris': [
                {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm'},
              ],
            },
          ],
        },
      ],
    });

    isian.gantiBentuk(disusutkan);

    expect(isian.tandaSel(1412, tahap, 'pembacaan', 2), TandaSel.revisi);
  });

  test('penanda ke baris yang lenyap ikut hilang, nggak nyasar ke baris lain', () {
    final isian = isianDenganRevisi({'sel:$tahap:12880:pembacaan:1'});

    expect(isian.tandaSel(12880, tahap, 'pembacaan', 0), TandaSel.revisi);

    final tanpa12880 = LembarKerja.fromJson({
      'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
      'judul': 'Calibration Worksheet - Conductivity Meter',
      'untuk': 'teknisi',
      'jumlah_pengulangan': 5,
      'satuan_campuran': true,
      'bagian': [
        {
          'kode': 'hasil',
          'judul': 'CALIBRATION RESULT',
          'tabel': [
            {
              'tahap': 'sesudah_adjustment',
              'judul': 'After adjustment Reading',
              'kolom': [
                {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
              ],
              'pengulangan': [1, 2, 3, 4, 5],
              'baris': [
                {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm'},
                {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm'},
              ],
            },
          ],
        },
      ],
    });

    isian.gantiBentuk(tanpa12880);

    // Yang penting BUKAN cuma penandanya hilang — tapi nggak pindah ke baris
    // lain. Kotak merah di angka yang sudah benar bikin teknisi mbetulin yang
    // nggak salah, dan yang salah tetap lolos.
    expect(isian.selRevisi, isEmpty);
    expect(isian.tandaSel(25, tahap, 'pembacaan', 0), TandaSel.tidakAda);
    expect(isian.tandaSel(1412, tahap, 'pembacaan', 0), TandaSel.tidakAda);
  });

  group('temuan validator jadi penanda sekali ketuk', () {
    Temuan temuan({required String pesan, String? kodeSel}) => Temuan.fromJson({
      'tingkat': 'peringatan',
      'kode': 'pembacaan_di_luar_rentang',
      'pesan': pesan,
      'konteks': {
        'titik_ke': 2,
        'pembacaan_ke': 3,
        if (kodeSel != null) 'kode_sel': kodeSel,
      },
    });

    test('temuan bawa kode selnya', () {
      final t = temuan(
        pesan: 'Titik ke-2 Repeat 3: komanya kegeser.',
        kodeSel: 'sel:$tahap:1412:pembacaan:3',
      );

      expect(t.kodeSel, 'sel:$tahap:1412:pembacaan:3');
    });

    test('temuan tanpa kode sel balik null, bukan string kosong', () {
      expect(temuan(pesan: 'Standar acuannya belum dipilih.').kodeSel, isNull);
      expect(
        Temuan.fromJson({
          'tingkat': 'peringatan',
          'kode': 'x',
          'pesan': 'y',
          'konteks': {'kode_sel': ''},
        }).kodeSel,
        isNull,
      );
    });
  });
}
