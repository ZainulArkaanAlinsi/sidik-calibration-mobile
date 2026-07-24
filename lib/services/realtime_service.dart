import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';

/// Peristiwa realtime dari backend (spec poin 12D). Payload sengaja TIPIS —
/// cuma "sinyal ada perubahan", datanya tetap ditarik lewat REST ber-otorisasi
/// (angka/isi sensitif nggak ikut lewat websocket).
sealed class PeristiwaRealtime {
  const PeristiwaRealtime();
}

/// Sinyal data organisasi berubah (channel `organisasi.{id}`, event
/// `data.berubah`). [jenis] mis. `kalibrasi`/`sertifikat`, [aksi] mis.
/// `dibuat`/`disetujui`.
class DataBerubah extends PeristiwaRealtime {
  const DataBerubah({required this.jenis, required this.aksi, this.id});

  final String jenis;
  final String aksi;
  final int? id;

  factory DataBerubah.fromJson(Map<String, dynamic> json) => DataBerubah(
    jenis: json['jenis'] as String? ?? '',
    aksi: json['aksi'] as String? ?? '',
    id: (json['id'] as num?)?.toInt(),
  );
}

/// Notifikasi baru masuk (channel `App.Models.User.{id}`) — lonceng nyala.
class NotifikasiMasuk extends PeristiwaRealtime {
  const NotifikasiMasuk();
}

/// Sambungan realtime: subscribe channel privat organisasi & user, keluarin
/// aliran [PeristiwaRealtime].
abstract class RealtimeService {
  /// Konek + subscribe. Idempoten — panggil ulang aman (putus dulu).
  /// [organizationId] boleh null (backend belum tentu punya org buat user itu).
  Future<void> hubungkan({
    required String token,
    required int userId,
    int? organizationId,
  });

  Stream<PeristiwaRealtime> get peristiwa;

  Future<void> putus();
}

/// Klien Reverb/Pusher **pure-Dart** (tanpa plugin native) → jalan sama di
/// mobile & desktop, dan bisa diuji tanpa server.
///
/// Protokol Pusher itu JSON di atas websocket: connect → dapat `socket_id` →
/// otorisasi channel privat lewat `POST /broadcasting/auth` → `pusher:subscribe`
/// → terima event. Channel privat diprefiks `private-`.
class PusherRealtimeService implements RealtimeService {
  PusherRealtimeService({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;
  final _peristiwa = StreamController<PeristiwaRealtime>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  String? _token;
  int? _userId;
  int? _orgId;
  bool _aktif = false;

  @override
  Stream<PeristiwaRealtime> get peristiwa => _peristiwa.stream;

  String get _channelOrg => 'private-organisasi.$_orgId';
  String get _channelUser => 'private-App.Models.User.$_userId';

  @override
  Future<void> hubungkan({
    required String token,
    required int userId,
    int? organizationId,
  }) async {
    await putus();
    _token = token;
    _userId = userId;
    _orgId = organizationId;
    _aktif = true;
    await _sambung();
  }

  Future<void> _sambung() async {
    try {
      final ch = WebSocketChannel.connect(Uri.parse(AppConfig.reverbWsUrl));
      _channel = ch;
      _sub = ch.stream.listen(
        _tanganiPesan,
        onError: (_) => _sambungUlang(),
        onDone: _sambungUlang,
        cancelOnError: true,
      );
      // Subscribe nunggu `pusher:connection_established` (di _tanganiPesan) —
      // di sana socket_id-nya baru ada.
    } catch (_) {
      // Reverb mati / nggak kejangkau: diam aja. App tetap jalan, data ketarik
      // waktu layar dibuka (fallback non-realtime). Coba lagi nanti.
      _sambungUlang();
    }
  }

  void _sambungUlang() {
    if (!_aktif) return;
    _channel = null;
    // Backoff tetap sederhana: 5 detik. Realtime itu penyempurna, bukan syarat.
    Timer(const Duration(seconds: 5), () {
      if (_aktif) _sambung();
    });
  }

  void _tanganiPesan(dynamic raw) {
    final Map<String, dynamic> pesan;
    try {
      pesan = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = pesan['event'] as String?;
    // `data` di protokol Pusher biasanya string JSON, kadang objek.
    final data = _keMap(pesan['data']);
    final channel = pesan['channel'] as String?;

    switch (event) {
      case 'pusher:connection_established':
        // Baru sekarang socket_id ada → simpan, lalu otorisasi & subscribe.
        _socketId = data['socket_id'] as String?;
        _subscribe(_channelUser);
        if (_orgId != null) _subscribe(_channelOrg);
      case 'pusher:ping':
        _kirim({'event': 'pusher:pong', 'data': <String, dynamic>{}});
      case 'pusher:error':
      case 'pusher_internal:subscription_succeeded':
      case null:
        break;
      case 'data.berubah':
        _peristiwa.add(DataBerubah.fromJson(data));
      default:
        // Event lain di channel USER = notifikasi (Laravel broadcast notif pakai
        // nama kelas panjang; nggak perlu dicocokin persis).
        if (channel == _channelUser && !event.startsWith('pusher')) {
          _peristiwa.add(const NotifikasiMasuk());
        }
    }
  }

  Map<String, dynamic> _keMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is String && v.isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is Map<String, dynamic>) return d;
      } catch (_) {}
    }
    return const {};
  }

  /// Otorisasi channel privat lalu kirim `pusher:subscribe`.
  Future<void> _subscribe(String channel) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      final res = await _http.post(
        Uri.parse(AppConfig.broadcastingAuthUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'socket_id': _socketId, 'channel_name': channel}),
      );
      if (res.statusCode != 200) return; // nggak berhak / server nolak: lewat
      final auth = (jsonDecode(res.body) as Map<String, dynamic>)['auth'];
      _kirim({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': auth},
      });
    } catch (_) {
      // Auth gagal: channel ini nggak ke-subscribe, sisanya tetap jalan.
    }
  }

  String? _socketId;

  void _kirim(Map<String, dynamic> pesan) => _channel?.sink.add(jsonEncode(pesan));

  @override
  Future<void> putus() async {
    _aktif = false;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _socketId = null;
  }
}

/// Tiruan: alur realtime bisa diuji tanpa websocket. [pancarkan] buat mendorong
/// peristiwa dari test. Dipakai juga saat realtime nonaktif (no-op).
class MockRealtimeService implements RealtimeService {
  final _peristiwa = StreamController<PeristiwaRealtime>.broadcast();

  @override
  Stream<PeristiwaRealtime> get peristiwa => _peristiwa.stream;

  @override
  Future<void> hubungkan({
    required String token,
    required int userId,
    int? organizationId,
  }) async {}

  /// Dorong satu peristiwa (buat test).
  void pancarkan(PeristiwaRealtime p) => _peristiwa.add(p);

  @override
  Future<void> putus() async {}
}
