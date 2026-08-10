import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/folder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/history_provider.dart' show pdfDownloaderProvider;
import '../../services/buka_berkas.dart';
import '../../services/pdf_downloader.dart' show PdfDownloadException;
import '../../widgets/glass_surface.dart';
import '../history/calibration_detail_screen.dart';
import '../history/kirim_email_screen.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik_loader.dart';

/// Folder Manager (spesifikasi poin 3 & 7) — menggantikan "Notifikasi" di
/// navbar bawah.
///
/// **Sebagian besar isinya kebentuk sendiri** di backend (`PT / tahun`) tiap
/// sertifikat terbit — CRUD di sini buat ngerapiin sisanya: bikin folder
/// arsip sendiri, ganti nama, hapus yang nggak kepake.
///
/// Tombol tulisnya cuma muncul buat **admin** (backend nolak role lain dengan
/// 403), dan folder `tipe: sistem` nggak dikasih "Ganti nama" karena namanya
/// dipakai backend buat nemuin folder yang udah ada.
///
/// Dipakai dua cara: sebagai tab navbar ([folderId] null, tanpa tombol back)
/// dan sebagai halaman sendiri waktu masuk ke sub-folder (ada tombol back —
/// spesifikasi poin 5).
class FolderManagerScreen extends ConsumerWidget {
  const FolderManagerScreen({super.key, this.folderId, this.judul});

  /// Null = folder akar (daftar PT).
  final int? folderId;

  final String? judul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Nulis folder itu admin doang — backend nolak role lain dengan 403.
    // Tombolnya disembunyiin biar teknisi nggak nyoba lalu ditolak, tapi yang
    // beneran njagain tetap backend, bukan `if` ini.
    final admin = ref.bolehkah(
      NamaIzin.folderTulis,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(judul ?? l10n.folderTitle),
        // Ikon notifikasi di atas, bukan di navbar bawah (poin 4).
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: ReadableWidth(
        child: folderId == null
            ? const _Akar()
            : _IsiFolder(folderId: folderId!),
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _dialogNamaFolder(
                context: context,
                ref: ref,
                judul: l10n.folderBuatJudul,
                onSimpan: (nama) => ref
                    .read(folderAksiProvider)
                    .buat(nama: nama, parentId: folderId),
              ),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.folderBuat),
            )
          : null,
    );
  }
}

/// Dialog satu kolom nama, dipakai bareng "Folder baru" & "Ganti nama".
///
/// [onSimpan] balikin pesan error dari backend, atau `null` kalau berhasil —
/// pesannya dipakai apa adanya karena backend yang paling tau konteksnya
/// ("sudah ada folder bernama X di lokasi ini").
Future<void> _dialogNamaFolder({
  required BuildContext context,
  required WidgetRef ref,
  required String judul,
  required Future<String?> Function(String nama) onSimpan,
  String namaAwal = '',
}) async {
  final l10n = AppLocalizations.of(context);

  final nama = await showDialog<String>(
    context: context,
    builder: (context) => _DialogNamaFolder(judul: judul, namaAwal: namaAwal),
  );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  if (nama == null) return;
  if (nama.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.folderNamaKosong)));
    return;
  }

  final error = await onSimpan(nama);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}

/// Isi dialog nama folder.
///
/// Punya controller-nya sendiri **dengan sengaja**: kalau controller dibikin
/// di luar lalu di-`dispose()` begitu `showDialog` selesai, TextField-nya masih
/// kepakai selama animasi dialog nutup — dan itu langsung assert
/// "TextEditingController was used after being disposed". Widget yang punya,
/// widget itu juga yang buang.
class _DialogNamaFolder extends StatefulWidget {
  const _DialogNamaFolder({required this.judul, required this.namaAwal});

  final String judul;
  final String namaAwal;

  @override
  State<_DialogNamaFolder> createState() => _DialogNamaFolderState();
}

class _DialogNamaFolderState extends State<_DialogNamaFolder> {
  late final _controller = TextEditingController(text: widget.namaAwal);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simpan() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.judul),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.folderNamaLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _simpan(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.folderBatal),
        ),
        TextButton(onPressed: _simpan, child: Text(l10n.folderSimpan)),
      ],
    );
  }
}

/// Daftar PT di tingkat paling atas.
class _Akar extends ConsumerWidget {
  const _Akar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(folderListProvider(null));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(folderListProvider(null)),
      child: switch (async) {
        AsyncData(:final value) => value.isEmpty
            ? const _Kosong()
            : _DaftarFolder(folder: value),
        AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(folderListProvider(null)),
        ),
        _ => const Center(child: SidikLoader(size: 88)),
      },
    );
  }
}

/// Sub-folder + file di dalam satu folder.
class _IsiFolder extends ConsumerWidget {
  const _IsiFolder({required this.folderId});

  final int folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(folderDetailProvider(folderId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(folderDetailProvider(folderId)),
      child: switch (async) {
        AsyncData(:final value) =>
          value.subFolder.isEmpty && value.file.isEmpty
              ? _Kosong(pesan: l10n.folderIsiKosong)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final f in value.subFolder) ...[
                      _KartuFolder(folder: f),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final f in value.file) ...[
                      _KartuFile(file: f),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(folderDetailProvider(folderId)),
        ),
        _ => const Center(child: SidikLoader(size: 88)),
      },
    );
  }
}

class _DaftarFolder extends StatelessWidget {
  const _DaftarFolder({required this.folder});

  final List<Folder> folder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: folder.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _KartuFolder(folder: folder[i]),
    );
  }
}

class _KartuFolder extends ConsumerWidget {
  const _KartuFolder({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    final rincian = [
      if (folder.jumlahFolder != null && folder.jumlahFolder! > 0)
        l10n.folderJumlahFolder(folder.jumlahFolder!),
      if (folder.jumlahFile != null && folder.jumlahFile! > 0)
        l10n.folderJumlahFile(folder.jumlahFile!),
      // Waktu bikin ikut di baris rincian, bukan baris sendiri: folder
      // biasanya banyak dan pendek-pendek, jadi nambah baris ketiga bikin
      // daftarnya dua kali lebih panjang tanpa nambah kejelasan.
      if (folder.dibuatPada != null)
        waktuRelatif(
          folder.dibuatPada!,
          Localizations.localeOf(context).languageCode,
          hariIni: l10n.waktuHariIni,
          kemarin: l10n.waktuKemarin,
        ),
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(
          folder.folderSistem ? Icons.folder_special_outlined : Icons.folder_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(folder.nama, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          rincian.isEmpty ? l10n.folderIsiKosong : rincian,
          style: theme.textTheme.labelSmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (admin)
              _MenuFolder(folder: folder)
            else
              const SizedBox.shrink(),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  FolderManagerScreen(folderId: folder.id, judul: folder.nama),
            ),
          );
        },
      ),
    );
  }
}

/// Ganti nama & hapus per folder.
///
/// **Folder `sistem` nggak dikasih "Ganti nama".** Namanya = nama PT / tahun,
/// dan itu yang dipakai `FolderOrganizer` buat nemuin folder yang udah ada —
/// begitu direname, sertifikat berikutnya bikin folder baru dan arsipnya
/// kepecah dua. Backend nolaknya (`prohibited`), jadi jangan ditawarin.
///
/// "Hapus" tetap dikasih: folder sistem yang udah KOSONG boleh dibuang. Yang
/// masih ada isinya ditolak backend, dan pesannya ditampilin apa adanya —
/// nyembunyiin tombolnya malah bikin folder sisa nggak bisa dirapiin sama
/// sekali.
class _MenuFolder extends ConsumerWidget {
  const _MenuFolder({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (context) => [
        if (folder.folderSistem)
          PopupMenuItem(
            enabled: false,
            child: Text(
              l10n.folderSistemDikunci,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          )
        else
          PopupMenuItem(
            value: 'ganti',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.drive_file_rename_outline, size: 20),
              title: Text(l10n.folderGantiNama),
            ),
          ),
        PopupMenuItem(
          value: 'hapus',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, size: 20),
            title: Text(l10n.folderHapus),
          ),
        ),
      ],
      onSelected: (nilai) async {
        if (nilai == 'ganti') {
          await _dialogNamaFolder(
            context: context,
            ref: ref,
            judul: l10n.folderGantiNamaJudul,
            namaAwal: folder.nama,
            onSimpan: (nama) => ref.read(folderAksiProvider).gantiNama(
              id: folder.id,
              nama: nama,
              parentId: folder.parentId,
            ),
          );
          return;
        }

        final yakin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.folderHapusJudul),
            content: Text(l10n.folderHapusBody(folder.nama)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.folderBatal),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.folderHapusLanjut),
              ),
            ],
          ),
        );

        if (yakin != true || !context.mounted) return;

        final messenger = ScaffoldMessenger.of(context);
        final error = await ref
            .read(folderAksiProvider)
            .hapus(id: folder.id, parentId: folder.parentId);

        if (error != null) {
          messenger.showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );
  }
}

/// Satu baris berkas di dalam folder — **bisa dibuka & dibagikan**.
///
/// Sebelum ini barisnya `ListTile` tanpa `onTap`, tanpa tombol, tanpa menu:
/// ditekan nggak terjadi apa-apa. Padahal semua bahannya udah ada dan udah
/// kepakai di layar Sertifikat — [bukaBerkas] (yang ngerti beda Android/iOS
/// vs desktop), [pdfDownloaderProvider], dan [KirimEmailScreen]. Yang kurang
/// cuma penyambungannya di sini.
///
/// Alurnya sama persis dengan layar Sertifikat, sengaja nggak bikin jalur
/// baru: unduh ke berkas lokal lewat endpoint ber-otorisasi, baru serahin ke
/// aplikasi bawaan sistem. `download_url` butuh header `Authorization`, jadi
/// nggak bisa dilempar mentah ke browser.
class _KartuFile extends ConsumerStatefulWidget {
  const _KartuFile({required this.file});

  final FolderFile file;

  @override
  ConsumerState<_KartuFile> createState() => _KartuFileState();
}

class _KartuFileState extends ConsumerState<_KartuFile> {
  bool _sibuk = false;

  FolderFile get file => widget.file;

  /// Sertifikat yang PDF-nya masih digenerate belum bisa dibuka — ditahan di
  /// sini juga, bukan cuma diberi label, biar nggak ada yang nembak 404.
  bool get _belumSiap => file.dariSertifikat && !file.sertifikatSiapDiunduh;

  Future<void> _buka() async {
    if (_sibuk || _belumSiap || file.downloadUrl.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _sibuk = true);
    try {
      final path = await ref
          .read(pdfDownloaderProvider)
          .unduh(token, file.downloadUrl, namaFile: file.nama);

      final gagal = await bukaBerkas(path);
      if (gagal != null && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(gagal)));
      }
    } on PdfDownloadException catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Lembar kerja nggak punya berkas buat diunduh — backend sengaja ngirim
  /// `download_url: null` (lihat `FolderFileResource`). Tanpa ini barisnya
  /// mati total: nggak bisa diunduh DAN nggak nganterin ke mana-mana.
  void _bukaSesi() {
    final id = file.calibrationSessionId;
    if (id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationDetailScreen(calibrationId: id),
      ),
    );
  }

  void _bagikan() {
    final id = file.sertifikatId;
    final nomor = file.sertifikatNomor;
    if (id == null || nomor == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KirimEmailScreen(
          certificateId: id,
          nomorSertifikat: nomor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final rincian = [
      if (file.ukuranTerbaca != null) file.ukuranTerbaca!,
      if (file.diunggahOleh != null) file.diunggahOleh!,
      // Kapan berkasnya masuk. Satu folder gampang berisi belasan sertifikat
      // yang terbit di hari yang sama — tanpa jam, urutannya cuma bisa ditebak
      // dari posisi baris.
      if (file.dibuatPada != null)
        waktuRelatif(
          file.dibuatPada!,
          Localizations.localeOf(context).languageCode,
          hariIni: l10n.waktuHariIni,
          kemarin: l10n.waktuKemarin,
        ),
    ].join(' · ');

    // Sertifikat yang PDF-nya masih digenerate belum bisa diunduh — kasih tau,
    // jangan kasih tombol yang bakal balik 404.
    final belumSiap = _belumSiap;
    final bisaDibuka = !belumSiap && file.downloadUrl.isNotEmpty;
    final bisaDibagikan = file.sertifikatId != null && !belumSiap;

    // Lembar kerja nggak punya berkas buat diunduh (backend sengaja ngirim
    // `download_url: null`), tapi punya sesi — jadi barisnya nganterin ke
    // detail sesinya. Sebelum ini baris lembar kerja mati total.
    final aksiUtama = bisaDibuka
        ? _buka
        : (file.calibrationSessionId != null ? _bukaSesi : null);

    // Gaya disamain sama layar Login & Arsip (`SoftRaised`), bukan Card +
    // ListTile bawaan Material — layar ini satu-satunya yang kelihatan beda
    // sendiri di seluruh app.
    return SoftRaised(
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: aksiUtama,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: _sibuk
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    file.dariSertifikat
                        ? Icons.workspace_premium_outlined
                        : Icons.insert_drive_file_outlined,
                    color: belumSiap
                        ? theme.colorScheme.outline
                        : theme.colorScheme.secondary,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.nama,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (belumSiap || rincian.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    belumSiap ? l10n.folderSertifikatBelumSiap : rincian,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: belumSiap
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Menu cuma dimunculkan kalau ada yang bisa dilakukan — daripada
          // ngasih tombol yang ditekan lalu diam, persis masalah yang lagi
          // dibenerin di sini.
          if (bisaDibuka || bisaDibagikan)
            PopupMenuButton<String>(
              enabled: !_sibuk,
              onSelected: (v) => v == 'buka' ? _buka() : _bagikan(),
              itemBuilder: (_) => [
                if (bisaDibuka)
                  PopupMenuItem(
                    value: 'buka',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.open_in_new),
                      title: Text(l10n.folderBukaBerkas),
                    ),
                  ),
                if (bisaDibagikan)
                  PopupMenuItem(
                    value: 'bagikan',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.share_outlined),
                      title: Text(l10n.folderBagikanBerkas),
                    ),
                  ),
              ],
            )
          else if (aksiUtama != null)
            const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({this.pesan});

  final String? pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.folder_open_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan ?? l10n.folderEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (pesan == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.folderEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
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
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.folderLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.folderRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
