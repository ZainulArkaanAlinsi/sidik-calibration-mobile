import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/models/izin.dart' show NamaIzin;
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../../data/simulasi_provider.dart';
import '../../data/workbook_model.dart';
import '../../data/workbook_provider.dart';
import '../../data/workbook_service.dart' show batasEditSimulasi;
import '../../inti/sesi_studio.dart';
import '../../l10n/studio_l10n.dart';
import '../../tema/tema_studio.dart';
import '../../tema/warna_studio.dart';
import '../../widget/grid/grid_sel.dart';
import 'daftar_workbook_screen.dart'
    show LencanaImporWorkbook, LencanaSumberWorkbook;
import 'riwayat_workbook_screen.dart' show bukaRiwayatWorkbook;

/// Lebar area lembar mulai inspektur DIDORONG di samping grid; di bawahnya
/// (tablet potret) inspektur MENUTUPI grid dari kanan dan bisa ditutup.
const double lebarInspekturDorong = 900;

/// Lebar panel inspektur.
const double lebarPanelInspektur = 300;

/// Inspektur terbuka bawaan: layar lanskap yang cukup lebar (meja, tablet
/// lanskap). Tablet potret: tertutup — grid butuh lebarnya.
bool inspekturTerbukaBawaan(Size layar) =>
    layar.width >= lebarInspekturDorong && layar.width > layar.height;

/// Buka workbook di navigator AKAR: layar penuh seperti Excel, satu bilah
/// (bukan bilah cangkang + bilah workbook bertumpuk).
Future<void> bukaWorkbook(BuildContext context, WorkbookRingkas wb) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkbookScreen(workbookId: wb.id, judul: wb.nama),
      ),
    );

/// Satu workbook dalam mode "Asli Excel" (S1b, K-49-08; tampilan Tahap A).
///
/// Tahap C: admin, super_admin, dan teknisi bisa MENGEDIT sel sebagai
/// SIMULASI — server menghitung ulang workbook (`POST /hitung`) dan hasilnya
/// ditimpakan di atas grid; tidak ada yang disimpan (spanduk "Simulasi —
/// tidak disimpan" + Reset). Peran lain & workbook CSV: baca-saja. Lembar
/// tersembunyi tidak tampil di tab sampai ditampilkan lewat menu tab.
///
/// Susunannya meniru Excel supaya orang lab langsung mengenalinya: SATU bilah
/// atas (kembali, nama, aksi), bilah rumus selebar layar (kotak nama + isi),
/// grid, tab lembar di bawah, lalu bilah status (jumlah sel, sumber, zoom).
/// Inspektur sel = panel kanan yang bisa ditutup; menampilkan NILAI PERSIS
/// (`n`) di samping teks tampil (`s`): angka di grid adalah hasil format
/// angka Excel, bukan nilainya.
///
/// Dibuka di navigator akar ([bukaWorkbook]) — jadi layar ini menutup
/// dirinya sendiri bila akun berganti/keluar, versi Studio ditolak server,
/// atau izin `workbook.lihat` dicabut (cangkang di bawahnya sudah pindah ke
/// layar lain, tapi rute akar tidak ikut tergulung).
///
/// K-49-13: workbook berstatus RIWAYAT (versi lama) tampil baca saja dengan
/// spanduk "Riwayat — bukan master aktif". Master yang DIKELUARKAN dari
/// Studio saat layar ini terbuka (diarsipkan → 404; atau id lama sesudah
/// ekstrak ulang di server) → pesan "sudah diarsipkan/diganti" dan layar
/// kembali ke daftar.
class WorkbookScreen extends ConsumerStatefulWidget {
  const WorkbookScreen({super.key, required this.workbookId, this.judul});

  final int workbookId;

  /// Nama dari daftar — dipakai selama detail dimuat.
  final String? judul;

  @override
  ConsumerState<WorkbookScreen> createState() => _WorkbookScreenState();
}

class _WorkbookScreenState extends ConsumerState<WorkbookScreen> {
  /// Akun saat layar dibuka — dibaca di [initState], BUKAN malas: dibaca
  /// pertama kali di dalam listener berarti sudah akun yang baru.
  late final int? _akun;
  bool _ditutup = false;

  @override
  void initState() {
    super.initState();
    _akun = ref.read(authProvider).value?.id;
    // `ref.listen` di build tidak menembak untuk nilai awal: 426 yang sudah
    // tercatat sebelum layar ini dibangun tetap menutupnya.
    if (ref.read(klienKedaluwarsaProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tutup());
    }
  }

  void _tutup() {
    if (_ditutup || !mounted) return;
    _ditutup = true;
    final rute = ModalRoute.of(context);
    if (rute != null && rute.isActive) {
      Navigator.of(context).removeRoute(rute);
    }
  }

  /// Detail sudah pernah termuat di layar ini: 404 SESUDAHNYA berarti master
  /// dikeluarkan dari Studio selagi dibuka, bukan id yang memang tidak ada
  /// (itu tetap pesan "tidak ditemukan" di tempat).
  bool _pernahDimuat = false;

  /// 404 di detail (muat ulang) atau `/hitung` sesudah detail termuat:
  /// master diarsipkan/diganti selagi dibuka. Pesan jelas, daftar (dan
  /// riwayat) ditarik ulang, layar kembali ke daftar — edit simulasi ikut
  /// hilang (memang tidak pernah disimpan).
  void _masterHilang() {
    if (_ditutup || !mounted) return;
    ref.invalidate(daftarWorkbookProvider);
    ref.invalidate(riwayatWorkbookProvider);
    // Pembawa pesan akar: SnackBar-nya pindah ke layar di bawah sesudah rute
    // ini dilepas.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const ValueKey('pesan-master-diarsipkan'),
        content: Text(StudioL10n.of(context).workbookDiarsipkan),
      ),
    );
    _tutup();
  }

  static bool _tidakAda(Object? e) => e is ApiException && e.status == 404;

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((a) => a.value?.id), (_, id) {
      if (id != _akun) _tutup();
    });
    ref.listen(detailWorkbookProvider(widget.workbookId), (lama, baru) {
      if (baru is! AsyncError || !_tidakAda(baru.error)) return;
      if (_pernahDimuat || (lama?.hasValue ?? false)) {
        _masterHilang();
      } else {
        // 404 saat PERTAMA dibuka: pesan "tidak ditemukan" tetap di tempat,
        // tapi baris daftar di bawahnya basi (diarsipkan, atau id berganti
        // sesudah ekstrak ulang di server) — daftar ditarik ulang.
        ref.invalidate(daftarWorkbookProvider);
      }
    });
    ref.listen(
      simulasiWorkbookProvider(
        widget.workbookId,
      ).select((s) => s.galat?.status),
      (_, status) {
        if (status == 404) _masterHilang();
      },
    );
    ref.listen(klienKedaluwarsaProvider, (_, usang) {
      if (usang) _tutup();
    });
    ref.listen(izinProvider, (_, izin) {
      final i = izin.value;
      if (i != null &&
          !i.bolehkah(izinWorkbookLihat, cadangan: cadanganIzinWorkbook)) {
        _tutup();
      }
    });

    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final detail = ref.watch(detailWorkbookProvider(widget.workbookId));
    if (detail is AsyncData) _pernahDimuat = true;
    final judul = widget.judul ?? '';

    final Widget badan = switch (detail) {
      AsyncData(:final value) => _IsiWorkbook(detail: value),
      AsyncError(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BilahWorkbook(judul: judul),
          Expanded(
            child: _Keadaan(
              ikon: Icons.cloud_off_outlined,
              judul: switch (error) {
                ApiException(status: 404) => l10n.workbookTidakDitemukan,
                AuthException(:final message) when message.isNotEmpty =>
                  message,
                _ => l10n.workbookGagalMuat,
              },
              aksi: FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(detailWorkbookProvider(widget.workbookId)),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.cobaLagi),
              ),
            ),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BilahWorkbook(judul: judul),
          LinearProgressIndicator(semanticsLabel: l10n.memuat),
          const Spacer(),
        ],
      ),
    };

    return Scaffold(
      backgroundColor: w.latar,
      body: SafeArea(child: badan),
    );
  }
}

class _IsiWorkbook extends ConsumerStatefulWidget {
  const _IsiWorkbook({required this.detail});

  final WorkbookDetail detail;

  @override
  ConsumerState<_IsiWorkbook> createState() => _IsiWorkbookState();
}

class _IsiWorkbookState extends ConsumerState<_IsiWorkbook> {
  /// Lembar tersembunyi yang DITAMPILKAN di sesi layar ini (menu tab
  /// "Tampilkan lembar tersembunyi…") — tampilan saja, tidak disimpan.
  final _ditampilkan = <int>{};

  late int _indeks = _lembarAwal();

  /// Seleksi, mode rumus, dan zoom per lembar — pindah tab lalu kembali
  /// tidak kehilangan posisi, seperti Excel.
  final _kendali = <int, KendaliGridSel>{};

  /// Tata letak grid per lembar, dibuat SEKALI: grid memakai identitasnya
  /// untuk tahu kapan geometri perlu dihitung ulang.
  final _tataLetak = <int, TataLetakGrid>{};

  /// `null` sampai ukuran layar diketahui ([inspekturTerbukaBawaan]).
  bool? _inspektur;

  /// Lembar pertama yang terlihat & berisi (bukan tersembunyi/dikecualikan);
  /// semua tersembunyi (Excel tidak mengizinkan, tapi data bisa begitu) →
  /// lembar pertama DITAMPILKAN supaya layar tidak kosong tanpa tab.
  int _lembarAwal() {
    final l = widget.detail.lembar;
    var i = l.indexWhere(
      (x) => !x.tersembunyi.disembunyikan && !x.dikecualikan,
    );
    if (i < 0) i = l.indexWhere((x) => !x.tersembunyi.disembunyikan);
    if (i < 0 && l.isNotEmpty) {
      _ditampilkan.add(l.first.id);
      i = 0;
    }
    return i < 0 ? 0 : i;
  }

  bool _tampilDiTab(LembarWorkbook l) =>
      !l.tersembunyi.disembunyikan || _ditampilkan.contains(l.id);

  /// Pindah lembar: edit yang sedang terbuka disimpan dulu (seperti Excel);
  /// ditolak penyunting → tetap di lembar ini.
  void _pilihLembar(int i) {
    final semua = widget.detail.lembar;
    if (_indeks < semua.length) {
      final k = _kendali[semua[_indeks].id];
      if (k != null && k.sedangEdit && !k.simpanEdit()) return;
    }
    setState(() => _indeks = i);
  }

  /// Menu tab (klik kanan / tekan lama), seperti Excel.
  Future<void> _menuTab(Offset posisi) async {
    final l10n = StudioL10n.of(context);
    final tersembunyi = [
      for (final (i, l) in widget.detail.lembar.indexed)
        if (!_tampilDiTab(l)) (i, l),
    ];
    final layar = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pilihan = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        posisi & const Size(1, 1),
        Offset.zero & layar.size,
      ),
      items: [
        PopupMenuItem(
          key: const ValueKey('menu-tampilkan-lembar'),
          value: 'tampilkan',
          enabled: tersembunyi.isNotEmpty,
          child: Text(l10n.lembarTampilkanTersembunyi),
        ),
      ],
    );
    if (pilihan != 'tampilkan' || !mounted) return;
    final dipilih = await showDialog<int>(
      context: context,
      builder: (context) => _DialogTampilkanLembar(lembar: tersembunyi),
    );
    if (dipilih == null || !mounted) return;
    setState(() => _ditampilkan.add(widget.detail.lembar[dipilih].id));
    _pilihLembar(dipilih);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inspektur ??= inspekturTerbukaBawaan(MediaQuery.sizeOf(context));
  }

  @override
  void didUpdateWidget(covariant _IsiWorkbook lama) {
    super.didUpdateWidget(lama);
    if (!identical(lama.detail, widget.detail)) {
      _tataLetak.clear();
      if (_indeks >= widget.detail.lembar.length) _indeks = _lembarAwal();
    }
    // Digantikan master baru selagi dibuka (muat ulang → `status: riwayat`):
    // edit simulasi yang ada dibuang — riwayat baca saja, tidak dihitung.
    if (!lama.detail.meta.riwayat && widget.detail.meta.riwayat) {
      final id = widget.detail.meta.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(simulasiWorkbookProvider(id).notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    for (final k in _kendali.values) {
      k.dispose();
    }
    super.dispose();
  }

  KendaliGridSel _kendaliUntuk(LembarWorkbook l) =>
      _kendali.putIfAbsent(l.id, KendaliGridSel.new);

  TataLetakGrid _tataLetakUntuk(LembarWorkbook l) =>
      _tataLetak.putIfAbsent(l.id, l.tataLetak.keGrid);

  void _muatUlang() {
    ref.invalidate(detailWorkbookProvider(widget.detail.meta.id));
    ref.invalidate(halamanSelWorkbookProvider);
  }

  void _aturInspektur(bool buka) {
    if (_inspektur != buka) setState(() => _inspektur = buka);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final meta = widget.detail.meta;
    final semua = widget.detail.lembar;
    final lembar = semua.isEmpty ? null : semua[_indeks];
    final bergrid =
        lembar != null &&
        !lembar.dikecualikan &&
        lembar.jumlahBaris >= 1 &&
        lembar.jumlahKolom >= 1;
    final kendali = lembar == null ? null : _kendaliUntuk(lembar);
    final inspektur = bergrid && (_inspektur ?? false);

    // Simulasi hidup selama layar ini terbuka (bukan cuma selama ada grid
    // yang menonton overlay-nya) — tanpa membangun ulang layar tiap kali
    // "Menghitung…" berubah.
    ref.listen(simulasiWorkbookProvider(meta.id), (_, _) {});
    // Edit = SIMULASI di server: syarat yang SAMA dengan penolak 409
    // `berkas_asli_tidak_ada` di server (sumber xlsm DAN berkas asli
    // tersimpan) + izin `workbook.hitung` (server tidak menyebutnya →
    // cadangan aturan peran kontrak). Server tetap menolak sendiri
    // (403/409, termasuk `perlu_sandi` yang tidak terlihat dari meta) — ini
    // bukan kontrol akses.
    //
    // RIWAYAT (K-49-13, versi lama) selalu baca saja: server masih mau
    // menghitungnya, tapi Studio hanya menyimulasikan master aktif.
    final bolehEdit =
        !meta.riwayat &&
        meta.sumber == SumberWorkbook.xlsm &&
        meta.berkasAsliTersimpan &&
        ref.bolehkah(
          NamaIzin.workbookHitung,
          // K-50-12: satu akun Studio (ability `studio`), tanpa penyaring
          // peran di klien — server yang memutuskan.
          cadangan: true,
        );

    final Widget badan;
    if (lembar == null) {
      badan = _Keadaan(
        ikon: Icons.layers_clear_outlined,
        judul: l10n.lembarTidakAda,
      );
    } else if (lembar.dikecualikan) {
      badan = PanelLembarDikecualikan(lembar: lembar);
    } else {
      badan = _LembarGrid(
        key: ValueKey('lembar-${lembar.id}'),
        workbookId: meta.id,
        lembar: lembar,
        tataLetak: _tataLetakUntuk(lembar),
        kendali: kendali!,
        // Angka General ditiru dari `n` hanya untuk workbook asli; teks sel
        // CSV sudah hasil format Excel saat ekspor (lebar perkiraan).
        tiruGeneral:
            meta.sumber == SumberWorkbook.xlsm &&
            !lembar.tataLetak.lebarPerkiraan,
        bolehEdit: bolehEdit,
        onTekanLama: (_) => _aturInspektur(true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BilahWorkbook(
          judul: meta.nama,
          workbook: meta,
          kendali: bergrid ? kendali : null,
          inspekturTerbuka: inspektur,
          onInspektur: bergrid ? () => _aturInspektur(!inspektur) : null,
          onMuatUlang: _muatUlang,
          bolehEdit: bolehEdit,
        ),
        if (bergrid)
          _BilahRumus(
            workbookId: meta.id,
            lembar: lembar,
            kendali: kendali!,
            bolehEdit: bolehEdit,
          ),
        if (meta.riwayat) _SpandukRiwayat(workbook: meta),
        _SpandukSimulasi(workbookId: meta.id),
        Expanded(
          child: _AreaLembar(
            terbuka: inspektur,
            panel: bergrid
                ? _PanelInspektur(
                    workbookId: meta.id,
                    lembar: lembar,
                    kendali: kendali!,
                    onTutup: () => _aturInspektur(false),
                  )
                : null,
            child: badan,
          ),
        ),
        if (semua.isNotEmpty)
          _TabLembar(
            lembar: [
              for (final (i, l) in semua.indexed)
                if (_tampilDiTab(l) || i == _indeks) (i, l),
            ],
            indeks: _indeks,
            onPilih: _pilihLembar,
            onMenu: _menuTab,
          ),
        _Kaki(
          workbook: meta,
          lembar: lembar,
          kendali: bergrid ? kendali : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── bilah atas

/// SATU-SATUNYA bilah atas layar workbook: kembali, nama + sumber + profil,
/// lalu aksi (tampilkan rumus, inspektur, muat ulang).
class _BilahWorkbook extends StatelessWidget {
  const _BilahWorkbook({
    required this.judul,
    this.workbook,
    this.kendali,
    this.inspekturTerbuka = false,
    this.onInspektur,
    this.onMuatUlang,
    this.bolehEdit = false,
  });

  final String judul;
  final WorkbookRingkas? workbook;
  final KendaliGridSel? kendali;
  final bool inspekturTerbuka;
  final VoidCallback? onInspektur;
  final VoidCallback? onMuatUlang;

  /// Peran boleh simulasi: penanda "Simulasi" + urung/ulang menggantikan
  /// gembok "Baca saja".
  final bool bolehEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final wb = workbook;
    final k = kendali;
    final lebar = MediaQuery.sizeOf(context).width;

    return Material(
      color: w.permukaan,
      child: Container(
        height: UkuranStudio.tinggiBilah,
        padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j1),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: w.garis)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.kembali,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: UkuranStudio.j1),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        judul,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: teks.titleSmall,
                      ),
                    ),
                  ),
                  if (wb != null) ...[
                    const SizedBox(width: UkuranStudio.j3),
                    LencanaSumberWorkbook(workbook: wb),
                    if (lebar >= 760 && wb.versi != null) ...[
                      const SizedBox(width: UkuranStudio.j2),
                      LencanaImporWorkbook(workbook: wb),
                    ],
                    if (lebar >= 760) ...[
                      const SizedBox(width: UkuranStudio.j2),
                      Flexible(
                        child: Text(
                          wb.kodeProfil ?? l10n.workbookBelumDipetakan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: wb.kodeProfil == null
                              ? teks.bodySmall?.copyWith(color: w.teksRedup)
                              : TipografiStudio.angka(
                                  ukuran: 12,
                                  warna: w.teks2,
                                ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (wb != null && !wb.riwayat && wb.jumlahRiwayat > 0)
              _TombolRiwayat(workbook: wb, berlabel: lebar >= 1000),
            Tooltip(
              key: ValueKey(bolehEdit ? 'penanda-simulasi' : 'penanda-baca'),
              message: bolehEdit
                  ? l10n.workbookSimulasiKet
                  : l10n.workbookBacaSaja,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UkuranStudio.j2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      bolehEdit ? Icons.science_outlined : Icons.lock_outline,
                      size: 14,
                      color: w.teksRedup,
                    ),
                    if (lebar >= 600) ...[
                      const SizedBox(width: 4),
                      Text(
                        bolehEdit
                            ? l10n.workbookSimulasi
                            : l10n.workbookBacaSaja,
                        style: teks.labelMedium?.copyWith(color: w.teksRedup),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (bolehEdit && wb != null) _TombolUrung(workbookId: wb.id),
            if (k != null)
              ListenableBuilder(
                listenable: k,
                builder: (context, _) => IconButton(
                  key: const ValueKey('tombol-rumus'),
                  tooltip: k.tampilkanRumus
                      ? l10n.workbookTampilkanNilai
                      : l10n.workbookTampilkanRumus,
                  isSelected: k.tampilkanRumus,
                  icon: const Icon(Icons.functions),
                  onPressed: k.balikRumus,
                ),
              ),
            if (onInspektur != null)
              IconButton(
                key: const ValueKey('tombol-inspektur'),
                tooltip: inspekturTerbuka
                    ? l10n.workbookTutupInspektur
                    : l10n.workbookInspektur,
                isSelected: inspekturTerbuka,
                icon: const Icon(Icons.info_outline),
                selectedIcon: const Icon(Icons.info),
                onPressed: onInspektur,
              ),
            if (onMuatUlang != null)
              IconButton(
                tooltip: l10n.workbookMuatUlang,
                icon: const Icon(Icons.refresh),
                onPressed: onMuatUlang,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Riwayat (n)" di bilah atas master aktif (K-49-13): versi lama jenis ini.
/// Layar lebar = tombol berlabel; sempit = ikon berlencana jumlah.
class _TombolRiwayat extends StatelessWidget {
  const _TombolRiwayat({required this.workbook, required this.berlabel});

  final WorkbookRingkas workbook;
  final bool berlabel;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final n = workbook.jumlahRiwayat;
    void buka() => bukaRiwayatWorkbook(context, workbook);
    if (!berlabel) {
      return IconButton(
        key: const ValueKey('tombol-riwayat'),
        tooltip: l10n.workbookRiwayat(n),
        icon: Badge.count(count: n, child: const Icon(Icons.history)),
        onPressed: buka,
      );
    }
    return Tooltip(
      message: l10n.workbookRiwayatKet,
      child: TextButton.icon(
        key: const ValueKey('tombol-riwayat'),
        style: TextButton.styleFrom(
          foregroundColor: w.teks2,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: buka,
        icon: const Icon(Icons.history, size: 18),
        label: Text(l10n.workbookRiwayat(n)),
      ),
    );
  }
}

/// Spanduk di atas grid untuk versi RIWAYAT (K-49-13): bukan master aktif,
/// baca saja; menyebut pengganti bila server mengirimnya.
class _SpandukRiwayat extends StatelessWidget {
  const _SpandukRiwayat({required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final gaya = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: w.teks);
    final pengganti = workbook.digantikanOlehId;
    final versi = workbook.versi;
    return Tooltip(
      message: l10n.workbookRiwayatSpandukKet,
      child: Container(
        key: const ValueKey('spanduk-riwayat'),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
        decoration: BoxDecoration(
          color: w.awasTipis,
          border: Border(bottom: BorderSide(color: w.garis)),
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 16, color: w.awas),
            const SizedBox(width: UkuranStudio.j2),
            Flexible(
              child: Text(
                [
                  l10n.workbookRiwayatSpanduk,
                  if (versi != null) l10n.workbookImpor(versi),
                  if (pengganti != null) l10n.workbookDigantikanOleh(pengganti),
                ].join(' · '),
                key: const ValueKey('teks-spanduk-riwayat'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gaya?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── bilah rumus

/// Sel snapshot di dalam rentang terpakai lembar yang halamannya sudah
/// termuat; `null` bila kosong/belum termuat. Sel di LUAR rentang terpakai
/// (area kosong grid) tidak pernah menanyakan server.
SelWorkbook? _selPada(
  WidgetRef ref,
  int workbookId,
  LembarWorkbook lembar,
  AlamatSel a,
) {
  if (a.baris > lembar.jumlahBaris || a.kolom > lembar.jumlahKolom) {
    return null;
  }
  return ref
      .watch(
        halamanSelWorkbookProvider((
          workbookId: workbookId,
          lembarId: lembar.id,
          halaman: halamanUntukBaris(a.baris),
        )),
      )
      .value
      ?.pada(a.baris, a.kolom);
}

/// Isi sel seperti bilah rumus Excel: rumus bila ada, selain itu NILAI
/// tersimpan (bukan teks berformat) dalam bentuk bilah rumus Excel — 15 digit
/// signifikan ([teksBilahRumus]). Nilai persis 17 digit: inspektur.
String? _isiBilah(SelWorkbook? s) {
  if (s == null) return null;
  final n = s.nilai;
  return s.rumus ?? (n != null ? teksBilahRumus(n) : s.teks);
}

/// Isi untuk mulai mengedit sel [a] (F2, dobel ketuk, bilah rumus): edit
/// simulasi yang berlaku → sel hasil simulasi → sel snapshot. `null` =
/// halamannya belum termuat (edit tidak dimulai).
String? _isiUntukEdit(
  WidgetRef ref,
  int workbookId,
  LembarWorkbook lembar,
  AlamatSel a,
) {
  final sim = ref.read(simulasiWorkbookProvider(workbookId));
  final edit = sim.isiEdit(lembar.id, a);
  if (edit != null) return edit;
  final hasil = sim.overlayUntuk(lembar.id).pada(a.baris, a.kolom);
  if (hasil != null) return _isiBilah(hasil);
  if (a.baris > lembar.jumlahBaris || a.kolom > lembar.jumlahKolom) return '';
  final h = ref.read(
    halamanSelWorkbookProvider((
      workbookId: workbookId,
      lembarId: lembar.id,
      halaman: halamanUntukBaris(a.baris),
    )),
  );
  if (!h.hasValue) return null;
  return _isiBilah(h.requireValue.pada(a.baris, a.kolom)) ?? '';
}

/// Nilai persis untuk dibaca orang: representasi terpendek yang kembali ke
/// double YANG SAMA (`double.toString`) — tidak dibulatkan, tidak diformat
/// locale. `1.4452480055555562e-7` tetap begitu.
String nilaiPersis(num n) => n.toString();

/// Bilah rumus Excel: kotak nama, ✕ ✓ (peran yang boleh mengedit), fx, isi.
/// Mengetuk isinya = mulai edit sel aktif DI SINI; saat mengedit di sel,
/// isinya mengikuti ketikan (satu [KendaliGridSel.teksEdit]).
class _BilahRumus extends StatelessWidget {
  const _BilahRumus({
    required this.workbookId,
    required this.lembar,
    required this.kendali,
    required this.bolehEdit,
  });

  final int workbookId;
  final LembarWorkbook lembar;
  final KendaliGridSel kendali;
  final bool bolehEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final sentuh =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
    final sempit = MediaQuery.sizeOf(context).width < 760;
    final gayaMono = TipografiStudio.angka(ukuran: 12, warna: w.teks);

    return Container(
      height: sentuh ? 36 : 32,
      decoration: BoxDecoration(
        color: w.permukaan,
        border: Border(bottom: BorderSide(color: w.garis)),
      ),
      child: ListenableBuilder(
        listenable: kendali,
        builder: (context, _) {
          final aktif = kendali.aktif;
          final edit = kendali.sedangEdit;
          final diBilah = edit && kendali.tempatEdit == TempatEdit.bilah;

          final Widget isi;
          if (diBilah) {
            isi = MediaQuery.withNoTextScaling(
              child: TextField(
                key: const ValueKey('isian-bilah-rumus'),
                controller: kendali.teksEdit,
                focusNode: kendali.fokusBilah,
                style: gayaMono,
                maxLines: 1,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration.collapsed(hintText: null),
                onTapOutside: (_) {},
                onSubmitted: (_) => kendali.simpanEdit(arahBaris: 1),
              ),
            );
          } else if (edit) {
            // Mengedit di sel: bilah menampilkan ketikan yang sama.
            isi = ValueListenableBuilder<TextEditingValue>(
              valueListenable: kendali.teksEdit,
              builder: (context, v, _) => Text(
                v.text,
                key: const ValueKey('isi-bilah-rumus'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gayaMono,
              ),
            );
          } else {
            isi = Consumer(
              builder: (context, ref, _) {
                final edit = bolehEdit
                    ? ref.watch(
                        simulasiWorkbookProvider(
                          workbookId,
                        ).select((s) => s.isiEdit(lembar.id, aktif)),
                      )
                    : null;
                final hasil = ref
                    .watch(
                      overlayLembarProvider((
                        workbookId: workbookId,
                        lembarId: lembar.id,
                      )),
                    )
                    .pada(aktif.baris, aktif.kolom);
                final sel = hasil ?? _selPada(ref, workbookId, lembar, aktif);
                final angkaAtauRumus =
                    edit != null || sel?.rumus != null || sel?.nilai != null;
                return Text(
                  edit ?? _isiBilah(sel) ?? '',
                  key: const ValueKey('isi-bilah-rumus'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: angkaAtauRumus ? gayaMono : teks.bodyMedium,
                );
              },
            );
          }

          return Row(
            children: [
              Container(
                key: const ValueKey('kotak-nama'),
                width: sempit ? 72 : 96,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: UkuranStudio.j2,
                ),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: w.garis)),
                ),
                child: Text(
                  aktif.a1,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TipografiStudio.angka(ukuran: 12, warna: w.teks),
                ),
              ),
              if (bolehEdit) ...[
                // ✕ ✓ seperti Excel (aktif hanya saat mengedit) — di tablet
                // inilah "Esc"/"Enter"-nya.
                IconButton(
                  key: const ValueKey('tombol-batal-edit'),
                  tooltip: l10n.bilahBatalEdit,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: w.gagal,
                  icon: const Icon(Icons.close),
                  onPressed: edit ? kendali.batalEdit : null,
                ),
                IconButton(
                  key: const ValueKey('tombol-simpan-edit'),
                  tooltip: l10n.bilahSimpanEdit,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: w.lulus,
                  icon: const Icon(Icons.check),
                  onPressed: edit ? kendali.simpanEdit : null,
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UkuranStudio.j2,
                ),
                child: Text(
                  'fx',
                  style: teks.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: w.teksRedup,
                  ),
                ),
              ),
              Container(width: 1, color: w.garis),
              const SizedBox(width: UkuranStudio.j2),
              Expanded(
                // Isi selebar sisa bilah (teks terpotong elipsis di tepi
                // kanan layar), di tengah tinggi bilah.
                child: diBilah || !bolehEdit
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: double.infinity, child: isi),
                      )
                    : GestureDetector(
                        key: const ValueKey('ketuk-bilah-rumus'),
                        behavior: HitTestBehavior.opaque,
                        onTap: kendali.mulaiEditDiBilah,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.text,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(width: double.infinity, child: isi),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Urungkan / ulangi edit simulasi (untuk tablet tanpa keyboard; Ctrl+Z /
/// Ctrl+Y di grid sama).
class _TombolUrung extends ConsumerWidget {
  const _TombolUrung({required this.workbookId});

  final int workbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final p = simulasiWorkbookProvider(workbookId);
    final (urung, ulang) = ref.watch(
      p.select((s) => (s.bisaUrungkan, s.bisaUlangi)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('tombol-urungkan'),
          tooltip: l10n.simulasiUrungkan,
          icon: const Icon(Icons.undo),
          onPressed: urung ? () => ref.read(p.notifier).urungkan() : null,
        ),
        IconButton(
          key: const ValueKey('tombol-ulangi'),
          tooltip: l10n.simulasiUlangi,
          icon: const Icon(Icons.redo),
          onPressed: ulang ? () => ref.read(p.notifier).ulangi() : null,
        ),
      ],
    );
  }
}

/// Spanduk tipis di atas grid, HANYA bila ada edit: "Simulasi — tidak
/// disimpan", jumlah sel diubah, galat mesin hitung, Reset; bila kiriman
/// terakhir gagal (409/422/504/…): pesannya + "Batalkan edit terakhir"
/// (+ "Coba lagi" bila masuk akal).
class _SpandukSimulasi extends ConsumerWidget {
  const _SpandukSimulasi({required this.workbookId});

  final int workbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final p = simulasiWorkbookProvider(workbookId);
    final s = ref.watch(p);
    if (!s.adaEdit) return const SizedBox.shrink();
    final galat = s.galat;
    final cacat = s.hasil?.jumlahCacat ?? 0;
    final gayaKecil = teks.labelMedium?.copyWith(color: w.teks);

    String pesanGalat(GalatSimulasi g) => switch (g.jenis) {
      JenisGalatSimulasi.berkasAsliTidakAda => l10n.simulasiGalatBerkasAsli,
      JenisGalatSimulasi.perluSandi => l10n.simulasiGalatPerluSandi(
        '$workbookId',
      ),
      JenisGalatSimulasi.ditolak => l10n.simulasiGalatDitolak(g.pesan),
      JenisGalatSimulasi.terlaluLama => l10n.simulasiGalatLama,
      JenisGalatSimulasi.terlaluSering => l10n.simulasiGalatSering,
      JenisGalatSimulasi.dilarang => l10n.simulasiGalatDilarang,
      JenisGalatSimulasi.lain => l10n.simulasiGalatLain(g.pesan),
    };

    return Container(
      key: const ValueKey('spanduk-simulasi'),
      decoration: BoxDecoration(
        color: w.infoTipis,
        border: Border(bottom: BorderSide(color: w.garis)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 16, color: w.info),
                const SizedBox(width: UkuranStudio.j2),
                Flexible(
                  child: Text(
                    '${l10n.simulasiSpanduk} · '
                    '${l10n.simulasiJumlahEdit(s.edit.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gayaKecil?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (s.jumlahGalatHitung > 0) ...[
                  const SizedBox(width: UkuranStudio.j2),
                  Tooltip(
                    message: [
                      for (final g in s.hasil!.galat.take(8))
                        '${g.a}: ${g.pesan}',
                    ].join('\n'),
                    child: Text(
                      l10n.simulasiGalatHitung(s.jumlahGalatHitung),
                      key: const ValueKey('galat-hitung-sel'),
                      style: teks.labelMedium?.copyWith(color: w.gagal),
                    ),
                  ),
                ],
                if (cacat > 0) ...[
                  const SizedBox(width: UkuranStudio.j2),
                  Flexible(
                    child: Text(
                      l10n.kakiSelCacat(cacat),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: teks.labelMedium?.copyWith(color: w.awas),
                    ),
                  ),
                ],
                const Spacer(),
                Tooltip(
                  message: l10n.simulasiResetKet,
                  child: TextButton.icon(
                    key: const ValueKey('tombol-reset-simulasi'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => ref.read(p.notifier).reset(),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(l10n.simulasiReset),
                  ),
                ),
              ],
            ),
          ),
          if (galat != null)
            Padding(
              padding: const EdgeInsets.only(bottom: UkuranStudio.j1),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: w.gagal),
                  const SizedBox(width: UkuranStudio.j2),
                  Expanded(
                    child: Text(
                      pesanGalat(galat),
                      key: const ValueKey('galat-simulasi'),
                      style: teks.bodySmall?.copyWith(color: w.teks),
                    ),
                  ),
                  if (galat.bisaDiulang)
                    TextButton(
                      key: const ValueKey('tombol-hitung-ulang'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ref.read(p.notifier).hitungUlang(),
                      child: Text(l10n.cobaLagi),
                    ),
                  TextButton(
                    key: const ValueKey('tombol-batalkan-terakhir'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: s.bisaUrungkan
                        ? () => ref.read(p.notifier).urungkan()
                        : null,
                    child: Text(l10n.simulasiBatalkanTerakhir),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── area lembar

/// Grid + panel inspektur kanan. Area lebar ([lebarInspekturDorong]):
/// panel di samping grid. Sempit: panel menutupi grid dari kanan (geser
/// masuk/keluar), grid tidak menyempit.
class _AreaLembar extends StatefulWidget {
  const _AreaLembar({
    required this.terbuka,
    required this.panel,
    required this.child,
  });

  final bool terbuka;
  final Widget? panel;
  final Widget child;

  @override
  State<_AreaLembar> createState() => _AreaLembarState();
}

class _AreaLembarState extends State<_AreaLembar> {
  /// Panel tumpuk masih dibangun selama animasi tutupnya berjalan.
  bool _menutup = false;

  @override
  void didUpdateWidget(covariant _AreaLembar lama) {
    super.didUpdateWidget(lama);
    if (lama.terbuka && !widget.terbuka) _menutup = true;
  }

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final panel = widget.panel;
    return LayoutBuilder(
      builder: (context, batas) {
        if (panel == null) return widget.child;
        if (batas.maxWidth >= lebarInspekturDorong) {
          // Mode dorong tidak beranimasi: tidak ada "sedang menutup" yang
          // perlu ditunggu bila jendela nanti menyempit.
          _menutup = false;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.child),
              if (widget.terbuka) ...[
                VerticalDivider(width: 1, thickness: 1, color: w.garis),
                SizedBox(width: lebarPanelInspektur, child: panel),
              ],
            ],
          );
        }
        final lebar = batas.maxWidth * 0.86 < lebarPanelInspektur
            ? batas.maxWidth * 0.86
            : lebarPanelInspektur;
        final bangun = widget.terbuka || _menutup;
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: lebar,
              child: IgnorePointer(
                ignoring: !widget.terbuka,
                child: AnimatedSlide(
                  offset: widget.terbuka ? Offset.zero : const Offset(1, 0),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  onEnd: () {
                    if (_menutup && mounted) {
                      setState(() => _menutup = false);
                    }
                  },
                  child: bangun
                      ? Material(elevation: 8, color: w.permukaan, child: panel)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PanelInspektur extends StatelessWidget {
  const _PanelInspektur({
    required this.workbookId,
    required this.lembar,
    required this.kendali,
    required this.onTutup,
  });

  final int workbookId;
  final LembarWorkbook lembar;
  final KendaliGridSel kendali;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return ColoredBox(
      key: const ValueKey('panel-inspektur'),
      color: w.permukaan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: UkuranStudio.j4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: w.garis)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.workbookInspektur, style: teks.titleSmall),
                  ),
                ),
                IconButton(
                  key: const ValueKey('tutup-inspektur'),
                  tooltip: l10n.workbookTutupInspektur,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onTutup,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(UkuranStudio.j4),
              child: InspekturSelWorkbook(
                workbookId: workbookId,
                lembar: lembar,
                kendali: kendali,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── grid

class _LembarGrid extends ConsumerWidget {
  const _LembarGrid({
    super.key,
    required this.workbookId,
    required this.lembar,
    required this.tataLetak,
    required this.kendali,
    this.tiruGeneral = false,
    this.bolehEdit = false,
    this.onTekanLama,
  });

  final int workbookId;
  final LembarWorkbook lembar;
  final TataLetakGrid tataLetak;
  final KendaliGridSel kendali;

  /// Lihat [SelWorkbook.keGrid].
  final bool tiruGeneral;

  /// Sel bisa diedit (simulasi). `false` = grid baca-saja.
  final bool bolehEdit;
  final ValueChanged<AlamatSel>? onTekanLama;

  KunciHalamanSel _kunci(int halaman) =>
      (workbookId: workbookId, lembarId: lembar.id, halaman: halaman);

  KunciOverlayLembar get _kunciOverlay =>
      (workbookId: workbookId, lembarId: lembar.id);

  SelGrid? _dari(AsyncValue<HalamanSelWorkbook> h, int b, int k) {
    final isi = h.value;
    if (isi != null) return isi.selGrid(b, k, tiruGeneral: tiruGeneral);
    if (h.hasError) return SelGrid.gagal;
    return null;
  }

  /// Sel grid = sel snapshot (halaman barisnya) dengan simulasi di atasnya.
  /// Sel di luar rentang terpakai snapshot (edit di area kosong) tidak
  /// menanyakan halaman ke server.
  SelGrid? _sel(WidgetRef ref, int b, int k, {required bool tonton}) {
    final po = overlayLembarProvider(_kunciOverlay);
    final overlay = tonton ? ref.watch(po) : ref.read(po);
    final SelGrid? dasar;
    if (b <= lembar.jumlahBaris && k <= lembar.jumlahKolom) {
      final ph = halamanSelWorkbookProvider(_kunci(halamanUntukBaris(b)));
      dasar = _dari(tonton ? ref.watch(ph) : ref.read(ph), b, k);
    } else {
      dasar = SelGrid.kosong;
    }
    if (overlay.kosong) return dasar;
    return overlay.selGrid(b, k, dasar, tiruGeneral: tiruGeneral);
  }

  PenyuntingSelGrid _penyunting(WidgetRef ref, StudioL10n l10n) {
    final p = simulasiWorkbookProvider(workbookId);
    return PenyuntingSelGrid(
      isiUntukEdit: (r, a) => _isiUntukEdit(r, workbookId, lembar, a),
      simpan: (isi) {
        final diterima = ref.read(p.notifier).terapkan({
          for (final e in isi.entries) kunciEdit(lembar.id, e.key): e.value,
        });
        return diterima ? null : l10n.simulasiBatasEdit(batasEditSimulasi);
      },
      urungkan: () => ref.read(p.notifier).urungkan(),
      ulangi: () => ref.read(p.notifier).ulangi(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);

    if (lembar.jumlahBaris < 1 || lembar.jumlahKolom < 1) {
      return _Keadaan(ikon: Icons.grid_off_outlined, judul: l10n.lembarKosong);
    }

    // Halaman pertama menentukan keadaan lembar: gagal di sini = seluruh
    // lembar gagal (pesan + coba lagi), bukan grid penuh sel bertanda.
    final pertama = ref.watch(halamanSelWorkbookProvider(_kunci(0)));
    // Edit di luar rentang terpakai snapshot memperluas rentang grid.
    final (barisSim, kolomSim) = ref.watch(
      overlayLembarProvider(
        _kunciOverlay,
      ).select((o) => (o.barisMaks, o.kolomMaks)),
    );
    if (pertama.hasError && !pertama.hasValue) {
      return _Keadaan(
        ikon: Icons.cloud_off_outlined,
        judul: l10n.lembarGagalMuat,
        aksi: FilledButton.icon(
          onPressed: () => ref.invalidate(halamanSelWorkbookProvider),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.cobaLagi),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 2,
          child: pertama.isLoading
              ? LinearProgressIndicator(semanticsLabel: l10n.memuat)
              : null,
        ),
        _PeringatanCacat(
          workbookId: workbookId,
          lembarId: lembar.id,
          kendali: kendali,
        ),
        Expanded(
          child: GridSel(
            key: ValueKey('grid-${lembar.id}'),
            jumlahBaris: math.max(lembar.jumlahBaris, barisSim),
            jumlahKolom: math.max(lembar.jumlahKolom, kolomSim),
            tataLetak: tataLetak,
            kendali: kendali,
            fokusOtomatis: true,
            labelSemantik: lembar.nama,
            onTekanLama: onTekanLama,
            penyunting: bolehEdit ? _penyunting(ref, l10n) : null,
            gambar: [
              for (final g in lembar.gambar)
                GambarGrid(
                  kunci: g.id,
                  kolom: g.kolom,
                  baris: g.baris,
                  dx: g.dx,
                  dy: g.dy,
                  lebar: g.lebar,
                  tinggi: g.tinggi,
                  isi: _GambarLembar(workbookId: workbookId, gambar: g),
                ),
            ],
            selTonton: (ref, b, k) => _sel(ref, b, k, tonton: true),
            selBaca: (ref, b, k) => _sel(ref, b, k, tonton: false),
            siapkanRentang: (ref, r) async {
              // Didengarkan selama ditunggu supaya halaman yang baru ditarik
              // ikut jeda simpan biasa, bukan menetap tanpa pendengar.
              final langganan = <ProviderSubscription<Object?>>[];
              try {
                // Halaman di luar rentang terpakai snapshot tidak ditarik.
                final akhir = math.min(r.barisAkhir, lembar.jumlahBaris);
                for (
                  var h = halamanUntukBaris(r.barisAwal);
                  h <= halamanUntukBaris(akhir);
                  h++
                ) {
                  final p = halamanSelWorkbookProvider(_kunci(h));
                  langganan.add(ref.listenManual(p, (_, _) {}));
                  await ref.read(p.future);
                }
              } finally {
                for (final l in langganan) {
                  l.close();
                }
              }
            },
          ),
        ),
        Container(height: 1, color: w.garis),
      ],
    );
  }
}

/// Sel yang dikirim server tapi tidak terbaca klien ini — disebut, bukan
/// disembunyikan (halaman pertama + halaman sel aktif).
class _PeringatanCacat extends StatelessWidget {
  const _PeringatanCacat({
    required this.workbookId,
    required this.lembarId,
    required this.kendali,
  });

  final int workbookId;
  final int lembarId;
  final KendaliGridSel kendali;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kendali,
      builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final halaman = {0, halamanUntukBaris(kendali.aktif.baris)};
          var cacat = 0;
          for (final h in halaman) {
            final p = halamanSelWorkbookProvider((
              workbookId: workbookId,
              lembarId: lembarId,
              halaman: h,
            ));
            // Halaman sel aktif di luar rentang terpakai tidak ditarik
            // hanya untuk menghitung sel cacat.
            if (h != 0 && !ref.exists(p)) continue;
            cacat += ref.watch(p).value?.jumlahCacat ?? 0;
          }
          if (cacat == 0) return const SizedBox.shrink();
          final w = WarnaStudio.of(context);
          return Container(
            key: const ValueKey('peringatan-sel-cacat'),
            color: w.awasTipis,
            padding: const EdgeInsets.symmetric(
              horizontal: UkuranStudio.j3,
              vertical: UkuranStudio.j1,
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined, size: 16, color: w.awas),
                const SizedBox(width: UkuranStudio.j2),
                Expanded(
                  child: Text(
                    StudioL10n.of(context).kakiSelCacat(cacat),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: w.teks),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── dikecualikan

/// Lembar yang `dikecualikan` = `true`: isinya tidak diimpor — yang tampil
/// penanda ke tabel pengelolanya, bukan grid kosong yang bisa disangka
/// lembar kosong. Sejak K-49-12 lembar DATABASE/SERTIFIKAT biasanya BERISI
/// dan tampil sebagai grid biasa (dengan chip "juga di tabel …").
class PanelLembarDikecualikan extends StatelessWidget {
  const PanelLembarDikecualikan({super.key, required this.lembar});

  final LembarWorkbook lembar;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final tabel = lembar.tautanTabel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(UkuranStudio.j6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 28, color: w.info),
                  const SizedBox(height: UkuranStudio.j3),
                  Text(
                    tabel == null
                        ? l10n.lembarDikecualikanTanpaTautan
                        : l10n.lembarDikecualikanJudul(tabel),
                    style: teks.titleMedium,
                  ),
                  if (lembar.alasanDikecualikan != null) ...[
                    const SizedBox(height: UkuranStudio.j2),
                    Text(lembar.alasanDikecualikan!, style: teks.bodyMedium),
                  ],
                  const SizedBox(height: UkuranStudio.j2),
                  Text(l10n.lembarDikecualikanKet, style: teks.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── inspektur

/// Inspektur sel aktif: alamat, tipe, NILAI PERSIS, teks tampil, rumus,
/// format angka, gaya. Isi panel kanan ([_PanelInspektur]).
class InspekturSelWorkbook extends StatelessWidget {
  const InspekturSelWorkbook({
    super.key,
    required this.workbookId,
    required this.lembar,
    required this.kendali,
  });

  final int workbookId;
  final LembarWorkbook lembar;
  final KendaliGridSel kendali;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: kendali,
      builder: (context, _) {
        final aktif = kendali.aktif;
        final gabungan = lembar.tataLetak.merge
            .where((m) => m.memuat(aktif.baris, aktif.kolom))
            .firstOrNull;
        final diLuar =
            aktif.baris > lembar.jumlahBaris ||
            aktif.kolom > lembar.jumlahKolom;

        return Consumer(
          builder: (context, ref, _) {
            final AsyncValue<HalamanSelWorkbook>? halaman = diLuar
                ? null
                : ref.watch(
                    halamanSelWorkbookProvider((
                      workbookId: workbookId,
                      lembarId: lembar.id,
                      halaman: halamanUntukBaris(aktif.baris),
                    )),
                  );
            // Simulasi: sel hasil hitung server menimpa sel snapshot.
            final overlay = ref.watch(
              overlayLembarProvider((
                workbookId: workbookId,
                lembarId: lembar.id,
              )),
            );
            final hasil = overlay.pada(aktif.baris, aktif.kolom);
            final isiSimulasi = ref.watch(
              simulasiWorkbookProvider(
                workbookId,
              ).select((s) => s.isiEdit(lembar.id, aktif)),
            );
            final galatHitung =
                overlay.galat[kunciSel(aktif.baris, aktif.kolom)];
            final termuat =
                hasil != null || halaman == null || halaman.hasValue;
            final sel = hasil ?? halaman?.value?.pada(aktif.baris, aktif.kolom);
            final nilai = sel?.nilai;
            const kosong = '—';

            String tipe(SelWorkbook? s) => switch (s?.tipe) {
              null || TipeSel.kosong => l10n.tipeKosong,
              TipeSel.angka => l10n.tipeAngka,
              TipeSel.teks => l10n.tipeTeks,
              TipeSel.logika => l10n.tipeLogika,
              TipeSel.galat => l10n.tipeGalat,
              TipeSel.rumus => l10n.tipeRumus,
            };

            final g = sel?.gaya;
            final gaya = g == null || g.kosong
                ? kosong
                : [
                    if (g.tebal) l10n.gayaTebal,
                    if (g.miring) l10n.gayaMiring,
                    if (g.isi != null) l10n.gayaIsi(_hex(g.isi!)),
                    if (g.teks != null) l10n.gayaWarnaTeks(_hex(g.teks!)),
                    if (g.rata != null) l10n.gayaRata(g.rata!),
                    if (g.vertikalMentah != null)
                      l10n.gayaVertikal(g.vertikalMentah!),
                    if (g.bungkus) l10n.gayaBungkus,
                    if (g.font != null) l10n.gayaFont(g.font!),
                    if (g.ukuran != null)
                      l10n.gayaUkuran(nilaiPersis(g.ukuran!)),
                    if (g.garis.ada) l10n.gayaGaris,
                  ].join(' · ');

            return Column(
              key: const ValueKey('inspektur-sel'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BarisInspektur(
                  label: l10n.inspekturAlamat,
                  nilai: '${lembar.nama}!${aktif.a1}',
                  mono: true,
                ),
                if (gabungan != null)
                  _BarisInspektur(
                    label: l10n.inspekturGabungan,
                    nilai: gabungan.a1,
                    mono: true,
                  ),
                if (isiSimulasi != null)
                  _BarisInspektur(
                    kunci: const ValueKey('inspektur-simulasi'),
                    label: l10n.inspekturSimulasi,
                    nilai: isiSimulasi.isEmpty ? kosong : isiSimulasi,
                    mono: true,
                  ),
                if (galatHitung != null)
                  _BarisInspektur(
                    kunci: const ValueKey('inspektur-galat-hitung'),
                    label: l10n.inspekturGalatHitung,
                    nilai: galatHitung,
                  ),
                if (!termuat)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UkuranStudio.j2,
                    ),
                    child: halaman.hasError
                        ? Text(l10n.lembarGagalMuat, style: teks.bodySmall)
                        : LinearProgressIndicator(semanticsLabel: l10n.memuat),
                  )
                else ...[
                  _BarisInspektur(label: l10n.inspekturTipe, nilai: tipe(sel)),
                  _BarisInspektur(
                    kunci: const ValueKey('inspektur-nilai'),
                    label: l10n.inspekturNilai,
                    nilai: nilai == null ? kosong : nilaiPersis(nilai),
                    mono: true,
                  ),
                  _BarisInspektur(
                    kunci: const ValueKey('inspektur-teks'),
                    label: l10n.inspekturTeks,
                    nilai: sel == null || sel.teks.isEmpty ? kosong : sel.teks,
                  ),
                  _BarisInspektur(
                    kunci: const ValueKey('inspektur-rumus'),
                    label: l10n.inspekturRumus,
                    nilai: sel?.rumus ?? kosong,
                    mono: true,
                  ),
                  _BarisInspektur(
                    label: l10n.inspekturFormat,
                    nilai: sel?.formatAngka ?? kosong,
                    mono: true,
                  ),
                  _BarisInspektur(label: l10n.inspekturGaya, nilai: gaya),
                ],
                const SizedBox(height: UkuranStudio.j3),
                Text(
                  l10n.inspekturKet,
                  style: teks.bodySmall?.copyWith(color: w.teksRedup),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _BarisInspektur extends StatelessWidget {
  const _BarisInspektur({
    required this.label,
    required this.nilai,
    this.mono = false,
    this.kunci,
  });

  final String label;
  final String nilai;
  final bool mono;
  final Key? kunci;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: UkuranStudio.j2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: teks.labelSmall),
          const SizedBox(height: 2),
          SelectableText(
            nilai,
            key: kunci,
            style: mono
                ? TipografiStudio.angka(ukuran: 13, warna: w.teks)
                : teks.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── tab lembar

/// Tab lembar di BAWAH grid, seperti Excel. Satu-satunya daftar mendatar di
/// layar workbook (uji E2E bergantung pada itu).
class _TabLembar extends StatelessWidget {
  const _TabLembar({
    required this.lembar,
    required this.indeks,
    required this.onPilih,
    required this.onMenu,
  });

  /// Lembar yang tampil di tab: (indeks di workbook, lembar). Lembar
  /// tersembunyi tidak ada di sini sampai ditampilkan lewat [onMenu].
  final List<(int, LembarWorkbook)> lembar;
  final int indeks;
  final ValueChanged<int> onPilih;

  /// Klik kanan / tekan lama di bilah tab (posisi global).
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final sentuh =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;

    return GestureDetector(
      key: const ValueKey('bilah-tab-lembar'),
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (d) => onMenu(d.globalPosition),
      onLongPressStart: (d) => onMenu(d.globalPosition),
      child: Container(
        height: sentuh ? 40 : 30,
        decoration: BoxDecoration(
          color: w.permukaanRendah,
          border: Border(top: BorderSide(color: w.garisKuat)),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: UkuranStudio.j2),
          children: [
            for (final (i, l) in lembar)
              _Tab(
                key: ValueKey('tab-lembar-${l.id}'),
                lembar: l,
                terpilih: i == indeks,
                onTap: () => onPilih(i),
                tooltip: switch (l) {
                  LembarWorkbook(dikecualikan: true) =>
                    l10n.lembarDikecualikanTab,
                  LembarWorkbook(
                    tersembunyi: KetersembunyianLembar.veryHidden,
                  ) =>
                    l10n.lembarSangatTersembunyi,
                  LembarWorkbook(tersembunyi: KetersembunyianLembar.hidden) =>
                    l10n.lembarTersembunyi,
                  LembarWorkbook(:final tautanTabel?) => l10n.lembarJugaDiTabel(
                    tautanTabel,
                  ),
                  _ => null,
                },
                gaya: teks.labelMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.lembar,
    required this.terpilih,
    required this.onTap,
    required this.tooltip,
    required this.gaya,
  });

  final LembarWorkbook lembar;
  final bool terpilih;
  final VoidCallback onTap;
  final String? tooltip;
  final TextStyle? gaya;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final tersembunyi = lembar.tersembunyi != KetersembunyianLembar.tidak;
    final ikon = lembar.dikecualikan
        ? Icons.shield_outlined
        : (tersembunyi
              ? Icons.visibility_off_outlined
              : (lembar.tautanTabel != null ? Icons.link : null));

    Widget tab = Semantics(
      button: true,
      selected: terpilih,
      label: tooltip == null ? null : '${lembar.nama}. $tooltip',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
          decoration: BoxDecoration(
            // Tab aktif menyatu dengan lembar di atasnya (putih, tanpa garis
            // atas), seperti Excel; garis aksen di bawah namanya.
            color: terpilih ? w.permukaan : null,
            border: Border(
              bottom: BorderSide(
                color: terpilih ? w.aksen : Colors.transparent,
                width: 2,
              ),
              right: BorderSide(color: w.garis),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[
                Icon(ikon, size: 14, color: w.teksRedup),
                const SizedBox(width: 4),
              ],
              Text(
                lembar.nama,
                style: gaya?.copyWith(
                  color: terpilih ? w.teks : w.teks2,
                  fontWeight: terpilih ? FontWeight.w600 : FontWeight.w500,
                  fontStyle: tersembunyi ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Sentuh: tekan lama = menu tab (seperti Excel), bukan tooltip. Mouse
    // tetap memunculkan tooltip saat hover (triggerMode tidak berlaku untuk
    // mouse).
    if (tooltip != null) {
      tab = Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.manual,
        child: tab,
      );
    }
    return tab;
  }
}

// ─────────────────────────────────────────────────────────────── kaki

/// Bilah status di paling bawah, seperti Excel: jumlah sel & rumus, sumber,
/// penanda (lebar perkiraan, tautan tabel), pilihan, lalu zoom di kanan.
class _Kaki extends StatelessWidget {
  const _Kaki({required this.workbook, required this.lembar, this.kendali});

  final WorkbookRingkas workbook;
  final LembarWorkbook? lembar;
  final KendaliGridSel? kendali;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final gaya = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: w.teks2);
    final sentuh =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
    final lebar = MediaQuery.sizeOf(context).width;
    final sha = workbook.sha256;
    final shaPendek = sha.length > 12 ? sha.substring(0, 12) : sha;
    final sumber = switch (workbook.sumber) {
      SumberWorkbook.csv => 'CSV',
      SumberWorkbook.xlsm => 'XLSM',
      SumberWorkbook.lain => workbook.sumberMentah,
    };
    final l = lembar;
    final k = kendali;
    final tabel = l?.tautanTabel;

    Widget pemisah() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j2),
      child: Text('·', style: gaya),
    );

    return Container(
      height: sentuh ? 36 : 28,
      padding: const EdgeInsets.only(left: UkuranStudio.j3),
      decoration: BoxDecoration(
        color: w.permukaan,
        border: Border(top: BorderSide(color: w.garis)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (l != null && !l.dikecualikan)
                  Text(
                    l10n.kakiSel(l.jumlahSel, l.jumlahRumus),
                    key: const ValueKey('kaki-sel'),
                    style: gaya,
                  ),
                if (lebar >= 760) ...[
                  if (l != null && !l.dikecualikan) pemisah(),
                  Text(l10n.kakiSumber(sumber), style: gaya),
                  pemisah(),
                  Tooltip(
                    message: sha,
                    child: GestureDetector(
                      onLongPress: () =>
                          Clipboard.setData(ClipboardData(text: sha)),
                      child: Text(
                        'sha256 $shaPendek',
                        style: TipografiStudio.angka(
                          ukuran: 11,
                          warna: w.teks2,
                        ),
                      ),
                    ),
                  ),
                ],
                if (l != null && l.tataLetak.lebarPerkiraan) ...[
                  const SizedBox(width: UkuranStudio.j2),
                  _Chip(
                    kunci: const ValueKey('chip-lebar-perkiraan'),
                    ikon: Icons.straighten,
                    teks: l10n.kakiLebarPerkiraan,
                    keterangan: l10n.kakiLebarPerkiraanKet,
                  ),
                ],
                if (l != null && !l.dikecualikan && tabel != null) ...[
                  const SizedBox(width: UkuranStudio.j2),
                  Flexible(
                    child: _Chip(
                      kunci: const ValueKey('chip-tautan-tabel'),
                      ikon: Icons.link,
                      teks: l10n.lembarJugaDiTabel(tabel),
                      keterangan: l10n.lembarJugaDiTabelKet(tabel),
                    ),
                  ),
                ],
                if (k != null) ...[
                  const SizedBox(width: UkuranStudio.j2),
                  Flexible(
                    child: ListenableBuilder(
                      listenable: k,
                      builder: (context, _) => k.rentang.tunggal
                          ? const SizedBox.shrink()
                          : Text(
                              l10n.kakiPilihan(
                                k.rentang.a1,
                                k.rentang.jumlahSel,
                              ),
                              key: const ValueKey('kaki-pilihan'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: gaya,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _StatusHitung(workbookId: workbook.id),
          if (k != null) _KendaliZoom(kendali: k),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.kunci,
    required this.ikon,
    required this.teks,
    required this.keterangan,
  });

  final Key kunci;
  final IconData ikon;
  final String teks;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Tooltip(
      message: keterangan,
      child: Container(
        key: kunci,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: w.infoTipis,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 12, color: w.info),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                teks,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: w.info),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zoom di kanan bilah status, seperti Excel: −, persen (menu pilihan +
/// "pas lebar"), +.
class _KendaliZoom extends StatelessWidget {
  const _KendaliZoom({required this.kendali});

  final KendaliGridSel kendali;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final gaya = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: w.teks2);
    return ListenableBuilder(
      listenable: kendali,
      builder: (context, _) {
        final z = kendali.zoom;
        final persen = '${(z * 100).round()}%';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('zoom-perkecil'),
              tooltip: l10n.zoomPerkecil,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              icon: const Icon(Icons.remove),
              onPressed: z > KendaliGridSel.zoomMin
                  ? () => kendali.aturZoom(langkahZoom(kendali.zoom, -1))
                  : null,
            ),
            PopupMenuButton<double>(
              key: const ValueKey('zoom-nilai'),
              tooltip: l10n.zoomPilih,
              initialValue: z,
              onSelected: (v) =>
                  v <= 0 ? kendali.pasLebar() : kendali.aturZoom(v),
              itemBuilder: (_) => [
                for (final p in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(value: p, child: Text('${(p * 100).round()}%')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  key: const ValueKey('zoom-pas-lebar'),
                  value: 0,
                  child: Text(l10n.zoomPasLebar),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 40,
                  child: Text(
                    persen,
                    key: const ValueKey('zoom-persen'),
                    textAlign: TextAlign.center,
                    style: gaya,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('zoom-perbesar'),
              tooltip: l10n.zoomPerbesar,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              icon: const Icon(Icons.add),
              onPressed: z < KendaliGridSel.zoomMaks
                  ? () => kendali.aturZoom(langkahZoom(kendali.zoom, 1))
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _Keadaan extends StatelessWidget {
  const _Keadaan({required this.ikon, required this.judul, this.aksi});

  final IconData ikon;
  final String judul;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 36, color: w.teksRedup),
            const SizedBox(height: UkuranStudio.j3),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (aksi != null) ...[
              const SizedBox(height: UkuranStudio.j4),
              aksi!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── gambar

/// Isi satu gambar lembar: png/jpeg ditarik dengan header auth yang sama
/// (`gambarWorkbookProvider`, cache memori) dan direntang ke kotak jangkarnya
/// seperti Excel; jenis lain (EMF/WMF/…) = kotak abu tipis berlabel jenisnya.
class _GambarLembar extends ConsumerWidget {
  const _GambarLembar({required this.workbookId, required this.gambar});

  final int workbookId;
  final GambarLembar gambar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    if (!gambar.jenis.bisaDigambar) {
      final jenis = gambar.jenisMentah.trim();
      return _KotakGambar(label: jenis.isEmpty ? '?' : jenis.toUpperCase());
    }
    final byte = ref.watch(
      gambarWorkbookProvider((workbookId: workbookId, gambarId: gambar.id)),
    );
    return switch (byte) {
      AsyncData(value: final b?) => Image.memory(
        b,
        key: const ValueKey('gambar-png-jpeg'),
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _KotakGambar(label: l10n.gambarGagalMuat),
      ),
      AsyncData() || AsyncError() => _KotakGambar(label: l10n.gambarGagalMuat),
      _ => const SizedBox.expand(),
    };
  }
}

class _KotakGambar extends StatelessWidget {
  const _KotakGambar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Container(
      key: const ValueKey('kotak-gambar'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: w.permukaanRendah.withValues(alpha: 0.6),
        border: Border.all(color: w.garisKuat),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: 10, color: w.teksRedup),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── tampilkan

/// "Unhide" Excel: daftar lembar tersembunyi; memilih satu = tampilkan &
/// buka. Tampilan saja — tidak disimpan ke workbook. Lembar `veryHidden`
/// (di Excel cuma lewat VBA) ikut didaftar dengan tandanya supaya isinya
/// tetap bisa diperiksa di Studio.
class _DialogTampilkanLembar extends StatelessWidget {
  const _DialogTampilkanLembar({required this.lembar});

  /// (indeks di workbook, lembar).
  final List<(int, LembarWorkbook)> lembar;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final teks = Theme.of(context).textTheme;
    return SimpleDialog(
      key: const ValueKey('dialog-tampilkan-lembar'),
      title: Text(l10n.lembarTampilkanJudul),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j6),
          child: Text(l10n.lembarTampilkanKet, style: teks.bodySmall),
        ),
        const SizedBox(height: UkuranStudio.j2),
        for (final (i, l) in lembar)
          SimpleDialogOption(
            key: ValueKey('pilih-lembar-${l.id}'),
            onPressed: () => Navigator.of(context).pop(i),
            child: Text(
              l.tersembunyi == KetersembunyianLembar.veryHidden
                  ? '${l.nama}  (${l10n.lembarSangatTersembunyi})'
                  : l.nama,
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: UkuranStudio.j4),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Menghitung…" di bilah status selama `/hitung` ditunggu.
class _StatusHitung extends ConsumerWidget {
  const _StatusHitung({required this.workbookId});

  final int workbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menghitung = ref.watch(
      simulasiWorkbookProvider(workbookId).select((s) => s.menghitung),
    );
    if (!menghitung) return const SizedBox.shrink();
    final w = WarnaStudio.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: UkuranStudio.j2),
      child: Row(
        key: const ValueKey('status-menghitung'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: w.info),
          ),
          const SizedBox(width: 6),
          Text(
            StudioL10n.of(context).simulasiMenghitung,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: w.teks2),
          ),
        ],
      ),
    );
  }
}
