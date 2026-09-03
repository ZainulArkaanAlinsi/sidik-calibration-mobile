import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/providers/penjaga_urutan_muat.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Balasan yang ketinggalan tidak boleh menimpa layar (BUG-020).
///
/// ## Kenapa berkas ini ada
///
/// Pola ini tersebar di lima pintu muat-ulang:
///
/// ```dart
/// Future<void> cari(String query) async {
///   _search = query;
///   state = const AsyncValue.loading();
///   state = await AsyncValue.guard(() => build());
/// }
/// ```
///
/// Tidak ada apa pun di situ yang menghubungkan balasan dengan permintaan yang
/// memintanya. Teknisi mengetik "jang" lalu "jangka"; permintaan "jang" lebih
/// lambat sampai, mendarat SESUDAH "jangka", dan menimpa layar dengan hasil
/// dari kata kunci yang sudah tidak ada di kotak pencarian. Yang terlihat: dia
/// mengetik lebih spesifik, hasilnya justru melebar.
///
/// Penjaganya sudah ada dan sudah benar di `PratinjauController`, lengkap
/// dengan alasannya di tempat: *"permintaan lama bisa nyampe sesudah yang baru
/// dan nimpa layar … Debounce ngurangin peluangnya, nggak ngilangin."* Yang
/// tidak ada cuma jalannya ke lima pintu ini.
///
/// ## Kenapa diuji lewat notifier bikinan, bukan lewat `CustomerController`
///
/// Yang harus dibuktikan di sini urutan balasan, dan itu cuma bisa dibuktikan
/// kalau test-nya yang menentukan kapan tiap permintaan pulang. Lewat controller
/// asli, `build()`-nya juga menunggu token dan ikut lahir ulang tiap
/// `authProvider` bergerak — jadi jumlah permintaan yang berangkat tidak lagi
/// ditentukan test-nya, dan yang tersisa cuma balapan yang kebetulan menang.
/// Balapan yang kebetulan bukan bukti.
///
/// Yang hilang dari cara ini cuma satu: dia tidak membuktikan lima pintu itu
/// benar-benar lewat penjaganya. Itu ditutup grup kedua di bawah.

/// Notifier tiruan yang seluruh permintaannya ditahan test.
class _Ditahan extends AsyncNotifier<String> with PenjagaUrutanMuat<String> {
  /// Satu penahan per permintaan, urut sesuai urutan berangkat.
  final List<Completer<String>> tertahan = [];

  /// Nilai pertama dipasang langsung supaya `build()` awal tidak ikut
  /// menggantung dan mengaburkan hitungan.
  bool _pertama = true;

  @override
  Future<String> build() {
    if (_pertama) {
      _pertama = false;
      return Future.value('awal');
    }
    final penahan = Completer<String>();
    tertahan.add(penahan);
    return penahan.future;
  }

  Future<void> cari() => muatDenganPenjaga(build);
}

final _ditahanProvider = AsyncNotifierProvider<_Ditahan, String>(_Ditahan.new);

void main() {
  Future<void> putar() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('penjaga urutan', () {
    late ProviderContainer w;
    late _Ditahan notifier;

    setUp(() async {
      w = ProviderContainer();
      addTearDown(w.dispose);
      // Langganannya ditahan supaya provider tidak dibuang auto-dispose di
      // tengah kerja async-nya — alasan yang sama dengan catatan di
      // `simpanan_pelanggan_test.dart`.
      w.listen(_ditahanProvider, (_, _) {});
      await putar();
      notifier = w.read(_ditahanProvider.notifier);
      expect(w.read(_ditahanProvider).value, 'awal');
    });

    /// Inti bug-nya.
    test('balasan lama yang nyampe belakangan dibuang', () async {
      unawaited(notifier.cari()); // "jang"
      await putar();
      unawaited(notifier.cari()); // "jangka"
      await putar();

      expect(notifier.tertahan, hasLength(2));

      // Yang BARU pulang duluan…
      notifier.tertahan[1].complete('jangka');
      await putar();
      expect(w.read(_ditahanProvider).value, 'jangka');

      // …lalu yang LAMA baru menyusul. Sebelum diperbaiki, baris ini menimpa
      // layar dengan hasil kata kunci yang sudah tidak ada di kotaknya.
      notifier.tertahan[0].complete('jang');
      await putar();

      expect(
        w.read(_ditahanProvider).value,
        'jangka',
        reason: 'Balasan permintaan lama nimpa hasil pencarian yang baru.',
      );
    });

    /// Error dari permintaan lama sama menyesatkannya dengan datanya: layar
    /// merah untuk pencarian yang sudah tidak ada di kotaknya, sementara hasil
    /// yang benar sudah terlanjur tampil.
    test('error dari permintaan lama juga dibuang', () async {
      unawaited(notifier.cari());
      await putar();
      unawaited(notifier.cari());
      await putar();

      notifier.tertahan[1].complete('jangka');
      await putar();
      notifier.tertahan[0].completeError(Exception('server nggak nyaut'));
      await putar();

      final state = w.read(_ditahanProvider);
      expect(
        state.hasError,
        isFalse,
        reason: 'Layar merah dari permintaan yang sudah basi.',
      );
      expect(state.value, 'jangka');
    });

    /// Tiga beruntun, dan yang menang tetap yang TERAKHIR diketik — bukan
    /// sekadar "yang bukan pertama".
    test('tiga beruntun, yang menang tetap yang terakhir', () async {
      unawaited(notifier.cari());
      await putar();
      unawaited(notifier.cari());
      await putar();
      unawaited(notifier.cari());
      await putar();

      expect(notifier.tertahan, hasLength(3));

      notifier.tertahan[2].complete('ketiga');
      await putar();
      notifier.tertahan[0].complete('pertama');
      await putar();
      notifier.tertahan[1].complete('kedua');
      await putar();

      expect(w.read(_ditahanProvider).value, 'ketiga');
    });

    /// JANGAN kebablasan: jalur normal harus tetap sampai ke layar. Penjaga
    /// yang terlalu ketat membuang SEMUA balasan, dan gejalanya persis sama
    /// dengan server yang tidak pernah menjawab.
    test('permintaan tunggal tetap mendarat', () async {
      unawaited(notifier.cari());
      await putar();

      notifier.tertahan.single.complete('jangka');
      await putar();

      expect(w.read(_ditahanProvider).value, 'jangka');
    });

    /// Error dari permintaan TERAKHIR tetap harus kelihatan — kalau tidak,
    /// server mati jadi tidak bisa dibedakan dari hasil kosong.
    test('error dari permintaan terakhir tetap tampil', () async {
      unawaited(notifier.cari());
      await putar();

      notifier.tertahan.single.completeError(Exception('server nggak nyaut'));
      await putar();

      expect(w.read(_ditahanProvider).hasError, isTrue);
    });

    test('loading dipasang begitu permintaan berangkat', () async {
      unawaited(notifier.cari());
      await putar();

      expect(w.read(_ditahanProvider).isLoading, isTrue);
    });
  });

  /// Yang dibawa pulang sebuah permintaan bukan cuma `state`.
  ///
  /// `EquipmentController` menyimpan nomor halaman terakhirnya di FIELD, dan
  /// dulu field itu ditulis di dalam `build()` — sebelum penjaganya sempat
  /// menolak hasilnya. Jadi `state` dijaga, `_lastPage` tidak: pencarian lama
  /// yang pulang belakangan meninggalkan `lastPage` milik kata kunci yang sudah
  /// tidak ada di kotaknya, dan "muat lebih banyak" berikutnya meminta halaman
  /// yang bukan miliknya lalu menempelkannya ke daftar yang salah.
  ///
  /// Di sini controller ASLINYA yang diuji, bukan notifier tiruan — yang harus
  /// dibuktikan justru field milik controller itu. Determinismenya dijaga
  /// dengan cara lain: layanannya menahan tiap balasan sampai test-nya yang
  /// melepas, dan jumlah permintaan yang sudah berangkat ikut diperiksa di tiap
  /// langkah supaya build tak terduga bikin test-nya MERAH, bukan salah hitung
  /// diam-diam.
  group('metadata halaman ikut dijaga urutannya', () {
    test('pencarian lama nggak meninggalkan lastPage-nya', () async {
      final layanan = _LayananBertahap();

      final w = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          equipmentServiceProvider.overrideWithValue(layanan),
        ],
      );
      addTearDown(w.dispose);

      await w
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0001', password: 'rahasia123');

      w.listen(equipmentProvider, (_, _) {});
      await putar();

      // Build pertama: satu halaman saja.
      expect(layanan.antrean, hasLength(1));
      layanan.jawab(0, lastPage: 1);
      await putar();

      final notifier = w.read(equipmentProvider.notifier);
      expect(notifier.bisaMuatLagi, isFalse);

      // Teknisi mengetik "jang", lalu melanjutkannya jadi "jangka".
      unawaited(notifier.cari('jang'));
      await putar();
      unawaited(notifier.cari('jangka'));
      await putar();

      expect(
        layanan.antrean,
        hasLength(3),
        reason: 'Jumlah permintaannya bukan yang diatur test — hasilnya bukan '
            'bukti balapan, cuma kebetulan.',
      );

      // "jangka" pulang duluan: satu halaman.
      layanan.jawab(2, lastPage: 1);
      await putar();

      // "jang" pulang belakangan: sembilan halaman. Hasilnya ketinggalan, jadi
      // NOMOR HALAMANNYA pun harus ikut dibuang.
      layanan.jawab(1, lastPage: 9);
      await putar();

      expect(
        notifier.bisaMuatLagi,
        isFalse,
        reason: 'lastPage punya pencarian lama ketinggalan di controller — '
            '"muat lebih banyak" bakal minta halaman 2 milik kata kunci lain.',
      );
    });
  });

  /// Yang tidak dibuktikan grup di atas: lima pintu aslinya benar-benar
  /// memakai penjaganya.
  ///
  /// Ini penjagaan struktural, bukan perilaku — dan itu memang yang dibutuhkan.
  /// Bug-nya lahir bukan karena penjaganya salah, tapi karena penjaganya tidak
  /// dipasang; controller yang lupa `with PenjagaUrutanMuat` akan merah di sini
  /// sebelum sempat lahir dengan balapan yang sama.
  group('controller aslinya memakai penjaga itu', () {
    test('empat controller data pakai mixin-nya', () {
      // Token & auth di-override supaya `build()` keempatnya tidak menyentuh
      // Keystore lewat platform channel yang tidak ada di `flutter test`.
      // Yang diperiksa di sini tipenya, bukan datanya — tapi membaca
      // `.notifier` tetap menjalankan `build()`.
      final wadah = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
        ],
      );
      addTearDown(wadah.dispose);

      expect(wadah.read(customerProvider.notifier), isA<PenjagaUrutanMuat>());
      expect(wadah.read(orderListProvider.notifier), isA<PenjagaUrutanMuat>());
      expect(wadah.read(userListProvider.notifier), isA<PenjagaUrutanMuat>());
      expect(wadah.read(equipmentProvider.notifier), isA<PenjagaUrutanMuat>());
    });
  });
}

/// Layanan alat yang tiap balasannya ditahan sampai test-nya melepas.
///
/// Bedanya dari `MockEquipmentService`: yang itu menjawab langsung, jadi tidak
/// pernah ada dua permintaan yang sedang di jalan bersamaan — dan balapan yang
/// tidak pernah terjadi tidak membuktikan apa pun.
class _LayananBertahap implements EquipmentService {
  final antrean = <Completer<EquipmentPage>>[];

  void jawab(int ke, {required int lastPage}) {
    antrean[ke].complete(
      EquipmentPage(items: const [], currentPage: 1, lastPage: lastPage),
    );
  }

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) {
    final penunggu = Completer<EquipmentPage>();
    antrean.add(penunggu);
    return penunggu.future;
  }

  @override
  Future<Equipment> simpan(String token, Equipment data) =>
      throw UnimplementedError();

  @override
  Future<Equipment> ubah(String token, Equipment data) =>
      throw UnimplementedError();

  @override
  Future<void> hapus(String token, int id) => throw UnimplementedError();
}
