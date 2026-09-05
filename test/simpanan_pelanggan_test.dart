import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/perusahaan_direktori.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/simpanan_pelanggan.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Mock yang **menghitung panggilannya**.
///
/// Angka itu yang jadi buktinya di test ganti akun. Membandingkan isi daftar
/// saja bisa hijau walau providernya nggak pernah lahir ulang — data akun A dan
/// akun B di satu lab memang berbentuk sama. Yang membedakan "diambil ulang"
/// dari "sisa yang kebetulan cocok" cuma jumlah panggilan ke server.
class _LookupPenghitung implements CustomerLookupService {
  _LookupPenghitung({required this.daftar});

  List<CustomerLookup> daftar;

  /// Kalau `true`, [cari] gagal — menirukan server mati / sinyal habis.
  bool mati = false;

  int panggilan = 0;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    panggilan++;
    if (mati) throw Exception('server nggak nyaut');
    return daftar;
  }

  @override
  Future<HasilDirektori> cariDirektori(
    String token, {
    required String search,
  }) async => (daftar: const <PerusahaanDirektori>[], atribusi: null);

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) async => CustomerLookup(id: 99, nama: nama, alamat: alamat);
}

ProviderContainer _wadah(_LookupPenghitung lookup) {
  final wadah = ProviderContainer(
    overrides: [
      // Kosong: tiap test masuk lewat `login()`, bukan lewat token yang sudah
      // nempel. Itu yang bikin urutan login → logout → login bisa diuji utuh.
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authServiceProvider.overrideWithValue(
        MockAuthService(jeda: Duration.zero),
      ),
      customerLookupServiceProvider.overrideWithValue(lookup),
      // Logout mencabut token push sebelum membuang token akun. Tanpa override
      // ini, jalannya test ikut bergantung pada platform host — dan yang mau
      // diuji di sini bukan itu.
      sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
    ],
  );
  addTearDown(wadah.dispose);
  return wadah;
}

/// Baca hasil provider sambil **menahan langganannya**.
///
/// Bukan kerapian: `customerLookupProvider` itu auto-dispose, dan kalau nggak
/// ada yang mendengarkan, Riverpod boleh membuangnya di tengah kerja async-nya.
/// Kalau itu kejadian, `.future` nggak pernah selesai — test-nya nggak gagal,
/// dia MENGGANTUNG sampai timeout 30 detik, dan pesan yang keluar nunjuk ke
/// arah yang salah ("disposed during loading state"). Kena persis di test jalur
/// offline, yang hop async-nya paling banyak.
///
/// Di aplikasi beneran selalu ada widget yang mendengarkan selama sheet-nya
/// kebuka, jadi menahan langganan di sini justru yang mendekati kenyataan.
///
/// Langganannya sengaja nggak ditutup: dia mati bareng wadahnya di tearDown,
/// dan di test ganti akun umurnya yang panjang itu justru yang jadi buktinya
/// — lihat catatan di situ.
Future<HasilPelanggan> _hasil(ProviderContainer wadah, String cari) {
  final provider = customerLookupProvider(cari);
  wadah.listen(provider, (_, _) {});
  return wadah.read(provider.future);
}

const _pelangganA = [
  CustomerLookup(id: 1, nama: 'PT Maju Jaya', alamat: 'Jl. Raya Bekasi KM 27'),
  CustomerLookup(id: 2, nama: 'CV Sentosa Abadi'),
];

const _pelangganB = [CustomerLookup(id: 7, nama: 'PT Rahasia Lab Sebelah')];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SimpananPelanggan', () {
    test('nyimpen lalu baca balik utuh', () async {
      const simpanan = SimpananPelanggan();

      await simpanan.simpan(1, _pelangganA);
      final isi = await simpanan.baca(1);

      expect(isi, isNotNull);
      expect(isi!.daftar.map((c) => c.id), [1, 2]);
      expect(isi.daftar.first.alamat, 'Jl. Raya Bekasi KM 27');
      // Yang tanpa alamat tetap tanpa alamat — bukan berubah jadi string kosong.
      expect(isi.daftar.last.alamat, isNull);
    });

    test('laci organisasi lain nggak kebaca', () async {
      const simpanan = SimpananPelanggan();

      await simpanan.simpan(1, _pelangganA);

      expect(await simpanan.baca(2), isNull);
    });

    test('organisasi null nggak disimpan sama sekali', () async {
      const simpanan = SimpananPelanggan();

      await simpanan.simpan(null, _pelangganA);

      // Bukan cuma `baca(null)` yang null — nggak ada laci apa pun yang lahir.
      // Satu laci bersama buat semua akun tanpa organisasi bikin mereka saling
      // melihat daftar pelanggan.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('pelanggan.')), isEmpty);
    });

    test('bersihkan() buang SEMUA laci, bukan cuma satu organisasi', () async {
      const simpanan = SimpananPelanggan();

      await simpanan.simpan(1, _pelangganA);
      await simpanan.simpan(2, _pelangganB);

      await simpanan.bersihkan();

      expect(await simpanan.baca(1), isNull);
      expect(await simpanan.baca(2), isNull);
    });

    test('isi rusak dianggap NGGAK ADA, bukan bikin meledak', () async {
      SharedPreferences.setMockInitialValues({
        'pelanggan.v1.1': 'ini bukan json',
      });

      expect(await const SimpananPelanggan().baca(1), isNull);
    });

    test('saring() nyari nama, alamat, dan tahan tanda baca', () {
      const simpanan = SimpananPelanggan();
      const daftar = [
        CustomerLookup(id: 1, nama: 'PT. Maju Jaya', alamat: 'Cikarang'),
        CustomerLookup(id: 2, nama: 'CV Sentosa', alamat: 'Tangerang'),
      ];

      expect(simpanan.saring(daftar, 'maju').map((c) => c.id), [1]);
      expect(simpanan.saring(daftar, 'tangerang').map((c) => c.id), [2]);
      // Yang tersimpan `PT. Maju Jaya`, yang diketik `PT Maju Jaya` — server
      // menemukannya lewat `nama_normal`, jadi jalur offline harus sama.
      expect(simpanan.saring(daftar, 'PT Maju Jaya').map((c) => c.id), [1]);
      expect(simpanan.saring(daftar, '   ').length, 2);
    });
  });

  group('customerLookupProvider', () {
    test('server hidup → hasil server, dan disimpan buat nanti', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');

      final hasil = await _hasil(wadah, '');

      expect(hasil.dariSimpanan, isFalse);
      expect(hasil.daftar.map((c) => c.id), [1, 2]);
      expect((await const SimpananPelanggan().baca(1))?.daftar.length, 2);
    });

    test('hasil pencarian NGGAK menimpa simpanan daftar utuh', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');

      await _hasil(wadah, '');

      // Pencarian yang cuma balik satu baris. Kalau ini ikut disimpan, teknisi
      // yang offline cuma bisa menemukan pelanggan yang pernah dia ketik.
      lookup.daftar = const [CustomerLookup(id: 1, nama: 'PT Maju Jaya')];
      await _hasil(wadah, 'maju');

      expect((await const SimpananPelanggan().baca(1))?.daftar.length, 2);
    });

    test('server mati + ada simpanan → daftar simpanan, ditandai', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');
      await _hasil(wadah, '');

      lookup.mati = true;
      wadah.invalidate(customerLookupProvider);

      final hasil = await _hasil(wadah, '');

      expect(hasil.dariSimpanan, isTrue);
      expect(hasil.daftar.map((c) => c.id), [1, 2]);
      expect(hasil.diambil, isNotNull);
    });

    test('server mati + pencarian → simpanan ikut disaring', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');
      await _hasil(wadah, '');

      lookup.mati = true;

      final hasil = await _hasil(wadah, 'sentosa');

      expect(hasil.dariSimpanan, isTrue);
      expect(hasil.daftar.map((c) => c.id), [2]);
    });

    test(
      'server mati + NGGAK ada simpanan → error, bukan daftar kosong',
      () async {
        final lookup = _LookupPenghitung(daftar: _pelangganA)..mati = true;
        final wadah = _wadah(lookup);

        await wadah
            .read(authProvider.notifier)
            .login(identifier: 'SDK-0002', password: 'rahasia123');

        // Daftar kosong di sini kebaca "pelanggannya beneran nggak ada", dan
        // teknisi yang percaya itu mendaftarkan ulang PT yang sudah terdaftar.
        await expectLater(_hasil(wadah, ''), throwsA(isA<Exception>()));
      },
    );
  });

  group('ganti akun di HP yang sama', () {
    test('logout buang simpanan, dan akun berikutnya AMBIL ULANG', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      // Langganan yang dipasang [_hasil] ditahan hidup sampai akhir test, dan
      // itu bagian yang bikin test ini bermakna — bukan sekadar rapi.
      //
      // Tanpa dia, providernya nggak didengarkan siapa pun, jadi auto-dispose
      // Riverpod membuangnya di sela-sela `await` dan bacaan berikutnya
      // menghitung ulang dari nol. Angkanya tetap naik, isinya tetap berganti
      // — tapi yang terbukti cuma "auto-dispose jalan", bukan "providernya
      // ikut akun". Hapus `ref.watch(authProvider)` dari providernya dan test
      // versi tanpa langganan itu TETAP hijau.
      //
      // Dengan langganan yang hidup, satu-satunya sebab dia bisa lahir ulang
      // adalah dependensinya ke `authProvider`.

      // 1. Akun A (teknisi) — daftarnya masuk, dan ikut tersimpan di HP.
      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');

      final hasilA = await _hasil(wadah, '');
      expect(hasilA.daftar.map((c) => c.id), [1, 2]);

      final panggilanSetelahA = lookup.panggilan;

      // 2. Logout.
      await wadah.read(authProvider.notifier).logout();

      // Laci di disk beneran kosong. Ini lapis yang nggak dijaga auto-dispose
      // Riverpod sama sekali: isi SharedPreferences bertahan melewati logout,
      // melewati aplikasi ditutup, melewati HP dimatikan.
      expect(await const SimpananPelanggan().baca(1), isNull);

      // 3. Akun B (admin, lab yang sama).
      lookup.daftar = _pelangganB;
      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0001', password: 'rahasia123');

      final hasilB = await _hasil(wadah, '');

      // 4. Isinya data B — DAN servernya beneran ditanya lagi.
      //
      // Dua-duanya, bukan salah satu. Assert isi doang bisa hijau walau
      // providernya nggak pernah lahir ulang, kalau data dua akun kebetulan
      // berbentuk sama — dan dua akun di satu lab memang lihat daftar yang
      // sama. Jadi panggilannya ikut dihitung.
      //
      // Angkanya `greaterThan`, bukan bilangan pasti: keadaan auth bergerak
      // dua kali per jalur (`loading` lalu `data`), dan berapa banyak yang
      // dikoalisikan penjadwal Riverpod bukan hal yang layak dipatok di test
      // ini.
      expect(hasilB.daftar.map((c) => c.id), [7]);
      expect(hasilB.dariSimpanan, isFalse);
      expect(lookup.panggilan, greaterThan(panggilanSetelahA));
    });

    test('logoutAll ikut buang simpanan, sama kayak logout', () async {
      final lookup = _LookupPenghitung(daftar: _pelangganA);
      final wadah = _wadah(lookup);

      await wadah
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0002', password: 'rahasia123');
      await _hasil(wadah, '');

      expect(await const SimpananPelanggan().baca(1), isNotNull);

      await wadah.read(authProvider.notifier).logoutAll();

      // Jalurnya dua, bukan satu. Ketinggalan di sini bikin "keluarkan sesi
      // saya di semua perangkat" justru MENINGGALKAN lebih banyak sisa
      // daripada logout biasa — kebalikan dari yang orangnya minta.
      expect(await const SimpananPelanggan().baca(1), isNull);
    });
  });
}
