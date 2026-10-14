import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/draf_lokal.dart';

/// Simpanan lembar kerja di HP (F3, paket 30 Sep) — berkas JSON per akun.
///
/// Yang dijaga di sini aturan pemilik proyek K-30-09 (simpan 14 hari untuk
/// akun yang sama, buang begitu akun lain masuk) dan tulisan yang ATOMIK:
/// HP yang mati di tengah menulis nggak boleh meninggalkan salinan terpotong.
///
/// Pakai berkas sungguhan di folder sementara, bukan tiruan: yang paling
/// gampang rusak justru `rename` menimpa berkas yang sudah ada di Windows.
void main() {
  late Directory akar;
  late SimpananDrafLokalBerkas simpanan;

  setUp(() async {
    akar = await Directory.systemTemp.createTemp('draf_lokal_test_');
    simpanan = SimpananDrafLokalBerkas(
      () async => Directory('${akar.path}${Platform.pathSeparator}draf_lokal'),
    );
  });

  tearDown(() async {
    if (await akar.exists()) await akar.delete(recursive: true);
  });

  DrafLokal draf({
    int userId = 7,
    int? sesiId,
    String cid = '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
    DateTime? disimpan,
    StatusDrafLokal status = StatusDrafLokal.lokal,
    Map<String, dynamic>? isian,
  }) => DrafLokal(
    userId: userId,
    sesiId: sesiId,
    clientRequestId: cid,
    profil: 'ph_meter',
    judul: 'pH Meter Mettler Toledo · B628755900',
    equipmentId: 12,
    pengulangan: 5,
    disimpanPada: disimpan ?? DateTime.utc(2026, 10, 14, 6, 41),
    status: status,
    isian:
        isian ??
        {
          'teks': {'catatan_teknisi': 'buffer 7 lot baru'},
          'titik': {
            '4.0': {
              'kotak': {'sesudah_adjustment|pembacaan|0': '4.01'},
              'standard_id': null,
              'no_probe': '',
            },
          },
        },
  );

  Iterable<File> berkasDi(int userId) {
    final folder = Directory(
      '${akar.path}${Platform.pathSeparator}draf_lokal'
      '${Platform.pathSeparator}$userId',
    );
    if (!folder.existsSync()) return const [];
    return folder.listSync().whereType<File>();
  }

  test('ditulis lalu dibaca balik utuh, termasuk isian bersarang', () async {
    final asli = draf(status: StatusDrafLokal.belumTersinkron).copyWith(
      kiriman: {'status': 'draft', 'equipment_id': 12},
      dicobaKirim: true,
    );

    await simpanan.simpan(asli);
    final dibaca = await simpanan.baca(7, asli.kunci);

    expect(dibaca, isNotNull);
    expect(dibaca!.toJson(), asli.toJson());
    expect(dibaca.kunci, 'baru-0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71');
    expect(await simpanan.daftar(7), hasLength(1));
  });

  test(
    'menimpa salinan yang sudah ada tanpa meninggalkan berkas sementara',
    () async {
      await simpanan.simpan(draf(sesiId: 72));
      await simpanan.simpan(
        draf(
          sesiId: 72,
          isian: {
            'teks': {'catatan_teknisi': 'versi kedua'},
          },
        ),
      );

      final dibaca = await simpanan.baca(7, 'sesi-72');
      expect((dibaca!.isian['teks'] as Map)['catatan_teknisi'], 'versi kedua');

      final nama = berkasDi(7).map((f) => f.uri.pathSegments.last).toList();
      expect(nama, ['sesi-72.json'], reason: 'Berkas .tmp tertinggal: $nama');
    },
  );

  test('salinan lebih dari 14 hari dibuang, yang 13 hari tetap', () async {
    final sekarang = DateTime.utc(2026, 10, 14, 8);

    await simpanan.simpan(
      draf(sesiId: 1, disimpan: sekarang.subtract(const Duration(days: 15))),
    );
    await simpanan.simpan(
      draf(sesiId: 2, disimpan: sekarang.subtract(const Duration(days: 13))),
    );

    await simpanan.buangKedaluwarsa(7, sekarang: sekarang);

    final sisa = await simpanan.daftar(7);
    expect(sisa.map((d) => d.sesiId), [2]);
  });

  test(
    'akun lain masuk: salinan akun sebelumnya dibuang, miliknya tetap',
    () async {
      await simpanan.simpan(draf(userId: 7, sesiId: 1));
      await simpanan.simpan(draf(userId: 9, sesiId: 2));

      await simpanan.buangAkunLain(9);

      expect(await simpanan.daftar(7), isEmpty);
      expect(await simpanan.baca(7, 'sesi-1'), isNull);
      expect((await simpanan.daftar(9)).map((d) => d.sesiId), [2]);
    },
  );

  test(
    'akun lain nggak bisa membaca salinan akun ini lewat kuncinya',
    () async {
      await simpanan.simpan(draf(userId: 7, sesiId: 5));

      expect(await simpanan.baca(9, 'sesi-5'), isNull);
      expect(await simpanan.daftar(9), isEmpty);
    },
  );

  test('berkas rusak dilewat, salinan lain tetap kelihatan', () async {
    await simpanan.simpan(draf(sesiId: 3));
    final rusak = File(
      '${akar.path}${Platform.pathSeparator}draf_lokal'
      '${Platform.pathSeparator}7${Platform.pathSeparator}sesi-4.json',
    );
    await rusak.writeAsString('{"versi_format": 1, "isian": ');

    final daftar = await simpanan.daftar(7);
    expect(daftar.map((d) => d.sesiId), [3]);
  });

  test(
    'kunci yang bukan sesi-<id>/baru-<uuid> ditolak, bukan jadi path',
    () async {
      await simpanan.simpan(draf(cid: '../../keluar'));

      expect(berkasDi(7), isEmpty);
      expect(
        File('${akar.path}${Platform.pathSeparator}keluar.json').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'folder aplikasi nggak tersedia: semua operasi diam, nggak melempar',
    () async {
      final mati = SimpananDrafLokalBerkas(
        () async => throw const FileSystemException('nggak ada folder'),
      );

      await mati.simpan(draf());
      expect(await mati.baca(7, draf().kunci), isNull);
      expect(await mati.daftar(7), isEmpty);
      await mati.hapus(7, draf().kunci);
      await mati.buangKedaluwarsa(7);
      await mati.buangAkunLain(7);
    },
  );

  group('lebih baru dari server', () {
    final server = DateTime.utc(2026, 10, 14, 6, 0);

    test('server belum pernah ada (lembar baru): salinan HP dipakai', () {
      expect(draf().lebihBaruDari(null), isTrue);
    });

    test('server nggak berubah sejak dimuat: salinan HP menang walau jam HP '
        'telat', () {
      // Jam HP telat 5 menit: salinannya "kelihatan" lebih tua dari server.
      final d = draf(
        disimpan: server.subtract(const Duration(minutes: 5)),
      ).copyWith(basisServer: server);

      expect(d.lebihBaruDari(server), isTrue);
    });

    test('server diubah sesudah salinan ditulis (perangkat lain): server '
        'menang', () {
      final d = draf(
        disimpan: server.add(const Duration(minutes: 1)),
      ).copyWith(basisServer: server);

      expect(d.lebihBaruDari(server.add(const Duration(minutes: 30))), isFalse);
    });
  });
}
