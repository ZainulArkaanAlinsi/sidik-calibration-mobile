import '../models/autoclave_hasil.dart';
import 'api_client.dart';
import 'equipment_lookup_service.dart' show namaAlatMock;
import 'mock_store.dart';

/// Olah data Autoklaf lewat `POST /api/calibrations/autoclave/preview`.
///
/// Endpoint terpisah dari `/calibrations/preview` karena bentuk data Autoklaf
/// (3 disk suhu × titik waktu + 1 titik tekanan berkonversi satuan) nggak muat
/// di model "titik ukur + pengulangan" alat lain. Tabel kalibrator & CMC ada di
/// server; payload cuma data ukur teknisi.
abstract class AutoclaveService {
  /// [payload] = data ukur mentah, dirakit `LembarKerjaState.payloadMatriks`
  /// dari jalur `kode_data` yang dikirim backend di `bagian.matriks`.
  Future<AutoclaveHasil> pratinjau(String token, Map<String, dynamic> payload);

  /// Simpan sesi Autoklaf BARU (`POST /calibrations/autoclave`). [payload]
  /// gabungan identitas (equipment_id, tanggal, kondisi lingkungan) + data
  /// ukur. Balik id sesi tersimpan.
  Future<int> simpan(String token, Map<String, dynamic> payload);

  /// Perbarui sesi Autoklaf yang SUDAH ADA (`PUT /calibrations/autoclave/{id}`)
  /// — lanjut draft, atau perbaiki yang dikembalikan admin.
  ///
  /// Bodinya sama persis dengan [simpan]. Dipisah karena draft yang dibuka
  /// ulang lalu disimpan lewat `POST` melahirkan sesi KEMBAR: lembar yang
  /// dibuka ulang membawa `client_request_id` baru, jadi server nggak punya
  /// cara mengenalinya sebagai sesi yang sama.
  Future<int> perbarui(String token, int id, Map<String, dynamic> payload);
}

class ApiAutoclaveService implements AutoclaveService {
  ApiAutoclaveService(this._api);

  final ApiClient _api;

  @override
  Future<AutoclaveHasil> pratinjau(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final json = await _api.post(
      '/calibrations/autoclave/preview',
      token: token,
      body: payload,
    );
    return AutoclaveHasil.fromJson(json);
  }

  @override
  Future<int> simpan(String token, Map<String, dynamic> payload) async {
    final json = await _api.post(
      '/calibrations/autoclave',
      token: token,
      body: payload,
    );
    return _idDari(json);
  }

  @override
  Future<int> perbarui(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    final json = await _api.put(
      '/calibrations/autoclave/$id',
      token: token,
      body: payload,
    );
    return _idDari(json);
  }

  int _idDari(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Satu panggilan simpan yang tercatat di [MockAutoclaveService].
typedef PanggilanSimpanAutoclave = ({
  String metode,
  int? id,
  Map<String, dynamic> payload,
});

/// Tiruan buat mode mock & test.
///
/// **Nggak ngarang angka olah data.** [pratinjau] cuma memulangkan set point
/// yang dikirim — hasil Autoklaf (rata-rata disk, U95, konversi tekanan) itu
/// hitungan server yang diadu ke master Excel, dan angka karangan di build
/// mock gampang disangka angka beneran.
///
/// [simpan] meniru dedup server: `client_request_id` yang sama memulangkan
/// sesi yang SAMA, bukan sesi baru — persis yang dijanjikan
/// `CalibrationController::replay` di backend.
class MockAutoclaveService implements AutoclaveService {
  MockAutoclaveService({this.gagal = false});

  final bool gagal;

  /// Semua simpan/perbarui yang pernah dicoba, termasuk yang gagal.
  final List<PanggilanSimpanAutoclave> panggilan = [];

  final Map<String, int> _idPerClientRequest = {};

  @override
  Future<AutoclaveHasil> pratinjau(
    String token,
    Map<String, dynamic> payload,
  ) async {
    if (gagal) throw Exception('server nggak nyaut');

    return AutoclaveHasil(setPoint: (payload['set_point'] as num?)?.toDouble());
  }

  @override
  Future<int> simpan(String token, Map<String, dynamic> payload) async {
    panggilan.add((metode: 'POST', id: null, payload: payload));
    if (gagal) throw Exception('server nggak nyaut');

    final cid = payload['client_request_id'] as String?;
    final lama = cid == null ? null : _idPerClientRequest[cid];
    if (lama != null) return lama;

    final equipmentId = (payload['equipment_id'] as num?)?.toInt();
    final id = MockStore.instance.tambahSesi(
      namaAlat:
          '${(equipmentId == null ? null : namaAlatMock(equipmentId)) ?? 'Autoclave'} (sesi baru)',
      namaTeknisi: 'Teknisi',
      draft: payload['status'] == 'draft',
    );
    if (cid != null) _idPerClientRequest[cid] = id;

    await MockStore.instance.tungguTersimpan();

    return id;
  }

  @override
  Future<int> perbarui(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    panggilan.add((metode: 'PUT', id: id, payload: payload));
    if (gagal) throw Exception('server nggak nyaut');

    // Status sesinya ikut aturan server — lihat `MockStore.perbarui`.
    MockStore.instance.perbarui(id, draft: payload['status'] == 'draft');
    await MockStore.instance.tungguTersimpan();

    return id;
  }
}
