import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/lembar_kerja_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/auth_service.dart' show AuthException;
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
    this.sesiId,
  });

  final LembarKerja bentuk;

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
      // satuan atau koma kegeser. Ditahan di sini karena yang bisa mbenerin
      // cuma orang yang lagi berdiri di depan alatnya; di admin angka kayak
      // gini cuma jadi peringatan yang gampang dilewatin.
      final jauh = _isian.titikPembacaanJauh;

      if (jauh.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.lkPembacaanJauhDariTitik(
                jauh.map((t) => t.label).join(', '),
              ),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
        return;
      }

      // Satu Repeat yang jauh menyimpang dari Repeat lain SEBARIS — nangkep
      // DIGIT KETUKER, yang penjaga di atas nggak bisa nangkep.
      //
      // `783,52` di baris `738,5` cuma 6% dari nominalnya, jadi penjaga orde
      // lolos mulus. Tapi buat alat yang U95-nya lahir per kelompok, satu
      // angka itu menaikkan U95 sembilan titik saudaranya 212x CMC lab — dan
      // sertifikatnya terbit dengan angka itu (`CAL/2026/08/0043`).
      final menyimpang = _isian.titikRepeatMenyimpang;

      if (menyimpang.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.lkRepeatMenyimpang(
                menyimpang.map((t) => t.label).join(', '),
              ),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
        return;
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

    if (!draft && !await _konfirmasiAngka()) return;
    if (!mounted) return;

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
                      )
                    : _LembarSatuKolom(
                        bentuk: bentuk,
                        isian: _isian,
                        halaman: _halaman,
                        onBerubah: _isianBerubah,
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
              // Nomor formulir + nomor metode, persis kayak yang tercetak di
              // kertas: yang FM di kop, yang IK di baris "Calibration Methode".
              // Teknisi cuma membacanya — `calibration_method_id` tetap milik
              // admin.
              bentuk.kodeMetode == null
                  ? bentuk.kodeDokumen
                  : '${bentuk.kodeDokumen} · ${bentuk.kodeMetode}',
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

            if (bagian.belumBisaDiisi)
              _BagianTanpaInput(catatan: bagian.catatan)
            else if (bagian.kode == 'usage_check')
              _UsageCheck(bagian: bagian, isian: isian, onBerubah: onBerubah)
            else ...[
              for (final grup in _kelompokkanField(bagian.field)) ...[
                // Seluruh blok spesifikasi digambar bentuk cetak — termasuk
                // yang cuma sekotak (`Kapasitas Max.`), biar ketiga barisnya
                // sejajar kayak di kertas dan bukan campur dua gaya.
                // Nama tempat cuma ditanyain kalau kalibrasinya DI LUAR lab.
                // Sesi in-lab yang nyimpen nama tempat bikin sertifikatnya
                // nulis `Insitu (…)` buat kerjaan yang nggak pernah keluar
                // gedung.
                if (grup.first.kode == 'lokasi_nama' &&
                    isian.lokasi != LokasiKalibrasi.onsite)
                  const SizedBox.shrink()
                else if (grup.first.spesifikasiAlat)
                  _BarisSpesifikasi(field: grup, isian: isian)
                else
                  _Field(field: grup.first, isian: isian, onBerubah: onBerubah),
                const SizedBox(height: AppSpacing.md),
              ],
            ],

            // Pindai lembar penuh (OCR lokal) — di atas tabelnya, karena dia
            // ngisi SELURUH tabel sekaligus, bukan satu tabel.
            if (bagian.tabel.isNotEmpty)
              _TombolPindaiLembar(
                profil: isian.bentuk.kodeDokumen,
                equipmentId: isian.alat?.id,
              ),

            for (final tabel in bagian.tabel) ...[
              LembarKerjaTabel(
                tabel: tabel,
                isian: isian,
                onBerubah: onBerubah,
              ),
              const SizedBox(height: AppSpacing.lg),
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
            if (bagian.tabel.isNotEmpty) _PanelPratinjau(isian: isian),
          ],
        ),
      ),
    );
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


/// Tombol pindai LEMBAR PENUH (OCR lokal) — beda dari tombol "foto tabel ini"
/// yang ngirim citranya ke AI di server.
///
/// Jalur ini baca angkanya DI HP (ML Kit on-device): fotonya nggak pernah
/// keluar dari perangkat, nggak ada biaya per foto, dan jalan tanpa sinyal.
/// Syaratnya satu: koordinat tiap sel harus udah diukur dari formulir CETAK
/// asli, dan formulirnya dicetak ulang pakai 4 penanda sudut + QR versi.
///
/// **`siap_pindai` dari server yang mutusin tombol ini hidup atau mati.**
/// Sekarang keenam lembar masih `geometri_belum_diverifikasi` — koordinat
/// tebakan berarti angka mendarat di sel yang salah, dan itu justru kegagalan
/// yang mau dicegah fitur ini. Alasannya ditampilin apa adanya, bukan
/// diterjemahin jadi "fitur belum tersedia": teknisi berhak tahu yang kurang
/// itu apa, dan yang bisa nutup cuma lab (cetak ulang formulir + ukur).
class _TombolPindaiLembar extends ConsumerWidget {
  const _TombolPindaiLembar({required this.profil, required this.equipmentId});

  final String profil;
  final int? equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final template = ref.watch(
      worksheetTemplateProvider((kode: profil, equipmentId: equipmentId)),
    );

    // Gagal narik template NGGAK ditampilin sebagai error: ini jalan pintas,
    // bukan jalur kerja. Yang nggak boleh cuma satu — nampilin tombol aktif
    // buat lembar yang belum boleh dipindai.
    final data = template.value;
    if (data == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: data.siapPindai ? () {} : null,
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: Text(l10n.lkPindaiLembar),
          ),
        ),
        if (!data.siapPindai) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.lkPindaiBelumSiap(data.alasanBelumSiap ?? '—'),
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
class _BarisSpesifikasi extends StatelessWidget {
  const _BarisSpesifikasi({required this.field, required this.isian});

  final List<FieldLembarKerja> field;
  final LembarKerjaState isian;

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
                child: TextField(
                  controller: isian.teks[f.kode],
                  decoration: InputDecoration(
                    // Labelnya udah ditulis sekali di atas — yang di dalam
                    // kotak tinggal satuannya, persis kertasnya.
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
        nilai: isian.nilaiTurunan(
          field.kode,
          namaTeknisi: user?.nama,
          kodeTeknisi: user?.kodeTeknisi,
        ),
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

    if (field.kode == 'equipment.satuan') {
      return _PilihSatuan(field: field, isian: isian, onBerubah: onBerubah);
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
