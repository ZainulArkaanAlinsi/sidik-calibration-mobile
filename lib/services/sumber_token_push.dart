/// Dari mana token push perangkat ini didapat.
///
/// **Sengaja antarmuka yang sekarang kosong isinya.** Satu-satunya sumber yang
/// nyata nanti Firebase Cloud Messaging, dan paketnya (`firebase_messaging`)
/// nggak bisa dipasang sebelum `android/app/google-services.json` ada: plugin
/// Gradle-nya bikin `flutter build apk` GAGAL kalau berkas itu nggak ketemu.
/// Jadi kalau paketnya ditambah duluan, ada jendela waktu di mana aplikasinya
/// nggak bisa dibangun sama sekali — dan itu ongkos yang nggak perlu dibayar
/// cuma buat menunggu satu berkas.
///
/// Dengan dipisah begini, seluruh jalur pendaftarannya — endpoint, penyimpanan
/// token, pencabutan waktu logout — bisa ditulis, diuji, dan digabung sekarang.
/// Yang tersisa nanti cuma menukar satu implementasi.
abstract class SumberTokenPush {
  /// Token perangkat ini, atau `null` kalau memang belum ada.
  ///
  /// `null` BUKAN error: pengguna boleh menolak izin notifikasi, dan desktop
  /// nggak punya token push sama sekali (di situ kabarnya lewat websocket
  /// Reverb, yang justru nggak butuh layanan pihak ketiga).
  Future<String?> token();

  /// Token yang diganti layanan push di tengah jalan.
  ///
  /// FCM merotasi token tanpa diminta — aplikasi dipasang ulang, data aplikasi
  /// dihapus, atau token dianggap basi. Kalau yang baru nggak didaftarkan
  /// ulang, notifikasinya berhenti masuk dan nggak ada satu pun error yang
  /// muncul: dari sisi server, token lamanya masih terlihat sah sampai ada
  /// yang mencoba mengirim ke situ.
  Stream<String> tokenBerubah();
}

/// Sumber kosong — dipakai selama Firebase belum dipasang, dan selamanya di
/// desktop.
///
/// Bukan penambal sementara yang bakal dibuang: panel admin desktop memang
/// nggak pernah punya token push, dan di situ kabar realtime-nya sudah sampai
/// lewat Reverb.
class TanpaTokenPush implements SumberTokenPush {
  const TanpaTokenPush();

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> tokenBerubah() => const Stream.empty();
}
