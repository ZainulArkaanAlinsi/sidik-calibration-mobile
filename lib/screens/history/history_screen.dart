import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/history_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../widgets/app_button.dart';
import '../../widgets/master_detail_pane.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tampil_masuk.dart';
import '../../widgets/notification_bell.dart';
import 'calibration_detail_screen.dart';

/// Riwayat kalibrasi — sama pola 4-state-nya kayak Dashboard
/// (`loading` skeleton · `empty` · `normal` daftar sesi · `error` + coba
/// lagi), biar teknisi/admin nggak bingung ketemu dua behavior beda buat
/// masalah yang sama (jaringan lemot, sesi habis, dst).
///
/// Admin dapat tambahan: tombol setujui/tolak langsung di kartu sesi yang
/// `menunggu_approval` — nggak ada layar approval terpisah, biar admin
/// nggak perlu loncat-loncat antara "lihat riwayat" dan "approve sesuatu".
/// Di jendela lebar layar ini jadi **panel ganda**: daftar sesi tetap
/// kelihatan di kiri, detailnya kebuka di kanan. Buat admin yang memeriksa
/// sesi satu per satu, itu ngilangin bolak-balik push–back tiap ganti sesi.
/// Di HP perilakunya nggak berubah sama sekali: tap kartu → push layar detail.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with WidgetsBindingObserver {
  /// Sesi yang lagi kebuka di panel kanan. Null = belum ada yang dipilih.
  /// Cuma dipakai waktu panel ganda aktif; di mode satu panel detailnya
  /// di-push, bukan disimpen di sini.
  int? _terpilih;

  /// Kolom cari di atas daftar. Disaring di HP, bukan dikirim ke server:
  /// `ambilRiwayat` udah narik SEMUA halaman, jadi yang dicari pasti ada di
  /// [historyProvider]. Tanpa debounce kayak layar Draf — di sini nggak ada
  /// pengelompokan ulang, cuma `contains` per baris, dan daftarnya dibangun
  /// malas (`ListView.separated`).
  final _cariController = TextEditingController();
  String _cari = '';

  /// Default MATI: baris yang disembunyikan akun ini nggak ikut tampil. Nyala
  /// = semua tampil, yang tersembunyi diberi penanda + aksi "Tampilkan lagi".
  bool _tampilkanTersembunyi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cariController.dispose();
    super.dispose();
  }

  void _gantiCari(String kata) => setState(() => _cari = kata);

  void _hapusCari() {
    _cariController.clear();
    setState(() => _cari = '');
  }

  /// Sembunyikan satu baris — optimistic di [HistoryController.sembunyikan],
  /// SnackBar "Urungkan" baru muncul sesudah server mengiyakan. Muncul
  /// duluan berarti ngaku berhasil padahal belum tentu.
  Future<void> _sembunyikan(CalibrationHistoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      await ref.read(historyProvider.notifier).sembunyikan(item.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_pesanGagal(l10n, e, sembunyikan: true))),
      );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.riwayatDisembunyikanSnack),
          action: SnackBarAction(
            label: l10n.riwayatUrungkan,
            onPressed: () {
              if (mounted) unawaited(_tampilkanLagi(item));
            },
          ),
        ),
      );
  }

  Future<void> _tampilkanLagi(CalibrationHistoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      await ref.read(historyProvider.notifier).tampilkanLagi(item.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_pesanGagal(l10n, e, sembunyikan: false))),
      );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.riwayatDitampilkanLagiSnack)));
  }

  /// 403 = akun yang memang tidak boleh (super admin menurut kontrak 8 Okt
  /// 2026) — dikasih kalimat sendiri, bukan "gagal" yang ngajak nyoba lagi.
  String _pesanGagal(
    AppLocalizations l10n,
    Object galat, {
    required bool sembunyikan,
  }) {
    if (galat is ApiException && galat.status == 403) {
      return l10n.riwayatSembunyikanDitolak;
    }
    if (galat is TokenHilangException) return l10n.historySessionExpired;
    final pesan = galat.toString();
    return sembunyikan
        ? l10n.riwayatSembunyikanGagal(pesan)
        : l10n.riwayatTampilkanLagiGagal(pesan);
  }

  /// Balik ke jendela/app ini → tarik ulang daftarnya.
  ///
  /// Daftar riwayat itu satu-satunya layar yang nampilin keputusan orang lain
  /// (admin nyetujui, teknisi ngirim ulang), jadi dia paling gampang basi. Yang
  /// mestinya ngabarin itu broadcast realtime, TAPI `realtimeSyncProvider`
  /// jatuh ke [MockRealtimeService] begitu kunci Reverb kosong — dan itu
  /// keadaan normal di dev. Akibatnya: sesi ditolak lewat HP, jendela macOS
  /// tetap nulis "Menunggu approval" sampai app-nya dimatiin. Dua perangkat
  /// nunjuk database yang sama tapi cerita beda, dan yang kelihatan salah
  /// justru layarnya, bukan sinkronnya.
  ///
  /// Nggak nunggu selesai & nggak nampilin loading: ini penyegaran latar, dan
  /// daftar lama tetap kepakai sampai yang baru dateng.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    unawaited(ref.read(historyProvider.notifier).muatUlang());
  }

  /// Dipanggil dari kartu. [panelGanda] dateng dari tata letak yang lagi
  /// aktif — bukan dari `Platform`, karena jendela desktop yang disempitin
  /// pantas dapet perilaku HP.
  void _pilih(CalibrationHistoryItem item, {required bool panelGanda}) {
    if (panelGanda) {
      setState(() => _terpilih = item.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationDetailScreen(calibrationId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riwayat = ref.watch(historyProvider);
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    // Urutan cek sama kayak dashboard: data dulu, baru error, baru loading —
    // biar retry Riverpod yang jalan di belakang layar nggak nyangkut di
    // skeleton selamanya (lihat komentar di dashboard_screen.dart).
    final data = riwayat.value;

    // Dibikin fungsi, bukan variabel, karena daftarnya perlu tau lagi mode
    // apa — dan itu baru ketauan di dalam [MasterDetailPane].
    Widget isi(bool panelGanda) {
      if (data != null) {
        if (data.isEmpty) return const _Kosong();

        final tampil = [
          for (final s in data)
            if ((_tampilkanTersembunyi || !s.tersembunyi) &&
                s.cocokDengan(_cari))
              s,
        ];

        // Daftarnya ADA tapi nggak ada yang lolos saringan — beda keadaan
        // dari [_Kosong] ("belum pernah ada riwayat"), dan jalan keluarnya
        // juga beda. Layar kosong di sini bakal kebaca "datanya ilang".
        if (tampil.isEmpty) {
          return _TidakCocok(
            kata: _cari.trim(),
            cocokTersembunyi: _tampilkanTersembunyi
                ? 0
                : data
                      .where((s) => s.tersembunyi && s.cocokDengan(_cari))
                      .length,
            onTampilkanTersembunyi: () =>
                setState(() => _tampilkanTersembunyi = true),
          );
        }

        return _Isi(
          items: tampil,
          isAdmin: isAdmin,
          // Sorotan cuma masuk akal kalau detailnya emang lagi kebuka di
          // sebelahnya. Di satu panel, kartu "terpilih" nggak ada artinya.
          terpilih: panelGanda ? _terpilih : null,
          onPilih: (item) => _pilih(item, panelGanda: panelGanda),
          onSembunyikan: _sembunyikan,
          onTampilkanLagi: _tampilkanLagi,
        );
      }
      if (riwayat.hasError) {
        return _Gagal(
          pesan: riwayat.error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.historyLoadFailed,
          onCobaLagi: () => ref.read(historyProvider.notifier).muatUlang(),
        );
      }
      return const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHistory),
        // Pintasan Arsip di sini sengaja dibuang: spesifikasi poin 7 minta
        // bagian "Folder" dihapus dari Riwayat, karena penelusuran folder
        // pindah SELURUHNYA ke Folder Manager di navbar bawah. Dua pintu ke
        // hal yang sama cuma bikin orang ragu mana yang bener.
        // `RefreshIndicator` di bawah cuma kepanggil sama gestur TARIK, dan
        // di desktop gestur itu nggak ada — jadi tanpa tombol ini jendela
        // macOS nggak punya cara nyegerin daftar sama sekali selain dimatiin.
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.historySegarkan,
            onPressed: () => ref.read(historyProvider.notifier).muatUlang(),
          ),
          const NotificationBell(),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: AppColors.warnaLatar(context)),
        child: MasterDetailPane(
          // Kolom cari DI LUAR daftar yang digulir — ikut pola layar Draf,
          // jadi tetap kelihatan waktu daftarnya udah digulir jauh. Disembunyikan
          // cuma kalau riwayatnya memang nol: nyari di daftar kosong nggak ada
          // gunanya, dan [_Kosong] udah menjelaskan keadaannya.
          master: (context, panelGanda) => ReadableWidth(
            child: Column(
              children: [
                if (data == null || data.isNotEmpty)
                  _KepalaCari(
                    controller: _cariController,
                    kata: _cari,
                    onGanti: _gantiCari,
                    onHapus: _hapusCari,
                    jumlahTersembunyi:
                        data?.where((s) => s.tersembunyi).length ?? 0,
                    tampilkanTersembunyi: _tampilkanTersembunyi,
                    onGantiTampilkanTersembunyi: (nyala) =>
                        setState(() => _tampilkanTersembunyi = nyala),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(historyProvider.notifier).muatUlang(),
                    child: isi(panelGanda),
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
    );
  }
}

class _Isi extends StatefulWidget {
  const _Isi({
    required this.items,
    required this.isAdmin,
    required this.terpilih,
    required this.onPilih,
    required this.onSembunyikan,
    required this.onTampilkanLagi,
  });

  final List<CalibrationHistoryItem> items;
  final bool isAdmin;

  /// Id sesi yang lagi kebuka di panel kanan. Null = nggak ada yang disorot.
  final int? terpilih;

  final void Function(CalibrationHistoryItem item) onPilih;

  final void Function(CalibrationHistoryItem item) onSembunyikan;
  final void Function(CalibrationHistoryItem item) onTampilkanLagi;

  @override
  State<_Isi> createState() => _IsiState();
}

class _IsiState extends State<_Isi> {
  /// Daftar riwayat me-recycle kartunya. Tanpa catatan ini, tiap kartu yang
  /// digulir balik animasi masuknya jalan lagi — dan daftar yang berkedip tiap
  /// discroll justru terbaca sebagai scroll yang berat, bukan hidup.
  final _jejak = JejakMasuk();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: widget.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return TampilMasuk(
          indeks: index,
          jejak: _jejak,
          child: _HistoryCard(
            item: item,
            isAdmin: widget.isAdmin,
            disorot: item.id == widget.terpilih,
            onTap: () => widget.onPilih(item),
            onSembunyikan: () => widget.onSembunyikan(item),
            onTampilkanLagi: () => widget.onTampilkanLagi(item),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.isAdmin,
    required this.disorot,
    required this.onTap,
    required this.onSembunyikan,
    required this.onTampilkanLagi,
  });

  final CalibrationHistoryItem item;
  final bool isAdmin;

  /// Sesi ini yang lagi kebuka di panel kanan.
  final bool disorot;

  final VoidCallback onTap;
  final VoidCallback onSembunyikan;
  final VoidCallback onTampilkanLagi;

  /// Lencana status SERTIFIKAT — beda sumbu dari [_badge] (status SESI /
  /// PASS-FAIL). Sesi bisa "PASS" sementara sertifikatnya sudah dibatalkan,
  /// dan justru itu yang nggak boleh ketutupan di daftar.
  ///
  /// Nada & ikon ngikutin `StatusSidik` (`terbit` lulus, `menunggu_generate`
  /// tunggu, `gagal` gagal). Dibatalkan pakai ikon `block`, bukan
  /// `cancel_outlined`-nya FAIL: alat yang nggak lolos dan dokumen yang
  /// ditarik itu dua hal yang nggak boleh kebaca sama sekilas.
  StatusBadge? _lencanaSertifikat(AppLocalizations l10n) =>
      switch (item.statusSertifikat) {
        null => null,
        'terbit' => StatusBadge(
          label: l10n.riwayatSertifikatTerbit,
          tone: BadgeTone.success,
          icon: Icons.workspace_premium_outlined,
        ),
        'dibatalkan' => StatusBadge(
          label: l10n.riwayatSertifikatDibatalkan,
          tone: BadgeTone.danger,
          icon: Icons.block,
        ),
        'menunggu_generate' => StatusBadge(
          label: l10n.riwayatSertifikatDiproses,
          tone: BadgeTone.info,
          icon: Icons.hourglass_empty,
        ),
        'gagal' => StatusBadge(
          label: l10n.riwayatSertifikatGagal,
          tone: BadgeTone.danger,
          icon: Icons.error_outline,
        ),
        // Status yang belum dikenal APK ini tetap tampil apa adanya — lebih
        // jujur daripada dijatuhin ke salah satu label yang dikenal.
        final lain => StatusBadge(
          label: lain,
          tone: BadgeTone.neutral,
          icon: Icons.help_outline,
        ),
      };

  StatusBadge _badge(AppLocalizations l10n) {
    if (item.status == CalibrationStatus.disetujui) {
      // `keputusan` bisa NULL, dan itu keadaan yang sah — bukan "belum ada".
      //
      // Conductivity Meter nggak divonis lulus/gagal: master Excel-nya nggak
      // punya satu pun sel yang mbandingin hasil ke batas keberterimaan, jadi
      // backend ngirim `keputusan: null`. Sebelum ini `_ =>` nangkep null dan
      // nampilinnya sebagai PASS — tiap sesi Conductivity kebaca "lulus" padahal
      // alatnya emang nggak pernah dinilai.
      //
      // Yang ditampilkan strip, bukan badge kosong dan bukan tulisan "null".
      return switch (item.keputusan) {
        Keputusan.pass => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
        Keputusan.fail => StatusBadge(
          label: l10n.historyStatusFail,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        ),
        null => StatusBadge(
          label: l10n.statusTanpaKeputusan,
          tone: BadgeTone.neutral,
        ),
      };
    }

    return switch (item.status) {
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
    // Draf sah disimpen tanpa tanggal kalibrasi, jadi baris ini harus bisa
    // ngaku "belum diisi". JANGAN dijatuhin ke `DateTime.now()`: tanggal palsu
    // "hari ini" di daftar riwayat kelihatan sah, dan nggak ada yang bakal
    // curiga sampai sertifikatnya kecetak salah tanggal.
    final tglKalibrasi = item.tanggalKalibrasi;
    final tanggal = tglKalibrasi == null
        ? l10n.tanggalKosong
        : DateFormat('d MMM yyyy', locale).format(tglKalibrasi);
    final lencanaSertifikat = _lencanaSertifikat(l10n);
    final batal = item.statusSertifikat == 'dibatalkan';

    return Card(
      // Kartu yang lagi kebuka di panel kanan dikasih garis tepi aksen, bukan
      // warna latar beda: latar beda bakal berantem sama badge status yang
      // udah pakai warna buat nyampein PASS/FAIL/menunggu.
      shape: disorot
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikon jenis alat — bikin kartu lebih gampang dipindai
                  // (mata langsung ke jenis alatnya), gaya kartu referensi.
                  _IkonAlat(nama: item.namaAlat),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.namaAlat,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.namaTeknisi} · $tanggal',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // Kapan barisnya TERAKHIR bergerak — beda dari tanggal
                        // kalibrasi di atas, dan ini yang mbedain beberapa sesi
                        // yang tanggal kalibrasinya sama persis.
                        if (item.waktuTerakhir != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            waktuRelatif(
                              item.waktuTerakhir!,
                              locale,
                              hariIni: l10n.waktuHariIni,
                              kemarin: l10n.waktuKemarin,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Menu ditumpuk DI BAWAH lencana status, bukan di
                  // sebelahnya: di HP 360 px kolom nama alat udah sempit, dan
                  // satu tombol lagi sebaris bikin namanya patah per kata.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badge(l10n),
                      _MenuBaris(
                        tersembunyi: item.tersembunyi,
                        onSembunyikan: onSembunyikan,
                        onTampilkanLagi: onTampilkanLagi,
                      ),
                    ],
                  ),
                ],
              ),
              // Nomor + lencana sertifikat di baris sendiri, selebar kartu. Di
              // HP 360 px kolom teks di atas cuma ~120 px — lencana
              // "Dibatalkan" nggak muat di situ dan meluap.
              if (item.nomorSertifikat != null ||
                  lencanaSertifikat != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  // Sejajar kolom teks di atas: ikon alat 42 + jarak md.
                  padding: const EdgeInsets.only(left: 42 + AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.nomorSertifikat != null)
                        Text(
                          l10n.historyCertNumber(item.nomorSertifikat!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            // Nomor sertifikat yang dibatalkan dicoret:
                            // nomornya tetap kebaca (buat dicocokkan ke
                            // arsip), tapi nggak kebaca sebagai yang berlaku.
                            decoration: batal
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ?lencanaSertifikat,
                    ],
                  ),
                ),
              ],
              // Penanda baris yang disembunyikan — cuma kelihatan waktu
              // "Tampilkan yang disembunyikan" nyala. Aksinya ditaruh di sini
              // juga, bukan cuma di menu: orang yang nyalain sakelar itu
              // biasanya memang lagi mau mengembalikan sesuatu.
              if (item.tersembunyi) ...[
                const SizedBox(height: AppSpacing.sm),
                // `Wrap`, bukan `Row` + `Spacer`: di HP sempit lencana dan
                // tombolnya nggak muat sebaris, jadi tombolnya turun.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    StatusBadge(
                      label: l10n.riwayatLencanaTersembunyi,
                      tone: BadgeTone.neutral,
                      icon: Icons.visibility_off_outlined,
                    ),
                    TextButton.icon(
                      onPressed: onTampilkanLagi,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(l10n.riwayatTampilkanLagi),
                    ),
                  ],
                ),
              ],
              if (item.status == CalibrationStatus.perluRevisi &&
                  item.catatanRevisi != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.historyCatatanRevisi(item.catatanRevisi!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.statusPeringatan(context),
                  ),
                ),
              ],
              // TIDAK ada tombol approval di sini. Riwayat menjawab "apa saja
              // yang pernah dikerjakan" — daftar bacaan, bukan tempat
              // memutuskan. Yang memutuskan layar Antrean Approval, dan
              // menaruh tombol yang sama di dua tempat bikin admin menyetujui
              // dari daftar yang tidak menampilkan angka perhitungannya.
              // Keputusan pemilik proyek, 16 Sep 2026.
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu tiga titik per baris. Teksnya sengaja panjang: "sembunyikan" gampang
/// kebaca "hapus", dan teknisi yang ngira datanya kehapus bakal ngelapor
/// kehilangan sertifikat. Keterangan "tetap tersimpan" ikut di menunya, bukan
/// cuma di SnackBar sesudahnya.
class _MenuBaris extends StatelessWidget {
  const _MenuBaris({
    required this.tersembunyi,
    required this.onSembunyikan,
    required this.onTampilkanLagi,
  });

  final bool tersembunyi;
  final VoidCallback onSembunyikan;
  final VoidCallback onTampilkanLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<bool>(
      tooltip: l10n.riwayatMenuOpsi,
      icon: const Icon(Icons.more_vert),
      // `true` = sembunyikan, `false` = tampilkan lagi.
      onSelected: (sembunyikan) =>
          sembunyikan ? onSembunyikan() : onTampilkanLagi(),
      itemBuilder: (context) => [
        if (tersembunyi)
          PopupMenuItem<bool>(
            value: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_outlined),
              title: Text(l10n.riwayatTampilkanLagi),
            ),
          )
        else
          PopupMenuItem<bool>(
            value: true,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(l10n.riwayatSembunyikan),
              subtitle: Text(l10n.riwayatSembunyikanKeterangan),
            ),
          ),
      ],
    );
  }
}

/// Kolom cari + sakelar "Tampilkan yang disembunyikan".
///
/// Sakelarnya cuma muncul kalau memang ADA yang disembunyikan (atau lagi
/// nyala) — chip yang selalu bilang "(0)" cuma makan tempat.
class _KepalaCari extends StatelessWidget {
  const _KepalaCari({
    required this.controller,
    required this.kata,
    required this.onGanti,
    required this.onHapus,
    required this.jumlahTersembunyi,
    required this.tampilkanTersembunyi,
    required this.onGantiTampilkanTersembunyi,
  });

  final TextEditingController controller;
  final String kata;
  final ValueChanged<String> onGanti;
  final VoidCallback onHapus;
  final int jumlahTersembunyi;
  final bool tampilkanTersembunyi;
  final ValueChanged<bool> onGantiTampilkanTersembunyi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
          TextField(
            controller: controller,
            onChanged: onGanti,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.riwayatCariHint,
              suffixIcon: kata.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.riwayatCariHapus,
                      onPressed: onHapus,
                    ),
            ),
          ),
          if (jumlahTersembunyi > 0 || tampilkanTersembunyi) ...[
            const SizedBox(height: AppSpacing.sm),
            FilterChip(
              avatar: const Icon(Icons.visibility_off_outlined, size: 18),
              label: Text(l10n.riwayatTampilkanTersembunyi(jumlahTersembunyi)),
              selected: tampilkanTersembunyi,
              onSelected: onGantiTampilkanTersembunyi,
            ),
          ],
        ],
      ),
    );
  }
}

/// Riwayat ADA, tapi nggak ada yang lolos saringan (kata cari dan/atau
/// sakelar tersembunyi). Kalau yang cocok ternyata ada di baris yang
/// disembunyikan, itu disebut terang-terangan + tombol buat nampilinnya —
/// tanpa itu orang yang lupa pernah nyembunyiin bakal ngira datanya ilang.
class _TidakCocok extends StatelessWidget {
  const _TidakCocok({
    required this.kata,
    required this.cocokTersembunyi,
    required this.onTampilkanTersembunyi,
  });

  /// Sudah di-`trim`. Kosong = yang nyaring cuma sakelar tersembunyi.
  final String kata;
  final int cocokTersembunyi;
  final VoidCallback onTampilkanTersembunyi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          kata.isEmpty
              ? l10n.riwayatSemuaTersembunyi
              : l10n.riwayatCariKosong(kata),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (kata.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.riwayatCariKosongSaran,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (cocokTersembunyi > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          if (kata.isNotEmpty) ...[
            Text(
              l10n.riwayatAdaCocokTersembunyi(cocokTersembunyi),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: l10n.riwayatTampilkanTersembunyi(cocokTersembunyi),
            icon: Icons.visibility_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onTampilkanTersembunyi,
          ),
        ],
      ],
    );
  }
}

/// Ikon jenis alat dalam kotak membulat lembut. Ikonnya dicocokin lewat
/// keyword nama (sumbernya teks bebas), dengan fallback ikon "ukur" generik.
class _IkonAlat extends StatelessWidget {
  const _IkonAlat({required this.nama});

  final String nama;

  IconData get _ikon {
    final n = nama.toLowerCase();
    return switch (n) {
      _ when n.contains('ph meter') => Icons.science_outlined,
      _ when n.contains('turbidi') => Icons.blur_on_outlined,
      _ when n.contains('conductivity') => Icons.bolt_outlined,
      _ when n.contains('thermo') || n.contains('termo') =>
        Icons.device_thermostat_outlined,
      _ when n.contains('timbang') => Icons.scale_outlined,
      _ when n.contains('oven') || n.contains('furnace') =>
        Icons.local_fire_department_outlined,
      _ when n.contains('pipet') || n.contains('buret') =>
        Icons.science_outlined,
      _ when n.contains('caliper') || n.contains('micrometer') =>
        Icons.straighten_outlined,
      _ => Icons.straighten_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_ikon, size: 21, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.history_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.historyEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.historyEmptyBody,
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
          label: AppLocalizations.of(context).historyRetry,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 160),
              const SizedBox(height: AppSpacing.xs),
              const SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
