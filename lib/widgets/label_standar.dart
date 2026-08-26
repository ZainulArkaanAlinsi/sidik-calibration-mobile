import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/standard.dart';

/// Isi satu `DropdownMenuItem` standar: nama alat, plus **peringatan
/// kadaluarsa di barisnya sendiri** kalau sertifikatnya lewat.
///
/// ## Kenapa peringatannya nggak boleh nempel di nama
///
/// Dulu ketiga dropdown standar merangkainya jadi satu baris:
///
///     '${s.nama} (${l10n.lkStandarKadaluarsa})'
///
/// Satu baris itu **selalu** kepotong di lembar Refractometer & Gas Detector.
/// Diukur di menu yang benar-benar terbuka: tersedia 772 dp, teks minta 953 —
/// dan yang jatuh di luar 772 justru buntutnya, yaitu peringatannya. Yang
/// dibaca teknisi:
///
///     Temperature Calibrator Constant 40T (sertifik…
///
/// Nama kalibratornya lengkap, peringatannya hilang. Nol error, nol pita
/// kuning-hitam — cuma satu keterangan yang diam-diam nggak pernah sampai.
///
/// Memendekkan tulisannya nggak menyelesaikan: `Temperature Calibrator
/// Yokogawa CA 150 Handy Cal` minta 775 dp **tanpa embel-embel apa pun**.
/// Namanya sendiri sudah mepet, jadi apa pun yang ditempel di belakangnya
/// bakal jadi yang pertama dibuang.
///
/// Baris kedua kebal terhadap itu: panjangnya nggak ikut panjang nama, dan
/// warnanya `colorScheme.error` — sama persis dengan cara baris standar di
/// bagian STANDARD lembar kerja sudah menampilkannya sejak dulu. Jadi ini
/// menyeragamkan ke pola yang sudah ada, bukan bikin pola baru.
///
/// ## Kenapa tombolnya tetap satu baris
///
/// Item ini cuma dipakai di DAFTAR yang terbuka. Tombol tertutupnya dikasih
/// [namaSaja] lewat `selectedItemBuilder`, karena `DropdownButton` mengukur
/// tinggi tombol dari item TERTINGGI — tanpa itu, tiap dropdown yang daftarnya
/// memuat satu standar kadaluarsa ikut tinggi walau yang kepilih standar yang
/// masih berlaku, dan tata letak empat belas lembar lain ikut bergeser.
///
/// Aman juga karena standar kadaluarsa `enabled: false`: dia nggak pernah bisa
/// jadi isi tombol.
class LabelStandarDropdown extends StatelessWidget {
  const LabelStandarDropdown({super.key, required this.standard, this.gaya});

  final Standard standard;

  /// Gaya nama alat. Null = ikut `DefaultTextStyle` dropdown-nya.
  ///
  /// Ada karena dropdown thermohygro di panel admin sengaja lebih kecil
  /// (`fontSize: 13`) — kalau baris peringatannya ikut ukuran bawaan, dia
  /// malah lebih besar dari nama yang diterangkannya.
  final TextStyle? gaya;

  /// Isi tombol TERTUTUP: nama saja, satu baris.
  ///
  /// Dipakai sebagai `selectedItemBuilder` supaya tinggi tombolnya nggak ikut
  /// tumbuh gara-gara item kadaluarsa di daftarnya. Lihat catatan kelas.
  static Widget namaSaja(Standard standard, {TextStyle? gaya}) => Text(
    standard.nama,
    style: gaya,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) {
    // DUA baris, beda dari [namaSaja] yang cuma satu.
    //
    // `Temperature Calibrator Yokogawa CA 150 Handy Cal` minta 775 dp di kolom
    // selebar 772 — lebih panjang tiga piksel, dan cukup buat memakan huruf
    // terakhirnya. Dibatasi satu baris di daftar juga, nama itu nggak pernah
    // kebaca utuh DI MANA PUN: tombolnya memang satu baris, dan daftarnya
    // dulu ikut satu baris.
    //
    // Aman ke golden: yang melar cuma baris menu, dan menu itu overlay yang
    // cuma ada waktu dropdown-nya lagi dibuka. Tinggi tombol tertutupnya tetap
    // diukur dari [namaSaja] lewat `selectedItemBuilder`.
    final nama = Text(
      standard.nama,
      style: gaya,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (standard.masihBerlaku) return nama;

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nama,
        Text(
          AppLocalizations.of(context).lkStandarKadaluarsa,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
