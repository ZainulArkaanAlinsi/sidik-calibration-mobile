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
///    layar apa pun digambar: tulis `pasang.ps1`, jalankan terlepas, lalu
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
  ///
  /// `-v2`, bukan `versi-windows.json`: aplikasi 1.0.567–1.0.570 membaca nama
  /// lama dan membawa pemasang batch yang MACET (jendela `find.exe` menumpuk,
  /// 15 Sep 2026). Nama lama sengaja tidak diterbitkan lagi supaya aplikasi-
  /// aplikasi itu tidak pernah mencoba memasang rilis berikutnya dengan skrip
  /// cacatnya — mereka diperbarui sekali secara manual, sesudahnya lewat sini.
  static const urlManifestBawaan = String.fromEnvironment(
    'URL_MANIFEST_WINDOWS',
    defaultValue: 'https://sidik-kalibrasi.web.app/versi-windows-v2.json',
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

      // Sudah pernah dicoba dan aplikasinya masih versi lama = skripnya tidak
      // sampai selesai (dimatikan, macet, atau listrik padam). JANGAN coba
      // lagi. 15 Sep 2026 skrip versi batch macet menunggu dan tiap pembukaan
      // aplikasi menyalakannya lagi — jendela konsol menumpuk tanpa ujung.
      if (siap.dicoba) {
        await _catatGagal(siap.versi);
        await _bersihkan(siap);
        return false;
      }

      await _penanda.writeAsString(
        jsonEncode({'versi': siap.versi, 'zip': siap.zip, 'dicoba': true}),
        flush: true,
      );

      final skrip = File(_jalur('pasang.ps1'));
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

  /// Isi `pasang.ps1`.
  ///
  /// ## Kenapa PowerShell, bukan batch lagi
  ///
  /// Versi batch (`tasklist | find` + `tar` + `robocopy`) lolos waktu diuji
  /// lewat PowerShell `Start-Process`, lalu MACET di laptop sungguhan 15 Sep
  /// 2026. Aplikasi menjalankannya dengan `Process.start(detached)`, yaitu
  /// tanpa konsol: tiap program konsol yang dipanggil skrip membuka JENDELA
  /// sendiri, dan `find.exe` di ujung pipa menunggu masukan selamanya. Jendela
  /// hitam menumpuk, pembaruannya tidak pernah jalan.
  ///
  /// Di sini seluruh kerja — menunggu proses, mengekstrak, menyalin, menyalakan
  /// lagi — dikerjakan cmdlet di dalam SATU proses PowerShell yang tersembunyi.
  /// Tidak ada program konsol lain yang dipanggil, jadi tidak ada jendela dan
  /// tidak ada pipa yang bisa menggantung.
  @visibleForTesting
  static String susunSkrip({
    required int pid,
    required String zip,
    required String folderKerja,
    required String folderInstalasi,
    required String exe,
    required String versi,
  }) {
    // Literal PowerShell ber-kutip tunggal: satu-satunya karakter khusus di
    // dalamnya kutip tunggal itu sendiri, digandakan.
    String k(String s) => "'${s.replaceAll("'", "''")}'";

    final ekstrak = k('$folderKerja\\ekstrak');
    final penanda = k('$folderKerja\\siap.json');
    final gagal = k('$folderKerja\\gagal.txt');
    final namaExe = exe.split(RegExp(r'[\\/]')).last;

    return [
      r"$ErrorActionPreference = 'Stop'",
      'try {',
      // Tunggu proses aplikasi benar-benar mati: DLL-nya dikunci selama hidup.
      // Batas 2 menit supaya skrip tidak pernah menggantung tanpa ujung.
      '  \$p = Get-Process -Id $pid -ErrorAction SilentlyContinue',
      '  if (\$p) { \$p.WaitForExit(120000) | Out-Null }',
      '  if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { throw "aplikasi belum tertutup" }',
      '',
      // Ekstrak ke folder sementara DULU: zip rusak berhenti di sini, sebelum
      // folder instalasi tersentuh.
      '  Remove-Item -LiteralPath $ekstrak -Recurse -Force -ErrorAction SilentlyContinue',
      '  Expand-Archive -LiteralPath ${k(zip)} -DestinationPath $ekstrak -Force',
      '  if (-not (Test-Path -LiteralPath (Join-Path $ekstrak ${k(namaExe)}))) { throw "isi zip tidak lengkap" }',
      '',
      // Berkas yang baru dilepas Windows kadang masih terkunci sesaat
      // (antivirus memindai exe yang baru ditutup) — dicoba ulang.
      '  for (\$i = 1; \$i -le 10; \$i++) {',
      '    try { Copy-Item -Path (Join-Path $ekstrak "*") -Destination ${k(folderInstalasi)} -Recurse -Force; break }',
      '    catch { if (\$i -eq 10) { throw }; Start-Sleep -Seconds 1 }',
      '  }',
      '',
      '  Remove-Item -LiteralPath $penanda -Force -ErrorAction SilentlyContinue',
      '  Remove-Item -LiteralPath $ekstrak -Recurse -Force -ErrorAction SilentlyContinue',
      '  Remove-Item -LiteralPath ${k(zip)} -Force -ErrorAction SilentlyContinue',
      '  Start-Process -FilePath ${k(exe)}',
      '  exit 0',
      '} catch {',
      // Penanda dicabut dan versinya dicatat, supaya aplikasi yang dinyalakan
      // lagi di bawah tidak mencoba versi yang sama dan berputar.
      '  Remove-Item -LiteralPath $penanda -Force -ErrorAction SilentlyContinue',
      '  Add-Content -LiteralPath $gagal -Value ${k(versi)}',
      '  Remove-Item -LiteralPath $ekstrak -Recurse -Force -ErrorAction SilentlyContinue',
      '  Start-Process -FilePath ${k(exe)}',
      '  exit 1',
      '}',
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

  Future<({String versi, String zip, bool dicoba})?> _bacaPenanda() async {
    if (!await _penanda.exists()) return null;

    try {
      final json = jsonDecode(await _penanda.readAsString());
      final versi = json['versi'] as String?;
      final zip = json['zip'] as String?;
      if (versi == null || zip == null) return null;

      return (versi: versi, zip: zip, dicoba: json['dicoba'] == true);
    } catch (_) {
      await _penanda.delete();
      return null;
    }
  }

  Future<void> _bersihkan(({String versi, String zip, bool dicoba}) siap) async {
    if (await _penanda.exists()) await _penanda.delete();
    final zip = File(siap.zip);
    if (await zip.exists()) await zip.delete();
  }

  Future<void> _catatGagal(String versi) async {
    await folderKerja.create(recursive: true);
    await _catatanGagal.writeAsString('$versi\r\n', mode: FileMode.append, flush: true);
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

  /// `-ExecutionPolicy Bypass` hanya untuk skrip ini sendiri (yang ditulis
  /// aplikasi ini sesaat sebelumnya), bukan mengubah kebijakan mesin. Tanpanya
  /// laptop dengan kebijakan bawaan `Restricted` menolak menjalankan berkas
  /// `.ps1` apa pun, dan pembaruannya diam-diam tidak pernah terjadi.
  ///
  /// ## Kenapa lewat `conhost --headless`
  ///
  /// Diukur 15 Sep 2026 di Windows sungguhan, tiga cara berdampingan:
  /// `powershell.exe` dengan `ProcessStartMode.detached` **tidak jalan sama
  /// sekali** (20 s, berkas tetap lama) — proses konsol tanpa konsol. Itu juga
  /// akar jendela `find.exe` yang macet di versi batch. `conhost --headless`
  /// memberinya konsol tak terlihat: selesai 1,5 s, tanpa jendela, tetap
  /// terlepas dari aplikasi yang sebentar lagi keluar. Mode normal juga jalan
  /// dan dipakai cadangan kalau `conhost` tidak ada.
  static Future<void> _jalankanTerlepas(String skrip) async {
    final sistem = '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32';
    final powershell = [
      '$sistem\\WindowsPowerShell\\v1.0\\powershell.exe',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      skrip,
    ];

    final conhost = File('$sistem\\conhost.exe');
    if (await conhost.exists()) {
      await Process.start(
        conhost.path,
        ['--headless', ...powershell],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    await Process.start(powershell.first, powershell.skip(1).toList());
  }

  /// Dipakai test Windows yang menjalankan skrip dengan cara PERSIS sama
  /// seperti aplikasi — pelajaran dari versi batch yang lolos uji lain jalur.
  @visibleForTesting
  static Future<void> jalankanTerlepasUntukTest(String skrip) =>
      _jalankanTerlepas(skrip);
}
