import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/utils/susun_daftar_arsip.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../models/garis_waktu_arsip.dart';
import '../../models/pencarian_arsip.dart';
import '../../providers/arsip_cari_provider.dart';
import '../../providers/auth_provider.dart' show authProvider;
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/master_data_provider.dart';
import '../../services/auth_service.dart' show ApiException, gagalJaringan;
import '../../widgets/app_button.dart';
import '../../widgets/galat_peran.dart' show galatSesiBerakhir;
import '../../widgets/master_detail_pane.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../history/calibration_detail_screen.dart';
import 'widgets/kartu_arsip.dart';

/// Arsip menurut waktu + pencarian terpadu.
///
/// Dua tampilan, satu kotak cari:
///
/// - **Garis waktu** (tanpa kata cari dan tanpa rentang tanggal): tahun ›
///   bulan › pekan › hari, dibuka satu tingkat per ketukan. Kelompok, label,
///   dan jumlahnya semua dari server — layar ini tidak menghitung pekan atau
///   jumlah apa pun.
/// - **Hasil cari** (ada kata ≥ 2 karakter atau rentang tanggal kalibrasi):
///   daftar sesi dari `GET /calibrations`, satu baris per alat (menurut id
///   alat; wakilnya sertifikat terbit terbaru).
///
/// Saringan PT berlaku di keduanya. Folder arsip fisik (PT › Tahun › Bulan ›
/// Jenis) tidak disentuh — layar ini cuma cara lain melihat dokumen yang sama.
///
/// Aksi utamanya SATU: mencari (kotak cari di puncak). Selebihnya saringan
/// (chip), penelusuran (ketuk kelompok), dan tombol sekunder.
///
/// Di lebar ≥ [AppUkuran.ambangDuaKolom] layar jadi dua kolom (daftar +
/// detail sesi); di bawah itu satu daftar dan detailnya dibuka lewat push.
///
/// Arsip selalu butuh server (tidak ada salinan lokal): saat tidak ada
/// koneksi layar bilang begitu, bukan menampilkan daftar basi.
class GarisWaktuArsipScreen extends ConsumerStatefulWidget {
  const GarisWaktuArsipScreen({super.key});

  @override
  ConsumerState<GarisWaktuArsipScreen> createState() =>
      _GarisWaktuArsipScreenState();
}

/// Batas panjang `q` di server (`422` kalau lebih).
const _batasHurufCari = 100;

/// Hasil pemilih PT. `id` null = "Semua PT".
typedef _PilihanPt = ({int? id, String? nama});

class _GarisWaktuArsipScreenState extends ConsumerState<GarisWaktuArsipScreen> {
  /// Kewajiban klien dari kontrak: pencarian server O(N) per lab, jadi tidak
  /// boleh ditembak per ketukan.
  static const _jedaCari = Duration(milliseconds: 300);

  final _cari = TextEditingController();
  Timer? _jeda;

  /// Yang sedang diketik, belum tentu sudah dikirim. Hanya untuk petunjuk
  /// "minimal 2 karakter".
  String _ketik = '';

  /// Sesi yang detailnya terbuka di panel kanan.
  int? _terpilih;

  /// Kunci alat (lihat `KelompokInstrumen.kunci`) yang sesi lainnya sedang
  /// dibentangkan.
  final _terbuka = <String>{};

  @override
  void dispose() {
    _jeda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _berubah(String teks) {
    _jeda?.cancel();
    setState(() => _ketik = teks);
    _jeda = Timer(
      _jedaCari,
      () => ref.read(filterArsipProvider.notifier).aturKata(teks),
    );
  }

  /// Tombol cari di papan ketik: langsung, tanpa menunggu jeda.
  void _kirim(String teks) {
    _jeda?.cancel();
    setState(() => _ketik = teks);
    ref.read(filterArsipProvider.notifier).aturKata(teks);
  }

  void _hapusCari() {
    _jeda?.cancel();
    _cari.clear();
    setState(() => _ketik = '');
    ref.read(filterArsipProvider.notifier).aturKata('');
  }

  void _hapusSemua() {
    _jeda?.cancel();
    _cari.clear();
    setState(() => _ketik = '');
    ref.read(filterArsipProvider.notifier).bersihkan();
  }

  Future<void> _pilihPt(FilterArsip filter) async {
    final hasil = await showModalBottomSheet<_PilihanPt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PilihPtSheet(terpilihId: filter.pelangganId),
    );
    if (hasil == null || !mounted) return;
    ref.read(filterArsipProvider.notifier).aturPelanggan(hasil.id, hasil.nama);
  }

  Future<void> _pilihTanggal(FilterArsip filter) async {
    final l10n = AppLocalizations.of(context);
    final sekarang = DateTime.now();
    final dari = filter.dari;
    final sampai = filter.sampai;

    final rentang = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(sekarang.year + 1, 12, 31),
      initialDateRange: dari != null && sampai != null
          ? DateTimeRange(start: dari, end: sampai)
          : null,
      helpText: l10n.gwPilihRentang,
    );
    if (rentang == null || !mounted) return;
    ref
        .read(filterArsipProvider.notifier)
        .aturRentang(rentang.start, rentang.end);
  }

  void _pilih(int sesiId, {required bool panelGanda}) {
    if (panelGanda) {
      setState(() => _terpilih = sesiId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationDetailScreen(calibrationId: sesiId),
      ),
    );
  }

  Future<void> _segarkan(FilterArsip filter) {
    return filter.modeHasil
        ? ref.read(hasilCariArsipProvider.notifier).muatUlang()
        : ref.read(garisWaktuProvider.notifier).muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(filterArsipProvider);
    final jalur = ref.watch(jalurGarisWaktuProvider);
    // Semua `ref.watch` di sini, bukan di dalam builder panel: builder itu
    // jalan di fase layout, di luar build layar ini.
    final garis = filter.modeHasil ? null : ref.watch(garisWaktuProvider);
    final hasil = filter.modeHasil ? ref.watch(hasilCariArsipProvider) : null;
    final sibuk = (hasil ?? garis)?.isLoading ?? false;
    // Akun yang sedang masuk: isi milik akun lain tidak boleh tampil, sekejap
    // pun, selagi data akun ini dimuat.
    final akunId = ref.watch(authProvider.select((a) => a.value?.id));

    // Tombol kembali sistem naik satu tingkat dulu; baru keluar layar kalau
    // sudah di akar atau sedang melihat hasil cari.
    final naikDulu = !filter.modeHasil && jalur.length > 1;

    return PopScope(
      canPop: !naikDulu,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(jalurGarisWaktuProvider.notifier).naik();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.gwJudul),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.historySegarkan,
              onPressed: () => _segarkan(filter),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(color: AppColors.warnaLatar(context)),
          child: MasterDetailPane(
            ambang: AppUkuran.ambangDuaKolom,
            master: (context, panelGanda) => ReadableWidth(
              child: Column(
                children: [
                  _KepalaFilter(
                    controller: _cari,
                    filter: filter,
                    sedangMengetikSatuHuruf: _ketik.trim().length == 1,
                    onGanti: _berubah,
                    onKirim: _kirim,
                    onHapusCari: _hapusCari,
                    onPilihPt: () => _pilihPt(filter),
                    onHapusPt: () => ref
                        .read(filterArsipProvider.notifier)
                        .aturPelanggan(null, null),
                    onPilihTanggal: () => _pilihTanggal(filter),
                    onHapusTanggal: () => ref
                        .read(filterArsipProvider.notifier)
                        .aturRentang(null, null),
                    onHapusSemua: _hapusSemua,
                  ),
                  _GarisMemuat(aktif: sibuk),
                  if (!filter.modeHasil && jalur.length > 1)
                    _JejakWaktu(
                      jalur: jalur,
                      onTap: ref
                          .read(jalurGarisWaktuProvider.notifier)
                          .kembaliKe,
                    ),
                  Expanded(
                    child: hasil != null
                        ? _isiHasil(l10n, filter, akunId, hasil, panelGanda)
                        : _isiGarisWaktu(
                            l10n,
                            filter,
                            akunId,
                            jalur.last,
                            garis!,
                            panelGanda,
                          ),
                  ),
                ],
              ),
            ),
            detail: _terpilih == null
                ? null
                : CalibrationDetailScreen(calibrationId: _terpilih!),
            kosong: PanePlaceholder(
              icon: Icons.fact_check_outlined,
              judul: l10n.detailPaneEmptyTitle,
              pesan: l10n.detailPaneEmptyBody,
            ),
          ),
        ),
      ),
    );
  }

  // ── Garis waktu ───────────────────────────────────────────────────────────

  Widget _isiGarisWaktu(
    AppLocalizations l10n,
    FilterArsip filter,
    int? akunId,
    LangkahGarisWaktu langkah,
    AsyncValue<StatusGarisWaktu> async,
    bool panelGanda,
  ) {
    // Galat menang atas isi lama: daftar yang tampil harus yang diminta.
    if (async.hasError && !async.isLoading) {
      return _Gagal(
        pesan: _pesanGalat(l10n, async.error),
        bisaCobaLagi: _bisaCobaLagi(async.error),
        onCobaLagi: () => ref.read(garisWaktuProvider.notifier).muatUlang(),
      );
    }

    final status = async.value;

    // Sesudah berpindah tingkat, isi tingkat lama masih sempat terbaca selama
    // tingkat baru dimuat. Yang ditampilkan hanya yang cocok dengan
    // tingkatnya, supaya judul jejak dan isinya tidak saling membantah.
    final berlaku =
        status != null &&
        status.posisi == langkah.posisi &&
        status.pelangganId == filter.pelangganId &&
        status.akunId == akunId;
    if (!berlaku) return const _Skeleton();

    final halaman = status.halaman;
    if (halaman.kelompok.isEmpty && status.item.isEmpty) {
      return _Kosong(pesan: l10n.gwKosong);
    }

    final hari = halaman.tingkat == TingkatGarisWaktu.hari;
    final baris = hari
        ? susunHari(
            halaman.kelompok,
            status.item,
            judulPt: filter.pelangganId == null,
          )
        : const <BarisDaftarArsip>[];
    final adaFooter =
        hari &&
        !async.isLoading &&
        (status.bisaMuatLagi || status.galatMuatLagi != null);
    final jumlahIsi = hari ? baris.length : halaman.kelompok.length;

    return RefreshIndicator(
      onRefresh: () => ref.read(garisWaktuProvider.notifier).muatUlang(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        // Satu baris kepala (total dari server) + isi + tombol muat lagi.
        itemCount: 1 + jumlahIsi + (adaFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Ringkasan(teks: l10n.gwTotalDokumen(halaman.totalDokumen));
          }
          final indeks = i - 1;
          if (indeks >= jumlahIsi) {
            return _TombolMuatLagi(
              memuat: status.memuatLagi,
              gagal: status.galatMuatLagi != null,
              onTap: () =>
                  ref.read(garisWaktuProvider.notifier).muatLebihBanyak(),
            );
          }

          if (!hari) {
            final kelompok = halaman.kelompok[indeks];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KartuKelompokWaktu(
                kelompok: kelompok,
                onTap: kelompok.telusuri == null
                    ? null
                    : () => ref
                          .read(jalurGarisWaktuProvider.notifier)
                          .masuk(kelompok),
              ),
            );
          }

          return switch (baris[indeks]) {
            BarisJudulPt(:final nama) => JudulPtArsip(nama: nama),
            BarisJudulHari(hari: final h) => JudulHariArsip(kelompok: h),
            BarisSertifikat(:final item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KartuSertifikatWaktu(
                item: item,
                disorot: item.sesiId != null && item.sesiId == _terpilih,
                onTap: item.sesiId == null
                    ? null
                    : () => _pilih(item.sesiId!, panelGanda: panelGanda),
              ),
            ),
            BarisInstrumen() => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  // ── Hasil cari ────────────────────────────────────────────────────────────

  Widget _isiHasil(
    AppLocalizations l10n,
    FilterArsip filter,
    int? akunId,
    AsyncValue<HasilCariArsip> async,
    bool panelGanda,
  ) {
    if (async.hasError && !async.isLoading) {
      return _Gagal(
        pesan: _pesanGalat(l10n, async.error),
        bisaCobaLagi: _bisaCobaLagi(async.error),
        onCobaLagi: () => ref.read(hasilCariArsipProvider.notifier).muatUlang(),
      );
    }

    final data = async.value;
    if (data == null || data.akunId != akunId) return const _Skeleton();

    // Saringan baru sedang dimuat: daftar saringan lama TETAP tampil (dengan
    // garis kemajuan di atasnya) — daftar yang mengosong tiap ketikan terasa
    // lambat. Kerangka hanya bila belum ada apa pun untuk ditampilkan.
    final basi = data.filter != filter;
    if (basi && data.baris.isEmpty) return const _Skeleton();

    if (data.baris.isEmpty) {
      return _TanpaHasil(kata: filter.kataKirim);
    }

    final baris = susunHasil(data.baris, judulPt: filter.pelangganId == null);
    final adaLipatan = baris.any(
      (b) => b is BarisInstrumen && b.instrumen.lainnya.isNotEmpty,
    );
    // Tombol "muat lagi" hanya untuk daftar yang sudah final: selagi saringan
    // baru dimuat, daftar lama tampil tetapi halaman berikutnya bukan haknya.
    final adaFooter =
        !basi &&
        !async.isLoading &&
        (data.bisaMuatLagi || data.galatMuatLagi != null);

    return RefreshIndicator(
      onRefresh: () => ref.read(hasilCariArsipProvider.notifier).muatUlang(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 1 + baris.length + (adaFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Ringkasan(
              teks: l10n.gwHasilTotal(data.total),
              catatan: adaLipatan ? l10n.gwGabungSeri : null,
            );
          }
          final indeks = i - 1;
          if (indeks >= baris.length) {
            return _TombolMuatLagi(
              memuat: data.memuatLagi,
              gagal: data.galatMuatLagi != null,
              onTap: () =>
                  ref.read(hasilCariArsipProvider.notifier).muatLebihBanyak(),
            );
          }

          return switch (baris[indeks]) {
            BarisJudulPt(:final nama) => JudulPtArsip(nama: nama),
            BarisInstrumen(:final instrumen) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KartuInstrumenArsip(
                instrumen: instrumen,
                terbuka: _terbuka.contains(instrumen.kunci),
                terpilihId: panelGanda ? _terpilih : null,
                onToggle: () => setState(() {
                  final kunci = instrumen.kunci;
                  if (!_terbuka.remove(kunci)) _terbuka.add(kunci);
                }),
                onPilih: (CalibrationHistoryItem sesi) =>
                    _pilih(sesi.id, panelGanda: panelGanda),
              ),
            ),
            BarisJudulHari() || BarisSertifikat() => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  /// Kalimat untuk tiap jenis galat: sesi habis, server lama, izin, terlalu
  /// sering, tanpa koneksi (arsip memang butuh online), baru yang umum.
  String _pesanGalat(AppLocalizations l10n, Object? galat) {
    if (galat is TokenHilangException ||
        (galat != null && galatSesiBerakhir(galat))) {
      return l10n.historySessionExpired;
    }
    if (galat is ServerBelumMendukungArsipException) return l10n.gwServerLama;
    if (galat is ApiException) {
      if (galat.status == 403) return l10n.gwGalat403;
      if (galat.status == 429) return l10n.gwGalat429;
      // Pesan validasi server sudah berbahasa Indonesia dan menyebut
      // parameter yang salah.
      if (galat.status == 422) return galat.message;
    }
    if (gagalJaringan(galat)) return l10n.gwOffline;
    return l10n.arsipLoadGagal;
  }

  /// Server yang belum mendukung dan sesi yang habis tidak sembuh dengan
  /// mencoba lagi.
  bool _bisaCobaLagi(Object? galat) =>
      galat is! ServerBelumMendukungArsipException &&
      galat is! TokenHilangException &&
      !(galat != null && galatSesiBerakhir(galat));
}

// ── Bagian layar ────────────────────────────────────────────────────────────

/// Kotak cari + chip PT dan tanggal.
class _KepalaFilter extends StatelessWidget {
  const _KepalaFilter({
    required this.controller,
    required this.filter,
    required this.sedangMengetikSatuHuruf,
    required this.onGanti,
    required this.onKirim,
    required this.onHapusCari,
    required this.onPilihPt,
    required this.onHapusPt,
    required this.onPilihTanggal,
    required this.onHapusTanggal,
    required this.onHapusSemua,
  });

  final TextEditingController controller;
  final FilterArsip filter;
  final bool sedangMengetikSatuHuruf;
  final ValueChanged<String> onGanti;
  final ValueChanged<String> onKirim;
  final VoidCallback onHapusCari;
  final VoidCallback onPilihPt;
  final VoidCallback onHapusPt;
  final VoidCallback onPilihTanggal;
  final VoidCallback onHapusTanggal;
  final VoidCallback onHapusSemua;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final format = DateFormat('d MMM yyyy', locale);

    final dari = filter.dari;
    final sampai = filter.sampai;
    final labelTanggal = dari == null && sampai == null
        ? l10n.gwFilterTanggal
        : [
            if (dari != null) format.format(dari),
            if (sampai != null) format.format(sampai),
          ].join(' – ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: l10n.gwCariHint,
            textField: true,
            child: TextField(
              controller: controller,
              onChanged: onGanti,
              onSubmitted: onKirim,
              textInputAction: TextInputAction.search,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_batasHurufCari),
              ],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.gwCariHint,
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.gwCariHapus,
                        onPressed: onHapusCari,
                      ),
              ),
            ),
          ),
          if (sedangMengetikSatuHuruf)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.gwCariMinHuruf,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InputChip(
                avatar: const Icon(
                  Icons.apartment_outlined,
                  size: AppUkuran.ikonSebaris,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppUkuran.labelChipMaks,
                  ),
                  child: Text(
                    filter.pelangganNama ?? l10n.gwSemuaPt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                selected: filter.pelangganId != null,
                showCheckmark: false,
                onPressed: onPilihPt,
                onDeleted: filter.pelangganId == null ? null : onHapusPt,
              ),
              InputChip(
                avatar: const Icon(
                  Icons.date_range_outlined,
                  size: AppUkuran.ikonSebaris,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppUkuran.labelChipMaks,
                  ),
                  child: Text(
                    labelTanggal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                selected: filter.adaRentang,
                showCheckmark: false,
                onPressed: onPilihTanggal,
                onDeleted: filter.adaRentang ? onHapusTanggal : null,
              ),
              if (filter.adaFilter)
                TextButton(
                  onPressed: onHapusSemua,
                  child: Text(l10n.gwHapusFilter),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Garis kemajuan tipis di bawah kotak cari. Slot-nya selalu ada (tinggi
/// tetap) supaya daftar tidak melompat saat pemuatan mulai atau selesai.
class _GarisMemuat extends StatelessWidget {
  const _GarisMemuat({required this.aktif});

  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: AppUkuran.indikatorGaris,
      child: aktif
          ? LinearProgressIndicator(
              minHeight: AppUkuran.indikatorGaris,
              semanticsLabel: l10n.gwMemuat,
            )
          : null,
    );
  }
}

/// Jejak tingkat yang sedang dibuka: `Semua tahun › 2026 › November 2026`.
/// Yang terakhir (tingkat sekarang) tidak bisa diketuk.
class _JejakWaktu extends StatelessWidget {
  const _JejakWaktu({required this.jalur, required this.onTap});

  final List<LangkahGarisWaktu> jalur;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < jalur.length; i++) ...[
            if (i > 0)
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  size: AppUkuran.ikonSebaris,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (i == jalur.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  jalur[i].label ?? l10n.gwAkar,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => onTap(i),
                child: Text(jalur[i].label ?? l10n.gwAkar),
              ),
          ],
        ],
      ),
    );
  }
}

/// Baris pembuka daftar: total dari server, plus catatan opsional. Wilayah
/// "live": pembaca layar mengumumkan jumlah baru saat hasil cari berganti.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.teks, this.catatan});

  final String teks;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final redup = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teks,
              style: theme.textTheme.labelLarge?.copyWith(color: redup),
            ),
            if (catatan != null)
              Text(
                catatan!,
                style: theme.textTheme.labelSmall?.copyWith(color: redup),
              ),
          ],
        ),
      ),
    );
  }
}

class _TombolMuatLagi extends StatelessWidget {
  const _TombolMuatLagi({
    required this.memuat,
    required this.gagal,
    required this.onTap,
  });

  final bool memuat;
  final bool gagal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          if (gagal)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.gwMuatLagiGagal,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          memuat
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: SizedBox(
                    width: AppUkuran.indikatorKecil,
                    height: AppUkuran.indikatorKecil,
                    child: CircularProgressIndicator(
                      strokeWidth: AppUkuran.garisTebal,
                      semanticsLabel: l10n.gwMemuat,
                    ),
                  ),
                )
              : AppButton(
                  label: l10n.gwMuatLagi,
                  icon: Icons.expand_more,
                  variant: AppButtonVariant.secondary,
                  onPressed: onTap,
                ),
        ],
      ),
    );
  }
}

/// Belum ada dokumen sama sekali pada tingkat ini.
class _Kosong extends StatelessWidget {
  const _Kosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        ExcludeSemantics(
          child: Icon(
            Icons.folder_open_outlined,
            size: AppUkuran.ikonKeadaan,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// Pencarian jalan, tapi tidak ada yang cocok. Beda dari [_Kosong]: jalan
/// keluarnya juga beda (ubah kata/saringan, bukan "belum ada data").
class _TanpaHasil extends StatelessWidget {
  const _TanpaHasil({required this.kata});

  /// Kata yang dikirim; null kalau yang menyaring hanya tanggal/PT.
  final String? kata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        ExcludeSemantics(
          child: Icon(
            Icons.search_off,
            size: AppUkuran.ikonKeadaan,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          kata == null ? l10n.gwHasilKosongFilter : l10n.gwHasilKosong(kata!),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (kata != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.gwHasilKosongSaran,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({
    required this.pesan,
    required this.onCobaLagi,
    this.bisaCobaLagi = true,
  });

  final String pesan;
  final VoidCallback onCobaLagi;

  /// Server yang belum mendukung tidak sembuh dengan mencoba lagi.
  final bool bisaCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        ExcludeSemantics(
          child: Icon(
            Icons.cloud_off_outlined,
            size: AppUkuran.ikonKeadaan,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            pesan,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (bisaCobaLagi) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.historyRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: onCobaLagi,
          ),
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => const Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  height: AppUkuran.skeletonJudul,
                  width: AppUkuran.skeletonLebarJudul,
                ),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(
                  height: AppUkuran.skeletonKeterangan,
                  width: AppUkuran.skeletonLebarKeterangan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemilih PT untuk saringan: cari nama, atau "Semua PT".
///
/// Daftar PT datang dari `customerLookupProvider` yang sama dengan form Alat
/// (`GET /customers/lookup`, terbuka untuk semua peran) — id yang dikirim
/// sebagai `customer_id` adalah `customers.id`.
class _PilihPtSheet extends ConsumerStatefulWidget {
  const _PilihPtSheet({required this.terpilihId});

  final int? terpilihId;

  @override
  ConsumerState<_PilihPtSheet> createState() => _PilihPtSheetState();
}

class _PilihPtSheetState extends ConsumerState<_PilihPtSheet> {
  final _kunci = TextEditingController();
  Timer? _jeda;
  String _query = '';

  @override
  void dispose() {
    _jeda?.cancel();
    _kunci.dispose();
    super.dispose();
  }

  void _ketik(String teks) {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = teks.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasil = ref.watch(customerLookupProvider(_query));
    final layar = MediaQuery.sizeOf(context);

    return Padding(
      // Sheet naik mengikuti keyboard supaya kolom cari tidak tertutup.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          // Tinggi mengikuti isi sampai batas layar: di lanskap HP lembar ini
          // tidak boleh lebih tinggi dari layarnya.
          constraints: BoxConstraints(
            maxHeight: layar.height * AppUkuran.nisbiLembar,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.gwPilihPt,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _kunci,
                  onChanged: _ketik,
                  decoration: InputDecoration(
                    hintText: l10n.gwCariPtHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: hasil.when(
                    skipLoadingOnReload: true,
                    loading: () => Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: l10n.gwMemuat,
                        ),
                      ),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.gwPtGagal),
                    ),
                    data: (hasil) => ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(l10n.gwSemuaPt),
                          selected: widget.terpilihId == null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop<_PilihanPt>((id: null, nama: null)),
                        ),
                        if (hasil.daftar.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(l10n.gwPtKosong),
                          ),
                        for (final pt in hasil.daftar)
                          ListTile(
                            title: Text(pt.nama),
                            subtitle: pt.alamat == null || pt.alamat!.isEmpty
                                ? null
                                : Text(
                                    pt.alamat!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            selected: widget.terpilihId == pt.id,
                            trailing: widget.terpilihId == pt.id
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.of(
                              context,
                            ).pop<_PilihanPt>((id: pt.id, nama: pt.nama)),
                          ),
                      ],
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
