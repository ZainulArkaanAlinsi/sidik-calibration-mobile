import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/inti/sesi_studio.dart';

/// Penjaga `providerSesiStudio` (tinjau S1 saran 3).
///
/// Daftar provider yang disapu saat keluar / disegarkan sesudah masuk ulang
/// ditulis tangan di `lib/inti/sesi_studio.dart`. Provider data baru yang
/// lupa didaftarkan TIDAK menghasilkan error apa pun — datanya cuma bertahan
/// melewati keluar (keepAlive, family non-autoDispose). Test ini membaca
/// SUMBER-nya: setiap provider yang dideklarasikan di berkas provider data
/// wajib muncul di daftar itu.
///
/// Dijalankan dari `studio/` (seperti test pubspec di `klien_studio_test`).
void main() {
  /// Provider di berkas data yang memang BUKAN data akun — alasan tertulis.
  const bukanDataAkun = {
    // `GET /health` publik: status server, sama untuk siapa pun.
    'statusServerProvider':
        'status server publik, tanpa token, bukan milik akun',
    // Pembungkus aksi (fungsi unggah), tidak menyimpan data apa pun; sandi
    // berkas lewat parameter dan tidak ditahan.
    'unggahMasterProvider': 'aksi tanpa keadaan, tidak memegang data akun',
  };

  bool layanan(String nama) =>
      nama.endsWith('ServiceProvider') || nama.startsWith('layanan');

  Set<String> deklarasi(File berkas) => {
    for (final m in RegExp(
      r'^final\s+(\w+Provider)\s*=',
      multiLine: true,
    ).allMatches(berkas.readAsStringSync()))
      m.group(1)!,
  };

  Set<String> terdaftar() {
    final sumber = File('lib/inti/sesi_studio.dart').readAsStringSync();
    final awal = sumber.indexOf('providerSesiStudio = [');
    expect(awal, isNonNegative, reason: 'daftar providerSesiStudio hilang');
    final akhir = sumber.indexOf('];', awal);
    final blok = sumber
        .substring(awal, akhir)
        .split('\n')
        .map((b) => b.replaceFirst(RegExp(r'//.*'), ''))
        .join('\n');
    return {
      for (final m in RegExp(r'\b(\w+Provider)\b').allMatches(blok))
        m.group(1)!,
    };
  }

  test('setiap provider data Studio (lib/data/*_provider.dart) terdaftar di '
      'providerSesiStudio', () {
    final berkas = Directory('lib/data')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_provider.dart'))
        .toList();
    expect(berkas, isNotEmpty);

    final daftar = terdaftar();
    final hilang = <String>[];
    for (final f in berkas) {
      for (final nama in deklarasi(f)) {
        if (layanan(nama) || bukanDataAkun.containsKey(nama)) continue;
        if (!daftar.contains(nama)) hilang.add('${f.path}: $nama');
      }
    }
    expect(
      hilang,
      isEmpty,
      reason:
          'Provider data akun yang tidak disapu saat keluar. Daftarkan di '
          'providerSesiStudio (lib/inti/sesi_studio.dart), atau — kalau '
          'memang bukan data akun — tulis alasannya di `bukanDataAkun`.',
    );
  });

  test('provider data acuan paket bersama yang dipakai Studio ikut '
      'terdaftar', () {
    final berkas = File('../lib/providers/data_acuan_provider.dart');
    expect(berkas.existsSync(), isTrue);
    final daftar = terdaftar();
    final hilang = [
      for (final nama in deklarasi(berkas))
        if (!layanan(nama) && !daftar.contains(nama)) nama,
    ];
    expect(hilang, isEmpty);
  });

  test('isi runtime sama dengan yang dibaca dari sumber', () {
    expect(providerSesiStudio, contains(izinProvider));
    expect(providerSesiStudio, contains(daftarWorkbookProvider));
    expect(providerSesiStudio, contains(detailWorkbookProvider));
    expect(providerSesiStudio, contains(halamanSelWorkbookProvider));
    expect(providerSesiStudio, hasLength(terdaftar().length));
  });
}
