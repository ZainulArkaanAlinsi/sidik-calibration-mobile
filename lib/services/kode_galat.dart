import 'auth_service.dart' show ApiException;

/// Kode galat 422 dari server yang punya penanganan khusus di app.
///
/// Server menaruhnya di kunci `kode` (`CalibrationController::approve`,
/// `PengesahanController::sahkan`). `code` ikut dibaca supaya kontrak yang
/// ditulis dalam bahasa Inggris tidak diam-diam jatuh ke pesan generik.
abstract final class KodeGalat {
  /// Yang mengisi atau mengoreksi sesi tidak boleh menyetujui/mengesahkannya
  /// sendiri (K-30-03). Berlaku juga untuk super admin — tanpa pengecualian.
  static const pemisahanWewenang = 'pemisahan_wewenang';

  /// Approve ditolak karena Order Number sesi masih kosong (K-49-14).
  static const nomorOrderWajib = 'nomor_order_wajib';

  /// Approve ditolak: No. Sertifikat kosong / tidak valid / sudah dipakai
  /// sertifikat lain di lab ini (K-50-04). Status sesi tidak berubah.
  static const nomorSertifikatWajib = 'nomor_sertifikat_wajib';
  static const nomorSertifikatTidakValid = 'nomor_sertifikat_tidak_valid';
  static const nomorSertifikatDipakai = 'nomor_sertifikat_dipakai';

  /// Tarik sertifikat: sandi akun yang menarik salah.
  static const konfirmasiSandiSalah = 'konfirmasi_sandi_salah';
}

/// `kode` dari badan respons galat server; `null` kalau tidak ada.
String? kodeDariBadan(Map<String, dynamic> body) {
  final kode = body['kode'] ?? body['code'];
  return kode is String && kode.isNotEmpty ? kode : null;
}

/// `kode` dari galat apa pun — `null` kalau bukan [ApiException].
String? kodeGalatApi(Object galat) =>
    galat is ApiException ? kodeDariBadan(galat.body) : null;
