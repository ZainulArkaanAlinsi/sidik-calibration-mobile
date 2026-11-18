import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Jawaban `POST /api/me/ganti-sandi` (200).
///
/// [sesiDicabut] = jumlah token LAIN akun ini yang dihapus server. Token yang
/// sedang dipakai dipertahankan, jadi layar TIDAK boleh logout setelahnya.
class HasilGantiSandi {
  const HasilGantiSandi({this.sesiDicabut = 0});

  final int sesiDicabut;

  factory HasilGantiSandi.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final jumlah = data is Map ? data['sesi_dicabut'] : null;

    return HasilGantiSandi(sesiDicabut: jumlah is num ? jumlah.toInt() : 0);
  }
}

/// Ganti sandi SENDIRI (semua peran internal; kontrak
/// `docs/perintah-frontend-ganti-sandi-lab.md`).
///
/// Penilaian sandi (panjang, pernah bocor, sama dengan yang lama) sepenuhnya
/// di server: galat 422 dilempar sebagai [ApiException] dengan badan asli
/// (`kode`, `errors.<kolom>[0]`) supaya layar yang memetakannya ke kolom.
///
/// Service ini tidak pernah menyimpan atau mencatat sandi.
abstract class GantiSandiService {
  Future<HasilGantiSandi> ganti(
    String token, {
    required String sandiLama,
    required String sandiBaru,
    required String konfirmasi,
  });
}

class ApiGantiSandiService implements GantiSandiService {
  ApiGantiSandiService(this._api);

  final ApiClient _api;

  @override
  Future<HasilGantiSandi> ganti(
    String token, {
    required String sandiLama,
    required String sandiBaru,
    required String konfirmasi,
  }) async {
    // POST tanpa `client_request_id`: tidak diulang otomatis oleh ApiClient.
    // Nama kolom persis kontrak (`sandi_confirmation`, bukan `konfirmasi`).
    final json = await _api.post(
      '/me/ganti-sandi',
      token: token,
      body: {
        'sandi_lama': sandiLama,
        'sandi': sandiBaru,
        'sandi_confirmation': konfirmasi,
      },
    );
    return HasilGantiSandi.fromJson(json);
  }
}

/// Tiruan buat test dan mode mock. Meniru aturan server seperlunya supaya
/// layar bisa diuji; sandinya TIDAK disimpan.
class MockGantiSandiService implements GantiSandiService {
  MockGantiSandiService({
    this.sandiYangBenar = 'sandi-lama-benar',
    this.sesiDicabut = 2,
    this.galat,
    this.jeda = Duration.zero,
  });

  final String sandiYangBenar;
  final int sesiDicabut;

  /// Bila diisi, selalu dilempar (meniru 429/403/jaringan).
  final Object? galat;
  final Duration jeda;

  int jumlahPanggilan = 0;

  @override
  Future<HasilGantiSandi> ganti(
    String token, {
    required String sandiLama,
    required String sandiBaru,
    required String konfirmasi,
  }) async {
    jumlahPanggilan++;
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;

    if (sandiLama != sandiYangBenar) {
      throw const ApiException(
        'Sandi lama tidak cocok.',
        status: 422,
        body: {
          'kode': 'sandi_lama_salah',
          'message': 'Sandi lama tidak cocok.',
        },
      );
    }
    if (sandiBaru.length < 10) {
      throw const ApiException(
        'Sandi baru minimal 10 karakter.',
        status: 422,
        body: {
          'message': 'Sandi baru minimal 10 karakter.',
          'errors': {
            'sandi': ['Sandi baru minimal 10 karakter.'],
          },
        },
      );
    }
    if (sandiBaru != konfirmasi) {
      throw const ApiException(
        'Konfirmasi sandi baru tidak cocok.',
        status: 422,
        body: {
          'message': 'Konfirmasi sandi baru tidak cocok.',
          'errors': {
            'sandi': ['Konfirmasi sandi baru tidak cocok.'],
          },
        },
      );
    }
    if (sandiBaru == sandiLama) {
      throw const ApiException(
        'Sandi baru tidak boleh sama dengan sandi lama.',
        status: 422,
        body: {
          'message': 'Sandi baru tidak boleh sama dengan sandi lama.',
          'errors': {
            'sandi': ['Sandi baru tidak boleh sama dengan sandi lama.'],
          },
        },
      );
    }

    return HasilGantiSandi(sesiDicabut: sesiDicabut);
  }
}
