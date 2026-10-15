import '../l10n/app_localizations.dart';
import '../services/kode_galat.dart';

/// Kalimat jelas untuk kode galat peran yang dikenali; `null` untuk kode lain
/// (pemanggil memakai pesan server apa adanya).
///
/// Pesan server untuk `pemisahan_wewenang` ditulis buat admin ("Minta Master
/// Data lain"), padahal sejak K-49-14 yang paling sering menabraknya super
/// admin yang baru saja mengisi lembar sendiri. Kalimat di sini netral peran
/// dan menyebut jalan keluarnya: orang LAIN yang menyetujui/mengesahkan.
String? pesanGalatPeran(AppLocalizations l10n, String? kode) => switch (kode) {
  KodeGalat.pemisahanWewenang => l10n.galatPemisahanWewenang,
  KodeGalat.nomorOrderWajib => l10n.galatNomorOrderWajib,
  _ => null,
};

/// [pesanGalatPeran] langsung dari objek galat, jatuh ke [cadangan].
String pesanGalatAksi(
  AppLocalizations l10n,
  Object galat, {
  required String cadangan,
}) => pesanGalatPeran(l10n, kodeGalatApi(galat)) ?? cadangan;
