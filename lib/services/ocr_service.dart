import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Satu angka hasil baca layar pH meter.
class HasilOcr {
  const HasilOcr({
    required this.nilai,
    required this.teksMentah,
    required this.keyakinan,
    this.suhu,
  });

  /// Nilai pH yang dipilih parser.
  final double nilai;

  /// Seluruh teks yang kebaca ML Kit, apa adanya. Dikirim ke backend sebagai
  /// `ocr_raw_text` — kalau nanti ada sengketa angka, ini buktinya.
  final String teksMentah;

  /// 0..1. **Bukan** confidence-nya ML Kit (ML Kit nggak ngasih confidence per
  /// blok di Android), tapi turunan dari seberapa masuk akal angkanya: nempel
  /// ke nilai buffer yang diharapkan = tinggi, ngambang = rendah. Dipakai buat
  /// nandain mana yang wajib dicek ekstra teliti, bukan buat lolos-otomatis.
  final double keyakinan;

  /// Suhu larutan kalau kebaca di layar yang sama. `null` = nggak ketemu.
  final double? suhu;
}

/// Baca angka dari foto layar pH meter — **semua di HP**, nggak ada foto yang
/// diunggah ke mana pun buat dikenali.
///
/// Yang dikenali cuma **layar digital** (angka tercetak), bukan tulisan tangan
/// di kertas worksheet — itu keputusan user 22 Jul 2026, dan bedanya besar:
/// ML Kit akurat buat tujuh-segmen/LCD, tapi sering meleset di tulisan tangan.
abstract class OcrService {
  Future<HasilOcr?> bacaLayar(File foto, {double? perkiraan});

  void dispose();
}

class MlKitOcrService implements OcrService {
  final _pengenal = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<HasilOcr?> bacaLayar(File foto, {double? perkiraan}) async {
    final hasil = await _pengenal.processImage(InputImage.fromFile(foto));
    return PhOcrParser.pilih(hasil.text, perkiraan: perkiraan);
  }

  @override
  void dispose() => _pengenal.close();
}

/// Pemilih angka — dipisah dari ML Kit **dengan sengaja**, biar logika yang
/// paling gampang salah ini bisa diuji tanpa kamera, HP, atau foto sungguhan.
class PhOcrParser {
  const PhOcrParser._();

  /// Batas atas skala pH. Angka di atas ini nggak mungkin pembacaan pH —
  /// paling mungkin suhu (mis. `22,2`).
  static const double skalaPhMaks = 14.0;

  /// Seberapa jauh angka boleh meleset dari nilai buffer yang diharapkan tapi
  /// masih dianggap pembacaan yang sah.
  ///
  /// Longgar (±1 pH) karena alat yang **rusak** justru itu yang mau ketahuan —
  /// kalau dipersempit, pembacaan menyimpang yang justru penting malah dibuang
  /// parser dan teknisi nggak pernah lihat.
  static const double toleransiPerkiraan = 1.0;

  /// Ambil angka pH (dan suhu kalau ada) dari teks hasil OCR.
  ///
  /// [perkiraan] itu nilai buffer yang lagi dikerjain (4/7/10). Kalau diisi,
  /// angka yang paling nempel ke situ yang dipilih — ini yang bikin parser
  /// nggak ketuker antara pH `4,01` dan suhu `22,2` waktu dua-duanya nongol
  /// di satu layar.
  static HasilOcr? pilih(String teks, {double? perkiraan}) {
    final angka = _semuaAngka(teks);
    if (angka.isEmpty) return null;

    // Suhu = kandidat di luar skala pH. Diambil duluan supaya nggak ikut
    // kepilih jadi nilai pH.
    final kandidatSuhu = angka.where((a) => a > skalaPhMaks).toList();
    final kandidatPh = angka.where((a) => a <= skalaPhMaks).toList();

    if (kandidatPh.isEmpty) return null;

    final double terpilih;
    final double keyakinan;

    if (perkiraan != null) {
      final terdekat = kandidatPh.reduce(
        (a, b) =>
            (a - perkiraan).abs() <= (b - perkiraan).abs() ? a : b,
      );
      final jarak = (terdekat - perkiraan).abs();

      // Semua kandidat jauh dari buffer yang diharapkan → besar kemungkinan
      // yang kefoto bukan layar yang bener (atau OCR-nya ngaco). Lebih baik
      // bilang "nggak kebaca" daripada ngisi angka ngawur yang keburu
      // ke-approve.
      if (jarak > toleransiPerkiraan) return null;

      terpilih = terdekat;
      keyakinan = (1 - jarak / toleransiPerkiraan).clamp(0.0, 1.0);
    } else {
      // Tanpa perkiraan, nggak ada dasar buat milih — ambil yang pertama dan
      // tandai keyakinannya rendah supaya teknisi ngecek.
      terpilih = kandidatPh.first;
      keyakinan = 0.3;
    }

    return HasilOcr(
      nilai: terpilih,
      teksMentah: teks,
      keyakinan: keyakinan,
      suhu: kandidatSuhu.isEmpty ? null : kandidatSuhu.first,
    );
  }

  /// Tarik semua bilangan desimal dari teks OCR.
  ///
  /// Koma dianggap titik desimal — layar & worksheet di sini pakai format
  /// Indonesia (`4,01`), sementara `double.parse` cuma ngerti titik.
  static List<double> _semuaAngka(String teks) {
    final pola = RegExp(r'\d+(?:[.,]\d+)?');

    return pola
        .allMatches(teks)
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '.')))
        .whereType<double>()
        .toList();
  }
}

/// Data tiruan buat test & jalanin app tanpa kamera.
class MockOcrService implements OcrService {
  MockOcrService({this.hasil, this.gagal = false});

  final HasilOcr? hasil;
  final bool gagal;

  @override
  Future<HasilOcr?> bacaLayar(File foto, {double? perkiraan}) async {
    if (gagal) throw Exception('kamera nggak bisa dibuka');
    return hasil;
  }

  @override
  void dispose() {}
}
