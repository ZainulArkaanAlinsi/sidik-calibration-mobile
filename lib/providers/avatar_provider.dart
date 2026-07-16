import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Path foto profil yang dipilih user dari galeri/kamera HP-nya sendiri.
///
/// Disimpan **lokal per perangkat** (belum diunggah ke backend di fase ini) dan
/// dipersist lewat `SharedPreferences` biar nggak ilang tiap app dibuka. Null =
/// belum milih → UI nampilin inisial nama. Kalau plugin storage nggak ada
/// (mis. di widget test), semua akses ditelan diam-diam dan state tetap null.
final avatarPathProvider = NotifierProvider<AvatarNotifier, String?>(
  AvatarNotifier.new,
);

class AvatarNotifier extends Notifier<String?> {
  static const _key = 'avatar_path';

  @override
  String? build() {
    _muat();
    return null;
  }

  Future<void> _muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_key);
      if (path != null && path.isNotEmpty) state = path;
    } catch (_) {
      // Plugin nggak ada / gagal baca → biarin null.
    }
  }

  Future<void> setPath(String? path) async {
    state = (path != null && path.isNotEmpty) ? path : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, state!);
      }
    } catch (_) {
      // Gagal nyimpen bukan alasan buat nggak ganti foto di sesi ini.
    }
  }
}
