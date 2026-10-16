import 'api_client.dart';
import 'equipment_lookup_service.dart' show namaAlatMock;
import 'mock_store.dart';

/// Hasil `POST` pembuat sesi: id-nya, plus status sesi yang DIJAWAB server.
///
/// Statusnya ikut karena server memulangkan sesi LAMA apa adanya waktu
/// `client_request_id`-nya sudah dikenal (replay) — isi kiriman yang baru
/// nggak dibandingkan sama sekali. Pengirim antrean butuh tahu sesi itu masih
/// draft atau sudah lebih jauh sebelum menimpanya.
typedef SesiDibuat = ({int id, String? status});

/// Pengirim ulang draf yang tertahan di HP (antrean offline).
///
/// Bodinya PERSIS yang dulu gagal dikirim layar lembar kerja — endpointnya
/// sama dengan jalur online (`/calibrations` atau `/calibrations/autoclave`),
/// cuma dipanggil tanpa layar.
abstract class PengirimDrafService {
  /// `POST` sesi baru. [matriks] = lembar Autoklaf.
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  });

  /// `PUT` sesi yang sudah ada.
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  });
}

class ApiPengirimDrafService implements PengirimDrafService {
  ApiPengirimDrafService(this._api);

  final ApiClient _api;

  static String _dasar(bool matriks) =>
      matriks ? '/calibrations/autoclave' : '/calibrations';

  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async {
    final json = await _api.post(_dasar(matriks), token: token, body: body);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (id: (data['id'] as num).toInt(), status: data['status'] as String?);
  }

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final json = await _api.put(
      '${_dasar(matriks)}/$id',
      token: token,
      body: body,
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Tiruan: meniru dedup server (`client_request_id` sama → sesi yang sama)
/// supaya build mock bisa mencoba antrean offline tanpa melahirkan sesi
/// kembar di [MockStore].
class MockPengirimDrafService implements PengirimDrafService {
  final Map<String, int> _idPerClientRequest = {};

  /// Semua panggilan, buat test: `('POST'|'PUT', id, body)`.
  final List<({String metode, int? id, Map<String, dynamic> body})> panggilan =
      [];

  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async {
    panggilan.add((metode: 'POST', id: null, body: body));

    final cid = body['client_request_id'] as String?;
    final lama = cid == null ? null : _idPerClientRequest[cid];
    if (lama != null) return (id: lama, status: 'draft');

    final equipmentId = (body['equipment_id'] as num?)?.toInt();
    final nama = equipmentId == null ? null : namaAlatMock(equipmentId);
    final id = MockStore.instance.tambahSesi(
      namaAlat: '${nama ?? (matriks ? 'Autoclave' : 'Alat')} (sesi baru)',
      namaTeknisi: 'Teknisi',
      draft: body['status'] == 'draft',
    );
    if (cid != null) _idPerClientRequest[cid] = id;
    await MockStore.instance.tungguTersimpan();

    return (id: id, status: body['status'] as String?);
  }

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    panggilan.add((metode: 'PUT', id: id, body: body));

    // Sinkron draf offline selalu `status: draft` — sesi revisi jadi draf
    // dengan catatan admin tetap terbawa, sama kayak server.
    MockStore.instance.perbarui(id, draft: body['status'] == 'draft');
    await MockStore.instance.tungguTersimpan();

    return id;
  }
}
