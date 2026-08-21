import 'mock_store.dart';
import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import '../models/pratinjau_hitung.dart';
import 'api_client.dart';
import 'equipment_lookup_service.dart';

/// Lembar kerja teknisi: ambil bentuk formulirnya, kirim isiannya.
abstract class LembarKerjaService {
  /// Bentuk formulir dari `GET /api/calibrations/lembar-kerja`. Responsnya
  /// udah disaring per-role di backend, jadi hasilnya beda antara teknisi &
  /// admin — layar nggak perlu nyaring apa-apa lagi.
  ///
  /// [profil] = kode jenis alat (`ph_meter` / `turbidimeter` /
  /// `chlorine_meter`). Backend milih bentuk lembar kerjanya dari sini;
  /// default pH kalau kosong. Lihat `docs/kontrak-api.md` §4.
  ///
  /// [pengulangan] = berapa KOTAK pengulangan yang digambar (2–10). `null` =
  /// pakai bawaan profilnya (5, ngikut form kertas). Ini murni soal tampilan:
  /// rumusnya selalu ngikut berapa kotak yang beneran diisi, jadi ngecilin
  /// kolom nggak ngubah hasil hitungannya.
  /// [equipmentId] bikin backend nyusutin bentuknya ke ALAT ITU: titik yang
  /// punya varian satuan dikirim SATU baris, ngikut satuan di resolusi alat.
  /// Tanpa ini yang kekirim bentuk generik — Conductivity keluar 4 baris dengan
  /// dua varian titik tengah yang saling ngunci, dan satuannya nggak ngikut
  /// alat pelanggan.
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  });

  /// `POST /api/calibrations/preview` — hitung TANPA nyimpen.
  ///
  /// Bodinya identik sama [kirim], jadi nggak ada dua bentuk payload yang harus
  /// dirawat: yang dilihat teknisi di layar dihitung dari kiriman yang sama
  /// persis kayak yang bakal disimpan.
  Future<PratinjauHitung> pratinjau(String token, LembarKerjaSubmission isian);

  /// `POST /api/calibrations` — balikin id sesi yang kebentuk.
  Future<int> kirim(String token, LembarKerjaSubmission isian);

  /// `PUT /api/calibrations/{id}` — lanjut draft atau perbaiki sesi yang
  /// dikembalikan admin.
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian);
}

class ApiLembarKerjaService implements LembarKerjaService {
  ApiLembarKerjaService(this._api);

  final ApiClient _api;

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async {
    final q = <String>[
      if (profil != null && profil.isNotEmpty) 'profil=$profil',
      if (pengulangan != null) 'pengulangan=$pengulangan',
      if (equipmentId != null) 'equipment_id=$equipmentId',
    ];
    final path = '/calibrations/lembar-kerja${q.isEmpty ? '' : '?${q.join('&')}'}';
    final json = await _api.get(path, token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return LembarKerja.fromJson(data);
  }

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) async {
    final json = await _api.post(
      '/calibrations/preview',
      token: token,
      body: isian.toJson(),
    );
    return PratinjauHitung.fromJson(json);
  }

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    final json = await _api.post(
      '/calibrations',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async {
    final json = await _api.put(
      '/calibrations/$id',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  int _idDari(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Tiruan buat test. [payloadTerakhir] nyimpen body yang bakal dikirim ke
/// server — itu yang diperiksa test, bukan tampilannya, karena aturan yang
/// paling gampang rusak diam-diam ada di bentuk payload-nya (sel kosong wajib
/// jadi `null`, bukan dibuang).
class MockLembarKerjaService implements LembarKerjaService {
  MockLembarKerjaService({
    this.gagal = false,
    this.untukAdmin = false,
    this.gagalKirimSampaiPercobaanKe = 0,
    this.tanpaPasanganStandar = false,
  });

  final bool gagal;
  final bool untukAdmin;

  /// Buang `standard_id` dari baris tabel hasil — niru standar yang belum
  /// didaftarin di master lab, atau backend versi lama yang belum ngirim
  /// pasangan titik↔larutan. Layar mesti jatuh ke pilihan manual, bukan
  /// ninggalin titiknya tanpa standar diam-diam.
  final bool tanpaPasanganStandar;

  /// Bikin `kirim`/`perbarui` gagal sampai percobaan ke-n — buat niru sinyal
  /// putus di lapangan, dan mastiin retry-nya bawa `client_request_id` yang
  /// SAMA (kalau berubah, backend bikin sesi dobel).
  final int gagalKirimSampaiPercobaanKe;

  /// Semua payload yang pernah dicoba dikirim, termasuk yang gagal.
  final List<Map<String, dynamic>> payload = [];

  Map<String, dynamic>? get payloadTerakhir =>
      payload.isEmpty ? null : payload.last;

  int get jumlahKirim => payload.length;

  /// Alat yang diminta tiap kali bentuk diambil (`null` = bentuk generik).
  /// Dicatat karena inilah yang nentuin Conductivity keluar 3 baris atau 4:
  /// tanpa ini, dua varian titik tengah muncul bareng dan saling ngunci.
  final List<int?> equipmentIdDiminta = [];

  /// Jumlah kotak pengulangan yang diminta tiap kali bentuk diambil (`null` =
  /// nggak minta apa-apa, pakai bawaan). Dicatat biar test bisa mastiin
  /// pilihan teknisi beneran nyampe ke backend, bukan cuma keganti di layar.
  final List<int?> pengulanganDiminta = [];

  /// Payload tiap kali pratinjau diminta — dipakai test buat mastiin bodinya
  /// sama persis kayak yang dikirim `kirim`, bukan bentuk kedua yang dirawat
  /// terpisah.
  final List<Map<String, dynamic>> payloadPratinjau = [];

  /// Jawaban yang dibalikin [pratinjau].
  ///
  /// Sengaja **dititipin test**, bukan dihitung di sini: begitu mock ngitung
  /// rata-rata/U95 sendiri, repo ini punya implementasi rumus kedua yang bisa
  /// beda diam-diam dari backend — dan angka yang keliatan bener di test justru
  /// jadi bukti palsu. Test spectro ngisinya dari respons ASLI
  /// `POST /api/calibrations/preview`.
  PratinjauHitung? balasanPratinjau;

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) async {
    if (gagal) throw Exception('server nggak nyaut');
    payloadPratinjau.add(isian.toJson());

    return balasanPratinjau ??
        const PratinjauHitung(titik: [], belumDihitung: []);
  }

  @override
  Future<LembarKerja> ambilBentuk(
    String token, {
    String? profil,
    int? pengulangan,
    int? equipmentId,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    pengulanganDiminta.add(pengulangan);
    equipmentIdDiminta.add(equipmentId);

    final bentuk = switch (profil) {
      'turbidimeter' => contohBentukLembarKerjaTurbidi(untukAdmin: untukAdmin),
      'chlorine_meter' => contohBentukLembarKerjaChlorine(untukAdmin: untukAdmin),
      'refractometer' => contohBentukLembarKerjaRefractometer(
        untukAdmin: untukAdmin,
      ),
      'spectrophotometer' => contohBentukLembarKerjaSpectro(
        untukAdmin: untukAdmin,
      ),
      'viscometer' => contohBentukLembarKerjaVisco(untukAdmin: untukAdmin),
      'do_meter' => contohBentukLembarKerjaDo(untukAdmin: untukAdmin),
      'gas_detector' => contohBentukLembarKerjaGas(untukAdmin: untukAdmin),
      'tits' => contohBentukLembarKerjaTits(untukAdmin: untukAdmin),
      // Profil kosong / nggak dikenal SENGAJA jatuh ke pH, bukan lempar error —
      // sama kayak janji kontraknya (`docs/kontrak-api.md` §4).
      _ => contohBentukLembarKerja(untukAdmin: untukAdmin),
    };

    // Niru backend: yang ditulis ulang cuma jumlah KOTAKnya.
    final dipakai = pengulangan == null
        ? bentuk
        : setelKolomPengulanganMock(bentuk, pengulangan);

    return LembarKerja.fromJson(
      tanpaPasanganStandar ? _tanpaPasangan(dipakai) : dipakai,
    );
  }

  /// Salinan bentuk tanpa `standard_id`/`standard_nama` di baris tabel hasil.
  static Map<String, dynamic> _tanpaPasangan(Map<String, dynamic> bentuk) => {
    ...bentuk,
    'bagian': [
      for (final bagian in (bentuk['bagian'] as List).cast<Map<String, dynamic>>())
        {
          ...bagian,
          if (bagian['tabel'] != null)
            'tabel': [
              for (final tabel in (bagian['tabel'] as List).cast<Map<String, dynamic>>())
                {
                  ...tabel,
                  'baris': [
                    for (final baris
                        in (tabel['baris'] as List).cast<Map<String, dynamic>>())
                      {...baris}
                        ..remove('standard_id')
                        ..remove('standard_nama'),
                  ],
                },
            ],
        },
    ],
  };

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    // Dicatat ke ingatan bersama, bukan balikin id karangan: tanpa ini sesi
    // yang barusan dikirim teknisi nggak pernah nongol di antrean approval,
    // dan alur dari lembar kerja sampai sertifikat nggak bisa dicoba sama
    // sekali tanpa backend nyala. Lihat [MockStore].
    //
    // Namanya dibaca dari alat yang DIPILIH, bukan dipatok 'pH Meter': dulu
    // sesi turbidimeter nongol di antrean approval sebagai pH Meter, dan admin
    // yang lagi nyoba alurnya offline nggak punya cara buat sadar itu salah.
    final id = MockStore.instance.tambahSesi(
      namaAlat: '${namaAlatMock(isian.equipmentId) ?? 'Alat'} (sesi baru)',
      namaTeknisi: 'Teknisi',
      draft: isian.simpanSebagaiDraft,
    );

    final hasil = _catat(isian, id);

    // Baru bilang berhasil sesudah sesinya beneran mendarat di disk. Lihat
    // `MockStore.tungguTersimpan`.
    await MockStore.instance.tungguTersimpan();

    return hasil;
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async =>
      _catat(isian, id);

  int _catat(LembarKerjaSubmission isian, int id) {
    // Dicatat DULUAN, baru dilempar errornya — payload percobaan yang gagal
    // itu justru yang mau diperiksa test.
    payload.add(isian.toJson());

    if (gagal || payload.length <= gagalKirimSampaiPercobaanKe) {
      throw Exception('server nggak nyaut');
    }

    return id;
  }
}

/// Tiruan `CalibrationProfile::setelKolomPengulangan()` di backend, buat mode
/// mock & widget test.
///
/// Sengaja niru bentuk keluarannya, bukan aturannya: yang diuji di sisi mobile
/// itu "layarnya ngikut apa pun jumlah kotak yang dikirim backend", bukan
/// "mobile bisa ngitung sendiri berapa kotaknya". Batas 2–10 tetap urusan
/// backend — di sini nggak divalidasi lagi biar nggak ada dua sumber aturan.
Map<String, dynamic> setelKolomPengulanganMock(
  Map<String, dynamic> bentuk,
  int jumlah,
) {
  Object? tulisUlang(Object? simpul) {
    if (simpul is Map<String, dynamic>) {
      return {
        for (final e in simpul.entries)
          e.key: switch (e.key) {
            'jumlah_pengulangan' when e.value is int => jumlah,
            'pengulangan' when e.value is List => List<int>.generate(jumlah, (i) => i + 1),
            _ => tulisUlang(e.value),
          },
      };
    }
    if (simpul is List) return simpul.map(tulisUlang).toList();
    return simpul;
  }

  return tulisUlang(bentuk)! as Map<String, dynamic>;
}

/// Salinan bentuk yang dibalikin `GET /api/calibrations/lembar-kerja`
/// (`LembarKerjaTemplate` di backend). Ditaruh di lib, bukan di test, biar
/// dipakai bareng sama mock — dan biar kalau bentuk backend berubah,
/// ketahuannya dari satu tempat.
Map<String, dynamic> contohBentukLembarKerja({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    // `standard_id` per baris = pasangan tercetak titik↔buffer, dan id-nya
    // sengaja sama persis kayak baris usage check di bawah: itu larutan yang
    // SAMA, cuma dilihat dari dua bagian formulir. Mock yang ngirim id beda
    // bakal bikin layar kelihatan bener padahal ketertelusurannya pecah.
    'baris': [
      {
        'titik_ukur': 4.00,
        'label': '4,00',
        'standard_id': 2,
        'standard_nama': 'pH Buffer Solution 4',
      },
      {
        'titik_ukur': 7.00,
        'label': '7,00',
        'standard_id': 3,
        'standard_nama': 'pH Buffer Solution 7',
      },
      {
        'titik_ukur': 10.01,
        'label': '10,01',
        'standard_id': 4,
        'standard_nama': 'pH Buffer Solution 10',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'pH', 'tipe': 'angka', 'satuan': 'pH'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field(
          'equipment.range_resolusi',
          '2. Range/Resolution',
          'teks',
          sumber: 'otomatis',
          satuan: 'pH',
        ),
        // Tiga kolom ini DIKETIK TEKNISI dari badan alat, bukan disalin
        // master — lihat LembarKerjaTemplate di backend.
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field(
          'thermohygro_standard_id',
          '6. Thermohygro used',
          'pilihan',
          sumber: 'master_thermohygro',
          // Id-nya nunjuk ke `MockStandardService` beneran (40/42/43/41).
          // Dulu 7/11/12/9 — id yang nggak ada isinya di mock, jadi pilihan
          // teknisi nyampe ke payload sebagai standar yang nggak eksis.
          pilihan: [
            {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
            {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
            {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
            {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
          ],
        ),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Lima baris TERCETAK di formulir, bukan katalog standar lab. Baris
      // terakhir sengaja `standard_id: null` — di lab beneran pun standar itu
      // belum kedaftar di master, dan barisnya tetap harus kelihatan.
      'baris': [
        {'label': 'pH Buffer Solutions 4', 'standard_id': 2, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 7', 'standard_id': 3, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 10', 'standard_id': 4, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field(
          'lokasi',
          '1. Location',
          'pilihan',
          pilihan: [
            {'nilai': 'lab', 'label': 'In lab'},
            {'nilai': 'onsite', 'label': 'Insitu'},
          ],
        ),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field(
            'calibration_method_id',
            '2. Calibration Methode',
            'pilihan',
            sumber: 'master_metode',
            hanyaAdmin: true,
          ),
      ],
    },
    {
      'kode': 'hasil',
      // SATU halaman, sama kayak Turbidimeter & Chlorine. Backend udah nggak
      // mecah dua sejak `3ab1d09` ("satu gulungan"), mobile-nya ketinggalan —
      // jadi build mock nampilin tombol "LANJUT KE HALAMAN BERIKUTNYA" yang di
      // build asli nggak ada sama sekali.
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0509_Rev.4',
    'judul': 'Calibration Worksheet - pH Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [4.00, 7.00, 10.01],
    'satuan': 'pH',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Turbidimeter (`?profil=turbidimeter`, `TurbidimeterProfile`
/// di backend). Titik 1/100/1000 NTU dengan resolusi per-titik (0,01/0,1/1),
/// dipakai mock biar alur turbidimeter bisa dicoba tanpa backend.
Map<String, dynamic> contohBentukLembarKerjaTurbidi({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {
        'titik_ukur': 1.0,
        'label': '1',
        'resolusi': 0.01,
        'desimal': 2,
        'standard_id': 20,
        'standard_nama': 'Turbidity Standard 1 NTU',
      },
      {
        'titik_ukur': 100.0,
        'label': '100',
        'resolusi': 0.1,
        'desimal': 1,
        'standard_id': 21,
        'standard_nama': 'Turbidity Standard 100 NTU',
      },
      {
        'titik_ukur': 1000.0,
        'label': '1000',
        'resolusi': 1.0,
        'desimal': 0,
        'standard_id': 22,
        'standard_nama': 'Turbidity Standard 1000 NTU',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'NTU', 'tipe': 'angka', 'satuan': 'NTU'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'NTU'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
              {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      'baris': [
        {'label': 'Turbidity Standard 1 NTU', 'standard_id': 20, 'terdaftar': true},
        {'label': 'Turbidity Standard 100 NTU', 'standard_id': 21, 'terdaftar': true},
        {'label': 'Turbidity Standard 1000 NTU', 'standard_id': 22, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'In lab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0530_Rev.2',
    'judul': 'Calibration Worksheet - Turbidimeter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.0, 100.0, 1000.0],
    'satuan': 'NTU',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Chlorin Meter (`?profil=chlorine_meter`, `ChlorineProfile` di
/// backend). Disalin dari lembar kerja cetaknya, **SIDIK-FM-CAL-0531_Rev.2** —
/// satu halaman (`Page 1 of 1`), metode `SIDIK-IK-CAL-0524`.
///
/// ## Kenapa titiknya 1,74 & 1,83 dan BUKAN 0,40 & 4,00
///
/// Lembar cetak Rev.2 nulis `Solution Standard 0.40` & `4.00`, dan baris
/// STANDARD-nya "Chlorine Std. Solutions 0.4 / 4 mg/l". Tiga sumber lain
/// bilang beda, dan ketiganya lebih baru:
///
/// - **Lampiran akreditasi LK-285-IDN no. 42** (`docs/Rekap-Data-Kemampuan-
///   Kalibrasi.md`, berlaku 28 Okt 2024–27 Okt 2029): titik **1,74** mg/L
///   (CMC 0,091) & **1,83** mg/L (CMC 0,08).
/// - **`Project-PT-Sidik/Chlorine_Meter_CSV/DATABASE.csv`** (snapshot 19 Des
///   2025): Jenis Rentang 1,74 & 1,83 dengan CMC yang sama persis, dan standar
///   fisiknya "Chlorine Standard Solution 1.74 mg/L" (U95 0,09) & "Chlorine
///   Standar Cuvettes 1.83 mg/L" (U95 0,06), dua-duanya Supelco/Merck.
/// - **Sesi asli 0189-CAL-624** (Hanna HI97711, Juni 2024): standarnya 1,74 &
///   1,83, pembacaannya 1,76 & 1,86.
///
/// `FORM_VALIDASI.csv` revisi #6 (3 Apr 2024) nyatet "Update std Chlorine 4
/// mgl (MRA/ISO 17034)" — set standarnya emang sempat gonta-ganti, dan lembar
/// cetak Rev.2 ketinggalan. Yang dipakai di sini yang **ada di lingkup
/// akreditasi**: kalibrasi di titik luar lampiran nggak bisa jadi sertifikat.
/// Diputusin bareng Raihan 5 Agt 2026.
///
/// Beda dari Turbidimeter: resolusinya **seragam** 0,01 mg/L di dua titik, jadi
/// `resolusi`/`desimal` per baris sengaja NGGAK dikirim (null = seragam). Cuma
/// alat yang resolusinya beda per titik yang butuh itu.
Map<String, dynamic> contohBentukLembarKerjaChlorine({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {
        'titik_ukur': 1.74,
        'label': '1,74',
        'standard_id': 30,
        'standard_nama': 'Chlorine Standard Solution 1.74 mg/L',
      },
      {
        'titik_ukur': 1.83,
        'label': '1,83',
        'standard_id': 31,
        'standard_nama': 'Chlorine Standar Cuvettes 1.83 mg/L',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'mg/L', 'tipe': 'angka', 'satuan': 'mg/L'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'mg/L'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro Used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
              {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Dua baris pertama namanya diambil apa adanya dari DATABASE.csv —
      // itu nama standar fisik yang beneran ada di lab, lengkap sama nilai
      // sertifikatnya. Dua baris terakhir sama kayak lembar pH & Turbidimeter.
      'baris': [
        {
          'label': 'Chlorine Standard Solution 1.74 mg/L',
          'standard_id': 30,
          'terdaftar': true,
        },
        {
          'label': 'Chlorine Standar Cuvettes 1.83 mg/L',
          'standard_id': 31,
          'terdaftar': true,
        },
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 6, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0531_Rev.2',
    'judul': 'Calibration Worksheet - Chlorine Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.74, 1.83],
    'satuan': 'mg/L',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Refractometer (`?profil=refractometer`, `RefractometerProfile`
/// di backend). Lembar cetaknya **SIDIK-FM-CAL-0523_Rev.2**, satu halaman.
/// Alat KEEMPAT yang punya lembar sendiri, dan yang paling beda dari tiga
/// sebelumnya.
///
/// ## Kolom °C di sini BUKAN pelengkap
///
/// Di lembar Chlorine, suhu cuma dicatat buat jejak. Di sini dia yang dipakai
/// NGITUNG: indeks bias berubah ikut suhu, jadi pembacaan dinormalisasi dulu ke
/// **20 °C** (huruf "20" di `n20D` itu ini) sebelum diadu ke larutan standar.
///
/// ```
/// Corrected = Observed + 0,00045 × (T − 20)     // n20D
/// Corrected = Observed + 0,07    × (T − 20)     // °Brix
/// ```
///
/// Sesi master `2211.11.R`: titik 1,33659 dibaca `1,3362` pada rata-rata suhu
/// **27 °C** → `1,3362 + 0,00045 × 7` = **1,33935**. Yang kecetak di sertifikat
/// sebagai Unit Under Test itu 1,33935, BUKAN 1,3362. Teknisi yang ngosongin
/// kolom suhu tetap boleh ngirim — backend pakai pembacaan apa adanya, nggak
/// nebak — tapi hasilnya jadi kurang teliti.
///
/// ## Kenapa `desimal`/`resolusi` per baris NGGAK dikirim
///
/// Sama alasannya kayak Chlorine: resolusinya **seragam** 0,0001 n20D di dua
/// titik. Bedanya, di sini itu penting banget — nilai terkoreksinya bisa **5
/// desimal** (`1,33935`) padahal resolusi alatnya 4. Mad ke 4 desimal bikin
/// `1,33935` kecetak `1,3394`, beda dari sertifikat.
///
/// ## Satuan ditanya di depan
///
/// Satu refractometer bisa nampilin n20D atau °Brix, dan pilihannya ngubah
/// SEMUA angka hilirnya (koefisien suhu 0,00045 vs 0,07, titik standar, CMC).
/// Makanya `equipment.satuan` ada di `identitas_alat` — ditanya sebelum teknisi
/// mulai ngisi tabel, bukan ditebak.
Map<String, dynamic> contohBentukLembarKerjaRefractometer({
  bool untukAdmin = false,
}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Larutan fisiknya SAMA, cuma dibaca di skala yang beda: `BSAG2.5-0034`
  // dibaca 2,5 °Brix atau 1,33659 n20D, `BSAG40-0071` dibaca 40 °Brix atau
  // 1,39986 n20D. Angkanya cocok sama CMC yang diseed backend, jadi titiknya
  // tetap dapat budget ketidakpastian.
  const barisN20D = [
    {'titik_ukur': 1.33659, 'label': '1,33659'},
    {'titik_ukur': 1.39986, 'label': '1,39986'},
  ];
  const barisBrix = [
    {'titik_ukur': 2.5, 'label': '2,5'},
    {'titik_ukur': 40.0, 'label': '40'},
  ];

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    // Sengaja tanpa `resolusi`/`desimal` — lihat docblock.
    'baris': barisN20D,
    'baris_per_satuan': {'n20D': barisN20D, '°Brix': barisBrix},
    'kolom': [
      {'kode': 'pembacaan', 'label': 'n20D', 'tipe': 'angka', 'satuan': 'n20D'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        // Tanpa `satuan` — nilainya udah bawa satuannya sendiri ("0–53 °Brix /
        // 0,1 °Brix"), dan alat ini bisa kecatat di skala mana pun. Lihat
        // `RefractometerProfile` di backend.
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro Used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '36', 'label': 'TH-1', 'grup': 'Inlab'},
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '44', 'label': 'TH-5', 'grup': 'Inlab'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
            ]),
        // Pilihannya ikut di field-nya sendiri, jadi layar nggak perlu baca
        // `pilihan_satuan` di akar respons — dua-duanya isinya sama.
        field('equipment.satuan', '7. Satuan Refracto', 'pilihan',
            pilihan: const [
              {'nilai': 'n20D', 'label': 'n20D'},
              {'nilai': '°Brix', 'label': '°Brix'},
            ]),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Satu botol fisik dipakai buat dua satuan sekaligus (BSAG2.5-0034 =
      // 2,5 °Brix DAN 1,33659 n20D), makanya empat baris larutan walau yang
      // dikalibrasi cuma dua titik n20D.
      'baris': [
        {
          'label': 'Refractometer Std Solution 1.33659 n20D',
          'standard_id': 50,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 1.39986 n20D',
          'standard_id': 51,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 2.5 oBrix',
          'standard_id': 52,
          'terdaftar': true,
        },
        {
          'label': 'Refractometer Std Solution 40 oBrix',
          'standard_id': 53,
          'terdaftar': true,
        },
        {
          'label': 'Termometer & Sensor Std.',
          'standard_id': 6,
          'terdaftar': true,
        },
        {'label': 'PT100/SH1', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0523_Rev.2',
    'judul': 'Calibration Worksheet - Refractometer',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [1.33659, 1.39986],
    'satuan': 'n20D',
    'satuan_suhu': '°C',
    'pilihan_satuan': [
      {'nilai': 'n20D', 'label': 'n20D (indeks bias)'},
      {'nilai': '°Brix', 'label': '°Brix (kadar sukrosa)'},
    ],
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim. Suhu tiap pembacaan WAJIB diisi kalau '
        'bisa: tanpa itu pembacaan nggak bisa dinormalisasi ke 20 °C.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Spectrophotometer (`?profil=spectrophotometer`,
/// `SpectrophotometerProfile` di backend). Diambil dari respons ASLI
/// `GET /api/calibrations/lembar-kerja?equipment_id=12` di DB lab, bukan
/// dikarang — angka titiknya persis yang tercetak di master
/// `Master Olah Data_Spectrofotometer.xlsm`.
///
/// Tiga hal di bentuk ini yang nggak ada di lima alat sebelumnya, dan
/// ketiganya pernah bikin layar salah gambar:
///
///  1. **Tiga tabel dalam satu bagian**, masing-masing punya satuan &
///     jumlah pengulangan sendiri. Blok %T dapat **enam** kolom (master nyetak
///     dua baris X1..X3 per nilai standar), sementara `jumlah_pengulangan` di
///     level lembar tetap 3. Layar yang ngambil dari level lembar bakal
///     ngilangin tiga kolom terakhir %T — dan teknisi nggak punya tempat
///     ngetik separuh datanya.
///  2. **`satuan_campuran` berbentuk DAFTAR** (`["nm", "%T"]`), bukan `true`
///     kayak Conductivity. Dua-duanya sah; lihat `_campuran` di
///     `models/lembar_kerja.dart`.
///  3. **Bagian berstatus `sumber_belum_ada`** (SRE) yang tampil tapi nggak
///     nerima input sama sekali.
Map<String, dynamic> contohBentukLembarKerjaSpectro({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Tiap baris bawa `standard_id`-nya sendiri — teknisi NGGAK milih filter per
  // titik. Rentang Holmium (283–641 nm) & Didynium (474–810 nm) tumpang tindih
  // 167 nm, jadi pemilihan manual gampang salah dan salahnya nggak kelihatan
  // dari dokumen hasilnya.
  Map<String, dynamic> tabel(
    String grup,
    String judul,
    String judulNilai,
    String satuan,
    double resolusi,
    int desimal,
    int standardId,
    String standardNama,
    List<double> nilai,
    int pengulangan, {
    Map<String, String>? kolomTetap,
    String? catatan,
  }) => {
    // Alat ini nggak punya tahap adjustment — master-nya cuma sekali baca per
    // titik. `tahap` tetap dikirim backend sebagai identitas kolom isian, dan
    // ketiga tabelnya isinya SAMA. Aman karena tiap titik cuma punya satu
    // tabel; yang misahin isian antar tabel itu titiknya, bukan tahapnya.
    'tahap': 'sesudah_adjustment',
    'grup': grup,
    'judul': judul,
    'satuan': satuan,
    // Bentuk tabel seperti di lembar CETAK: kolom "No.", kepala kolom nilai
    // standar, kepala gabungan kolom angka, dan awalan X1..X3. Blok %T nggak
    // punya kolom "No." — kolom kirinya dipakai `λ (nm)` yang kegabung.
    'nomor_baris': kolomTetap == null,
    'judul_nilai': judulNilai,
    'judul_pengulangan': 'Measurement Result',
    'prefiks_pengulangan': 'X',
    // Enam pengulangan %T digambar DUA baris X1..X3 di kertas.
    'pengulangan_per_baris': 3,
    'kolom_tetap': kolomTetap,
    'catatan': catatan,
    'baris': [
      for (final n in nilai)
        {
          'titik_ukur': n,
          // Ditulis kayak di kertas: satu desimal, koma.
          'label': n.toStringAsFixed(1).replaceAll('.', ','),
          'resolusi': resolusi,
          'desimal': desimal,
          'satuan': satuan,
          'standard_id': standardId,
          'standard_nama': standardNama,
        },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': satuan, 'tipe': 'angka', 'satuan': satuan},
    ],
    'pengulangan': [for (var i = 1; i <= pengulangan; i++) i],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        // DIKETIK TEKNISI, bukan ditarik master alat: alat ini punya DUA skala
        // (`0–100 %T` & `200–700 nm`), sementara `equipments` cuma punya satu
        // satuan + satu pasang rentang, jadi yang otomatis pasti salah separuh.
        field('spesifikasi_alat.rentang_ukur_transmitan', '2. Rentang Ukur',
            'teks', satuan: '%T'),
        field('spesifikasi_alat.rentang_ukur_panjang_gelombang',
            '2. Rentang Ukur', 'teks', satuan: 'nm'),
        field('spesifikasi_alat.kapasitas_maks_transmitan', 'Kapasitas Max.',
            'teks', satuan: '%T'),
        field('spesifikasi_alat.resolusi_transmitan', 'Resolusi Alat', 'teks',
            satuan: '%T'),
        field('spesifikasi_alat.resolusi_panjang_gelombang', 'Resolusi Alat',
            'teks', satuan: 'nm'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro used', 'pilihan',
            sumber: 'master_thermohygro'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      'baris': [
        {
          'label': 'Filter Standard 1 (Holmium Oxide)',
          'standard_id': 25,
          'serial_number': 'SPG080982.A',
          'terdaftar': true,
        },
        {
          'label': 'Filter Standard 2 (Didynium)',
          'standard_id': 26,
          'serial_number': 'SPG080982.B',
          'terdaftar': true,
        },
        {
          'label': 'Filter Standard 3 (Neutral Gas Filter 1,2,3)',
          'standard_id': 27,
          'serial_number': 'SPG080982.C',
          'terdaftar': true,
        },
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'In lab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        // Sertifikat nulis `Insitu (PT. LDC)` — nama tempatnya diketik teknisi.
        field('lokasi_nama', 'Nama Lokasi (kalau Insitu)', 'teks'),
        field('teknisi.kode', 'Technician ID', 'teks', sumber: 'otomatis'),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel(
          'holmium',
          'Wave Length ( λ ) - Filter Holmium',
          'Std Value (λ1)',
          'nm',
          0.01,
          2,
          25,
          'Filter Standard 1',
          const [279.6, 287.7, 334, 360.9, 418.6, 445.8, 453.6, 460, 536.3, 637.9],
          3,
        ),
        tabel(
          'didynium',
          'Wave Length ( λ ) - Filter Didynium',
          'Std Value (λ1)',
          'nm',
          0.01,
          2,
          26,
          'Filter Standard 2',
          const [475.2, 513.7, 529.7, 572.7, 585.7, 684.9, 738.5, 748, 806.1],
          3,
          catatan: '*) Measured at 25°C and with spectral bandwidth 1 nm.',
        ),
        tabel(
          'akurasi_transmitan',
          'Accuracy %T and Linierity at λ = 560nm',
          'Std Value',
          '%T',
          0.001,
          3,
          27,
          'Filter Standard 3',
          const [0, 9.9, 20, 30.1, 100],
          6,
          kolomTetap: const {'label': 'λ (nm)', 'nilai': '560'},
        ),
      ],
    },
    {
      'kode': 'sre',
      'halaman': 1,
      'judul': 'SRE (Stray Radiant Energy)',
      'status': 'sumber_belum_ada',
      'catatan':
          'Belum diimplementasikan: di master, nilai standar SRE hilang '
          '(SERTIFIKAT!C57 & O57 = #REF!), budget-nya #DIV/0! '
          '(PERHITUNGAN U95%!AA65-AA66), faktor cakupannya bukan t-student, dan '
          'CMC-nya nunjuk balik ke hasil hitungnya sendiri. Backend nggak '
          'nyetak angka SRE sampai lab nyediakan lembar sumber yang sah.',
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-IK-CAL-0508_Rev.4',
    'judul': 'Calibration Worksheet - Spectrophotometer',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 3,
    'larutan_standar': const [
      279.6, 287.7, 334, 360.9, 418.6, 445.8, 453.6, 460, 536.3, 637.9,
      475.2, 513.7, 529.7, 572.7, 585.7, 684.9, 738.5, 748, 806.1,
      0, 9.9, 20, 30.1, 100,
    ],
    // Keisi satuan blok PERTAMA, bukan kosong — itu yang dikirim backend, dan
    // `satuan_campuran` di bawahnya yang bilang jangan dipakai buat melabeli.
    'satuan': 'nm',
    'satuan_campuran': const ['nm', '%T'],
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — lembar '
        'kerja tetap bisa dikirim. Tiap kelompok (Holmium / Didynium / %T) '
        'punya SATU U95 bersama yang dihitung dari STDEV terbesar di kelompok '
        'itu, jadi titik yang kosong ngurangin dasar hitungnya.',
    'bagian': bagian,
  };
}

/// Bentuk lembar kerja **Viscometer** (alat ke-7).
///
/// Tanpa ini `MockLembarKerjaService.ambilBentuk` jatuh ke cabang `_` dan
/// mulangin lembar pH Meter buat profil `viscometer` — kartunya udah nongol di
/// picker (`_profilKhusus` + baris CMC di `MockCategoryService`), teknisi
/// natapnya, dan yang kebuka formulir alat lain tanpa satu pun error. Persis
/// kegagalan diam yang bikin commit "alat ke-7 nyambung ke lembar kerja"
/// ditulis, cuma pindah ke jalur offline.
///
/// Bagian `hasil`-nya disalin dari keluaran backend beneran
/// (`test/fixtures/viscometer-bentuk-hasil.json`, dump
/// `ViscometerProfile::bentukLembarKerja()`): dua tabel Before/After yang
/// isinya sama, kolom `cP` + `°C` per Repeat, dan Spindle/RPM/Resolusi PER
/// TITIK. Bagian identitas & penutupnya nyusul pola enam alat lain, karena
/// dump-nya cuma nyimpen bagian hasil.
Map<String, dynamic> contohBentukLembarKerjaVisco({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Tiga titik master lab: nilai sertifikat larutannya (99,65 / 1018 / 59003
  // cP) beda jauh dari label bulat yang TERCETAK di kertas (100 / 1000 /
  // 60000). Bedanya sengaja dipertahankan — itu yang bikin `labelTercetak`
  // ada di jalur foto tabel, dan mock yang meratakan keduanya bakal nutupin
  // bug jangkar yang justru mau dijaga.
  const titik = [
    (nilai: 99.65, label: '100', standardId: 28),
    (nilai: 1018.0, label: '1000', standardId: 29),
    (nilai: 59003.0, label: '60000', standardId: 30),
  ];

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'satuan': 'cP',
    'judul_nilai': 'Standard',
    'judul_pengulangan': 'UUT Reading',
    // `prefiks_pengulangan` sengaja NULL: kertas Rev.3 nyetak kepala kolomnya
    // sebagai nomor polos `1`..`5`, bukan `X1` / `Repeat 1`.
    'baris': [
      for (final t in titik)
        {
          'titik_ukur': t.nilai,
          'label': t.label,
          'resolusi': 0.1,
          'desimal': 1,
          'satuan': 'cP',
          'standard_id': t.standardId,
          'standard_nama': 'Viscosity Standard Solution ${t.label} cP',
        },
    ],
    // Dua sub-kolom per Repeat — pembacaan DAN suhu larutannya, karena nilai
    // acuan larutan diinterpolasi di suhu terukur titik itu.
    'kolom': const [
      {'kode': 'pembacaan', 'label': 'cP', 'tipe': 'angka', 'satuan': 'cP'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': const [1, 2, 3, 4, 5],
  };

  // Daftar spindle dipangkas kayak fixture-nya (aslinya 63 opsi). Yang
  // disisain cuma yang ANGKANYA ada di dokumen lab: HA1/HA2/HA7 dari sesi
  // master (`docs/data-uji-viscometer.md` §3) plus dua RV yang kebawa di dump
  // backend. SMC nggak ditebak dari konvensi Brookfield — salah satu digit di
  // sini nggeser Fullscale ratusan kali dan vonis PASS/FAIL ikut geser.
  const spindle = [
    {'nilai': 'HA1', 'label': 'HA1 (SMC 1)', 'grup': 'HA'},
    {'nilai': 'HA2', 'label': 'HA2 (SMC 4)', 'grup': 'HA'},
    {'nilai': 'HA7', 'label': 'HA7 (SMC 400)', 'grup': 'HA'},
    {'nilai': 'RV1', 'label': 'RV1 (SMC 1)', 'grup': 'RV'},
    {'nilai': 'RV2', 'label': 'RV2 (SMC 4)', 'grup': 'RV'},
  ];

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        // Kode yang sama kayak enam alat lain — `nilaiOtomatis` di
        // `LembarKerjaState` cuma kenal daftar `equipment.*` yang itu, dan kode
        // karangan bakal nampilin kotak kosong selamanya tanpa ngeluh.
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'cP'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro used', 'pilihan',
            sumber: 'master_thermohygro'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'model_viscometer',
      'halaman': 1,
      'judul': 'Model Viscometer',
      // Dipilih SEKALI per sesi, dan dia yang nentuin `TK` di
      // `Fullscale = TK × SMC × 10000 / RPM`. Nggak dipilih → MPE nggak ada →
      // sertifikatnya terbit tanpa vonis PASS/FAIL, bukan ditolak.
      'field': [
        field(
          'spesifikasi_alat.model_viscometer',
          'Model',
          'pilihan',
          // Cuma model yang dipakai sesi master (`TK = 2`) yang ditulis di
          // sini. Model lain ada di backend, tapi TK-nya belum kecatat di
          // dokumen mana pun yang repo ini pegang.
          pilihan: const [
            {'nilai': 'DV2THA', 'label': 'DV2THA / HA (TK 2)'},
          ],
        ),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      'baris': [
        for (final t in titik)
          {
            'label': 'Viscosity Standard Solution ${t.label} cP',
            'standard_id': t.standardId,
            'terdaftar': true,
          },
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: const [
          {'nilai': 'lab', 'label': 'In lab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('lokasi_nama', 'Nama Lokasi (kalau Insitu)', 'teks'),
        field('teknisi.kode', 'Technician ID', 'teks', sumber: 'otomatis'),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'Data Result',
      'field': [
        field('suhu_awal', 'T awal', 'angka', satuan: '°C'),
        field('suhu_akhir', 'T akhir', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'RH awal', 'angka', satuan: '%RH'),
        field('kelembaban_akhir', 'RH akhir', 'angka', satuan: '%RH'),
        // Spindle & RPM PER TITIK, bukan sekali per lembar: sesi master pakai
        // tiga spindle beda dengan dua kecepatan di satu lembar. Urutannya
        // dijaga per titik supaya `_indeksTitik` bisa nempelin tiap set ke
        // tabel titiknya.
        for (var i = 0; i < titik.length; i++) ...[
          field(
            'spesifikasi_alat.spindle_titik_${i + 1}',
            'Spindle — ${titik[i].label} cP',
            'pilihan',
            pilihan: spindle,
          ),
          field(
            'spesifikasi_alat.rpm_titik_${i + 1}',
            'RPM — ${titik[i].label} cP',
            'angka',
            satuan: 'rpm',
          ),
          field(
            'spesifikasi_alat.resolusi_titik_${i + 1}',
            'Resolusi — ${titik[i].label} cP',
            'angka',
            satuan: 'cP',
          ),
        ],
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before Adjustment'),
        tabel('sesudah_adjustment', 'After Adjustment'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0524_Rev.3',
    'kode_metode': 'SIDIK-IK-CAL-0517_Rev.3',
    'judul': 'Calibration Worksheet - Viscometer',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': const [99.65, 1018.0, 59003.0],
    'satuan': 'cP',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — lembar '
        'kerja tetap bisa dikirim. Khusus alat ini: Spindle & RPM tiap titik '
        'ikut nentuin batas keberterimaan (MPE), jadi titik yang dua kolom itu '
        'kosong tetap dihitung U95%-nya tapi nggak dapat vonis PASS/FAIL.',
    'bagian': bagian,
  };
}

/// Bentuk lembar kerja **DO Meter** (alat ke-9).
///
/// Strukturnya kembar dengan Chlorine — jalur generik yang sama, tanpa layar
/// atau endpoint khusus. Yang khas cuma empat hal, dan semuanya gampang salah
/// kalau ditebak dari kertasnya:
///
///  1. **Satu titik: 8,77 mg/L**, bukan 0,00 yang tercetak di formulir. "Zero
///     Oxygen Std. 0.0 mg/l" di kertas itu larutan buat MENOL-KAN alat sebelum
///     diukur, bukan titik kalibrasinya. Pola yang sama dengan Chlorine, yang
///     kertasnya nyetak 0,4/4 tapi titiknya 1,74/1,83.
///  2. **Thermohygro ada di bagian `hasil`**, bukan di identitas alat seperti
///     pH & Chlorine — mengikuti kotak centang TH-2/6/7/4 di kertasnya.
///  3. **Tanpa vonis PASS/FAIL.** Master nggak punya batas keberterimaan dan
///     sertifikatnya nggak mencetak vonis, jadi `keputusan` sesi bakal `null`.
///  4. **`%O2` nggak diolah.** Kertas & master punya kolomnya, tapi seluruh
///     perhitungan %O2 di master rusak (`#DIV/0!` / `#REF!`) — di
///     `SERTIFIKAT` sel U95-nya pun `#REF!`. Backend cuma mengolah mg/L, sama
///     dengan yang benar-benar tercetak di sertifikat, jadi kolom %O2 SENGAJA
///     nggak dibikin di sini.
///
/// `resolusi`/`desimal` per baris sengaja nggak dikirim: resolusinya seragam
/// 0,01 dan "nggak ada" di mobile berarti "pakai resolusi alat". Sama seperti
/// Chlorine.
Map<String, dynamic> contohBentukLembarKerjaDo({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Nilai sertifikat larutannya, bukan angka bulat di kertas. Sesi master
  // `0566-CAL-624` memakai titik ini.
  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {
        'titik_ukur': 8.77,
        'label': '8,77',
        'standard_id': 32,
        'standard_nama': 'Oxygen Standard Solution 8.77 mg/L',
      },
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'mg/L', 'tipe': 'angka', 'satuan': 'mg/L'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'mg/L'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Nama & nomor seri disalin dari blok "Standard used" di master
      // (`SERTIFIKAT` baris 32-34). Larutan 5,51 mg/L ikut terdaftar karena
      // dipakai menol-kan alat, walau bukan titik kalibrasinya.
      'baris': [
        {
          'label': 'Oxygen Standard Solution 8.77 mg/L',
          'standard_id': 32,
          'terdaftar': true,
        },
        {
          'label': 'Oxygen Standard Solution 5.51 mg/L',
          'standard_id': 33,
          'terdaftar': true,
        },
        {
          'label': 'Termometer & Sensor Std.',
          'standard_id': 34,
          'terdaftar': true,
        },
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
        // Di sini, BUKAN di identitas alat — mengikuti kotak centang
        // TH-2/6/7/4 yang tercetak di blok hasil kertasnya.
        field('thermohygro_standard_id', 'Thermohygro Used', 'pilihan',
            sumber: 'master_thermohygro',
            pilihan: const [
              {'nilai': '40', 'label': 'TH-2', 'grup': 'Insitu'},
              {'nilai': '42', 'label': 'TH-6', 'grup': 'Insitu'},
              {'nilai': '43', 'label': 'TH-7', 'grup': 'Insitu'},
              {'nilai': '41', 'label': 'TH-4', 'grup': 'Inlab'},
            ]),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0532_Rev.2',
    'kode_metode': 'SIDIK-IK-CAL-0530_Rev.2',
    'judul': 'Calibration Worksheet - DO Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': const [8.77],
    'satuan': 'mg/L',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — lembar '
        'kerja tetap bisa dikirim. Sertifikat memakai tabel After adjustment; '
        'alat ini nggak dapat vonis PASS/FAIL karena masternya nggak punya '
        'batas keberterimaan.',
    'bagian': bagian,
  };
}

/// Bentuk lembar kerja **Multi Gas Detector** (alat ke-10).
///
/// Disalin dari keluaran `GasDetectorProfile::bentukLembarKerja()`, bukan
/// dikarang dari kertasnya. Tanpa ini mode offline diam-diam menyajikan lembar
/// pH buat profil `gas_detector` — persis kegagalan senyap yang sudah terjadi
/// di Viscometer.
///
/// Empat hal yang beda dari delapan alat lain, dan keempatnya gampang salah
/// kalau ditebak:
///
///  1. **Satuannya campur per baris** — ppm, ppm, %LEL, %. `satuan` di level
///     lembar sengaja `null`; yang benar nempel di tiap baris. Layar sudah
///     mendukung ini (`BarisTabelHasil.satuan`), sama seperti Conductivity.
///  2. **TIGA pengulangan, bukan lima.**
///  3. **Ada tekanan udara awal & akhir (hPa)** — kolom ketiga di tabel
///     Environment Condition, dan cuma alat ini yang punya. Bukan pelengkap:
///     komponen suhu & tekanan di budget-nya lahir dari pergeseran ruangan
///     (Δ = |akhir − awal|), jadi tanpa dua angka itu U95-nya keluar terlalu
///     kecil tanpa satu pun error.
///  4. **Tabelnya cuma kolom Reading** — nggak ada kolom suhu larutan seperti
///     pH/DO, karena yang diukur gas, bukan larutan.
///
/// `kode_dokumen` memang `null`: lembar kerja gas detector belum punya nomor
/// formulir. Yang tercetak di sertifikat metodenya, `SIDIK-IK-CAL-0536_Rev.0`.
Map<String, dynamic> contohBentukLembarKerjaGas({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  // Nilai titiknya konsentrasi sertifikat tabung gasnya, bukan angka bulat
  // yang tertulis di badan alat.
  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': const [
      {
        'titik_ukur': 101.0,
        'label': 'CO',
        'satuan': 'ppm',
        'resolusi': 1.0,
        'desimal': 0,
        'remark': 'Carbon Monoxide (CO)',
      },
      {
        'titik_ukur': 25.0,
        'label': 'H2S',
        'satuan': 'ppm',
        'resolusi': 1.0,
        'desimal': 0,
        'remark': 'Hydrogen Sulfide (H\u2082S)',
      },
      {
        'titik_ukur': 50.0,
        'label': 'CH4',
        'satuan': '%LEL',
        'resolusi': 1.0,
        'desimal': 0,
        'remark': 'Methane (CH4)',
      },
      {
        'titik_ukur': 17.9,
        'label': 'O2',
        'satuan': '%',
        'resolusi': 0.1,
        'desimal': 1,
        'remark': 'Oxygen (O2)',
      },
    ],
    // Satu kolom saja, dan satuannya null di level kolom — yang dipakai
    // satuan per BARIS di atas.
    'kolom': const [
      {'kode': 'pembacaan', 'label': 'Reading', 'tipe': 'angka', 'satuan': null},
    ],
    'pengulangan': const [1, 2, 3],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('alat_merk', '2. Merk/Manufacture', 'teks'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Empat tabung gas + satu thermobarometer. `terdaftar: false` karena
      // master standarnya belum punya barisnya — namanya tetap tercetak di
      // lembar supaya teknisi bisa mencentang apa yang benar-benar dipakai.
      'baris': const [
        {'label': 'Standar Gas Mixture (CO) \u2014 101 ppm', 'terdaftar': false},
        {'label': 'Standar Gas Mixture (H\u2082S) \u2014 25 ppm', 'terdaftar': false},
        {
          'label': 'Standar Gas Mixture (CH4) \u2014 2,5 % (50 %LEL)',
          'terdaftar': false,
        },
        {'label': 'Standar Gas Mixture (O2) \u2014 17,9 %', 'terdaftar': false},
        {'label': 'Thermobarometer Lutron', 'terdaftar': false},
      ],
      'field': [
        field('standar_dicek.*.dipakai', 'Usage Check', 'centang'),
        field('standar_dicek.*.keterangan', 'Keterangan', 'teks'),
      ],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: const [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition \u2014 First', 'angka', satuan: '\u00B0C'),
        field('kelembaban_awal', 'Env. Condition \u2014 First', 'angka',
            satuan: '%RH'),
        field('tekanan_awal', 'Env. Condition \u2014 First', 'angka', satuan: 'hPa'),
        field('suhu_akhir', 'Env. Condition \u2014 End', 'angka', satuan: '\u00B0C'),
        field('kelembaban_akhir', 'Env. Condition \u2014 End', 'angka',
            satuan: '%RH'),
        field('tekanan_akhir', 'Env. Condition \u2014 End', 'angka', satuan: 'hPa'),
        // Namanya "Environmental Meter", bukan "Thermohygro": alat yang
        // dipakai di sini juga membaca tekanan.
        field('thermohygro_standard_id', 'Environmental Meter Used', 'pilihan',
            sumber: 'master_thermohygro'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before Adjustment Reading'),
        tabel('sesudah_adjustment', 'After Adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': null,
    'kode_metode': 'SIDIK-IK-CAL-0536_Rev.0',
    'judul': 'Calibration Worksheet - Multi Gas Detector',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 3,
    'larutan_standar': const [101.0, 25.0, 50.0, 17.9],
    // Sengaja null — lihat docblock, satuannya nempel per baris.
    'satuan': null,
    'satuan_suhu': '\u00B0C',
    'satuan_tekanan': 'hPa',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin \u2014 lembar '
        'kerja tetap bisa dikirim. Khusus alat ini, TEKANAN UDARA awal & akhir '
        'wajib buat dapat ketidakpastian yang benar.',
    'bagian': bagian,
  };
}

/// Bentuk lembar kerja **TITS** (Temperature Indikator Tanpa Sensor, alat
/// ke-11) — salinan respons backend buat mode offline & test widget.
///
/// Empat hal yang cuma alat ini punya, dan semuanya harus ikut di sini kalau
/// nggak test-nya nguji lembar yang beda dari yang dikirim server:
///
///  1. `judul_nilai_per_mode` — kolom Standard & UUT BERTUKAR sisi antar mode.
///  2. `pengulangan_arah` — enam kolom, UP ×3 lalu DOWN ×3.
///  3. `titik_bisa_diubah` — barisnya cuma saran, teknisi yang nyusun.
///  4. `mode_kalibrasi` & `tipe_sensor` — dua dropdown yang nentuin ANGKA.
///
/// Kunci polos `judul_nilai`/`judul_pengulangan`/`pengulangan` sengaja ikut
/// dengan tipe LAMA (string & daftar angka), persis seperti backend: itu yang
/// bikin aplikasi versi lama tetap bisa buka lembarnya.
Map<String, dynamic> contohBentukLembarKerjaTits({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  const titikSaran = [-20.0, 10.0, 50.0, 100.0, 200.0, 400.0, 600.0, 800.0, 1000.0];

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'satuan': '°C',
    'judul_nilai': 'Standard Indication',
    'judul_nilai_per_mode': const {
      'measure': 'Standard Indication',
      'source': 'UUT Indication',
    },
    'judul_pengulangan': 'Reading Unit Under Test',
    'judul_pengulangan_per_mode': const {
      'measure': 'Reading Unit Under Test',
      'source': 'Reading Standard',
    },
    'titik_bisa_diubah': true,
    'baris': [
      for (final t in titikSaran)
        {
          'titik_ukur': t,
          'label': '${t == t.roundToDouble() ? t.toInt() : t} °C',
          'satuan': '°C',
        },
    ],
    'kolom': const [
      {'kode': 'pembacaan', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': const [1, 2, 3, 4, 5, 6],
    'pengulangan_arah': const [
      {'ke': 1, 'arah': 'UP', 'label': 'UP X1'},
      {'ke': 2, 'arah': 'UP', 'label': 'UP X2'},
      {'ke': 3, 'arah': 'UP', 'label': 'UP X3'},
      {'ke': 4, 'arah': 'DOWN', 'label': 'DOWN X1'},
      {'ke': 5, 'arah': 'DOWN', 'label': 'DOWN X2'},
      {'ke': 6, 'arah': 'DOWN', 'label': 'DOWN X3'},
    ],
  };

  final bagian = [
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('alat_merk', '2. Merk/Manufacture', 'teks'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('spesifikasi_alat.rentang_ukur', '5. Rentang Ukur', 'angka',
            satuan: '°C'),
        field('spesifikasi_alat.kapasitas', '6. Kapasitas Alat', 'angka',
            satuan: '°C'),
        field('spesifikasi_alat.resolusi', '7. Resolusi Alat', 'angka',
            satuan: '°C'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('mode_kalibrasi', '1. Mode', 'pilihan', pilihan: const [
          {'nilai': 'measure', 'label': 'Measure (UUT membaca)'},
          {'nilai': 'source', 'label': 'Source (UUT men-source)'},
        ]),
        field('tipe_sensor', '2. Temperature Type', 'pilihan', pilihan: const [
          {'nilai': 'RTD', 'label': 'RTD'},
          {'nilai': 'Type K', 'label': 'Type K'},
          {'nilai': 'Type N', 'label': 'Type N'},
          {'nilai': 'Type B', 'label': 'Type B'},
          {'nilai': 'Type T', 'label': 'Type T'},
          {'nilai': 'Type R', 'label': 'Type R'},
          {'nilai': 'Type S', 'label': 'Type S'},
          {'nilai': 'Type J', 'label': 'Type J'},
        ]),
        field('lokasi', '3. Location', 'pilihan', pilihan: const [
          {'nilai': 'lab', 'label': 'Inlab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '4. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka',
            satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka',
            satuan: '%RH'),
        field('thermohygro_standard_id', 'Environmental Meter Used', 'pilihan',
            sumber: 'master_thermohygro'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before Adjustment Reading'),
        tabel('sesudah_adjustment', 'After Adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': null,
    'kode_metode': 'SIDIK-IK-CAL-0502_Rev.3',
    'judul': 'Calibration Worksheet - Temperature Indicator Tanpa Sensor (TITS)',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    // TIGA per arah, sementara kolom yang digambar enam. Dua angka yang beda
    // artinya, dan backend mengirim dua-duanya.
    'jumlah_pengulangan': 3,
    'arah_pembacaan': const ['UP', 'DOWN'],
    'larutan_standar': titikSaran,
    'satuan': '°C',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — lembar '
        'kerja tetap bisa dikirim. Khusus alat ini, MODE (Measure/Source) dan '
        'TIPE SENSOR wajib dipilih.',
    'bagian': bagian,
  };
}
