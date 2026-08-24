import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../calibration/instrument_picker_screen.dart'
    show profilLembarKerjaUntuk;
import '../calibration/lembar_kerja_screen.dart';

/// Layar Draf — lembar kerja yang disimpen setengah jadi, **dikelompokkan per
/// jenis alat**.
///
/// Kenapa layar sendiri, bukan penyaring di Riwayat: draf itu kerjaan yang
/// BELUM selesai, dan yang dicari teknisi di situ bukan "apa yang pernah saya
/// kerjakan" tapi "lembar mana yang saya tinggal, dan sudah berapa lama".
/// Sebelum ini satu-satunya jalan nemuinnya nyisir daftar Riwayat yang isinya
/// campur sesi selesai — dan draf paling lama justru paling jauh ke bawah.
///
/// Disusun kayak rak perpustakaan: satu rak per jenis alat, tiap punggungnya
/// nyebut nama alat/pelanggan dan kapan ditaruh. Angka jam mentah sengaja
/// nggak dipakai — lihat [waktuLalu].
///
/// **Nggak ada tombol hapus draf.** `DELETE /api/calibrations/{id}` belum ada
/// di backend; tombol yang manggil endpoint nggak ada cuma bikin teknisi ngira
/// drafnya kebuang padahal masih nangkring di server.
class DrafScreen extends ConsumerStatefulWidget {
  const DrafScreen({super.key});

  @override
  ConsumerState<DrafScreen> createState() => _DrafScreenState();
}

class _DrafScreenState extends ConsumerState<DrafScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _cari = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounce 400ms, angkanya disamain sama kolom cari di layar Alat.
  ///
  /// Di sana yang ditahan permintaan ke server; di sini penyaringannya lokal
  /// (satu `ambilDraf()` udah narik semua halaman), yang ditahan **pengelompokan
  /// ulang**. Daftar draf dibangun ulang per ketukan: dikelompokkan per jenis,
  /// tiap kelompok diurutkan, lalu kelompoknya diurutkan lagi. Tanpa jeda ini
  /// kerjaan itu jalan enam kali buat satu kata yang diketik cepat, dan di HP
  /// kelas menengah itu kebaca sebagai kolom cari yang ketinggalan ngetik.
  void _onCariChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _cari = query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draf = ref.watch(drafProvider);

    // Urutan cek sama kayak Dashboard & Riwayat: data dulu, baru error, baru
    // loading — biar retry Riverpod yang jalan di belakang layar nggak
    // nyangkut di skeleton selamanya.
    final data = draf.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? const _Kosong() : _Isi(semua: data, cari: _cari);
    } else if (draf.hasError) {
      isi = _Gagal(
        pesan: draf.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.drafGagal,
        onCobaLagi: () => ref.read(drafProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.drafTitle),
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: Container(
        decoration: BoxDecoration(color: AppColors.warnaLatar(context)),
        child: ReadableWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onCariChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.drafCariHint,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(drafProvider.notifier).muatUlang(),
                  child: isi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- pengelompokan

/// Satu rak: jenis alat + draf-draf di dalamnya.
class _Kelompok {
  const _Kelompok(this.label, this.isi);

  final String label;
  final List<CalibrationHistoryItem> isi;
}

/// Kunci pengelompokan: **jenis** alat, bukan alat pelanggannya.
///
/// `profil` dari server duluan (`ph_meter`, `tits`, `oven`) karena itu satu
/// nilai per jenis, apa pun nama alat yang diketik pelanggan. Jatuh ke
/// [CalibrationHistoryItem.namaAlat] cuma buat respons backend lama yang belum
/// ngirim `profil` — di situ dua alat sejenis bisa kepecah jadi dua rak, dan
/// itu jauh lebih baik daripada semuanya numpuk jadi satu rak "—".
String _kunciJenis(CalibrationHistoryItem d) => d.profil ?? d.namaAlat;

/// Judul rak yang kebaca orang.
///
/// `nama_alat_kemampuan` (nama jenis di lampiran akreditasi) yang dipakai,
/// bukan kode profilnya: teknisi kenalnya "pH Meter", bukan `ph_meter`.
/// Nerjemahin kode ke nama di sisi APK berarti nyimpen tabel yang pasti
/// ketinggalan tiap alat baru masuk lewat `POST /api/categories/{kode}/kemampuan`
/// — persis alasan `profil` dipindah ke server.
String _labelJenis(List<CalibrationHistoryItem> grup) {
  for (final d in grup) {
    final nama = d.namaAlatKemampuan;
    if (nama != null && nama.trim().isNotEmpty) return nama;
  }
  return grup.first.namaAlat;
}

/// Urutan: yang paling BARU disimpen di atas, di dalam rak maupun antar rak.
///
/// Acuannya [CalibrationHistoryItem.waktuTerakhir] — buat draf itu
/// `updated_at`, satu-satunya jejak yang draf pasti punya.
///
/// **`tanggalKalibrasi` sengaja nggak disentuh sama sekali**, nggak buat
/// nyaring dan nggak buat ngurutin. Kolomnya nullable di backend justru supaya
/// draf boleh disimpen sebelum teknisi tau alatnya bakal dikerjain kapan, dan
/// draf tanpa tanggal pernah ILANG SENYAP dari daftar gara-gara jalur baca yang
/// mengandaikan tanggalnya ada. Layar ini nggak boleh jadi pintu balik buat bug
/// itu — makanya draf tanpa `waktuTerakhir` pun tetap dirender, cuma didorong
/// ke bawah.
int _bandingWaktu(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

List<_Kelompok> _kelompokkanDraf(List<CalibrationHistoryItem> semua) {
  final peta = <String, List<CalibrationHistoryItem>>{};
  for (final d in semua) {
    peta.putIfAbsent(_kunciJenis(d), () => []).add(d);
  }

  final hasil = [
    for (final grup in peta.values)
      _Kelompok(
        _labelJenis(grup),
        grup.toList()
          ..sort((a, b) {
            final w = _bandingWaktu(a.waktuTerakhir, b.waktuTerakhir);
            // Dua draf yang `updated_at`-nya identik (impor massal, atau
            // backend lama yang nggak ngirimnya sama sekali) tetap butuh urutan
            // yang TETAP — daftar yang loncat-loncat tiap dibuka bikin orang
            // ngira drafnya nambah/ilang. Id turun = yang dibikin belakangan
            // di atas.
            return w != 0 ? w : b.id.compareTo(a.id);
          }),
      ),
  ]..sort((a, b) {
      final w = _bandingWaktu(a.isi.first.waktuTerakhir, b.isi.first.waktuTerakhir);
      return w != 0 ? w : a.label.compareTo(b.label);
    });

  return hasil;
}

/// Kena kata yang lagi diketik?
///
/// Yang dicari orang di layar ini nama alat atau nama PT-nya. Nama teknisi ikut
/// karena admin yang mbuka layar ini lihat draf semua teknisi (backend nggak
/// nyaring `mine` buat admin), dan pertanyaan pertamanya "punya siapa yang
/// nyangkut". Tanggal SENGAJA nggak ikut dicari — draf boleh nggak punya
/// tanggal sama sekali.
bool _cocokDraf(CalibrationHistoryItem d, String kunci) {
  if (kunci.isEmpty) return true;
  bool ada(String? teks) => teks != null && teks.toLowerCase().contains(kunci);
  return ada(d.namaAlat) ||
      ada(d.namaPelanggan) ||
      ada(d.namaTeknisi) ||
      ada(d.namaAlatKemampuan);
}

// -------------------------------------------------------------------- daftar

class _Isi extends StatelessWidget {
  const _Isi({required this.semua, required this.cari});

  final List<CalibrationHistoryItem> semua;
  final String cari;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kunci = cari.trim().toLowerCase();

    final tersaring = semua.where((d) => _cocokDraf(d, kunci)).toList();

    if (tersaring.isEmpty) {
      // Beda pesan dari [_Kosong]: "belum pernah nyimpen draf" dan "draf ada
      // tapi nggak ada yang cocok" itu dua keadaan yang jalan keluarnya beda.
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.drafCariKosong,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    final kelompok = _kelompokkanDraf(tersaring);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: kelompok.length,
      itemBuilder: (context, i) => _Rak(kelompok: kelompok[i]),
    );
  }
}

class _Rak extends StatelessWidget {
  const _Rak({required this.kelompok});

  final _Kelompok kelompok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  kelompok.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.drafGrupJumlah(kelompok.isi.length),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final draf in kelompok.isi)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _KartuDraf(item: draf),
          ),
      ],
    );
  }
}

class _KartuDraf extends StatelessWidget {
  const _KartuDraf({required this.item});

  final CalibrationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final waktu = item.waktuTerakhir;

    return GlassSurface.rata(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LembarKerjaScreen(
                sesiId: item.id,
                // Profil WAJIB ikut — sama alasannya kayak di layar detail sesi
                // & Alur Kerja. Tanpa ini lembar Chlorine dibuka pakai formulir
                // pH (3 titik 4/7/10,01), dan angka yang udah diketik teknisi
                // mendarat di baris yang salah waktu drafnya dilanjutin.
                profil: item.profil ??
                    profilLembarKerjaUntuk(item.namaAlat) ??
                    'ph_meter',
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaAlat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.namaPelanggan != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.namaPelanggan!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        // Draf yang backend-nya belum ngirim satu pun timestamp
                        // tetap dirender — barisnya cuma diam soal waktu, bukan
                        // ilang dari rak. Em dash-nya sama kayak yang dipakai
                        // tanggal kalibrasi kosong di layar lain.
                        waktu == null
                            ? l10n.tanggalKosong
                            : l10n.drafDisimpan(
                                waktuLalu(
                                  waktu,
                                  locale,
                                  baruSaja: l10n.waktuBaruSaja,
                                  menitLalu: l10n.waktuMenitLalu,
                                  jamLalu: l10n.waktuJamLalu,
                                  kemarin: l10n.waktuKemarin,
                                  hariLalu: l10n.waktuHariLalu,
                                ),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- keadaan lain

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // `ListView`, bukan `Center`: `RefreshIndicator` butuh anak yang bisa
    // di-scroll, dan layar kosong justru yang paling sering ditarik orang buat
    // mastiin datanya emang nggak ada.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.edit_note, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.drafKosongJudul,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.drafKosongBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).equipRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 160),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
