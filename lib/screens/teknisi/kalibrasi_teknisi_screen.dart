import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/beku_lembar_kerja.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/draf_lokal_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/kalibrasi_teknisi_provider.dart';
import '../../providers/kesiapan_pindai_lembar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/auth_service.dart' show gagalJaringan;
import '../../services/draf_lokal.dart' show DrafLokal;
import '../../widgets/biru_awan/kartu_sidik24.dart';
import '../../widgets/biru_awan/kepala_layar.dart';
import '../../widgets/biru_awan/lencana.dart';
import '../../widgets/biru_awan/panel_baris.dart';
import '../../widgets/biru_awan/stempel_sidik.dart';
import '../../widgets/biru_awan/tombol_sidik.dart';
import '../../widgets/biru_awan/ubin_ikon.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/status_tampil.dart';
import '../../widgets/tombol_pindai_lembar.dart';
import '../calibration/category_picker_screen.dart';
import '../calibration/instrument_picker_screen.dart'
    show profilLembarKerjaUntuk;
import '../calibration/lembar_kerja_screen.dart';
import '../notification/notification_screen.dart';

/// Tab "Kalibrasi" — SATU-SATUNYA tempat kerja teknisi (keputusan pemilik
/// 15 Okt 2026, K-50-14: teknisi hanya mengisi lembar kerja + profil).
///
/// REVISI 16 Nov 2026 (R1, `docs/desain-ulang/REVISI-16NOV.md`; REVISI-1 §7
/// "Beranda teknisi"): area kerja yang ringkas menggantikan banner besar dan
/// carousel. Susunannya, dari atas: header identitas (logo, nama lab, lonceng),
/// sapaan, judul "Pekerjaan saya", ringkasan tiga angka (draf, perlu revisi,
/// menunggu pemeriksaan), tombol "Kalibrasi baru", lalu bagian-bagiannya urut
/// pekerjaannya: perbaiki yang dikembalikan, "Lanjutkan pekerjaan" (draf,
/// DAFTAR VERTIKAL, bukan carousel), dan "Aktivitas terbaru" (kiriman terakhir).
/// Tiap item menampilkan nama alat, pelanggan, nomor kalibrasi, waktu pembaruan,
/// dan status. Tidak ada dashboard, grafik, panel 3D, daftar alat, atau arsip.
///
/// Tiga daftar dimuat sendiri-sendiri (satu gagal tidak menjatuhkan yang
/// lain), masing-masing SATU permintaan halaman pertama, dan tiap bagian
/// punya keadaannya sendiri: kerangka saat memuat, kabar saat kosong, galat
/// dengan "Coba lagi", dan "tanpa koneksi" bila yang gagal jaringannya.
/// Angka di ringkasan datang dari daftar yang sama dengan bagian di bawahnya;
/// tidak ada permintaan tambahan. Satu-satunya bacaan lain: salinan lembar di
/// HP ini (`drafLokalProvider`), hanya untuk menggerbangi klaim "semua
/// terkirim".
class KalibrasiTeknisiScreen extends ConsumerWidget {
  const KalibrasiTeknisiScreen({super.key});

  static void segarkan(WidgetRef ref) {
    ref
      ..invalidate(perluRevisiTeknisiProvider)
      ..invalidate(drafProvider)
      ..invalidate(terkirimTerakhirProvider);
  }

  /// Buka lembar kerja, lalu segarkan ketiga daftar sesudah kembali — lembar
  /// yang barusan dikirim pindah dari Draf/Perlu revisi ke Terkirim.
  static Future<void> buka(
    BuildContext context,
    WidgetRef ref,
    Widget layar,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => layar));
    if (context.mounted) segarkan(ref);
  }

  /// Draf & perlu revisi dibuka langsung ke lembar kerjanya.
  ///
  /// Profil dari server dulu; tebakan nama cuma cadangan. Kalau dua-duanya tak
  /// dikenal, JANGAN jatuh ke lembar pH: angka yang sudah diketik akan mendarat
  /// di baris pH yang salah.
  static void _bukaSesi(
    BuildContext context,
    WidgetRef ref,
    CalibrationHistoryItem sesi,
  ) {
    final profil = sesi.profil ?? profilLembarKerjaUntuk(sesi.namaAlat);
    if (profil == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const ValueKey('snackbar-profil-tak-dikenal'),
            content: Text(AppLocalizations.of(context).tekProfilTakDikenal),
          ),
        );
      return;
    }
    buka(
      context,
      ref,
      BekuLembarKerja(
        child: LembarKerjaScreen(sesiId: sesi.id, profil: profil),
      ),
    );
  }

  static const _tepi = EdgeInsets.symmetric(horizontal: AppSpacing.md);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final revisi = ref.watch(perluRevisiTeknisiProvider);
    final draf = ref.watch(drafProvider);
    final terkirim = ref.watch(terkirimTerakhirProvider);
    // Salinan lembar di HP ini: dibaca SAJA, hanya untuk menggerbangi klaim
    // "semua terkirim". Daftarnya tidak ditampilkan di sini (tempatnya layar
    // Draf).
    final lokal = ref.watch(drafLokalProvider);
    final nama = ref.watch(authProvider.select((s) => s.value?.nama));
    // "Sekarang" milik `jamProvider` (bisa dipatok di tes dan golden), supaya
    // "diperbarui 5 menit lalu" tidak bergantung jam dinding.
    final sekarang = ref.watch(jamProvider)();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            segarkan(ref);
            // Daftar jenis lembar di-cache sepanjang sesi; tarik-segarkan
            // satu-satunya jalan memintanya lagi (tombol "Pindai lembar
            // kerja").
            ref.invalidate(kesiapanPindaiLembarProvider);
            await Future.wait([
              ref
                  .read(perluRevisiTeknisiProvider.future)
                  .then((_) {}, onError: (_) {}),
              ref.read(drafProvider.future).then((_) {}, onError: (_) {}),
              ref
                  .read(terkirimTerakhirProvider.future)
                  .then((_) {}, onError: (_) {}),
            ]);
          },
          child: ReadableWidth(
            child: ListView(
              // Selalu bisa ditarik, juga saat isinya pendek: tarik-segarkan
              // satu-satunya jalan pulih dari galat awal (mis. tanpa koneksi).
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                const Padding(padding: _tepi, child: _Kepala()),
                Padding(
                  padding: _tepi.copyWith(top: AppSpacing.md),
                  child: _Judul(
                    nama: nama,
                    revisi: revisi,
                    draf: draf,
                    terkirim: terkirim,
                    lokal: lokal,
                  ),
                ),
                const SizedBox(height: JarakBiruAwan.blok),
                Padding(
                  padding: _tepi,
                  child: _Ringkasan(
                    revisi: revisi,
                    draf: draf,
                    terkirim: terkirim,
                  ),
                ),
                const SizedBox(height: JarakBiruAwan.blok),
                MasukBerurutan(
                  indeks: 0,
                  child: Padding(
                    padding: _tepi,
                    child: TombolSidik(
                      key: const ValueKey('tombol-mulai-kalibrasi'),
                      label: l10n.tekKalibrasiBaru,
                      ikon: Icons.add_task,
                      onPressed: () => buka(
                        context,
                        ref,
                        const BekuLembarKerja(child: CategoryPickerScreen()),
                      ),
                    ),
                  ),
                ),
                // Tampil hanya bila server menyatakan ada jenis lembar yang
                // boleh dipindai; selain itu tidak memakan ruang.
                Padding(
                  padding: _tepi,
                  child: TombolPindaiLembar(
                    jarakAtas: JarakBiruAwan.blok,
                    setelahKembali: () async => segarkan(ref),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Bagian(
                  kunci: 'bagian-perlu-revisi',
                  sembunyiBilaKosong: true,
                  judul: l10n.tekPerluRevisi,
                  kosong: l10n.tekPerluRevisiKosong,
                  isi: revisi,
                  onCobaLagi: () => ref.invalidate(perluRevisiTeknisiProvider),
                  bangunKerangka: (_) => const SizedBox.shrink(),
                  bangunIsi: (context, daftar) => Padding(
                    padding: _tepi,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in daftar)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: JarakBiruAwan.blok,
                            ),
                            child: _KartuRevisi(
                              sesi: s,
                              onTap: () => _bukaSesi(context, ref, s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                MasukBerurutan(
                  indeks: 1,
                  child: _Bagian(
                    kunci: 'bagian-draf',
                    judul: l10n.tekLanjutkanPekerjaan,
                    kosong: l10n.tekDrafKosong,
                    isi: draf,
                    onCobaLagi: () => ref.invalidate(drafProvider),
                    bangunKerangka: (_) => const _KerangkaDaftar(),
                    bangunIsi: (context, daftar) => Padding(
                      padding: _tepi,
                      // DAFTAR VERTIKAL, bukan carousel: semua draf terlihat
                      // dan terjangkau dengan satu gulir.
                      child: PanelBaris.daftar(
                        anak: [
                          for (final s in daftar)
                            _BarisPekerjaan(
                              sesi: s,
                              ikon: Icons.edit_note,
                              status: StempelSidik(
                                StatusTampil.dariKode(_kodeStatus(s.status)),
                              ),
                              sekarang: sekarang,
                              onTap: () => _bukaSesi(context, ref, s),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                MasukBerurutan(
                  indeks: 2,
                  child: _Bagian(
                    kunci: 'bagian-terkirim',
                    judul: l10n.tekAktivitasTerbaru,
                    kosong: l10n.tekTerkirimKosong,
                    isi: terkirim,
                    onCobaLagi: () => ref.invalidate(terkirimTerakhirProvider),
                    bangunKerangka: (_) => const _KerangkaDaftar(),
                    bangunIsi: (context, daftar) => Padding(
                      padding: _tepi,
                      child: PanelBaris.daftar(
                        anak: [
                          for (final s in daftar)
                            _BarisPekerjaan(
                              sesi: s,
                              ikon: Icons.straighten,
                              status: _stempel(l10n, s.status),
                              sekarang: sekarang,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kode status API untuk pemetaan tampilan yang sudah ada
/// ([StatusTampil.dariKode]); satu status satu tampilan di seluruh app.
String _kodeStatus(CalibrationStatus s) => switch (s) {
  CalibrationStatus.draft => 'draft',
  CalibrationStatus.menungguApproval => 'menunggu_approval',
  CalibrationStatus.disetujui => 'disetujui',
  CalibrationStatus.perluRevisi => 'perlu_revisi',
};

/// Stempel status satu baris. Status sesi memakai pemetaan yang sudah ada
/// ([StatusTampil.dariKode]); satu pengecualian: "menunggu approval" ditulis
/// penuh ("Menunggu approval", seperti layar lama) karena kata "Menunggu"
/// saja di daftar kiriman tidak menyebut menunggu siapa.
Widget _stempel(AppLocalizations l10n, CalibrationStatus status) =>
    status == CalibrationStatus.menungguApproval
    ? StempelSidik.teks(
        teks: l10n.historyStatusMenungguApproval,
        nada: NadaStempel.tunggu,
        ikon: Icons.hourglass_empty,
      )
    : StempelSidik(StatusTampil.dariKode(_kodeStatus(status)));

/// Logo, nama lab, dan lonceng notifikasi (lencana merah = belum dibaca).
class _Kepala extends ConsumerWidget {
  const _Kepala();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Gagal mengambil angka lencana dianggap 0, bukan galat: lonceng yang
    // galat tidak menolong siapa-siapa dan layar notifikasinya sendiri tetap
    // bisa dibuka (sama seperti `NotificationBell` lama).
    final belumDibaca = ref.watch(unreadCountProvider).value ?? 0;

    return KepalaTab(
      judul: l10n.tekBerandaMerek,
      subjudul: l10n.tekBerandaKeteranganMerek,
      aksi: [
        // Simpul sendiri: tanpa `container`, tombol bulat menyatu dengan nama
        // dan keterangan lab di sebelahnya jadi satu simpul pembaca layar.
        Semantics(
          container: true,
          child: LoncengBerlencana(
            label: belumDibaca > 0
                ? l10n.tekBerandaNotifikasiBelumDibaca(belumDibaca)
                : l10n.navNotifications,
            jumlah: belumDibaca,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Isi daftar hanya bila terbaca; memuat/gagal = `null`, BUKAN daftar kosong.
List<T>? _terbaca<T>(AsyncValue<List<T>> daftar) =>
    daftar.hasValue ? daftar.value : null;

/// Jumlah kiriman terakhir yang berstatus "menunggu approval" di antara yang
/// SUDAH dimuat (halaman pertama, paling banyak sepuluh), atau `null` bila
/// daftar belum terbaca. Hitungan eksak nanti memakai `status=menunggu_approval`
/// + `meta.total` dari server (CalibrationController.php:184, repo API);
/// sekarang server mengembalikan 15 sesi terbaru semua status, jadi angkanya
/// bisa kurang dari yang sebenarnya menunggu di seluruh lab.
int? _menunggu(AsyncValue<List<CalibrationHistoryItem>> terkirim) => _terbaca(
  terkirim,
)?.where((s) => s.status == CalibrationStatus.menungguApproval).length;

/// "Halo, {nama}", judul "Pekerjaan saya", dan SATU klaim bersyarat: "Semua
/// lembar sudah terkirim." Klaim itu tidak pernah lebih yakin daripada yang
/// sudah terbaca: hanya bila ketiga daftar server terbaca dan kosong DAN tidak
/// ada salinan di HP ini yang belum tersinkron ([lokal] terbaca dan kosong).
/// Selain itu tidak ada klaim sama sekali; angka-angkanya ada di [_Ringkasan].
class _Judul extends StatelessWidget {
  const _Judul({
    required this.nama,
    required this.revisi,
    required this.draf,
    required this.terkirim,
    required this.lokal,
  });

  final String? nama;
  final AsyncValue<List<CalibrationHistoryItem>> revisi;
  final AsyncValue<List<CalibrationHistoryItem>> draf;
  final AsyncValue<List<CalibrationHistoryItem>> terkirim;
  final AsyncValue<List<DrafLokal>> lokal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    final dataRevisi = _terbaca(revisi);
    final dataDraf = _terbaca(draf);
    final dataTerkirim = _terbaca(terkirim);
    // Salinan di HP: HANYA yang sudah selesai dibaca (`AsyncData`). `hasValue`
    // tidak cukup — pembacaan yang sedang diulang atau gagal masih membawa
    // nilai sebelumnya (mis. `[]` waktu akun belum terbaca), dan nilai basi
    // tidak boleh membenarkan klaim "semua terkirim".
    final dataLokal = lokal is AsyncData<List<DrafLokal>> ? lokal.value : null;

    final nTunggu = _menunggu(terkirim) ?? 0;
    final bersih =
        nTunggu == 0 &&
        (dataRevisi?.isEmpty ?? false) &&
        (dataDraf?.isEmpty ?? false) &&
        dataTerkirim != null &&
        (dataLokal?.isEmpty ?? false);

    final depan = nama?.trim().split(RegExp(r'\s+')).first ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (depan.isNotEmpty)
          Text(
            l10n.dashGreetingName(depan),
            style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
          ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(
            l10n.tekPekerjaanSaya,
            style: HurufBiruAwan.judulLayar.copyWith(color: m.tinta),
          ),
        ),
        if (bersih) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: UkuranKomponenBiruAwan.ikonTombol,
                color: m.lulus,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.tekBerandaBersih,
                  style: HurufBiruAwan.ringkasan.copyWith(color: m.tinta),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ringkasan tiga angka: draf, perlu revisi, menunggu pemeriksaan.
///
/// Tiap angka datang dari daftar yang SAMA dengan bagian di bawahnya. Daftar
/// yang belum terbaca (memuat atau gagal) ditulis "–", BUKAN 0: nol adalah
/// klaim. "Menunggu pemeriksaan" dihitung dari kiriman terakhir yang dimuat
/// (paling banyak sepuluh), dan keterangannya menyebut itu ("dari {n} kiriman
/// terakhir"). Layar sempit atau huruf besar menyusunnya ke bawah, tiap baris
/// penuh, supaya kata tidak terpotong.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({
    required this.revisi,
    required this.draf,
    required this.terkirim,
  });

  final AsyncValue<List<CalibrationHistoryItem>> revisi;
  final AsyncValue<List<CalibrationHistoryItem>> draf;
  final AsyncValue<List<CalibrationHistoryItem>> terkirim;

  /// Lebar sel (dp) di bawah ini: susunan ke bawah. Di bawahnya kata terpanjang
  /// ("pemeriksaan", 13 sp) tidak muat dalam satu baris dan akan putus di
  /// tengah kata.
  static const double _lebarSelMin = 112;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dataTerkirim = _terbaca(terkirim);
    final nRevisi = _terbaca(revisi)?.length;

    final sel = <_DataSel>[
      _DataSel(
        kunci: 'ringkasan-draf',
        label: l10n.drafTitle,
        nilai: _terbaca(draf)?.length,
      ),
      _DataSel(
        kunci: 'ringkasan-revisi',
        label: l10n.tekPerluRevisi,
        nilai: nRevisi,
        // Krem HANYA bila ada yang perlu diperiksa.
        awas: (nRevisi ?? 0) > 0,
      ),
      _DataSel(
        kunci: 'ringkasan-menunggu',
        label: l10n.tekRingkasanMenunggu,
        nilai: _menunggu(terkirim),
        catatan: dataTerkirim == null
            ? null
            : l10n.tekRingkasanDariKiriman(dataTerkirim.length),
      ),
    ];

    return LayoutBuilder(
      builder: (context, batas) {
        final skala = MediaQuery.textScalerOf(context).scale(1);
        final lebarSel = (batas.maxWidth - 2 * JarakBiruAwan.blok) / 3;
        final bawah = lebarSel < _lebarSelMin || skala > 1.15;
        if (bawah) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sel.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _SelRingkasan(data: sel[i], baris: true),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sel.length; i++) ...[
                if (i > 0) const SizedBox(width: JarakBiruAwan.blok),
                Expanded(child: _SelRingkasan(data: sel[i])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DataSel {
  const _DataSel({
    required this.kunci,
    required this.label,
    required this.nilai,
    this.catatan,
    this.awas = false,
  });

  final String kunci;
  final String label;

  /// `null` = daftarnya belum terbaca ("–").
  final int? nilai;

  /// Dasar hitungan, bila bukan seluruh daftar.
  final String? catatan;
  final bool awas;
}

class _SelRingkasan extends StatelessWidget {
  const _SelRingkasan({required this.data, this.baris = false});

  final _DataSel data;

  /// Susunan satu baris penuh (label di kiri, angka di kanan).
  final bool baris;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final nilai = data.nilai;
    final teksNilai = nilai == null ? '–' : '$nilai';
    final tinta = data.awas ? m.awas : m.tinta2;

    final judul = Text(
      data.label,
      style: HurufLanjutBiruAwan.labelKpi.copyWith(color: tinta),
    );
    final angka = Text(
      teksNilai,
      style: HurufLanjutBiruAwan.angkaKpi.copyWith(color: m.tinta),
    );
    final catatan = data.catatan == null
        ? null
        : Text(
            data.catatan!,
            style: HurufBiruAwan.catatan.copyWith(color: m.tinta2),
          );

    return Semantics(
      key: ValueKey(data.kunci),
      container: true,
      excludeSemantics: true,
      label:
          '${data.label}: ${nilai ?? l10n.tekRingkasanBelumTerbaca}'
          '${data.catatan == null ? '' : ', ${data.catatan}'}',
      child: KartuSidik24(
        latar: data.awas ? LatarKartu.awas : LatarKartu.kertas,
        padding: const EdgeInsets.symmetric(
          horizontal: JarakBiruAwan.blok,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: baris
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [judul, ?catatan],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  angka,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [judul, angka, ?catatan],
              ),
      ),
    );
  }
}

/// Satu bagian daftar: judul + jumlah, lalu SALAH SATU dari kerangka (memuat),
/// kabar kosong, galat / tanpa koneksi dengan "Coba lagi", atau isinya. Tiap
/// bagian memuat dan gagal sendiri-sendiri.
class _Bagian extends StatelessWidget {
  const _Bagian({
    required this.kunci,
    required this.judul,
    required this.kosong,
    required this.isi,
    required this.onCobaLagi,
    required this.bangunKerangka,
    required this.bangunIsi,
    this.sembunyiBilaKosong = false,
  });

  /// Bagian lama yang hanya muncul kalau ADA isinya (Perlu revisi: jalur Tolak
  /// dicabut 15 Okt 2026, tinggal sesi lama). Selama memuat pun tidak
  /// memajang apa-apa; galat tetap tampil dengan tombol coba lagi.
  final bool sembunyiBilaKosong;

  final String kunci;
  final String judul;
  final String kosong;
  final AsyncValue<List<CalibrationHistoryItem>> isi;
  final VoidCallback onCobaLagi;
  final WidgetBuilder bangunKerangka;

  /// Isi bagian; mengatur bantalan tepinya sendiri.
  final Widget Function(BuildContext, List<CalibrationHistoryItem>) bangunIsi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final data = isi.value;

    if (sembunyiBilaKosong && !isi.hasError && (data == null || data.isEmpty)) {
      return const SizedBox.shrink();
    }

    final Widget keadaan;
    if (data != null) {
      keadaan = data.isEmpty
          ? Padding(
              padding: KalibrasiTeknisiScreen._tepi,
              child: Semantics(
                container: true,
                child: KartuSidik24(
                  child: Text(
                    kosong,
                    style: HurufBiruAwan.keterangan.copyWith(color: m.tinta2),
                  ),
                ),
              ),
            )
          : bangunIsi(context, data);
    } else if (isi.hasError) {
      final tanpaKoneksi = gagalJaringan(isi.error);
      keadaan = Padding(
        padding: KalibrasiTeknisiScreen._tepi,
        child: Semantics(
          container: true,
          child: KartuSidik24(
            latar: LatarKartu.galat,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UbinIkon(
                      ikon: tanpaKoneksi ? Icons.wifi_off : Icons.error_outline,
                      warna: IsiBiruAwan.koral,
                    ),
                    const SizedBox(width: JarakBiruAwan.blok),
                    Expanded(
                      child: Text(
                        tanpaKoneksi ? l10n.tekTanpaKoneksi : l10n.tekGagalMuat,
                        style: HurufBiruAwan.keterangan.copyWith(
                          color: m.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TombolSidik(
                  label: l10n.folderRetry,
                  ragam: RagamTombolSidik.tegas,
                  lebarPenuh: false,
                  onPressed: onCobaLagi,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      keadaan = Semantics(
        container: true,
        label: l10n.tekMemuatDaftar,
        child: ExcludeSemantics(child: bangunKerangka(context)),
      );
    }

    return Padding(
      key: ValueKey(kunci),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: KalibrasiTeknisiScreen._tepi,
            child: Semantics(
              container: true,
              header: true,
              child: Text.rich(
                TextSpan(
                  text: judul,
                  children: [
                    // "Draf 0" tidak ditulis: kabar kosongnya sudah di bawah.
                    if (data != null && data.isNotEmpty)
                      TextSpan(
                        text: ' ${data.length}',
                        style: TextStyle(
                          color: m.tinta2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: HurufBiruAwan.judulBagian.copyWith(color: m.tinta),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          keadaan,
        ],
      ),
    );
  }
}

/// Lembar yang dikembalikan: catatan Master Data ditulis UTUH — itu yang harus
/// dikerjakan, dan teknisi tidak perlu membuka layar lain untuk membacanya.
class _KartuRevisi extends StatelessWidget {
  const _KartuRevisi({required this.sesi, required this.onTap});

  final CalibrationHistoryItem sesi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final catatan = sesi.catatanRevisi?.trim();
    final rincian = [?sesi.nomorSesi, ?sesi.namaPelanggan].join(' · ');

    return KartuSidik24(
      key: ValueKey('kartu-sesi-teknisi-${sesi.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UbinIkon.baris(
                ikon: Icons.error_outline,
                warna: IsiBiruAwan.kuning,
              ),
              const SizedBox(width: JarakBiruAwan.blok),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sesi.namaAlat,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HurufBiruAwan.judulBaris.copyWith(color: m.tinta),
                    ),
                    if (rincian.isNotEmpty)
                      Text(
                        rincian,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HurufBiruAwan.catatan.copyWith(color: m.tinta2),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              catatan,
              style: HurufBiruAwan.keteranganKecil.copyWith(
                color: w.tintaGalat,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu pekerjaan di daftar vertikal (draf atau kiriman terakhir): nama alat,
/// pelanggan, nomor kalibrasi, waktu pembaruan, dan status. Draf bisa diketuk
/// (membuka lembarnya); kiriman terakhir hanya baca.
///
/// Waktu pembaruan = kapan sesi terakhir diubah server (`diubahPada`), atau
/// kapan dikirim bila itu satu-satunya titik waktu yang ada. Tanpa keduanya
/// baris waktu TIDAK ditulis (tidak ada titik waktu yang dikarang).
class _BarisPekerjaan extends StatelessWidget {
  const _BarisPekerjaan({
    required this.sesi,
    required this.ikon,
    required this.status,
    required this.sekarang,
    this.onTap,
  });

  final CalibrationHistoryItem sesi;
  final IconData ikon;
  final Widget status;
  final DateTime sekarang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waktu = sesi.diubahPada ?? sesi.dikirimPada;
    final locale = Localizations.localeOf(context).toString();

    return BarisDaftar72(
      key: ValueKey('kartu-sesi-teknisi-${sesi.id}'),
      awal: UbinIkon.baris(ikon: ikon),
      judul: sesi.namaAlat,
      keterangan: sesi.namaPelanggan,
      nomor: sesi.nomorSesi,
      catatan: waktu == null
          ? null
          : l10n.tekDiperbarui(
              waktuLalu(
                waktu,
                locale,
                baruSaja: l10n.waktuBaruSaja,
                menitLalu: l10n.waktuMenitLalu,
                jamLalu: l10n.waktuJamLalu,
                kemarin: l10n.waktuKemarin,
                hariLalu: l10n.waktuHariLalu,
                sekarang: sekarang,
              ),
            ),
      akhir: status,
      onTap: onTap,
    );
  }
}

/// Blok kerangka: diam (tanpa denyut) supaya layar yang sedang memuat tidak
/// menjadi satu-satunya gerak berulang dan tes tetap bisa `pumpAndSettle`.
class _Blok extends StatelessWidget {
  const _Blok({this.lebar, required this.tinggi, required this.radius});

  final double? lebar;
  final double tinggi;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lebar,
      height: tinggi,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SidikMaterial.of(context).kertasTepi,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _KerangkaDaftar extends StatelessWidget {
  const _KerangkaDaftar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: KalibrasiTeknisiScreen._tepi,
      child: PanelBaris.daftar(
        anak: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  _Blok(
                    lebar: UkuranKomponenBiruAwan.ubinBaris,
                    tinggi: UkuranKomponenBiruAwan.ubinBaris,
                    radius: BentukBiruAwan.ikonUbin,
                  ),
                  SizedBox(width: JarakBiruAwan.blok),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Blok(
                        lebar: AppUkuran.skeletonLebarJudul,
                        tinggi: AppUkuran.skeletonJudul,
                        radius: BentukBiruAwan.lencana,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      _Blok(
                        lebar: AppUkuran.skeletonLebarKeterangan,
                        tinggi: AppUkuran.skeletonKeterangan,
                        radius: BentukBiruAwan.lencana,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
