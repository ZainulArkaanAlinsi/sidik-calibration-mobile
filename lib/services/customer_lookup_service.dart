import '../models/customer_lookup.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

/// Daftar pelanggan buat **dropdown** — bukan layanan CRUD Pelanggan
/// (itu [CustomerService], khusus layar Pelanggan yang admin-only).
abstract class CustomerLookupService {
  Future<List<CustomerLookup>> cari(String token, {String? search});
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
}

/// Data tiruan buat test.
class MockCustomerLookupService implements CustomerLookupService {
  MockCustomerLookupService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    if (gagal) throw Exception('server nggak nyaut');

    const semua = [
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

    if (search == null || search.isEmpty) return semua;

    // Nyari nama ATAU alamat, sama kayak `CustomerController::lookup()`. Mock
    // yang cuma nyari nama bikin build offline kelihatan beda dari server.
    final q = search.toLowerCase();
    return semua
        .where(
          (c) =>
              c.nama.toLowerCase().contains(q) ||
              (c.alamat ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}
