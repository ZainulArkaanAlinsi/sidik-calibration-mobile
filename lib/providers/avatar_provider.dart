import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_provider.dart';

/// Path foto profil yang dipilih user dari galeri/kamera HP-nya sendiri.
///
/// Disimpan **lokal per perangkat** (belum diunggah ke backend di fase ini) dan
/// dipersist lewat `SharedPreferences` biar nggak ilang tiap app dibuka. Null =
/// belum milih → UI nampilin inisial nama. Kalau plugin storage nggak ada
/// (mis. di widget test), semua akses ditelan diam-diam dan state tetap null.
///
/// **Key-nya di-scope per `user.id`.** Sebelumnya cuma satu key global
/// (`avatar_path`) buat semua akun — di HP yang dipakai gantian, semua orang
/// yang login jadi lihat & bisa timpa foto orang lain. `build()` nge-`watch`
/// [authProvider], jadi tiap ganti akun (login/logout/switch) state otomatis
/// direset dulu ke null lalu dimuat ulang dari key milik akun yang aktif.
final avatarPathProvider = NotifierProvider<AvatarNotifier, String?>(
  AvatarNotifier.new,
);

class AvatarNotifier extends Notifier<String?> {
  static const _keyPrefix = 'avatar_path_';

  int? _userId;

  @override
  String? build() {
    final userId = ref.watch(authProvider).value?.id;
    _userId = userId;
    if (userId != null) _muat(userId);
    return null;
  }

  Future<void> _muat(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('$_keyPrefix$userId');
      // User udah ganti (mis. logout cepat) sebelum baca ini kelar → jangan
      // nimpa state akun yang sekarang aktif dengan punya akun yang lama.
      if (_userId != userId) return;
      if (path != null && path.isNotEmpty) state = path;
    } catch (_) {
      // Plugin nggak ada / gagal baca → biarin null.
    }
  }

  Future<void> setPath(String? path) async {
    final userId = _userId;
    if (userId == null) return; // Nggak ada akun aktif → nggak ada yang disimpan.

    state = (path != null && path.isNotEmpty) ? path : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$userId';
      if (state == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, state!);
      }
    } catch (_) {
      // Gagal nyimpen bukan alasan buat nggak ganti foto di sesi ini.
    }
  }
}
