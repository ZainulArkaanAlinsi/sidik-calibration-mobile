import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Satu jawaban server yang diamati [KlienHttpBeridentitas].
class ResponsTeramati {
  const ResponsTeramati({
    required this.status,
    required this.berToken,
    required this.dikirimPada,
    this.sidikToken,
  });

  /// Kode HTTP jawaban.
  final int status;

  /// Request-nya membawa `Authorization`. Membedakan "token ditolak" (sesi
  /// berakhir) dari "kredensial salah" di `POST /login`, yang juga 401 tapi
  /// berangkat tanpa token.
  final bool berToken;

  /// Kapan request-nya BERANGKAT (bukan kapan jawabannya tiba) — supaya
  /// pengamat bisa mengabaikan jawaban untuk request yang dikirim sebelum
  /// keadaan berubah (mis. sebelum masuk ulang).
  final DateTime dikirimPada;

  /// Sidik ([sidikTokenBearer]) token yang DIBAWA request ini, `null` bila
  /// tanpa `Authorization`.
  ///
  /// Untuk pertanyaan "token MANA yang ditolak?" — waktu berangkat saja tidak
  /// cukup: request yang tokennya dibaca sebelum masuk ulang tapi baru
  /// berangkat sesudahnya (pengulangan 502–504 `ApiClient`, pemanasan
  /// `/health`) membawa token LAMA dengan waktu berangkat yang baru.
  ///
  /// Sidik, bukan tokennya: pengamat cukup membandingkan, tidak perlu
  /// memegang kredensial.
  final int? sidikToken;
}

/// Sidik token pembawa: pembanding kesamaan DI DALAM proses yang sama, bukan
/// hash kriptografis dan tidak untuk disimpan/dikirim ke mana pun.
int sidikTokenBearer(String token) => token.hashCode;

/// Sidik dari nilai header `Authorization` (`Bearer <token>`); `null` bila
/// tidak ada header. Skema selain `Bearer` disidik utuh.
int? sidikDariOtorisasi(String? nilaiHeader) {
  if (nilaiHeader == null) return null;
  const awalan = 'bearer ';
  final kredensial = nilaiHeader.toLowerCase().startsWith(awalan)
      ? nilaiHeader.substring(awalan.length).trim()
      : nilaiHeader;
  return sidikTokenBearer(kredensial);
}

/// Pembungkus [http.Client] yang menempelkan header identitas klien ke SETIAP
/// request dan mengabari [pengamat] status tiap jawaban.
///
/// ## Titik sambung, bukan perubahan perilaku
///
/// Dipasang aplikasi yang MEMILIH memakainya — hari ini Sidik Studio, lewat
/// penimpaan `apiClientProvider` (`studio/lib/inti/penimpaan.dart`). App
/// lapangan tetap memakai `ApiClient()` dengan `http.Client()` polos, jadi
/// request-nya tidak membawa header tambahan apa pun dan tidak ada yang
/// diamati. `ApiClient` sendiri tidak berubah.
///
/// ## Kenapa di tingkat `http.Client`, bukan di `ApiClient._headers`
///
/// `ApiClient` menyusun header di LIMA tempat (JSON, `unggahFile`,
/// `unggahBanyak`, `ambilBytes`, pemanasan `/health`). Semuanya berakhir di
/// `send()` client yang disuntik — satu tempat di sini menjangkau semuanya,
/// termasuk jalur yang ditambah kelak.
class KlienHttpBeridentitas extends http.BaseClient {
  KlienHttpBeridentitas({
    required Map<String, String> header,
    this.pengamat,
    http.Client? dalam,
  }) : header = Map.unmodifiable(header),
       _dalam = dalam ?? http.Client();

  /// Header yang ditempel ke setiap request; menimpa nilai bernama sama.
  final Map<String, String> header;

  /// Dipanggil sekali per jawaban, sebelum jawaban diteruskan ke pemanggil.
  final void Function(ResponsTeramati respons)? pengamat;

  final http.Client _dalam;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(header);

    // Peta header `package:http` tidak peka huruf besar/kecil.
    final otorisasi = request.headers['authorization'];
    final berToken = otorisasi != null;
    final dikirimPada = DateTime.now();

    final res = await _dalam.send(request);

    final amati = pengamat;
    if (amati != null) {
      try {
        amati(
          ResponsTeramati(
            status: res.statusCode,
            berToken: berToken,
            dikirimPada: dikirimPada,
            sidikToken: sidikDariOtorisasi(otorisasi),
          ),
        );
      } catch (e, st) {
        // Pengamat yang rusak TIDAK boleh mengubah jawaban server jadi galat
        // di semua layar. Dicatat, tidak ditelan diam-diam.
        debugPrint('KlienHttpBeridentitas: pengamat gagal: $e\n$st');
      }
    }

    return res;
  }

  @override
  void close() => _dalam.close();
}
