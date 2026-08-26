import '../core/utils/angka.dart';

/// Aturan penggabungan hasil pindai ke isian yang udah ada di form.
///
/// Ini **aturan paling berbahaya** di seluruh alur foto: teknisi boleh memindai
/// berkali-kali buat nambal sel yang kurang, dan angka yang udah dia betulin
/// manual nggak boleh keganti sama pindai berikutnya. Kalau ketimpa, koreksinya
/// ilang tanpa jejak — dan yang masuk sertifikat justru angka mesin yang tadi
/// salah.
///
/// Dulu tinggal di `worksheet_vision.dart`. Jalur AI Vision cloud-nya dicabut,
/// tapi aturan ini nggak ikut mati: yang butuh justru sama. DUA jalur kamera
/// yang tersisa — `PINDAI LEMBAR KERJA` (OCR template lokal) dan `FOTO TABEL
/// INI` (ML Kit di perangkat) — sama-sama nuangin angka mesin ke kotak yang
/// mungkin udah diisi tangan, dan sama-sama lewat sini
/// (`lembar_kerja_state.dart`).
class GabungTabel {
  const GabungTabel._();

  /// Nilai baru buat satu sel, atau `null` kalau sel itu nggak boleh diubah.
  /// Sel dianggap kosong kalau isinya spasi doang.
  ///
  /// [desimal] = resolusi titiknya (Turbidimeter: 2/1/0). Kalau diisi,
  /// pembacaan dipad ke situ tanpa buang nol belakang — hasil pindai `4.6` di
  /// titik ber-resolusi 0,01 masuk sebagai `4,60`. `null` = alat resolusi
  /// seragam, pakai perilaku lama (buang nol belakang).
  static String? nilaiBaru(String sekarang, double? hasil, {int? desimal}) {
    if (hasil == null) return null;
    if (sekarang.trim().isNotEmpty) return null;
    // Dua jalurnya sama-sama pakai KOMA. `formatNilai` sengaja nggak diubah
    // global — dia kepakai juga di tabel Perhitungan & sertifikat, dan itu
    // urusan terpisah. Yang diseragamin cuma isian lembar kerja.
    return desimal != null
        ? formatNilai(hasil, desimalMin: desimal).replaceAll('.', ',')
        : _rapi(hasil);
  }

  /// Versi teks buat kolom non-tabel (catatan, lokasi, env condition).
  /// Aturannya **sama persis**: kolom yang udah ada isinya nggak pernah
  /// ditimpa, biar koreksi manual teknisi selamat dari pindai berikutnya.
  static String? nilaiBaruTeks(String sekarang, String? hasil) {
    if (hasil == null || hasil.trim().isEmpty) return null;
    if (sekarang.trim().isNotEmpty) return null;
    return hasil.trim();
  }

  /// Buang nol di belakang: `4.0` → `4`, `22.2` tetap `22.2`, `10.11` tetap
  /// `10.11`. Bukan dibulatkan ke desimal tetap — pH 2 desimal, suhu 1 desimal.
  /// **8 desimal, dan komanya dipertahankan.**
  ///
  /// *8, bukan 3.* Dulu `toStringAsFixed(3)`, dan itu MEMBUANG digit: hasil
  /// baca `1,3362` dari lembar Refractometer mendarat di kotak `1,336`. Teknisi
  /// lihat angkanya "kurang" tanpa ada yang error — pembacaan resolusi 0,0001
  /// dipotong jadi 0,001, sepuluh kali lebih kasar dari alatnya. Tiga alat
  /// pertama selamat cuma karena kebetulan (paling halus 0,01).
  ///
  /// Angka 8 disamain sama `formatNilai` (`desimalMaks: 8`) dan kolom DB
  /// `decimal(20,8)` — batas presisi yang sama di seluruh sistem.
  ///
  /// *Desimalnya KOMA*, ngikut lembar kerjanya sendiri (titik ukur ditulis
  /// `1,74`) dan formulir kertasnya. Tanpa ini, di satu tabel yang sama label
  /// barisnya berkoma tapi isian yang dituangin mesin bertitik — kelihatan
  /// kayak dua sumber angka yang beda. Kotaknya sendiri nerima dua-duanya
  /// (`parseAngka`), jadi ini murni biar kebacanya seragam.
  ///
  /// Nol di belakang tetap dibuang, jadi `25,0` tetap `25` dan derau float
  /// (`0.30000000000000004`) tetap jadi `0,3`.
  static String _rapi(double nilai) => nilai
      .toStringAsFixed(8)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
}
