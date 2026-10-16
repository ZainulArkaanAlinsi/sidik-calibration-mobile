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

  test('akun lain masuk: simpanan otomatis akun sebelumnya dibuang, miliknya '
      'tetap', () async {
    await simpanan.simpan(draf(userId: 7, sesiId: 1));
    await simpanan.simpan(draf(userId: 9, sesiId: 2));

    await simpanan.buangAkunLain(9, sekarang: DateTime.utc(2026, 10, 14, 8));

    expect(await simpanan.daftar(7), isEmpty);
    expect(await simpanan.baca(7, 'sesi-1'), isNull);
    expect((await simpanan.daftar(9)).map((d) => d.sesiId), [2]);
    expect(
      Directory(
        '${akar.path}${Platform.pathSeparator}draf_lokal'
        '${Platform.pathSeparator}7',
      ).existsSync(),
      isFalse,
      reason: 'Folder kosong akun lain tertinggal.',
    );
  });

  // Keputusan review 14 Okt 2026: draf yang SUDAH antre / ditolak server itu
  // data lapangan yang belum sampai server — nggak boleh hilang gara-gara
  // tablet dipakai akun lain. Tetap disimpan buat pemiliknya, nggak kelihatan
  // akun lain, dan tetap kedaluwarsa sesudah 14 hari.
  test(
    'akun lain masuk: draf antre & yang ditolak milik akun sebelumnya TETAP, '
    'tapi nggak kelihatan akun baru',
    () async {
      final sekarang = DateTime.utc(2026, 10, 14, 8);
      await simpanan.simpan(
        draf(userId: 7, sesiId: 1, status: StatusDrafLokal.belumTersinkron),
      );
      await simpanan.simpan(
        draf(userId: 7, sesiId: 2, status: StatusDrafLokal.perluDiperbaiki),
      );
      await simpanan.simpan(draf(userId: 7, sesiId: 3));
      await simpanan.simpan(
        draf(
          userId: 7,
          sesiId: 4,
          status: StatusDrafLokal.belumTersinkron,
          disimpan: sekarang.subtract(const Duration(days: 15)),
        ),
      );

      await simpanan.buangAkunLain(9, sekarang: sekarang);

      expect(await simpanan.daftar(9), isEmpty);
      expect(await simpanan.baca(9, 'sesi-1'), isNull);
      expect(
        (await simpanan.daftar(7)).map((d) => d.sesiId).toSet(),
        {1, 2},
        reason: 'Yang antre/ditolak harus tetap; otomatis & >14 hari dibuang.',
      );
    },
  );

  test('simpanan memori mengikuti aturan yang sama', () async {
    final memori = SimpananDrafLokalMemori();
    await memori.simpan(
      draf(userId: 7, sesiId: 1, status: StatusDrafLokal.belumTersinkron),
    );
    await memori.simpan(draf(userId: 7, sesiId: 3));

    await memori.buangAkunLain(9, sekarang: DateTime.utc(2026, 10, 14, 8));

    expect((await memori.daftar(7)).map((d) => d.sesiId), [1]);
  });

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
      expect(
        await mati.gantiJikaSama(7, draf().kunci, draf().disimpanPada),
        isFalse,
      );
      await mati.buangKedaluwarsa(7);
      await mati.buangAkunLain(7);
    },
  );

  // Saran A review draf-offline ronde 2 (15 Okt 2026): periksa-dan-tulis
  // pengirim antrean satu operasi, berurutan dengan simpan otomatis layar.
  group('ganti bersyarat (gantiJikaSama)', () {
    final awal = DateTime.utc(2026, 10, 14, 6, 41);
    final sesudah = DateTime.utc(2026, 10, 14, 6, 42);

    test('salinan yang masih sama dibuang', () async {
      await simpanan.simpan(draf(sesiId: 72, disimpan: awal));

      expect(await simpanan.gantiJikaSama(7, 'sesi-72', awal), isTrue);
      expect(await simpanan.baca(7, 'sesi-72'), isNull);
      expect(berkasDi(7), isEmpty);
    });

    test('simpan yang dipanggil lebih dulu mendarat dulu: salinan barunya '
        'nggak ikut dibuang', () async {
      await simpanan.simpan(draf(sesiId: 72, disimpan: awal));

      // Dua-duanya dipanggil tanpa ditunggu, persis seperti layar & pengirim
      // antrean yang jalan bersamaan.
      final tulis = simpanan.simpan(
        draf(
          sesiId: 72,
          disimpan: sesudah,
          isian: {
            'teks': {'catatan_teknisi': 'ketikan terakhir'},
          },
        ),
      );
      final ganti = simpanan.gantiJikaSama(7, 'sesi-72', awal);
      await tulis;

      expect(await ganti, isFalse);
      final sisa = await simpanan.baca(7, 'sesi-72');
      expect(
        (sisa!.isian['teks'] as Map)['catatan_teknisi'],
        'ketikan terakhir',
      );
    });

    test(
      'simpan yang dipanggil sesudahnya mendarat di atas hasilnya',
      () async {
        await simpanan.simpan(draf(sesiId: 72, disimpan: awal));

        final ganti = simpanan.gantiJikaSama(7, 'sesi-72', awal);
        final tulis = simpanan.simpan(draf(sesiId: 72, disimpan: sesudah));
        await tulis;

        expect(await ganti, isTrue);
        expect((await simpanan.baca(7, 'sesi-72'))!.disimpanPada, sesudah);
      },
    );

    test('pindah kunci: pengganti ditulis, kunci lama dibuang', () async {
      final asli = draf(
        disimpan: awal,
        status: StatusDrafLokal.belumTersinkron,
      );
      await simpanan.simpan(asli);

      final pindah = await simpanan.gantiJikaSama(
        7,
        asli.kunci,
        awal,
        pengganti: asli.copyWith(sesiId: 501),
      );

      expect(pindah, isTrue);
      final nama = berkasDi(7).map((f) => f.uri.pathSegments.last).toList();
      expect(nama, ['sesi-501.json']);
      expect(
        (await simpanan.baca(7, 'sesi-501'))!.status,
        StatusDrafLokal.belumTersinkron,
      );
    });

    test('pengganti milik akun lain ditolak, salinan asli utuh', () async {
      final asli = draf(sesiId: 72, disimpan: awal);
      await simpanan.simpan(asli);

      final hasil = await simpanan.gantiJikaSama(
        7,
        'sesi-72',
        awal,
        pengganti: draf(userId: 9, sesiId: 72, disimpan: awal),
      );

      expect(hasil, isFalse);
      expect(await simpanan.baca(7, 'sesi-72'), isNotNull);
      expect(berkasDi(9), isEmpty);
    });

    test('simpanan memori mengikuti aturan yang sama', () async {
      final memori = SimpananDrafLokalMemori();
      await memori.simpan(draf(sesiId: 72, disimpan: sesudah));

      expect(await memori.gantiJikaSama(7, 'sesi-72', awal), isFalse);
      expect(await memori.baca(7, 'sesi-72'), isNotNull);
      expect(await memori.gantiJikaSama(7, 'sesi-72', sesudah), isTrue);
      expect(await memori.baca(7, 'sesi-72'), isNull);
    });
  });

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
