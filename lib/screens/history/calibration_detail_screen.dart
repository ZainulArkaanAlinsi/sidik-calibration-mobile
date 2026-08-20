import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/angka.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_detail.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/autoclave_hasil_panel.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../calibration/lembar_kerja_screen.dart';
import '../calibration/instrument_picker_screen.dart';
import '../certificate/sertifikat_screen.dart';

String _fmt(double? v, {int decimals = 4}) =>
    v == null ? '—' : v.toStringAsFixed(decimals);

/// Detail satu sesi kalibrasi — breakdown per titik ukur (rata-rata, error,
/// koreksi, Type A/B, ketidakpastian diperluas, keputusan PASS/FAIL), sama
/// persis kayak yang ditampilin sheet "PERHITUNGAN" di master worksheet.
///
/// **Nggak ada rumus GUM di sini** — semua angka datang mentah-mentah dari
/// `GET /api/calibrations/{id}` (`docs/kontrak-api.md` §4). Kalau sesi belum
/// dihitung backend (`draft` / lagi antre), tabel titik kosong dan layar
/// nampilin pesan "belum dihitung" — bukan spinner selamanya.
class CalibrationDetailScreen extends ConsumerWidget {
  const CalibrationDetailScreen({super.key, required this.calibrationId});

  final int calibrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(calibrationDetailProvider(calibrationId));
    final l10n = AppLocalizations.of(context);

    final data = detail.value;

    final Widget isi;
    if (data != null) {
      isi = _Isi(detail: data, calibrationId: calibrationId);
    } else if (detail.hasError) {
      isi = _Gagal(
        onCobaLagi: () =>
            ref.invalidate(calibrationDetailProvider(calibrationId)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      body: isi,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.detail, required this.calibrationId});

  final int calibrationId;

  final CalibrationDetail detail;

  StatusBadge _statusBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (detail.status == CalibrationStatus.disetujui) {
      // `keputusan` bisa NULL, dan itu keadaan yang sah — bukan "belum ada".
      //
      // Conductivity Meter nggak divonis lulus/gagal: master Excel-nya nggak
      // punya satu pun sel yang mbandingin hasil ke batas keberterimaan, jadi
      // backend ngirim `keputusan: null`. Sebelum ini `_ =>` nangkep null dan
      // nampilinnya sebagai PASS — tiap sesi Conductivity kebaca "lulus" padahal
      // alatnya emang nggak pernah dinilai.
      //
      // Yang ditampilkan strip, bukan badge kosong dan bukan tulisan "null".
      return switch (detail.keputusan) {
        Keputusan.fail => StatusBadge(
          label: l10n.historyStatusFail,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        ),
        Keputusan.pass => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
        null => StatusBadge(
          label: l10n.statusTanpaKeputusan,
          tone: BadgeTone.neutral,
        ),
      };
    }

    return switch (detail.status) {
      CalibrationStatus.draft => StatusBadge(
        label: l10n.historyStatusDraft,
        tone: BadgeTone.neutral,
        icon: Icons.edit_note,
      ),
      CalibrationStatus.menungguApproval => StatusBadge(
        label: l10n.historyStatusMenungguApproval,
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      CalibrationStatus.perluRevisi => StatusBadge(
        label: l10n.historyStatusPerluRevisi,
        tone: BadgeTone.warning,
        icon: Icons.edit_outlined,
      ),
      CalibrationStatus.disetujui => throw StateError('unreachable'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final tanggal = DateFormat(
      'd MMMM yyyy',
      locale,
    ).format(detail.tanggalKalibrasi);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.namaAlat,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${detail.namaTeknisi} · $tanggal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (detail.nomorSesi != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.detailNomorSesi(detail.nomorSesi!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _statusBadge(context),
          ],
        ),

        if (detail.status == CalibrationStatus.perluRevisi &&
            detail.catatanRevisi != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cobaltSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.cobalt),
            ),
            child: Text(l10n.historyCatatanRevisi(detail.catatanRevisi!)),
          ),
        ],

        if (detail.perluVerifikasi) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cobaltSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.cobalt),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.statusPeringatan(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.detailPerluVerifikasi)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TombolVerifikasi(calibrationId: calibrationId),
        ],

        // Admin boleh mbenerin lembar yang MASIH nunggu approval.
        //
        // Dulu status itu ngunci semua orang, jadi admin yang nemu satu angka
        // keliru harus nolak — lembar balik ke teknisi, teknisi betulin, kirim
        // ulang, admin review lagi. Sekarang `PUT /api/calibrations/{id}`
        // nerima admin di status ini (backend yang mutusin; frontend cuma
        // mbukain pintunya).
        //
        // `disetujui` tetap terkunci buat SEMUA orang — sertifikatnya udah
        // terbit dan udah dikirim ke pelanggan.
        // `perlu_revisi` ikut kebuka: itu sesi yang DIKEMBALIKAN admin ke
        // teknisi. Tanpa pintu ini, teknisi cuma dapat notifikasi "ditolak"
        // tanpa satu pun cara mbenerin — sesinya mentok di HP-nya.
        if (detail.status == CalibrationStatus.menungguApproval ||
            detail.status == CalibrationStatus.perluRevisi) ...[
          const SizedBox(height: AppSpacing.md),
          _TombolEditAdmin(detail: detail),
        ],

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.detailKondisiLingkungan.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.standarAcuan != null)
                  _InfoRow(
                    label: l10n.detailStandarAcuan,
                    value: detail.standarAcuan!.nama,
                  ),
                if (detail.kondisiLingkungan?.thermohygro != null)
                  _InfoRow(
                    label: l10n.detailThermohygro,
                    value: detail.kondisiLingkungan!.thermohygro!,
                  ),
                if (detail.lokasi != null)
                  _InfoRow(
                    label: l10n.detailLokasi,
                    value: detail.lokasi == 'onsite'
                        ? l10n.detailLokasiOnsite
                        : l10n.detailLokasiLab,
                  ),

                // Sesi yang ngirim kondisi lengkap (awal/akhir) dapat rincian
                // penuh; sesi lama yang cuma punya satu angka tetap kebaca
                // lewat `suhu_ruang`/`kelembaban` di level atas.
                if (detail.kondisiLingkungan?.suhu != null)
                  _BesaranBlok(
                    judul: l10n.detailSuhuRuang,
                    besaran: detail.kondisiLingkungan!.suhu!,
                  )
                else if (detail.suhuRuang != null)
                  _InfoRow(
                    label: l10n.detailSuhuRuang,
                    value: '${_fmt(detail.suhuRuang, decimals: 1)} °C',
                  ),

                if (detail.kondisiLingkungan?.kelembaban != null)
                  _BesaranBlok(
                    judul: l10n.detailKelembaban,
                    besaran: detail.kondisiLingkungan!.kelembaban!,
                  )
                else if (detail.kelembaban != null)
                  _InfoRow(
                    label: l10n.detailKelembaban,
                    value: '${_fmt(detail.kelembaban, decimals: 1)} %RH',
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.detailTitikUkurTitle.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (detail.autoclave != null)
          // Autoklaf: hasilnya Section A/B/C, bukan tabel titik ukur. `titik`-nya
          // memang kosong, jadi tanpa cabang ini sesi Autoklaf cuma nampilin
          // "belum dihitung" padahal hasilnya lengkap.
          AutoclaveHasilPanel(hasil: detail.autoclave!)
        else if (detail.titik.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.detailBelumDihitung)),
              ],
            ),
          )
        else
          for (final (i, titik) in detail.titik.indexed) ...[
            // Kepala kelompok tiap kali `remark` ganti — dari backend, BUKAN
            // ditebak dari besar angkanya. Rentang Holmium (283–641 nm) &
            // Didynium (474–810 nm) tumpang tindih 167 nm, jadi 513,7 nm
            // kelihatan kayak Holmium padahal dia Didynium.
            //
            // Titiknya nggak dikelompokin ulang, cuma dikasih kepala waktu
            // labelnya ganti: urutan yang dikirim backend itu urutan lembar,
            // dan itu juga urutan barisnya di sertifikat.
            if (titik.remark != null &&
                titik.remark!.isNotEmpty &&
                (i == 0 || detail.titik[i - 1].remark != titik.remark)) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Text(
                titik.remark!,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Ringkasan kelompok: satu tabel padat berisi seluruh titiknya,
            // digambar SEKALI di titik pertama kelompok. Yang dicari orang
            // waktu buka layar ini pertama kali cuma empat angka per titik;
            // rinciannya nunggu diminta.
            // Cukup `i == 0 || remark ganti`: alat tanpa keterangan titik
            // (remark null) ikut lewat sini sebagai SATU kelompok, jadi
            // ringkasannya digambar sekali di atas — bukan diulang di tiap
            // kartu.
            if (i == 0 || detail.titik[i - 1].remark != titik.remark) ...[
              _RingkasanKelompok(
                titik: [
                  for (final t in detail.titik)
                    if (t.remark == titik.remark) t,
                ],
                desimalSesi: detail.desimal,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            _TitikResultCard(
              titik: titik,
              pembacaan: detail.pembacaanMentah
                  .where(
                    (p) =>
                        p.titikKe == titik.titikKe &&
                        p.tahap == TahapPembacaan.sesudahAdjustment,
                  )
                  .toList(),
              sebelum: detail.titikSebelum
                  .where((s) => s.titikKe == titik.titikKe)
                  .firstOrNull,
              pembacaanSebelum: detail.pembacaanMentah
                  .where(
                    (p) =>
                        p.titikKe == titik.titikKe &&
                        p.tahap == TahapPembacaan.sebelumAdjustment,
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

        // Penutup tabel titik — sama kayak kolom MAX STDEV di worksheet asli,
        // yang letaknya juga di ujung kanan bawah tiap tabel.
        if (detail.maxStdev != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _MaxStdev(sesudah: detail.maxStdev!, sebelum: detail.maxStdevSebelum),
        ],

        if (detail.certificateId != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.detailLihatSertifikat,
            icon: Icons.workspace_premium_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                // Pakai id SERTIFIKAT, bukan id sesi: pratinjaunya baca
                // `snapshot` dari `GET /certificates/{id}` — isi yang
                // dibekukan waktu terbit, bukan data sesi yang masih hidup.
                builder: (_) =>
                    SertifikatScreen(certificateId: detail.certificateId!),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Satu baris `label — nilai`.
///
/// Label dikasih **kolom berlebar tetap**, bukan `Expanded`. Dulu `Expanded`,
/// dan di HP itu nggak kelihatan salah karena kartunya sempit — labelnya melar
/// sedikit, nilainya tetap kebaca di sebelahnya.
///
/// Di panel kanan desktop kartunya ~800px, dan `Expanded` mendorong nilainya ke
/// tepi kanan sejauh itu juga. Yang kejadian: "Suhu ruang" di kiri, `21,0 °C`
/// nyaris di ujung layar, dan mata nggak pernah nyampai ke sana — dilaporkan
/// 10 Agt 2026 sebagai "nilai suhu & kelembabannya kosong", padahal angkanya
/// dikirim backend dan memang dirender.
///
/// [_lebarLabel] muat buat label terpanjang di blok ini ("Lokasi kalibrasi")
/// dan masih nyisain ruang nilai di layar HP tersempit, jadi nilainya berbaris
/// rapi satu kolom tanpa kejauhan — di HP maupun di desktop.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  static const double _lebarLabel = 160;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _lebarLabel,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Sisanya buat nilai — biar teks panjang (nama standar acuan) turun
          // baris di kolomnya sendiri, bukan kepotong.
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu besaran lingkungan (suhu / kelembaban) — dibaca dua kali lalu
/// dikoreksi, jadi angkanya ada enam. Tiga yang dibaca langsung (awal, akhir,
/// rata-rata) ditaruh sebaris sebagai kolom biar kebandingin sekali lihat;
/// tiga turunan (koreksi, nilai terkoreksi, U95%) turun jadi baris label-nilai
/// karena itu yang dicetak di sertifikat dan dibaca satu-satu.
class _BesaranBlok extends StatelessWidget {
  const _BesaranBlok({required this.judul, required this.besaran});

  final String judul;
  final BesaranLingkungan besaran;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final satuan = besaran.satuan;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Kolom(
                label: l10n.detailAwal,
                nilai: '${_fmt(besaran.awal, decimals: 1)} $satuan',
              ),
              _Kolom(
                label: l10n.detailAkhir,
                nilai: '${_fmt(besaran.akhir, decimals: 1)} $satuan',
              ),
              _Kolom(
                label: l10n.detailRataRata,
                nilai: '${_fmt(besaran.rataRata, decimals: 2)} $satuan',
                tebal: true,
              ),
            ],
          ),
          if (besaran.koreksi != null)
            _InfoRow(
              label: l10n.detailKoreksi,
              value: '${_fmt(besaran.koreksi, decimals: 2)} $satuan',
            ),
          if (besaran.nilaiTerkoreksi != null)
            _InfoRow(
              label: l10n.detailNilaiTerkoreksi,
              value: '${_fmt(besaran.nilaiTerkoreksi, decimals: 2)} $satuan',
            ),
          if (besaran.u95 != null)
            _InfoRow(
              label: l10n.detailU95Lingkungan,
              value: '± ${_fmt(besaran.u95, decimals: 4)} $satuan',
            ),
        ],
      ),
    );
  }
}

class _Kolom extends StatelessWidget {
  const _Kolom({required this.label, required this.nilai, this.tebal = false});

  final String label;
  final String nilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nilai,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitikResultCard extends StatelessWidget {
  const _TitikResultCard({
    required this.titik,
    this.pembacaan = const [],
    this.sebelum,
    this.pembacaanSebelum = const [],
  });

  final MeasurementResult titik;
  final List<RawMeasurement> pembacaan;

  /// Ringkasan as-found. Null buat alat yang nggak nyatet kondisi sebelum
  /// adjustment (umumnya semua alat non-pH).
  final MeasurementBefore? sebelum;
  final List<RawMeasurement> pembacaanSebelum;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Tiga keadaan, bukan dua. `null` = alatnya emang nggak divonis PASS/FAIL
    // (Conductivity Meter), dan itu HARUS kelihatan beda dari lulus — badge
    // hijau di titik yang nggak punya kriteria kelulusan itu ngaku-ngaku
    // penilaian, di layar yang dipakai mutusin nerbitin sertifikat.
    final keputusan = titik.keputusan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.detailTitikLabel(
                      titik.titikKe,
                      _fmt(titik.titikUkur, decimals: 2),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(
                  label: switch (keputusan) {
                    Keputusan.pass => l10n.historyStatusPass,
                    Keputusan.fail => l10n.historyStatusFail,
                    null => l10n.detailTanpaVonis,
                  },
                  tone: switch (keputusan) {
                    Keputusan.pass => BadgeTone.success,
                    Keputusan.fail => BadgeTone.danger,
                    null => BadgeTone.neutral,
                  },
                  icon: switch (keputusan) {
                    Keputusan.pass => Icons.check_circle_outline,
                    Keputusan.fail => Icons.cancel_outlined,
                    null => Icons.remove_circle_outline,
                  },
                ),
              ],
            ),
            if (titik.standarAcuan != null) ...[
              const SizedBox(height: 2),
              Text(
                titik.standarAcuan!.nama,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (titik.metode != null) ...[
              const SizedBox(height: 2),
              Text(
                '${l10n.detailMetode}: ${titik.metode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (pembacaan.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _TahapPembacaan(
                judul: l10n.detailSesudahAdjustment,
                pembacaan: pembacaan,
                tone: AppColors.statusSukses(context),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Rantai hitungnya, berikut rumus Excel master. Gantiin daftar
            // `Rata-rata / Error / Koreksi / STDEV / Type A / Type B` yang
            // berserak: angkanya sama, tapi urutannya sekarang nunjukin dari
            // mana ke mana — dan itu yang dicari waktu ada hasil yang
            // kelihatan aneh.
            _ProsesHitung(titik: titik),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(label: l10n.detailError, value: _fmt(titik.error)),
            _InfoRow(
              label: l10n.detailJumlahPengulangan,
              value: '${titik.jumlahPengulangan}',
            ),
            if (titik.typeBComponents.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.detailKomponenTypeB,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    for (final komponen in titik.typeBComponents)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• ${komponen.keterangan}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            // Toleransi tetap ditulis terpisah: dia BUKAN bagian rantai hitung,
            // dia pembanding hasilnya. Alat tanpa batas keberterimaan ngirim
            // null dan barisnya nggak muncul, bukan nulis `± 0,0000`.
            if (titik.keputusan != null)
              _InfoRow(
                label: l10n.detailToleransi,
                value: '± ${_fmt(titik.toleransi)}',
              ),

            // As-found ditaruh paling bawah dan sengaja lebih redup: yang
            // disertifikasi itu angka di atas. Kalau dua-duanya sama menonjol,
            // gampang salah kutip waktu ditanya pelanggan.
            if (sebelum != null || pembacaanSebelum.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg),
              _TahapPembacaan(
                judul: l10n.detailSebelumAdjustment,
                pembacaan: pembacaanSebelum,
                tone: theme.colorScheme.onSurfaceVariant,
                catatan: l10n.detailAsFoundCatatan,
              ),
              if (sebelum != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(
                  label: l10n.detailRataRata,
                  value: _fmt(sebelum!.rataRata, decimals: 3),
                ),
                _InfoRow(
                  label: l10n.detailKoreksi,
                  value: _fmt(sebelum!.koreksi),
                ),
                _InfoRow(
                  label: l10n.detailStandarDeviasi,
                  value:
                      '${_fmt(sebelum!.standarDeviasi)} (n=${sebelum!.jumlahPengulangan})',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Ringkasan satu kelompok titik — empat angka per baris, sekali lihat.
///
/// Layar ini dulu cuma tumpukan kartu setinggi ±18 baris per titik. Buat alat
/// 24 titik (Spectrophotometer) itu berarti nyaris dua puluh layar scroll
/// sebelum ketemu angka yang dicari, dan nggak ada satu tempat pun yang
/// nunjukin hasil sesi secara utuh.
///
/// Angkanya SAMA PERSIS sama yang kecetak di sertifikat — formatter dan
/// desimalnya satu jalur ([formatSertifikat] + `desimal` per titik), karena
/// layar ini dipakai admin buat mutusin nerbitin.
class _RingkasanKelompok extends StatelessWidget {
  const _RingkasanKelompok({required this.titik, required this.desimalSesi});

  final List<MeasurementResult> titik;
  final int desimalSesi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final satuan = titik.first.satuan;
    final gayaKepala = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final gayaAngka = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    String kepala(String teks) => satuan == null ? teks : '$teks ($satuan)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              children: [
                Text(kepala(l10n.detailKolStandard), style: gayaKepala),
                Text(
                  kepala(l10n.detailRataRata),
                  style: gayaKepala,
                  textAlign: TextAlign.right,
                ),
                Text(
                  kepala(l10n.detailKoreksi),
                  style: gayaKepala,
                  textAlign: TextAlign.right,
                ),
                Text(
                  kepala(l10n.detailKolU95),
                  style: gayaKepala,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            for (final t in titik)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatNilaiStandar(
                        t.titikUkur,
                        t.desimalEfektif(desimalSesi),
                      ),
                      style: gayaAngka,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatSertifikat(
                        t.rataRata,
                        t.desimalEfektif(desimalSesi),
                        tandaNol: t.tandaNol,
                      ),
                      style: gayaAngka,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatSertifikat(
                        t.koreksi,
                        t.desimalEfektif(desimalSesi),
                        tandaNol: t.tandaNol,
                      ),
                      style: gayaAngka,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatSertifikat(
                        t.ketidakpastianDiperluas,
                        t.desimalEfektif(desimalSesi),
                      ),
                      style: gayaAngka,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Rantai hitung satu titik, dari pembacaan mentah sampai U95 — **berikut rumus
/// Excel-nya**.
///
/// Ada karena layar ini yang dipakai admin sebelum nerbitin sertifikat, dan
/// sebelumnya dia cuma nyodorin hasil akhir. Waktu ada angka yang kelihatan
/// aneh, satu-satunya cara ngecek adalah buka master Excel di laptop lain.
///
/// **Nggak ada satu pun hitungan di sini.** Tiap angka di kolom kanan datang
/// apa adanya dari `GET /api/calibrations/{id}`; yang ditambah layar cuma NAMA
/// rumusnya, disalin dari master lab. Kalau suatu saat angkanya nggak cocok
/// sama rumusnya, yang salah datanya — dan itu justru yang mau kelihatan.
class _ProsesHitung extends StatelessWidget {
  const _ProsesHitung({required this.titik});

  final MeasurementResult titik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final n = titik.jumlahPengulangan;

    final langkah = <({String judul, String rumus, String nilai})>[
      (
        judul: l10n.detailRataRata,
        rumus: '=AVERAGE(X1:X$n)',
        nilai: _fmt(titik.rataRata, decimals: 4),
      ),
      (
        judul: l10n.detailStandarDeviasi,
        rumus: '=STDEV.S(X1:X$n)',
        nilai: _fmt(titik.standarDeviasi, decimals: 6),
      ),
      (
        judul: l10n.detailKoreksi,
        rumus:
            '= ${_fmt(titik.titikUkur, decimals: 2)} − ${_fmt(titik.rataRata, decimals: 4)}',
        nilai: _fmt(titik.koreksi, decimals: 4),
      ),
      (
        judul: l10n.detailTypeA,
        rumus: l10n.detailRumusTypeA,
        nilai: _fmt(titik.typeA, decimals: 6),
      ),
      (
        judul: l10n.detailTypeB,
        rumus: l10n.detailRumusTypeB,
        nilai: _fmt(titik.typeB, decimals: 6),
      ),
      (
        judul: l10n.detailKetidakpastianGabungan,
        rumus: '=SQRT(A² + B²)',
        nilai: _fmt(titik.ketidakpastianGabungan, decimals: 6),
      ),
      if (titik.derajatKebebasanEfektif != null)
        (
          judul: l10n.detailVeff,
          rumus: '= uc⁴ / Σ(uᵢ⁴/vᵢ)',
          nilai: _fmt(titik.derajatKebebasanEfektif, decimals: 4),
        ),
      (
        judul: l10n.detailFaktorCakupan,
        rumus: '=TINV(0,05; veff)',
        nilai: _fmt(titik.faktorCakupanK, decimals: 5),
      ),
      (
        judul: l10n.detailU95,
        rumus: '= uc × k',
        nilai: _fmt(titik.ketidakpastianDiperluas, decimals: 5),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.detailProsesHitung.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final l in langkah)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(l.judul, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    l.rumus,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    l.nilai,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.detailProsesCatatan,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Kotak **MAX STDEV** — sebaran terburuk di antara semua titik.
///
/// Gunanya buat teknisi: satu angka buat nilai "seberapa stabil sesi ini".
/// Kalau titik lain rapi tapi satu titik sebarannya lebar, rata-rata per titik
/// nggak nunjukin itu — yang nunjukin ya angka maksimum ini.
///
/// Angka as-found ditaruh di bawah & lebih redup, sama alasannya kayak di
/// kartu titik: yang disertifikasi cuma yang as-left.
class _MaxStdev extends StatelessWidget {
  const _MaxStdev({required this.sesudah, this.sebelum});

  final double sesudah;
  final double? sebelum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.detailMaxStdev.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _fmt(sesudah),
                style: AppTypography.measurement.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (sebelum != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.detailMaxStdevSebelum,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                Text(
                  _fmt(sebelum!),
                  style: AppTypography.measurement.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Daftar pembacaan satu tahap. Suhu larutan ikut ditempel di angkanya kalau
/// ada — di pH, satu pembacaan itu pasangan pH/°C, dan angka pH tanpa suhunya
/// nggak cukup buat nelusuri ulang nilai acuannya.
class _TahapPembacaan extends StatelessWidget {
  const _TahapPembacaan({
    required this.judul,
    required this.pembacaan,
    required this.tone,
    this.catatan,
  });

  final String judul;
  final List<RawMeasurement> pembacaan;
  final Color tone;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          judul.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: tone,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (catatan != null) ...[
          const SizedBox(height: 2),
          Text(
            catatan!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (pembacaan.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in pembacaan)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: tone.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    p.suhu == null
                        ? _fmt(p.pembacaan, decimals: 3)
                        : '${_fmt(p.pembacaan, decimals: 2)} · ${_fmt(p.suhu, decimals: 1)}°',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
          l10n.detailLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.historyRetry,
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SkeletonBox(height: 24, width: 200),
        const SizedBox(height: AppSpacing.xs),
        const SkeletonBox(height: 14, width: 140),
        const SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 90, width: double.infinity),
        const SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 160, width: double.infinity),
      ],
    );
  }
}

/// Tombol "Saya sudah cek angkanya" — satu-satunya cara membuka sesi yang
/// pembacaannya datang dari kamera.
///
/// **Tanpa ini sesinya jalan buntu.** Pembacaan hasil foto disimpen
/// `is_verified: false`, dan pemeriksaan admin nolak nerbitin sertifikat selama
/// masih ada yang belum dikonfirmasi (`ocr_belum_diverifikasi`). Peringatannya
/// udah lama tampil di layar ini, tapi endpoint-nya nggak pernah dipanggil dari
/// mana pun — jadi admin keblokir dan teknisi nggak punya cara mbuka. Ketemu
/// 7 Agt 2026, waktu sesi Refractometer pertama dari foto mentok di antrean.
///
/// Kalimatnya sengaja **pernyataan teknisi**, bukan "Verifikasi": yang
/// ditandatangani di sini itu klaim bahwa dia udah mbandingin angka di layar
/// sama angka di alat. Itu inti aturannya — kamera mempercepat pengetikan,
/// bukan menggantikan orang yang bertanggung jawab.
class _TombolVerifikasi extends ConsumerStatefulWidget {
  const _TombolVerifikasi({required this.calibrationId});

  final int calibrationId;

  @override
  ConsumerState<_TombolVerifikasi> createState() => _TombolVerifikasiState();
}

class _TombolVerifikasiState extends ConsumerState<_TombolVerifikasi> {
  bool _sibuk = false;

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw Exception('Sesi login habis.');

      await ref
          .read(historyServiceProvider)
          .verifikasiPembacaan(token, widget.calibrationId);

      if (!mounted) return;
      // Detailnya ditarik ulang, bukan ditebak: yang nentuin peringatan itu
      // hilang atau nggak ya server, bukan layar ini.
      ref.invalidate(calibrationDetailProvider(widget.calibrationId));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.detailVerifikasiSukses)),
      );
    } catch (e) {
      if (!mounted) return;
      // Errornya ditampilin apa adanya — kalau ditelan, teknisi cuma lihat
      // tombol yang nggak ngapa-ngapain.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.detailVerifikasiGagal('$e'))),
      );
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: AppLocalizations.of(context).detailVerifikasiTombol,
        icon: Icons.check_circle_outline,
        isLoading: _sibuk,
        onPressed: _sibuk ? null : _kirim,
      ),
    );
  }
}

/// Tombol Edit buat admin di sesi `menunggu_approval`.
///
/// Dipisah jadi widget sendiri karena butuh `ref` (cek peran), sementara
/// [_Isi] di atas `StatelessWidget` — dan mengubahnya jadi Consumer cuma buat
/// satu tombol bikin seluruh layar ikut rebuild tiap auth berubah.
///
/// Teknisi nggak dikasih tombol ini: backend nolak dengan 422 yang jelas
/// ("…nggak bisa diubah teknisi. Minta admin yang ngedit…"), dan mancing orang
/// ke tombol yang pasti ditolak itu bikin dia ngira app-nya rusak.
class _TombolEditAdmin extends ConsumerWidget {
  const _TombolEditAdmin({required this.detail});

  final CalibrationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;
    final perluRevisi = detail.status == CalibrationStatus.perluRevisi;

    // Sesi yang DIKEMBALIKAN admin memang buat dikerjain ulang teknisi, jadi
    // di status itu tombolnya buat SEMUA orang. Di `menunggu_approval` tetap
    // admin doang — backend nolak teknisi dengan 422, dan mancing orang ke
    // tombol yang pasti ditolak bikin dia ngira app-nya rusak.
    if (!isAdmin && !perluRevisi) return const SizedBox.shrink();

    return AppButton(
      label: perluRevisi ? l10n.detailPerbaikiRevisi : l10n.detailEditAdmin,
      icon: Icons.edit_outlined,
      variant: AppButtonVariant.secondary,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LembarKerjaScreen(
            sesiId: detail.id,
            // Profil WAJIB ikut — tanpa ini layar jatuh ke formulir pH dan
            // admin ngedit lembar Conductivity pakai 3 titik 4/7/10,01.
            profil: profilLembarKerjaUntuk(detail.namaAlat) ?? 'ph_meter',
          ),
        ),
      ),
    );
  }
}
