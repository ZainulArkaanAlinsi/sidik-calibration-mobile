import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

/// Awalan kunci foto profil di `SharedPreferences` — **satu laci per ORANG**.
///
/// Versi ikut di kunci, sama alasannya dengan `SimpananPelanggan`: bentuk
/// datanya berubah → laci lama ditinggal, bukan dibaca setengah-setengah.
///
/// Per ORANG, bukan per organisasi. Itu bedanya dari `SimpananPelanggan`, dan
/// bukan detail: daftar pelanggan memang milik satu lab, tapi foto profil milik
/// satu manusia. Dua teknisi di lab yang SAMA punya `organization_id` yang sama
/// — kunci berbasis organisasi bakal tetap menyodorkan foto orang pertama ke
/// layar orang kedua.
const _awalanAvatar = 'avatar.v1.';

/// Kunci LAMA yang global, dari sebelum foto profil dipisah per orang.
///
/// **Tidak pernah dibaca lagi, dan sengaja tidak dipindahkan** ke laci pemilik
/// barunya. Memindahkannya berarti menebak siapa pemilik foto itu — dan tebakan
/// yang paling mungkin (orang yang login pertama sesudah pembaruan) justru
/// persis kebocoran yang berkas ini tutup: foto orang sebelumnya terpasang
/// sebagai identitas orang berikutnya.
///
/// Jadi fotonya ditinggalkan, dan pemiliknya memilih ulang sekali. Kuncinya
/// sendiri ikut disapu [sapuKunciAvatarLama] di logout berikutnya.
const _kunciAvatarLama = 'avatar_path';

/// Sapu kunci avatar global yang lama — **cuma yang lama.**
///
/// ## Kenapa laci per-orang TIDAK ikut dibuang
///
/// `SimpananPelanggan` membuang isinya di logout, dan di sana itu gratis: dia
/// cache daftar pelanggan yang bisa diambil ulang dari server kapan saja.
///
/// Foto profil beda. Dia **nggak punya salinan di server** — belum diunggah di
/// fase ini, jadi yang di HP itu satu-satunya. Membuangnya tiap logout berarti
/// teknisi kehilangan fotonya PERMANEN tiap ganti shift, dan itu menukar satu
/// bug dengan bug lain.
///
/// Kebocorannya sendiri sudah ditutup lapis pertama: laci si A (`avatar.v1.1`)
/// bukan laci yang dibaca si B (`avatar.v1.2`), jadi nggak ada jalan foto A
/// nyampe ke layar B. Aturannya memang "kunci memuat identitas akun **ATAU**
/// isinya dibuang di logout" — bukan dua-duanya wajib.
///
/// Yang tersisa buat disapu tinggal kunci global lama, dan itu sekali seumur
/// pemasangan.
Future<void> sapuKunciAvatarLama() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kunciAvatarLama);
}

/// Path foto profil yang dipilih user dari galeri/kamera HP-nya sendiri.
///
/// Disimpan **lokal per perangkat** (belum diunggah ke backend di fase ini) dan
/// dipersist lewat `SharedPreferences` biar nggak ilang tiap app dibuka. Null =
/// belum milih → UI nampilin inisial nama. Kalau plugin storage nggak ada
/// (mis. di widget test), semua akses ditelan diam-diam dan state tetap null.
///
/// ## Kenapa dia menyentuh `authProvider`
///
/// Yang tersimpan di `SharedPreferences` **tidak ikut auto-dispose sama
/// sekali**: dia bertahan melewati logout, melewati aplikasi ditutup, melewati
/// HP dimatikan. Jadi jaring auto-dispose Riverpod 3 yang melindungi provider
/// data lain tidak berlaku di sini — provider boleh lahir ulang, `build()`-nya
/// tetap membaca disk yang sama.
///
/// Satu APK dipakai teknisi dan admin, dan HP lab dipakai gantian. Tanpa
/// penjagaan ini: Teknisi A pasang foto → logout → Teknisi B login → foto A
/// terpasang sebagai identitas B, bersebelahan dengan nama dan email B.
final avatarPathProvider = NotifierProvider<AvatarNotifier, String?>(
  AvatarNotifier.new,
);

class AvatarNotifier extends Notifier<String?> {
  /// Pemilik laci yang sedang dibaca/ditulis. Null = belum login.
  int? _idPengguna;

  /// Nomor perpindahan keadaan terakhir. Naik tiap kali ADA yang menentukan
  /// foto mana yang berlaku — `build()` maupun [setPath].
  ///
  /// Identitas akun saja tidak cukup buat menjaganya. Bacaan disk yang telat
  /// selesai masih milik akun yang SAMA, jadi penjagaan `idPengguna` melewatkan
  /// urutan ini: teknisi memilih foto baru selagi bacaan awal masih di jalan →
  /// bacaan itu pulang membawa path LAMA → foto yang barusan dipilih terganti
  /// sendiri di layar, tanpa ada yang menyentuh apa pun.
  ///
  /// Yang tersimpan di disk tetap yang baru, dan itu justru yang bikin gejalanya
  /// membingungkan: fotonya balik lagi sesudah aplikasi dibuka ulang.
  int _generasi = 0;

  /// Antrean tulis ke disk — satu rantai, dijalankan menurut urutan panggilan.
  ///
  /// `SharedPreferences.setString`/`remove` itu dua panggilan async terpisah.
  /// Dua [setPath] yang tumpang tindih bikin dua-duanya melayang bersamaan, dan
  /// yang SELESAI belakangan yang menang — belum tentu yang DIPANGGIL
  /// belakangan. Hasilnya kunci per-orang menyimpan pilihan yang sudah
  /// ditinggalkan, sementara layarnya menampilkan yang benar.
  Future<void> _antreanTulis = Future<void>.value();

  @override
  String? build() {
    // `ref.watch`, bukan `ref.read`. Yang dibeli bukan kebenaran datanya —
    // yang dibeli ALASAN untuk mengambil ulang. Tanpa dependensi ke
    // `authProvider`, provider yang sudah punya nilai nggak punya sebab apa pun
    // buat membuangnya waktu akunnya ganti.
    final pengguna = ref.watch(authProvider).value;
    _idPengguna = pengguna?.id;

    _muat(_idPengguna, ++_generasi);

    return null;
  }

  String _kunci(int idPengguna) => '$_awalanAvatar$idPengguna';

  Future<void> _muat(int? idPengguna, int generasi) async {
    if (idPengguna == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kunci(idPengguna));

      // DUA syarat, dan keduanya perlu:
      //
      //  - akun berubah  → foto orang sebelumnya mendarat di layar orang
      //    sekarang lewat bacaan yang telat selesai;
      //  - generasi berubah, akun tetap → pilihan yang lebih baru ketimpa
      //    bacaan disk yang lebih tua.
      if (idPengguna != _idPengguna || generasi != _generasi) return;

      if (path != null && path.isNotEmpty) state = path;
    } catch (_) {
      // Plugin nggak ada / gagal baca → biarin null.
    }
  }

  Future<void> setPath(String? path) async {
    final idPengguna = _idPengguna;
    final nilai = (path != null && path.isNotEmpty) ? path : null;

    _generasi++;
    state = nilai;

    // Belum login berarti nggak ada laci yang boleh ditulis. Menyimpannya ke
    // laci bersama bikin foto itu muncul di layar siapa pun yang login
    // berikutnya — persis yang dicegah berkas ini.
    if (idPengguna == null) return;

    // `nilai` yang DITANGKAP di sini, bukan `state` yang dibaca nanti. Bedanya
    // kelihatan waktu akunnya keluar selagi simpanan masih di jalan: `build()`
    // memulangkan state ke null, dan tulisan yang membaca `state` belakangan
    // bakal MENGHAPUS foto pemilik laci ini — bukan menyimpannya.
    _antreanTulis = _antreanTulis.then((_) => _tulis(idPengguna, nilai));

    await _antreanTulis;
  }

  /// Nggak pernah melempar: kegagalan menyimpan bukan alasan buat memutus
  /// antreannya, dan rantai [_antreanTulis] cuma jalan terus kalau tiap
  /// mata rantainya selesai normal.
  Future<void> _tulis(int idPengguna, String? nilai) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (nilai == null) {
        await prefs.remove(_kunci(idPengguna));
      } else {
        await prefs.setString(_kunci(idPengguna), nilai);
      }
    } catch (_) {
      // Gagal nyimpen bukan alasan buat nggak ganti foto di sesi ini.
    }
  }
}
