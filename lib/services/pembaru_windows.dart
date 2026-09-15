import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io show pid;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/versi_aplikasi.dart';

/// Pembaruan otomatis aplikasi Windows: sekali pasang, versi berikutnya masuk
/// sendiri.
///
/// ## Kenapa ini ada
///
/// Mesin pembaruan yang lain (`PenyiapUpdate`, `BannerUpdate`) cuma kenal APK.
/// Paket Windows terbit sebagai zip di halaman unduh Firebase tanpa jalur apa
/// pun ke aplikasi yang sudah terpasang — jadi laptop lab tertahan selamanya di
/// versi yang pertama kali diekstrak, sementara HP di sebelahnya sudah jauh di
/// depan.
///
/// ## Cara kerjanya — dua langkah, di dua kali buka
///
/// 1. **Selama aplikasi jalan** ([mulaiCekBerkala]): baca `versi-windows.json`
///    di sebelah zip; kalau lebih baru, unduh zip-nya ke folder data pengguna,
///    cocokkan ukurannya, lalu tulis penanda `siap.json`. Tidak ada yang
///    diganti selagi aplikasinya terbuka — DLL yang sedang dipakai dikunci
///    Windows, dan mengganti di tengah lembar kerja berarti isian yang belum
///    dikirim hilang.
/// 2. **Waktu aplikasi dibuka berikutnya** ([terapkanKalauSiap]), sebelum
///    layar apa pun digambar: tulis `pasang.cmd`, jalankan terlepas, lalu
///    keluar. Skripnya menunggu proses ini mati, mengekstrak zip ke folder
///    sementara, menyalinnya menimpa folder instalasi, dan menyalakan
///    aplikasinya lagi. Dari sisi pengguna: jendela muncul beberapa detik lebih
///    lambat, dan versinya sudah baru.
///
/// Zip yang diunduh aplikasi sendiri tidak membawa tanda "berasal dari
/// internet", jadi versi-versi berikutnya tidak memunculkan layar SmartScreen —
/// cuma unduhan pertama lewat browser yang kena.
///
/// ## Yang sengaja tidak dilakukan
///
/// - **Zip rusak tidak pernah menyentuh folder instalasi.** Ekstraksi ke folder
///   sementara dijalankan dan diperiksa DULU; salin baru dimulai sesudah itu.
/// - **Versi yang gagal dipasang dicatat dan dilewati.** Tanpa itu skrip yang
///   gagal menyalakan ulang aplikasi, aplikasinya melihat penanda yang sama, dan
///   berputar tanpa ujung.
/// - **Folder instalasi yang tidak bisa ditulis (mis. `Program Files`) dilewati
///   dengan tenang.** Meminta hak admin diam-diam dari aplikasi kalibrasi bukan
///   hal yang pantas.
class PembaruWindows {
  PembaruWindows({
    required this.urlManifest,
    required this.folderKerja,
    required this.fileExe,
    required this.versiTerpasang,
    http.Client? client,
    Future<void> Function(String skrip)? jalankanSkrip,
    int? pid,
  }) : _client = client ?? http.Client(),
       _jalankanSkrip = jalankanSkrip ?? _jalankanTerlepas,
       _pid = pid ?? io.pid;

  /// Pembaru untuk aplikasi yang sedang berjalan ini.
  static Future<PembaruWindows> untukAplikasiIni() async {
    final dukungan = await getApplicationSupportDirectory();

    return PembaruWindows(
      urlManifest: urlManifestBawaan,
      folderKerja: Directory('${dukungan.path}${Platform.pathSeparator}pembaruan'),
      fileExe: File(Platform.resolvedExecutable),
      versiTerpasang: () async => (await PackageInfo.fromPlatform()).version,
    );
  }

  /// Diterbitkan `rilis-desktop.yml` di sebelah `sidik-windows.zip`.
  static const urlManifestBawaan = String.fromEnvironment(
    'URL_MANIFEST_WINDOWS',
    defaultValue: 'https://sidik-kalibrasi.web.app/versi-windows.json',
  );

  final String urlManifest;
  final Directory folderKerja;
  final File fileExe;
  final Future<String> Function() versiTerpasang;

  final http.Client _client;
  final Future<void> Function(String skrip) _jalankanSkrip;
  final int _pid;

  Timer? _timer;
  bool _sedangMenyiapkan = false;

  File get _penanda => File(_jalur('siap.json'));
  File get _catatanGagal => File(_jalur('gagal.txt'));

  String _jalur(String nama) =>
      '${folderKerja.path}${Platform.pathSeparator}$nama';

  /// Cek sekarang, lalu tiap [jeda]. Satu jam: rilis tidak datang tiap menit,
  /// dan laptop lab biasanya dibiarkan terbuka seharian.
  void mulaiCekBerkala({Duration jeda = const Duration(hours: 1)}) {
    _timer?.cancel();
    unawaited(siapkan());
    _timer = Timer.periodic(jeda, (_) => unawaited(siapkan()));
  }

  void berhenti() => _timer?.cancel();

  /// Langkah 1. Memulangkan `true` kalau sesudahnya ada pembaruan yang siap
  /// dipasang di pembukaan berikutnya. Tidak pernah melempar.
  Future<bool> siapkan() async {
    if (_sedangMenyiapkan) return false;
    _sedangMenyiapkan = true;

    try {
      final rilis = await _bacaManifest();
      if (rilis == null) return false;

      final terpasang = await versiTerpasang();
      if (!rilis.lebihBaruDari(terpasang)) return false;
      if (await _pernahGagal(rilis.versi)) return false;
      if (!await _folderInstalasiBisaDitulis()) return false;

      final siap = await _bacaPenanda();
      if (siap != null &&
          siap.versi == rilis.versi &&
          await File(siap.zip).exists()) {
        return true;
      }

      await folderKerja.create(recursive: true);
      final zip = File(_jalur('sidik-windows-${rilis.versi}.zip'));
      if (!await _unduh(rilis, zip)) return false;

      await _penanda.writeAsString(
        jsonEncode({'versi': rilis.versi, 'zip': zip.path}),
        flush: true,
      );

      return true;
    } catch (e) {
      debugPrint('Pembaruan Windows belum bisa disiapkan: $e');
      return false;
    } finally {
      _sedangMenyiapkan = false;
    }
  }

  /// Langkah 2. Memulangkan `true` kalau skrip pemasang sudah dinyalakan —
  /// pemanggil WAJIB keluar sesudahnya supaya berkasnya bisa ditimpa.
  Future<bool> terapkanKalauSiap() async {
    try {
      final siap = await _bacaPenanda();
      if (siap == null) return false;

      final terpasang = await versiTerpasang();
      final zip = File(siap.zip);
      final masihLebihBaru =
          VersiAplikasi(versi: siap.versi, urlUnduh: '').lebihBaruDari(terpasang);

      if (!masihLebihBaru || !await zip.exists()) {
        // Sudah terpasang (pembukaan pertama sesudah pembaruan berhasil) atau
        // zip-nya hilang: bersihkan supaya tidak dicoba lagi.
        await _bersihkan(siap);
        return false;
      }

      final skrip = File(_jalur('pasang.cmd'));
      await skrip.writeAsString(
        susunSkrip(
          pid: _pid,
          zip: zip.path,
          folderKerja: folderKerja.path,
          folderInstalasi: fileExe.parent.path,
          exe: fileExe.path,
          versi: siap.versi,
        ),
        flush: true,
      );

      await _jalankanSkrip(skrip.path);
      return true;
    } catch (e) {
      debugPrint('Pembaruan Windows tidak diterapkan: $e');
      return false;
    }
  }

  /// Isi `pasang.cmd`. Batch, bukan PowerShell: tidak tersangkut kebijakan
  /// eksekusi skrip, dan `tar.exe` + `robocopy` sudah ada di Windows 10 1803+.
  @visibleForTesting
  static String susunSkrip({
    required int pid,
    required String zip,
    required String folderKerja,
    required String folderInstalasi,
    required String exe,
    required String versi,
  }) {
    final ekstrak = '$folderKerja\\ekstrak';
    final penanda = '$folderKerja\\siap.json';
    final gagal = '$folderKerja\\gagal.txt';
    final namaExe = exe.split(RegExp(r'[\\/]')).last;

    return [
      '@echo off',
      'setlocal',
      // Semua perkakas lewat jalur ABSOLUT. Laptop yang memasang Git for Windows
      // dengan "Unix tools" di PATH menjawab `find` dengan find versi Unix —
      // ketahuan waktu skrip ini dijalankan sungguhan: dia menganggap "999999"
      // nama berkas, dan penungguan prosesnya jadi tebakan.
      'set "SYS=%SystemRoot%\\System32"',
      // Tunggu proses aplikasi benar-benar mati: DLL-nya dikunci selama hidup.
      // `ping` sebagai jeda, bukan `timeout`: `timeout` menolak jalan tanpa
      // konsol ("Input redirection is not supported"), dan skrip ini memang
      // dijalankan terlepas dari konsol.
      ':tunggu',
      '"%SYS%\\tasklist.exe" /FI "PID eq $pid" /NH 2>NUL | "%SYS%\\find.exe" " $pid " >NUL',
      'if not errorlevel 1 (',
      '  "%SYS%\\PING.EXE" -n 2 127.0.0.1 >NUL',
      '  goto tunggu',
      ')',
      'if exist "$ekstrak" rmdir /s /q "$ekstrak"',
      'mkdir "$ekstrak"',
      // Ekstrak ke folder sementara DULU: zip rusak berhenti di sini, sebelum
      // folder instalasi tersentuh.
      '"%SYS%\\tar.exe" -xf "$zip" -C "$ekstrak"',
      'if errorlevel 1 goto gagal',
      'if not exist "$ekstrak\\$namaExe" goto gagal',
      '"%SYS%\\Robocopy.exe" "$ekstrak" "$folderInstalasi" /E /R:5 /W:1 /NFL /NDL /NJH /NJS /NP >NUL',
      // robocopy: 0–7 berhasil (dengan variasi), 8 ke atas gagal.
      'if %ERRORLEVEL% GEQ 8 goto gagal',
      'del /q "$penanda" 2>NUL',
      'rmdir /s /q "$ekstrak" 2>NUL',
      'del /q "$zip" 2>NUL',
      'start "" "$exe"',
      'exit /b 0',
      ':gagal',
      // Penanda dicabut dan versinya dicatat, supaya aplikasi yang dinyalakan
      // lagi di bawah tidak mencoba versi yang sama dan berputar.
      'del /q "$penanda" 2>NUL',
      '>>"$gagal" echo $versi',
      'rmdir /s /q "$ekstrak" 2>NUL',
      'start "" "$exe"',
      'exit /b 1',
      '',
    ].join('\r\n');
  }

  Future<VersiAplikasi?> _bacaManifest() async {
    final res = await _client
        .get(Uri.parse(urlManifest), headers: {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) return null;

    final versi = (json['versi'] as String? ?? '').trim();
    final url = (json['url_unduh'] as String? ?? '').trim();
    if (versi.isEmpty || url.isEmpty) return null;

    return VersiAplikasi(
      versi: versi,
      // Boleh relatif ke manifest — zip-nya duduk di folder yang sama.
      urlUnduh: Uri.parse(urlManifest).resolve(url).toString(),
      build: (json['build'] as num?)?.toInt(),
      ukuran: (json['ukuran'] as num?)?.toInt(),
    );
  }

  Future<bool> _unduh(VersiAplikasi rilis, File tujuan) async {
    final sementara = File('${tujuan.path}.part');
    final res = await _client.send(
      http.Request('GET', Uri.parse(rilis.urlUnduh)),
    );

    if (res.statusCode != 200) return false;

    try {
      await res.stream.pipe(sementara.openWrite());
    } catch (_) {
      if (await sementara.exists()) await sementara.delete();
      rethrow;
    }

    // Ukuran dari manifest yang ditulis di runner yang sama dengan zip-nya.
    // Unduhan terpotong (sinyal putus, laptop tidur) berhenti di sini.
    final ukuran = await sementara.length();
    if (rilis.ukuran != null && ukuran != rilis.ukuran) {
      await sementara.delete();
      return false;
    }

    if (await tujuan.exists()) await tujuan.delete();
    await sementara.rename(tujuan.path);
    return true;
  }

  Future<({String versi, String zip})?> _bacaPenanda() async {
    if (!await _penanda.exists()) return null;

    try {
      final json = jsonDecode(await _penanda.readAsString());
      final versi = json['versi'] as String?;
      final zip = json['zip'] as String?;
      if (versi == null || zip == null) return null;

      return (versi: versi, zip: zip);
    } catch (_) {
      await _penanda.delete();
      return null;
    }
  }

  Future<void> _bersihkan(({String versi, String zip}) siap) async {
    if (await _penanda.exists()) await _penanda.delete();
    final zip = File(siap.zip);
    if (await zip.exists()) await zip.delete();
  }

  Future<bool> _pernahGagal(String versi) async {
    if (!await _catatanGagal.exists()) return false;

    final baris = await _catatanGagal.readAsLines();
    return baris.any((b) => b.trim() == versi);
  }

  Future<bool> _folderInstalasiBisaDitulis() async {
    final uji = File(
      '${fileExe.parent.path}${Platform.pathSeparator}.uji-tulis-pembaruan',
    );

    try {
      await uji.writeAsString('x', flush: true);
      await uji.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _jalankanTerlepas(String skrip) async {
    await Process.start(
      'cmd.exe',
      ['/c', skrip],
      mode: ProcessStartMode.detached,
    );
  }
}
