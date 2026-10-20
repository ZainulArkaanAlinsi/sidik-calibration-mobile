/// Berapa potongan sel yang dibaca ML Kit SEKALIGUS.
///
/// M01 (paket 30 Sep): 3–4. Diambil batas bawahnya: tiap pembacaan menulis
/// berkas sementara + memegang bitmap native, dan HP lab bukan HP unggulan.
/// Pengaruhnya ke waktu tunggu BELUM DIUKUR di HP.
const bacaSelSerentak = 3;

/// Jalankan [kerja] untuk tiap [masukan], paling banyak [batas] yang berjalan
/// bersamaan, dan pulangkan hasilnya DALAM URUTAN [masukan] — bukan urutan
/// selesainya.
///
/// Urutan itu yang menentukan: hasil ke-i dipasangkan dengan sel ke-i, dan
/// pasangan yang tertukar berarti angka mendarat di sel lain. Jadi hasilnya
/// ditaruh di slot indeksnya sendiri, tidak pernah di-`add` saat selesai.
///
/// [kerja] juga DIMULAI dalam urutan [masukan] (pekerja mengambil indeks
/// berikutnya secara berurutan), supaya pembaca tiruan yang membagikan bacaan
/// menurut urutan panggil tetap deterministik.
///
/// Galat: kalau satu [kerja] melempar, pekerja lain tetap menyelesaikan
/// antreannya, lalu galat PERTAMA (menurut urutan masukan) dilempar ulang.
/// Pemanggil yang tidak mau satu kegagalan menggugurkan semuanya menangkapnya
/// di dalam [kerja] sendiri — lihat `JalankanPindaiAsli`.
Future<List<R>> petaTerbatas<T, R>(
  List<T> masukan,
  Future<R> Function(T) kerja, {
  int batas = bacaSelSerentak,
}) async {
  if (batas < 1) {
    throw ArgumentError.value(batas, 'batas', 'minimal 1');
  }

  final hasil = List<R?>.filled(masukan.length, null);
  final galat = <int, (Object, StackTrace)>{};
  var berikut = 0;

  Future<void> pekerja() async {
    while (berikut < masukan.length) {
      final i = berikut++;
      try {
        hasil[i] = await kerja(masukan[i]);
      } catch (e, st) {
        galat[i] = (e, st);
      }
    }
  }

  final jumlahPekerja = masukan.length < batas ? masukan.length : batas;
  await Future.wait([for (var p = 0; p < jumlahPekerja; p++) pekerja()]);

  if (galat.isNotEmpty) {
    final pertama = (galat.keys.toList()..sort()).first;
    final (e, st) = galat[pertama]!;
    Error.throwWithStackTrace(e, st);
  }

  return [for (final r in hasil) r as R];
}
