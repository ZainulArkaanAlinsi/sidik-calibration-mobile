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
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/kalibrasi_teknisi_provider.dart';
import '../../providers/kesiapan_pindai_lembar_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/auth_service.dart' show gagalJaringan;
import '../../widgets/biru_awan/hero_langit.dart';
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
/// Tampilan Biru Awan (L7a, `docs/desain-ulang/LAYAR.md` 01): kepala dengan
/// lonceng, sapaan + kalimat ringkas, hero langit berisi "Mulai kalibrasi",
/// lalu bagian-bagiannya urut pekerjaannya: perbaiki yang dikembalikan,
/// lanjutkan draf, lihat apa yang sudah terkirim. Tidak ada dashboard,
/// grafik, panel 3D, daftar alat, atau arsip — semuanya pernah dibangun untuk
/// teknisi dan tidak ada yang dipakai di lapangan; yang ada cuma membuat app
/// lambat dibuka.
///
/// Tiga daftar dimuat sendiri-sendiri (satu gagal tidak menjatuhkan yang
/// lain), masing-masing SATU permintaan halaman pertama, dan tiap bagian
/// punya keadaannya sendiri: kerangka saat memuat, kabar saat kosong, galat
/// dengan "Coba lagi", dan "tanpa koneksi" bila yang gagal jaringannya.
/// Angka di kalimat judul datang dari daftar yang sama dengan bagian di
/// bawahnya; tidak ada permintaan atau provider tambahan.
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
    final nama = ref.watch(authProvider.select((s) => s.value?.nama));

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
                  child: _Sapaan(
                    nama: nama,
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
                    child: _Hero(
                      onMulai: () => buka(
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
                    judul: l10n.drafTitle,
                    kosong: l10n.tekDrafKosong,
                    isi: draf,
                    onCobaLagi: () => ref.invalidate(drafProvider),
                    bangunKerangka: (_) => const _KerangkaDraf(),
                    bangunIsi: (context, daftar) => _GeserDraf(
                      daftar: daftar,
                      onBuka: (s) => _bukaSesi(context, ref, s),
                    ),
                  ),
                ),
                MasukBerurutan(
                  indeks: 2,
                  child: _Bagian(
                    kunci: 'bagian-terkirim',
                    judul: l10n.tekTerkirim,
                    kosong: l10n.tekTerkirimKosong,
                    isi: terkirim,
                    onCobaLagi: () => ref.invalidate(terkirimTerakhirProvider),
                    bangunKerangka: (_) => const _KerangkaTerkirim(),
                    bangunIsi: (context, daftar) => Padding(
                      padding: _tepi,
                      child: PanelBaris.daftar(
                        anak: [for (final s in daftar) _BarisTerkirim(sesi: s)],
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

/// Stempel status satu baris Terkirim. Status sesi memakai pemetaan yang sudah
/// ada ([StatusTampil.dariKode]); satu pengecualian: "menunggu approval"
/// ditulis penuh ("Menunggu approval", seperti artboard dan layar lama) karena
/// kata "Menunggu" saja di daftar kiriman tidak menyebut menunggu siapa.
Widget _stempel(AppLocalizations l10n, CalibrationStatus status) =>
    status == CalibrationStatus.menungguApproval
    ? StempelSidik.teks(
        teks: l10n.historyStatusMenungguApproval,
        nada: NadaStempel.tunggu,
        ikon: Icons.hourglass_empty,
      )
    : StempelSidik(StatusTampil.dariKode(_kodeStatus(status)));

/// Logo, nama lab, dan lonceng notifikasi (lencana koral = belum dibaca).
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

/// "Halo, {nama}" + kalimat 28/34: "{n} draf belum dikirim. {m} menunggu
/// approval." Bagian bernilai 0 tidak ditulis. Angkanya dihitung dari daftar
/// yang sudah dimuat bagian di bawahnya: draf = isi bagian Draf; menunggu
/// approval = sesi berstatus itu di antara kiriman terakhir yang dimuat
/// (halaman pertama, paling banyak sepuluh), bukan hitungan seluruh lab.
class _Sapaan extends StatelessWidget {
  const _Sapaan({
    required this.nama,
    required this.revisi,
    required this.draf,
    required this.terkirim,
  });

  final String? nama;
  final AsyncValue<List<CalibrationHistoryItem>> revisi;
  final AsyncValue<List<CalibrationHistoryItem>> draf;
  final AsyncValue<List<CalibrationHistoryItem>> terkirim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    final nDraf = draf.value?.length ?? 0;
    final nTunggu =
        terkirim.value
            ?.where((s) => s.status == CalibrationStatus.menungguApproval)
            .length ??
        0;
    final potongan = <String>[
      if (nDraf > 0) l10n.tekBerandaDrafBelumDikirim(nDraf),
      if (nTunggu > 0) l10n.tekBerandaMenungguApproval(nTunggu),
    ];
    // "Semua terkirim" hanya bila ketiga daftar sudah terbaca dan tidak ada
    // lembar yang menunggu diperbaiki; selain itu judul netral, bukan klaim.
    final bersih =
        (revisi.value?.isEmpty ?? false) && draf.hasValue && terkirim.hasValue;

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
          child: Text.rich(
            TextSpan(
              children: [
                if (potongan.isEmpty)
                  TextSpan(
                    text: bersih
                        ? l10n.tekBerandaBersih
                        : l10n.tekBerandaJudulNetral,
                  )
                else
                  for (var i = 0; i < potongan.length; i++)
                    TextSpan(
                      text: i == 0 ? potongan[i] : ' ${potongan[i]}',
                      style: i == 0 ? null : TextStyle(color: m.tinta2),
                    ),
              ],
            ),
            style: HurufBiruAwan.judulLayar.copyWith(color: m.tinta),
          ),
        ),
      ],
    );
  }
}

/// Hero langit: "Kalibrasi baru" + judul + tombol navy "Mulai kalibrasi".
class _Hero extends StatelessWidget {
  const _Hero({required this.onMulai});

  final VoidCallback onMulai;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return HeroLangit(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tekHeroLabel,
            style: HurufLanjutBiruAwan.labelKpi.copyWith(color: m.tinta),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Dibatasi selebar visual hero (188) supaya tidak menabrak gambar
          // alat yang menumpang di kanan bawah (L4).
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: UkuranBiruAwan.visualHero,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.tekHeroJudul,
                style: HurufBiruAwan.judulHero.copyWith(color: m.tinta),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TombolSidik(
            key: const ValueKey('tombol-mulai-kalibrasi'),
            label: l10n.dashStartCalibration,
            ikon: Icons.add_task,
            ragam: RagamTombolSidik.tegas,
            lebarPenuh: false,
            onPressed: onMulai,
          ),
        ],
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

  /// Isi bagian; mengatur bantalan tepinya sendiri (daftar draf menggeser
  /// sampai tepi layar).
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
                  latar: LatarKartu.kabut,
                  child: Text(
                    kosong,
                    style: HurufBiruAwan.keterangan.copyWith(color: m.tinta),
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

/// Draf: baris geser mendatar, kartu 196 x 148 (tinggi ikut skala huruf).
class _GeserDraf extends StatelessWidget {
  const _GeserDraf({required this.daftar, required this.onBuka});

  final List<CalibrationHistoryItem> daftar;
  final void Function(CalibrationHistoryItem) onBuka;

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.textScalerOf(
      context,
    ).scale(UkuranBiruAwan.kartuDrafTinggi);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: KalibrasiTeknisiScreen._tepi,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < daftar.length; i++) ...[
            if (i > 0) const SizedBox(width: JarakBiruAwan.blok),
            SizedBox(
              width: UkuranBiruAwan.kartuDrafLebar,
              height: tinggi,
              child: _KartuDraf(
                sesi: daftar[i],
                onTap: () => onBuka(daftar[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KartuDraf extends StatelessWidget {
  const _KartuDraf({required this.sesi, required this.onTap});

  final CalibrationHistoryItem sesi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return KartuSidik24(
      key: ValueKey('kartu-sesi-teknisi-${sesi.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sesi.nomorSesi != null)
            Text(
              sesi.nomorSesi!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HurufBiruAwan.nomor.copyWith(color: m.tinta2),
            ),
          Text(
            sesi.namaAlat,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HurufBiruAwan.judulBaris.copyWith(color: m.tinta),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  sesi.namaPelanggan ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HurufBiruAwan.catatan.copyWith(color: m.tinta2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const UbinIkon.baris(ikon: Icons.edit_note),
            ],
          ),
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

/// Terkirim = baca saja: barisnya tidak membuka lembar, hanya menunjukkan
/// statusnya.
class _BarisTerkirim extends StatelessWidget {
  const _BarisTerkirim({required this.sesi});

  final CalibrationHistoryItem sesi;

  @override
  Widget build(BuildContext context) {
    return BarisDaftar72(
      key: ValueKey('kartu-sesi-teknisi-${sesi.id}'),
      awal: const UbinIkon.baris(ikon: Icons.straighten),
      judul: sesi.namaAlat,
      nomor: sesi.nomorSesi,
      keterangan: sesi.namaPelanggan,
      akhir: _stempel(AppLocalizations.of(context), sesi.status),
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

class _KerangkaDraf extends StatelessWidget {
  const _KerangkaDraf();

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.textScalerOf(
      context,
    ).scale(UkuranBiruAwan.kartuDrafTinggi);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: KalibrasiTeknisiScreen._tepi,
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: JarakBiruAwan.blok),
            SizedBox(
              width: UkuranBiruAwan.kartuDrafLebar,
              height: tinggi,
              child: const KartuSidik24(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Blok(
                      lebar: AppUkuran.skeletonLebarKeterangan,
                      tinggi: AppUkuran.skeletonKeterangan,
                      radius: BentukBiruAwan.pil,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _Blok(
                      lebar: AppUkuran.skeletonLebarJudul,
                      tinggi: AppUkuran.skeletonJudul,
                      radius: BentukBiruAwan.pil,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KerangkaTerkirim extends StatelessWidget {
  const _KerangkaTerkirim();

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
                        radius: BentukBiruAwan.pil,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      _Blok(
                        lebar: AppUkuran.skeletonLebarKeterangan,
                        tinggi: AppUkuran.skeletonKeterangan,
                        radius: BentukBiruAwan.pil,
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
