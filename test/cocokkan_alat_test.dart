import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/services/cocokkan_alat.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';

/// Mencocokkan identitas kertas ke alat terdaftar. Data alat KARANGAN
/// (seri dan PT sintetis); yang dijaga: seri persis = cocok, mirip = pilihan
/// (maks 3), selain itu = alat baru, seri kosong = wajib diketik, dan galat
/// server = jujur (bukan "alat baru").

/// Layanan pencari yang meniru `GET /equipments?search=`: LIKE pada seri yang
/// dinormalkan server (huruf besar, tanpa tanda baca; `SubkueriCocok`) atau
/// nama, mengabaikan `profil` (penyaring sisi server) tetapi MENCATATNYA.
class _Pencari implements EquipmentLookupService {
  _Pencari(this.alat, {this.gagal = false});

  final List<EquipmentLookup> alat;
  final bool gagal;
  final kueri = <String?>[];
  final profilDiminta = <String?>[];

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async {
    kueri.add(search);
    profilDiminta.add(profil);
    if (gagal) throw Exception('server nggak nyaut');

    final q = (search ?? '').toLowerCase();
    final qSeri = kunciSeri(q);

    return [
      for (final a in alat)
        if (q.isEmpty ||
            (qSeri.isNotEmpty && kunciSeri(a.serialNumber).contains(qSeri)) ||
            a.namaAlat.toLowerCase().contains(q))
          a,
    ];
  }
}

EquipmentLookup _a(
  int id,
  String seri, {
  String nama = 'pH Meter Contoh',
  String merk = '',
  String model = '',
  String pt = '',
}) => EquipmentLookup(
  id: id,
  namaAlat: nama,
  serialNumber: seri,
  kategori: 'instrumen-analitik',
  status: 'aktif',
  merk: merk,
  model: model,
  pelangganNama: pt,
);

void main() {
  const profil = 'ph_meter';

  group('cocok PERSIS lewat nomor seri', () {
    test('seri sama persis: satu alat, tanpa menunggu kueri lain', () async {
      final p = _Pencari([_a(1, 'B628755900'), _a(2, 'ZZ-100200')]);

      final h = await cocokkanAlat(
        layanan: p,
        token: 't',
        kertas: const IdentitasKertas(seri: 'B628755900'),
        profil: profil,
      );

      expect(h, isA<CocokPersis>());
      expect((h as CocokPersis).alat.id, 1);
      expect(p.kueri, ['B628755900'], reason: 'berhenti begitu persis ketemu');
      expect(p.profilDiminta, [profil], reason: 'disaring ke jenis lembar');
    });

    test('huruf kecil, spasi, dan tanda baca tidak membedakan', () async {
      final p = _Pencari([_a(7, 'MT-500-196-30')]);

      final h = await cocokkanAlat(
        layanan: p,
        token: 't',
        kertas: const IdentitasKertas(seri: 'mt 500 196 30'),
        profil: profil,
      );

      expect(h, isA<CocokPersis>());
      expect((h as CocokPersis).alat.id, 7);
      // Server menormalkan seri di sisinya, jadi kueri pertama (apa adanya)
      // sudah menjaringnya; tidak perlu kueri lain.
      expect(p.kueri, ['mt 500 196 30']);
    });

    test(
      'seri kertas O dan seri terdaftar 0 BUKAN persis (itu "mirip")',
      () async {
        final p = _Pencari([_a(3, 'B628755900')]);

        final h = await cocokkanAlat(
          layanan: p,
          token: 't',
          kertas: const IdentitasKertas(seri: 'B6287559O0'),
          profil: profil,
        );

        expect(h, isA<CocokMirip>());
        expect((h as CocokMirip).kandidat.single.id, 3);
      },
    );
  });

  group('MIRIP: salah baca satu dua karakter', () {
    test('maksimal tiga kandidat, yang terdekat dulu', () async {
      final p = _Pencari([
        _a(1, 'B628755901'),
        _a(2, 'B628755800'),
        _a(3, 'B628755900X'),
        _a(4, 'B628755910'),
        _a(5, 'ZZ99999999'),
      ]);

      final h = await cocokkanAlat(
        layanan: p,
        token: 't',
        kertas: const IdentitasKertas(seri: 'B628755900'),
        profil: profil,
      );

      expect(h, isA<CocokMirip>());
      final k = (h as CocokMirip).kandidat;
      expect(k.length, maksKandidatMirip);
      expect(k.map((a) => a.id), isNot(contains(5)));
      expect(k.first.id, anyOf(1, 2, 4, 3), reason: 'yang jarak edit-nya 1');
    });

    test('seri jauh berbeda = alat baru (bukan mirip)', () async {
      final p = _Pencari([_a(1, 'XX-777-888'), _a(2, 'QQ-1234')]);

      final h = await cocokkanAlat(
        layanan: p,
        token: 't',
        kertas: const IdentitasKertas(seri: 'B628755900'),
        profil: profil,
      );

      expect(h, isA<AlatBaru>());
      expect((h as AlatBaru).seriKosong, isFalse);
    });
  });

  group('alat BARU dan seri kosong', () {
    test('tidak ada alat sama sekali: alat baru, seri ada', () async {
      final h = await cocokkanAlat(
        layanan: _Pencari(const []),
        token: 't',
        kertas: const IdentitasKertas(seri: 'SN-4471'),
        profil: profil,
      );

      expect(h, isA<AlatBaru>());
      expect((h as AlatBaru).seriKosong, isFalse);
    });

    test(
      'seri placeholder ("-", "N/A", "Tidak ada"): seri kosong, TANPA kueri '
      'server (alat kedua tidak boleh menempel ke alat berseri "NA")',
      () async {
        for (final placeholder in ['-', '...', 'N/A', 'NA', 'Tidak ada']) {
          final p = _Pencari([_a(1, 'NA')]);

          final h = await cocokkanAlat(
            layanan: p,
            token: 't',
            kertas: IdentitasKertas(namaAlat: 'pH Meter', seri: placeholder),
            profil: profil,
          );

          expect(h, isA<AlatBaru>(), reason: placeholder);
          expect((h as AlatBaru).seriKosong, isTrue, reason: placeholder);
          expect(p.kueri, isEmpty, reason: placeholder);
        }
      },
    );

    test(
      'seri tak terbaca: alat baru dengan seri kosong, TANPA kueri server',
      () async {
        final p = _Pencari([_a(1, 'B628755900')]);

        final h = await cocokkanAlat(
          layanan: p,
          token: 't',
          kertas: const IdentitasKertas(namaAlat: 'pH Meter', merk: 'Mettler'),
          profil: profil,
        );

        expect(h, isA<AlatBaru>());
        expect((h as AlatBaru).seriKosong, isTrue);
        expect(
          p.kueri,
          isEmpty,
          reason: 'tanpa seri tidak ada kunci untuk dicari',
        );
      },
    );

    test(
      'seri "-" atau titik-titik (tanpa huruf/angka) = seri kosong',
      () async {
        final h = await cocokkanAlat(
          layanan: _Pencari(const []),
          token: 't',
          kertas: const IdentitasKertas(seri: '- . -'),
          profil: profil,
        );

        expect((h as AlatBaru).seriKosong, isTrue);
      },
    );
  });

  group('galat server: jujur, bukan "alat baru"', () {
    test('server tidak terjangkau = CocokGagal', () async {
      final h = await cocokkanAlat(
        layanan: _Pencari(const [], gagal: true),
        token: 't',
        kertas: const IdentitasKertas(seri: 'SN-4471'),
        profil: profil,
      );

      expect(h, isA<CocokGagal>());
    });
  });

  group('selisih kertas lawan data terdaftar', () {
    final alat = _a(
      1,
      'B628755900',
      merk: 'Mettler Toledo',
      model: 'Five Easy',
      pt: 'PT Tirta Contoh Mandiri',
    );

    test(
      'bidang yang sama (abaikan besar-kecil, tanda baca) bukan selisih',
      () {
        final s = selisihIdentitas(
          const IdentitasKertas(
            merk: 'METTLER  toledo',
            model: 'five-easy',
            pemilik: 'PT. Tirta Contoh Mandiri',
          ),
          alat,
        );

        expect(s, isEmpty);
      },
    );

    test('bidang yang beda dilaporkan dengan kedua nilainya', () {
      final s = selisihIdentitas(
        const IdentitasKertas(
          merk: 'Hanna',
          model: 'Five Easy',
          pemilik: 'CV Lain',
        ),
        alat,
      );

      expect(s, const [
        SelisihIdentitas(
          kode: 'alat_merk',
          kertas: 'Hanna',
          terdaftar: 'Mettler Toledo',
        ),
        SelisihIdentitas(
          kode: 'pemilik_nama',
          kertas: 'CV Lain',
          terdaftar: 'PT Tirta Contoh Mandiri',
        ),
      ]);
    });

    test(
      'kosong di salah satu sisi bukan selisih (tidak ada yang dibantah)',
      () {
        expect(selisihIdentitas(IdentitasKertas.kosong, alat), isEmpty);
        expect(
          selisihIdentitas(
            const IdentitasKertas(merk: 'Hanna'),
            _a(2, 'X1234'),
          ),
          isEmpty,
        );
      },
    );
  });
}
