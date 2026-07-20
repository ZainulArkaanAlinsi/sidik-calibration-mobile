/// Ringkasan dashboard. Isinya beda tergantung role — teknisi dapat angka
/// miliknya sendiri, admin dapat angka lintas-teknisi. **Backend yang nentuin
/// dari token**, mobile nggak ngirim role (lihat `docs/kontrak-api.md`).
/// Satu titik di grafik pekerjaan: berapa sesi masuk vs selesai dalam satu
/// periode. Backend yang ngagregasi — mobile nggak pernah ngitung sendiri dari
/// daftar sesi, karena di lab yang udah jalan setahun itu ribuan baris cuma
/// buat gambar belasan titik.
class TitikTren {
  const TitikTren({
    required this.periode,
    required this.masuk,
    required this.selesai,
  });

  /// Label apa adanya dari backend (mis. `2026-07`). Mobile nggak nafsirin
  /// formatnya — granularitasnya bisa harian/mingguan/bulanan.
  final String periode;
  final int masuk;
  final int selesai;

  factory TitikTren.fromJson(Map<String, dynamic> json) => TitikTren(
    periode: json['periode']?.toString() ?? '',
    masuk: (json['masuk'] as num?)?.toInt() ?? 0,
    selesai: (json['selesai'] as num?)?.toInt() ?? 0,
  );
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalAlat,
    required this.alatOverdue,
    required this.kalibrasiDraft,
    required this.kalibrasiSelesai,
    required this.menungguApproval,
    required this.sertifikatBulanIni,
    required this.grafikPekerjaan,
  });

  final int totalAlat;
  final int alatOverdue;
  final int kalibrasiDraft;
  final int kalibrasiSelesai;
  final int menungguApproval;
  final int sertifikatBulanIni;

  /// 6 bulan terakhir, dikunci backend. Bisa kosong kalau backend versi lama —
  /// layar nanganin itu dengan nggak nampilin grafiknya sama sekali.
  final List<TitikTren> grafikPekerjaan;

  /// Dashboard dianggap kosong kalau **belum ada apa-apa sama sekali** —
  /// bukan sekadar angka nol di satu kotak. Ini yang mutusin layar nampilin
  /// state `empty` (ajakan mulai) atau `normal` (angka-angka).
  bool get kosong =>
      totalAlat == 0 &&
      alatOverdue == 0 &&
      kalibrasiDraft == 0 &&
      menungguApproval == 0 &&
      sertifikatBulanIni == 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    // Field yang belum dikirim backend dianggap 0, bukan bikin app crash.
    int angka(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DashboardSummary(
      totalAlat: angka('total_alat'),
      alatOverdue: angka('alat_overdue'),
      kalibrasiDraft: angka('kalibrasi_draft'),
      kalibrasiSelesai: angka('kalibrasi_selesai'),
      // Backend ngirim dua-duanya; `menunggu_proses` nama barunya, tapi yang
      // lama tetap dibaca sebagai cadangan biar app nggak pecah kalau nembak
      // backend versi lama.
      menungguApproval: json['menunggu_proses'] == null
          ? angka('menunggu_approval')
          : angka('menunggu_proses'),
      sertifikatBulanIni: angka('sertifikat_bulan_ini'),
      grafikPekerjaan:
          (json['grafik_pekerjaan'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()
              .map(TitikTren.fromJson)
              .toList(),
    );
  }
}
