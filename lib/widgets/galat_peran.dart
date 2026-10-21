import '../l10n/app_localizations.dart';
import '../services/kode_galat.dart';

/// Kalimat jelas untuk kode galat peran yang dikenali; `null` untuk kode lain
/// (pemanggil memakai pesan server apa adanya).
///
/// Pesan server untuk `pemisahan_wewenang` ditulis buat admin ("Minta Master
/// Data lain"), padahal sejak K-49-14 yang paling sering menabraknya super
/// admin yang baru saja mengisi lembar sendiri. Kalimat di sini netral peran
/// dan menyebut jalan keluarnya: orang LAIN yang menyetujui.
///
/// [pemilikNomor] = nomor sertifikat yang memegang nomor bentrok
/// (`sertifikat.nomor` di badan 422 `nomor_sertifikat_dipakai`).
String? pesanGalatPeran(
  AppLocalizations l10n,
  String? kode, {
  String? pemilikNomor,
}) => switch (kode) {
  KodeGalat.pemisahanWewenang => l10n.galatPemisahanWewenang,
  KodeGalat.nomorOrderWajib => l10n.galatNomorOrderWajib,
  KodeGalat.nomorSertifikatWajib => l10n.galatNomorSertifikatWajib,
  KodeGalat.nomorSertifikatTidakValid => l10n.galatNomorSertifikatTidakValid,
  KodeGalat.nomorSertifikatDipakai =>
    pemilikNomor == null
        ? l10n.galatNomorSertifikatDipakaiLain
        : l10n.galatNomorSertifikatDipakai(pemilikNomor),
  KodeGalat.konfirmasiSandiSalah => l10n.galatKonfirmasiSandiSalah,
  _ => null,
};

/// Kode yang dijawab dengan membuka dialog Setujui lagi (isian dipertahankan,
/// pesan tampil di kotaknya) — bukan snackbar.
bool kodeIsianSetujui(String? kode) =>
    kode == KodeGalat.nomorOrderWajib ||
    kode == KodeGalat.nomorSertifikatWajib ||
    kode == KodeGalat.nomorSertifikatTidakValid ||
    kode == KodeGalat.nomorSertifikatDipakai;

/// [pesanGalatPeran] langsung dari objek galat, jatuh ke [cadangan].
String pesanGalatAksi(
  AppLocalizations l10n,
  Object galat, {
  required String cadangan,
}) => pesanGalatPeran(l10n, kodeGalatApi(galat)) ?? cadangan;
