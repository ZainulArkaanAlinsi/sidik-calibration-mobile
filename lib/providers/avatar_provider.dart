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

  @override
  String? build() {
    // `ref.watch`, bukan `ref.read`. Yang dibeli bukan kebenaran datanya —
    // yang dibeli ALASAN untuk mengambil ulang. Tanpa dependensi ke
    // `authProvider`, provider yang sudah punya nilai nggak punya sebab apa pun
    // buat membuangnya waktu akunnya ganti.
    final pengguna = ref.watch(authProvider).value;
    _idPengguna = pengguna?.id;

    _muat(_idPengguna);

    return null;
  }

  String _kunci(int idPengguna) => '$_awalanAvatar$idPengguna';

  Future<void> _muat(int? idPengguna) async {
    if (idPengguna == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kunci(idPengguna));

      // Akunnya keburu ganti selagi baca disk. Tanpa penjagaan ini, foto orang
      // sebelumnya masih bisa mendarat di layar orang yang sekarang lewat
      // pembacaan yang telat selesai — kebocoran yang sama, cuma lewat waktu.
      if (idPengguna != _idPengguna) return;

      if (path != null && path.isNotEmpty) state = path;
    } catch (_) {
      // Plugin nggak ada / gagal baca → biarin null.
    }
  }

  Future<void> setPath(String? path) async {
    final idPengguna = _idPengguna;

    state = (path != null && path.isNotEmpty) ? path : null;

    // Belum login berarti nggak ada laci yang boleh ditulis. Menyimpannya ke
    // laci bersama bikin foto itu muncul di layar siapa pun yang login
    // berikutnya — persis yang dicegah berkas ini.
    if (idPengguna == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (state == null) {
        await prefs.remove(_kunci(idPengguna));
      } else {
        await prefs.setString(_kunci(idPengguna), state!);
      }
    } catch (_) {
      // Gagal nyimpen bukan alasan buat nggak ganti foto di sesi ini.
    }
  }
}
