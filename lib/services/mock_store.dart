import '../models/calibration_history_item.dart';

/// Ingatan bersama antar-mock, supaya alur kerjanya nyambung tanpa server.
///
/// ## Kenapa ada
///
/// Tiap mock dulunya berdiri sendiri: `MockLembarKerjaService.kirim()` cuma
/// balikin sebuah id, dan `MockHistoryService` balikin daftar yang ditulis
/// tetap di kode. Dua-duanya "jalan" kalau dites sendiri-sendiri — tapi
/// **rantainya putus**: lembar kerja yang dikirim teknisi nggak pernah nongol
/// di antrean approval admin, jadi alur pH dari awal sampai sertifikat nggak
/// bisa dicoba sama sekali tanpa backend nyala.
///
/// Ini nambal celah itu: satu tempat nyimpen sesi yang lahir di sesi pemakaian
/// ini, dibaca semua mock yang butuh.
///
/// ## Batasnya — baca ini sebelum percaya hasilnya
///
/// Isinya **cuma di memori dan ilang tiap app ditutup**. Yang kebukti lewat
/// jalur ini itu perilaku LAYARNYA, bukan backend-nya: nggak ada perhitungan
/// ketidakpastian beneran, nggak ada PDF yang digenerate, nggak ada aturan
/// approval sisi server. Buat mastiin sistemnya beneran jalan, tetap harus
/// lawan API asli.
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();

  /// Sesi yang lahir dari lembar kerja yang dikirim di sesi pemakaian ini.
  /// Ditaruh paling depan waktu dibaca — yang barusan dikerjain orang itu yang
  /// paling dicari, bukan contoh bawaan.
  final List<CalibrationHistoryItem> _sesi = [];

  /// Mulai di atas id contoh bawaan (1..4) biar nggak tabrakan.
  int _idBerikutnya = 500;
  int _idSertifikatBerikutnya = 950;

  List<CalibrationHistoryItem> get sesi => List.unmodifiable(_sesi);

  /// Catat sesi baru dari lembar kerja yang barusan dikirim.
  ///
  /// Statusnya langsung `menungguApproval`, bukan `draft`: yang manggil ini
  /// adalah tombol KIRIM, dan di alur aslinya itu emang langsung nyetor ke
  /// antrean admin.
  int tambahSesi({required String namaAlat, required String namaTeknisi}) {
    final id = _idBerikutnya++;

    _sesi.insert(
      0,
      CalibrationHistoryItem(
        id: id,
        namaAlat: namaAlat,
        namaTeknisi: namaTeknisi,
        tanggalKalibrasi: DateTime.now(),
        status: CalibrationStatus.menungguApproval,
      ),
    );

    return id;
  }

  /// Setujui sesi → terbit sertifikatnya. Balikin id sertifikat, atau `null`
  /// kalau sesinya bukan punya store ini (mis. contoh bawaan).
  int? setujui(int sesiId) {
    final i = _sesi.indexWhere((s) => s.id == sesiId);
    if (i < 0) return null;

    final certId = _idSertifikatBerikutnya++;

    _sesi[i] = _sesi[i].copyWith(
      status: CalibrationStatus.disetujui,
      keputusan: Keputusan.pass,
      certificateId: certId,
    );

    return certId;
  }

  void tolak(int sesiId, String catatan) {
    final i = _sesi.indexWhere((s) => s.id == sesiId);
    if (i < 0) return;

    _sesi[i] = _sesi[i].copyWith(
      status: CalibrationStatus.perluRevisi,
      catatanRevisi: catatan,
    );
  }

  /// Dipanggil test yang butuh mulai dari kosong. Tanpa ini, urutan test di
  /// satu berkas bisa saling ngintip sesi yang dibikin test sebelumnya.
  void reset() {
    _sesi.clear();
    _idBerikutnya = 500;
    _idSertifikatBerikutnya = 950;
  }
}
