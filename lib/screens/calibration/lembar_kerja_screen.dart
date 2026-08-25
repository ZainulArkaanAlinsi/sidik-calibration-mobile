import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../core/theme/app_spacing.dart';
import '../../core/utils/angka.dart';
import '../../core/utils/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_detail.dart' show MeasurementResult;
import '../../models/calibration_draft.dart' show LokasiKalibrasi;
import '../../models/equipment_lookup.dart';
import '../../models/lembar_kerja.dart';
import '../../models/room.dart';
import '../../models/standard.dart';
import '../../models/worksheet_scan.dart' show SelDipakaiPindai;
import '../../models/worksheet_template.dart';
import '../../providers/autoclave_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/lembar_kerja_provider.dart';
import '../../providers/sumber_foto_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/auth_service.dart' show AuthException;
import '../../services/jalankan_pindai.dart';
import '../../services/pembaca_sel.dart' show pngDari;
import '../../services/pindai_lembar.dart';
import '../../services/worksheet_scan_service.dart' show PindaiDitolak;
import '../../widgets/autoclave_hasil_panel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/sidik_loader.dart';
import '../../widgets/tampil_masuk.dart';
import 'lembar_kerja_state.dart';
import 'pindai_review_screen.dart';
import 'widgets/dropdown_gagal.dart';
import 'widgets/lembar_kerja_grid.dart';
import 'widgets/lembar_kerja_matriks.dart';
import 'widgets/lembar_kerja_tabel.dart';
import 'widgets/pengatur_titik.dart';

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

  /// Kode jenis alat (`ph_meter` / `turbidimeter` / `chlorine_meter` /
  /// `refractometer`) —
  /// nentuin bentuk lembar kerja yang diambil dari backend.
  final String profil;

  @override
  ConsumerState<LembarKerjaScreen> createState() => _LembarKerjaScreenState();
}

class _LembarKerjaScreenState extends ConsumerState<LembarKerjaScreen> {
  /// Berapa kotak pengulangan yang digambar. `null` = bawaan profilnya (5,
  /// ngikut form kertas) — teknisi yang nggak peduli nggak perlu milih apa-apa.
  int? _pengulangan;

  /// Alat yang lagi dipilih, diangkat ke sini karena bentuk lembar ditarik di
  /// level ini sementara dropdown alatnya ada di dalam [_Form].
  int? _equipmentId;

  /// Bentuk terakhir yang berhasil dimuat — dipegang biar layar nggak balik
  /// kosong waktu ganti alat bikin provider-nya mulai dari `loading`.
  LembarKerja? _bentukTerakhir;

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
    // Alat yang lagi dipilih ikut jadi kunci — TANPA ini backend selalu ngirim
    // bentuk GENERIK, dan buat Conductivity itu artinya baris `1,412 mS/cm`
    // muncul di lembar alat yang nggak punya titik itu sama sekali.
    //
    // Sesi 53 (12 Agt 2026) kejeblos di situ: teknisi ngisi 1413 di baris
    // 1,412 mS/cm — di master Excel kolom itu justru dikosongin, 1413 punya
    // kolom `1412 µS/cm`. Backend ngitung Error = 1413 − 1,412 = 1411,588 dan
    // lembarnya nyampe admin. Anggaran ketidakpastiannya sendiri udah bener
    // (U95 8,10901195 sama persis kayak Excel) — yang salah cuma barisnya.
    final kunci = (
      profil: widget.profil,
      pengulangan: _pengulangan,
      equipmentId: _equipmentId,
    );
    // Ganti alat = kunci baru = provider baru = mulai dari `loading`. Tanpa
    // nyimpen bentuk terakhir, badan layar balik jadi spinner sekejap dan
    // `_Form` ke-unmount — seluruh isian yang udah diketik ilang, termasuk alat
    // yang barusan dipilih. Formulirnya HARUS tetap terpasang; bentuk barunya
    // dipasang belakangan lewat `gantiBentuk`.
    ref.listen(lembarKerjaProvider(kunci), (_, next) {
      // Gagal narik bentuk alat SESUDAH lembar kepegang nggak boleh diam.
      //
      // Backend nolak (422) kalau master alatnya belum nyebut varian satuan
      // mana yang dipakai. Karena bentuk lama tetap kepasang biar isian nggak
      // ilang, tanpa pesan ini teknisi bakal lanjut ngisi lembar GENERIK yang
      // ambigu — persis keadaan yang penolakan itu mau cegah.
      if (next is AsyncError && _bentukTerakhir != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                next.error is AuthException
                    ? (next.error as AuthException).message
                    : '${next.error}',
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        return;
      }

      final baru = next.value;
      if (baru == null || identical(baru, _bentukTerakhir)) return;
      setState(() => _bentukTerakhir = baru);
    });

    final bentukAsync = ref.watch(lembarKerjaProvider(kunci));
    final bentuk = bentukAsync.value ?? _bentukTerakhir;
    // Dari bentuk yang lagi KEPASANG, bukan dari status async — waktu ganti
    // alat lagi dimuat, label jumlah kotak nggak boleh loncat balik ke bawaan.
    final terpakai = bentuk?.jumlahPengulangan ?? _pengulangan ?? 5;

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
      // Bentuk yang udah pernah kepegang MENANG atas status loading — lihat
      // `ref.listen` di atas. Gagal cuma ditampilin kalau belum ada bentuk sama
      // sekali; gagal narik bentuk alat nggak boleh ngebuang lembar yang lagi
      // diisi.
      body: switch ((bentuk, bentukAsync)) {
        // `ValueKey` WAJIB: `_FormState` bikin `LembarKerjaState`-nya sekali
        // (`late final`) dari `widget.bentuk`. Tanpa key, Flutter mendaur ulang
        // State yang lama waktu jumlah kotaknya ganti — tabelnya bakal tetap
        // 5 kolom padahal backend udah ngirim 3, dan nggak ada yang error.
        //
        // `key` SENGAJA nggak bawa `equipmentId`: ganti alat mesti mempertahankan
        // isian yang udah diketik, jadi State-nya dipakai ulang dan bentuk
        // barunya dipasang lewat `gantiBentuk` di `didUpdateWidget`. Kalau
        // equipmentId ikut key, tiap ganti alat bikin State baru dan seluruh
        // tabel yang udah diisi ilang — termasuk alat yang barusan dipilih.
        (final LembarKerja b, _) => _Form(
          key: ValueKey(b.jumlahPengulangan),
          bentuk: b,
          sesiId: widget.sesiId,
          profil: widget.profil,
          onAlatBerubah: (id) {
            if (id == _equipmentId) return;
            setState(() => _equipmentId = id);
          },
        ),
        (_, AsyncError(:final error)) => _Gagal(
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
  const _Form({
    super.key,
    required this.bentuk,
    required this.onAlatBerubah,
    required this.profil,
    this.sesiId,
  });

  final LembarKerja bentuk;

  /// Kode ALAT (`ph_meter`, `spectrophotometer`, …), dioper turun ke tombol
  /// pindai.
  ///
  /// **Bukan `bentuk.kodeDokumen`.** Dulu yang dikirim nomor formulirnya
  /// (`SIDIK-IK-CAL-0508_Rev.4`), sementara `GET /worksheet-templates/{kode}`
  /// mau kode alat — jadi 404, providernya error, dan tombol pindainya HILANG
  /// dari layar tanpa satu pun pesan. Kegagalan yang paling mahal waktunya:
  /// dari layar, fiturnya kelihatan nggak pernah dibikin.
  final String profil;

  /// Dipanggil begitu teknisi milih alat — bikin layar di atas narik bentuk
  /// lembar yang udah disusutin ke alat itu.
  final ValueChanged<int?> onAlatBerubah;

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
    // Lewat `jamProvider`, bukan `DateTime.now()` langsung — tanggal ini
    // kecetak ke golden lembar kerja, dan tanpa seam-nya golden itu merah tiap
    // ganti hari tanpa ada yang rusak.
    tanggalKalibrasiAwal: ref.read(jamProvider)(),
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

    // Angka yang diketik di tabel hasil nggak lewat `_isianBerubah` — selnya
    // sengaja nggak nge-rebuild formulir tiap ketukan tombol. Pratinjaunya
    // dengerin dari sini.
    _isian.onIsianDiketik = _jadwalkanPratinjau;

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
      if (!mounted) return;

      // Tabel pengukurannya dipulihkan walau `isian_teknisi` nggak ikut di
      // respons — dua-duanya datang dari sesi yang sama, tapi yang bikin
      // teknisi harus ngetik ulang dari kertas itu angkanya, bukan header-nya.
      var kebuang = 0;

      setState(() {
        if (isi != null) _isian.muatDariSesi(isi);
        kebuang = _isian.terapkanPembacaan(detail.pembacaanMentah);
        // Alat sesi lama ikut ngabarin ke atas, jadi lembar yang ditarik ulang
        // udah bentuk yang disusutin ke alat itu — bukan generik.
        widget.onAlatBerubah(_isian.alat?.id);
        // Sesudah baris mentah, bukan sebelum: yang mentah lebih dekat ke apa
        // yang teknisi centang (termasuk titik yang belum kehitung), yang
        // hasil hitung cuma cadangan buat sesi lama.
        _isian.terapkanStandarDariHasil(detail.titik);
      });

      // Angka yang nggak ketemu barisnya HARUS diomongin. Draft yang balik
      // dengan tabel bolong tanpa ada yang bilang itu persis cara sesi kekirim
      // ke admin dengan titik yang ilang diam-diam.
      if (kebuang > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).lkPembacaanTakTerpulih(kebuang)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (_) {
      // Lihat docblock.
    }
  }

  /// Satu pintu buat tiap perubahan isian.
  ///
  /// Selain nge-rebuild, dia ngabarin alat yang lagi kepilih ke layar di atas.
  /// Dipasang di sini — bukan cuma di dalam dropdown alat — supaya jalur lain
  /// yang nyetel alat (mis. pulih dari draft) ikut narik bentuk yang benar.
  /// Yang di atas nyaring sendiri kalau id-nya nggak berubah.
  void _isianBerubah() {
    // Ganti lokasi = kotak yang berlaku ikut ganti, dan yang ditinggalkan wajib
    // KOSONG, bukan cuma ilang dari layar. Dipanggil di sini — satu pintu buat
    // semua perubahan — biar nggak ada jalur yang lupa: yang nyalain bug lama
    // bukan dropdown ruangannya, tapi nilainya yang masih nyangkut sesudah
    // teknisi pindah ke Insitu.
    _isian.bersihkanFieldTersembunyi();
    setState(() {});
    widget.onAlatBerubah(_isian.alat?.id);
    _jadwalkanPratinjau();
  }

  /// Minta backend ngitung isian yang sekarang — DITUNDA, bukan tiap ketukan.
  ///
  /// Satu titik Spectrophotometer ikut nentuin U95 seluruh saudaranya sekelompok
  /// (STDEV terbesar yang masuk budget), jadi angka yang tampil bisa berubah
  /// gara-gara baris LAIN yang barusan diisi. Itu justru alasan panelnya ada,
  /// dan alasan permintaannya nggak bisa dipatok "sekali per baris kelar".
  ///
  /// Syaratnya cuma dua, dan dua-duanya soal jangan ngerepotin server buat
  /// jawaban yang udah pasti kosong: alatnya udah dipilih (`equipment_id` wajib
  /// di payload) dan ada minimal satu angka yang diketik.
  void _jadwalkanPratinjau() {
    _pratinjauTertunda?.cancel();

    if (_isian.alat == null) return;

    // Lembar bermatriks (Autoklaf) punya endpoint olah data sendiri, dan
    // teknisinya ngetik ke kotak matriks — bukan ke `titik`. Dipakai syarat
    // yang sama kayak alat lain, pratinjaunya nggak pernah kepanggil dan panel
    // hasilnya diam terus tanpa satu pun tanda kenapa.
    final bagian = _isian.bagianMatriks;

    if (bagian != null) {
      if (!_isian.adaIsianMatriks) return;

      _pratinjauTertunda = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        ref
            .read(autoclavePratinjauProvider.notifier)
            .hitung(_isian.payloadMatriks(bagian.matriks!, bagian.tabelTambahan));
      });

      return;
    }

    if (!_isian.titik.values.any((t) => t.adaPembacaan)) return;

    _pratinjauTertunda = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      ref
          .read(pratinjauProvider.notifier)
          .hitung(_isian.toSubmission(draft: true));
    });
  }

  Timer? _pratinjauTertunda;

  /// Bentuk baru dari backend dipasang ke state yang SUDAH ADA, bukan bikin
  /// state baru — isian yang udah diketik dipindahin per titik ukur oleh
  /// `gantiBentuk`, dan yang barisnya udah nggak ada dihitung biar bisa
  /// diomongin. Isian kalibrasi yang ilang diam-diam lebih bahaya daripada
  /// formulir yang bentuknya salah.
  @override
  void didUpdateWidget(covariant _Form lama) {
    super.didUpdateWidget(lama);

    if (identical(widget.bentuk, lama.bentuk)) return;

    final kebuang = _isian.gantiBentuk(widget.bentuk);
    setState(() {});

    if (kebuang > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).lkIsianTitikKebuang(kebuang),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pratinjauTertunda?.cancel();
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

    // Pembacaan tanpa suhu ditahan SEBELUM konfirmasi angka — biar teknisi
    // tau di lapangan, bukan sesudah kirim.
    //
    // Nilai acuan larutan Conductivity digeser ikut suhu. Di master Excel-nya,
    // kolom suhu kosong bikin polinomial dievaluasi pada T=0 dan keluar
    // `0,738 mS/cm`: bukan error, angka yang kelihatan wajar, dan ikut
    // tercetak di sertifikat. Draft tetap boleh disimpan setengah jadi.
    if (!draft) {
      final belum = _isian.titikSuhuBelumLengkap;

      if (belum.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.lkSuhuWajib(belum.map((t) => t.label).join(', ')),
            ),
          ),
        );
        return;
      }

      // Pembacaan yang melesetnya SATU ORDE dari nominal barisnya — salah
      // satuan atau koma kegeser. Ditanyain di sini karena yang bisa mbenerin
      // cuma orang yang lagi berdiri di depan alatnya; di admin angka kayak
      // gini cuma jadi peringatan yang gampang dilewatin.
      //
      // TANYA, bukan tahan. Ini dugaan soal kewajaran angka, bukan kekurangan
      // data: alat yang lagi dikalibrasi BOLEH baca jauh melenceng — rusak,
      // spindle/RPM nggak cocok, atau nol karena torsinya nggak nyampe. Waktu
      // penjaga ini masih memblokir, viscometer 19 Agt 2026 nggak bisa dikirim
      // sama sekali walau angkanya emang segitu di layar alatnya, dan
      // satu-satunya jalan keluar teknisi ya ngarang angka biar lolos — persis
      // kebalikan dari yang mau dijaga.
      final jauh = _isian.titikPembacaanJauh;

      if (jauh.isNotEmpty) {
        final lanjut = await _konfirmasiPeringatan(
          l10n.lkPembacaanJauhDariTitik(jauh.map((t) => t.label).join(', ')),
        );
        if (!lanjut) return;
        if (!mounted) return;
      }

      // Satu Repeat yang jauh menyimpang dari Repeat lain SEBARIS — nangkep
      // DIGIT KETUKER, yang penjaga di atas nggak bisa nangkep.
      //
      // `783,52` di baris `738,5` cuma 6% dari nominalnya, jadi penjaga orde
      // lolos mulus. Tapi buat alat yang U95-nya lahir per kelompok, satu
      // angka itu menaikkan U95 sembilan titik saudaranya 212x CMC lab — dan
      // sertifikatnya terbit dengan angka itu (`CAL/2026/08/0043`).
      //
      // Sama kayak penjaga di atas: ditanyain, bukan ditahan. Sebaran antar
      // Repeat yang lebar itu GEJALA alat jelek, dan alat jelek justru yang
      // paling perlu sertifikatnya terbit apa adanya.
      final menyimpang = _isian.titikRepeatMenyimpang;

      if (menyimpang.isNotEmpty) {
        final lanjut = await _konfirmasiPeringatan(
          l10n.lkRepeatMenyimpang(menyimpang.map((t) => t.label).join(', ')),
        );
        if (!lanjut) return;
        if (!mounted) return;
      }

      // Dropdown yang nentuin ANGKA tapi belum dipilih — di TITS itu Mode
      // (Measure/Source) & Temperature Type.
      //
      // Beda dari kolom kosong biasa: arah perhitungan koreksi BERBALIK antara
      // dua mode dan koreksi kalibrator beda per tipe sensor, jadi backend
      // nggak nebak — dia mulangin SELURUH titik di `belum_dihitung`. Teknisi
      // yang nggak ditanya di sini baru tau setelah lembarnya nyampe admin,
      // dan waktu itu dia udah nggak di depan alatnya.
      //
      // TANYA, bukan tahan: backend nandainya `wajib: false`, dan lembar
      // setengah jadi dari lapangan memang boleh dikirim.
      final penentuKosong = _isian.pilihanPenentuAngkaKosong;

      if (penentuKosong.isNotEmpty) {
        final lanjut = await _konfirmasiPeringatan(
          l10n.lkPenentuAngkaKosong(
            penentuKosong.map((f) => f.label).join(', '),
          ),
        );
        if (!lanjut) return;
        if (!mounted) return;
      }

      // Isian YATIM: angkanya keisi tapi standarnya belum dicentang, jadi
      // nggak bisa dihitung. Ditahan di sini, bukan dibiarin nyampe admin —
      // di sana dia muncul sebagai `titik_kosong` yang MEMBLOKIR penerbitan,
      // dan yang bisa mbenerin justru udah nggak di depan alatnya.
      final yatim = _isian.titikTerisiTanpaStandar;

      if (yatim.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.lkStandarBelumDicentang(
                yatim.map((t) => t.label).join(', '),
              ),
            ),
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }
    }

    // Jam yang bentuknya nggak kebaca ditahan DI SINI, bukan dibiarin ditolak
    // server. Backend jawabnya `The waktu.0 field must match the format H:i`,
    // dan `waktu.0` bukan nama yang ada di kertas kerja teknisi — dia nggak
    // punya cara tau kolom mana yang mesti dibetulin.
    //
    // Kotak jamnya sendiri sekarang udah nyisipin titik dua sambil diketik,
    // jadi yang nyampe sini praktis cuma draft lama yang kesimpen sebelum
    // formatter itu ada.
    final jamNgawur = _isian.jamMatriksNgawur();

    if (jamNgawur.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.lkJamTidakTerbaca(jamNgawur.map((t) => '$t').join(', ')),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    if (!draft && !await _konfirmasiAngka()) return;
    if (!mounted) return;

    setState(() => _mengirim = true);

    // Lembar bermatriks punya endpoint simpan sendiri (`POST
    // /calibrations/autoclave`): payloadnya bukan `measurements[]` melainkan
    // blok `suhu`/`tekanan` bermatriks, dan server yang mutusin UUT Reading
    // dari kelima kolomnya.
    final bagianMatriks = _isian.bagianMatriks;

    if (bagianMatriks != null) {
      await _kirimMatriks(bagianMatriks, draft: draft);
      return;
    }

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

    // Teknisi baru aja nyatain di dialog konfirmasi bahwa angka hasil foto
    // udah dia cocokin sama alatnya — jadi ditandai SEKARANG, bukan disuruh
    // balik lagi ke Riwayat buat mencet tombol kedua.
    //
    // Draft dilewat: draft nggak masuk antrean admin, jadi nggak ada yang
    // keblokir, dan dialog konfirmasinya sendiri emang nggak muncul buat draft.
    if (!draft && _isian.adaIsianDariFoto) {
      try {
        final token = await ref.read(tokenStorageProvider).read();
        if (token != null) {
          await ref
              .read(historyServiceProvider)
              .verifikasiPembacaan(token, hasil.id);
        }
      } catch (e) {
        // Kiriman UDAH sukses — ini cuma penandaan. Jangan bikin teknisi
        // ngira sesinya gagal; kasih tau jalan keluarnya, tombolnya masih ada
        // di layar detail sesi.
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.lkKonfirmasiGagalTandai('$e'))),
          );
          navigator.pop(hasil.id);
          return;
        }
      }
    }

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasil.draft ? l10n.lkBerhasilDraft : l10n.lkBerhasilKirim,
        ),
      ),
    );
    navigator.pop(hasil.id);
  }

  /// Kirim lembar bermatriks lewat endpoint alatnya sendiri.
  ///
  /// Kepisah dari jalur `measurements[]` bukan karena rapi-rapian: bentuk
  /// datanya beda sampai ke akarnya, dan memaksanya lewat jalur yang sama
  /// berarti meratakan matriks jadi daftar titik — yang persis bikin bacaan
  /// manometer bisa mendarat di blok suhu.
  Future<void> _kirimMatriks(
    BagianLembarKerja bagian, {
    required bool draft,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final token = await ref.read(tokenStorageProvider).read();

      if (token == null) {
        if (!mounted) return;
        setState(() => _mengirim = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.lkGagalKirim('token'))),
        );
        return;
      }

      final id = await ref
          .read(autoclaveServiceProvider)
          .simpan(token, _isian.payloadSimpanMatriks(bagian, draft: draft));

      // Lembar bermatriks lewat endpoint alatnya sendiri, jadi dia NGGAK
      // kelewatan `KirimLembarKerjaController.kirim()` yang megang invalidasi
      // buat jalur `measurements[]`. Tanpa baris ini draf Autoklaf yang barusan
      // disimpen absen dari layar Draf sementara draf pH nongol — beda perilaku
      // buat tombol yang tulisannya sama persis.
      ref.invalidate(drafProvider);

      if (!mounted) return;
      setState(() => _mengirim = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text(draft ? l10n.lkBerhasilDraft : l10n.lkBerhasilKirim),
        ),
      );
      navigator.pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mengirim = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.lkGagalKirim('$e'))),
      );
    }
  }

  /// Peringatan kewajaran angka yang BISA dilewati teknisi.
  ///
  /// Bedanya sama penjaga suhu & isian yatim: yang itu bikin angkanya nggak
  /// bisa DIHITUNG sama sekali (nilai acuan nggak ketauan), jadi tetap ditahan
  /// mati. Yang lewat sini cuma dugaan "kelihatan salah ketik" — dan dugaan
  /// nggak boleh nyandera data lapangan, karena alat yang lagi dikalibrasi
  /// emang boleh baca aneh.
  ///
  /// Tetap dialog, bukan snackbar: teknisi mesti natap angkanya sekali dan
  /// menyatakan "emang segitu", jadi salah ketik beneran masih ketangkep.
  Future<bool> _konfirmasiPeringatan(String pesan) async {
    final l10n = AppLocalizations.of(context);

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.lkPeringatanAngkaJudul),
        content: Text(pesan),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.lkKonfirmasiPeriksaLagi),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.lkPeringatanAngkaLanjut),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  /// Rata-rata tiap larutan standar ditunjukin sekali, tepat sebelum kirim.
  ///
  /// Ini penjaga terakhir buat salah ketik yang angkanya WAJAR. 6 Agt 2026 satu
  /// sesi chlorine kekirim dengan pembacaan 1,90 buat standar 1,83 (lembar
  /// kerjanya 1,86) dan nembus sampai sertifikat terbit. Nggak ada satu pun
  /// pemeriksaan otomatis yang bisa nangkep itu: 1,90 meleset 3,8% di alat
  /// bertoleransi 8% — angka yang sama sekali wajar, nggak bisa dibedain dari
  /// penyimpangan alat beneran. Yang bisa mbedain cuma orang yang inget dia
  /// nulis apa di kertas.
  ///
  /// Makanya bentuknya ringkasan, bukan peringatan: `1,83 → rata-rata 1,90`
  /// berdampingan, dan yang salah ketik bakal kelihatan sendiri. Nggak ada yang
  /// diblokir — tombol kirimnya tetap ada di dialog yang sama.
  ///
  /// Cuma buat KIRIM KE ADMIN. Draft sengaja lolos: draft itu justru dipakai
  /// buat nyimpen kerjaan setengah jadi, dan nanyain "yakin angkanya?" tiap kali
  /// teknisi nyimpen di tengah jalan cuma bikin dialognya diklik tanpa dibaca.
  Future<bool> _konfirmasiAngka() async {
    final l10n = AppLocalizations.of(context);
    final ringkasan = _isian.ringkasanKirim();

    // Nggak ada satu pun pembacaan — nggak ada yang perlu dicek ulang. Sesi
    // kosong tetap boleh dikirim (mis. lembar kerja yang tabelnya nyusul), dan
    // dialog kosong cuma jadi satu ketukan sia-sia.
    if (ringkasan.every((r) => r.kosong)) return true;

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Isinya setinggi jumlah titik × ukuran huruf HP-nya: lembar pH (3
        // titik) di huruf 1,3× aja udah lebih tinggi dari layar 640 px. Tanpa
        // ini isinya overflow sampai tombol "Kirim sekarang" kedorong keluar
        // layar — dialog yang nggak bisa ditutup, tepat di detik teknisi mau
        // ngirim.
        scrollable: true,
        title: Text(l10n.lkKonfirmasiJudul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in ringkasan) _BarisKonfirmasi(ringkasan: r),

            // Angka hasil foto disebut EKSPLISIT di sini, dan di sini juga
            // teknisi menyatakan udah ngecek — bukan lewat tombol terpisah
            // sesudah kirim.
            //
            // Dulu penandaannya jadi langkah sendiri di layar Riwayat, dan
            // itu keliru dua-duanya: teknisi nggak pernah dikasih tau dia
            // mesti balik ke sana (sesinya diam-diam nge-blok admin), dan
            // tombol yang ditekan belakangan cuma buat mbuka blokir itu
            // stempel karet — dia nggak lagi natap angkanya. Yang natap
            // angkanya ya di dialog ini.
            if (_isian.adaIsianDariFoto) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.lkKonfirmasiDariFoto,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.lkKonfirmasiCatatan,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.lkKonfirmasiPeriksaLagi),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.lkKonfirmasiKirim),
          ),
        ],
      ),
    );

    return lanjut ?? false;
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
                        onBerubah: _isianBerubah,
                        sesiId: widget.sesiId,
                        profil: widget.profil,
                      )
                    : _LembarSatuKolom(
                        bentuk: bentuk,
                        isian: _isian,
                        halaman: _halaman,
                        onBerubah: _isianBerubah,
                        sesiId: widget.sesiId,
                        profil: widget.profil,
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
    required this.profil,
    this.sesiId,
  });

  /// Sesi yang lagi dikerjakan — dioper turun ke tombol pindai.
  final int? sesiId;

  /// Kode ALAT, dioper turun ke tombol pindai.
  final String profil;

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

        // Kartu bertabel SENGAJA nggak dianimasikan — lihat catatan di
        // `_LembarDuaKolom._isiKolom`. Ini jalur HP, yang paling sering
        // dibuka, jadi justru di sini ongkosnya paling terasa.
        ...bagianBerurutan(
          bentuk.bagianDiHalaman(bentuk.halaman[halaman]),
          (bagian) => _Bagian(
            bagian: bagian,
            isian: isian,
            onBerubah: onBerubah,
            sesiId: sesiId,
            profil: profil,
            gambarGrid: bentuk.bagianPertama(bagian),
          ),
        ),

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
    required this.profil,
    this.sesiId,
  });

  /// Sesi yang lagi dikerjakan — dioper turun ke tombol pindai.
  final int? sesiId;

  /// Kode ALAT, dioper turun ke tombol pindai.
  final String profil;

  final LembarKerja bentuk;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Kartu bagian, sebagian datang berurutan.
  ///
  /// Yang punya TABEL sengaja muncul langsung tanpa animasi, dan ini bukan
  /// karena kelewat. `Opacity` memaksa Flutter merender subtree-nya ke lapisan
  /// terpisah selama animasi berjalan, dan tabel hasil di layar ini rutin berisi
  /// 60 kotak angka (2 tabel x 3 baris x 5 repeat x 2 kolom). Menganimasikan
  /// lapisan sebesar itu bikin lembar kerja terasa LEBIH LAMBAT dibuka — persis
  /// kebalikan dari alasan animasinya ditambahkan.
  ///
  /// Yang tersisa justru yang paling menentukan kesannya: kop, identitas alat,
  /// pemilik, data kalibrasi, dan penutup. Itu yang kelihatan duluan waktu
  /// layarnya dibuka; tabelnya sendiri hampir selalu perlu digulir dulu.
  List<Widget> _isiKolom(int nomorHalaman) => [
    ...bagianBerurutan(
      bentuk.bagianDiHalaman(nomorHalaman),
      (bagian) => _Bagian(
        bagian: bagian,
        isian: isian,
        onBerubah: onBerubah,
        sesiId: sesiId,
        profil: profil,
        gambarGrid: bentuk.bagianPertama(bagian),
      ),
    ),
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
              // Nomor formulir + nomor metode, persis kayak yang tercetak di
              // kertas: yang FM di kop, yang IK di baris "Calibration Methode".
              // Teknisi cuma membacanya — `calibration_method_id` tetap milik
              // admin.
              //
              // Yang KOSONG dibuang, bukan dirangkai apa adanya. TITS &
              // Gas Detector nomor formulirnya belum terbit (`kode_dokumen:
              // null`), dan merangkai buta bikin kop-nya mulai dengan pemisah
              // menggantung — " · SIDIK-IK-CAL-0502_Rev.3" — yang kebaca kayak
              // nomor formulirnya gagal dimuat, bukan kayak memang belum ada.
              [bentuk.kodeDokumen, bentuk.kodeMetode]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
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
/// Kartu bagian + jarak antar kartu, sebagian datang berurutan.
///
/// Yang punya TABEL sengaja muncul langsung tanpa animasi, dan ini bukan
/// karena kelewat. `Opacity` memaksa Flutter merender subtree-nya ke lapisan
/// terpisah selama animasi berjalan, dan tabel hasil di layar ini rutin berisi
/// 60 kotak angka (2 tabel x 3 baris x 5 repeat x 2 kolom). Menganimasikan
/// lapisan sebesar itu bikin lembar kerja terasa LEBIH LAMBAT dibuka — persis
/// kebalikan dari alasan animasinya ditambahkan.
///
/// Yang tersisa justru yang paling menentukan kesan pertamanya: kop, identitas
/// alat, pemilik, data kalibrasi, penutup. Itu yang kelihatan begitu layarnya
/// kebuka; tabelnya sendiri hampir selalu perlu digulir dulu.
///
/// Dipakai bareng jalur satu kolom (HP) dan dua kolom (layar lebar) supaya
/// aturannya nggak bisa beda di antara keduanya.
List<Widget> bagianBerurutan(
  List<BagianLembarKerja> bagian,
  Widget Function(BagianLembarKerja) bangun,
) {
  var urut = 0;

  return [
    for (final b in bagian) ...[
      if (b.tabel.isEmpty)
        TampilMasuk(indeks: urut++, child: bangun(b))
      else
        bangun(b),
      const SizedBox(height: AppSpacing.md),
    ],
  ];
}

class _Bagian extends ConsumerWidget {
  const _Bagian({
    required this.bagian,
    required this.isian,
    required this.onBerubah,
    required this.profil,
    this.sesiId,
    this.gambarGrid = false,
  });

  final BagianLembarKerja bagian;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Dioper ke tombol pindai: hasil pindai dicatat server per sesi, dan teknisi
  /// cuma boleh memindai sesi yang dia kerjakan sendiri.
  final int? sesiId;

  /// Kode ALAT (`ph_meter`, `spectrophotometer`, …) — bukan nomor formulirnya.
  final String profil;

  /// Bagian ini yang menggambar GRID sensor.
  ///
  /// Gridnya milik LEMBAR, bukan milik bagian — bentuk Enclosure mengirim
  /// `grid_sensor` di tingkat atas, bukan di dalam salah satu `bagian`. Jadi
  /// yang menggambarnya dipilih dari luar (bagian PERTAMA), supaya gridnya
  /// nggak kegambar berkali-kali kalau nanti bentuknya nambah bagian kedua.
  final bool gambarGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Satu saklar buat DUA tombol pindai di bagian ini — yang lembar penuh di
    // bawah, dan yang per tabel di dalam `LembarKerjaTabel`. Dibaca sekali di
    // sini biar nggak mungkin ada keadaan setengah: tombol "FOTO TABEL INI"
    // nongol sendirian tanpa "PINDAI LEMBAR KERJA" itu justru bikin teknisi
    // ngira fiturnya rusak, bukan dimatiin.
    final pindaiAktif = ref.watch(pindaiLembarAktifProvider);

    // Grup `spindle_titik_N` / `rpm_titik_N` / `resolusi_titik_N` ditarik
    // keluar dari daftar field biasa SELAMA bagian ini punya tabel buat
    // ditempelin — kalau nggak ada tabel sama sekali, dibiarin lewat jalur
    // lama (render di daftar field) daripada ilang diam-diam.
    final grupField = _kelompokkanField(bagian.field);
    final grupTitik = <int, List<List<FieldLembarKerja>>>{};
    if (bagian.tabel.isNotEmpty) {
      for (final grup in grupField) {
        final indeks = _indeksTitik(grup.first);
        if (indeks != null) (grupTitik[indeks] ??= []).add(grup);
      }
    }
    final urutanTitik = grupTitik.keys.toList()..sort();

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

            if (bagian.belumBisaDiisi)
              _BagianTanpaInput(catatan: bagian.catatan)
            else if (bagian.kode == 'usage_check')
              _UsageCheck(bagian: bagian, isian: isian, onBerubah: onBerubah)
            else ...[
              // Kondisi lingkungan di kertas itu TABEL, bukan empat kotak
              // bertumpuk: baris `First`/`End`, kolom `Temperature`/`Humidity`.
              // Digambar sekali di sini, lalu keempat kolomnya dilewati di
              // perulangan bawah.
              if (_kondisiLingkungan(bagian.field) != null) ...[
                _TabelKondisiLingkungan(
                  field: _kondisiLingkungan(bagian.field)!,
                  isian: isian,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              for (final grup in grupField) ...[
                if (_kodeKondisiLingkungan.contains(grup.first.kode))
                  const SizedBox.shrink()
                else if (_indeksTitik(grup.first) != null &&
                    bagian.tabel.isNotEmpty)
                  // Ditunda: digambar nempel ke tabel titiknya, lihat di
                  // bawah — bukan di sini.
                  const SizedBox.shrink()
                else
                // Seluruh blok spesifikasi digambar bentuk cetak — termasuk
                // yang cuma sekotak (`Kapasitas Max.`), biar ketiga barisnya
                // sejajar kayak di kertas dan bukan campur dua gaya.
                // Kolom bersyarat yang syaratnya lagi nggak kepenuhan —
                // `Ruangan` waktu Insitu, `Nama Tempat` waktu Inlab. Aturannya
                // dibaca dari `tampil_kalau` yang dibawa bentuk lembar, jadi
                // layar ini nggak kenal satu pun nama kolom. Nilainya SEKALIAN
                // dikosongin di `bersihkanFieldTersembunyi` — disembunyiin doang
                // itu yang dulu bikin sertifikat Insitu kecetak nama ruang lab.
                if (!isian.fieldTampil(grup.first))
                  const SizedBox.shrink()
                // Jaring buat server yang belum ngirim `tampil_kalau` sama
                // sekali: aturan lama yang nge-hardcode `lokasi_nama` tetap
                // jalan, jadi APK baru + backend lama nggak nanyain nama tempat
                // ke sesi in-lab. Dicabut begitu semua server produksi udah
                // ngirim penandanya.
                else if (grup.first.tampilKalau == null &&
                    grup.first.kode == 'lokasi_nama' &&
                    isian.lokasi != LokasiKalibrasi.onsite)
                  const SizedBox.shrink()
                // `Set Point` digambar menyatu sama kepala matriks, persis
                // posisinya di pojok kiri-atas tabel di kertas. Dilewat di
                // sini biar nggak muncul dua kali.
                else if (bagian.matriks != null &&
                    grup.first.kode == 'set_point')
                  const SizedBox.shrink()
                else if (grup.first.spesifikasiAlat)
                  _BarisSpesifikasi(
                    field: grup,
                    isian: isian,
                    onBerubah: onBerubah,
                  )
                else
                  _Field(field: grup.first, isian: isian, onBerubah: onBerubah),
                const SizedBox(height: AppSpacing.md),
              ],
            ],

            // Pindai lembar penuh (OCR lokal) — di atas tabelnya, karena dia
            // ngisi SELURUH tabel sekaligus, bukan satu tabel.
            //
            // Digantung di `--dart-define=PINDAI_LEMBAR` (default MATI). Yang
            // dimatiin cuma render-nya: `_TombolPindaiLembar` di bawah dan
            // seluruh mesin geometrinya tetap dikompilasi & tetap dites.
            // Lihat `AppConfig.pindaiLembarAktif` buat alasan lengkapnya.
            if (pindaiAktif && bagian.tabel.isNotEmpty)
              _TombolPindaiLembar(
                profil: profil,
                equipmentId: isian.alat?.id,
                sesiId: sesiId,
                isian: isian,
                onBerubah: onBerubah,
              ),

            // Lembar ber-GRID (Enclosure) menggambar gridnya di sini, dan
            // memang nggak punya `tabel` maupun `matriks` buat digambar
            // sesudahnya — bentuknya cuma mengirim kolom identitas plus
            // `grid_sensor`. Merk kalibrator dibaca dari standar yang lagi
            // dipilih; itu yang menentukan kolom Channel muncul atau nggak.
            if (gambarGrid && isian.grid != null) ...[
              LembarKerjaGrid(
                state: isian.grid!,
                satuanSuhu: isian.bentuk.satuanSuhu,
                onBerubah: onBerubah,
                merkKalibrator: _merkStandar(ref, isian.standardId),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isian.bentuk.catatanPengisian.isNotEmpty)
                _CatatanIsi(catatan: isian.bentuk.catatanPengisian),
            ],

            // Bagian bermatriks menggambar matriksnya, BUKAN `bagian.tabel`.
            //
            // Autoklaf mengirim dua-duanya buat dua pembaca yang beda:
            // `matriks` buat layar teknisi, `tabel` buat pipeline OCR — bentuk
            // "baris × pengulangan" yang `titik_ukur`-nya nol semua, dibikin
            // supaya rangka geometri lembar cetaknya bisa lahir. Digambar
            // dua-duanya, teknisi lihat tabel yang sama dua kali dan yang satu
            // barisnya tanpa nama.
            if (bagian.matriks != null) ...[
              LembarKerjaMatriks(
                matriks: bagian.matriks!,
                isian: isian,
                onBerubah: onBerubah,
                tabelTambahan: bagian.tabelTambahan,
                setPoint: _fieldSetPoint(bagian),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (bagian.fieldDiLuarKertas.isNotEmpty) ...[
                _FieldDiLuarKertas(
                  field: bagian.fieldDiLuarKertas,
                  isian: isian,
                  onBerubah: onBerubah,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ] else
            for (var i = 0; i < bagian.tabel.length; i++) ...[
              // Daftar titik diatur SEKALI di atas tabel pertama, bukan per
              // tabel: satu daftar berlaku buat Before & After sekaligus.
              // Cuma muncul di lembar yang backend-nya bilang titiknya boleh
              // diubah (TITS); sepuluh alat lain nggak berubah tampilannya.
              if (i == 0 && bagian.tabel[i].titikBisaDiubah) ...[
                PengaturTitik(isian: isian, onBerubah: onBerubah),
                const SizedBox(height: AppSpacing.lg),
              ],
              LembarKerjaTabel(
                tabel: bagian.tabel[i],
                isian: isian,
                onBerubah: onBerubah,
                // Saklar DAN bentuk kertasnya. Saklar bilang "fitur ini
                // nyala"; `fotoTabelDidukung` bilang "kertas alat INI bisa
                // dituturkan ke pembaca foto". Dua-duanya harus benar —
                // saklar nyala doang bikin tombolnya muncul di lembar
                // Autoklaf & TIDS, dan yang balik ke teknisi bukan error tapi
                // angka ngawur yang kelihatan wajar.
                pindaiAktif: pindaiAktif && isian.bentuk.fotoTabelDidukung,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Spindle/RPM/Resolusi tiap titik ditempel di sini, sesudah
              // tabel PERTAMA — persis posisinya di kertas: langsung di
              // bawah `Standard`/`UUT Reading` titik itu, bukan dikumpulin
              // jauh di atas kedua tabel. Sekali aja (nggak diulang lagi
              // sesudah tabel After Adjustment): datanya milik titik, bukan
              // milik tahap — spindle & RPM yang dipakai sama buat before
              // maupun after.
              if (i == 0 && urutanTitik.isNotEmpty) ...[
                for (final indeks in urutanTitik) ...[
                  for (final grup in grupTitik[indeks]!) ...[
                    _BarisSpesifikasi(
                      field: grup,
                      isian: isian,
                      onBerubah: onBerubah,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ],

            // Catatan pengisian diulang di bawah tabel, bukan cuma di kop
            // dokumen. Kopnya ada di paling atas; waktu teknisi lagi ngisi
            // kotak angka dia udah discroll jauh dari situ, dan buat
            // Refractometer kalimat itu yang ngasih tahu kolom °C bukan
            // pelengkap — pembacaan yang suhunya kosong nggak bisa
            // dinormalisasi ke 20 °C.
            //
            // Kalimatnya diambil dari backend (`catatan_pengisian`), jadi tiap
            // alat dapat catatannya sendiri dan layar ini nggak perlu tahu alat
            // mana yang suhunya ikut dihitung.
            if (bagian.tabel.isNotEmpty && isian.bentuk.catatanPengisian.isNotEmpty)
              _CatatanIsi(catatan: isian.bentuk.catatanPengisian),

            // Jaraknya ikut di dalam panel, bukan di sini: panel yang lagi
            // kosong (belum ada isian, atau belum ada balasan) mesti nggak
            // makan ruang sama sekali — kalau nggak, seluruh bagian di
            // bawahnya kegeser buat sesuatu yang nggak kelihatan.
            // Panel hasil ikut bentuk lembarnya. Lembar bermatriks dihitung
            // endpoint lain dan jawabannya juga beda bentuk (Kestabilan /
            // Keseragaman / Variasi, bukan koreksi per titik) — dipaksa lewat
            // panel titik, yang kelihatan cuma kotak kosong.
            if (bagian.matriks != null)
              const _PanelHasilMatriks()
            else if (bagian.tabel.isNotEmpty)
              _PanelPratinjau(isian: isian),
          ],
        ),
      ),
    );
  }

  /// Merk standar yang lagi dipilih, buat menentukan kolom Channel.
  ///
  /// Null waktu daftar standarnya belum kebaca ATAU belum ada yang dipilih —
  /// dan dua-duanya sengaja berujung "belum tahu", bukan "nggak butuh kanal".
  /// Kolom Channel yang muncul belakangan lebih baik daripada kolom yang
  /// terlanjur disembunyikan buat kalibrator yang sebenarnya butuh.
  static String? _merkStandar(WidgetRef ref, int? standardId) {
    if (standardId == null) return null;
    final daftar = ref.watch(standardListProvider).value;
    if (daftar == null) return null;
    for (final s in daftar) {
      if (s.id == standardId) return s.merk;
    }
    return null;
  }
}

/// Catatan pengisian yang ditaruh nempel di bawah tabel hasil.
///
/// Nadanya sengaja **ngasih tahu, bukan ngelarang**: nggak ada kotak yang
/// ditandai merah dan nggak ada yang ngunci tombol kirim. Lembar setengah jadi
/// tetap boleh dikirim dari lapangan — itu aturan lembar kerja yang nggak
/// berubah sejak awal, dan penjagaannya ada di pemeriksaan admin.
class _CatatanIsi extends StatelessWidget {
  const _CatatanIsi({required this.catatan});

  final String catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            catatan,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}


/// Tombol pindai LEMBAR PENUH — satu-satunya jalur kamera yang dipakai app ini.
///
/// ANGKANYA dibaca DI HP (ML Kit on-device): nggak ada panggilan ke layanan AI
/// pihak ketiga, nggak ada biaya per foto, dan pembacaannya jalan tanpa sinyal.
/// Endpoint AI lama (`POST /raw-measurements/extract-from-photo`) masih hidup di
/// server tapi app ini nggak pernah manggilnya lagi — jangan hidupkan lagi tanpa
/// membaca ulang docblock-nya di backend.
///
/// **Yang dikirim ke server bukan cuma angkanya.** `POST /worksheet-scans` juga
/// mengunggah citra lembar yang sudah diratakan; server menyimpannya dan
/// menyajikannya lagi per sel supaya layar review bisa nampilin tulisan aslinya
/// di sebelah angka tebakan. Jadi "dibaca di HP" bukan berarti fotonya nggak
/// keluar HP — retensinya diatur `config/ocr.php` di backend. Ditulis terang di
/// sini karena versi sebelumnya menjanjikan sebaliknya.
///
/// Syarat teknisnya satu: koordinat tiap sel harus sudah diukur dari formulir
/// CETAK asli, dan formulirnya dicetak ulang pakai 4 penanda sudut + QR versi.
///
/// **`siap_pindai` dari server yang mutusin tombol ini hidup atau mati.** Per
/// 20 Agu 2026 enam lembar sudah `terverifikasi` (pH, Turbidimeter, Chlorine,
/// Refractometer, Conductivity, Spectrophotometer); Viscometer masih
/// `geometri_belum_diverifikasi` dan Autoklaf masih menunggu geometrinya diadu
/// ke lembar cetak. Koordinat tebakan berarti angka mendarat di sel yang salah,
/// dan itu justru kegagalan yang mau dicegah fitur ini. Alasannya ditampilin apa
/// adanya, bukan diterjemahin jadi "fitur belum tersedia": teknisi berhak tahu
/// yang kurang itu apa, dan yang bisa nutup cuma lab (cetak ulang formulir +
/// ukur).
class _TombolPindaiLembar extends ConsumerStatefulWidget {
  const _TombolPindaiLembar({
    required this.profil,
    required this.equipmentId,
    required this.isian,
    required this.onBerubah,
    this.sesiId,
  });

  final String profil;
  final int? equipmentId;

  /// Sesi yang lagi dikerjakan. Boleh `null` — teknisi kadang memindai sebelum
  /// sesinya dibikin, dan server memang menerima kiriman tanpa sesi.
  final int? sesiId;

  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  ConsumerState<_TombolPindaiLembar> createState() =>
      _TombolPindaiLembarState();
}

class _TombolPindaiLembarState extends ConsumerState<_TombolPindaiLembar> {
  bool _sibuk = false;

  /// Foto → baca QR → ratakan → potong tiap sel → baca ML Kit → kirim → layar
  /// review → angkanya masuk formulir.
  ///
  /// Urutannya ada di [JalankanPindai], bukan di sini: yang di layar cuma
  /// ambil fotonya, tampilkan sibuknya, terjemahkan sebabnya kalau gagal, dan
  /// nuang angka yang teknisi setujui.
  Future<void> _pindai(WorksheetTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sibuk = true);

    try {
      // Lembar penuh, jadi resolusinya dipertahankan: yang dibaca ML Kit itu
      // potongan sel selebar ~140 px di ruang template, dan tiap piksel yang
      // dibuang di sini hilang dari angka yang dibaca.
      final foto = await ref
          .read(sumberFotoProvider)
          .ambil(maxWidth: 4200, imageQuality: 100);

      if (foto == null || !mounted) return;

      final citra = img.decodeImage(await foto.readAsBytes());

      if (citra == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkPindaiGagalFoto)));

        return;
      }

      final pabrik = ref.read(pabrikPembacaPindaiProvider);
      final pembaca = pabrik.sel();
      final pembacaQr = pabrik.qr();

      try {
        final susunan = await JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: pembaca,
          pembacaQr: pembacaQr,
        ).susun(
          citra,
          template: template,
          calibrationSessionId: widget.sesiId,
          equipmentId: widget.equipmentId,
        );

        final token = await ref.read(tokenStorageProvider).read();
        if (token == null || !mounted) return;

        final hasil = await ref
            .read(worksheetScanServiceProvider)
            .kirim(
              token,
              susunan.body,
              // Lampiran audit — dan sumber potongan sel di layar review.
              // Boleh gagal naik; hasil bacanya nggak ikut batal.
              citraWarp: pngDari(susunan.citraWarp),
            );

        if (!mounted) return;

        final dipakai = await navigator.push<List<SelDipakaiPindai>>(
          MaterialPageRoute<List<SelDipakaiPindai>>(
            builder: (_) => PindaiReviewScreen(hasil: hasil),
          ),
        );

        if (dipakai == null || dipakai.isEmpty || !mounted) return;

        final terisi = widget.isian.terapkanHasilPindai(dipakai);
        widget.onBerubah();

        messenger.showSnackBar(
          SnackBar(content: Text(l10n.lkPindaiTerpakai(terisi))),
        );
      } finally {
        await pembaca.tutup();
        await pembacaQr.tutup();
      }
    } on PindaiGagal catch (e) {
      // Sebabnya ditampilkan, bukan "gagal memindai": sebagian besar sebab
      // nggak akan membaik dengan mengulang jepretan, dan teknisi yang motret
      // ulang lima kali buat lembar yang memang nggak ber-QR itu kerugian yang
      // nggak kelihatan di mana pun.
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(switch (e.sebab) {
            GagalPindai.belumSiap =>
              l10n.lkPindaiBelumSiap(template.alasanBelumSiap ?? '—'),
            GagalPindai.tanpaGeometri => l10n.lkPindaiTanpaGeometri,
            GagalPindai.markerTidakKetemu => l10n.lkPindaiMarkerHilang,
            GagalPindai.geometriMeleset => l10n.lkPindaiTerlaluMiring,
            GagalPindai.qrTidakKebaca => l10n.lkPindaiQrHilang,
            GagalPindai.qrLembarLain => l10n.lkPindaiQrLembarLain,
            GagalPindai.mutuBuram => l10n.lkPindaiBuram,
            GagalPindai.mutuGelap => l10n.lkPindaiGelap,
            GagalPindai.mutuSilau => l10n.lkPindaiSilau,
            GagalPindai.mutuPantulan => l10n.lkPindaiPantulan,
            GagalPindai.mutuMiring => l10n.lkPindaiTerlaluMiring,
            GagalPindai.mutuKejauhan => l10n.lkPindaiKejauhan,
          }),
        ),
      );
    } on PindaiDitolak catch (e) {
      // Pesan server ditampilkan APA ADANYA — kalimatnya sudah ditulis buat
      // teknisi yang lagi berdiri di depan alat pelanggan. Nggak ada satu
      // angka pun yang dipakai dari lembar yang ditolak.
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            e.bugAplikasi ? l10n.lkPindaiBugAplikasi(e.pesan) : e.pesan,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkPindaiGagalFoto)));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final template = ref.watch(
      worksheetTemplateProvider((
        kode: widget.profil,
        equipmentId: widget.equipmentId,
      )),
    );

    // Gagal narik template NGGAK ditampilin sebagai error: ini jalan pintas,
    // bukan jalur kerja. Yang nggak boleh cuma satu — nampilin tombol aktif
    // buat lembar yang belum boleh dipindai.
    final data = template.value;

    // **Tombolnya selalu digambar**, bahkan waktu templatenya gagal diambil.
    //
    // Dulu di sini `return const SizedBox.shrink()` — dan itu bikin satu
    // kegagalan kecil di jaringan/URL berubah jadi FITURNYA HILANG DARI LAYAR
    // tanpa satu pun pesan. Yang kejadian 14 Agt 2026: layar ngirim nomor
    // formulir (`SIDIK-IK-CAL-0508_Rev.4`) ke endpoint yang mau kode alat, jadi
    // 404 — dan dari mata teknisi, tombol pindainya kelihatan nggak pernah
    // dibikin. Nggak ada error, nggak ada tombol mati, nggak ada apa-apa.
    //
    // Sekarang: gagal ambil template = tombol MATI + alasannya kelihatan.
    // Nggak bisa dipakai tetap nggak bisa dipakai, tapi setidaknya kelihatan
    // ADA dan kelihatan KENAPA.
    final alasan = switch ((data, template)) {
      (final WorksheetTemplate t, _) when !t.siapPindai =>
        l10n.lkPindaiBelumSiap(t.alasanBelumSiap ?? '—'),
      (null, AsyncError(:final error)) => l10n.lkPindaiTemplateGagal('$error'),
      (null, _) => l10n.lkPindaiTemplateMemuat,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (data?.siapPindai ?? false) && !_sibuk
                ? () => _pindai(data!)
                : null,
            icon: _sibuk || template.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined, size: 18),
            label: Text(l10n.lkPindaiLembar),
          ),
        ),
        if (alasan != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            alasan,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Hasil hitung sementara dari `POST /calibrations/preview`.
///
/// Ada supaya teknisi lihat angkanya SEBELUM lembarnya masuk antrean approval.
/// Sebelum ini satu-satunya cara tau hasilnya adalah ngirim sesinya, dan sesi
/// yang salah titik cuma bisa dibetulin lewat jalur revisi admin — bolak-balik
/// yang makan sehari buat kesalahan ketik lima detik.
///
/// **Nggak ada satu pun rumus di sini.** Rata-rata, koreksi, dan U95 semuanya
/// dari backend. Buat alat yang U95-nya lahir per kelompok (Spectrophotometer),
/// angkanya bahkan nggak bisa diturunkan dari satu titik: yang masuk budget itu
/// STDEV TERBESAR sekelompok, jadi baris yang barusan diketik bisa ngubah U95
/// sembilan baris lain.
///
/// Titik yang U95-nya kembar SENGAJA nggak digabung. Sepuluh titik Holmium
/// dengan `0,43255708` yang sama persis itu hasil yang bener, bukan data dobel,
/// dan ngeringkasnya jadi satu baris bikin teknisi ngira sembilan titiknya
/// nggak kehitung.
/// Panel hasil buat lembar bermatriks (Autoklaf).
///
/// Isinya jawaban `POST /calibrations/autoclave/preview` — Kestabilan,
/// Keseragaman, Variasi — bukan koreksi per titik ukur. Bentuknya beda sampai
/// ke akarnya dari [_PanelPratinjau], jadi dipisah widget, bukan ditekuk.
class _PanelHasilMatriks extends ConsumerWidget {
  const _PanelHasilMatriks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(autoclavePratinjauProvider);
    final theme = Theme.of(context);

    if (status.hasil == null && !status.menghitung && status.gagal == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status.gagal != null)
            Text(
              AppLocalizations.of(context).acGagalMenghitung('${status.gagal}'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (status.hasil != null)
            AutoclaveHasilPanel(hasil: status.hasil!),
        ],
      ),
    );
  }
}

class _PanelPratinjau extends ConsumerWidget {
  const _PanelPratinjau({required this.isian});

  final LembarKerjaState isian;

  /// Desimal titik ini: dari backend dulu, baru dari bentuk lembar.
  ///
  /// Kalau dua-duanya diam, angkanya ditulis apa adanya ([formatNilai]) — bukan
  /// dipatok dua desimal. Mbulatin ke angka karangan di layar yang dipakai
  /// mriksa hasil itu kebalikan dari gunanya panel ini.
  String _tulis(MeasurementResult titik, double nilai) {
    final desimal = titik.desimal ?? isian.titik[titik.titikUkur]?.desimal;

    return desimal == null
        ? formatNilai(nilai)
        : formatSertifikat(nilai, desimal, tandaNol: titik.tandaNol);
  }

  /// Label baris di lembar buat titik ke-[titikKe] (1-based, urutan kiriman).
  ///
  /// `belum_dihitung` cuma bawa nomor urut, dan "Titik ke-13" nggak nolong
  /// siapa-siapa di lembar 24 baris. Urutan `titikUrut` sama persis sama urutan
  /// `measurements` yang barusan dikirim — dua-duanya dari `titik.values`.
  String? _labelTitik(int titikKe) {
    final urut = isian.titikUrut;
    if (titikKe < 1 || titikKe > urut.length) return null;

    final t = urut[titikKe - 1];

    return t.satuan.isEmpty ? t.label : '${t.label} ${t.satuan}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(pratinjauProvider);
    final hasil = status.hasil;

    if (hasil == null || hasil.kosong) return const SizedBox.shrink();

    // Kelompok diambil dari `remark` yang dikirim backend, BUKAN ditebak dari
    // besar angkanya: rentang Holmium (283–641 nm) & Didynium (474–810 nm)
    // tumpang tindih 167 nm, jadi 513,7 nm kelihatan kayak Holmium padahal dia
    // Didynium — dan U95 yang nempel jadi punya kelompok yang salah.
    //
    // Urutannya ngikut urutan titik, bukan diurut abjad: itu urutan lembarnya.
    final kelompok = <String?, List<MeasurementResult>>{};
    for (final t in hasil.titik) {
      kelompok.putIfAbsent(t.remark, () => []).add(t);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.lkPratinjauJudul,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              // Angka lama tetap kelihatan selama yang baru dihitung — yang
              // nambah cuma penanda sibuk di pojok.
              if (status.menghitung)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.lkPratinjauCatatan,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          for (final e in kelompok.entries) ...[
            const SizedBox(height: AppSpacing.sm),
            // Alat tanpa kelompok (pH, Turbidimeter, …) ngirim `remark: null` —
            // kolomnya dikosongin, bukan dikasih judul karangan.
            if (e.key != null && e.key!.isNotEmpty) ...[
              Text(
                e.key!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            _TabelPratinjau(
              titik: e.value,
              tulis: _tulis,
              satuanTitik: (t) => t.satuan ?? isian.titik[t.titikUkur]?.satuan ?? '',
            ),
          ],

          if (hasil.belumDihitung.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.lkPratinjauBelumDihitung,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Alasannya dari backend, ditampilin apa adanya. Lembar setengah
            // isi tetap boleh dikirim — ini kabar, bukan penghalang — tapi tiap
            // titik kosong NGURANGI dasar hitung kelompoknya, dan itu yang
            // nggak kelihatan dari tabel yang barisnya keliatan wajar.
            for (final b in hasil.belumDihitung)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '${_labelTitik(b.titikKe) ?? l10n.lkPratinjauTitikKe(b.titikKe)} — ${b.alasan}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Tabel angka pratinjau satu kelompok.
class _TabelPratinjau extends StatelessWidget {
  const _TabelPratinjau({
    required this.titik,
    required this.tulis,
    required this.satuanTitik,
  });

  final List<MeasurementResult> titik;
  final String Function(MeasurementResult, double) tulis;
  final String Function(MeasurementResult) satuanTitik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final gayaKepala = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final gayaAngka = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    TableRow baris(List<Widget> sel) => TableRow(children: [
      for (final s in sel)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: s,
        ),
    ]);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        baris([
          Text(l10n.lkPratinjauKolomTitik, style: gayaKepala),
          Text(l10n.lkPratinjauKolomRata, style: gayaKepala, textAlign: TextAlign.right),
          Text(l10n.lkPratinjauKolomKoreksi, style: gayaKepala, textAlign: TextAlign.right),
          Text(l10n.lkPratinjauKolomU95, style: gayaKepala, textAlign: TextAlign.right),
        ]),
        for (final t in titik)
          baris([
            Text(
              '${tulis(t, t.titikUkur)} ${satuanTitik(t)}'.trim(),
              style: gayaAngka,
            ),
            Text(tulis(t, t.rataRata), style: gayaAngka, textAlign: TextAlign.right),
            Text(tulis(t, t.koreksi), style: gayaAngka, textAlign: TextAlign.right),
            Text(
              tulis(t, t.ketidakpastianDiperluas),
              style: gayaAngka,
              textAlign: TextAlign.right,
            ),
          ]),
      ],
    );
  }
}

/// Bagian yang ADA di lembar kertas tapi belum punya sumber angka yang sah
/// (`status: sumber_belum_ada`).
///
/// Dua jalan pintas yang sama-sama salah dihindari di sini. Nyembunyiin
/// bagiannya bikin teknisi ngira layarnya kurang — dia nyariin, karena blok itu
/// tercetak di lembar kertas yang dia pegang. Nyediakan kotak kosong bikin dia
/// ngetik angka yang nggak akan pernah nyampe: backend nggak nerima field apa
/// pun dari bagian ini, jadi isiannya ilang tanpa jejak.
///
/// Jadi: kelihatan, berlabel, dengan alasan dari backend apa adanya — dan tanpa
/// satu pun kotak yang bisa disentuh.
class _BagianTanpaInput extends StatelessWidget {
  const _BagianTanpaInput({required this.catatan});

  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.lkBagianBelumBisaDiisi,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (catatan != null && catatan!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              catatan!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// Kolom yang di lembar cetak digambar SEBARIS dikelompokkan di sini.
///
/// Cuma berlaku buat `spesifikasi_alat.*` yang labelnya sama & berurutan —
/// `2. Rentang Ukur` punya dua kotak (`0-100 %T` dan `200-700 nm`), dan di
/// kertas dua-duanya di satu baris, di kanan satu label.
///
/// Sengaja NGGAK digeneralisasi ke semua kolom berlabel kembar: pasangan
/// "Env. Condition — First" (°C / %RH) juga berlabel sama, dan bentuk
/// bertumpuknya udah dipakai lima alat lain. Yang berubah cuma blok yang
/// backend-nya emang minta bentuk cetak.
/// Empat kolom yang di kertas jadi satu tabel Environment Condition.
///
/// Kunci payload-nya sama di keenam alat, jadi dicocokkan lewat kode — bukan
/// lewat label, yang tiap profil menulisnya sedikit berbeda ("Env. Condition —
/// First", "Suhu Ruangan").
const _kodeKondisiLingkungan = {
  'suhu_awal',
  'kelembaban_awal',
  'suhu_akhir',
  'kelembaban_akhir',
  // Cuma Gas Detector yang ngirim dua ini. Ikut didaftarin di sini supaya
  // mereka nggak digambar DUA KALI: sekali sebagai kolom ketiga tabel, sekali
  // lagi sebagai kotak lepas di perulangan bawah.
  'tekanan_awal',
  'tekanan_akhir',
};

/// Keempat kolom kondisi lingkungan, atau `null` kalau bagian ini nggak punya
/// keempat-empatnya.
///
/// Sengaja semua-atau-nggak-sama-sekali: tabel yang separuh kotaknya hilang
/// lebih membingungkan daripada empat kotak bertumpuk seperti dulu.
({
  FieldLembarKerja suhuAwal,
  FieldLembarKerja kelembabanAwal,
  FieldLembarKerja suhuAkhir,
  FieldLembarKerja kelembabanAkhir,
  FieldLembarKerja? tekananAwal,
  FieldLembarKerja? tekananAkhir,
})? _kondisiLingkungan(List<FieldLembarKerja> field) {
  FieldLembarKerja? cari(String kode) {
    for (final f in field) {
      if (f.kode == kode) return f;
    }

    return null;
  }

  final suhuAwal = cari('suhu_awal');
  final kelembabanAwal = cari('kelembaban_awal');
  final suhuAkhir = cari('suhu_akhir');
  final kelembabanAkhir = cari('kelembaban_akhir');

  if (suhuAwal == null ||
      kelembabanAwal == null ||
      suhuAkhir == null ||
      kelembabanAkhir == null) {
    return null;
  }

  // Tekanan udara OPSIONAL, dan sepasang-sepasang: satu kolom yang cuma punya
  // baris First tanpa End itu setengah tabel, dan setengah tabel lebih bikin
  // ragu daripada nggak ada kolomnya sama sekali.
  final tekananAwal = cari('tekanan_awal');
  final tekananAkhir = cari('tekanan_akhir');
  final adaTekanan = tekananAwal != null && tekananAkhir != null;

  return (
    suhuAwal: suhuAwal,
    kelembabanAwal: kelembabanAwal,
    suhuAkhir: suhuAkhir,
    kelembabanAkhir: kelembabanAkhir,
    tekananAwal: adaTekanan ? tekananAwal : null,
    tekananAkhir: adaTekanan ? tekananAkhir : null,
  );
}

/// Kolom `spesifikasi_alat.*_titik_N` — Spindle/RPM/Resolusi Viscometer,
/// satu set per titik ukur. Dipakai buat naruh grupnya NEMPEL ke tabel
/// titik itu ([_Bagian.build]), bukan numpuk di atas kedua tabel kayak
/// kolom spesifikasi lain: lihat `perintah-frontend-viscometer.md` §5.2 —
/// di kertas cetaknya, `Resolusi UUT` / `Rpm used` / `Spindle used` ada
/// PERSIS di bawah tabel `Standard`/`UUT Reading` titik itu.
final _polaTitik = RegExp(r'_titik_(\d+)$');

int? _indeksTitik(FieldLembarKerja field) {
  if (!field.spesifikasiAlat) return null;
  final cocok = _polaTitik.firstMatch(field.kunciSpesifikasi);
  return cocok == null ? null : int.parse(cocok.group(1)!);
}

List<List<FieldLembarKerja>> _kelompokkanField(List<FieldLembarKerja> field) {
  final hasil = <List<FieldLembarKerja>>[];

  for (final f in field) {
    final akhir = hasil.isEmpty ? null : hasil.last;
    final gabung = akhir != null &&
        f.spesifikasiAlat &&
        akhir.first.spesifikasiAlat &&
        akhir.first.label == f.label;

    if (gabung) {
      akhir.add(f);
    } else {
      hasil.add([f]);
    }
  }

  return hasil;
}

/// Satu baris spesifikasi alat: satu label, beberapa kotak bersatuan.
///
/// Bentuknya niru lembar cetak — `Rentang Ukur : [0-100] %T [200-700] nm`.
/// Isinya teks apa adanya, bukan angka: `0-100` emang bukan bilangan, dan yang
/// tercetak di sertifikat juga teks.
/// `Set Point` digambar MENYATU sama kepala tabel, bukan di daftar kolom biasa.
///
/// Di kertas Autoklaf angka itu duduk di pojok kiri-atas tabel, sebaris sama
/// banner kolom — bukan di panel identitas alat di atasnya. Ditarik keluar di
/// sini supaya nggak digambar dua kali.
FieldLembarKerja? _fieldSetPoint(BagianLembarKerja bagian) {
  for (final f in bagian.field) {
    if (f.kode == 'set_point') return f;
  }
  return null;
}

/// Kolom yang **nggak ada di lembar kertas** tapi dibutuhkan olah datanya.
///
/// Dipisah dengan penanda, bukan dicampur ke kolom lain: teknisi yang nyocokin
/// layar ke kertasnya bakal nyariin kolom ini di lembar dan nggak nemu. Tanpa
/// penanda dia bakal ngira layarnya rusak — atau lebih buruk, ngira kolomnya
/// boleh dilewat, padahal olah data tekanan nggak jalan tanpa itu.
class _FieldDiLuarKertas extends StatelessWidget {
  const _FieldDiLuarKertas({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final List<FieldLembarKerja> field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Di luar kertas',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Aturan tampil bersyarat yang sama kayak kolom di kertas — panel ini
        // nyimpen nilainya di slot yang sama, jadi kalau dilewat di sini kolom
        // bersyarat pertama yang mendarat di panel ini bakal kegambar terus.
        for (final f in field.where(isian.fieldTampil)) ...[
          _Field(field: f, isian: isian, onBerubah: onBerubah),
          if (f.catatan != null) ...[
            const SizedBox(height: 4),
            Text(
              f.catatan!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _BarisSpesifikasi extends StatelessWidget {
  const _BarisSpesifikasi({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final List<FieldLembarKerja> field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.first.label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in field) ...[
              if (f != field.first) const SizedBox(width: AppSpacing.sm),
              Expanded(
                // Spindle & Model Viscometer nyampe ke sini sebagai
                // `spesifikasi_alat.*` bertipe pilihan — daftarnya 63 opsi
                // (SMC-nya beda 400× antar spindle) dan HARUS dropdown, bukan
                // isian bebas: lihat `perintah-frontend-viscometer.md` §3.1.
                child: f.tipe == TipeField.pilihan
                    ? _DropdownSpesifikasi(
                        field: f,
                        controller: isian.teks[f.kode]!,
                        onBerubah: onBerubah,
                      )
                    : TextField(
                        controller: isian.teks[f.kode],
                        decoration: InputDecoration(
                          // Labelnya udah ditulis sekali di atas — yang di
                          // dalam kotak tinggal satuannya, persis kertasnya.
                          labelText: f.satuan,
                          border: const OutlineInputBorder(),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Dropdown buat `spesifikasi_alat.*` bertipe pilihan (Model & Spindle
/// Viscometer). Nilai kepilih ditulis ke [controller] apa adanya — kunci
/// payloadnya udah lewat `kunciSpesifikasi`, bukan `f.kode`, jadi widget ini
/// nggak perlu tahu bentuk payloadnya.
class _DropdownSpesifikasi extends StatelessWidget {
  const _DropdownSpesifikasi({
    required this.field,
    required this.controller,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final TextEditingController controller;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    // Nilai lama yang nggak ketemu di daftar pilihan dibiarin kosong, bukan
    // dipaksa masuk — `DropdownButtonFormField` nge-assert kalau nilainya
    // nggak cocok persis salah satu item, dan itu bikin layarnya mati total.
    final terpilih = field.pilihan.any((p) => p.nilai == controller.text)
        ? controller.text
        : null;

    return DropdownButtonFormField<String>(
      initialValue: terpilih,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        for (final p in field.pilihan)
          DropdownMenuItem(value: p.nilai, child: Text(p.label)),
      ],
      onChanged: (value) {
        if (value == null) return;
        controller.text = value;
        onBerubah();
      },
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
      final readonly = _Readonly(
        label: field.label,
        nilai: isian.nilaiTurunan(
          field.kode,
          namaTeknisi: user?.nama,
          kodeTeknisi: user?.kodeTeknisi,
        ),
        satuan: field.satuan,
      );

      // Volume enclosure beda dari kolom otomatis lain: sumbernya BUKAN data
      // yang sudah jadi (alat, akun), tapi kotak yang lagi diketik teknisi
      // detik ini juga.
      //
      // Kotak isian biasa (`_Isian`) nyimpen isinya di controller-nya sendiri
      // dan NGGAK manggil `onBerubah` tiap ketukan — sengaja, biar lembar
      // 87 kotak nggak digambar ulang tiap huruf. Efek sampingnya: tanpa
      // penyambung ini, teknisi ngetik P/L/T dan kotak Volume-nya diam aja.
      // Nggak error, nggak kosong — cuma nggak pernah keisi, dan kelihatannya
      // seperti fitur yang rusak.
      //
      // Jadi kotak ini nempel langsung ke lima controller yang jadi bahannya.
      // Yang digambar ulang cuma dia sendiri, bukan seluruh lembar.
      if (field.kode == 'dimensi.volume') {
        final bahan = <Listenable>[
          for (final k in const [
            'dimensi_panjang',
            'dimensi_lebar',
            'dimensi_tinggi',
            'dimensi_jari_jari',
            'dimensi_tinggi_silinder',
          ])
            if (isian.teks[k] != null) isian.teks[k]!,
        ];

        if (bahan.isEmpty) return readonly;

        return ListenableBuilder(
          listenable: Listenable.merge(bahan),
          builder: (_, _) => _Readonly(
            label: field.label,
            nilai: isian.nilaiTurunan(field.kode),
            satuan: field.satuan,
          ),
        );
      }

      return readonly;
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

/// Environment Condition, digambar seperti di lembar cetak.
///
/// Kertasnya (lihat `SIDIK-FM-CAL-0511_Rev.5` & `…0510_Rev.5`) menaruhnya
/// sebagai tabel: baris `First`/`End`, kolom `Temperature`/`Humidity`, satuan
/// tercetak di sel sendiri di kanan tiap angka. Layar dulu menumpuk keempat
/// kolomnya sebagai empat baris berlabel "Env. Condition — First" — isinya
/// sama, tapi teknisi yang menyalin dari kertas harus mencari-cari mana yang
/// suhu dan mana yang kelembaban.
class _TabelKondisiLingkungan extends StatelessWidget {
  const _TabelKondisiLingkungan({required this.field, required this.isian});

  final ({
    FieldLembarKerja suhuAwal,
    FieldLembarKerja kelembabanAwal,
    FieldLembarKerja suhuAkhir,
    FieldLembarKerja kelembabanAkhir,
    FieldLembarKerja? tekananAwal,
    FieldLembarKerja? tekananAkhir,
  })
  field;

  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final garis = BorderSide(color: theme.colorScheme.outlineVariant);

    // Dua-duanya ada atau dua-duanya nggak — dijamin `_kondisiLingkungan()`.
    final adaTekanan = field.tekananAwal != null && field.tekananAkhir != null;

    Widget kepala(String teks) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        teks,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );

    Widget waktu(String teks) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      alignment: Alignment.center,
      child: Text(teks, style: theme.textTheme.labelMedium),
    );

    Widget kotak(FieldLembarKerja f) => Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: isian.teks[f.kode],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 6,
          ),
          // Satuannya tercetak di kertas sebagai sel sendiri, jadi di sini
          // dipakai `suffixText` — bukan `helperText` seperti kolom lain, yang
          // di dalam sel tabel malah menambah tinggi baris.
          suffixText: f.satuan,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lkKondisiLingkungan,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Table(
          border: TableBorder(
            top: garis,
            bottom: garis,
            left: garis,
            right: garis,
            horizontalInside: garis,
            verticalInside: garis,
          ),
          // Kolom tekanan cuma ada di Gas Detector. Lebar kolomnya dihitung,
          // bukan ditulis dua versi: tabel yang sama dipakai sembilan alat,
          // dan dua cabang tata letak cepat atau lambat jadi dua tampilan yang
          // beda tanpa ada yang berniat begitu.
          columnWidths: {
            0: const FlexColumnWidth(1),
            for (var i = 1; i <= (adaTekanan ? 3 : 2); i++)
              i: const FlexColumnWidth(1.6),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                kepala(l10n.lkWaktu),
                kepala(l10n.lkSuhu),
                kepala(l10n.lkKelembaban),
                if (adaTekanan) kepala(l10n.lkTekanan),
              ],
            ),
            TableRow(
              children: [
                waktu(l10n.lkAwal),
                kotak(field.suhuAwal),
                kotak(field.kelembabanAwal),
                if (adaTekanan) kotak(field.tekananAwal!),
              ],
            ),
            TableRow(
              children: [
                waktu(l10n.lkAkhir),
                kotak(field.suhuAkhir),
                kotak(field.kelembabanAkhir),
                if (adaTekanan) kotak(field.tekananAkhir!),
              ],
            ),
          ],
        ),
      ],
    );
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

/// Contoh isian yang ditulis di bawah kotak, buat kolom yang labelnya doang
/// nggak cukup buat orang lapangan.
///
/// "Nama Tempat (Insitu)" itu istilah sistem; yang bikin teknisi langsung
/// ngerti apa yang diminta ya CONTOHnya — nama pelanggan yang beneran dia
/// datangi, karena persis itu yang kecetak di sertifikat sebagai
/// `Calibration Location : Insitu (PT. LDC)`. Sebelum ada contohnya, kotak itu
/// keisi macam-macam ("Insitu", "luar", nama kota), dan yang kena dokumen
/// resmi.
///
/// Ini satu-satunya tempat kode kolom masih disebut di layar, dan itu disengaja:
/// yang nempel di kode cuma KALIMAT BANTU. Aturan tampil dan pengosongan
/// nilainya udah generik lewat `tampil_kalau`, jadi kode yang nggak kekenal di
/// sini paling banter kehilangan contohnya — bukan bikin kotaknya ilang atau
/// nilainya kekirim diam-diam.
String? _contohIsian(AppLocalizations l10n, FieldLembarKerja field) =>
    field.kode == 'lokasi_nama' ? l10n.lkContohNamaTempat : null;

class _Isian extends StatelessWidget {
  const _Isian({required this.field, required this.isian});

  final FieldLembarKerja field;
  final LembarKerjaState isian;

  @override
  Widget build(BuildContext context) {
    final controller = isian.teks[field.kode];
    if (controller == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final panjang = field.tipe == TipeField.teksPanjang;
    final angka = field.tipe == TipeField.angka;
    final contoh = _contohIsian(l10n, field);

    return TextField(
      controller: controller,
      maxLines: panjang ? 4 : 1,
      keyboardType: angka
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : (panjang ? TextInputType.multiline : TextInputType.text),
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: field.satuan,
        helperText: _helperSatuan(field.satuan, contoh),
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

/// Dropdown untuk kolom `pilihan` yang daftarnya ikut di bentuk lembar.
///
/// Nilainya disimpan di `isian.teks[kode]` — sama seperti kolom ketik — supaya
/// perakit payload nggak perlu tahu kolom ini dropdown atau bukan.
class _PilihanUmum extends StatelessWidget {
  const _PilihanUmum({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final controller = isian.teks[field.kode];
    if (controller == null) return const SizedBox.shrink();

    final nilai = controller.text.trim();
    final adaDiDaftar = field.pilihan.any((p) => p.nilai == nilai);

    return DropdownButtonFormField<String>(
      // Nilai di luar daftar dianggap belum kepilih, bukan dipaksa masuk:
      // `DropdownButtonFormField` melempar assert kalau `value`-nya nggak ada
      // di `items`, dan itu bikin seluruh layar merah — bukan satu kolom.
      initialValue: adaDiDaftar ? nilai : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final p in field.pilihan)
          DropdownMenuItem(value: p.nilai, child: Text(p.label)),
      ],
      onChanged: (v) {
        controller.text = v ?? '';
        onBerubah();
      },
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

    if (field.kode == 'equipment.satuan') {
      return _PilihSatuan(field: field, isian: isian, onBerubah: onBerubah);
    }

    // Kolom pilihan yang bawa daftar pilihannya sendiri digambar dropdown
    // biasa. Dulu SEMUA kolom pilihan di luar tiga kode di atas dirender
    // `SizedBox.shrink()` — alasannya waktu itu benar (nilainya nggak nyambung
    // ke mana-mana waktu dikirim), tapi jadi salah begitu Autoklaf masuk:
    // `satuan_tekanan` & `display_tekanan` nentuin ARTI angka tekanan (Bar vs
    // Psi vs kPa) dan sekarang ikut kekirim lewat `payloadMatriks`.
    //
    // Gagalnya diam-diam: kotaknya nggak ada di layar, teknisi nggak pernah
    // tahu ada yang harus dipilih, dan angka tekanannya sampai server tanpa
    // satuan.
    if (field.kode != 'lokasi') {
      if (field.pilihan.isEmpty) return const SizedBox.shrink();

      return _PilihanUmum(
        field: field,
        isian: isian,
        onBerubah: onBerubah,
      );
    }

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

/// "7. Satuan Refracto" — n20D (indeks bias) atau °Brix (kadar sukrosa).
///
/// Satu-satunya kolom `pilihan` yang kodenya **bertitik** (`equipment.satuan`)
/// tapi tetap bisa diedit. Di tempat lain kode bertitik artinya kolom turunan
/// yang read-only (lihat `FieldLembarKerja.turunan`), dan itu bukan cuma gaya
/// penamaan: `terapkanHasilHeader` mengandalkan kolom bertitik nggak punya
/// controller di `teks` supaya AI Vision nggak pernah bisa nulis serial number
/// atau nama pelanggan. Aturan itu **tetap utuh** — pilihan ini disimpen di
/// `LembarKerjaState.satuan`, bukan di `teks`, jadi nggak ada jalur baru buat
/// AI ngisi kolom identitas.
///
/// Kenapa ditanya ke teknisi dan bukan diambil diam-diam dari master alat: satu
/// refractometer fisik bisa nampilin dua-duanya, dan yang nentuin ya posisi
/// skala waktu dibaca — bukan yang kecatat waktu alatnya didaftarin. Nilai
/// awalnya tetap dari master (lihat `isiDariAlat`), jadi kasus normal nol
/// ketukan.
class _PilihSatuan extends StatelessWidget {
  const _PilihSatuan({
    required this.field,
    required this.isian,
    required this.onBerubah,
  });

  final FieldLembarKerja field;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    // Satuan dari backend yang nggak ada di daftar pilihan dibiarin kosong,
    // bukan dipaksa masuk: `DropdownButtonFormField` nge-assert kalau nilainya
    // nggak cocok persis salah satu item, dan itu bikin layarnya mati total
    // cuma gara-gara beda ejaan.
    final terpilih = field.pilihan.any((p) => p.nilai == isian.satuan)
        ? isian.satuan
        : null;

    return DropdownButtonFormField<String>(
      // Nilainya bisa berubah dari LUAR dropdown ini — `isiDariAlat` nyetel
      // satuan begitu alatnya dipilih. `FormField` nggak nyinkronin
      // `initialValue` waktu rebuild, jadi tanpa key yang ikut berubah,
      // teknisi milih alat °Brix tapi kotaknya tetap nulis n20D.
      key: ValueKey(terpilih),
      initialValue: terpilih,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final p in field.pilihan)
          DropdownMenuItem(value: p.nilai, child: Text(p.label)),
      ],
      onChanged: (value) => _pilih(context, value),
    );
  }

  /// Ganti satuan bisa **ngosongin tabel** — Refractometer di skala °Brix
  /// diadu ke larutan 2,5 & 40, bukan 1,33659 & 1,39986.
  ///
  /// Pembacaan yang kebuang emang nggak punya arti di satuan baru, tapi tetap
  /// angka yang diketik teknisi di lapangan — jadi ditanya dulu, bukan
  /// dilenyapkan diam-diam. Kalau tabelnya masih kosong (kasus paling umum:
  /// satuan disetel di awal, sebelum ngisi), nggak ada yang ditanyain.
  Future<void> _pilih(BuildContext context, String? value) async {
    if (value == null || value == isian.satuan) return;

    if (isian.gantiSatuanMenghapusIsian(value)) {
      final l10n = AppLocalizations.of(context);
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.lkGantiSatuanJudul),
          content: Text(l10n.lkGantiSatuanPesan(isian.satuan, value)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.lkGantiSatuanBatal),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.lkGantiSatuanLanjut),
            ),
          ],
        ),
      );

      if (lanjut != true) {
        // Dropdown-nya udah terlanjur nampilin pilihan baru; `onBerubah` bikin
        // dia digambar ulang dari `isian.satuan` yang nggak jadi berubah.
        onBerubah();
        return;
      }
    }

    isian.satuan = value;
    onBerubah();
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
            labelCetak: baris.labelCetak,
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
    this.labelCetak,
    this.serialNumber,
    this.kadaluarsa = false,
  });

  final String label;

  /// Tulisan baris ini di kertas, kalau beda dari [label]. Yang dicetak besar
  /// adalah yang ini — teknisi mencocokkan layar ke lembar di tangannya, dan
  /// nama alat standar yang sebenarnya turun jadi keterangan di bawahnya.
  final String? labelCetak;

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
                    labelCetak ?? label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: aktif ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Nama alat standar yang sebenarnya, waktu kertasnya menulis
                  // nama lain. Tanpa ini teknisi mencentang "Std Solution
                  // 84 µS" tanpa pernah tahu botol yang dipakai 25 µS/cm.
                  if (labelCetak != null && labelCetak != label)
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

/// Satu larutan standar di dialog konfirmasi: label larutan di kiri, rata-rata
/// pembacaannya di kanan.
///
/// Angkanya diformat pakai [formatSertifikat] — pemisah koma, desimal ngikut
/// resolusi titiknya, sama persis kayak yang nanti kecetak di sertifikat.
/// Teknisi mbandingin baris ini ke lembar kerja kertas di tangannya, jadi
/// bentuk angkanya nggak boleh beda dari yang dia tulis.
class _BarisKonfirmasi extends StatelessWidget {
  const _BarisKonfirmasi({required this.ringkasan});

  final RingkasanTitik ringkasan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rata = ringkasan.rataRata;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ringkasan.label} ${ringkasan.satuan}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            rata == null
                ? l10n.lkKonfirmasiBarisKosong
                : l10n.lkKonfirmasiBaris(
                    ringkasan.terisi,
                    ringkasan.total,
                    formatSertifikat(rata, ringkasan.desimal),
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              // Kotak yang dilewat ditandai warna, bukan cuma angka kecil:
              // "3 dari 5" gampang kebaca sekilas sebagai lengkap.
              color: ringkasan.adaYangKosong
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
