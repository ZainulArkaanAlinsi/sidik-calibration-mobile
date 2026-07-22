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
    this.label = '',
  });

  /// Kunci periode apa adanya dari backend (mis. `2026-07`). Mobile nggak
  /// nafsirin formatnya — granularitasnya bisa harian/mingguan/bulanan.
  final String periode;

  /// Label sumbu X yang **udah jadi** dari backend (mis. `Jul 2026`), jadi
  /// mobile nggak usah nerjemahin nama bulan sendiri. Bisa kosong kalau
  /// endpoint-nya nggak ngirim — [WorkChart] nurunin sendiri dari [periode].
  final String label;

  final int masuk;
  final int selesai;

  factory TitikTren.fromJson(Map<String, dynamic> json) => TitikTren(
    // Dua endpoint, dua nama field, isi yang sama:
    //   `GET /dashboard`      -> `bulan` (+ `label` siap pakai)
    //   `GET /dashboard/tren` -> `periode`
    //
    // Dulu di sini cuma baca `periode`, jadi buat layar Dashboard nilainya
    // selalu '' dan sumbu X grafiknya kosong melompong. Nggak ketahuan dari
    // test karena `MockDashboardService` ngisinya pakai `periode` juga —
    // cuma server beneran yang ngirim `bulan`.
    periode: (json['bulan'] ?? json['periode'])?.toString() ?? '',
    label: json['label']?.toString() ?? '',
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
    this.totalSertifikat = 0,
  });

  final int totalAlat;
  final int alatOverdue;
  final int kalibrasiDraft;
  final int kalibrasiSelesai;
  final int menungguApproval;
  final int sertifikatBulanIni;

  /// Sertifikat terbit **sepanjang waktu**, dan **selalu se-lab** — bukan cuma
  /// punya user yang lagi login.
  ///
  /// Ini beda cakupan sama angka sesi ([kalibrasiDraft], [menungguApproval],
  /// [kalibrasiSelesai]) yang buat teknisi disaring jadi miliknya sendiri.
  /// Jadi wajar kalau teknisi lihat "Kalibrasi selesai: 2" bareng "Total
  /// sertifikat: 15" — itu bukan bug, makanya di layar dua kelompok angka ini
  /// dipisah dengan judul yang beda ("Kalibrasi Saya" vs "Sertifikat Lab").
  final int totalSertifikat;

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
      sertifikatBulanIni == 0 &&
      totalSertifikat == 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    // Field yang belum dikirim backend dianggap 0, bukan bikin app crash.
    int angka(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DashboardSummary(
      totalAlat: angka('total_alat'),
      alatOverdue: angka('alat_overdue'),
      kalibrasiDraft: angka('kalibrasi_draft'),
      kalibrasiSelesai: angka('kalibrasi_selesai'),
      // JANGAN diganti `menunggu_proses`. Dua-duanya dikirim backend tapi
      // artinya beda dan **saling tumpang tindih**:
      //
      //   menunggu_approval = status == menunggu_approval
      //   menunggu_proses   = SEMUA sesi yang statusnya != disetujui
      //                       (draft + menunggu_approval + perlu_revisi)
      //
      // Kartu "Draft" dan "Menunggu approval" dirender bersebelahan, jadi
      // kalau yang kanan diisi `menunggu_proses`, sesi draft kehitung dua
      // kali — sekali di kartu kiri, sekali lagi di kanan.
      menungguApproval: angka('menunggu_approval'),
      sertifikatBulanIni: angka('sertifikat_bulan_ini'),
      totalSertifikat: angka('total_sertifikat'),
      grafikPekerjaan:
          (json['grafik_pekerjaan'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()
              .map(TitikTren.fromJson)
              .toList(),
    );
  }
}
