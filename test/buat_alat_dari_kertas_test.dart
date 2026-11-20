import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/buat_alat_dari_kertas.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart'
    show seriBisaDipakai;

import 'support/layanan_alat_uji.dart';

/// "Buat dan lanjut": PT lalu alat, IDEMPOTEN. Yang dijaga bukan bentuk
/// panelnya tetapi aturan keras: tidak ada duplikat (seri dicek sebelum
/// membuat, 422 seri kembar dijawab dengan alat yang ada), PT mirip tidak
/// ditembus diam-diam, dan gagal sebagian aman diulang.

EquipmentLookup _a(
  int id,
  String seri, {
  String kategori = 'instrumen-analitik',
  String pt = '',
  String nama = 'pH Meter Lama',
}) => EquipmentLookup(
  id: id,
  namaAlat: nama,
  serialNumber: seri,
  kategori: kategori,
  status: 'aktif',
  pelangganNama: pt,
);

DataAlatBaru _data({
  String seri = 'SN-4471',
  String pemilik = 'PT Tirta Contoh',
  String alamat = 'Jl. Contoh 1',
}) => DataAlatBaru(
  namaAlat: 'pH Meter',
  seri: seri,
  pemilik: pemilik,
  alamat: alamat,
  merk: 'Mettler',
  model: 'Five Easy',
  kategori: 'instrumen-analitik',
  profil: 'ph_meter',
  namaAlatKemampuan: 'pH Meter',
);

PembuatAlatDariKertas _pembuat(
  PtUji pt,
  PencariAlatUji cari,
  LayananAlatUji layanan,
) => PembuatAlatDariKertas(
  pelanggan: pt,
  cariAlat: cari,
  layananAlat: layanan,
  token: () async => 'tok',
);

void main() {
  group('alat BARU dan PT BARU', () {
    test(
      'PT didaftarkan, alat dibuat memakai id PT itu dan jenis dari lembar',
      () async {
        final pt = PtUji();
        final layanan = LayananAlatUji();
        final h = await _pembuat(
          pt,
          PencariAlatUji(),
          layanan,
        ).jalankan(_data());

        expect(h, isA<AlatSiap>());
        final siap = h as AlatSiap;
        expect(siap.alat.serialNumber, 'SN-4471');
        expect(siap.alat.pelangganNama, 'PT Tirta Contoh');
        expect(siap.alat.pelangganAlamat, 'Jl. Contoh 1');
        expect(pt.didaftarkan, 1);
        expect(layanan.dikirim, hasLength(1));
        final kirim = layanan.dikirim.single;
        expect(kirim.pelangganId, 901);
        expect(kirim.kategori, 'instrumen-analitik');
        expect(kirim.namaAlatKemampuan, 'pH Meter');
        expect(kirim.merk, 'Mettler');
        expect(kirim.model, 'Five Easy');
      },
    );

    test(
      'PT yang sama (abaikan tanda baca dan huruf) dipakai, TIDAK didaftarkan',
      () async {
        final pt = PtUji(
          ada: const [CustomerLookup(id: 7, nama: 'PT. Tirta  Contoh')],
        );
        final layanan = LayananAlatUji();
        final h = await _pembuat(
          pt,
          PencariAlatUji(),
          layanan,
        ).jalankan(_data());

        expect(h, isA<AlatSiap>());
        expect(pt.didaftarkan, 0, reason: 'jangan melahirkan PT kembar');
        expect(layanan.dikirim.single.pelangganId, 7);
      },
    );
  });

  group('tidak pernah menduplikasi alat', () {
    test('seri sudah terdaftar (sejenis, PT sama): TIDAK terpasang sendiri, '
        'menunggu ketukan teknisi; tidak ada POST', () async {
      final pt = PtUji();
      final layanan = LayananAlatUji();
      final h = await _pembuat(
        pt,
        PencariAlatUji([_a(12, 'SN-4471', pt: 'PT Tirta Contoh')]),
        layanan,
      ).jalankan(_data(seri: 'sn 4471'));

      expect(h, isA<SeriSudahTerdaftar>());
      expect((h as SeriSudahTerdaftar).alat.id, 12);
      expect(h.pemilikBeda, isFalse);
      expect(layanan.dikirim, isEmpty, reason: 'tidak membuat alat kembar');
      expect(
        pt.didaftarkan,
        0,
        reason: 'tidak ada PT yatim untuk alat yang ada',
      );
    });

    test('seri sama, jenis sama, PT BEDA: kartu dengan penanda pemilik beda, '
        'tidak terpasang', () async {
      final pt = PtUji();
      final layanan = LayananAlatUji();
      final h = await _pembuat(
        pt,
        PencariAlatUji([_a(12, 'SN-4471', pt: 'PT Milik Orang Lain')]),
        layanan,
      ).jalankan(_data());

      expect(h, isNot(isA<AlatSiap>()));
      expect(h, isA<SeriSudahTerdaftar>());
      expect((h as SeriSudahTerdaftar).pemilikBeda, isTrue);
      expect(h.alat.pelangganNama, 'PT Milik Orang Lain');
      expect(layanan.dikirim, isEmpty);
      expect(pt.didaftarkan, 0);
    });

    test('seri sama, KATEGORI sama tetapi JENIS beda (kategori terlalu kasar): '
        'seri milik alat lain, tidak dipasang, tidak dibuat', () async {
      final pt = PtUji();
      final layanan = LayananAlatUji();
      // Satu kategori memuat banyak jenis: alat ini tidak ikut pencarian per
      // profil lembar, tetapi ada di lab dengan kategori yang SAMA.
      final cari = PencariAlatUji([
        _a(12, 'SN-4471', nama: 'Turbidimeter Hach', pt: 'PT Milik Orang Lain'),
      ])..sembunyikanDariProfil = {12};
      final h = await _pembuat(pt, cari, layanan).jalankan(_data());

      expect(h, isNot(isA<AlatSiap>()));
      expect(h, isA<SeriMilikAlatLain>());
      expect((h as SeriMilikAlatLain).alat.namaAlat, 'Turbidimeter Hach');
      expect(layanan.dikirim, isEmpty);
      expect(pt.didaftarkan, 0);
    });

    test(
      'seri milik alat KATEGORI lain: tetap ditolak dengan alasan, tidak dibuat',
      () async {
        final pt = PtUji();
        final layanan = LayananAlatUji();
        final cari = PencariAlatUji([_a(12, 'SN-4471', kategori: 'suhu')])
          ..sembunyikanDariProfil = {12};
        final h = await _pembuat(pt, cari, layanan).jalankan(_data());

        expect(h, isA<SeriMilikAlatLain>());
        expect((h as SeriMilikAlatLain).alat.id, 12);
        expect(layanan.dikirim, isEmpty);
        expect(pt.didaftarkan, 0);
      },
    );

    test(
      'server menolak seri kembar (422, balapan): juga TIDAK terpasang sendiri',
      () async {
        final cari = PencariAlatUji();
        final layanan = LayananAlatUji(
          sebelumSimpan: (_) async {
            // Di antara pengecekan dan POST, perangkat lain mendaftarkannya.
            cari.alat.add(_a(33, 'SN-4471', pt: 'PT Tirta Contoh'));
            throw const ApiException(
              'Nomor seri sudah dipakai.',
              status: 422,
              body: {
                'errors': {
                  'serial_number': ['sudah dipakai'],
                },
              },
            );
          },
        );

        final h = await _pembuat(PtUji(), cari, layanan).jalankan(_data());

        expect(h, isNot(isA<AlatSiap>()));
        expect(h, isA<SeriSudahTerdaftar>());
        expect((h as SeriSudahTerdaftar).alat.id, 33);
      },
    );

    for (final placeholder in [
      '-',
      '--',
      '...',
      '?',
      'N/A',
      'n/a',
      'NA',
      'NIL',
      'Tidak ada',
      'TANPA SERI',
      '   ',
      '000',
    ]) {
      test(
        'seri placeholder "$placeholder" ditolak: tanpa pencarian, tanpa PT, '
        'tanpa alat (alat kedua tidak menempel diam-diam ke alat pertama)',
        () async {
          final pt = PtUji();
          final layanan = LayananAlatUji();
          final cari = PencariAlatUji([_a(12, 'NA', pt: 'PT Tirta Contoh')]);
          final h = await _pembuat(
            pt,
            cari,
            layanan,
          ).jalankan(_data(seri: placeholder));

          expect(h, isA<SeriTidakValid>());
          expect(cari.dipanggil, 0);
          expect(layanan.dikirim, isEmpty);
          expect(pt.didaftarkan, 0);
        },
      );
    }

    test('seri bernomor biasa tetap lolos (bukan placeholder)', () async {
      for (final seri in ['SN-4471', 'B628755900', 'NA-1234', 'A1']) {
        expect(seriBisaDipakai(seri), isTrue, reason: seri);
      }
    });

    test(
      '422 yang BUKAN soal seri tidak disamarkan: gagal dengan pesannya',
      () async {
        final layanan = LayananAlatUji(
          sebelumSimpan: (_) async => throw const ApiException(
            'Kategori tidak aktif.',
            status: 422,
            body: {
              'errors': {
                'kategori': ['tidak aktif'],
              },
            },
          ),
        );

        final h = await _pembuat(
          PtUji(),
          PencariAlatUji(),
          layanan,
        ).jalankan(_data());

        expect(h, isA<GagalBuatAlat>());
        expect(
          ((h as GagalBuatAlat).galat as ApiException).message,
          'Kategori tidak aktif.',
        );
      },
    );
  });

  group('PT mirip: teknisi yang memutuskan', () {
    const mirip = [
      CustomerLookup(id: 3, nama: 'PT Tirta Contoh Mandiri'),
      CustomerLookup(id: 4, nama: 'PT Tirta Contoh Abadi'),
    ];

    test(
      '409 mirip: berhenti dengan kandidat, belum ada alat dan PT dibuat',
      () async {
        final pt = PtUji(mirip: mirip);
        final layanan = LayananAlatUji();
        final h = await _pembuat(
          pt,
          PencariAlatUji(),
          layanan,
        ).jalankan(_data());

        expect(h, isA<PtPerluDipilih>());
        expect((h as PtPerluDipilih).kandidat.map((c) => c.id), [3, 4]);
        expect(layanan.dikirim, isEmpty);
        expect(pt.didaftarkan, 0);
      },
    );

    test(
      'teknisi memilih kandidat: alat dibuat untuk PT itu, PT tidak baru',
      () async {
        final pt = PtUji(mirip: mirip);
        final layanan = LayananAlatUji();
        final p = _pembuat(pt, PencariAlatUji(), layanan);

        await p.jalankan(_data());
        final h = await p.jalankan(_data(), ptDipilih: mirip.last);

        expect(h, isA<AlatSiap>());
        expect(layanan.dikirim.single.pelangganId, 4);
        expect(pt.didaftarkan, 0);
      },
    );

    test(
      'teknisi menegaskan PT lain: tetap_buat dikirim, baru lalu dibuat',
      () async {
        final pt = PtUji(mirip: mirip);
        final layanan = LayananAlatUji();
        final p = _pembuat(pt, PencariAlatUji(), layanan);

        await p.jalankan(_data());
        final h = await p.jalankan(_data(), tetapBuatPt: true);

        expect(h, isA<AlatSiap>());
        expect(pt.terakhirTetapBuat, isTrue);
        expect(pt.didaftarkan, 1);
        expect(layanan.dikirim.single.pelangganId, 901);
      },
    );
  });

  group('PT yang namanya hampir sama (Tbk, Indonesia, PT/CV) ditanyakan', () {
    test(
      'inti nama: awalan PT/CV/UD dan akhiran Tbk/Persero/Indonesia dibuang',
      () {
        expect(intiNamaPt('PT. Maju Jaya Tbk'), 'maju jaya');
        expect(intiNamaPt('CV Maju Jaya'), 'maju jaya');
        expect(intiNamaPt('UD  maju  jaya (Persero)'), 'maju jaya');
        expect(intiNamaPt('PT Maju Jaya Indonesia Tbk'), 'maju jaya');
        expect(intiNamaPt('PT Tirta Contoh Mandiri'), 'tirta contoh mandiri');
        // Nama yang hanya terdiri dari kata badan tidak dikosongkan.
        expect(intiNamaPt('PT Indonesia'), 'indonesia');
      },
    );

    test(
      'ptMirip: saling mengandung (kata utuh), bukan persis, inti >= 4 huruf',
      () {
        expect(ptMirip('PT Maju Jaya', 'PT Maju Jaya Tbk'), isTrue);
        expect(ptMirip('PT Maju Jaya Indonesia', 'PT Maju Jaya'), isTrue);
        expect(ptMirip('PT Maju Jaya', 'CV Maju Jaya'), isTrue);
        expect(ptMirip('PT Tirta Contoh', 'PT Tirta Contoh Mandiri'), isTrue);
        // Persis (huruf besar dan tanda baca diabaikan): bukan "mirip", itu sama.
        expect(ptMirip('PT. Maju  Jaya', 'pt maju jaya'), isFalse);
        // Berbeda.
        expect(ptMirip('PT Maju Jaya', 'PT Maju Mundur'), isFalse);
        // Potongan kata bukan kata utuh.
        expect(ptMirip('PT Maju', 'PT Majulah Jaya'), isFalse);
        // Terlalu pendek untuk dibandingkan.
        expect(ptMirip('PT A', 'PT A Jaya'), isFalse);
        expect(ptMirip('PT AB', 'PT ABC'), isFalse);
      },
    );

    test(
      'PT terdaftar "X Tbk", kertas "X": berhenti dengan kandidat, tidak ada '
      'PT baru dan tidak ada alat',
      () async {
        final pt = PtUji(
          ada: const [CustomerLookup(id: 7, nama: 'PT Tirta Contoh Tbk')],
        );
        final layanan = LayananAlatUji();
        final h = await _pembuat(
          pt,
          PencariAlatUji(),
          layanan,
        ).jalankan(_data());

        expect(h, isA<PtPerluDipilih>());
        expect((h as PtPerluDipilih).kandidat.map((c) => c.id), [7]);
        expect(pt.didaftarkan, 0);
        expect(layanan.dikirim, isEmpty);
      },
    );

    test('PT terdaftar "X", kertas "X Indonesia" (kertas LEBIH PANJANG): tetap '
        'ditanyakan, lewat pencarian inti nama', () async {
      final pt = PtUji(
        ada: const [CustomerLookup(id: 7, nama: 'PT Tirta Contoh')],
      );
      final h = await _pembuat(
        pt,
        PencariAlatUji(),
        LayananAlatUji(),
      ).jalankan(_data(pemilik: 'PT Tirta Contoh Indonesia'));

      expect(h, isA<PtPerluDipilih>());
      expect((h as PtPerluDipilih).kandidat.map((c) => c.id), [7]);
      expect(pt.didaftarkan, 0);
    });

    test('PT terdaftar "CV X", kertas "PT X": ditanyakan (badan usaha beda, '
        'nama sama)', () async {
      final pt = PtUji(
        ada: const [CustomerLookup(id: 7, nama: 'CV Tirta Contoh')],
      );
      final h = await _pembuat(
        pt,
        PencariAlatUji(),
        LayananAlatUji(),
      ).jalankan(_data());

      expect(h, isA<PtPerluDipilih>());
    });

    test(
      'PT yang BERBEDA (bukan saling mengandung): PT baru, tidak ditanya',
      () async {
        final pt = PtUji(
          ada: const [CustomerLookup(id: 7, nama: 'PT Tirta Mundur')],
        );
        final h = await _pembuat(
          pt,
          PencariAlatUji(),
          LayananAlatUji(),
        ).jalankan(_data());

        expect(h, isA<AlatSiap>());
        expect(pt.didaftarkan, 1);
      },
    );

    test(
      'teknisi memilih kandidat lokal: alat untuk PT itu, tanpa PT baru',
      () async {
        const ada = CustomerLookup(id: 7, nama: 'PT Tirta Contoh Tbk');
        final pt = PtUji(ada: const [ada]);
        final layanan = LayananAlatUji();
        final p = _pembuat(pt, PencariAlatUji(), layanan);

        await p.jalankan(_data());
        final h = await p.jalankan(_data(), ptDipilih: ada);

        expect(h, isA<AlatSiap>());
        expect(layanan.dikirim.single.pelangganId, 7);
        expect(pt.didaftarkan, 0);
      },
    );

    test('"Tetap buat PT baru" menembus kandidat lokal', () async {
      final pt = PtUji(
        ada: const [CustomerLookup(id: 7, nama: 'PT Tirta Contoh Tbk')],
      );
      final layanan = LayananAlatUji();
      final p = _pembuat(pt, PencariAlatUji(), layanan);

      await p.jalankan(_data());
      final h = await p.jalankan(_data(), tetapBuatPt: true);

      expect(h, isA<AlatSiap>());
      expect(pt.didaftarkan, 1);
      expect(layanan.dikirim.single.pelangganId, isNot(7));
    });

    test('periksaPt: terdaftar persis, mirip, atau akan didaftarkan', () async {
      final pt = PtUji(
        ada: const [
          CustomerLookup(id: 5, nama: 'PT. Tirta  Contoh'),
          CustomerLookup(id: 8, nama: 'PT Maju Jaya Tbk'),
        ],
      );
      final p = _pembuat(pt, PencariAlatUji(), LayananAlatUji());

      final ada = await p.periksaPt('PT Tirta Contoh');
      expect(ada, isA<PtTerdaftar>());
      expect((ada as PtTerdaftar).pt.id, 5);

      final mirip = await p.periksaPt('PT Maju Jaya');
      expect(mirip, isA<PtMiripAda>());
      expect((mirip as PtMiripAda).kandidat.map((c) => c.id), [8]);

      final baru = await p.periksaPt('PT Sumber Baru Sejahtera');
      expect(baru, isA<PtAkanDidaftarkan>());
      expect((baru as PtAkanDidaftarkan).nama, 'PT Sumber Baru Sejahtera');
      expect(pt.didaftarkan, 0, reason: 'memeriksa tidak membuat apa pun');
    });
  });

  group('gagal sebagian aman diulang', () {
    test(
      'PT berhasil, alat gagal (sinyal): ulang tidak mendaftarkan PT lagi',
      () async {
        final pt = PtUji();
        var gagalSekali = true;
        final layanan = LayananAlatUji(
          sebelumSimpan: (_) async {
            if (gagalSekali) {
              gagalSekali = false;
              throw const KoneksiException('putus');
            }
          },
        );
        final p = _pembuat(pt, PencariAlatUji(), layanan);

        final pertama = await p.jalankan(_data());
        expect(pertama, isA<GagalBuatAlat>());
        expect(pt.didaftarkan, 1);
        final pencarianSesudahPertama = pt.jumlahCari;

        final kedua = await p.jalankan(_data());
        expect(kedua, isA<AlatSiap>());
        expect(pt.didaftarkan, 1, reason: 'PT tidak kembar');
        expect(
          pt.jumlahCari,
          pencarianSesudahPertama,
          reason: 'PT yang sudah beres dipakai ulang tanpa mencari lagi',
        );
        expect(layanan.dikirim, hasLength(1));
      },
    );

    test(
      'nama PT diubah teknisi sesudah gagal: PT baru dicari, bukan memo lama',
      () async {
        final pt = PtUji();
        var gagalSekali = true;
        final layanan = LayananAlatUji(
          sebelumSimpan: (_) async {
            if (gagalSekali) {
              gagalSekali = false;
              throw const KoneksiException('putus');
            }
          },
        );
        final p = _pembuat(pt, PencariAlatUji(), layanan);

        await p.jalankan(_data(pemilik: 'PT Salah Baca'));
        final h = await p.jalankan(_data(pemilik: 'PT Tirta Contoh'));

        expect(h, isA<AlatSiap>());
        expect((h as AlatSiap).alat.pelangganNama, 'PT Tirta Contoh');
      },
    );

    test(
      'sesudah berhasil, panggilan ulang dengan seri sama tidak membuat lagi',
      () async {
        final layanan = LayananAlatUji();
        final p = _pembuat(PtUji(), PencariAlatUji(), layanan);

        final a = await p.jalankan(_data()) as AlatSiap;
        final b = await p.jalankan(_data()) as AlatSiap;

        expect(b.alat.id, a.alat.id);
        expect(layanan.dikirim, hasLength(1));
      },
    );

    test('dua ketukan bersamaan: SATU kerja, SATU alat', () async {
      final layanan = LayananAlatUji();
      final p = _pembuat(PtUji(), PencariAlatUji(), layanan);

      final hasil = await Future.wait([
        p.jalankan(_data()),
        p.jalankan(_data()),
      ]);

      expect(layanan.dikirim, hasLength(1));
      expect((hasil[0] as AlatSiap).alat.id, (hasil[1] as AlatSiap).alat.id);
    });

    test('galat tak terduga dibungkus GagalBuatAlat, tidak melempar', () async {
      final layanan = LayananAlatUji(
        sebelumSimpan: (_) async => throw StateError('aneh'),
      );
      final h = await _pembuat(
        PtUji(),
        PencariAlatUji(),
        layanan,
      ).jalankan(_data());

      expect(h, isA<GagalBuatAlat>());
    });
  });
}
