import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/garis_waktu_arsip.dart';

/// Parsing jawaban garis waktu arsip dan baris Riwayat `bentuk=ringan`.
///
/// Sumber bentuk, nama kunci, dan nilai: contoh JSON di kontrak API
/// `docs/perintah-frontend-arsip-cari.md` §2 (Riwayat) dan §3 (garis waktu) —
/// disalin apa adanya, bukan dikarang. Label seperti `Pekan 44 (1 Nov 2026)`
/// SENGAJA dibaca sebagai teks dari server; app tidak menghitung pekan.

Map<String, dynamic> _meta({
  int halaman = 1,
  int terakhir = 1,
  int perHalaman = 20,
  int total = 0,
}) => {
  'current_page': halaman,
  'last_page': terakhir,
  'per_page': perHalaman,
  'total': total,
};

// Kontrak §3, tingkat `tahun`.
final _tahun = <String, dynamic>{
  'data': {
    'tingkat': 'tahun',
    'induk': <String, dynamic>{},
    'total_dokumen': 6,
    'kelompok': [
      {
        'kunci': '2026',
        'label': '2026',
        'jumlah': 5,
        'mulai': '2026-01-01',
        'selesai': '2026-12-31',
        'telusuri': {'tingkat': 'bulan', 'tahun': 2026},
      },
      {
        'kunci': '2025',
        'label': '2025',
        'jumlah': 1,
        'mulai': '2025-01-01',
        'selesai': '2025-12-31',
        'telusuri': {'tingkat': 'bulan', 'tahun': 2025},
      },
    ],
    'item': <dynamic>[],
  },
  'meta': _meta(),
};

// Kontrak §3, tingkat `pekan` November: pekan 44 hanya berisi 1 Nov.
final _pekanNovember = <String, dynamic>{
  'data': {
    'tingkat': 'pekan',
    'induk': {'tahun': 2026, 'bulan': 11},
    'total_dokumen': 4,
    'kelompok': [
      {
        'kunci': '2026-W46',
        'label': 'Pekan 46 (9–15 Nov 2026)',
        'jumlah': 3,
        'mulai': '2026-11-09',
        'selesai': '2026-11-15',
        'telusuri': {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
        },
      },
      {
        'kunci': '2026-W44',
        'label': 'Pekan 44 (1 Nov 2026)',
        'jumlah': 1,
        'mulai': '2026-11-01',
        'selesai': '2026-11-01',
        'telusuri': {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 44,
        },
      },
    ],
    'item': <dynamic>[],
  },
  'meta': _meta(),
};

// Kontrak §3, tingkat `hari` dengan `per_page=2` (halaman 1 dari 2).
final _hari = <String, dynamic>{
  'data': {
    'tingkat': 'hari',
    'induk': {'tahun': 2026, 'bulan': 11, 'pekan': 46},
    'total_dokumen': 3,
    'kelompok': [
      {
        'kunci': '2026-11-12',
        'label': 'Kamis, 12 Nov 2026',
        'jumlah': 2,
        'mulai': '2026-11-12',
        'selesai': '2026-11-12',
        'telusuri': {
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
          'tingkat': 'hari',
          'tanggal': '2026-11-12',
        },
      },
      {
        'kunci': '2026-11-09',
        'label': 'Senin, 9 Nov 2026',
        'jumlah': 1,
        'mulai': '2026-11-09',
        'selesai': '2026-11-09',
        'telusuri': {
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
          'tingkat': 'hari',
          'tanggal': '2026-11-09',
        },
      },
    ],
    'item': [
      {
        'id': 6,
        'nomor': 'CAL/2026/11/0005',
        'status': 'terbit',
        'revisi_ke': null,
        'tanggal': '2026-11-12',
        'nama_alat': 'Micrometer',
        'serial_number': 'SN-0205',
        'perusahaan': 'PT Contoh Alfa',
        'customer_id': 1,
        'nomor_order': null,
        'calibration_session_id': 6,
        'pdf_url': 'http://localhost/api/certificates/6/download',
      },
      {
        'id': 5,
        'nomor': 'CAL/2026/11/0004',
        'status': 'terbit',
        'revisi_ke': null,
        'tanggal': '2026-11-12',
        'nama_alat': 'Jangka Sorong',
        'serial_number': 'SN-0204',
        'perusahaan': 'PT Contoh Alfa',
        'customer_id': 1,
        'nomor_order': 'PO-2026-0042',
        'calibration_session_id': 5,
        'pdf_url': 'http://localhost/api/certificates/5/download',
      },
    ],
  },
  'meta': _meta(perHalaman: 2, terakhir: 2, total: 3),
};

// Kontrak §2, satu baris `GET /api/calibrations?bentuk=ringan&q=sn-0204`.
final _barisRingan = <String, dynamic>{
  'id': 5,
  'nomor_sesi': 'KAL/2026/11/9005',
  'nomor_order': 'PO-2026-0042',
  'status': 'disetujui',
  'keputusan': 'PASS',
  'hasil': {'keputusan': 'PASS'},
  'tanggal_kalibrasi': '2026-11-11',
  'equipment': {
    'id': 5,
    'nama_alat': 'Jangka Sorong',
    'nama_alat_kemampuan': null,
    'profil': 'jangka_sorong',
    'serial_number': 'SN-0204',
  },
  'alat_serial_number': null,
  'pelanggan': {'id': 1, 'nama': 'PT Contoh Alfa'},
  'teknisi': {'id': 6, 'nama': 'Dr. Arch Schaefer'},
  'catatan_revisi': null,
  'certificate_id': 5,
  'sertifikat': {
    'id': 5,
    'nomor': 'CAL/2026/11/0004',
    'status': 'terbit',
    'diterbitkan_pada': '2026-11-12',
  },
  'submitted_at': null,
  'reviewed_at': null,
  'updated_at': '2026-11-12T21:24:17+07:00',
  'tersembunyi': false,
};

void main() {
  group('tanggal kalender polos', () {
    test('dipecah per bagian: tidak bergeser zona dan tidak ada jam', () {
      final t = tanggalPolos('2026-11-12')!;

      expect(t, DateTime(2026, 11, 12));
      expect(t.isUtc, isFalse);
      expect(t.hour, 0);
    });

    test('bagian jam dibuang, harinya tetap hari yang tertulis', () {
      // Yang dijaga kontrak §0 butir 4: parse-ke-UTC lalu geser mengubah
      // harinya. Fixture sengaja MENYEBERANG tengah malam UTC supaya mutan
      // "geser zona" ketahuan juga di CI yang zonanya UTC:
      //   02:00 +07:00 = 19:00 UTC hari SEBELUMNYA,
      //   23:30 -05:00 = 04:30 UTC hari SESUDAHNYA.
      expect(tanggalPolos('2026-11-12T02:00:00+07:00'), DateTime(2026, 11, 12));
      expect(tanggalPolos('2026-11-12T23:30:00-05:00'), DateTime(2026, 11, 12));
      expect(tanggalPolos('2026-11-12T20:00:00+07:00'), DateTime(2026, 11, 12));
    });

    test('tanggal yang tidak ada di kalender tidak dibetulkan diam-diam', () {
      expect(tanggalPolos('2026-02-31'), isNull);
      expect(tanggalPolos('bukan tanggal'), isNull);
      expect(tanggalPolos(null), isNull);
      expect(tanggalPolos(20261112), isNull);
    });
  });

  group('PosisiGarisWaktu', () {
    test('menyimpan telusuri apa adanya, angka dijadikan teks', () {
      final posisi = PosisiGarisWaktu.dariTelusuri({
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
        'tanggal': '2026-11-12',
      })!;

      expect(posisi.parameter, {
        'tingkat': 'hari',
        'tahun': '2026',
        'bulan': '11',
        'pekan': '46',
        'tanggal': '2026-11-12',
      });
      expect(posisi.tingkat, TingkatGarisWaktu.hari);
    });

    test('urutan kunci dan angka-vs-teks tidak mempengaruhi kesamaan', () {
      final a = PosisiGarisWaktu.dariTelusuri({
        'tingkat': 'pekan',
        'tahun': 2026,
        'bulan': 11,
      });
      final b = PosisiGarisWaktu.dariTelusuri({
        'bulan': '11',
        'tahun': '2026',
        'tingkat': 'pekan',
      });

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          PosisiGarisWaktu.dariTelusuri({
            'tingkat': 'pekan',
            'tahun': 2026,
            'bulan': 10,
          }),
        ),
      );
    });

    test('kunci yang tidak dikenal ikut terbawa, bukan dibuang', () {
      final posisi = PosisiGarisWaktu.dariTelusuri({
        'tingkat': 'bulan',
        'tahun': 2026,
        'kunci_baru': 'x',
      })!;

      expect(posisi.parameter['kunci_baru'], 'x');
    });

    test('tanpa tingkat yang dikenal = bukan posisi', () {
      expect(PosisiGarisWaktu.dariTelusuri(null), isNull);
      expect(PosisiGarisWaktu.dariTelusuri({'tahun': 2026}), isNull);
      expect(PosisiGarisWaktu.dariTelusuri({'tingkat': 'dekade'}), isNull);
    });

    test('akar = tingkat tahun tanpa induk', () {
      expect(PosisiGarisWaktu.akar.parameter, {'tingkat': 'tahun'});
      expect(PosisiGarisWaktu.akar.tingkat, TingkatGarisWaktu.tahun);
    });
  });

  group('HalamanGarisWaktu', () {
    test('tingkat tahun: kelompok, jumlah, rentang, dan alamat bawahnya', () {
      final h = HalamanGarisWaktu.fromJson(_tahun);

      expect(h.tingkat, TingkatGarisWaktu.tahun);
      expect(h.totalDokumen, 6);
      expect(h.kelompok.map((k) => k.kunci), ['2026', '2025']);

      final k = h.kelompok.first;
      expect(k.jumlah, 5);
      expect(k.mulai, DateTime(2026));
      expect(k.selesai, DateTime(2026, 12, 31));
      expect(k.telusuri!.parameter, {'tingkat': 'bulan', 'tahun': '2026'});
      expect(h.item, isEmpty);
    });

    test(
      'pekan dipotong per bulan: label & rentang dari server apa adanya',
      () {
        final h = HalamanGarisWaktu.fromJson(_pekanNovember);
        final pekan44 = h.kelompok.last;

        expect(pekan44.kunci, '2026-W44');
        expect(pekan44.label, 'Pekan 44 (1 Nov 2026)');
        expect(pekan44.jumlah, 1);
        expect(pekan44.mulai, DateTime(2026, 11));
        expect(pekan44.selesai, DateTime(2026, 11));
        expect(pekan44.telusuri!.parameter['pekan'], '44');
        expect(pekan44.telusuri!.tingkat, TingkatGarisWaktu.hari);
      },
    );

    test('tingkat hari: dokumen, paginasi, dan alamat per hari', () {
      final h = HalamanGarisWaktu.fromJson(_hari);

      expect(h.tingkat, TingkatGarisWaktu.hari);
      expect(h.halaman, 1);
      expect(h.halamanTerakhir, 2);
      expect(h.totalItem, 3);

      expect(h.kelompok.first.telusuri!.parameter['tanggal'], '2026-11-12');
      expect(h.kelompok.first.label, 'Kamis, 12 Nov 2026');

      final satu = h.item.first;
      expect(satu.id, 6);
      expect(satu.nomor, 'CAL/2026/11/0005');
      expect(satu.status, 'terbit');
      expect(satu.revisiKe, isNull);
      expect(satu.tanggal, DateTime(2026, 11, 12));
      expect(satu.namaAlat, 'Micrometer');
      expect(satu.nomorSeri, 'SN-0205');
      expect(satu.perusahaan, 'PT Contoh Alfa');
      expect(satu.pelangganId, 1);
      expect(satu.nomorOrder, isNull);
      expect(satu.sesiId, 6);
      expect(satu.pdfUrl, 'http://localhost/api/certificates/6/download');

      expect(h.item.last.nomorOrder, 'PO-2026-0042');
    });

    test('satu dokumen cacat dilewati, sisanya tetap tampil', () {
      final rusak = Map<String, dynamic>.from(_hari);
      final data = Map<String, dynamic>.from(rusak['data'] as Map);
      data['item'] = [
        <String, dynamic>{'nomor': 'tanpa id'},
        ...(data['item'] as List),
      ];
      rusak['data'] = data;

      final h = HalamanGarisWaktu.fromJson(rusak);

      expect(h.item.map((i) => i.id), [6, 5]);
    });

    test('teks kosong pada alat/seri/order dianggap tidak ada', () {
      final h = HalamanGarisWaktu.fromJson({
        'data': {
          'tingkat': 'hari',
          'total_dokumen': 1,
          'kelompok': <dynamic>[],
          'item': [
            {
              'id': 1,
              'nomor': 'CAL/1',
              'status': 'terbit',
              'serial_number': '  ',
              'nomor_order': '',
              'nama_alat': '',
            },
          ],
        },
        'meta': _meta(),
      });

      final i = h.item.single;
      expect(i.nomorSeri, isNull);
      expect(i.nomorOrder, isNull);
      expect(i.namaAlat, isNull);
    });

    test('bentuk bukan garis waktu (server lama) dilempar, bukan dibaca '
        'sebagai kosong', () {
      expect(
        () =>
            HalamanGarisWaktu.fromJson({'data': <dynamic>[], 'meta': _meta()}),
        throwsFormatException,
      );
      expect(
        () => HalamanGarisWaktu.fromJson({
          'data': {'tingkat': 'tahun'},
        }),
        throwsFormatException,
      );
      expect(
        () => HalamanGarisWaktu.fromJson({
          'data': {'tingkat': 'dekade', 'kelompok': <dynamic>[]},
        }),
        throwsFormatException,
      );
    });
  });

  group('baris Riwayat bentuk ringan', () {
    test('dibaca CalibrationHistoryItem.fromJson tanpa perubahan', () {
      final s = CalibrationHistoryItem.fromJson(_barisRingan);

      expect(s.id, 5);
      expect(s.namaAlat, 'Jangka Sorong');
      expect(s.nomorSesi, 'KAL/2026/11/9005');
      expect(s.nomorOrder, 'PO-2026-0042');
      expect(s.nomorOrderDiketahui, isTrue);
      expect(s.status, CalibrationStatus.disetujui);
      expect(s.keputusan, Keputusan.pass);
      expect(s.nomorSertifikat, 'CAL/2026/11/0004');
      expect(s.statusSertifikat, 'terbit');
      expect(s.namaPelanggan, 'PT Contoh Alfa');
      // `alat_serial_number` null → jatuh ke seri alat terdaftar.
      expect(s.nomorSeri, 'SN-0204');
      expect(s.tanggalKalibrasi, DateTime(2026, 11, 11));
      // Identitas alat untuk lipatan "satu baris per alat".
      expect(s.equipmentId, 5);
    });

    test('id alat hilang atau bukan angka dibaca "tidak diketahui", barisnya '
        'tidak dibuang', () {
      final tanpaId = Map<String, dynamic>.from(_barisRingan)
        ..['equipment'] = {'nama_alat': 'Jangka Sorong'};
      final idTeks = Map<String, dynamic>.from(_barisRingan)
        ..['equipment'] = {'id': 'abc', 'nama_alat': 'Jangka Sorong'};

      expect(CalibrationHistoryItem.fromJson(tanpaId).equipmentId, isNull);
      expect(CalibrationHistoryItem.fromJson(idTeks).equipmentId, isNull);
      expect(CalibrationHistoryItem.fromJson(idTeks).namaAlat, 'Jangka Sorong');
    });

    test('tanpa keputusan: hasil null → tidak dibaca PASS', () {
      final tanpa = Map<String, dynamic>.from(_barisRingan)
        ..['hasil'] = null
        ..['keputusan'] = null;

      expect(CalibrationHistoryItem.fromJson(tanpa).keputusan, isNull);
    });
  });
}
