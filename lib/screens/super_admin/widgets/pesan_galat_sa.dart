import '../../../l10n/app_localizations.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../services/auth_service.dart' show ApiException, AuthException;
import '../../../services/kode_galat.dart' show kodeDariBadan;

/// Kode galat bisnis server untuk pengelolaan pengguna & anggota (kontrak
/// `docs/perintah-frontend-super-admin.md` §3.3 dan §4.4). Percabangan UI
/// memakai KODE, bukan isi `message` — teksnya boleh berubah di server.
abstract final class KodeSa {
  static const picUtamaTerakhir = 'pic_utama_terakhir';
  static const sudahNonaktif = 'sudah_nonaktif';
  static const sudahAktif = 'sudah_aktif';
  static const perluPersetujuan = 'perlu_persetujuan';
  static const alatSudahPindah = 'alat_sudah_pindah';
  static const alatBukanMilikPtAsal = 'alat_bukan_milik_pt_asal';
  static const ptTujuanSama = 'pt_tujuan_sama';
}

/// Kalimat untuk galat apa pun dari aksi pengelolaan.
///
/// - Kode bisnis yang dikenal → kalimat lokal yang menyebut jalan keluarnya.
/// - `404` → "mungkin sudah berubah" (server menjawab 404 untuk milik lab lain
///   juga; layar tidak membedakannya).
/// - Lainnya: pesan server apa adanya (sudah manusiawi lewat `ApiClient`),
///   atau kalimat umum bila bukan galat server.
///
/// [untukAnggota] membedakan `sudah_nonaktif` milik anggota pelanggan dari
/// milik akun lab.
String pesanGalatSa(
  AppLocalizations l10n,
  Object galat, {
  bool untukAnggota = false,
}) {
  if (galat is TokenHilangException) return l10n.historySessionExpired;

  if (galat is ApiException) {
    final kode = kodeDariBadan(galat.body);
    switch (kode) {
      case KodeSa.picUtamaTerakhir:
        return l10n.saGalatPicTerakhir;
      case KodeSa.sudahNonaktif:
        return untukAnggota
            ? l10n.saGalatSudahNonaktifAnggota
            : l10n.saGalatSudahNonaktif;
      case KodeSa.sudahAktif:
        return l10n.saGalatSudahAktif;
      case KodeSa.perluPersetujuan:
        return l10n.saGalatPerluPersetujuan;
      case KodeSa.alatSudahPindah:
        return l10n.saGalatAlatSudahPindah;
      case KodeSa.alatBukanMilikPtAsal:
        return l10n.saGalatAlatBukanMilik;
      case KodeSa.ptTujuanSama:
        return l10n.saGalatPtSama;
    }
    if (galat.status == 404) return l10n.saGalatTidakAda;
    return galat.message;
  }

  if (galat is AuthException && galat.message.isNotEmpty) return galat.message;
  return l10n.saGalatUmum;
}

/// Galat yang artinya daftar di layar sudah basi dan perlu diambil ulang:
/// baris sudah hilang (404) atau sudah di keadaan yang diminta.
bool perluMuatUlang(Object galat) {
  if (galat is! ApiException) return false;
  if (galat.status == 404) return true;
  final kode = kodeDariBadan(galat.body);
  return kode == KodeSa.sudahNonaktif ||
      kode == KodeSa.sudahAktif ||
      kode == KodeSa.alatSudahPindah ||
      kode == KodeSa.alatBukanMilikPtAsal;
}

/// Pesan pertama kolom [kunci] dari badan 422 Laravel
/// (`errors.<kolom>[0]`), atau `null`.
String? pesanKolomServer(ApiException e, String kunci) {
  final errors = e.body['errors'];
  if (errors is! Map) return null;
  final nilai = errors[kunci];
  if (nilai is List && nilai.isNotEmpty) return '${nilai.first}';
  if (nilai is String && nilai.isNotEmpty) return nilai;
  return null;
}
