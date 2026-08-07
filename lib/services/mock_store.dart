import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calibration_history_item.dart';

/// Tempat [MockStore] nyimpen isinya. Dipisah jadi antarmuka biar test tetap
/// jalan di memori (cepat & deterministik) sementara app beneran nulis ke disk.
abstract class PenyimpanMockStore {
  Future<String?> baca();

  Future<void> tulis(String isi);
}

/// Penyimpan bawaan app: `SharedPreferences`. Dipilih daripada file karena
/// isinya kecil (puluhan baris riwayat) dan nggak perlu izin apa pun di
/// Android/macOS/Windows sekaligus.
class PenyimpanPrefs implements PenyimpanMockStore {
  static const _kunci = 'mock_store_sesi_v1';

  @override
  Future<String?> baca() async =>
      (await SharedPreferences.getInstance()).getString(_kunci);

  @override
  Future<void> tulis(String isi) async =>
      (await SharedPreferences.getInstance()).setString(_kunci, isi);
}

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
/// Ini nambal celah itu: satu tempat nyimpen sesi yang lahir dari pemakaian
/// app, dibaca semua mock yang butuh.
///
/// ## Sejak 5 Agt 2026: isinya SELAMAT waktu app ditutup
///
/// Sebelumnya cuma di memori, dan itu bikin sesi tes berhari-hari hilang tanpa
/// jejak — dikira data kehapus, padahal memang nggak pernah disimpan. Sekarang
/// tiap perubahan langsung ditulis lewat [PenyimpanMockStore].
///
/// ## Batasnya — baca ini sebelum percaya ANGKANYA
///
/// Yang kebukti lewat jalur ini itu perilaku LAYARNYA, bukan backend-nya:
/// **nggak ada perhitungan ketidakpastian beneran, nggak ada PDF yang
/// digenerate, nggak ada aturan approval sisi server.** Jadi angka di build
/// mock NGGAK akan sama dengan isi database, dan itu bukan bug — build mock
/// nol panggilan jaringan. Buat mastiin angkanya, tetap harus lawan API asli
/// (lihat `docs/skrip/e2e-ph.py`).
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();

  /// Sesi yang lahir dari lembar kerja yang dikirim lewat app ini. Ditaruh
  /// paling depan waktu dibaca — yang barusan dikerjain orang itu yang paling
  /// dicari, bukan contoh bawaan.
  final List<CalibrationHistoryItem> _sesi = [];

  /// Mulai di atas id contoh bawaan (1..4) biar nggak tabrakan.
  int _idBerikutnya = 500;
  int _idSertifikatBerikutnya = 950;

  /// `null` = jalan di memori doang (test, atau app sebelum [pulihkan]).
  PenyimpanMockStore? _penyimpan;

  /// Tulisan terakhir yang lagi jalan. Dipakai [tungguTersimpan].
  Future<void>? _tulisanBerjalan;

  List<CalibrationHistoryItem> get sesi => List.unmodifiable(_sesi);

  /// Pasang penyimpan & muat isi yang tersimpan. Dipanggil SEKALI waktu app
  /// mulai, sebelum layar pertama digambar.
  ///
  /// Gagal baca sengaja didiemin: data mock ilang itu nggak enak, tapi app yang
  /// nggak mau kebuka gara-gara satu baris JSON rusak jauh lebih buruk.
  Future<void> pulihkan(PenyimpanMockStore penyimpan) async {
    _penyimpan = penyimpan;

    try {
      final isi = await penyimpan.baca();
      if (isi == null || isi.isEmpty) return;

      final data = jsonDecode(isi) as Map<String, dynamic>;
      final daftar = (data['sesi'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_dariLokal)
          .whereType<CalibrationHistoryItem>()
          .toList();

      _sesi
        ..clear()
        ..addAll(daftar);

      // Id lanjut dari yang tersimpan, bukan balik ke 500 — kalau diulang,
      // sesi baru bakal nabrak id sesi lama dan `setujui`/`tolak` kena baris
      // yang salah.
      _idBerikutnya = (data['id_berikutnya'] as num?)?.toInt() ?? _idBerikutnya;
      _idSertifikatBerikutnya =
          (data['id_sertifikat_berikutnya'] as num?)?.toInt() ??
          _idSertifikatBerikutnya;
    } catch (_) {
      // Lihat docblock — sengaja nggak ngeblok app.
    }
  }

  /// Catat sesi baru dari lembar kerja yang barusan dikirim.
  ///
  /// [draft] `true` = tombol SIMPAN SEBAGAI DRAFT, `false` = KIRIM KE ADMIN.
  ///
  /// Dulu statusnya SELALU `menungguApproval`, apa pun tombolnya. Akibatnya
  /// draft yang belum siap ikut nongol di antrean approval admin — dan teknisi
  /// nggak punya cara buat mbedain mana yang beneran udah dikirim. Dua-duanya
  /// kelihatan sama.
  int tambahSesi({
    required String namaAlat,
    required String namaTeknisi,
    bool draft = false,
  }) {
    final id = _idBerikutnya++;

    _sesi.insert(
      0,
      CalibrationHistoryItem(
        id: id,
        namaAlat: namaAlat,
        namaTeknisi: namaTeknisi,
        tanggalKalibrasi: DateTime.now(),
        status: draft
            ? CalibrationStatus.draft
            : CalibrationStatus.menungguApproval,
      ),
    );

    _simpan();
    return id;
  }

  /// Tunggu tulisan terakhir mendarat di disk.
  ///
  /// [_simpan] sengaja nggak di-`await` yang manggil supaya tombolnya nggak
  /// nahan UI. Tapi buat KIRIM itu nggak cukup: kalau app ditutup persis
  /// sesudah kirim, tulisannya bisa belum sempat mendarat dan sesinya ilang —
  /// gejalanya "harusnya udah kekirim, kok nggak ada". Jadi jalur kirim nunggu
  /// di sini sebelum bilang berhasil.
  Future<void> tungguTersimpan() async {
    await _tulisanBerjalan;
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

    _simpan();
    return certId;
  }

  void tolak(int sesiId, String catatan) {
    final i = _sesi.indexWhere((s) => s.id == sesiId);
    if (i < 0) return;

    _sesi[i] = _sesi[i].copyWith(
      status: CalibrationStatus.perluRevisi,
      catatanRevisi: catatan,
    );

    _simpan();
  }

  /// Dipanggil test yang butuh mulai dari kosong. Tanpa ini, urutan test di
  /// satu berkas bisa saling ngintip sesi yang dibikin test sebelumnya.
  ///
  /// [lupakanPenyimpan] default true supaya test nggak sengaja kebawa nulis ke
  /// disk gara-gara test lain sebelumnya manggil [pulihkan].
  void reset({bool lupakanPenyimpan = true}) {
    _sesi.clear();
    _idBerikutnya = 500;
    _idSertifikatBerikutnya = 950;
    _tulisanBerjalan = null;
    if (lupakanPenyimpan) _penyimpan = null;
  }

  /// Tulis balik ke penyimpan. Sengaja **nggak** di-`await` yang manggil:
  /// nyimpen itu urusan latar, dan nahan tombol KIRIM sampai disk selesai
  /// nulis cuma bikin app kerasa lemot tanpa alasan.
  void _simpan() {
    final penyimpan = _penyimpan;
    if (penyimpan == null) return;

    final isi = jsonEncode({
      'sesi': _sesi.map(_keLokal).toList(),
      'id_berikutnya': _idBerikutnya,
      'id_sertifikat_berikutnya': _idSertifikatBerikutnya,
    });

    // Gagal tulis didiemin dengan alasan yang sama kayak gagal baca.
    _tulisanBerjalan = penyimpan.tulis(isi).catchError((_) {});
  }

  /// Bentuk simpanan LOKAL — sengaja beda dari `CalibrationHistoryItem.fromJson`
  /// yang bacanya respons API (bersarang: `equipment.nama_alat`, `teknisi.nama`).
  /// Dua bentuk itu nggak boleh ketuker; yang ini datar & cuma dipakai di sini.
  Map<String, dynamic> _keLokal(CalibrationHistoryItem s) => {
    'id': s.id,
    'nama_alat': s.namaAlat,
    'nama_teknisi': s.namaTeknisi,
    'nama_pelanggan': s.namaPelanggan,
    'tanggal_kalibrasi': s.tanggalKalibrasi.toIso8601String(),
    'status': s.status.name,
    'keputusan': s.keputusan?.name,
    'nomor_sertifikat': s.nomorSertifikat,
    'catatan_revisi': s.catatanRevisi,
    'certificate_id': s.certificateId,
  };

  /// `null` kalau barisnya cacat — satu baris rusak nggak boleh ngebuang
  /// seluruh riwayat yang lain.
  CalibrationHistoryItem? _dariLokal(Map<String, dynamic> j) {
    try {
      return CalibrationHistoryItem(
        id: (j['id'] as num).toInt(),
        namaAlat: j['nama_alat'] as String? ?? '—',
        namaTeknisi: j['nama_teknisi'] as String? ?? '—',
        namaPelanggan: j['nama_pelanggan'] as String?,
        tanggalKalibrasi: DateTime.parse(j['tanggal_kalibrasi'] as String),
        status: CalibrationStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => CalibrationStatus.draft,
        ),
        keputusan: switch (j['keputusan']) {
          'pass' => Keputusan.pass,
          'fail' => Keputusan.fail,
          _ => null,
        },
        nomorSertifikat: j['nomor_sertifikat'] as String?,
        catatanRevisi: j['catatan_revisi'] as String?,
        certificateId: (j['certificate_id'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
