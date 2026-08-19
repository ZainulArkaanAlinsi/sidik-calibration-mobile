import '../core/utils/parse_list.dart';
import 'calibration_detail.dart' show MeasurementResult;

/// Hasil `POST /api/calibrations/preview` — hitungan backend TANPA nyimpen
/// sesi.
///
/// Ada supaya teknisi tau angkanya mendarat di mana **sebelum** lembarnya
/// dikirim ke admin. Sebelum ini satu-satunya cara lihat hasil hitung adalah
/// ngirim sesinya, dan sesi yang salah titik cuma bisa dibetulin lewat jalur
/// revisi admin.
///
/// **Mobile nggak ngitung apa pun di sini.** Rata-rata, koreksi, dan U95 semua
/// datang dari backend — buat Spectrophotometer angkanya bahkan nggak bisa
/// diturunkan dari satu titik: U95-nya lahir per KELOMPOK, dari STDEV terbesar
/// seluruh titik di kelompok itu.
class PratinjauHitung {
  const PratinjauHitung({
    required this.titik,
    required this.belumDihitung,
  });

  /// Titik yang berhasil dihitung. Bentuknya SAMA PERSIS kayak `titik[]` di
  /// `GET /calibrations/{id}` — backend sengaja lewat helper yang sama, jadi
  /// parser-nya dipakai ulang apa adanya.
  final List<MeasurementResult> titik;

  /// Titik yang nggak bisa dihitung, lengkap sama alasannya.
  final List<TitikBelumDihitung> belumDihitung;

  bool get kosong => titik.isEmpty && belumDihitung.isEmpty;

  factory PratinjauHitung.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return PratinjauHitung(
      titik: parseListAman(data['titik'], MeasurementResult.fromJson),
      belumDihitung: parseListAman(
        data['belum_dihitung'],
        TitikBelumDihitung.fromJson,
      ),
    );
  }
}

/// Satu titik yang dilewat backend waktu ngitung, plus alasannya.
///
/// Wajib ditampilin, bukan dibuang. Lembar boleh dikirim walau sebagian kosong
/// (`semua_kolom_opsional`), tapi tiap titik kosong NGURANGI dasar hitung
/// kelompoknya — di Spectrophotometer satu titik yang cuma keisi satu
/// pembacaan ikut nentuin U95 sembilan titik saudaranya. Teknisi yang nggak
/// dikasih tau bakal ngira barisnya udah beres.
class TitikBelumDihitung {
  const TitikBelumDihitung({required this.titikKe, required this.alasan});

  /// Nomor urut titik di lembar (1-based), bukan nilai titik ukurnya.
  final int titikKe;

  /// Kalimat dari backend, mis. "Baru 1 pembacaan terisi, minimal 2 — standar
  /// deviasi nggak bisa dihitung dari satu angka." Ditampilin apa adanya:
  /// alasannya beda-beda per aturan, dan nulis ulang di sini bikin dua versi
  /// kalimat yang bisa berbeda diam-diam.
  final String alasan;

  factory TitikBelumDihitung.fromJson(Map<String, dynamic> json) =>
      TitikBelumDihitung(
        titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
        alasan: json['alasan'] as String? ?? '',
      );
}
