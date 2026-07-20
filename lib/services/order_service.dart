import '../models/order.dart';
import 'api_client.dart';

/// Order kalibrasi — **baca doang dari mobile.**
///
/// Backend ngunci tulis (`store`/`update`/`destroy`) ke admin, dan itu
/// disengaja: order lahir di meja depan waktu alat pelanggan diterima, bukan
/// di lapangan. Teknisi cuma perlu lihat antrean yang ditugaskan ke dia lalu
/// mulai ngerjain — nomor order pun dibikin backend pakai `lockForUpdate()`,
/// nomor kiriman client diabaikan.
abstract class OrderService {
  /// [teknisiId] `'saya'` = order yang punya minimal satu alat ditugaskan ke
  /// pemilik token. Sengaja string, bukan int: mobile nggak perlu tahu ID-nya
  /// sendiri, dan backend yang nerjemahin.
  Future<List<OrderKalibrasi>> daftar(
    String token, {
    String? teknisiId,
    String? search,
  });

  Future<OrderKalibrasi> detail(String token, int id);
}

class ApiOrderService implements OrderService {
  ApiOrderService(this._api);

  final ApiClient _api;

  @override
  Future<List<OrderKalibrasi>> daftar(
    String token, {
    String? teknisiId,
    String? search,
  }) async {
    final query = <String, String>{
      if (teknisiId != null && teknisiId.isNotEmpty) 'teknisi_id': teknisiId,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final path = query.isEmpty
        ? '/orders'
        : '/orders?${query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final json = await _api.get(path, token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return data.cast<Map<String, dynamic>>().map(OrderKalibrasi.fromJson).toList();
  }

  @override
  Future<OrderKalibrasi> detail(String token, int id) async {
    final json = await _api.get('/orders/$id', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return OrderKalibrasi.fromJson(data);
  }
}
