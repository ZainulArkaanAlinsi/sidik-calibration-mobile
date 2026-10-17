import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/models/izin.dart' show NamaIzin;
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart'
    show TokenHilangException;
import 'package:sidik_calibration/providers/izin_provider.dart';

import 'workbook_model.dart';
import 'workbook_service.dart';

/// Izin baca Workbook Alat (`MatriksIzin` server, S1b). Namanya di
/// `NamaIzin` paket bersama (dijaga `test/nama_izin_test.dart` akar lawan
/// fixture yang DIGENERATE dari `MatriksIzin::PETA`); alias ini menjaga
/// pemanggil Studio tetap satu nama.
const izinWorkbookLihat = NamaIzin.workbookLihat;

/// Cadangan bila server belum menyebut izin ini: TIDAK (alasan sama dengan
/// `cadanganIzinDataAcuan` — fiturnya lahir bersama izinnya; cadangan `true`
/// menawarkan pintu ke rute yang di server lama dijawab 404).
const cadanganIzinWorkbook = false;

/// Gerbang seksi & kartu Beranda. Menyembunyikan menu BUKAN kontrol akses —
/// server tetap menolak sendiri.
bool bolehBukaWorkbook(WidgetRef ref) =>
    ref.bolehkah(izinWorkbookLihat, cadangan: cadanganIzinWorkbook);

final workbookServiceProvider = Provider<WorkbookService>((ref) {
  if (AppConfig.useMock) return MockWorkbookService();
  return ApiWorkbookService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  // Ikut akun yang masuk: ganti akun → data lab sebelumnya tidak ikut.
  ref.watch(authProvider);

  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Kunci [daftarWorkbookProvider]. `cari` kosong = semua.
typedef KunciDaftarWorkbook = ({String? kodeProfil, String cari});

/// Daftar workbook (Beranda memakai kunci kosong).
///
/// `autoDispose`: kuncinya ikut kata cari, dan tiap kata cari yang pernah
/// diketik tidak perlu menetap di memori sampai keluar.
final daftarWorkbookProvider = FutureProvider.autoDispose
    .family<List<WorkbookRingkas>, KunciDaftarWorkbook>((ref, kunci) async {
      final token = await _token(ref);
      return ref
          .read(workbookServiceProvider)
          .daftar(token, kodeProfil: kunci.kodeProfil, cari: kunci.cari);
    }, retry: (_, _) => null);

/// Meta + lembar satu workbook.
///
/// `autoDispose`: cuma `WorkbookScreen` yang menontonnya — detail workbook
/// yang sudah ditutup tidak menetap di memori sampai keluar akun; membuka
/// lagi = satu permintaan kecil.
final detailWorkbookProvider = FutureProvider.autoDispose
    .family<WorkbookDetail, int>((ref, id) async {
      final token = await _token(ref);
      return ref.read(workbookServiceProvider).detail(token, id);
    }, retry: (_, _) => null);

/// Semua versi jenis satu workbook (K-49-13, `GET …/{id}/riwayat`).
///
/// `autoDispose`: cuma layar riwayat yang menontonnya.
final riwayatWorkbookProvider = FutureProvider.autoDispose
    .family<RiwayatWorkbook, int>((ref, id) async {
      final token = await _token(ref);
      return ref.read(workbookServiceProvider).riwayat(token, id);
    }, retry: (_, _) => null);

/// Baris per halaman sel. Server membolehkan 500; 200 cukup untuk satu
/// layar penuh di monitor tinggi sekalipun, dan jawabannya tetap kecil.
const int ukuranHalamanSel = 200;

/// Simpan halaman yang sudah tidak terlihat selama ini sebelum dibuang —
/// menggulir bolak-balik tidak menembak server lagi, tapi lembar yang sudah
/// ditinggal tidak menumpuk di memori.
const Duration simpanHalamanSel = Duration(minutes: 3);

/// Kunci satu halaman sel. [halaman] basis-0: baris
/// `halaman*200+1 .. (halaman+1)*200`.
typedef KunciHalamanSel = ({int workbookId, int lembarId, int halaman});

/// Halaman berisi [baris] (basis-1).
int halamanUntukBaris(int baris) => (baris - 1) ~/ ukuranHalamanSel;

/// Satu halaman sel (200 baris). Sel grid menonton halaman barisnya sendiri,
/// jadi yang ditarik cuma halaman yang pernah terlihat.
///
/// `autoDispose` + `keepAlive` berjangka [simpanHalamanSel]: cache selama
/// dipakai dan sebentar sesudahnya. Tetap `watch(authProvider)` (lewat
/// `_token`) dan terdaftar di `providerSesiStudio` — keepAlive mencabut jaring
/// auto-dispose, jadi sapuan akun wajib eksplisit.
final halamanSelWorkbookProvider = FutureProvider.autoDispose
    .family<HalamanSelWorkbook, KunciHalamanSel>((ref, kunci) async {
      final tautan = ref.keepAlive();
      Timer? jeda;
      ref.onCancel(() {
        jeda = Timer(simpanHalamanSel, tautan.close);
      });
      ref.onResume(() => jeda?.cancel());
      ref.onDispose(() => jeda?.cancel());

      final token = await _token(ref);
      final dari = kunci.halaman * ukuranHalamanSel + 1;
      return ref
          .read(workbookServiceProvider)
          .sel(
            token,
            workbookId: kunci.workbookId,
            lembarId: kunci.lembarId,
            barisDari: dari,
            barisSampai: dari + ukuranHalamanSel - 1,
          );
    }, retry: (_, _) => null);

/// Kunci [gambarWorkbookProvider].
typedef KunciGambarWorkbook = ({int workbookId, String gambarId});

/// Byte satu gambar lembar (png/jpeg; `null` = tidak ada di server). Cache
/// memori dengan jeda simpan yang sama dengan halaman sel: menggulir
/// bolak-balik tidak menarik ulang, lembar yang ditinggal tidak menumpuk.
/// Ikut akun (`_token`) dan terdaftar di `providerSesiStudio`.
final gambarWorkbookProvider = FutureProvider.autoDispose
    .family<Uint8List?, KunciGambarWorkbook>((ref, kunci) async {
      final tautan = ref.keepAlive();
      Timer? jeda;
      ref.onCancel(() {
        jeda = Timer(simpanHalamanSel, tautan.close);
      });
      ref.onResume(() => jeda?.cancel());
      ref.onDispose(() => jeda?.cancel());

      final token = await _token(ref);
      return ref
          .read(workbookServiceProvider)
          .gambar(
            token,
            workbookId: kunci.workbookId,
            gambarId: kunci.gambarId,
          );
    }, retry: (_, _) => null);

/// Tarik ulang semua data workbook (lazy). Simulasi TIDAK ikut dibuang:
/// edit yang berlaku dihitung lagi di atas snapshot yang baru.
void segarkanWorkbook(WidgetRef ref) {
  ref.invalidate(daftarWorkbookProvider);
  ref.invalidate(detailWorkbookProvider);
  ref.invalidate(riwayatWorkbookProvider);
  ref.invalidate(halamanSelWorkbookProvider);
  ref.invalidate(gambarWorkbookProvider);
}
