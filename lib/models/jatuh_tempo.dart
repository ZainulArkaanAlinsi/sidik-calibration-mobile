import 'equipment.dart';

/// Satu alat beserta jaraknya ke tanggal jatuh tempo — bahan layar "Jatuh
/// tempo" dan "Jadwal kalibrasi ulang".
class AlatJatuhTempo {
  const AlatJatuhTempo({required this.alat, required this.hari});

  final Equipment alat;

  /// Selisih hari kalender dari HARI INI ke tanggal jatuh tempo. Negatif =
  /// sudah lewat, `0` = jatuh tempo hari ini. `null` = server menandai alat
  /// ini `overdue` tapi tanggalnya tidak terkirim; jumlah harinya tidak boleh
  /// ditebak, jadi layar cuma menulis "lewat jadwal" tanpa angka.
  final int? hari;

  bool get lewat => hari == null || hari! < 0;
}

/// Ringkasan jatuh tempo se-lab, dikelompokkan di sisi aplikasi dari daftar
/// alat yang sudah dimuat.
///
/// ## Kenapa dikelompokkan di sini
///
/// Server sudah menyaring dan mengurutkan (`jatuh_tempo_dalam`,
/// `termasuk_lewat`, `urut=jatuh_tempo`), jadi yang ditarik cuma alat yang
/// relevan. Yang TETAP dikerjakan di sini adalah memotong menjadi lewat / 30 /
/// 90 hari, karena "hari ini" milik `jamProvider` (bisa dipatok di test & golden)
/// dan bukan milik server — dan alat berstatus `overdue` tanpa tanggal perlu
/// dibedakan dari yang tanggalnya diketahui.
class RingkasanJatuhTempo {
  const RingkasanJatuhTempo({
    this.lewat = const [],
    this.dalam30 = const [],
    this.dalam90 = const [],
  });

  /// Sudah lewat, PALING LAMA dulu (yang tanggalnya tidak diketahui paling
  /// bawah).
  final List<AlatJatuhTempo> lewat;

  /// 0–30 hari ke depan, yang paling dekat dulu.
  final List<AlatJatuhTempo> dalam30;

  /// 0–90 hari ke depan — SUDAH memuat [dalam30] (rentang bertingkat, sama
  /// seperti chip "30 hari / 90 hari" di desain).
  final List<AlatJatuhTempo> dalam90;

  bool get kosong => lewat.isEmpty && dalam90.isEmpty;

  /// Berapa hari alat yang paling lama lewat sudah terlambat; `null` kalau
  /// tidak ada yang lewat atau tanggalnya tidak diketahui.
  int? get terlamaLewatHari {
    for (final a in lewat) {
      if (a.hari != null) return -a.hari!;
    }
    return null;
  }
}

/// Kelompokkan [alat] terhadap [hariIni]. Fungsi murni supaya bisa diuji tanpa
/// widget dan tanpa jaringan.
///
/// Hanya jam-menit yang dibuang: yang dibandingkan TANGGAL kalender, karena
/// alat yang jatuh tempo hari ini belum lewat sampai tengah malam.
RingkasanJatuhTempo susunJatuhTempo(
  Iterable<Equipment> alat,
  DateTime hariIni,
) {
  final hariPatokan = DateTime.utc(hariIni.year, hariIni.month, hariIni.day);
  final lewat = <AlatJatuhTempo>[];
  final ke90 = <AlatJatuhTempo>[];
  final terlihat = <int>{};

  for (final a in alat) {
    // Alat nonaktif tidak ikut dijadwalkan; dan daftar yang datang dari dua
    // permintaan (overdue + aktif) bisa memuat id yang sama dua kali.
    if (a.status == EquipmentStatus.nonaktif || !terlihat.add(a.id)) continue;

    final tempo = a.tanggalJatuhTempo;
    final int? hari = tempo == null
        ? null
        : DateTime.utc(
            tempo.year,
            tempo.month,
            tempo.day,
          ).difference(hariPatokan).inDays;

    if (a.status == EquipmentStatus.overdue || (hari != null && hari < 0)) {
      lewat.add(AlatJatuhTempo(alat: a, hari: hari));
    } else if (hari != null && hari <= 90) {
      ke90.add(AlatJatuhTempo(alat: a, hari: hari));
    }
  }

  // Tanggal tidak diketahui ke dasar; sisanya menurut tanggal (paling lama
  // lewat = angka paling negatif = paling atas).
  int urut(AlatJatuhTempo x, AlatJatuhTempo y) {
    if (x.hari == null && y.hari == null) return 0;
    if (x.hari == null) return 1;
    if (y.hari == null) return -1;
    return x.hari!.compareTo(y.hari!);
  }

  lewat.sort(urut);
  ke90.sort(urut);

  return RingkasanJatuhTempo(
    lewat: lewat,
    dalam30: ke90.where((a) => a.hari! <= 30).toList(),
    dalam90: ke90,
  );
}
