import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/ringkasan_sebelum_kirim.dart';
import 'package:sidik_calibration/screens/calibration/verifikasi_sel_dicek.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;
import 'package:sidik_calibration/services/peta_tabel_foto.dart';
import 'package:sidik_calibration/services/verifikasi_sel_service.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Gerbang "wajib dicek": kirim final ditahan sampai SETIAP sel hasil kamera
/// dicek teknisi satu per satu.
///
/// Yang dikunci di sini (tanpa layar):
///  - sel dianggap dicek HANYA lewat konfirmasi pada sel itu atau lewat
///    perubahan nilainya; tidak ada jalan untuk mengonfirmasi banyak sel;
///  - tulisan tangan tidak pernah hijau / otomatis dicek;
///  - sel kosong tetap kosong dan tidak ikut dihitung;
///  - status tahan muat ulang (salinan HP) dan ikut payload;
///  - ringkasan sebelum kirim memperlakukannya sebagai butir yang MENAHAN;
///  - konfirmasi ke server berupa daftar id eksplisit, tidak pernah massal.
void main() {
  const alat = EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Mettler Toledo',
    model: 'Five Easy',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA CONTOH MANDIRI',
    pelangganAlamat: 'Jl. Contoh Primer A-10, Kab. Bandung',
  );

  LembarKerjaState isianBaru() =>
      LembarKerjaState(
          bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
          clientRequestId: 'uji-gerbang-cek',
        )
        ..alat = alat
        ..isiDariAlat();

  TabelHasil tabelSesudah(LembarKerjaState s) => s.bentuk.bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.tahap == 'sesudah_adjustment');

  SelTabelFoto sel(
    double titik,
    int repeat,
    String teks, {
    double? keyakinan = 0.99,
    String kolom = 'pembacaan',
  }) => (
    titikUkur: titik,
    repeatNo: repeat,
    fieldId: kolom,
    teks: teks,
    keyakinan: keyakinan,
  );

  /// Tiga sel pembacaan hasil foto di tiga titik.
  LembarKerjaState dariFoto() {
    final s = isianBaru();
    final terisi = s.terapkanHasilFotoTabel([
      sel(4.0, 1, '4,01'),
      sel(7.0, 1, '7,02'),
      sel(10.01, 1, '10,00'),
    ], tabel: tabelSesudah(s));
    expect(terisi, 3, reason: 'prasyarat: tiga sel foto mendarat');

    return s;
  }

  String kunciUnik(double titik, {int index = 0}) =>
      'tabel|${LembarKerjaState.kunciSel(titik, 'sesudah_adjustment', 'pembacaan', index)}';

  group('CatatanCek', () {
    test('tanpa penanda atau kosong = tanpa tanda', () {
      final c = CatatanCek();

      expect(
        c.status('a', ditandai: false, teks: '7,02'),
        StatusCekSel.tanpaTanda,
      );
      c.tandai('a', '7,02');
      expect(
        c.status('a', ditandai: true, teks: '  '),
        StatusCekSel.tanpaTanda,
        reason: 'sel kosong tetap kosong: tidak ada yang perlu dicek',
      );
    });

    test('baru dari mesin = perlu dicek, sampai konfirmasi atau diubah', () {
      final c = CatatanCek()..tandai('a', '7,02');

      expect(
        c.status('a', ditandai: true, teks: '7,02'),
        StatusCekSel.perluCek,
      );
      expect(
        c.status('a', ditandai: true, teks: '7.020'),
        StatusCekSel.perluCek,
        reason: 'angka sama beda penulisan = belum diubah',
      );
      expect(
        c.status('a', ditandai: true, teks: '7,03'),
        StatusCekSel.sudahDicek,
        reason: 'mengubah nilai = teknisi sudah melihatnya',
      );

      c.konfirmasi('a');
      expect(
        c.status('a', ditandai: true, teks: '7,02'),
        StatusCekSel.sudahDicek,
      );
    });

    test(
      'mesin menaruh angka baru di sel yang sudah dikonfirmasi: cek ulang',
      () {
        final c = CatatanCek()
          ..tandai('a', '7,02')
          ..konfirmasi('a')
          ..tandai('a', '7,50');

        expect(
          c.status('a', ditandai: true, teks: '7,50'),
          StatusCekSel.perluCek,
        );
      },
    );

    test('tanpa isi awal (salinan lama) tetap perlu dicek, tidak otomatis', () {
      final c = CatatanCek();

      expect(
        c.status('a', ditandai: true, teks: '7,02'),
        StatusCekSel.perluCek,
      );
    });

    test('toJson / pulihkan pulang-pergi', () {
      final c = CatatanCek()
        ..tandai('a', '7,02')
        ..tandai('b', '4,01')
        ..konfirmasi('b');
      final d = CatatanCek()..pulihkan(c.toJson());

      expect(
        d.status('a', ditandai: true, teks: '7,02'),
        StatusCekSel.perluCek,
      );
      expect(
        d.status('b', ditandai: true, teks: '4,01'),
        StatusCekSel.sudahDicek,
      );
    });
  });

  group('gerbang di state lembar', () {
    test('semua sel foto masuk "perlu dicek", termasuk keyakinan 0,99', () {
      final s = dariFoto();

      expect(
        NilaiVonisFoto.dari(0.99),
        isNot(VonisFoto.hijau),
        reason: 'tulisan tangan tidak pernah hijau',
      );
      expect(s.jumlahPerluCek, 3);
      expect(s.daftarSelCek().map((x) => x.status).toSet(), {
        StatusCekSel.perluCek,
      });
    });

    test('lembar tanpa foto: tidak ada sel, tidak ada gerbang', () {
      final s = isianBaru();
      s.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '7,00';

      expect(s.jumlahPerluCek, 0);
      expect(s.daftarSelCek(), isEmpty);
      expect(s.selCekBerikutnya(), isNull);
      expect(
        s.toSubmission(draft: false).toJson(),
        isNot(contains('cek_bacaan')),
      );
    });

    test('konfirmasi mengubah SATU sel saja', () {
      final s = dariFoto();

      expect(s.konfirmasiSelCek(kunciUnik(7.0)), isTrue);

      expect(s.jumlahPerluCek, 2);
      final status = {for (final x in s.daftarSelCek()) x.kunci: x.status};
      expect(status[kunciUnik(7.0)], StatusCekSel.sudahDicek);
      expect(status[kunciUnik(4.0)], StatusCekSel.perluCek);
      expect(status[kunciUnik(10.01)], StatusCekSel.perluCek);
    });

    test('konfirmasi kunci asing atau sel yang sudah dicek: tidak berubah', () {
      final s = dariFoto();

      expect(s.konfirmasiSelCek('tabel|bukan-kunci'), isFalse);
      expect(s.konfirmasiSelCek('apa-saja'), isFalse);
      s.konfirmasiSelCek(kunciUnik(7.0));
      expect(s.konfirmasiSelCek(kunciUnik(7.0)), isFalse);
      expect(s.jumlahPerluCek, 2);
    });

    test(
      'mengubah nilai = dicek; mengembalikan ke angka mesin = perlu cek lagi',
      () {
        final s = dariFoto();
        final kotak = s.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0);

        kotak.text = '7,05';
        expect(s.jumlahPerluCek, 2);

        kotak.text = '7,02';
        expect(s.jumlahPerluCek, 3);
      },
    );

    test('sel yang dikosongkan teknisi tidak dihitung', () {
      final s = dariFoto();

      s.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '';

      expect(s.jumlahPerluCek, 2);
      expect(
        s.daftarSelCek().map((x) => x.kunci),
        isNot(contains(kunciUnik(7.0))),
      );
    });

    test('selCekBerikutnya: urut, memutar, dan null saat semua dicek', () {
      final s = dariFoto();
      final urut = s.daftarSelCek().map((x) => x.kunci).toList();

      expect(s.selCekBerikutnya()!.kunci, urut.first);
      expect(s.selCekBerikutnya(setelah: urut.first)!.kunci, urut[1]);
      expect(
        s.selCekBerikutnya(setelah: urut.last)!.kunci,
        urut.first,
        reason: 'memutar ke awal',
      );

      for (final k in urut) {
        s.konfirmasiSelCek(k);
      }
      expect(s.selCekBerikutnya(), isNull);
      expect(s.jumlahPerluCek, 0);
    });

    test('sel kamera yang diisi ulang oleh mesin kembali perlu dicek', () {
      final s = dariFoto();
      s.konfirmasiSelCek(kunciUnik(7.0));

      final kotak = s.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0)
        ..text = '';
      expect(kotak.text, isEmpty);
      s.terapkanHasilFotoTabel([sel(7.0, 1, '7,10')], tabel: tabelSesudah(s));

      expect(s.jumlahPerluCek, 3, reason: 'angka baru dari mesin, cek ulang');
    });

    test('revisiCek naik saat konfirmasi dan saat jumlah berubah', () {
      final s = dariFoto();
      final awal = s.revisiCek.value;

      s.konfirmasiSelCek(kunciUnik(4.0));
      expect(s.revisiCek.value, greaterThan(awal));

      final sebelum = s.revisiCek.value;
      s.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '7,09';
      s.segarkanCek();
      expect(s.revisiCek.value, greaterThan(sebelum));
    });
  });

  group('tahan muat ulang dan payload', () {
    test('salinan lokal membawa status; sel yang sudah dicek tetap dicek', () {
      final s = dariFoto();
      s.konfirmasiSelCek(kunciUnik(7.0));
      final salinan = s.salinanLokal();

      final baru = isianBaru()..pulihkanSalinanLokal(salinan);

      expect(baru.jumlahPerluCek, 2);
      final status = {for (final x in baru.daftarSelCek()) x.kunci: x.status};
      expect(status[kunciUnik(7.0)], StatusCekSel.sudahDicek);
      expect(status[kunciUnik(4.0)], StatusCekSel.perluCek);
    });

    test(
      'salinan lama tanpa blok cek_bacaan: penanda kamera tetap menahan',
      () {
        final s = dariFoto();
        final salinan = Map<String, dynamic>.of(s.salinanLokal())
          ..remove('cek_bacaan');

        final baru = isianBaru()..pulihkanSalinanLokal(salinan);

        expect(baru.jumlahPerluCek, 3);
      },
    );

    test('payload memuat daftar perlu_cek dan sudah_dicek', () {
      final s = dariFoto();
      s.konfirmasiSelCek(kunciUnik(7.0));

      final cek =
          s.toSubmission(draft: true).toJson()['cek_bacaan']
              as Map<String, dynamic>;

      expect(cek['sudah_dicek'], [kunciUnik(7.0)]);
      expect(cek['perlu_cek'], [kunciUnik(4.0), kunciUnik(10.01)]);
    });

    test('draf tetap bisa dirakit walau ada sel yang belum dicek', () {
      final s = dariFoto();

      expect(() => s.toSubmission(draft: true), returnsNormally);
    });
  });

  group('ringkasan sebelum kirim', () {
    test('sel belum dicek = butir yang MENAHAN, dengan jumlah', () {
      final s = dariFoto();

      final r = susunRingkasanSebelumKirim(s);

      expect(r.menahan, isTrue);
      final butir = r.wajib.singleWhere(
        (b) => b.jenis == JenisButirRingkasan.ocrPerluDicek,
      );
      expect(butir.jumlah, 3);
      expect(butir.lompat, startsWith('bagian:'));
      expect(r.peringatan, isEmpty);
    });

    test('semua dicek satu per satu: butir hilang', () {
      final s = dariFoto();
      for (final k in s.daftarSelCek().map((x) => x.kunci).toList()) {
        s.konfirmasiSelCek(k);
      }

      final r = susunRingkasanSebelumKirim(s);

      expect(
        r.wajib.map((b) => b.jenis),
        isNot(contains(JenisButirRingkasan.ocrPerluDicek)),
      );
      expect(r.menahan, isFalse);
    });
  });

  group('tanpa verifikasi massal di jalur lembar kerja', () {
    // Penjaga sumber: panggilan massal (badan kosong = "semua yang belum
    // dicek") adalah persis yang dihapus. Test perilaku di bawah membuktikan
    // jalur baru; ini mencegah panggilan lama kembali lewat pintu lain.
    test('layar lembar kerja tidak memanggil verifikasiPembacaan', () {
      final layar = File(
        'lib/screens/calibration/lembar_kerja_screen.dart',
      ).readAsStringSync();

      expect(layar, isNot(contains('verifikasiPembacaan(')));
      expect(layar, contains('verifikasiBarisSelDicek('));
    });

    test('pembantu konfirmasi tidak memakai jalur massal', () {
      final pembantu = File(
        'lib/screens/calibration/verifikasi_sel_dicek.dart',
      ).readAsStringSync();

      expect(pembantu, isNot(contains('verifikasiPembacaan(')));
    });
  });

  group('konfirmasi ke server: id eksplisit, tidak pernah massal', () {
    RawMeasurement baris(int id, {required bool terverifikasi}) =>
        RawMeasurement(
          id: id,
          titikKe: 1,
          titikUkur: 7.0,
          pembacaanKe: id,
          pembacaan: 7.0,
          inputSource: 'ocr',
          isVerified: terverifikasi,
        );

    test(
      'masih ada sel belum dicek: tidak ada panggilan sama sekali',
      () async {
        final s = dariFoto();
        final riwayat = _Riwayat([baris(1, terverifikasi: false)]);
        final verifikasi = MockVerifikasiSelService();

        final n = await verifikasiBarisSelDicek(
          token: 't',
          sesiId: 1,
          isian: s,
          riwayat: riwayat,
          verifikasi: verifikasi,
        );

        expect(n, 0);
        expect(verifikasi.panggilan, isEmpty);
        expect(riwayat.diverifikasi, isEmpty);
        expect(riwayat.detailDiambil, 0);
      },
    );

    test(
      'semua dicek: hanya baris yang belum terverifikasi, lewat daftar id',
      () async {
        final s = dariFoto();
        for (final k in s.daftarSelCek().map((x) => x.kunci).toList()) {
          s.konfirmasiSelCek(k);
        }
        final riwayat = _Riwayat([
          baris(11, terverifikasi: false),
          baris(12, terverifikasi: true),
          baris(13, terverifikasi: false),
        ]);
        final verifikasi = MockVerifikasiSelService();

        final n = await verifikasiBarisSelDicek(
          token: 't',
          sesiId: 1,
          isian: s,
          riwayat: riwayat,
          verifikasi: verifikasi,
        );

        expect(n, 2);
        expect(verifikasi.panggilan.single.sesiId, 1);
        expect(verifikasi.panggilan.single.ids, [11, 13]);
        expect(
          riwayat.diverifikasi,
          isEmpty,
          reason: 'jalur massal (badan kosong) tidak boleh dipakai',
        );
      },
    );

    test(
      'daftar id kosong ditolak service, tidak diam-diam jadi "semua"',
      () async {
        final verifikasi = MockVerifikasiSelService();

        expect(
          () => verifikasi.verifikasi('t', 1, const []),
          throwsArgumentError,
        );
      },
    );

    test(
      'tidak ada baris yang belum terverifikasi: server tidak dipanggil',
      () async {
        final s = dariFoto();
        for (final k in s.daftarSelCek().map((x) => x.kunci).toList()) {
          s.konfirmasiSelCek(k);
        }
        final verifikasi = MockVerifikasiSelService();

        final n = await verifikasiBarisSelDicek(
          token: 't',
          sesiId: 1,
          isian: s,
          riwayat: _Riwayat([baris(1, terverifikasi: true)]),
          verifikasi: verifikasi,
        );

        expect(n, 0);
        expect(verifikasi.panggilan, isEmpty);
      },
    );
  });
}

/// Riwayat yang cuma menjawab detail sesi dan mencatat jalur massal.
class _Riwayat extends MockHistoryService {
  _Riwayat(this._baris);

  final List<RawMeasurement> _baris;
  int detailDiambil = 0;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    detailDiambil++;
    final asli = await super.ambilDetail(token, id);

    return CalibrationDetail(
      id: asli.id,
      namaAlat: asli.namaAlat,
      status: asli.status,
      tanggalKalibrasi: asli.tanggalKalibrasi,
      namaTeknisi: asli.namaTeknisi,
      pembacaanMentah: _baris,
    );
  }
}
