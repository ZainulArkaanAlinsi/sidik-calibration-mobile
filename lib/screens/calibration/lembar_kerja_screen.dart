import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/lembar_kerja.dart';
import '../../models/room.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/lembar_kerja_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/sidik_loader.dart';
import 'lembar_kerja_state.dart';
import 'widgets/dropdown_gagal.dart';
import 'widgets/lembar_kerja_tabel.dart';

/// Lembar Kerja (SIDIK-FM-CAL-0509_Rev.4) — layar input teknisi, dipakai buat
/// alat yang punya bentuk lembar sendiri (pH Meter, Turbidimeter, ...). Bentuk
/// per jenis alat ditentuin [profil] → `?profil=` di endpoint.
///
/// **Kolomnya digambar dari `GET /api/calibrations/lembar-kerja`, bukan
/// di-hardcode.** Backend yang punya definisi formulirnya, dan responsnya udah
/// disaring per-role: waktu yang login teknisi, kolom administratif (Order
/// Number, Calibration Methode, Thermohygro used) nggak ikut terkirim sama
/// sekali — jadi layar ini nggak mungkin nampilin kolom yang bukan haknya,
/// bahkan kalau ada bug di sisi tampilan.
///
/// **Tombol kirim nggak pernah dikunci.** Satu-satunya yang ditahan itu alat
/// belum dipilih — tanpa itu nggak ada yang bisa dikirim sama sekali. Sisanya
/// boleh kosong: teknisi di lapangan sering ketemu kondisi yang bikin satu-dua
/// kolom nggak bisa diisi, dan nahan tombol di situ bikin data hilang
/// seluruhnya. Penjagaannya ada di pemeriksaan admin sebelum sertifikat
/// terbit, bukan di formulir ini.
///
/// **Nggak ada satu pun rumus di sini.** Average, Correction, STDEV, U95% —
/// semua dihitung backend. Ikut ngitung di layar cepat atau lambat bikin
/// angkanya beda dari sertifikat.
class LembarKerjaScreen extends ConsumerStatefulWidget {
  const LembarKerjaScreen({
    super.key,
    this.sesiId,
    this.judulTambahan,
    this.profil = 'ph_meter',
  });

  /// Keisi = lanjut draft / perbaiki sesi yang dikembalikan admin (`PUT`).
  /// Null = sesi baru (`POST`).
  final int? sesiId;

  final String? judulTambahan;

  /// Kode jenis alat (`ph_meter` / `turbidimeter` / `chlorine_meter`) —
  /// nentuin bentuk lembar kerja yang diambil dari backend.
  final String profil;

  @override
  ConsumerState<LembarKerjaScreen> createState() => _LembarKerjaScreenState();
}

class _LembarKerjaScreenState extends ConsumerState<LembarKerjaScreen> {
  /// Berapa kotak pengulangan yang digambar. `null` = bawaan profilnya (5,
  /// ngikut form kertas) — teknisi yang nggak peduli nggak perlu milih apa-apa.
  int? _pengulangan;

  /// Ganti jumlah kotak = bentuk formulirnya beda = tabelnya dibangun ulang,
  /// dan isian yang udah diketik ilang.
  ///
  /// Dikonfirmasi dulu, bukan dikerjain diam-diam. Teknisi yang udah ngisi tiga
  /// titik terus nggak sengaja nyenggol menu ini nggak punya cara ngembaliin
  /// isiannya — nggak ada undo di layar ini.
  Future<void> _ubahPengulangan(int pilihan) async {
    final l10n = AppLocalizations.of(context);
    if (pilihan == (_pengulangan ?? 5)) return;

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.lkUbahPengulanganJudul),
        content: Text(l10n.lkUbahPengulanganPesan(pilihan)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.lkPengulanganBatal),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.lkUbahPengulanganLanjut),
          ),
        ],
      ),
    );

    if (lanjut == true && mounted) setState(() => _pengulangan = pilihan);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kunci = (profil: widget.profil, pengulangan: _pengulangan);
    final bentukAsync = ref.watch(lembarKerjaProvider(kunci));
    final terpakai = bentukAsync.value?.jumlahPengulangan ?? _pengulangan ?? 5;

    return Scaffold(
      appBar: AppBar(
        // Tombol back-nya bawaan AppBar — tiap halaman wajib punya
        // (spesifikasi poin 5).
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.lkTitle),
            if (widget.judulTambahan != null)
              Text(
                widget.judulTambahan!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            tooltip: l10n.lkPengulanganTooltip,
            onSelected: _ubahPengulangan,
            itemBuilder: (_) => [
              for (var n = 2; n <= 10; n++)
                PopupMenuItem(
                  value: n,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: n == terpakai
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                      // `Expanded`, bukan `Text` telanjang: lebar popup-nya
                      // dibatasi, dan tanpa ini barisnya meluber di locale yang
                      // labelnya lebih panjang.
                      Expanded(child: Text(l10n.lkPengulanganPilihan(n))),
                    ],
                  ),
                ),
            ],
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  l10n.lkPengulanganRingkas(terpakai),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (bentukAsync) {
        // `ValueKey` WAJIB: `_FormState` bikin `LembarKerjaState`-nya sekali
        // (`late final`) dari `widget.bentuk`. Tanpa key, Flutter mendaur ulang
        // State yang lama waktu jumlah kotaknya ganti — tabelnya bakal tetap
        // 5 kolom padahal backend udah ngirim 3, dan nggak ada yang error.
        AsyncData(:final value) => _Form(
          key: ValueKey(value.jumlahPengulangan),
          bentuk: value,
          sesiId: widget.sesiId,
        ),
        AsyncError(:final error) => _Gagal(
          error: error,
          onCobaLagi: () => ref.invalidate(lembarKerjaProvider(kunci)),
        ),
        _ => const Center(child: SidikLoader(size: 88)),
      },
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi, this.error});

  final VoidCallback onCobaLagi;

  /// Error mentah dari provider. Ditampilin apa adanya (kecil, di bawah) —
  /// biar di lapangan bisa dibedain "backend nggak kejangkau" (mis. Connection
  /// refused / SocketException) dari "bentuk data salah" (parse error), tanpa
  /// harus colok laptop buat baca log.
  final Object? error;

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
          l10n.lkLoadGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.lkRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.bentuk, this.sesiId});

  final LembarKerja bentuk;
  final int? sesiId;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final LembarKerjaState _isian = LembarKerjaState(
    bentuk: widget.bentuk,
    // Dibikin SEKALI waktu layar kebuka, bukan tiap tap tombol: kalau sinyal
    // putus pas nunggu respons dan teknisi nekan kirim lagi, backend ngenalin
    // ini submission yang sama dan balikin sesi yang udah ada — bukan bikin
    // sesi dobel buat satu kejadian kalibrasi.
    clientRequestId: generateUuidV4(),
  );

  /// Di atas lebar ini lembar kerjanya digambar dua kolom bersebelahan, persis
  /// kertasnya. Angkanya dari kebutuhan isi, bukan merek perangkat: dua kolom
  /// formulir + tabel 5 pengulangan butuh ruang segini biar kotaknya nggak
  /// mepet. Jendela desktop yang dikecilin balik ke mode halaman.
  static const _lebarDuaKolom = 1100.0;

  bool _mengirim = false;

  /// Index ke [LembarKerja.halaman], bukan nomor halamannya sendiri — lembar
  /// kerja alat lain bisa punya penomoran yang beda.
  int _halaman = 0;

  @override
  void initState() {
    super.initState();

    final id = widget.sesiId;
    if (id != null) _muatSesiLama(id);
  }

  /// Isi ulang formulir dari sesi yang dibuka lagi (lanjut draft / perbaiki
  /// yang dikembalikan admin).
  ///
  /// Gagalnya sengaja didiemin: formulirnya tetap kebuka dan tetap bisa diisi
  /// manual. Nampilin error di sini malah nutup jalan kerja teknisi cuma
  /// gara-gara satu permintaan meleset.
  Future<void> _muatSesiLama(int id) async {
    try {
      final detail = await ref.read(calibrationDetailProvider(id).future);
      final isi = detail.isianTeknisi;
      if (isi == null || !mounted) return;

      setState(() => _isian.muatDariSesi(isi));
    } catch (_) {
      // Lihat docblock.
    }
  }

  @override
  void dispose() {
    _isian.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool draft}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Satu-satunya yang ditahan: alat belum dipilih. Tanpa itu nggak ada yang
    // bisa dikirim sama sekali — bukan "kolom wajib", tapi identitas barangnya.
    if (_isian.alat == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.lkBelumPilihAlat)));
      return;
    }

    setState(() => _mengirim = true);

    final hasil = await ref
        .read(kirimLembarKerjaProvider.notifier)
        .kirim(_isian.toSubmission(draft: draft), sesiId: widget.sesiId);

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (hasil == null) {
      final error = ref.read(kirimLembarKerjaProvider).error;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.lkGagalKirim('$error'))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasil.draft ? l10n.lkBerhasilDraft : l10n.lkBerhasilKirim,
        ),
      ),
    );
    navigator.pop(hasil.id);
  }

  Future<bool> _bolehKeluar() async {
    if (!_isian.adaIsian || _mengirim) return true;

    final l10n = AppLocalizations.of(context);

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lkKeluarTanpaSimpan),
        content: Text(l10n.lkKeluarTanpaSimpanBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.lkKeluarBatal),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lkKeluarLanjut),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bentuk = widget.bentuk;

    // Diambil sebelum `await` — sesudahnya `context` punya build ini udah
    // nggak dijamin kepasang lagi.
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _bolehKeluar() && mounted) navigator.pop();
      },
      // `LayoutBuilder` membungkus ISI **dan** bilah tombol. Sempat kebalik —
      // cuma isinya yang dibungkus — dan bilah tombolnya kebangun duluan waktu
      // `_duaKolom` masih false, jadi tombol "halaman berikutnya" tetap nongol
      // di layar lebar yang nggak punya halaman berikutnya.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Di layar lebar, kertasnya digambar apa adanya: identitas & standar
          // di kiri, hasil kalibrasi di kanan, satu layar. Di HP itu mustahil
          // kebaca, jadi kolomnya jadi halaman.
          final duaKolom =
              constraints.maxWidth >= _lebarDuaKolom &&
              bentuk.halaman.length == 2;

          return Column(
            children: [
              Expanded(
                child: duaKolom
                    ? _LembarDuaKolom(
                        bentuk: bentuk,
                        isian: _isian,
                        onBerubah: () => setState(() {}),
                      )
                    : _LembarSatuKolom(
                        bentuk: bentuk,
                        isian: _isian,
                        halaman: _halaman,
                        onBerubah: () => setState(() {}),
                      ),
              ),

              // Tombolnya nempel di bawah, bukan ikut ke-scroll: lembar kerjanya
              // panjang, dan teknisi nggak boleh perlu scroll sampai ujung cuma
              // buat nyimpen draft di tengah kerjaan.
              Material(
                elevation: 8,
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol kirim CUMA di halaman terakhir. Di halaman 1 dia
                        // ada tapi belum kelihatan semua isinya — teknisi gampang
                        // ngirim lembar yang tabel hasilnya masih kosong. Di mode
                        // dua kolom seluruh lembar kelihatan sekaligus, jadi nggak
                        // ada yang perlu ditahan.
                        if (duaKolom || _halaman == bentuk.halaman.length - 1)
                          AppButton(
                            // Admin ngisi lembarnya buat dirinya sendiri — nggak ada
                            // "ke admin"-nya. Yang nentuin bentuk formulir juga
                            // backend (`untuk: admin`), jadi label ini ikut sumber
                            // yang sama, bukan ngecek role sendiri.
                            label: bentuk.untukAdmin
                                ? l10n.lkKirimAdmin
                                : l10n.lkKirim,
                            isLoading: _mengirim,
                            // SELALU aktif. Lihat docblock LembarKerjaScreen.
                            onPressed: () => _submit(draft: false),
                          )
                        else
                          AppButton(
                            label: l10n.lkHalamanLanjut,
                            icon: Icons.arrow_forward,
                            onPressed: () => setState(() => _halaman++),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (!duaKolom && _halaman > 0) ...[
                              Expanded(
                                child: AppButton(
                                  label: l10n.lkHalamanKembali,
                                  icon: Icons.arrow_back,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () => setState(() => _halaman--),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              // Simpan draft ada di SETIAP halaman, bukan cuma yang
                              // terakhir: teknisi sering kepotong di tengah kerjaan
                              // (alat dipakai orang, dipanggil, baterai HP habis),
                              // dan kehilangan separuh lembar kerja jauh lebih mahal
                              // daripada tombol yang kesebar.
                              child: AppButton(
                                label: l10n.lkSimpanDraft,
                                variant: AppButtonVariant.secondary,
                                isLoading: _mengirim,
                                onPressed: () => _submit(draft: true),
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// Banner "lembar kerja ini dikembalikan admin".
///
/// Muncul cuma waktu ada kolom yang ditandai — kalau ditolak tanpa nunjuk kolom
/// tertentu, catatan revisinya udah tampil di layar Alur Kerja dan banner di
/// sini cuma jadi kebisingan.
/// Banner "lembar ini dikembalikan admin" di atas lembar kerja.
///
/// Yang paling penting di sini **catatan adminnya**, bukan bannernya. Kolom
/// bergaris merah cuma jawab "mana yang salah"; alasannya yang jawab "harus
/// diapain". Sebelumnya catatan itu cuma ada di notifikasi (dipotong 120
/// karakter) dan layar detail sesi — bukan di layar tempat teknisi ngerjain
/// betulannya, jadi dia mesti mundur-mundur atau ngira-ngira.
class _BannerRevisi extends StatelessWidget {
  const _BannerRevisi({required this.jumlah, this.catatan});

  /// Berapa kolom yang ditandai admin. 0 = admin cuma nulis catatan tanpa
  /// nandain kolom — sah, dan tetap mesti kelihatan.
  final int jumlah;

  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fg = theme.colorScheme.onErrorContainer;
    final teks = catatan?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_return_outlined, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  // Tanpa kolom ditandai, kalimat "kolom yang ditandai di
                  // bawah" nunjuk ke sesuatu yang nggak ada.
                  jumlah > 0 ? l10n.lkBannerRevisi : l10n.lkBannerRevisiTanpaKolom,
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ),
            ],
          ),
          if (teks != null && teks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.lkCatatanAdmin,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            // Apa adanya, nggak dipotong: catatan revisi yang kepotong bikin
            // teknisi ngerjain separuh permintaan.
            Text(
              teks,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ],
          if (jumlah > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lkRevisiJumlahKolom(jumlah),
              style: theme.textTheme.labelSmall?.copyWith(color: fg),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu halaman lembar kerja, buat HP & jendela sempit.
class _LembarSatuKolom extends StatelessWidget {
  const _LembarSatuKolom({
    required this.bentuk,
    required this.isian,
    required this.halaman,
    required this.onBerubah,
  });

  final LembarKerja bentuk;
  final LembarKerjaState isian;
  final int halaman;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Scroll balik ke atas tiap ganti halaman — tanpa key, posisi scroll
      // halaman 1 kebawa ke halaman 2 dan teknisi mendarat di tengah tabel
      // tanpa lihat judulnya.
      key: PageStorageKey('lk-halaman-$halaman'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (halaman == 0) ...[
          _KopDokumen(bentuk: bentuk),
          const SizedBox(height: AppSpacing.md),
          if (isian.adaRevisi) ...[
            _BannerRevisi(
              jumlah: isian.revisiField.length,
              catatan: isian.catatanRevisi,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],

        if (bentuk.halaman.length > 1) ...[
          _PenandaHalaman(nomor: halaman + 1, dari: bentuk.halaman.length),
          const SizedBox(height: AppSpacing.md),
        ],

        for (final bagian in bentuk.bagianDiHalaman(
          bentuk.halaman[halaman],
        )) ...[
          _Bagian(bagian: bagian, isian: isian, onBerubah: onBerubah),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Lembar kerja PERSIS kayak kertasnya: dua kolom bersebelahan, satu layar.
///
/// Kiri = identitas alat, pemilik, standar, data kalibrasi. Kanan = kondisi
/// lingkungan + tabel Before/After adjustment. Ini bentuk yang dilihat teknisi
/// di formulir cetaknya, jadi di layar yang cukup lebar nggak ada alasan
/// nyusun ulang jadi dua halaman — mata mereka udah hafal peta ini.
///
/// Dua kolom scroll SENDIRI-SENDIRI. Kalau digabung jadi satu scroll, tabel
/// hasil yang panjang bikin kolom kiri ikut ketarik ke bawah dan kepala
/// dokumennya ilang dari layar.
class _LembarDuaKolom extends StatelessWidget {
  const _LembarDuaKolom({
    required this.bentuk,
    required this.isian,
    required this.onBerubah,
  });

  final LembarKerja bentuk;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  List<Widget> _isiKolom(int nomorHalaman) => [
    for (final bagian in bentuk.bagianDiHalaman(nomorHalaman)) ...[
      _Bagian(bagian: bagian, isian: isian, onBerubah: onBerubah),
      const SizedBox(height: AppSpacing.md),
    ],
    const SizedBox(height: AppSpacing.lg),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Column(
            children: [
              _KopDokumen(bentuk: bentuk),
              if (isian.adaRevisi) ...[
                const SizedBox(height: AppSpacing.md),
                _BannerRevisi(
                  jumlah: isian.revisiField.length,
                  catatan: isian.catatanRevisi,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey('lk-kolom-kiri'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: _isiKolom(bentuk.halaman.first),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: ListView(
                  key: const PageStorageKey('lk-kolom-kanan'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: _isiKolom(bentuk.halaman.last),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Halaman 1 dari 2" + garis kemajuan. Lembar kerjanya panjang; tanpa penanda
/// ini teknisi nggak punya cara tau masih ada halaman berikutnya.
class _PenandaHalaman extends StatelessWidget {
  const _PenandaHalaman({required this.nomor, required this.dari});

  final int nomor;
  final int dari;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lkHalamanKe(nomor, dari),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: nomor / dari, minHeight: 4),
        ),
      ],
    );
  }
}

class _KopDokumen extends StatelessWidget {
  const _KopDokumen({required this.bentuk});

  final LembarKerja bentuk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bentuk.judul, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              bentuk.kodeDokumen,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    // Catatannya datang dari backend — dia yang paling tahu
                    // kolom mana yang lagi opsional. Kalau kosong, pakai
                    // kalimat baku yang artinya sama.
                    bentuk.catatanPengisian.isEmpty
                        ? l10n.lkSemuaOpsional
                        : bentuk.catatanPengisian,
                    style: theme.textTheme.bodySmall,
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

/// Satu bagian lembar kerja. Bagian yang punya tabel dirender sebagai tabel
/// hasil; sisanya sebagai daftar kolom.
class _Bagian extends ConsumerWidget {
  const _Bagian({
    required this.bagian,
    required this.isian,
    required this.onBerubah,
  });

  final BagianLembarKerja bagian;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bagian.judul.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: AppSpacing.lg),

            if (bagian.kode == 'usage_check')
              _UsageCheck(bagian: bagian, isian: isian, onBerubah: onBerubah)
            else ...[
              for (final f in bagian.field) ...[
                _Field(field: f, isian: isian, onBerubah: onBerubah),
                const SizedBox(height: AppSpacing.md),
              ],
            ],

            for (final tabel in bagian.tabel) ...[
              LembarKerjaTabel(
                tabel: tabel,
                isian: isian,
                onBerubah: onBerubah,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu kolom. Yang nentuin bentuknya `tipe` + `sumber` dari backend, bukan
/// daftar `if` per nama kolom — kolom baru dari Rev.5 tetap kerender.
class _Field extends ConsumerWidget {
  const _Field({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kolom yang diminta admin dibetulin dikasih pita di kiri + label kecil.
    // Sengaja penanda, bukan penghalang: teknisi tetap boleh ngirim tanpa
    // nyentuh semuanya — kadang yang diminta admin ternyata udah bener dan
    // yang salah justru hal lain.
    if (isian.revisiField.contains(field.kode)) {
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context);

      return Container(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.error, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lkPerluDibetulin,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _isi(context, ref),
          ],
        ),
      );
    }

    return _isi(context, ref);
  }

  Widget _isi(BuildContext context, WidgetRef ref) {
    // Kolom `sumber: otomatis` — ketarik dari alat/akun, teknisi cuma lihat.
    if (field.sumber.readOnly) {
      final user = ref.watch(authProvider).value;
      return _Readonly(
        label: field.label,
        nilai: isian.nilaiTurunan(field.kode, namaTeknisi: user?.nama),
        satuan: field.satuan,
      );
    }

    return switch (field.sumber) {
      SumberField.masterAlat => _PilihAlat(isian: isian, onBerubah: onBerubah),
      SumberField.masterRuangan => _PilihRuangan(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      SumberField.masterStandar => _PilihStandar(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      SumberField.masterMetode => _PilihMetode(field: field, isian: isian),
      // Pilihannya udah ikut di respons — dirender sama kayak pilihan tetap
      // lain, cuma dikelompokkan Insitu/Inlab sesuai kertas.
      SumberField.masterThermohygro => _PilihanTetap(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      _ => _FieldBiasa(field: field, isian: isian, onBerubah: onBerubah),
    };
  }
}

class _FieldBiasa extends StatelessWidget {
  const _FieldBiasa({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    return switch (field.tipe) {
      TipeField.tanggal => _PilihTanggal(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      TipeField.pilihan => _PilihanTetap(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      ),
      _ => _Isian(field: field, isian: isian),
    };
  }
}

/// Satuan ditaruh di `helperText`, bukan cuma diserahkan ke `suffixText`.
///
/// Flutter nge-render affix (`prefixText`/`suffixText`) dengan opacity 0 selama
/// labelnya belum ngambang — lihat `_AffixText` di `input_decorator.dart`
/// (`opacity: labelIsFloating ? 1.0 : 0.0`). Artinya satuan baru kelihatan
/// setelah field difokus atau diisi.
///
/// Di lembar kerja itu bikin celaka: backend sengaja ngasih label kembar buat
/// pasangan suhu/kelembaban ("Env. Condition — First" `°C` vs `%RH`), jadi
/// satuan **satu-satunya** pembeda. Kalau disembunyikan sampai field disentuh,
/// teknisi nggak punya cara tahu kotak mana yang mana waktu mau mulai ngisi.
///
/// Nggak digabung ke `labelText`: label bawaan backend udah panjang, dan
/// `InputDecorator` motong label pakai `TextOverflow.ellipsis` — "Env.
/// Condition — End (%RH)" kepotong jadi "(%R...". `helperText` selalu tampil
/// dan punya barisnya sendiri, jadi aman.
String? _helperSatuan(String? satuan, [String? tambahan]) {
  final unit = (satuan == null || satuan.isEmpty) ? null : satuan;
  return switch ((tambahan, unit)) {
    (null, final u) => u,
    (final t, null) => t,
    (final t, final u) => '$t · $u',
  };
}

class _Isian extends StatelessWidget {
  const _Isian({required this.field, required this.isian});

  final FieldLembarKerja field;
  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    final controller = isian.teks[field.kode];
    if (controller == null) return const SizedBox.shrink();

    final panjang = field.tipe == TipeField.teksPanjang;
    final angka = field.tipe == TipeField.angka;

    return TextField(
      controller: controller,
      maxLines: panjang ? 4 : 1,
      keyboardType: angka
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : (panjang ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: field.satuan,
        helperText: _helperSatuan(field.satuan),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PilihTanggal extends StatelessWidget {
  const _PilihTanggal({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nilai = isian.tanggal[field.kode];

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final dipilih = await showDatePicker(
                  context: context,
                  initialDate: nilai ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  // Backend nolak tanggal kalibrasi di masa depan
                  // (`before_or_equal:today`) — jangan sampai bisa dipilih di
                  // sini terus ditolak sesudah teknisi selesai ngisi semuanya.
                  lastDate: DateTime.now(),
                );
                if (dipilih == null) return;
                isian.tanggal[field.kode] = dipilih;
                onBerubah();
              },
              child: Text(nilai == null ? l10n.lkKosong : _format(nilai)),
            ),
          ),
          if (nilai != null)
            IconButton(
              tooltip: l10n.lkHapusTanggal,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                isian.tanggal[field.kode] = null;
                onBerubah();
              },
            ),
        ],
      ),
    );
  }
}

class _PilihanTetap extends StatelessWidget {
  const _PilihanTetap({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    if (field.kode == 'thermohygro_standard_id') {
      return _PilihThermohygro(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      );
    }

    // Sisanya cuma Location. Kolom pilihan lain yang belum dikenali sengaja
    // nggak dirender apa-apa daripada nampilin dropdown yang nilainya nggak
    // nyambung ke mana-mana waktu dikirim.
    if (field.kode != 'lokasi') return const SizedBox.shrink();

    return DropdownButtonFormField<LokasiKalibrasi>(
      initialValue: isian.lokasi,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final p in field.pilihan)
          DropdownMenuItem(
            value: p.nilai == 'onsite'
                ? LokasiKalibrasi.onsite
                : LokasiKalibrasi.lab,
            child: Text(p.label),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        isian.lokasi = value;
        onBerubah();
      },
    );
  }
}

/// "6. Thermohygro used" — dikelompokkan Insitu vs Inlab persis kayak kotak
/// centang di kertas.
///
/// Pilihannya datang dari backend (empat unit yang tercetak di formulir), bukan
/// seluruh master standar: unit lain memang ada di lab, tapi secara prosedur
/// nggak boleh dipakai buat pekerjaan ini. Pengelompokannya juga bukan hiasan —
/// Insitu berarti unit yang dibawa ke lokasi pelanggan.
class _PilihThermohygro extends StatelessWidget {
  const _PilihThermohygro({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (field.pilihan.isEmpty) {
      return _Readonly(label: field.label, nilai: l10n.lkThermohygroKosong);
    }

    // Urutan grup ngikut urutan munculnya di respons — itu urutan kertasnya.
    final grup = <String, List<PilihanField>>{};
    for (final p in field.pilihan) {
      grup.putIfAbsent(p.grup ?? '', () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final entri in grup.entries) ...[
          if (entri.key.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                entri.key,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final p in entri.value)
                ChoiceChip(
                  label: Text(p.label),
                  selected: isian.thermohygroStandardId?.toString() == p.nilai,
                  onSelected: (pilih) {
                    // Ditekan lagi = batal pilih. Teknisi bisa salah pencet,
                    // dan tanpa jalan keluar dia kepaksa ninggalin unit yang
                    // salah tercatat di dokumen kalibrasi.
                    isian.thermohygroStandardId = pilih
                        ? int.tryParse(p.nilai)
                        : null;
                    onBerubah();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PilihAlat extends ConsumerWidget {
  const _PilihAlat({required this.isian, required this.onBerubah});

  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // pH Meter selalu di kategori instrumen-analitik; null = semua alat, biar
    // lembar kerja ini bisa dipakai kategori lain waktu formulirnya nambah.
    final alatAsync = ref.watch(equipmentLookupProvider(null));

    return alatAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(l10n.lkAlatKosong),
      data: (list) => DropdownButtonFormField<EquipmentLookup>(
        initialValue: isian.alat,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.lkPilihAlat,
          border: const OutlineInputBorder(),
        ),
        hint: Text(list.isEmpty ? l10n.lkAlatKosong : l10n.lkPilih),
        items: [
          for (final e in list)
            DropdownMenuItem(
              value: e,
              child: Text(
                '${e.namaAlat} · ${e.serialNumber}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: list.isEmpty
            ? null
            : (value) {
                isian.alat = value;
                // Identitas alat & pemilik keisi dari master — teknisi tinggal
                // mbenerin yang beda sama barang fisiknya. Lihat `isiDariAlat`.
                isian.isiDariAlat();
                onBerubah();
              },
      ),
    );
  }
}

class _PilihRuangan extends ConsumerWidget {
  const _PilihRuangan({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ruanganAsync = ref.watch(roomListProvider);

    return ruanganAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      // Ruangan itu kolom opsional — gagal muat NGGAK ngeblok lembar kerjanya.
      // Tapi dibikin lenyap juga salah: teknisi nggak bisa bedain "kolomnya
      // emang nggak diminta" dari "kolomnya gagal keambil", jadi dia ngirim
      // tanpa ruangan sambil ngira itu sah. Lihat [DropdownGagal].
      error: (_, _) => DropdownGagal(
        label: field.label,
        pesan: l10n.lkRuanganGagal,
        onCobaLagi: () => ref.invalidate(roomListProvider),
      ),
      data: (list) => DropdownButtonFormField<int>(
        initialValue: isian.roomId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        hint: Text(l10n.lkPilih),
        items: [
          for (final Room r in list)
            DropdownMenuItem(value: r.id, child: Text(r.label)),
        ],
        onChanged: (value) {
          isian.roomId = value;
          onBerubah();
        },
      ),
    );
  }
}

class _PilihStandar extends ConsumerWidget {
  const _PilihStandar({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    // Kolom administratif "Thermohygro used" cuma nyampe sini kalau yang login
    // admin — backend nggak ngirimin bagiannya ke teknisi.
    final thermohygro = field.kode == 'thermohygro_standard_id';

    return standarAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      // Standar acuan itu KETERTELUSURAN — sesi tanpa standar yang ketaut
      // nggak bisa jadi sertifikat berakreditasi. Dulu kolomnya ilang diam-diam
      // waktu `GET /standards` gagal, jadi teknisi ngirim lembar yang pasti
      // dikembaliin admin, tanpa pernah dikasih tahu kenapa.
      error: (_, _) => DropdownGagal(
        label: field.label,
        pesan: l10n.standarLoadFailed,
        onCobaLagi: () => ref.invalidate(standardListProvider),
      ),
      data: (list) {
        final pilihan = thermohygro
            ? list.where((s) => s.punyaParameterKondisi).toList()
            : list;

        return DropdownButtonFormField<int>(
          initialValue: thermohygro
              ? isian.thermohygroStandardId
              : isian.standardId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          hint: Text(l10n.lkPilih),
          items: [
            for (final Standard s in pilihan)
              DropdownMenuItem(
                value: s.id,
                // Standar kadaluarsa TETAP kelihatan tapi nggak bisa dipilih —
                // kalau disembunyiin, teknisi yang nyari standar yang biasa dia
                // pakai bakal ngira datanya ilang.
                enabled: s.masihBerlaku,
                child: Text(
                  s.masihBerlaku
                      ? s.nama
                      : '${s.nama} (${l10n.lkStandarKadaluarsa})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (thermohygro) {
              isian.thermohygroStandardId = value;
            } else {
              isian.standardId = value;
            }
            onBerubah();
          },
        );
      },
    );
  }
}

/// "Calibration Methode" — kolom administratif, cuma kerender di sisi admin.
/// Belum ada layanan master metode di mobile, jadi buat sekarang ditampilin
/// sebagai kolom nonaktif biar admin tau kolomnya ada & diisi di panel web.
class _PilihMetode extends StatelessWidget {
  const _PilihMetode({required this.field, required this.isian});

  final FieldLembarKerja field;
  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    return _Readonly(label: field.label, nilai: '', satuan: field.satuan);
  }
}

class _Readonly extends StatelessWidget {
  const _Readonly({required this.label, required this.nilai, this.satuan});

  final String label;
  final String nilai;
  final String? satuan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tampil = nilai.trim().isEmpty ? l10n.lkKosong : nilai;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: satuan,
        helperText: _helperSatuan(satuan, l10n.lkOtomatis),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
      ),
      child: Text(
        tampil,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: nilai.trim().isEmpty
              ? theme.colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    );
  }
}

/// Kolom "Standard Name / Usage Check": daftar standar dari master data lab,
/// tiap baris ada centang "dipakai" + keterangan.
/// Tabel "STANDARD" — barisnya TERCETAK di formulir, bukan katalog standar lab.
///
/// Dulu bagian ini nampilin seluruh `GET /standards`, jadi di lembar pH ikut
/// muncul standar panjang dan tujuh unit thermohygro — nggak mirip kertasnya
/// sama sekali. Sekarang barisnya datang dari backend (`bagian.baris`), lima
/// baris yang sama persis dengan yang tercetak, dan teknisi cuma nyentang.
///
/// Master standar tetap dibaca, tapi cuma buat SATU hal: nempelin peringatan
/// kadaluarsa ke baris yang standarnya kedaftar. Itu temuan asesor kalau
/// kelewat, jadi peringatannya nggak boleh hilang cuma gara-gara barisnya
/// sekarang tercetak.
class _UsageCheck extends ConsumerWidget {
  const _UsageCheck({
    required this.bagian,
    required this.isian,
    required this.onBerubah,
  });

  final BagianLembarKerja bagian;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    // Backend lama nggak ngirim `baris` — jatuh balik ke daftar master biar
    // lembar kerjanya tetap bisa diisi, bukan nampilin bagian kosong.
    if (bagian.baris.isEmpty) {
      return standarAsync.when(
        skipLoadingOnReload: true,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Text(l10n.lkUsageCheckKosong),
        data: (list) => list.isEmpty
            ? Text(l10n.lkUsageCheckKosong)
            : Column(
                children: [
                  for (final s in list) ...[
                    _UsageCheckBaris(
                      label: s.nama,
                      serialNumber: s.serialNumber,
                      kadaluarsa: !s.masihBerlaku,
                      state: isian.usage(s.id),
                      onBerubah: onBerubah,
                    ),
                    const Divider(height: AppSpacing.md),
                  ],
                ],
              ),
      );
    }

    final master = {
      for (final s in standarAsync.value ?? const <Standard>[]) s.id: s,
    };

    return Column(
      children: [
        for (final baris in bagian.baris) ...[
          _UsageCheckBaris(
            label: baris.label,
            serialNumber:
                baris.serialNumber ?? master[baris.standardId]?.serialNumber,
            kadaluarsa: master[baris.standardId]?.masihBerlaku == false,
            // Baris yang standarnya belum kedaftar di master nggak punya
            // `standard_id`, jadi centangnya nggak bisa ditautkan ke apa pun —
            // ditampilkan, tapi nggak bisa diisi. Menghilangkannya lebih buruk:
            // teknisi nggak bakal sadar ada standar yang nggak kecatat.
            state: baris.standardId == null
                ? null
                : isian.usage(baris.standardId!),
            onBerubah: onBerubah,
          ),
          const Divider(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _UsageCheckBaris extends StatelessWidget {
  const _UsageCheckBaris({
    required this.label,
    required this.state,
    required this.onBerubah,
    this.serialNumber,
    this.kadaluarsa = false,
  });

  final String label;
  final String? serialNumber;
  final bool kadaluarsa;

  /// Null = standarnya belum terdaftar di master, jadi barisnya cuma bisa
  /// dilihat. Lihat catatan di `_UsageCheck`.
  final UsageCheckState? state;

  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final aktif = state != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: state?.dipakai ?? false,
              onChanged: aktif
                  ? (v) {
                      state!.dipakai = v ?? false;
                      onBerubah();
                    }
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: aktif ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (serialNumber != null && serialNumber!.isNotEmpty)
                    Text(
                      serialNumber!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (kadaluarsa)
                    Text(
                      l10n.lkStandarKadaluarsa,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (!aktif)
                    Text(
                      l10n.lkStandarBelumTerdaftar,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (aktif)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xl),
            child: TextField(
              controller: state!.keterangan,
              style: theme.textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.lkUsageCheckKeterangan,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    );
  }
}
