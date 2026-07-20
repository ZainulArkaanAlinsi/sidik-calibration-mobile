import 'dart:math';

/// UUID v4 acak — dipakai buat `client_request_id` (idempotency key waktu
/// submit kalibrasi, `docs/kontrak-api.md` §4). Nggak nambah dependency baru
/// buat satu fungsi kecil ini; `Random.secure()` cukup buat keperluan
/// "beda tiap sesi form", bukan kriptografi.
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Set versi (4) & varian (RFC 4122) sesuai spek UUID v4.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
