import 'autoclave_hasil.dart';
import 'calibration_history_item.dart';
import '../core/utils/parse_list.dart';

/// Standar acuan ringkas — dipakai di level sesi dan bisa di-override per
/// titik ukur (mis. pH: buffer 4/7/10 masing-masing sertifikatnya sendiri).
class StandardRef {
  const StandardRef({required this.id, required this.nama, this.noSertifikat});

  final int id;
  final String nama;
  final String? noSertifikat;

  factory StandardRef.fromJson(Map<String, dynamic> json) {
    return StandardRef(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      noSertifikat: json['no_sertifikat'] as String?,
    );
  }
}

/// Satu komponen Type B — angka udah dikonversi ke ketidakpastian BAKU (u),
/// bukan diperluas (U), dan `keterangan` udah diformat siap-tampil oleh
/// backend (`GumCalculator::komponenTypeB()` / `hitungDariKemampuan()`).
class UncertaintyComponent {
  const UncertaintyComponent({
    required this.sumber,
    required this.keterangan,
    required this.nilai,
    this.distribusi,
  });

  final String sumber;
  final String keterangan;
  final String? distribusi;
  final double nilai;

  factory UncertaintyComponent.fromJson(Map<String, dynamic> json) {
    return UncertaintyComponent(
      sumber: json['sumber'] as String? ?? '—',
      keterangan: json['keterangan'] as String? ?? '',
      distribusi: json['distribusi'] as String?,
      nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Tahap pembacaan — alat pH dibaca dua kali: waktu diterima ("as found") dan
/// setelah diadjust ("as left"). Cuma [sesudahAdjustment] yang ikut hitungan
/// GUM dan masuk sertifikat.
enum TahapPembacaan {
  sebelumAdjustment,
  sesudahAdjustment;

  static TahapPembacaan fromJson(String? value) =>
      value == 'sebelum_adjustment'
      ? TahapPembacaan.sebelumAdjustment
      : TahapPembacaan.sesudahAdjustment;
}

/// Satu pembacaan mentah (`pembacaan_mentah` di response) — baris asli yang
/// diinput teknisi, sebelum diringkas jadi rata-rata di [MeasurementResult].
/// Cuma ikut di response detail sesi (`GET /api/calibrations/{id}`), nggak di
/// daftar (`GET /api/calibrations`).
class RawMeasurement {
  const RawMeasurement({
    required this.id,
    required this.titikKe,
    required this.titikUkur,
    this.standardId,
    required this.pembacaanKe,
    required this.pembacaan,
    required this.inputSource,
    required this.isVerified,
    this.tahap = TahapPembacaan.sesudahAdjustment,
    this.suhu,
  });

  final int id;
  final int titikKe;

  /// Standar acuan yang dicentang teknisi buat baris ini. Null = belum dipilih
  /// (sah buat draft), atau baris dari sesi yang dikirim sebelum kolom ini ada.
  final int? standardId;

  /// Nilai titiknya (4.00 / 7.00 / 10.01), bukan nomor barisnya.
  ///
  /// Ini yang dipakai buat naruh angka balik ke lembar kerja waktu draft dibuka
  /// lagi. [titikKe] nggak bisa dipercaya buat itu — dia posisi, dan posisinya
  /// geser tiap bentuk lembar berubah.
  final double titikUkur;

  final int pembacaanKe;
  final double pembacaan;

  /// Default `sesudah_adjustment` — alat non-pH cuma punya satu tahap, dan
  /// backend nandain barisnya sebagai tahap yang disertifikasi.
  final TahapPembacaan tahap;

  /// Suhu larutan waktu baris ini dibaca (khusus pH). Null buat alat lain.
  final double? suhu;

  /// `manual` / `ocr`.
  final String inputSource;

  /// Pembacaan hasil OCR yang belum dikonfirmasi teknisi — sesi nggak bisa
  /// di-approve selama masih ada yang `false` (`CalibrationController::approve()`).
  final bool isVerified;

  factory RawMeasurement.fromJson(Map<String, dynamic> json) {
    return RawMeasurement(
      id: (json['id'] as num).toInt(),
      titikKe: (json['titik_ke'] as num).toInt(),
      // Backend ngirim decimal(20,8) — bisa nyampe sebagai angka atau string.
      titikUkur:
          (json['titik_ukur'] as num?)?.toDouble() ??
          double.tryParse('${json['titik_ukur']}') ??
          0,
      standardId: (json['standard_id'] as num?)?.toInt(),
      pembacaanKe: (json['pembacaan_ke'] as num).toInt(),
      pembacaan: (json['pembacaan'] as num).toDouble(),
      tahap: TahapPembacaan.fromJson(json['tahap'] as String?),
      suhu: (json['suhu'] as num?)?.toDouble(),
      inputSource: json['input_source'] as String? ?? 'manual',
      isVerified: json['is_verified'] as bool? ?? true,
    );
  }
}

/// Ringkasan satu titik **sebelum adjustment** (`titik_sebelum`) — sengaja
/// jauh lebih tipis dari [MeasurementResult]: nggak ada ketidakpastian,
/// toleransi, atau keputusan PASS/FAIL, karena kondisi as-found memang nggak
/// disertifikasi. Cuma dokumentasi "alatnya datang dalam keadaan seperti apa".
class MeasurementBefore {
  const MeasurementBefore({
    required this.titikKe,
    required this.titikUkur,
    required this.rataRata,
    required this.koreksi,
    required this.standarDeviasi,
    required this.jumlahPengulangan,
  });

  final int titikKe;
  final double titikUkur;
  final double rataRata;
  final double koreksi;
  final double standarDeviasi;
  final int jumlahPengulangan;

  factory MeasurementBefore.fromJson(Map<String, dynamic> json) {
    return MeasurementBefore(
      titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      koreksi: (json['koreksi'] as num?)?.toDouble() ?? 0,
      standarDeviasi: (json['standar_deviasi'] as num?)?.toDouble() ?? 0,
      jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Satu besaran lingkungan (suhu ATAU kelembaban) — dibaca awal & akhir sesi,
/// dikoreksi pakai sertifikat thermohygro, plus U95% yang diturunkan backend
/// dari `2·√((U_TH/2)² + (|awal−akhir|/2)²)`.
class BesaranLingkungan {
  const BesaranLingkungan({
    required this.awal,
    required this.akhir,
    required this.rataRata,
    required this.satuan,
    this.koreksi,
    this.nilaiTerkoreksi,
    this.u95,
  });

  final double awal;
  final double akhir;
  final double rataRata;
  final String satuan;
  final double? koreksi;
  final double? nilaiTerkoreksi;
  final double? u95;

  factory BesaranLingkungan.fromJson(Map<String, dynamic> json) {
    return BesaranLingkungan(
      awal: (json['awal'] as num?)?.toDouble() ?? 0,
      akhir: (json['akhir'] as num?)?.toDouble() ?? 0,
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      satuan: json['satuan'] as String? ?? '',
      koreksi: (json['koreksi'] as num?)?.toDouble(),
      nilaiTerkoreksi: (json['nilai_terkoreksi'] as num?)?.toDouble(),
      u95: (json['u95'] as num?)?.toDouble(),
    );
  }
}

/// Blok `kondisi_lingkungan` di response detail. Cuma keisi buat sesi yang
/// ngirim kondisi lingkungan lengkap (awal/akhir) — sesi lama yang cuma kirim
/// satu angka tetap balik lewat `suhu_ruang`/`kelembaban` di level atas.
class KondisiLingkungan {
  const KondisiLingkungan({this.suhu, this.kelembaban, this.thermohygro});

  final BesaranLingkungan? suhu;
  final BesaranLingkungan? kelembaban;
  final String? thermohygro;

  factory KondisiLingkungan.fromJson(Map<String, dynamic> json) {
    final suhu = json['suhu'] as Map<String, dynamic>?;
    final kelembaban = json['kelembaban'] as Map<String, dynamic>?;

    return KondisiLingkungan(
      suhu: suhu == null ? null : BesaranLingkungan.fromJson(suhu),
      kelembaban: kelembaban == null
          ? null
          : BesaranLingkungan.fromJson(kelembaban),
      thermohygro: json['thermohygro'] as String?,
    );
  }
}

/// Hasil kalkulasi GUM buat satu titik ukur (`titik` di respons `GET
/// /api/calibrations/{id}`, `docs/kontrak-api.md` §4) — bentuknya dikunci ke
/// `CalibrationResource::toArray()` di backend, bukan tebakan.
///
/// **Mobile nggak ngitung ulang apa pun di sini** — cuma nampilin apa yang
/// dibalikin backend.
class MeasurementResult {
  const MeasurementResult({
    required this.titikKe,
    required this.titikUkur,
    required this.rataRata,
    required this.error,
    required this.koreksi,
    required this.standarDeviasi,
    required this.jumlahPengulangan,
    required this.typeA,
    required this.typeB,
    this.typeBComponents = const [],
    required this.ketidakpastianGabungan,
    required this.faktorCakupanK,
    required this.ketidakpastianDiperluas,
    required this.toleransi,
    this.keputusan,
    this.standardId,
    this.standarAcuan,
    this.metode,
    this.desimal,
    this.satuan,
    this.tandaNol = true,
    this.remark,
    this.derajatKebebasanEfektif,
  });

  final int titikKe;
  final double titikUkur;

  /// Standar acuan yang dipakai ngitung titik ini.
  ///
  /// Dipakai buat mulangin CENTANG standar ke lembar kerja waktu sesi lama
  /// dibuka lagi. Sesi yang dikirim sebelum `raw_measurements.standard_id` ada
  /// cuma nyimpen pilihannya di sini.
  final int? standardId;
  final double rataRata;
  final double error;
  final double koreksi;
  final double standarDeviasi;
  final int jumlahPengulangan;
  final double typeA;
  final double typeB;
  final List<UncertaintyComponent> typeBComponents;
  final double ketidakpastianGabungan;
  final double faktorCakupanK;
  final double ketidakpastianDiperluas;
  final double toleransi;

  /// `PASS` / `FAIL` per titik — satu titik `FAIL` bikin seluruh sesi `FAIL`
  /// (`CalibrationController::isiUlangPengukuran()`).
  /// Null = alat ini **nggak divonis** PASS/FAIL.
  ///
  /// Bukan "belum diputuskan". Conductivity Meter nggak punya satu pun batas
  /// keberterimaan di master-nya, dan sertifikatnya berhenti di `Correction` +
  /// `U95%`. `GumCalculator::keputusan()` sengaja balikin null buat alat kayak
  /// gitu, dan kolomnya udah dibikin nullable di backend
  /// (`2026_08_10_150000_keputusan_titik_boleh_null`).
  ///
  /// Dulu field ini non-nullable dan parsingnya `== 'FAIL' ? fail : pass`, jadi
  /// null mendarat jadi **PASS**. Layar detail nampilin badge hijau "PASS" di
  /// titik yang nggak punya kriteria kelulusan sama sekali — di layar yang
  /// dipakai admin buat mutusin nerbitin sertifikat.
  final Keputusan? keputusan;

  /// Cuma keisi kalau titik ini pakai standar BEDA dari standar default sesi
  /// (mis. pH: buffer 4/7/10 masing-masing sertifikatnya sendiri).
  final StandardRef? standarAcuan;

  /// Instruksi kerja yang dipakai (mis. "SIDIK-IK-CAL-0506") — dicetak di
  /// sertifikat, jadi ditampilin apa adanya.
  final String? metode;

  /// Berapa desimal angka titik INI ditulis. `null` = ikut `desimal` level sesi
  /// ([CalibrationDetail.desimal]).
  ///
  /// Dikirim backend buat alat yang resolusinya berubah per rentang
  /// (Turbidimeter: 0,01 di bawah 10 NTU, 1 di atas 100) — satu angka di level
  /// sesi nggak bisa mewakili tiga resolusi sekaligus. Padanan `desimal`
  /// per-baris di [CertificateSnapshot], dan aturan jatuh-baliknya sama.
  final int? desimal;

  /// Satuan titik INI, buat alat yang nyampur satuan dalam satu lembar
  /// (Conductivity: 25 & 1412 µS/cm, 111 mS/cm).
  ///
  /// `null` = alat bersatuan seragam; layar jatuh ke satuan alat seperti biasa.
  /// Sebelum ada ini, layar detail & sertifikat nggak punya cara nulis
  /// `25 µS/cm` vs `111 mS/cm` selain nebak dari besar angkanya.
  final String? satuan;

  /// Koreksi negatif yang MEMBULAT KE NOL ditulis `-0,0` atau `0,0`.
  ///
  /// Beda per alat, dibaca dari master masing-masing: Turbidimeter
  /// `0189-CAL-624` nulis `-0,00`, sementara master Conductivity nyimpen
  /// `-0.03999999999999915` tapi nyetaknya `0,0`. Backend yang mutusin
  /// (`CalibrationProfile::tandaNolDicetak()`), layar tinggal ikut.
  ///
  /// Ada di sini — bukan cuma di [CertificateSnapshot] — biar tabel Calibration
  /// Report di layar riwayat & approval sama persis sama PDF-nya. Kalau beda,
  /// yang nemu duluan justru teknisi yang lagi mriksa hasilnya sendiri.
  final bool tandaNol;

  /// Nama KELOMPOK titik ini, mis. `Wave Length ( λ ) - Filter Holmium`.
  ///
  /// Cuma keisi buat alat yang titiknya berkelompok. Spectrophotometer yang
  /// pertama, dan di situ kelompok bukan label kosmetik: U95-nya lahir PER
  /// KELOMPOK, dari STDEV terbesar seluruh titik kelompok itu — sepuluh titik
  /// Holmium pulang dengan `ketidakpastian_diperluas` dan `faktor_cakupan_k`
  /// yang sama persis. Itu bener, bukan data kembar.
  ///
  /// Tanpa label ini, tabel di layar nampilin 24 baris dengan tiga nilai U95
  /// yang keliatan acak, dan `0,4 nm` nggak punya cara dibedain punya Didynium
  /// apa Holmium. Rentang dua kelompok itu tumpang tindih 167 nm, jadi
  /// nebaknya dari besar angka bakal salah persis di titik yang paling gampang
  /// ketuker.
  final String? remark;

  /// Derajat kebebasan efektif (Welch–Satterthwaite) — angka yang NENTUIN
  /// [faktorCakupanK] lewat `TINV(0,05; veff)`.
  ///
  /// Dipakai layar detail buat nunjukin rantai hitungnya utuh. Tanpa ini,
  /// `k = 3,18` muncul tanpa asal-usul dan nggak ada yang bisa ngecek ulang —
  /// padahal justru pemotongan veff ke bilangan bulat yang bikin k spektro
  /// beda jauh dari ±2 (`floor(3,4643)` → 3 → k 3,1824).
  ///
  /// `null` buat sesi lama yang responsnya belum bawa kunci ini.
  final double? derajatKebebasanEfektif;

  /// Desimal yang benar-benar dipakai nyetak titik ini.
  ///
  /// [desimalSesi] = angka tingkat-sesi, dipakai kalau backend nggak ngirim
  /// angka khusus buat titik ini.
  int desimalEfektif(int desimalSesi) => desimal ?? desimalSesi;

  factory MeasurementResult.fromJson(Map<String, dynamic> json) {
    final komponen = json['type_b_components'] as List<dynamic>? ?? const [];
    final standar = json['standar_acuan'] as Map<String, dynamic>?;

    return MeasurementResult(
      titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      standardId: (json['standard_id'] as num?)?.toInt(),
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      error: (json['error'] as num?)?.toDouble() ?? 0,
      koreksi: (json['koreksi'] as num?)?.toDouble() ?? 0,
      standarDeviasi: (json['standar_deviasi'] as num?)?.toDouble() ?? 0,
      jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 0,
      typeA: (json['type_a'] as num?)?.toDouble() ?? 0,
      typeB: (json['type_b'] as num?)?.toDouble() ?? 0,
      typeBComponents: parseListAman(komponen, UncertaintyComponent.fromJson),
      ketidakpastianGabungan:
          (json['ketidakpastian_gabungan'] as num?)?.toDouble() ?? 0,
      faktorCakupanK: (json['faktor_cakupan_k'] as num?)?.toDouble() ?? 0,
      ketidakpastianDiperluas:
          (json['ketidakpastian_diperluas'] as num?)?.toDouble() ?? 0,
      toleransi: (json['toleransi'] as num?)?.toDouble() ?? 0,
      keputusan: switch (json['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      standarAcuan: standar == null ? null : StandardRef.fromJson(standar),
      metode: json['metode'] as String?,
      desimal: (json['desimal'] as num?)?.toInt(),
      satuan: json['satuan'] as String?,
      tandaNol: json['tanda_nol'] as bool? ?? true,
      remark: json['remark'] as String?,
      derajatKebebasanEfektif:
          (json['derajat_kebebasan_efektif'] as num?)?.toDouble(),
    );
  }
}

/// Ringkasan sertifikat sesi ini — embed langsung di respons detail sesi
/// (`CalibrationResource::toArray()`), beda dari `Certificate` penuh yang
/// dibalikin `GET /api/certificates/{id}` (§5). `pdfUrl` cuma keisi kalau
/// `status == 'terbit'`.
class CertificateRef {
  const CertificateRef({
    required this.id,
    required this.nomor,
    required this.status,
    this.pdfUrl,
    this.qrToken,
    this.qrUrl,
  });

  final int id;
  final String nomor;
  final String status;
  final String? pdfUrl;

  /// Token halaman verifikasi publik (`GET /verify/{qr_token}`).
  ///
  /// **Backend belum ngirim ini** per 27 Jul — lihat
  /// `docs/permintaan-backend-alur-revisi-qr.md` §2. Sengaja nullable, jadi
  /// layar tinggal nyambung begitu backend nambahin, tanpa ubah apa-apa lagi.
  final String? qrToken;

  /// URL utuh halaman verifikasi. Lebih disukai daripada nyusun sendiri dari
  /// [qrToken] — domainnya milik backend, dan mobile nggak boleh ikut salah
  /// kalau domainnya ganti.
  final String? qrUrl;

  factory CertificateRef.fromJson(Map<String, dynamic> json) {
    return CertificateRef(
      id: (json['id'] as num).toInt(),
      nomor: json['nomor'] as String? ?? '—',
      status: json['status'] as String? ?? 'menunggu_generate',
      pdfUrl: json['pdf_url'] as String?,
      qrToken: json['qr_token'] as String?,
      qrUrl: json['qr_url'] as String?,
    );
  }
}

/// Respons penuh `GET /api/calibrations/{id}` (`docs/kontrak-api.md` §4) —
/// termasuk field bonus (`nomor_sesi`, `standar_acuan`, `suhu_ruang`,
/// `kelembaban`, `lokasi`, `sertifikat`, `titik`) yang dibutuhin buat
/// nampilin worksheet & tabel ketidakpastian di layar detail.
/// Kolom lembar kerja yang DIISI TEKNISI, dibaca balik apa adanya.
///
/// Kenapa dipisah dari sisa [CalibrationDetail]: yang lain itu hasil olahan
/// backend buat ditampilin (angka GUM, status, sertifikat). Yang ini bahan
/// mentah buat NGISI ULANG FORMULIRNYA waktu sesi dikembalikan buat revisi.
///
/// Tanpa ini, teknisi yang lembar kerjanya ditolak dapat formulir kosong dan
/// harus ngetik ulang semuanya — cuma buat mbenerin satu hal yang diminta
/// admin. Itu bikin revisi jadi hukuman, dan yang kejadian teknisi milih bikin
/// sesi baru daripada mbenerin yang lama.
class IsianTeknisi {
  const IsianTeknisi({
    this.equipmentId,
    this.standardId,
    this.roomId,
    this.thermohygroStandardId,
    this.tanggalTerima,
    this.lokasi,
    this.lokasiNama,
    this.catatanTeknisi,
    this.alatModel,
    this.alatSerialNumber,
    this.alatMerk,
    this.pemilikNama,
    this.pemilikAlamat,
    this.suhuAwal,
    this.suhuAkhir,
    this.kelembabanAwal,
    this.kelembabanAkhir,
    this.tekananAwal,
    this.tekananAkhir,
    this.standarDicek = const {},
    this.revisiField = const {},
    this.catatanRevisi,
    this.spesifikasiAlat = const {},
  });

  final int? equipmentId;
  final int? standardId;
  final int? roomId;
  final int? thermohygroStandardId;
  final DateTime? tanggalTerima;
  final String? lokasi;

  /// Nama tempat buat sesi `onsite` — `PT. LDC` di `Insitu (PT. LDC)`.
  final String? lokasiNama;
  final String? catatanTeknisi;

  final String? alatModel;
  final String? alatSerialNumber;
  final String? alatMerk;
  final String? pemilikNama;
  final String? pemilikAlamat;

  /// Rentang ukur / kapasitas / resolusi versi teknisi, kunci → teks apa
  /// adanya. Dipulangin backend biar draft yang dibuka lagi keisi persis kayak
  /// waktu ditinggal.
  final Map<String, String> spesifikasiAlat;

  final double? suhuAwal;
  final double? suhuAkhir;
  final double? kelembabanAwal;
  final double? kelembabanAkhir;

  /// Tekanan udara awal & akhir (hPa) — cuma Gas Detector yang punya.
  /// Dibawa balik supaya draft yang dibuka lagi nggak kehilangan dua angka
  /// yang justru nentuin ketidakpastiannya.
  final double? tekananAwal;
  final double? tekananAkhir;

  /// `standard_id` → (dipakai, keterangan).
  final Map<int, ({bool dipakai, String? keterangan})> standarDicek;

  /// Kode kolom yang diminta admin dibetulin. Layar nyorot persis kolom ini
  /// waktu lembar kerja dibuka lagi — teknisi nggak perlu nyisir puluhan kolom
  /// nyari mana yang dimaksud catatan revisinya.
  final Set<String> revisiField;

  /// Alasan admin ngembaliin lembarnya, apa adanya (nggak dipotong).
  ///
  /// Notifikasi cuma bawa 120 karakter pertama — cukup buat tau ada apa, nggak
  /// cukup buat tau harus ngapain. Yang lengkap dibawa ke sini biar kebaca di
  /// layar tempat teknisi ngerjain betulannya.
  final String? catatanRevisi;

  factory IsianTeknisi.fromJson(Map<String, dynamic> json) {
    final dicek = <int, ({bool dipakai, String? keterangan})>{};
    for (final baris in json['standar_dicek'] as List<dynamic>? ?? const []) {
      if (baris is! Map<String, dynamic>) continue;
      final id = (baris['standard_id'] as num?)?.toInt();
      if (id == null) continue;
      dicek[id] = (
        dipakai: baris['dipakai'] as bool? ?? false,
        keterangan: baris['keterangan'] as String?,
      );
    }

    final tanggalTerima = json['tanggal_terima'] as String?;

    return IsianTeknisi(
      equipmentId: ((json['equipment'] as Map<String, dynamic>?)?['id'] as num?)
          ?.toInt(),
      standardId:
          ((json['standar_acuan'] as Map<String, dynamic>?)?['id'] as num?)
              ?.toInt(),
      roomId: ((json['ruangan'] as Map<String, dynamic>?)?['id'] as num?)
          ?.toInt(),
      thermohygroStandardId:
          ((json['thermohygro'] as Map<String, dynamic>?)?['id'] as num?)
              ?.toInt(),
      tanggalTerima: tanggalTerima == null
          ? null
          : DateTime.tryParse(tanggalTerima),
      lokasi: json['lokasi'] as String?,
      lokasiNama: json['lokasi_nama'] as String?,
      catatanTeknisi: json['catatan_teknisi'] as String?,
      spesifikasiAlat: {
        for (final e in (json['spesifikasi_alat'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .entries)
          if (e.value != null) e.key: '${e.value}',
      },
      alatModel: json['alat_model'] as String?,
      alatSerialNumber: json['alat_serial_number'] as String?,
      alatMerk: json['alat_merk'] as String?,
      pemilikNama: json['pemilik_nama'] as String?,
      pemilikAlamat: json['pemilik_alamat'] as String?,
      suhuAwal: (json['suhu_awal'] as num?)?.toDouble(),
      suhuAkhir: (json['suhu_akhir'] as num?)?.toDouble(),
      kelembabanAwal: (json['kelembaban_awal'] as num?)?.toDouble(),
      kelembabanAkhir: (json['kelembaban_akhir'] as num?)?.toDouble(),
      tekananAwal: (json['tekanan_awal'] as num?)?.toDouble(),
      tekananAkhir: (json['tekanan_akhir'] as num?)?.toDouble(),
      standarDicek: dicek,
      revisiField: {
        for (final k in json['revisi_field'] as List<dynamic>? ?? const [])
          '$k',
      },
      catatanRevisi: json['catatan_revisi'] as String?,
    );
  }
}

class CalibrationDetail {
  const CalibrationDetail({
    required this.id,
    required this.namaAlat,
    required this.namaTeknisi,
    required this.tanggalKalibrasi,
    required this.status,
    this.profil,
    this.keputusan,
    this.certificateId,
    this.catatanRevisi,
    this.desimal = 4,
    this.nomorSesi,
    this.standarAcuan,
    this.suhuRuang,
    this.kelembaban,
    this.lokasi,
    this.sertifikat,
    this.kondisiLingkungan,
    this.titik = const [],
    this.titikSebelum = const [],
    this.pembacaanMentah = const [],
    this.perluVerifikasi = false,
    this.isianTeknisi,
    this.autoclave,
  });

  final int id;
  final String namaAlat;

  /// Kode profil lembar kerja sesi ini (`tits`, `conductivity_meter`, …), dari
  /// `equipment.profil`.
  ///
  /// Backend yang meresolusinya, bukan layar. [namaAlat] itu nama alat
  /// PELANGGAN dan bentuknya bebas — sesi TITS di master bernama "Temperature
  /// Calibrator" dan "Temperature Recorder Controller", nol kemiripan sama
  /// "Temperature Indicator tanpa Sensor" yang jadi kunci pencocokan
  /// profilnya. Nebak dari nama itu bikin sesi TITS yang dibuka lagi dapat
  /// formulir pH: 3 titik 4/7/10,01 di atas lembar suhu 9 titik −20…1000 °C,
  /// tanpa satu pun error muncul.
  ///
  /// Null = server lama yang belum ngirim kunci ini; pemanggil balik nebak
  /// dari [namaAlat] seperti dulu.
  final String? profil;
  final String namaTeknisi;
  final DateTime tanggalKalibrasi;
  final CalibrationStatus status;
  final Keputusan? keputusan;
  final int? certificateId;
  final String? catatanRevisi;

  /// Berapa desimal angka hasil dibulatkan.
  ///
  /// Dikirim backend (`data.desimal`), diturunin dari resolusi alat dan bisa
  /// ditimpa pengaturan organisasi. **Jangan diturunin sendiri dari
  /// `equipment.resolusi`** — itu cocok buat kasus biasa tapi meleset begitu
  /// organisasi nyetel timpaan, dan mobile nggak punya cara tau setelan itu ada.
  ///
  /// Nilai di sini **hidup** (ikut pengaturan yang berlaku sekarang), beda dari
  /// `CertificateSnapshot.desimal` yang **beku**. Itu disengaja: sesi belum
  /// punya dokumen resmi, sertifikat yang udah terbit nggak boleh berubah
  /// bentuk gara-gara pengaturan diubah sesudahnya.
  final int desimal;

  final String? nomorSesi;
  final StandardRef? standarAcuan;
  final double? suhuRuang;
  final double? kelembaban;
  final String? lokasi;
  final CertificateRef? sertifikat;

  /// Rincian awal/akhir + U95% lingkungan. Null buat sesi yang cuma ngirim
  /// satu angka suhu/kelembaban — pakai [suhuRuang]/[kelembaban] buat itu.
  final KondisiLingkungan? kondisiLingkungan;

  /// Bahan buat ngisi ulang formulir waktu sesi dibuka lagi (lanjut draft /
  /// perbaiki yang ditolak). Lihat [IsianTeknisi].
  final IsianTeknisi? isianTeknisi;

  /// Kosong kalau sesi belum lewat kalkulasi backend (`draft` yang belum
  /// pernah disubmit).
  final List<MeasurementResult> titik;

  /// Ringkasan as-found per titik. Kosong kalau sesi ini nggak nyatet
  /// pembacaan sebelum adjustment (alat non-pH umumnya nggak).
  final List<MeasurementBefore> titikSebelum;

  /// Baris pembacaan asli per titik — cuma ikut di respons detail (bukan
  /// daftar). Dikelompokkan manual per `titikKe` + `tahap` di UI.
  final List<RawMeasurement> pembacaanMentah;

  /// Masih ada pembacaan OCR yang belum dikonfirmasi teknisi — selama `true`,
  /// sesi ini ditolak backend waktu di-approve.
  final bool perluVerifikasi;

  /// Hasil Autoklaf (Section A/B/C), kalau sesi ini Autoklaf. `null` di alat
  /// lain — mereka pakai [titik]. Autoklaf `titik`-nya kosong; layar detail
  /// mbranch ke sini biar sesi tersimpan bisa direview sebelum approve.
  final AutoclaveHasil? autoclave;

  /// STDEV terbesar antar titik — kolom **MAX STDEV** di worksheet asli
  /// (`DATA HASIL KALIBRASI`), dihitung di sini karena backend nggak
  /// ngirimnya: dia cuma turunan `max()` dari `standar_deviasi` tiap titik,
  /// bukan besaran baru yang butuh data mentah.
  ///
  /// Dipisah sebelum/sesudah adjustment karena di worksheet emang dua tabel
  /// terpisah dengan MAX STDEV masing-masing — nyampur keduanya bikin angka
  /// as-found yang jelek (mis. 0,144) kebawa ke tabel as-left yang udah rapi
  /// (0,005), padahal yang disertifikasi cuma yang as-left.
  ///
  /// `null` kalau titiknya belum dihitung backend — bukan `0`, biar layar bisa
  /// bedain "belum ada data" dari "sebarannya nol".
  double? get maxStdev => _maks(titik.map((t) => t.standarDeviasi));

  double? get maxStdevSebelum =>
      _maks(titikSebelum.map((t) => t.standarDeviasi));

  static double? _maks(Iterable<double> nilai) =>
      nilai.isEmpty ? null : nilai.reduce((a, b) => a > b ? a : b);

  factory CalibrationDetail.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final standar = json['standar_acuan'] as Map<String, dynamic>?;
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    final lingkungan = json['kondisi_lingkungan'] as Map<String, dynamic>?;
    final titikJson = json['titik'] as List<dynamic>? ?? const [];
    final sebelumJson = json['titik_sebelum'] as List<dynamic>? ?? const [];
    final pembacaanJson = json['pembacaan_mentah'] as List<dynamic>? ?? const [];

    return CalibrationDetail(
      id: (json['id'] as num).toInt(),
      namaAlat: equipment?['nama_alat'] as String? ?? '—',
      profil: equipment?['profil'] as String?,
      namaTeknisi: teknisi?['nama'] as String? ?? '—',
      tanggalKalibrasi: DateTime.parse(json['tanggal_kalibrasi'] as String),
      status: CalibrationStatusJson.fromJson(json['status'] as String),
      keputusan: switch (hasil?['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      certificateId: (json['certificate_id'] as num?)?.toInt(),
      catatanRevisi: json['catatan_revisi'] as String?,
      desimal: (json['desimal'] as num?)?.toInt() ?? 4,
      nomorSesi: json['nomor_sesi'] as String?,
      standarAcuan: standar == null ? null : StandardRef.fromJson(standar),
      suhuRuang: (json['suhu_ruang'] as num?)?.toDouble(),
      kelembaban: (json['kelembaban'] as num?)?.toDouble(),
      lokasi: json['lokasi'] as String?,
      isianTeknisi: IsianTeknisi.fromJson(json),
      sertifikat: sertifikat == null ? null : CertificateRef.fromJson(sertifikat),
      kondisiLingkungan: lingkungan == null
          ? null
          : KondisiLingkungan.fromJson(lingkungan),
      titik: parseListAman(titikJson, MeasurementResult.fromJson),
      titikSebelum: parseListAman(sebelumJson, MeasurementBefore.fromJson),
      pembacaanMentah: parseListAman(pembacaanJson, RawMeasurement.fromJson),
      perluVerifikasi: json['perlu_verifikasi'] as bool? ?? false,
      autoclave: json['hasil_autoclave'] is Map<String, dynamic> &&
              (json['hasil_autoclave'] as Map).isNotEmpty
          ? AutoclaveHasil.fromJson(json['hasil_autoclave'] as Map<String, dynamic>)
          : null,
    );
  }
}
