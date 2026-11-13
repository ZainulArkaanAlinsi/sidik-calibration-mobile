import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/garis_waktu_arsip.dart';
import 'package:sidik_calibration/models/pencarian_arsip.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/arsip_cari_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/arsip_cari_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Keadaan saringan, jalur garis waktu, dan pemuatan halaman demi halaman.
///
/// Yang dijaga: saringan yang SAMA tidak menembak server lagi, 1 huruf tidak
/// pernah jadi pencarian, halaman berikutnya menempel (tanpa ganda) dan
/// berhenti di `last_page`, jawaban lama dari saringan yang sudah berganti
/// dibuang, dan ganti akun membuang saringan serta mengambil ulang datanya
/// (skill `sidik-fe-scope-akun`: yang dihitung adalah PANGGILAN service-nya,
/// bukan cuma isinya).

const _akunA = User(
  id: 1,
  nama: 'Budi Santoso',
  email: 'admin@pt-sidik.com',
  employeeId: 'SDK-0001',
  role: UserRole.admin,
  status: UserStatus.aktif,
  organizationId: 1,
);

const _akunB = User(
  id: 2,
  nama: 'Andi Pratama',
  email: 'teknisi@pt-sidik.com',
  employeeId: 'SDK-0002',
  role: UserRole.teknisi,
  status: UserStatus.aktif,
  organizationId: 2,
);

class _AuthUji extends AuthController {
  _AuthUji(this._awal);

  final User? _awal;

  @override
  Future<User?> build() async => _awal;

  void ganti(User? akun) => state = AsyncData(akun);
}

CalibrationHistoryItem _sesi(int id, {String alat = 'Jangka Sorong'}) =>
    CalibrationHistoryItem(
      id: id,
      namaAlat: alat,
      namaTeknisi: 'Dr. Arch Schaefer',
      status: CalibrationStatus.disetujui,
    );

HalamanRiwayat _halamanRiwayat(
  List<int> ids, {
  int halaman = 1,
  int terakhir = 1,
  int? total,
  String alat = 'Jangka Sorong',
}) => HalamanRiwayat(
  baris: [for (final id in ids) _sesi(id, alat: alat)],
  halaman: halaman,
  halamanTerakhir: terakhir,
  total: total ?? ids.length,
);

ItemGarisWaktu _dokumen(int id) => ItemGarisWaktu(
  id: id,
  nomor: 'CAL/2026/11/$id',
  status: 'terbit',
  tanggal: DateTime(2026, 11, 12),
);

HalamanGarisWaktu _halamanGaris(
  TingkatGarisWaktu tingkat, {
  List<KelompokGarisWaktu> kelompok = const [],
  List<int> dokumen = const [],
  int halaman = 1,
  int terakhir = 1,
}) => HalamanGarisWaktu(
  tingkat: tingkat,
  totalDokumen: 5,
  kelompok: kelompok,
  item: [for (final id in dokumen) _dokumen(id)],
  halaman: halaman,
  halamanTerakhir: terakhir,
);

KelompokGarisWaktu _kelompok(String kunci, Map<String, Object> telusuri) =>
    KelompokGarisWaktu(
      kunci: kunci,
      label: 'label $kunci',
      jumlah: 1,
      telusuri: PosisiGarisWaktu.dariTelusuri(telusuri),
    );

class _ServiceUji implements ArsipCariService {
  final riwayat = <({FilterArsip filter, int halaman})>[];
  final garis = <({PosisiGarisWaktu posisi, int? pelangganId, int halaman})>[];

  Future<HalamanRiwayat> Function(FilterArsip filter, int halaman) onRiwayat =
      (filter, halaman) async => _halamanRiwayat([1]);

  Future<HalamanGarisWaktu> Function(
    PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman,
  )
  onGaris = (posisi, pelangganId, halaman) async =>
      _halamanGaris(posisi.tingkat);

  @override
  Future<HalamanRiwayat> cariRiwayat(
    String token, {
    required FilterArsip filter,
    int halaman = 1,
  }) {
    riwayat.add((filter: filter, halaman: halaman));
    return onRiwayat(filter, halaman);
  }

  @override
  Future<HalamanGarisWaktu> garisWaktu(
    String token, {
    required PosisiGarisWaktu posisi,
    int? pelangganId,
    int halaman = 1,
  }) {
    garis.add((posisi: posisi, pelangganId: pelangganId, halaman: halaman));
    return onGaris(posisi, pelangganId, halaman);
  }
}

Future<({ProviderContainer wadah, _AuthUji Function() auth})> _siapkan(
  _ServiceUji service,
) async {
  final auth = _AuthUji(_akunA);
  final wadah = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('token')),
      authProvider.overrideWith(() => auth),
      arsipCariServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(wadah.dispose);
  // Auth selesai dimuat DULU: kalau tidak, penyelesaiannya (id akun null → 1)
  // dibaca sebagai pergantian akun dan memicu pengambilan kedua.
  _tahan(wadah, authProvider);
  await wadah.read(authProvider.future);
  return (wadah: wadah, auth: () => auth);
}

/// Provider auto-dispose: tanpa pendengar, ia dibuang di sela `await`.
void _tahan(ProviderContainer wadah, ProviderListenable<Object?> provider) {
  final langganan = wadah.listen(provider, (_, _) {});
  addTearDown(langganan.close);
}

void main() {
  group('FilterArsip', () {
    test('kata: hanya spasi ujung dipotong, minimal 2 karakter dikirim', () {
      expect(FilterArsip.kosong.denganKata('  CAL/2026  ').kata, 'CAL/2026');
      expect(FilterArsip.kosong.denganKata('').kataKirim, isNull);
      expect(FilterArsip.kosong.denganKata(' a ').kataKirim, isNull);
      expect(FilterArsip.kosong.denganKata('ab').kataKirim, 'ab');
      // Dua huruf dengan spasi di ujung: yang dihitung setelah dipotong.
      expect(FilterArsip.kosong.denganKata(' a  ').kataKirim, isNull);
    });

    test('mode hasil: kata >= 2 huruf atau rentang tanggal; PT saja bukan', () {
      expect(FilterArsip.kosong.modeHasil, isFalse);
      expect(FilterArsip.kosong.denganKata('a').modeHasil, isFalse);
      expect(FilterArsip.kosong.denganKata('ab').modeHasil, isTrue);
      expect(
        FilterArsip.kosong
            .denganRentang(DateTime(2026, 11), DateTime(2026, 11, 15))
            .modeHasil,
        isTrue,
      );
      // PT saja menyempitkan garis waktu, bukan pindah ke daftar hasil.
      expect(FilterArsip.kosong.denganPelanggan(3, 'PT A').modeHasil, isFalse);
    });

    test('adaFilter menghitung kata satu huruf, rentang, dan PT', () {
      expect(FilterArsip.kosong.adaFilter, isFalse);
      expect(FilterArsip.kosong.denganKata('a').adaFilter, isTrue);
      expect(FilterArsip.kosong.denganPelanggan(3, 'PT A').adaFilter, isTrue);
      expect(
        FilterArsip.kosong.denganRentang(DateTime(2026), null).adaFilter,
        isTrue,
      );
    });

    test('rentang dinormalisasi ke tanggal polos; kesamaan berdasar nilai', () {
      final a = FilterArsip.kosong.denganRentang(
        DateTime(2026, 11, 1, 13, 30),
        DateTime(2026, 11, 15, 8),
      );
      final b = FilterArsip.kosong.denganRentang(
        DateTime(2026, 11),
        DateTime(2026, 11, 15),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.dari, DateTime(2026, 11));
    });

    test('menghapus PT ikut membuang namanya', () {
      final f = FilterArsip.kosong
          .denganPelanggan(3, 'PT A')
          .denganPelanggan(null, 'sisa');

      expect(f.pelangganId, isNull);
      expect(f.pelangganNama, isNull);
    });
  });

  group('filterArsipProvider', () {
    test(
      'nilai yang sama tidak memicu perubahan (tidak ambil ulang)',
      () async {
        final s = await _siapkan(_ServiceUji());
        final dicatat = <FilterArsip>[];
        s.wadah.listen(
          filterArsipProvider,
          (_, baru) => dicatat.add(baru),
          fireImmediately: false,
        );
        final notifier = s.wadah.read(filterArsipProvider.notifier);

        notifier.aturKata('sn-0204');
        notifier.aturKata('sn-0204 ');
        notifier.aturKata('  sn-0204');

        expect(dicatat, hasLength(1));
        expect(dicatat.single.kata, 'sn-0204');
      },
    );

    test('atur dan bersihkan saringan', () async {
      final s = await _siapkan(_ServiceUji());
      _tahan(s.wadah, filterArsipProvider);
      final notifier = s.wadah.read(filterArsipProvider.notifier)
        ..aturKata('oven')
        ..aturPelanggan(3, 'PT Contoh Alfa')
        ..aturRentang(DateTime(2026, 11), DateTime(2026, 11, 15));

      final f = s.wadah.read(filterArsipProvider);
      expect(f.kata, 'oven');
      expect(f.pelangganId, 3);
      expect(f.dari, DateTime(2026, 11));

      notifier.bersihkan();
      expect(s.wadah.read(filterArsipProvider), FilterArsip.kosong);
    });

    test('ganti akun membuang saringan (id PT milik lab lain)', () async {
      final s = await _siapkan(_ServiceUji());
      _tahan(s.wadah, filterArsipProvider);
      s.wadah.read(filterArsipProvider.notifier)
        ..aturKata('oven')
        ..aturPelanggan(3, 'PT Contoh Alfa');

      s.auth().ganti(_akunB);
      await Future<void>.delayed(Duration.zero);

      expect(s.wadah.read(filterArsipProvider), FilterArsip.kosong);
    });

    test(
      'data akun yang sama dimuat ulang (profil) tidak membuang saringan',
      () async {
        final s = await _siapkan(_ServiceUji());
        _tahan(s.wadah, filterArsipProvider);
        s.wadah.read(filterArsipProvider.notifier).aturKata('oven');

        s.auth().ganti(
          const User(
            id: 1,
            nama: 'Budi S.',
            email: 'admin@pt-sidik.com',
            employeeId: 'SDK-0001',
            role: UserRole.admin,
            status: UserStatus.aktif,
            organizationId: 1,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(s.wadah.read(filterArsipProvider).kata, 'oven');
      },
    );
  });

  group('hasilCariArsipProvider', () {
    test('tanpa saringan hasil: tidak ada panggilan ke server', () async {
      final service = _ServiceUji();
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);

      final h = await s.wadah.read(hasilCariArsipProvider.future);
      s.wadah.read(filterArsipProvider.notifier).aturKata('a');
      await s.wadah.read(hasilCariArsipProvider.future);

      expect(service.riwayat, isEmpty);
      expect(h.baris, isEmpty);
      expect(h.bisaMuatLagi, isFalse);
    });

    test(
      'kata >= 2 huruf: satu panggilan, halaman 1, dengan saringan itu',
      () async {
        final service = _ServiceUji()
          ..onRiwayat = (f, h) async => _halamanRiwayat([7, 6], total: 2);
        final s = await _siapkan(service);
        _tahan(s.wadah, hasilCariArsipProvider);
        s.wadah.read(filterArsipProvider.notifier).aturKata('SN-0204');

        final h = await s.wadah.read(hasilCariArsipProvider.future);

        expect(service.riwayat, hasLength(1));
        expect(service.riwayat.single.filter.kataKirim, 'SN-0204');
        expect(service.riwayat.single.halaman, 1);
        expect(h.baris.map((b) => b.id), [7, 6]);
        expect(h.total, 2);
      },
    );

    test('halaman berikutnya menempel di bawah, tanpa id ganda, '
        'dan berhenti di last_page', () async {
      final service = _ServiceUji()
        ..onRiwayat = (f, halaman) async => switch (halaman) {
          1 => _halamanRiwayat([9, 8], terakhir: 2, total: 4),
          // 8 muncul lagi di halaman 2: tidak boleh tampil dua kali.
          _ => _halamanRiwayat([8, 7], halaman: 2, terakhir: 2, total: 4),
        };
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);
      s.wadah.read(filterArsipProvider.notifier).aturKata('jangka');
      await s.wadah.read(hasilCariArsipProvider.future);
      final notifier = s.wadah.read(hasilCariArsipProvider.notifier);

      await notifier.muatLebihBanyak();
      final sesudah = s.wadah.read(hasilCariArsipProvider).value!;
      expect(sesudah.baris.map((b) => b.id), [9, 8, 7]);
      expect(service.riwayat.last.halaman, 2);
      expect(sesudah.bisaMuatLagi, isFalse);

      // Sudah di halaman terakhir: tidak menembak lagi.
      await notifier.muatLebihBanyak();
      expect(service.riwayat, hasLength(2));
    });

    test('tiga halaman dimuat berurutan 2 lalu 3', () async {
      final service = _ServiceUji()
        ..onRiwayat = (f, halaman) async => _halamanRiwayat(
          [10 - halaman],
          halaman: halaman,
          terakhir: 3,
          total: 3,
        );
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);
      s.wadah.read(filterArsipProvider.notifier).aturKata('jangka');
      await s.wadah.read(hasilCariArsipProvider.future);
      final notifier = s.wadah.read(hasilCariArsipProvider.notifier);

      await notifier.muatLebihBanyak();
      await notifier.muatLebihBanyak();
      await notifier.muatLebihBanyak();

      expect(service.riwayat.map((p) => p.halaman), [1, 2, 3]);
      expect(
        s.wadah.read(hasilCariArsipProvider).value!.baris.map((b) => b.id),
        [9, 8, 7],
      );
    });

    test(
      'gagal memuat halaman berikutnya: daftar lama utuh, bisa diulang',
      () async {
        var gagal = true;
        final service = _ServiceUji()
          ..onRiwayat = (f, halaman) async {
            if (halaman == 1) {
              return _halamanRiwayat([9], terakhir: 2, total: 2);
            }
            if (gagal) throw Exception('jaringan putus');
            return _halamanRiwayat([8], halaman: 2, terakhir: 2, total: 2);
          };
        final s = await _siapkan(service);
        _tahan(s.wadah, hasilCariArsipProvider);
        s.wadah.read(filterArsipProvider.notifier).aturKata('jangka');
        await s.wadah.read(hasilCariArsipProvider.future);
        final notifier = s.wadah.read(hasilCariArsipProvider.notifier);

        await notifier.muatLebihBanyak();
        final galat = s.wadah.read(hasilCariArsipProvider).value!;
        expect(galat.baris.map((b) => b.id), [9]);
        expect(galat.galatMuatLagi, isNotNull);
        expect(galat.memuatLagi, isFalse);
        expect(galat.bisaMuatLagi, isTrue);

        gagal = false;
        await notifier.muatLebihBanyak();
        final pulih = s.wadah.read(hasilCariArsipProvider).value!;
        expect(pulih.baris.map((b) => b.id), [9, 8]);
        expect(pulih.galatMuatLagi, isNull);
      },
    );

    test('dua permintaan "muat lagi" beruntun hanya menembak sekali', () async {
      final tahanHalaman2 = Completer<HalamanRiwayat>();
      final service = _ServiceUji()
        ..onRiwayat = (f, halaman) => halaman == 1
            ? Future.value(_halamanRiwayat([9], terakhir: 2, total: 2))
            : tahanHalaman2.future;
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);
      s.wadah.read(filterArsipProvider.notifier).aturKata('jangka');
      await s.wadah.read(hasilCariArsipProvider.future);
      final notifier = s.wadah.read(hasilCariArsipProvider.notifier);

      final pertama = notifier.muatLebihBanyak();
      await notifier.muatLebihBanyak();
      tahanHalaman2.complete(
        _halamanRiwayat([8], halaman: 2, terakhir: 2, total: 2),
      );
      await pertama;

      expect(service.riwayat.where((p) => p.halaman == 2), hasLength(1));
    });

    test('jawaban halaman lama dibuang bila saringan sudah berganti', () async {
      final tahanHalaman2 = Completer<HalamanRiwayat>();
      final service = _ServiceUji()
        ..onRiwayat = (f, halaman) {
          if (f.kata == 'jangka' && halaman == 2) return tahanHalaman2.future;
          return Future.value(
            f.kata == 'jangka'
                ? _halamanRiwayat([9], terakhir: 2, total: 2)
                : _halamanRiwayat([50], alat: 'Oven'),
          );
        };
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);
      final filter = s.wadah.read(filterArsipProvider.notifier)
        ..aturKata('jangka');
      await s.wadah.read(hasilCariArsipProvider.future);
      final sedangMuat = s.wadah
          .read(hasilCariArsipProvider.notifier)
          .muatLebihBanyak();

      filter.aturKata('oven');
      await s.wadah.read(hasilCariArsipProvider.future);
      tahanHalaman2.complete(
        _halamanRiwayat([8], halaman: 2, terakhir: 2, total: 2),
      );
      await sedangMuat;

      final h = s.wadah.read(hasilCariArsipProvider).value!;
      expect(h.filter.kata, 'oven');
      expect(h.baris.map((b) => b.id), [50]);
    });

    test('"muat lagi" ditekan selagi saringan baru dimuat: halaman lama '
        'TIDAK diminta dan hasil baru tidak tertimpa', () async {
      // Probe peninjau: ketik "ab" (halaman 1 dari 2), ketik "abc" (jawaban
      // ditahan), tekan "muat lagi" di daftar "ab" yang masih tampil. Dulu
      // halaman 2 milik "ab" tiba belakangan dan menimpa hasil "abc".
      final tahanAbc = Completer<HalamanRiwayat>();
      final service = _ServiceUji()
        ..onRiwayat = (f, halaman) {
          if (f.kata == 'abc') return tahanAbc.future;
          return Future.value(
            _halamanRiwayat(
              [halaman == 1 ? 1 : 2],
              halaman: halaman,
              terakhir: 2,
              total: 2,
            ),
          );
        };
      final s = await _siapkan(service);
      _tahan(s.wadah, hasilCariArsipProvider);
      final filter = s.wadah.read(filterArsipProvider.notifier)..aturKata('ab');
      await s.wadah.read(hasilCariArsipProvider.future);

      filter.aturKata('abc');
      await pumpEventQueue();
      expect(s.wadah.read(hasilCariArsipProvider).isLoading, isTrue);

      await s.wadah.read(hasilCariArsipProvider.notifier).muatLebihBanyak();
      expect(
        service.riwayat.where((p) => p.halaman == 2),
        isEmpty,
        reason: 'halaman 2 milik "ab" tidak boleh diminta',
      );

      tahanAbc.complete(_halamanRiwayat([100]));
      final akhir = await s.wadah.read(hasilCariArsipProvider.future);

      expect(akhir.filter.kata, 'abc');
      expect(akhir.baris.map((b) => b.id), [100]);
      expect(service.riwayat.where((p) => p.halaman == 2), isEmpty);
    });

    test(
      'server lama: galatnya sampai ke state, bukan daftar kosong',
      () async {
        final service = _ServiceUji()
          ..onRiwayat = (f, h) async =>
              throw const ServerBelumMendukungArsipException();
        final s = await _siapkan(service);
        _tahan(s.wadah, hasilCariArsipProvider);
        s.wadah.read(filterArsipProvider.notifier).aturKata('jangka');

        await expectLater(
          s.wadah.read(hasilCariArsipProvider.future),
          throwsA(isA<ServerBelumMendukungArsipException>()),
        );
      },
    );

    test(
      'ganti akun: saringan hilang, hasil akun lama tidak dipakai ulang',
      () async {
        final service = _ServiceUji();
        // Id baris = urutan panggilan, jadi hasil basi langsung ketahuan.
        service.onRiwayat = (f, h) async =>
            _halamanRiwayat([service.riwayat.length]);
        final s = await _siapkan(service);
        _tahan(s.wadah, hasilCariArsipProvider);
        final filter = s.wadah.read(filterArsipProvider.notifier)
          ..aturKata('jangka');
        final akunA = await s.wadah.read(hasilCariArsipProvider.future);
        expect(akunA.baris.map((b) => b.id), [1]);

        s.auth().ganti(_akunB);
        final sesudahGanti = await s.wadah.read(hasilCariArsipProvider.future);
        expect(sesudahGanti.filter, FilterArsip.kosong);
        expect(sesudahGanti.baris, isEmpty);

        // Saringan yang sama diketik lagi oleh akun B: service HARUS dipanggil
        // lagi, bukan memakai hasil akun A yang kebetulan berbentuk sama.
        filter.aturKata('jangka');
        final akunB = await s.wadah.read(hasilCariArsipProvider.future);
        expect(service.riwayat, hasLength(2));
        expect(akunB.baris.map((b) => b.id), [2]);
      },
    );
  });

  group('jalur & garisWaktuProvider', () {
    final kelompokTahun = _kelompok('2026', {
      'tingkat': 'bulan',
      'tahun': 2026,
    });
    final kelompokBulan = _kelompok('2026-11', {
      'tingkat': 'pekan',
      'tahun': 2026,
      'bulan': 11,
    });

    test('mulai di akar: tingkat tahun, tanpa PT', () async {
      final service = _ServiceUji();
      final s = await _siapkan(service);
      _tahan(s.wadah, garisWaktuProvider);

      final status = await s.wadah.read(garisWaktuProvider.future);

      expect(service.garis, hasLength(1));
      expect(service.garis.single.posisi, PosisiGarisWaktu.akar);
      expect(service.garis.single.pelangganId, isNull);
      expect(status.posisi, PosisiGarisWaktu.akar);
    });

    test('masuk memakai telusuri kelompok persis; naik & kembaliKe', () async {
      final service = _ServiceUji();
      final s = await _siapkan(service);
      _tahan(s.wadah, garisWaktuProvider);
      await s.wadah.read(garisWaktuProvider.future);
      final jalur = s.wadah.read(jalurGarisWaktuProvider.notifier);

      jalur.masuk(kelompokTahun);
      await s.wadah.read(garisWaktuProvider.future);
      jalur.masuk(kelompokBulan);
      await s.wadah.read(garisWaktuProvider.future);

      expect(service.garis.map((g) => g.posisi.parameter), [
        {'tingkat': 'tahun'},
        {'tingkat': 'bulan', 'tahun': '2026'},
        {'tingkat': 'pekan', 'tahun': '2026', 'bulan': '11'},
      ]);
      expect(s.wadah.read(jalurGarisWaktuProvider).map((l) => l.label), [
        null,
        'label 2026',
        'label 2026-11',
      ]);

      jalur.naik();
      expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(2));

      jalur.kembaliKe(0);
      expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(1));

      // Sudah di akar: naik tidak merusak apa pun.
      jalur.naik();
      expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(1));
    });

    test(
      'kelompok tanpa telusuri atau alamat sama tidak menambah langkah',
      () async {
        final s = await _siapkan(_ServiceUji());
        _tahan(s.wadah, jalurGarisWaktuProvider);
        final jalur = s.wadah.read(jalurGarisWaktuProvider.notifier);

        jalur.masuk(
          const KelompokGarisWaktu(kunci: 'x', label: 'x', jumlah: 1),
        );
        jalur.masuk(_kelompok('akar', {'tingkat': 'tahun'}));

        expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(1));
      },
    );

    test('saringan PT: ikut terkirim dan jalur kembali ke akar', () async {
      final service = _ServiceUji();
      final s = await _siapkan(service);
      _tahan(s.wadah, garisWaktuProvider);
      await s.wadah.read(garisWaktuProvider.future);
      s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(kelompokTahun);
      await s.wadah.read(garisWaktuProvider.future);

      s.wadah.read(filterArsipProvider.notifier).aturPelanggan(3, 'PT A');
      final status = await s.wadah.read(garisWaktuProvider.future);

      expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(1));
      expect(service.garis.last.posisi, PosisiGarisWaktu.akar);
      expect(service.garis.last.pelangganId, 3);
      expect(status.pelangganId, 3);
    });

    test(
      'tingkat hari: dokumen halaman berikutnya menempel, tanpa ganda',
      () async {
        final hari = _kelompok('2026-11-12', {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
        });
        final service = _ServiceUji()
          ..onGaris = (posisi, pt, halaman) async => switch (halaman) {
            1 => _halamanGaris(
              TingkatGarisWaktu.hari,
              dokumen: [6, 5],
              terakhir: 2,
            ),
            _ => _halamanGaris(
              TingkatGarisWaktu.hari,
              dokumen: [5, 4],
              halaman: 2,
              terakhir: 2,
            ),
          };
        final s = await _siapkan(service);
        _tahan(s.wadah, garisWaktuProvider);
        await s.wadah.read(garisWaktuProvider.future);
        s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(hari);
        final awal = await s.wadah.read(garisWaktuProvider.future);
        expect(awal.bisaMuatLagi, isTrue);

        final notifier = s.wadah.read(garisWaktuProvider.notifier);
        await notifier.muatLebihBanyak();
        final sesudah = s.wadah.read(garisWaktuProvider).value!;

        expect(sesudah.item.map((i) => i.id), [6, 5, 4]);
        expect(service.garis.last.halaman, 2);
        expect(service.garis.last.posisi.parameter['pekan'], '46');
        expect(sesudah.bisaMuatLagi, isFalse);

        await notifier.muatLebihBanyak();
        expect(service.garis.where((g) => g.halaman == 2), hasLength(1));
      },
    );

    test(
      'tingkat hari: halaman berikutnya gagal → dokumen lama utuh, bisa diulang',
      () async {
        var gagal = true;
        final hari = _kelompok('2026-11-12', {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
        });
        final service = _ServiceUji()
          ..onGaris = (posisi, pt, halaman) async {
            if (halaman == 1) {
              return _halamanGaris(
                TingkatGarisWaktu.hari,
                dokumen: [6],
                terakhir: 2,
              );
            }
            if (gagal) throw Exception('jaringan putus');
            return _halamanGaris(
              TingkatGarisWaktu.hari,
              dokumen: [5],
              halaman: 2,
              terakhir: 2,
            );
          };
        final s = await _siapkan(service);
        _tahan(s.wadah, garisWaktuProvider);
        await s.wadah.read(garisWaktuProvider.future);
        s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(hari);
        await s.wadah.read(garisWaktuProvider.future);
        final notifier = s.wadah.read(garisWaktuProvider.notifier);

        await notifier.muatLebihBanyak();
        final galat = s.wadah.read(garisWaktuProvider).value!;
        expect(galat.item.map((i) => i.id), [6]);
        expect(galat.galatMuatLagi, isNotNull);
        expect(galat.memuatLagi, isFalse);
        expect(galat.bisaMuatLagi, isTrue);

        gagal = false;
        await notifier.muatLebihBanyak();
        final pulih = s.wadah.read(garisWaktuProvider).value!;
        expect(pulih.item.map((i) => i.id), [6, 5]);
        expect(pulih.galatMuatLagi, isNull);
      },
    );

    test(
      'tingkat hari: jawaban halaman lama dibuang bila tingkat sudah berpindah',
      () async {
        final hari = _kelompok('2026-11-12', {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
        });
        final tahanHalaman2 = Completer<HalamanGarisWaktu>();
        final service = _ServiceUji()
          ..onGaris = (posisi, pt, halaman) {
            if (posisi.tingkat == TingkatGarisWaktu.hari && halaman == 2) {
              return tahanHalaman2.future;
            }
            return Future.value(
              posisi.tingkat == TingkatGarisWaktu.hari
                  ? _halamanGaris(
                      TingkatGarisWaktu.hari,
                      dokumen: [6],
                      terakhir: 2,
                    )
                  : _halamanGaris(posisi.tingkat),
            );
          };
        final s = await _siapkan(service);
        _tahan(s.wadah, garisWaktuProvider);
        await s.wadah.read(garisWaktuProvider.future);
        final jalur = s.wadah.read(jalurGarisWaktuProvider.notifier)
          ..masuk(hari);
        await s.wadah.read(garisWaktuProvider.future);
        final sedangMuat = s.wadah
            .read(garisWaktuProvider.notifier)
            .muatLebihBanyak();

        jalur.naik();
        final akar = await s.wadah.read(garisWaktuProvider.future);
        tahanHalaman2.complete(
          _halamanGaris(
            TingkatGarisWaktu.hari,
            dokumen: [5],
            halaman: 2,
            terakhir: 2,
          ),
        );
        await sedangMuat;

        final akhir = s.wadah.read(garisWaktuProvider).value!;
        expect(akar.posisi, PosisiGarisWaktu.akar);
        expect(akhir.posisi, PosisiGarisWaktu.akar);
        expect(akhir.item, isEmpty);
      },
    );

    test('tingkat hari: tiga halaman dimuat berurutan 2 lalu 3', () async {
      final hari = _kelompok('2026-11-12', {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
      });
      final service = _ServiceUji()
        ..onGaris = (posisi, pt, halaman) async => _halamanGaris(
          posisi.tingkat,
          dokumen: posisi.tingkat == TingkatGarisWaktu.hari
              ? [10 - halaman]
              : [],
          halaman: halaman,
          terakhir: 3,
        );
      final s = await _siapkan(service);
      _tahan(s.wadah, garisWaktuProvider);
      await s.wadah.read(garisWaktuProvider.future);
      s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(hari);
      await s.wadah.read(garisWaktuProvider.future);
      final notifier = s.wadah.read(garisWaktuProvider.notifier);

      await notifier.muatLebihBanyak();
      await notifier.muatLebihBanyak();
      await notifier.muatLebihBanyak();

      final status = s.wadah.read(garisWaktuProvider).value!;
      expect(
        service.garis
            .where((g) => g.posisi.tingkat == TingkatGarisWaktu.hari)
            .map((g) => g.halaman),
        [1, 2, 3],
      );
      expect(status.item.map((i) => i.id), [9, 8, 7]);
      expect(status.bisaMuatLagi, isFalse);
    });

    test('tingkat hari: "muat lagi" ditekan selagi tingkat lain dimuat → '
        'halaman lama tidak diminta', () async {
      final hari = _kelompok('2026-11-12', {
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
      });
      var tahanAkar = false;
      final akarTertahan = Completer<HalamanGarisWaktu>();
      final service = _ServiceUji()
        ..onGaris = (posisi, pt, halaman) {
          if (posisi.tingkat == TingkatGarisWaktu.tahun && tahanAkar) {
            return akarTertahan.future;
          }
          return Future.value(
            posisi.tingkat == TingkatGarisWaktu.hari
                ? _halamanGaris(
                    TingkatGarisWaktu.hari,
                    dokumen: [halaman == 1 ? 6 : 5],
                    halaman: halaman,
                    terakhir: 2,
                  )
                : _halamanGaris(posisi.tingkat),
          );
        };
      final s = await _siapkan(service);
      _tahan(s.wadah, garisWaktuProvider);
      await s.wadah.read(garisWaktuProvider.future);
      final jalur = s.wadah.read(jalurGarisWaktuProvider.notifier)..masuk(hari);
      await s.wadah.read(garisWaktuProvider.future);

      tahanAkar = true;
      jalur.naik();
      await pumpEventQueue();
      expect(s.wadah.read(garisWaktuProvider).isLoading, isTrue);

      await s.wadah.read(garisWaktuProvider.notifier).muatLebihBanyak();
      expect(
        service.garis.where((g) => g.halaman == 2),
        isEmpty,
        reason: 'halaman 2 milik tingkat hari tidak boleh diminta',
      );

      akarTertahan.complete(_halamanGaris(TingkatGarisWaktu.tahun));
      final akhir = await s.wadah.read(garisWaktuProvider.future);
      expect(akhir.posisi, PosisiGarisWaktu.akar);
      expect(akhir.item, isEmpty);
    });

    test(
      'tingkat hari: dua "muat lagi" beruntun hanya menembak sekali',
      () async {
        final hari = _kelompok('2026-11-12', {
          'tingkat': 'hari',
          'tahun': 2026,
          'bulan': 11,
          'pekan': 46,
        });
        final tahanHalaman2 = Completer<HalamanGarisWaktu>();
        final service = _ServiceUji()
          ..onGaris = (posisi, pt, halaman) {
            if (posisi.tingkat == TingkatGarisWaktu.hari && halaman == 2) {
              return tahanHalaman2.future;
            }
            return Future.value(
              posisi.tingkat == TingkatGarisWaktu.hari
                  ? _halamanGaris(
                      TingkatGarisWaktu.hari,
                      dokumen: [6],
                      terakhir: 2,
                    )
                  : _halamanGaris(posisi.tingkat),
            );
          };
        final s = await _siapkan(service);
        _tahan(s.wadah, garisWaktuProvider);
        await s.wadah.read(garisWaktuProvider.future);
        s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(hari);
        await s.wadah.read(garisWaktuProvider.future);
        final notifier = s.wadah.read(garisWaktuProvider.notifier);

        final pertama = notifier.muatLebihBanyak();
        await notifier.muatLebihBanyak();
        tahanHalaman2.complete(
          _halamanGaris(
            TingkatGarisWaktu.hari,
            dokumen: [5],
            halaman: 2,
            terakhir: 2,
          ),
        );
        await pertama;

        expect(service.garis.where((g) => g.halaman == 2), hasLength(1));
        expect(s.wadah.read(garisWaktuProvider).value!.item.map((i) => i.id), [
          6,
          5,
        ]);
      },
    );

    test(
      'ganti akun: jalur kembali ke akar dan service dipanggil ulang',
      () async {
        final service = _ServiceUji();
        final s = await _siapkan(service);
        _tahan(s.wadah, garisWaktuProvider);
        await s.wadah.read(garisWaktuProvider.future);
        s.wadah.read(jalurGarisWaktuProvider.notifier).masuk(kelompokTahun);
        await s.wadah.read(garisWaktuProvider.future);
        final sebelum = service.garis.length;

        s.auth().ganti(_akunB);
        await s.wadah.read(garisWaktuProvider.future);

        expect(s.wadah.read(jalurGarisWaktuProvider), hasLength(1));
        expect(service.garis.length, greaterThan(sebelum));
        expect(service.garis.last.posisi, PosisiGarisWaktu.akar);
      },
    );
  });
}
