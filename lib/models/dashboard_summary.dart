/// Ringkasan dashboard. Isinya beda tergantung role — teknisi dapat angka
/// miliknya sendiri, admin dapat angka lintas-teknisi. **Backend yang nentuin
/// dari token**, mobile nggak ngirim role (lihat `docs/kontrak-api.md`).
class DashboardSummary {
  const DashboardSummary({
    required this.totalAlat,
    required this.alatOverdue,
    required this.kalibrasiDraft,
    required this.menungguApproval,
    required this.sertifikatBulanIni,
  });

  final int totalAlat;
  final int alatOverdue;
  final int kalibrasiDraft;
  final int menungguApproval;
  final int sertifikatBulanIni;

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
      menungguApproval: angka('menunggu_approval'),
      sertifikatBulanIni: angka('sertifikat_bulan_ini'),
    );
  }
}
