import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/klien_http_beridentitas.dart';

import '../data/simulasi_provider.dart';
import '../data/workbook_provider.dart';

/// Keadaan sesi Studio di mata klien (FR-STU-004).
enum KeadaanSesiStudio {
  /// Token dipercaya — tidak ada penolakan sejak terakhir masuk.
  aktif,

  /// Server menolak token (`401` pada request BERTOKEN). Cangkang memasang
  /// dialog "Sesi berakhir, masuk lagi" di atas layar yang sama.
  berakhir,
}

/// Lihat [SesiStudio].
final sesiStudioProvider = NotifierProvider<SesiStudio, KeadaanSesiStudio>(
  SesiStudio.new,
);

/// Pencatat "token ditolak".
///
/// Diisi pengamat HTTP Studio ([amatiResponsStudio]), BUKAN oleh layar: 401
/// bisa datang dari layanan mana pun, dan tiap layar menangkapnya sendiri-
/// sendiri berarti cepat atau lambat ada yang lupa.
///
/// Kembali ke [KeadaanSesiStudio.aktif] dengan sendirinya tiap akun yang masuk
/// berganti (masuk, keluar, ganti akun) — penolakan milik sesi sebelumnya
/// tidak boleh memunculkan dialog di sesi berikutnya.
class SesiStudio extends Notifier<KeadaanSesiStudio> {
  /// Cap generasi token: sidik token yang ditulis masuk ulang TERAKHIR.
  /// `null` = belum pernah masuk ulang di sesi akun ini.
  int? _sidikTokenSah;

  @override
  KeadaanSesiStudio build() {
    ref.watch(authProvider.select((a) => a.value?.id));
    _sidikTokenSah = null;
    return KeadaanSesiStudio.aktif;
  }

  /// Server menolak request yang membawa token bersidik [sidikToken]
  /// (`ResponsTeramati.sidikToken`).
  void laporTokenDitolak({required int? sidikToken}) {
    // Belum ada yang masuk: 401 di sini milik pemeriksaan token tersimpan
    // (`AuthController.build`) atau keluar — urusan layar masuk, bukan dialog.
    if (ref.read(authProvider).value == null) return;

    // Sesudah masuk ulang, yang dihitung cuma penolakan atas token BARU.
    // Bukan waktu berangkat: request yang tokennya dibaca sebelum masuk
    // ulang tapi baru berangkat sesudahnya (pengulangan 502–504 `ApiClient`,
    // pemanasan `/health`) membawa token LAMA dengan waktu yang baru — dan
    // dulu memunculkan dialog kedua (tinjau S1 saran 1).
    final sah = _sidikTokenSah;
    if (sah != null && sidikToken != sah) return;

    state = KeadaanSesiStudio.berakhir;
  }

  /// Masuk ulang berhasil dan [tokenBaru] sudah tersimpan.
  void pulih({required String tokenBaru}) {
    _sidikTokenSah = sidikTokenBearer(tokenBaru);
    state = KeadaanSesiStudio.aktif;
  }
}

/// Server menyatakan versi Studio ini terlalu lama (`426 klien_kedaluwarsa`,
/// FR-STU-003). Gerbang mengganti seluruh layar dengan pesan jujur.
///
/// Tidak ikut direset oleh ganti akun: versinya tetap usang siapa pun yang
/// masuk.
final klienKedaluwarsaProvider = NotifierProvider<KlienKedaluwarsa, bool>(
  KlienKedaluwarsa.new,
);

class KlienKedaluwarsa extends Notifier<bool> {
  @override
  bool build() => false;

  void tandai() => state = true;

  /// "Coba lagi": request berikutnya akan menandai ulang bila server masih
  /// menolak versi ini.
  void lupakan() => state = false;
}

/// Pengamat HTTP Studio — dipasang di `KlienHttpBeridentitas`
/// (`inti/penimpaan.dart`), dipanggil sekali per jawaban server.
void amatiResponsStudio(Ref ref, ResponsTeramati respons) {
  // `ApiClient` lama yang jawabannya baru tiba sesudah providernya dibangun
  // ulang: ref-nya sudah mati, dan kabar dari client lama tidak relevan.
  if (!ref.mounted) return;

  if (respons.status == 426) {
    ref.read(klienKedaluwarsaProvider.notifier).tandai();
  } else if (respons.status == 401 && respons.berToken) {
    ref
        .read(sesiStudioProvider.notifier)
        .laporTokenDitolak(sidikToken: respons.sidikToken);
  }
}

/// Provider yang memegang data milik SATU sesi akun — disapu saat keluar
/// (FR-STU-005) dan disegarkan sesudah masuk ulang (FR-STU-004).
///
/// Seksi baru yang memegang data akun (Kelola Data S2, Lembar Hitung S4, …)
/// WAJIB mendaftarkan providernya di sini. Data berisi data pribadi sebaiknya
/// juga `autoDispose` (NFR-STU-08).
///
/// Dijaga `test/provider_sesi_studio_test.dart`: provider data di
/// `lib/data/*_provider.dart` (dan provider data acuan paket bersama) yang
/// tidak terdaftar di sini bikin test merah.
final List<ProviderOrFamily> providerSesiStudio = [
  izinProvider,
  daftarPaketAcuanProvider,
  detailPaketAcuanProvider,
  garisWaktuAcuanProvider,
  versiAcuanProvider,
  berlakuAcuanProvider,
  bandingAcuanProvider,
  riwayatSelAcuanProvider,
  // Workbook Alat (S1b). Halaman sel memakai keepAlive berjangka — tanpa
  // sapuan eksplisit, isinya bertahan sampai jedanya habis.
  daftarWorkbookProvider,
  detailWorkbookProvider,
  halamanSelWorkbookProvider,
  gambarWorkbookProvider,
  // Simulasi Tahap C: edit belum disimpan + hasil hitung server (data lab).
  // Masuk ulang/keluar ikut menyapunya.
  simulasiWorkbookProvider,
  overlayLembarProvider,
];

/// Tarik ulang semua [providerSesiStudio]. Lazy: yang dibangun ulang cuma yang
/// sedang ditonton layar.
void segarkanDataSesi(ProviderContainer wadah) {
  for (final p in providerSesiStudio) {
    wadah.invalidate(p);
  }
}

/// Keluar dari Studio (FR-STU-005).
///
/// 1. `AuthController.logout` paket bersama: `POST /logout` mencabut token di
///    server, token di penyimpanan aman dibuang, simpanan akun di disk
///    (SharedPreferences) disapu. Push tidak tersentuh — Studio memakai
///    `TanpaTokenPush` (`penimpaan.dart`).
/// 2. Cache memori Studio: semua [providerSesiStudio] diinvalidasi, jadi tidak
///    ada data akun ini yang disajikan lagi tanpa ditarik ulang dari server.
///    Studio S1 tidak menyimpan data acuan di disk.
///
/// Menerima WADAH, bukan `WidgetRef`: tombol yang memanggil ini ikut lepas
/// dari pohon begitu status auth berubah, dan `WidgetRef` milik widget yang
/// sudah lepas tidak boleh dipakai lagi. Ambil dengan
/// `ProviderScope.containerOf(context, listen: false)` SEBELUM memanggil.
Future<void> keluarStudio(ProviderContainer wadah) async {
  await wadah.read(authProvider.notifier).logout();
  segarkanDataSesi(wadah);
}

/// Masuk ulang dengan [sandi] sebagai akun yang SAMA dengan sesi ini
/// (FR-STU-004), tanpa membongkar layar yang sedang terbuka.
///
/// Sengaja TIDAK lewat `authProvider.notifier.login()`: itu memasang
/// `AsyncLoading` di `authProvider`, gerbang menukar cangkang dengan layar
/// masuk, dan layar + isian yang sedang dikerjakan hilang — kebalikan dari
/// yang diminta FR-STU-004. Di sini yang berganti cuma tokennya; akun di
/// `authProvider` memang tidak berubah.
///
/// Melempar galat layanan auth apa adanya (sandi salah, akun dinonaktifkan,
/// 429, jaringan) — dialog yang menampilkannya. Token lama tidak disentuh
/// bila gagal.
Future<void> masukUlangStudio(
  ProviderContainer wadah, {
  required String sandi,
}) async {
  final akun = wadah.read(authProvider).value;
  if (akun == null) throw const AkunBerbedaException();

  final sesi = await wadah
      .read(authServiceProvider)
      .login(
        identifier: akun.employeeId.isNotEmpty ? akun.employeeId : akun.email,
        password: sandi,
      );

  // Identitasnya dikunci ke akun sesi ini, jadi seharusnya tidak pernah
  // terjadi — tapi kalau server memetakan identitas itu ke akun lain, token
  // akun lain TIDAK boleh dipakai diam-diam di bawah nama akun ini.
  if (sesi.user.id != akun.id) throw const AkunBerbedaException();

  await wadah.read(tokenStorageProvider).write(sesi.token);
  wadah.read(sesiStudioProvider.notifier).pulih(tokenBaru: sesi.token);
  segarkanDataSesi(wadah);
}

/// Masuk ulang menghasilkan akun yang bukan akun sesi ini.
class AkunBerbedaException extends AuthException {
  const AkunBerbedaException() : super('akun_berbeda');
}
