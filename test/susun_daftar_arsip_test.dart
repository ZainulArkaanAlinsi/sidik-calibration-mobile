import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/susun_daftar_arsip.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/garis_waktu_arsip.dart';

/// Penataan baris layar Arsip: satu baris per alat (nomor seri), PT terpisah
/// jelas, dan dokumen per hari. Fungsi murni — yang dijaga bukan tampilan,
/// melainkan bahwa urutan server tidak diubah dan tidak ada baris yang hilang.
///
/// Data: nama alat, PT, dan nomor seri disalin dari contoh kontrak API
/// `docs/perintah-frontend-arsip-cari.md` (PT Contoh Alfa, SN-0204/SN-0205).

CalibrationHistoryItem _sesi(
  int id, {
  String? seri,
  String? pt = 'PT Contoh Alfa',
  String alat = 'Jangka Sorong',
  int? alatId,
  String? statusSertifikat,
}) => CalibrationHistoryItem(
  id: id,
  namaAlat: alat,
  namaTeknisi: 'Dr. Arch Schaefer',
  status: CalibrationStatus.disetujui,
  nomorSeri: seri,
  namaPelanggan: pt,
  equipmentId: alatId,
  statusSertifikat: statusSertifikat,
);

ItemGarisWaktu _dokumen(
  int id, {
  DateTime? tanggal,
  String? pt = 'PT Contoh Alfa',
  int? ptId = 1,
}) => ItemGarisWaktu(
  id: id,
  nomor: 'CAL/2026/11/$id',
  status: 'terbit',
  tanggal: tanggal,
  perusahaan: pt,
  pelangganId: ptId,
);

KelompokGarisWaktu _hari(String kunci, int jumlah) =>
    KelompokGarisWaktu(kunci: kunci, label: 'label $kunci', jumlah: jumlah);

List<int> _idWakil(List<KelompokInstrumen> k) => [
  for (final x in k) x.wakil.id,
];

void main() {
  group('satu baris per alat (nomor seri)', () {
    test('sesi dengan nomor seri sama digabung, yang pertama jadi wakil', () {
      final k = kelompokkanPerAlat([
        _sesi(30, seri: 'SN-0204'),
        _sesi(20, seri: 'SN-0205', alat: 'Micrometer'),
        _sesi(10, seri: 'SN-0204'),
      ]);

      expect(_idWakil(k), [30, 20]);
      expect(k.first.lainnya.map((s) => s.id), [10]);
      expect(k.last.lainnya, isEmpty);
    });

    test('huruf besar/kecil dan spasi di ujung tidak membedakan alat', () {
      final k = kelompokkanPerAlat([
        _sesi(3, seri: 'SN-0204'),
        _sesi(2, seri: ' sn-0204 '),
      ]);

      expect(_idWakil(k), [3]);
      expect(k.single.lainnya.single.id, 2);
    });

    test('tanda baca TIDAK dibuang: SN-0204 dan SN0204 adalah dua alat', () {
      final k = kelompokkanPerAlat([
        _sesi(2, seri: 'SN-0204'),
        _sesi(1, seri: 'SN0204'),
      ]);

      expect(_idWakil(k), [2, 1]);
    });

    test('tanpa nomor seri tidak pernah digabung', () {
      final k = kelompokkanPerAlat([
        _sesi(3),
        _sesi(2, seri: ''),
        _sesi(1, seri: '   '),
      ]);

      expect(_idWakil(k), [3, 2, 1]);
      expect(k.every((x) => x.lainnya.isEmpty), isTrue);
    });

    test('nomor seri yang sama di PT berbeda adalah alat berbeda', () {
      final k = kelompokkanPerAlat([
        _sesi(2, seri: 'SN-1', pt: 'PT Contoh Alfa'),
        _sesi(1, seri: 'SN-1', pt: 'PT Contoh Beta'),
      ]);

      expect(_idWakil(k), [2, 1]);
    });

    test('urutan server dipertahankan; tidak ada sesi yang hilang', () {
      final masuk = [
        _sesi(9, seri: 'A'),
        _sesi(8, seri: 'B'),
        _sesi(7, seri: 'A'),
        _sesi(6),
        _sesi(5, seri: 'B'),
        _sesi(4, seri: 'A'),
      ];

      final k = kelompokkanPerAlat(masuk);

      expect(_idWakil(k), [9, 8, 6]);
      final semua = [
        for (final x in k) x.wakil.id,
        for (final x in k) ...x.lainnya.map((s) => s.id),
      ]..sort();
      expect(semua, [4, 5, 6, 7, 8, 9]);
      // Sesi lain alat yang sama menjaga urutan kemunculannya.
      expect(k.first.lainnya.map((s) => s.id), [7, 4]);
    });

    test('daftar kosong menghasilkan daftar kosong', () {
      expect(kelompokkanPerAlat(const []), isEmpty);
      expect(susunHasil(const [], judulPt: true), isEmpty);
    });
  });

  group('identitas alat = id alat, bukan nomor seri ketikan', () {
    test('dua alat berseri "-" (id berbeda) TIDAK terlipat', () {
      final k = kelompokkanPerAlat([
        _sesi(3, seri: '-', alatId: 1),
        _sesi(2, seri: '-', alatId: 2, alat: 'Oven'),
        _sesi(1, seri: '-', alatId: 1),
      ]);

      expect(_idWakil(k), [3, 2]);
      expect(k.first.lainnya.map((s) => s.id), [1]);
      expect(k.last.lainnya, isEmpty);
    });

    test('alat yang sama terlipat walau serinya diketik berbeda', () {
      final k = kelompokkanPerAlat([
        _sesi(3, seri: 'SN-0204', alatId: 5),
        _sesi(2, seri: 'SN0204 ', alatId: 5),
        _sesi(1, alatId: 5),
      ]);

      expect(k, hasLength(1));
      expect(k.single.lainnya, hasLength(2));
      expect(k.single.kunci, 'alat:5');
    });

    test('dua jenis alat berseri sama di satu PT tidak terlipat', () {
      final k = kelompokkanPerAlat([
        _sesi(2, seri: 'SN-1', alatId: 1, alat: 'Jangka Sorong'),
        _sesi(1, seri: 'SN-1', alatId: 2, alat: 'Micrometer'),
      ]);

      expect(_idWakil(k), [2, 1]);
    });

    test('tanpa id alat: seri placeholder tidak pernah melipat', () {
      final placeholder = ['-', '--', 'N/A', ' n/a ', 'NA', '0', '00', 'none'];
      final k = kelompokkanPerAlat([
        for (var i = 0; i < placeholder.length; i++)
          _sesi(100 - i, seri: placeholder[i]),
      ]);

      expect(k, hasLength(placeholder.length));
      expect(k.every((x) => x.lainnya.isEmpty), isTrue);
    });

    test('tanpa id alat: cadangan butuh PT, NAMA ALAT, dan seri yang sama', () {
      final k = kelompokkanPerAlat([
        _sesi(4, seri: 'SN-1'),
        _sesi(3, seri: 'sn-1'),
        _sesi(2, seri: 'SN-1', alat: 'Micrometer'),
        _sesi(1, seri: 'SN-1', pt: 'PT Contoh Beta'),
      ]);

      expect(_idWakil(k), [4, 2, 1]);
      expect(k.first.lainnya.map((s) => s.id), [3]);
    });

    test('id alat menang atas seri: id sama + seri beda = satu alat; id '
        'beda + seri sama = dua alat', () {
      final satu = kelompokkanPerAlat([
        _sesi(2, seri: 'A', alatId: 7),
        _sesi(1, seri: 'B', alatId: 7),
      ]);
      final dua = kelompokkanPerAlat([
        _sesi(2, seri: 'A', alatId: 7),
        _sesi(1, seri: 'A', alatId: 8),
      ]);

      expect(satu, hasLength(1));
      expect(dua, hasLength(2));
    });
  });

  group('wakil lipatan = sertifikat terbit terbaru', () {
    test(
      'sesi terbaru masih draf: wakilnya terbitan terbaru, draf dilipat',
      () {
        final k = kelompokkanPerAlat([
          _sesi(30, alatId: 5),
          _sesi(20, alatId: 5, statusSertifikat: 'terbit'),
          _sesi(10, alatId: 5, statusSertifikat: 'terbit'),
        ]);

        expect(k.single.wakil.id, 20);
        expect(k.single.lainnya.map((s) => s.id), [30, 10]);
      },
    );

    test('tanpa terbitan: wakil = sesi terbaru, walau server mengurutkan '
        'lain (peringkat cocok-persis)', () {
      final k = kelompokkanPerAlat([
        _sesi(5, alatId: 5),
        _sesi(9, alatId: 5),
        _sesi(7, alatId: 5),
      ]);

      expect(k.single.wakil.id, 9);
      expect(k.single.lainnya.map((s) => s.id), [5, 7]);
    });

    test('sertifikat dibatalkan/ditarik/gagal bukan terbitan', () {
      final k = kelompokkanPerAlat([
        _sesi(30, alatId: 5, statusSertifikat: 'dibatalkan'),
        _sesi(25, alatId: 5, statusSertifikat: 'ditarik'),
        _sesi(22, alatId: 5, statusSertifikat: 'gagal'),
        _sesi(20, alatId: 5, statusSertifikat: 'terbit'),
      ]);

      expect(k.single.wakil.id, 20);
    });

    test('semua dibatalkan: sesi terbaru yang jadi wakil', () {
      final k = kelompokkanPerAlat([
        _sesi(20, alatId: 5, statusSertifikat: 'dibatalkan'),
        _sesi(30, alatId: 5, statusSertifikat: 'dibatalkan'),
      ]);

      expect(k.single.wakil.id, 30);
    });

    test('posisi kelompok = kemunculan pertama anggotanya, bukan wakilnya', () {
      final k = kelompokkanPerAlat([
        _sesi(9, alatId: 1),
        _sesi(8, alatId: 2),
        _sesi(7, alatId: 1, statusSertifikat: 'terbit'),
      ]);

      // Alat 1 tetap di atas alat 2 (halaman berikutnya tak menyelip), tetapi
      // yang tampil adalah terbitannya (sesi 7).
      expect(_idWakil(k), [7, 8]);
    });
  });

  group('susunHasil: judul PT', () {
    String ringkas(BarisDaftarArsip b) => switch (b) {
      BarisJudulPt(:final nama) => 'PT:${nama ?? '-'}',
      BarisInstrumen(:final instrumen) => 'alat:${instrumen.wakil.id}',
      BarisJudulHari() || BarisSertifikat() => '?',
    };

    test('judul muncul tiap PT berganti, urutan server tidak diubah', () {
      final baris = susunHasil([
        _sesi(5, seri: 'A', pt: 'PT Contoh Alfa'),
        _sesi(4, seri: 'B', pt: 'PT Contoh Alfa'),
        _sesi(3, seri: 'C', pt: 'PT Contoh Beta'),
        _sesi(2, seri: 'D', pt: 'PT Contoh Alfa'),
      ], judulPt: true);

      expect(baris.map(ringkas), [
        'PT:PT Contoh Alfa',
        'alat:5',
        'alat:4',
        'PT:PT Contoh Beta',
        'alat:3',
        // Alfa muncul lagi: urutan server lebih penting daripada menyatukan
        // judul (halaman berikutnya selalu menempel di bawah).
        'PT:PT Contoh Alfa',
        'alat:2',
      ]);
    });

    test('PT yang sama tapi beda huruf besar/kecil tidak dapat judul baru', () {
      final baris = susunHasil([
        _sesi(2, seri: 'A', pt: 'PT Contoh Alfa'),
        _sesi(1, seri: 'B', pt: ' pt contoh alfa '),
      ], judulPt: true);

      expect(baris.whereType<BarisJudulPt>(), hasLength(1));
    });

    test('tanpa pelanggan dapat judul "tanpa pelanggan" (nama null)', () {
      final baris = susunHasil([_sesi(1, seri: 'A', pt: null)], judulPt: true);

      expect((baris.first as BarisJudulPt).nama, isNull);
    });

    test('satu PT dipilih di saringan: tanpa judul sama sekali', () {
      final baris = susunHasil([
        _sesi(2, seri: 'A'),
        _sesi(1, seri: 'B'),
      ], judulPt: false);

      expect(baris.whereType<BarisJudulPt>(), isEmpty);
      expect(baris.whereType<BarisInstrumen>(), hasLength(2));
    });

    test('alat yang digabung memunculkan satu baris, bukan dua', () {
      final baris = susunHasil([
        _sesi(3, seri: 'SN-0204'),
        _sesi(2, seri: 'SN-0204'),
        _sesi(1, seri: 'SN-0204'),
      ], judulPt: false);

      final alat = baris.whereType<BarisInstrumen>().single;
      expect(alat.instrumen.wakil.id, 3);
      expect(alat.instrumen.lainnya, hasLength(2));
    });
  });

  group('susunHari: dokumen di bawah harinya', () {
    String ringkas(BarisDaftarArsip b) => switch (b) {
      BarisJudulHari(hari: final h) => 'hari:${h.kunci}(${h.jumlah})',
      BarisJudulPt(:final nama) => 'PT:${nama ?? '-'}',
      BarisSertifikat(:final item) => 'doc:${item.id}',
      BarisInstrumen() => '?',
    };

    final hari = [_hari('2026-11-12', 2), _hari('2026-11-09', 1)];

    test('urutan hari dan jumlahnya dari server; dokumen masuk harinya', () {
      final baris = susunHari(hari, [
        _dokumen(6, tanggal: DateTime(2026, 11, 12)),
        _dokumen(5, tanggal: DateTime(2026, 11, 12)),
        _dokumen(4, tanggal: DateTime(2026, 11, 9)),
      ], judulPt: false);

      expect(baris.map(ringkas), [
        'hari:2026-11-12(2)',
        'doc:6',
        'doc:5',
        'hari:2026-11-09(1)',
        'doc:4',
      ]);
    });

    test(
      'hari yang dokumennya belum termuat tetap tampil dengan jumlahnya',
      () {
        final baris = susunHari(hari, [
          _dokumen(6, tanggal: DateTime(2026, 11, 12)),
        ], judulPt: false);

        expect(baris.map(ringkas), [
          'hari:2026-11-12(2)',
          'doc:6',
          'hari:2026-11-09(1)',
        ]);
      },
    );

    test(
      'dokumen tanpa hari yang cocok diletakkan di ujung, bukan dibuang',
      () {
        final baris = susunHari(hari, [
          _dokumen(6, tanggal: DateTime(2026, 11, 12)),
          _dokumen(99, tanggal: DateTime(2026, 11, 20)),
          _dokumen(98),
        ], judulPt: false);

        expect(baris.whereType<BarisSertifikat>().map((b) => b.item.id), [
          6,
          99,
          98,
        ]);
      },
    );

    test('judul PT diulang di tiap hari, dan tiap kali PT berganti', () {
      final baris = susunHari(hari, [
        _dokumen(6, tanggal: DateTime(2026, 11, 12)),
        _dokumen(
          5,
          tanggal: DateTime(2026, 11, 12),
          pt: 'PT Contoh Beta',
          ptId: 2,
        ),
        _dokumen(4, tanggal: DateTime(2026, 11, 9)),
      ], judulPt: true);

      expect(baris.map(ringkas), [
        'hari:2026-11-12(2)',
        'PT:PT Contoh Alfa',
        'doc:6',
        'PT:PT Contoh Beta',
        'doc:5',
        'hari:2026-11-09(1)',
        'PT:PT Contoh Alfa',
        'doc:4',
      ]);
    });

    test(
      'PT yang sama di dua hari berurutan tetap dapat judul di tiap hari',
      () {
        final baris = susunHari(hari, [
          _dokumen(6, tanggal: DateTime(2026, 11, 12)),
          _dokumen(4, tanggal: DateTime(2026, 11, 9)),
        ], judulPt: true);

        expect(baris.map(ringkas), [
          'hari:2026-11-12(2)',
          'PT:PT Contoh Alfa',
          'doc:6',
          'hari:2026-11-09(1)',
          'PT:PT Contoh Alfa',
          'doc:4',
        ]);
      },
    );

    test('tanpa dokumen sama sekali: hanya judul hari', () {
      expect(susunHari(hari, const [], judulPt: true).map(ringkas), [
        'hari:2026-11-12(2)',
        'hari:2026-11-09(1)',
      ]);
    });
  });
}
