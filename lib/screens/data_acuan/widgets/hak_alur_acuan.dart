/// Alur versi data acuan (T2.2/T2.3) — siapa boleh menekan tombol apa, dan
/// pesan galat yang layak tampil.
///
/// **Aturan milik SERVER.** Yang ada di sini cerminnya supaya layar tidak
/// menawarkan tombol yang pasti ditolak:
///  - izin `data-acuan.ajukan` / `.simulasi` / `.aktifkan` dari
///    `/me/permissions` (cadangan `false`: fiturnya lahir bersama izinnya);
///  - tolak versi `diajukan` dan aktifkan = super admin saja
///    (`AlurVersiAcuan::tolak`, grup `role:super_admin`);
///  - Sidik Studio = baca saja ([alurAcuanBacaSajaProvider]): token Studio
///    ditolak `aplikasi:internal` di rute tulis.
///
/// Pemisahan wewenang (pengaktif bukan pengimpor/penyunting/pengaju) hanya
/// diketahui server per versi — layar tidak menebaknya; jawabannya
/// `422 pengesah_ikut_menyunting` dipetakan ke kalimat yang jelas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/alur_acuan.dart';
import '../../../models/data_acuan.dart';
import '../../../models/izin.dart';
import '../../../models/user.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/data_acuan_provider.dart';
import '../../../providers/izin_provider.dart';
import '../../../services/auth_service.dart';
import 'keadaan_acuan.dart';

/// Hak aksi alur satu akun di satu aplikasi.
class HakAlurAcuan {
  const HakAlurAcuan({
    this.ajukan = false,
    this.simulasi = false,
    this.tolakDraf = false,
    this.tolakDiajukan = false,
    this.aktifkan = false,
  });

  static const tidakAda = HakAlurAcuan();

  final bool ajukan;
  final bool simulasi;
  final bool tolakDraf;
  final bool tolakDiajukan;
  final bool aktifkan;

  bool get adaAksi =>
      ajukan || simulasi || tolakDraf || tolakDiajukan || aktifkan;

  /// Tombol yang ditawarkan untuk versi berstatus [status].
  bool bolehAjukan(StatusVersiAcuan status) =>
      ajukan && status == StatusVersiAcuan.draf;

  bool bolehSimulasi(StatusVersiAcuan status) =>
      simulasi &&
      (status == StatusVersiAcuan.draf || status == StatusVersiAcuan.diajukan);

  bool bolehTolak(StatusVersiAcuan status) => switch (status) {
    StatusVersiAcuan.draf => tolakDraf,
    StatusVersiAcuan.diajukan => tolakDiajukan,
    _ => false,
  };

  bool bolehAktifkan(StatusVersiAcuan status) =>
      aktifkan && status == StatusVersiAcuan.diajukan;
}

/// Hak aksi alur menurut izin server, peran, dan aplikasi.
HakAlurAcuan hakAlurAcuan(WidgetRef ref) {
  if (ref.watch(alurAcuanBacaSajaProvider)) return HakAlurAcuan.tidakAda;

  final peran = peranDataAcuan(ref);
  // Teknisi & viewer tidak pernah menulis alur (server: `role:admin` /
  // `role:super_admin`). Izin yang kebetulan terbawa tidak membuka tombol.
  if (peran != UserRole.admin && peran != UserRole.superAdmin) {
    return HakAlurAcuan.tidakAda;
  }
  final superAdmin = peran == UserRole.superAdmin;

  bool izin(String nama) => ref.bolehkah(nama, cadangan: false);

  final ajukan = izin(NamaIzin.dataAcuanAjukan);
  return HakAlurAcuan(
    ajukan: ajukan,
    simulasi: izin(NamaIzin.dataAcuanSimulasi),
    // Tolak satu grup rute dengan ajukan (tanpa nama izin sendiri).
    tolakDraf: ajukan,
    tolakDiajukan: ajukan && superAdmin,
    aktifkan: superAdmin && izin(NamaIzin.dataAcuanAktifkan),
  );
}

/// Pintu menu alur di aplikasi lab: hanya untuk yang bisa MENULIS alur.
/// Membaca data acuan tetap urusan Sidik Studio (keputusan 9 Okt 2026).
bool bolehBukaAlurAcuan(WidgetRef ref) {
  final peran = peranDataAcuan(ref);
  if (peran != UserRole.admin && peran != UserRole.superAdmin) return false;
  return ref.bolehkah(NamaIzin.dataAcuanAjukan, cadangan: false) ||
      ref.bolehkah(NamaIzin.dataAcuanSimulasi, cadangan: false) ||
      ref.bolehkah(NamaIzin.dataAcuanAktifkan, cadangan: false);
}

/// Label butir pengakuan (`wajib_diakui`). Kode baru dari server ditampilkan
/// mentah, bukan ditebak.
String labelButirPengakuan(String kode, AppLocalizations l10n) =>
    switch (kode) {
      ButirPengakuanAcuan.terbitCetakBerubah => l10n.alurAcuanButirTerbit,
      ButirPengakuanAcuan.bersamaAntarVarian => l10n.alurAcuanButirBersama,
      ButirPengakuanAcuan.sesiGagal => l10n.alurAcuanButirSesiGagal,
      _ => kode,
    };

/// Label status simulasi.
String labelStatusSimulasi(SimulasiVersiAcuan sim, AppLocalizations l10n) =>
    switch (sim.status) {
      StatusSimulasiAcuan.belumAda => l10n.alurAcuanSimBelumAda,
      StatusSimulasiAcuan.terbaru => l10n.alurAcuanSimTerbaru,
      StatusSimulasiAcuan.kedaluwarsa => l10n.alurAcuanSimKedaluwarsa,
      StatusSimulasiAcuan.gagal => l10n.alurAcuanSimGagal,
      StatusSimulasiAcuan.tidakDikenal => sim.kodeStatus,
    };

/// Pesan galat aksi alur dalam Bahasa Indonesia/Inggris (l10n) — kode server
/// dipetakan; teks exception mentah TIDAK pernah ditampilkan.
String pesanGalatAlurAcuan(Object galat, AppLocalizations l10n) {
  if (galat is ApiException) {
    final body = galat.body;
    switch (KodeGalatAlurAcuan.dariKode(body['kode'])) {
      case KodeGalatAlurAcuan.statusTidakSesuai:
        return l10n.alurAcuanGalatStatus;
      case KodeGalatAlurAcuan.jenisTidakDidukung:
        return l10n.alurAcuanGalatJenis;
      case KodeGalatAlurAcuan.hanyaSuperAdmin:
        return l10n.alurAcuanGalatHanyaSuperAdmin;
      case KodeGalatAlurAcuan.pengesahIkutMenyunting:
        return l10n.alurAcuanGalatPengesahIkut;
      case KodeGalatAlurAcuan.berlakuMulaiLampau:
        return l10n.alurAcuanGalatBerlakuLampau;
      case KodeGalatAlurAcuan.simulasiBelumAda:
        return l10n.alurAcuanGalatSimulasiBelumAda;
      case KodeGalatAlurAcuan.simulasiKedaluwarsa:
        return l10n.alurAcuanGalatSimulasiKedaluwarsa;
      case KodeGalatAlurAcuan.simulasiGagal:
        return l10n.alurAcuanGalatSimulasiGagal;
      case KodeGalatAlurAcuan.pengakuanWajib:
        final rincian = body['rincian'];
        final butir = rincian is Map && rincian['butir'] is List
            ? [
                for (final b in rincian['butir'] as List)
                  labelButirPengakuan('$b', l10n),
              ]
            : const <String>[];
        return l10n.alurAcuanGalatPengakuan(
          butir.isEmpty ? '—' : butir.join(', '),
        );
      case KodeGalatAlurAcuan.rentangBentrok:
        return l10n.alurAcuanGalatRentang;
      case KodeGalatAlurAcuan.konfirmasiSandiSalah:
        return l10n.alurAcuanGalatSandi;
      case KodeGalatAlurAcuan.bukanAplikasiIni:
      case KodeGalatAlurAcuan.bukanAkunStudio:
        return l10n.alurAcuanGalatBukanAplikasi;
      case KodeGalatAlurAcuan.lain:
        return switch (galat.status) {
          401 || 403 => l10n.alurAcuanGalatTidakBerwenang,
          404 => l10n.alurAcuanGalatTidakDitemukan,
          429 => l10n.alurAcuanGalatTerlaluSering,
          422 => l10n.alurAcuanGalatIsian,
          _ => l10n.alurAcuanGalatUmum,
        };
    }
  }
  if (galat is KoneksiException) return l10n.alurAcuanGalatKoneksi;
  if (galat is TokenHilangException) return l10n.alurAcuanGalatTidakBerwenang;
  return l10n.alurAcuanGalatUmum;
}
