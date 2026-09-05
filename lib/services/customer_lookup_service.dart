import '../models/customer_lookup.dart';
import '../models/perusahaan_direktori.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Servernya menemukan pelanggan yang MIRIP, jadi barisnya belum dibikin.
///
/// Bukan kegagalan: ini justru jalan keluarnya. Nama yang cuma beda tanda baca
/// (`PT. Maju Jaya` lawan `PT Maju Jaya`) lolos unique index yang jalan di teks
/// mentah, dan kembar di situ bikin riwayat kalibrasi satu perusahaan terbelah
/// — yang kelihatan di layar cuma separuhnya. Kandidatnya ditunjukkan dulu biar
/// teknisi bisa memilih yang sudah ada.
class PelangganMiripException implements Exception {
  const PelangganMiripException({
    required this.pesan,
    required this.kandidat,
    required this.namaPersisSudahAda,
  });

  final String pesan;
  final List<CustomerLookup> kandidat;

  /// Nama yang PERSIS sama sudah ada. Bedanya penting: keadaan ini buntu —
  /// ditahan unique index di database, dan `tetapBuat` nggak menembusnya.
  /// Tombol "ini perusahaan lain" yang muncul di sini cuma bikin teknisi
  /// menabrak penolakan yang sama berkali-kali.
  final bool namaPersisSudahAda;
}

/// Pencarian direktori luar nggak bisa dipakai sekarang.
///
/// Dipisah dari "nol hasil" dengan sengaja. Nol hasil artinya "cari lagi dengan
/// kata lain"; ini artinya "jangan percaya layar ini sekarang". Disamakan,
/// teknisi mendaftarkan ulang PT yang sebenarnya ada di direktori cuma karena
/// key-nya belum disetel atau jaringannya lagi jelek.
class DirektoriTidakSiapException implements Exception {
  const DirektoriTidakSiapException(this.pesan, {required this.belumDisetel});

  final String pesan;

  /// `true` = setelan server (API key kosong), `false` = direktorinya nggak
  /// bisa dihubungi. Yang pertama nggak akan sembuh dengan mencoba lagi.
  final bool belumDisetel;
}

/// Daftar pelanggan buat **dropdown** — bukan layanan CRUD Pelanggan
/// (itu [CustomerService], khusus layar Pelanggan yang admin-only).
abstract class CustomerLookupService {
  Future<List<CustomerLookup>> cari(String token, {String? search});

  /// Cari nama & alamat perusahaan di direktori LUAR — dipakai waktu [cari] nol
  /// hasil, yaitu waktu pelanggannya beneran belum pernah masuk master lab.
  ///
  /// Lewat server, bukan HP nembak penyedianya langsung: API key-nya nggak
  /// boleh ada di dalam APK — key di aplikasi bisa dicabut siapa pun dari
  /// berkasnya lalu dipakai orang lain atas tagihan lab ini.
  ///
  /// Melempar [DirektoriTidakSiapException] kalau direktorinya belum disetel
  /// atau lagi mati — sengaja BUKAN daftar kosong.
  Future<HasilDirektori> cariDirektori(String token, {required String search});

  /// Daftarkan pelanggan baru dari lapangan. Langsung kepakai, tanpa antrean
  /// persetujuan admin.
  ///
  /// Melempar [PelangganMiripException] kalau ada yang mirip. [tetapBuat]
  /// menembusnya — tapi cuma kemiripan, bukan nama yang persis sama.
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  });
}

/// Nembak `GET /api/customers/lookup` — sengaja **bukan** `GET /api/customers`,
/// dan sejak 27 Agt sengaja **bukan** `GET /api/arsip/perusahaan` juga.
///
/// `/customers` itu admin-only, padahal `POST /equipments` boleh dipakai
/// teknisi. Waktu dropdown pelanggan di form Tambah Alat masih narik dari
/// `/customers`, hasilnya: form-nya jalan mulus waktu dites pakai akun admin,
/// tapi di akun teknisi request-nya ditolak 403 → dropdown kosong. Dan karena
/// `pelanggan_id` itu **wajib**, teknisi jadi nggak bisa nyimpen alat sama
/// sekali — mentok di form tanpa penjelasan.
///
/// ## Kenapa pindah dari `/arsip/perusahaan`
///
/// Jawaban pertamanya `/arsip/perusahaan`, dan itu keliru dengan cara yang
/// nggak kelihatan: endpoint itu ngelist **FOLDER**, bukan pelanggan. Empat
/// akibatnya, dan yang pertama paling berat:
///
/// | | Akibatnya |
/// |---|---|
/// | `id` yang datang itu **id folder** | Folder id 1 bisa milik pelanggan id 3. `pelanggan_id` yang kekirim sah tapi nunjuk PT LAIN — alatnya kesimpen ke pelanggan yang salah, nol error di sepanjang jalur |
/// | Folder cuma ada buat PT yang udah pernah punya sertifikat | Pelanggan BARU — justru yang paling sering diinput — nggak nongol sama sekali |
/// | Daftarnya disaring lagi per-role | Teknisi biasa cuma dikasih lihat folder yang ada berkasnya buat dia; sering **nol baris**, persis kegagalan 403 yang tadi mau dihindarin |
/// | `?search=` diabaikan | Server itu baca `q`, bukan `search`. Daftarnya balik utuh tiap ketik — kelihatan kayak pencariannya rusak |
///
/// `/customers/lookup` kebuka semua role, mulangin `customers.id` yang benar,
/// ngirim `alamat`, dan `?search=`-nya nyari **nama ATAU alamat**.
class ApiCustomerLookupService implements CustomerLookupService {
  ApiCustomerLookupService(this._api);

  final ApiClient _api;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    final path = search == null || search.isEmpty
        ? '/customers/lookup'
        : '/customers/lookup?search=${Uri.encodeQueryComponent(search)}';

    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return parseListAman(data, CustomerLookup.fromJson);
  }

  @override
  Future<HasilDirektori> cariDirektori(
    String token, {
    required String search,
  }) async {
    try {
      final json = await _api.get(
        '/customers/direktori?search=${Uri.encodeQueryComponent(search)}',
        token: token,
      );
      final data = (json['data'] as List<dynamic>? ?? const []);

      return (
        daftar: parseListAman(data, PerusahaanDirektori.fromJson),

        // Dibaca dari amplop, BUKAN dari tiap baris — dan bukan dikarang di
        // sini. Lihat docblock [HasilDirektori]: ini kewajiban lisensi yang
        // hilangnya nggak ninggalin error.
        //
        // `as String?` yang longgar disengaja: server memulangkan `null` kalau
        // penyedianya nggak mensyaratkan apa-apa, dan itu bukan kerusakan.
        atribusi: json['atribusi'] as String?,
      );
    } on ApiException catch (e) {
      // 503 = key-nya belum disetel di server; 502 = direktorinya nggak nyaut.
      // Keduanya dipisah dari nol hasil, dan dipisah satu sama lain: yang
      // pertama nggak akan sembuh dengan mencoba lagi, jadi layarnya nggak
      // boleh nawarin "coba lagi" di situ.
      if (e.status == 503 || e.status == 502) {
        throw DirektoriTidakSiapException(
          e.message,
          belumDisetel: e.status == 503,
        );
      }
      rethrow;
    }
  }

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) async {
    try {
      final json = await _api.post(
        '/customers/cepat',
        token: token,
        body: {
          'nama': nama,
          if (alamat != null && alamat.trim().isNotEmpty) 'alamat': alamat.trim(),
          'direktori_ref': ?direktoriRef,
          if (tetapBuat) 'tetap_buat': true,
        },
      );

      return CustomerLookup.fromJson(json['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status != 409) rethrow;

      throw PelangganMiripException(
        pesan: e.message,
        kandidat: parseListAman(
          e.body['kandidat'] as List<dynamic>? ?? const [],
          CustomerLookup.fromJson,
        ),
        namaPersisSudahAda: e.body['nama_persis_sudah_ada'] == true,
      );
    }
  }
}

/// Data tiruan buat test.
///
/// Menirukan **aturan servernya**, bukan cuma bentuk datanya: kemiripan nama,
/// penolakan nama yang persis sama, dan bedanya "direktori belum disetel" dari
/// "nol hasil". Mock yang cuma mulangin daftar bikin build offline kelihatan
/// benar padahal jalur yang beneran dipakai teknisi belum pernah dijalankan.
class MockCustomerLookupService implements CustomerLookupService {
  MockCustomerLookupService({
    this.gagal = false,
    this.direktoriBelumDisetel = false,
    this.direktoriMati = false,
  });

  final bool gagal;

  /// Menirukan server yang `DIREKTORI_PERUSAHAAN_KEY`-nya kosong.
  final bool direktoriBelumDisetel;

  /// Menirukan direktori luar yang nggak bisa dihubungi.
  final bool direktoriMati;

  /// Pelanggan yang didaftarkan lewat [daftarkan] nempel di sini, jadi
  /// pencarian sesudahnya menemukannya — persis kayak server.
  final List<CustomerLookup> _tambahan = [];

  /// Sama dengan `Customer::normalkanNama()` di server: huruf besar-kecil,
  /// tanda baca, dan spasi ganda diratakan. Bentuk badan usaha (PT/CV) SENGAJA
  /// nggak dibuang — `PT Maju` dan `CV Maju` dua badan hukum berbeda.
  static String _normal(String nama) => nama
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    if (gagal) throw Exception('server nggak nyaut');

    final semua = [..._bawaan, ..._tambahan];
    if (search == null || search.isEmpty) return semua;

    // Nyari nama ATAU alamat, sama kayak `CustomerController::lookup()`. Mock
    // yang cuma nyari nama bikin build offline kelihatan beda dari server.
    final q = search.toLowerCase();
    final qNormal = _normal(search);

    return semua
        .where(
          (c) =>
              c.nama.toLowerCase().contains(q) ||
              (c.alamat ?? '').toLowerCase().contains(q) ||
              // Lawan tanda baca, sama kayak server: yang tersimpan
              // `PT. Maju Jaya` sementara teknisi mengetik `PT Maju Jaya`.
              (qNormal.isNotEmpty && _normal(c.nama).contains(qNormal)),
        )
        .toList();
  }

  @override
  Future<HasilDirektori> cariDirektori(
    String token, {
    required String search,
  }) async {
    if (direktoriBelumDisetel) {
      throw const DirektoriTidakSiapException(
        'Pencarian direktori perusahaan belum disetel di server ini. '
        'Ketik nama & alamat PT-nya manual dulu.',
        belumDisetel: true,
      );
    }
    if (direktoriMati) {
      throw const DirektoriTidakSiapException(
        'Direktori perusahaan lagi nggak bisa dihubungi. '
        'Ketik nama & alamat PT-nya manual dulu.',
        belumDisetel: false,
      );
    }

    const direktori = [
      PerusahaanDirektori(
        ref: 'tempat-sinar-rejeki',
        nama: 'PT Sinar Rejeki Manufaktur',
        alamat: 'Kawasan Industri MM2100 Blok C-3, Cikarang Barat, Bekasi',
      ),
      PerusahaanDirektori(
        ref: 'tempat-sinar-terang',
        nama: 'PT Sinar Terang Kimia',
        alamat: 'Jl. Raya Serang KM 12, Cikupa, Tangerang',
      ),
      // Sengaja tanpa alamat: nggak semua tempat di direktori punya alamat
      // tertulis, dan layarnya harus tetap benar di situ.
      PerusahaanDirektori(ref: 'tempat-tanpa-alamat', nama: 'PT Bumi Sentosa'),
    ];

    final q = search.toLowerCase();

    return (
      daftar: direktori
          .where(
            (d) =>
                d.nama.toLowerCase().contains(q) ||
                (d.alamat ?? '').toLowerCase().contains(q),
          )
          .toList(),

      // Mock-nya ikut memajang atribusi, dan sengaja atribusi OSM: itu yang
      // dipulangkan server dengan setelan bawaannya. Mock yang memulangkan
      // `null` bikin build offline kelihatan benar padahal barisnya hilang —
      // dan barisnya yang justru diwajibkan lisensi.
      atribusi: '© OpenStreetMap contributors',
    );
  }

  @override
  Future<CustomerLookup> daftarkan(
    String token, {
    required String nama,
    String? alamat,
    String? direktoriRef,
    bool tetapBuat = false,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    final bersih = nama.trim();
    final normal = _normal(bersih);
    final semua = [..._bawaan, ..._tambahan];

    final kandidat = semua.where((c) => _normal(c.nama) == normal).toList();
    final namaPersisSudahAda = kandidat.any((c) => c.nama == bersih);

    // Urutan syaratnya sama kayak server: nama yang PERSIS sama tetap buntu
    // walau `tetapBuat` dinyalakan — yang menahan di sana unique index di
    // database, bukan aturan yang bisa ditembus.
    if (kandidat.isNotEmpty && (namaPersisSudahAda || !tetapBuat)) {
      throw PelangganMiripException(
        pesan: namaPersisSudahAda
            ? 'Pelanggan dengan nama ini sudah ada.'
            : 'Ada pelanggan dengan nama yang mirip.',
        kandidat: kandidat,
        namaPersisSudahAda: namaPersisSudahAda,
      );
    }

    final baru = CustomerLookup(
      id: 1000 + _tambahan.length,
      nama: bersih,
      alamat: alamat == null || alamat.trim().isEmpty ? null : alamat.trim(),
    );
    _tambahan.add(baru);

    return baru;
  }

  static const _bawaan = [
    CustomerLookup(
      id: 1,
      nama: 'PT Maju Jaya',
      alamat: 'Jl. Raya Bekasi KM 27, Cikarang, Bekasi',
    ),
    CustomerLookup(
      id: 2,
      nama: 'CV Sentosa Abadi',
      alamat: 'Jl. Industri Selatan Blok C-12, Cikarang, Bekasi',
    ),
    // Sengaja tanpa alamat: kolomnya boleh kosong di master, dan layarnya
    // harus tetap benar di situ.
    CustomerLookup(id: 3, nama: 'PT Industri Presisi'),
  ];
}
