import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Penjaga urutan respons buat notifier yang punya lebih dari satu pintu
/// muat-ulang (`cari`, `saring`, `filter`, `muatUlang`).
///
/// ## Masalahnya
///
/// Pola yang tersebar di provider-provider ini:
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
/// Debounce mengurangi peluangnya, **tidak menghilangkan**. Dua permintaan yang
/// berangkat 400 ms berjarak tetap bisa pulang terbalik kalau yang pertama
/// kena jaringan lapangan yang buruk — dan lapangan memang tempat aplikasi ini
/// dipakai.
///
/// ## Kenapa mixin, bukan disalin lima kali
///
/// Penjaganya sudah ada dan sudah benar di `PratinjauController`
/// (`lembar_kerja_provider.dart`), lengkap dengan alasannya di tempat. Yang
/// tidak ada cuma jalannya ke lima pintu lain — dan menyalinnya lima kali
/// berarti pintu keenam nanti lahir tanpa penjaga lagi, persis seperti lima ini
/// lahir tanpa penjaga.
///
/// Jadi bentuknya satu tempat yang harus dilewati: notifier yang memakai mixin
/// ini memanggil [muatDenganPenjaga] alih-alih menulis `state = await
/// AsyncValue.guard(...)` sendiri.
///
/// ## Yang TIDAK dijaga
///
/// Ini bukan pembatalan permintaan. Yang lama tetap berangkat, tetap dijawab
/// server, dan tetap menghabiskan kuotanya — yang dibuang cuma hasilnya. Untuk
/// memutus permintaannya sendiri butuh `CancelToken` di lapisan `ApiClient`,
/// dan itu perubahan yang jauh lebih besar daripada yang dibayar bug ini:
/// gejalanya self-correcting begitu ada pencarian berikutnya, dan tidak pernah
/// merusak data tersimpan.
mixin PenjagaUrutanMuat<T> on AsyncNotifier<T> {
  /// Nomor permintaan terakhir yang dikirim. Balasan yang nomornya bukan ini
  /// lagi berarti sudah ketinggalan.
  int _nomorTerakhir = 0;

  /// Daftarkan permintaan baru dan pulangkan nomornya.
  ///
  /// Dipakai langsung oleh pintu yang **tidak** boleh memasang `loading` —
  /// "muat lebih banyak" menambah ke daftar yang sudah kelihatan, dan
  /// mengosongkannya jadi spinner bikin scroll teknisi loncat ke atas.
  int mulaiPermintaan() => ++_nomorTerakhir;

  /// Apakah [nomor] masih permintaan terakhir. `false` berarti hasilnya sudah
  /// ketinggalan dan tidak boleh dipasang ke mana pun — bukan cuma ke `state`.
  bool masihTerbaru(int nomor) => nomor == _nomorTerakhir;

  /// Jalankan [muat], lalu pasang hasilnya ke `state` **cuma kalau dia masih
  /// yang terbaru**.
  ///
  /// Keadaan `loading` sengaja tetap dipasang oleh siapa pun yang masuk: itu
  /// memang yang benar begitu permintaan baru berangkat, dan tidak ada
  /// permintaan lama yang bisa "membatalkan" loading milik yang baru.
  ///
  /// ## [saatTerbaru] — buat keadaan yang bukan `state`
  ///
  /// `state` bukan satu-satunya yang dibawa pulang sebuah permintaan. Daftar
  /// yang dipaginasi juga membawa nomor halaman terakhirnya, dan itu disimpan
  /// di field notifier-nya, bukan di `state`.
  ///
  /// Field seperti itu **lolos dari penjagaan ini** kalau dipasang di dalam
  /// [muat]: yang dijaga cuma pemasangan `state` di bawah, sementara field-nya
  /// sudah tertulis sebelum penjaganya sempat menolak. Pencarian lama yang
  /// pulang belakangan lalu meninggalkan `lastPage` milik kata kunci yang sudah
  /// tidak ada di kotaknya — dan "muat lebih banyak" berikutnya meminta halaman
  /// yang bukan miliknya.
  ///
  /// Jadi keadaan semacam itu dipasang di sini, di sisi yang sama dengan
  /// `state`, dan ikut dibuang bersamanya.
  Future<void> muatDenganPenjaga(
    Future<T> Function() muat, {
    void Function()? saatTerbaru,
  }) async {
    final nomor = mulaiPermintaan();
    state = const AsyncValue.loading();

    final hasil = await AsyncValue.guard(muat);

    // Balasan yang ketinggalan dibuang di sini — termasuk kalau dia error.
    // Error dari permintaan lama sama menyesatkannya dengan datanya: layar
    // merah untuk pencarian yang sudah tidak ada di kotaknya.
    if (!masihTerbaru(nomor)) return;

    // Sebelum `state`, supaya tidak pernah ada satu frame pun yang menampilkan
    // daftar baru berikut metadata halaman yang lama.
    saatTerbaru?.call();

    state = hasil;
  }
}
