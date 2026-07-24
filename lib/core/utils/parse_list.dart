/// Parsing list dari respons backend yang **tahan item cacat**.
///
/// Layar-layar di app ini digambar dari data backend. Pola lama
/// `list.cast<Map<String, dynamic>>().map(X.fromJson).toList()` **ambruk total**
/// begitu satu item aja beda bentuk (kunci hilang, tipe salah) — satu record
/// cacat ngosongin seluruh layar. Di lapangan itu kebaca sebagai "komponen
/// hilang / data kurang", padahal 99% datanya sehat.
///
/// [parseListAman] ngelewat item yang gagal di-parse dan nerusin sisanya.
/// Kalau data benar, hasilnya **persis sama** kayak cara lama — ini jaring
/// pengaman di jalur error, bukan perubahan perilaku.
library;

List<T> parseListAman<T>(
  dynamic list,
  T Function(Map<String, dynamic>) parse,
) {
  if (list is! List) return const [];
  final hasil = <T>[];
  for (final item in list) {
    if (item is! Map) continue;
    try {
      hasil.add(parse(Map<String, dynamic>.from(item)));
    } catch (_) {
      // Item cacat dilewat; sisanya tetap tampil.
    }
  }
  return hasil;
}
