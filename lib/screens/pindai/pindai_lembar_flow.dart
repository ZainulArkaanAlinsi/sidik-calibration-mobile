import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img show Image;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/beku_lembar_kerja.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catatan_identifikasi_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/kesiapan_pindai_lembar_provider.dart';
import '../../providers/sumber_foto_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../services/catatan_identifikasi_lembar.dart';
import '../../services/foto_tertinggal.dart';
import '../../services/identitas_kertas.dart';
import '../../services/jenis_lembar.dart';
import '../../services/kenali_jenis_lembar.dart';
import '../../services/keputusan_pindai_lembar.dart';
import '../../services/modul_pembaca_teks.dart';
import '../../services/pembaca_halaman.dart'
    show PembacaHalaman, TeksTerbaca, sapuBerkasPindaiLama;
import '../../services/pesan_galat_pindai.dart';
import '../../services/potong_sel_foto.dart' show decodeFotoDiIsolate;
import '../../widgets/konfirmasi_foto_tertinggal.dart';
import '../../widgets/pilih_jenis_ringkas_sheet.dart';
import '../calibration/lembar_kerja_screen.dart';
import '../calibration/pindai_formulir_asli_flow.dart' show batasSisiFotoAsli;
import 'dari_foto_lembar.dart';

/// "Pindai lembar kerja" dari beranda, SATU-SATUNYA pintu foto: foto lembar ->
/// jenis dikenali OTOMATIS -> lembar kerja yang tepat terbuka -> terisi sebagai
/// saran kuning -> teknisi memeriksa dan membetulkan.
///
/// Urutannya, dan apa yang TIDAK dilakukannya:
///
///  1. Daftar jenis dari cache `kesiapanPindaiLembarProvider` (tidak meminta
///     server lagi); gagal = pesan butuh koneksi, tanpa kamera.
///  2. Kamera, lalu decode di isolate (foto 4200 px ≈ puluhan MB, dibuang
///     dari memori sebelum lembar kerja dibuka). Yang DISIMPAN hanya byte
///     JPEG aslinya (beberapa MB), bukan citra hasil decode; byte itu tetap
///     dipegang alur ini, `LembarKerjaScreen`, dan closure route selama lembar
///     kerja terbuka, lalu lepas saat route ditutup.
///  3. Pembaca halaman ML Kit di perangkat, putaran 0/90/180/270 sampai kode
///     formulir bersih terbaca atau bukti berlapis (kode, judul, revisi)
///     cukup kuat (`kenaliJenisLembar` -> `identifikasiLembar`). Pembaca
///     SELALU ditutup.
///  4. `putuskanPindaiLembar` (`keputusan_pindai_lembar.dart`):
///      - kode formulir UNIK + skor tinggi + jenisnya boleh dipindai =
///        lembar langsung terbuka, tanpa layar pilihan;
///      - kandidat lebih dari satu (kode bersama, bacaan samar, bertentangan)
///        = lembar ringkas "Pilih salah satu": SATU ketukan, tidak pernah
///        dipilihkan;
///      - tidak yakin / tidak terbaca = pesan jujur (foto ulang, jenis lain,
///        atau "Mulai kalibrasi"), tanpa tebakan.
///  5. TIDAK ada alat yang dipilihkan, satu pun, sebelum kertas dibaca (dulu
///     alur memilih alat terdaftar dari daftar lalu menyalin identitas dan
///     pemiliknya ke lembar, padahal yang benar adalah yang TERTULIS di
///     kertas). Identitas kertas dibaca dari teks halaman yang sama dengan
///     pengenalan jenis (`bacaIdentitasKertas`, jangkar label cetak), tanpa
///     membaca halaman kedua kali.
///  6. `LembarKerjaScreen(dariFoto:)` dibuka — dibungkus `BekuLembarKerja`
///     seperti pemanggil lembar kerja lain — dan MEMBACA foto yang sama
///     sendiri (tanpa dialog "Mau diisi bagaimana?", tanpa tombol foto kedua,
///     tanpa menunggu alat): kode formulir terbaca ikut dikirim sebagai
///     `kode_dokumen` supaya peta varian benar tanpa alat. Hasilnya lewat
///     layar periksa yang sudah ada, lalu sel dan identitas terisi BERWARNA
///     KUNING (saran) dan wajib diperiksa teknisi. Blok identitas di atas
///     lembar mencocokkan alat/PT ke yang terdaftar (atau membukakan panel
///     "Alat baru"), selalu dengan ketukan teknisi. Banner menyebut jenis yang
///     dikenali dan memberi "Ganti jenis".
///
/// Hasil OCR tetap HANYA saran: tidak ada sel yang terisi sebagai nilai
/// tersahkan, sel kosong tetap kosong, dan keputusan membuka lembar tidak
/// pernah mengunci jenisnya (banner "Ganti jenis" selalu ada). Foto tidak
/// diunggah dan tidak disimpan ke disk: hanya ada di memori, dan berkas
/// kameranya dihapus begitu bitanya terbaca. Yang dicatat ke HP hanya skor,
/// kode cetak, dan keputusan (`catatan_identifikasi_lembar.dart`, tanpa
/// citra).
///
/// Jenis yang belum boleh dipindai (`siap_pindai`/mode uji,
/// `perlu_konfirmasi_lab`, Temperatur Indikator) tidak pernah dibuka dari
/// sini: pesan jujur, tanpa navigasi. Jalur manual "Mulai kalibrasi" tidak
/// berubah.
///
/// [setelahKembali] dipanggil sesudah lembar kerja ditutup (mis. menyegarkan
/// daftar draf beranda teknisi).
Future<void> pindaiLembarKerja({
  required BuildContext context,
  required WidgetRef ref,
  Future<void> Function()? setelahKembali,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  // Wadah, bukan `ref`: closure "Ganti jenis" hidup selama lembar kerja
  // terbuka dan tidak boleh bergantung pada widget beranda yang memulainya.
  final wadah = ProviderScope.containerOf(context, listen: false);

  void kabar(String pesan) =>
      messenger.showSnackBar(SnackBar(content: Text(pesan)));

  // ---- 1. daftar jenis (cache sesi) ------------------------------------------
  final KesiapanPindaiLembar kesiapan;
  try {
    kesiapan = await ref.read(kesiapanPindaiLembarProvider.future);
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-daftar', e, st);
    kabar(l10n.pindaiLembarButuhKoneksi);
    return;
  }
  if (!kesiapan.adaYangBoleh) {
    kabar(l10n.lkAsliBelumSiap);
    return;
  }
  if (!context.mounted) return;

  final catatan = wadah.read(catatanIdentifikasiLembarProvider);
  final idPindai = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  // ---- 2-4. foto -> pengenalan -> keputusan (ulang bila "Foto ulang") --------
  final tentu = await _fotoDanJenis(
    context: context,
    ref: ref,
    kesiapan: kesiapan,
    catatan: catatan,
    idPindai: idPindai,
  );
  if (tentu == null || !context.mounted) return;

  final jenis = tentu.jenis;

  // ---- 5. jenis yang tidak boleh dipindai: pesan, tanpa navigasi -------------
  if (!kesiapan.bolehDipindai(jenis.formulir.templateId)) {
    kabar(l10n.lkAsliBelumSiap);
    return;
  }

  // ---- 6. buka lembar kerja: TANPA memilihkan alat ---------------------------
  await navigator.push(
    _ruteLembar(
      formulir: jenis.formulir,
      otomatis: jenis.otomatis,
      foto: tentu.foto,
      kesiapan: kesiapan,
      saran: [
        for (final k in jenis.saran)
          if (k.templateId != jenis.formulir.templateId) k,
      ],
      wadah: wadah,
      catatan: catatan,
      idPindai: idPindai,
    ),
  );

  if (context.mounted) await setelahKembali?.call();
}

/// Hasil menentukan jenis dari satu foto.
sealed class _Hasil {
  const _Hasil();
}

/// Jenis yang akan dibuka. [saran] = kandidat hasil foto, bahan "Ganti jenis".
class _Jenis extends _Hasil {
  const _Jenis(this.formulir, {required this.otomatis, required this.saran});

  final FormulirDikenal formulir;
  final bool otomatis;
  final List<FormulirDikenal> saran;
}

/// Teknisi minta memotret ulang.
class _FotoUlang extends _Hasil {
  const _FotoUlang();
}

/// Teknisi menutup pilihan tanpa memilih: tidak ada yang dibuka.
class _Batal extends _Hasil {
  const _Batal();
}

/// Yang dibawa dari foto ke lembar kerja: [jpeg] = byte JPEG kamera apa adanya
/// (satu-satunya salinan foto), [identitas] = identitas yang tertulis di kertas,
/// dan kode formulir tercetak + kandidatnya untuk `kode_dokumen`.
class _BekalFoto {
  const _BekalFoto({
    required this.jpeg,
    required this.identitas,
    required this.kodeCetak,
    required this.kandidatKode,
  });

  final Uint8List jpeg;
  final IdentitasKertas identitas;

  /// Kode formulir hasil identifikasi (`SIDIK-FM-CAL-0508.A`), atau `null`.
  final String? kodeCetak;

  /// Jenis yang ditunjuk oleh bukti di kertas (kode/judul/revisi).
  final List<FormulirDikenal> kandidatKode;

  /// `kode_dokumen` untuk [formulir]: kode tercetak bila jenis itu memang yang
  /// ditunjuk kertas (peta varian yang tepat), selain itu kode bawaan jenis itu
  /// (mis. teknisi memilih jenis lain lewat "Ganti jenis").
  String? kodeUntuk(FormulirDikenal formulir) {
    final cetak = kodeCetak;
    if (cetak != null &&
        cetak.isNotEmpty &&
        kandidatKode.any((k) => k.templateId == formulir.templateId)) {
      return cetak;
    }

    return formulir.kodeDokumen.isEmpty ? null : formulir.kodeDokumen;
  }
}

/// Foto + jenis yang akan dibuka.
typedef _Tentu = ({_Jenis jenis, _BekalFoto foto});

/// Foto -> pengenalan -> keputusan, diulang selama teknisi memilih "Foto
/// ulang" (foto sebelumnya dilepas dulu). `null` = berhenti tanpa membuka apa
/// pun (dibatalkan, gagal, atau pilihan ditutup).
Future<_Tentu?> _fotoDanJenis({
  required BuildContext context,
  required WidgetRef ref,
  required KesiapanPindaiLembar kesiapan,
  required CatatanIdentifikasiLembar catatan,
  required String idPindai,
}) async {
  while (true) {
    final kenal = await _ambilDanKenali(
      context: context,
      ref: ref,
      kesiapan: kesiapan,
    );
    if (kenal == null || !context.mounted) return null;

    final keputusan = putuskanPindaiLembar(
      kenal.petunjuk,
      boleh: kesiapan.bolehDipindai,
    );
    unawaited(
      catatan.tulis(
        'identifikasi',
        idPindai,
        ringkasIdentifikasi(kenal.petunjuk, keputusan),
      ),
    );

    final hasil = await _tentukanJenis(
      context: context,
      kesiapan: kesiapan,
      keputusan: keputusan,
      petunjuk: kenal.petunjuk,
      catatan: catatan,
      idPindai: idPindai,
    );
    if (!context.mounted) return null;

    switch (hasil) {
      case _FotoUlang():
        unawaited(catatan.tulis('foto_ulang', idPindai, const {}));
      case _Batal():
        return null;
      case _Jenis():
        return (
          jenis: hasil,
          foto: _BekalFoto(
            jpeg: kenal.jpeg,
            // Dibaca dari teks halaman yang SAMA dengan pengenalan jenis; tidak
            // ada pembacaan kedua dan tidak ada citra yang keluar HP.
            identitas: bacaIdentitasKertas(
              kenal.teks,
              sekarang: ProviderScope.containerOf(
                context,
                listen: false,
              ).read(jamProvider)(),
            ),
            kodeCetak: kenal.petunjuk?.kodeFormulir,
            kandidatKode: kenal.petunjuk?.kandidat ?? const [],
          ),
        );
    }
  }
}

/// Menerjemahkan [keputusan] menjadi jenis yang dibuka, atau menanyakannya
/// lewat lembar ringkas. Hanya fungsi tampilan: aturannya di
/// `putuskanPindaiLembar`.
Future<_Hasil> _tentukanJenis({
  required BuildContext context,
  required KesiapanPindaiLembar kesiapan,
  required KeputusanPindai keputusan,
  required HasilJenisLembar? petunjuk,
  required CatatanIdentifikasiLembar catatan,
  required String idPindai,
}) async {
  final l10n = AppLocalizations.of(context);
  final saran = <FormulirDikenal>[
    if (petunjuk != null)
      for (final k in petunjuk.peringkat) k.formulir,
  ];

  if (keputusan case BukaOtomatis(:final formulir)) {
    return _Jenis(formulir, otomatis: true, saran: saran);
  }

  final kandidat = keputusan is PilihSatu
      ? keputusan.kandidat
      : const <FormulirDikenal>[];

  final (judul, pesan, semua, tawarkanFotoUlang) = switch (keputusan) {
    PilihSatu(:final alasan) => (
      l10n.pindaiPilihSatuJudul,
      switch (alasan) {
        AlasanPilih.kodeBersama => l10n.jlBeberapaJenis,
        AlasanPilih.samar =>
          kandidat.length == 1 ? l10n.jlSamarCocok : l10n.jlSamarUsulan,
        AlasanPilih.bertentangan => l10n.jlBertentangan,
        AlasanPilih.lemah => l10n.jlSamarUsulan,
        AlasanPilih.judulSaja => l10n.jlDariJudul,
        AlasanPilih.perluKonfirmasi => l10n.pindaiPerluKonfirmasi,
      },
      kesiapan.dikenal,
      true,
    ),
    TakDikenali(:final alasan, :final kode, :final jenis) => switch (alasan) {
      AlasanTakDikenali.tidakTerbaca => (
        l10n.pindaiTakDikenaliJudul,
        l10n.pindaiTakDikenaliPesan,
        kesiapan.dikenal,
        true,
      ),
      AlasanTakDikenali.kodeTakDikenal => (
        l10n.pindaiTakDikenaliJudul,
        l10n.jlKodeTakDikenal(kode ?? ''),
        kesiapan.dikenal,
        true,
      ),
      // Dikenali tetapi belum boleh dipindai: memotret ulang atau memilih
      // jenis lain tidak membantu, hanya pesannya.
      AlasanTakDikenali.belumBisaDipindai => (
        l10n.pindaiBelumBisaJudul,
        l10n.pindaiBelumBisaPesan(jenis ?? ''),
        const <FormulirDikenal>[],
        false,
      ),
    },
    // Sudah dikembalikan di atas.
    BukaOtomatis() => throw StateError('BukaOtomatis ditangani lebih dulu'),
  };

  final pilih = await tampilkanPilihJenisRingkas(
    context,
    judul: judul,
    pesan: pesan,
    kandidat: kandidat,
    semua: semua,
    tawarkanFotoUlang: tawarkanFotoUlang,
  );

  switch (pilih) {
    case JenisDipilih(:final formulir):
      unawaited(
        catatan.tulis('pilihan', idPindai, {
          'dipilih': formulir.templateId,
          // -1 = dari "Jenis lain", bukan dari kandidat hasil foto.
          'urutan_kandidat': kandidat.indexWhere(
            (k) => k.templateId == formulir.templateId,
          ),
        }),
      );

      return _Jenis(formulir, otomatis: false, saran: saran);
    case MintaFotoUlang():
      return const _FotoUlang();
    case null:
      return const _Batal();
  }
}

/// Route lembar kerja untuk [formulir], membawa foto yang SAMA. "Ganti jenis"
/// membangun route berikutnya lewat fungsi ini juga.
Route<void> _ruteLembar({
  required FormulirDikenal formulir,
  required bool otomatis,
  required _BekalFoto foto,
  required KesiapanPindaiLembar kesiapan,
  required List<FormulirDikenal> saran,
  required ProviderContainer wadah,
  required CatatanIdentifikasiLembar catatan,
  required String idPindai,
}) => MaterialPageRoute<void>(
  builder: (_) => BekuLembarKerja(
    child: LembarKerjaScreen(
      profil: formulir.templateId,
      judulTambahan: namaPendekJudul(formulir.judul),
      dariFoto: DariFotoLembar(
        jpeg: foto.jpeg,
        jenis: namaPendekJudul(formulir.judul),
        otomatis: otomatis,
        identitas: foto.identitas,
        kodeDokumen: foto.kodeUntuk(formulir),
        gantiJenis: (ctx) => _gantiJenis(
          ctx,
          formulir: formulir,
          foto: foto,
          kesiapan: kesiapan,
          saran: saran,
          wadah: wadah,
          catatan: catatan,
          idPindai: idPindai,
        ),
      ),
    ),
  ),
);

/// "Ganti jenis" di banner lembar: kandidat lain dari foto yang sama (hanya
/// yang boleh dipindai) + semua jenis di bawah "Jenis lain". Mengembalikan
/// route lembar pengganti atau `null`.
Future<Route<void>?> _gantiJenis(
  BuildContext context, {
  required FormulirDikenal formulir,
  required _BekalFoto foto,
  required KesiapanPindaiLembar kesiapan,
  required List<FormulirDikenal> saran,
  required ProviderContainer wadah,
  required CatatanIdentifikasiLembar catatan,
  required String idPindai,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final pilih = await tampilkanPilihJenisRingkas(
    context,
    judul: l10n.pindaiGantiJenisJudul,
    pesan: l10n.pindaiGantiJenisPesan(namaPendekJudul(formulir.judul)),
    kandidat: [
      for (final k in saran)
        if (k.templateId != formulir.templateId &&
            kesiapan.bolehDipindai(k.templateId))
          k,
    ],
    semua: [
      for (final d in kesiapan.dikenal)
        if (d.templateId != formulir.templateId) d,
    ],
    tawarkanFotoUlang: false,
  );
  if (pilih is! JenisDipilih || !context.mounted) return null;

  final baru = pilih.formulir;
  if (!kesiapan.bolehDipindai(baru.templateId)) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.lkAsliBelumSiap)));

    return null;
  }

  unawaited(
    catatan.tulis('ganti_jenis', idPindai, {
      'dari': formulir.templateId,
      'ke': baru.templateId,
    }),
  );

  return _ruteLembar(
    formulir: baru,
    otomatis: false,
    foto: foto,
    kesiapan: kesiapan,
    saran: [
      for (final k in [formulir, ...saran])
        if (k.templateId != baru.templateId) k,
    ],
    wadah: wadah,
    catatan: catatan,
    idPindai: idPindai,
  );
}

/// Hasil pengenalan; `petunjuk == null` = tidak ada petunjuk sama sekali
/// (lembar pilihan menampilkan daftar manual). [jpeg] = byte JPEG kamera apa
/// adanya, untuk dibawa ke lembar kerja (satu-satunya salinan foto). [teks] =
/// elemen teks halaman (tegak) dari pembacaan yang sama, bahan identitas kertas;
/// kosong bila tidak ada petunjuk.
typedef _Pengenalan = ({
  HasilJenisLembar? petunjuk,
  Uint8List jpeg,
  List<TeksTerbaca> teks,
});

/// Kamera -> decode -> pembaca halaman. `null` = berhenti (dibatalkan atau
/// gagal; pesan sudah ditampilkan). Fungsi terpisah supaya citra hasil decode
/// (puluhan MB) lepas dari memori sebelum lembar pilihan dan lembar kerja
/// dibuka; yang keluar dari sini hanya byte JPEG-nya.
Future<_Pengenalan?> _ambilDanKenali({
  required BuildContext context,
  required WidgetRef ref,
  required KesiapanPindaiLembar kesiapan,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  void kabar(String pesan) =>
      messenger.showSnackBar(SnackBar(content: Text(pesan)));

  // Sisa berkas sementara pindai yang tertinggal (proses mati di tengah baca)
  // disapu dulu. Tidak ditunggu dan tidak boleh menggagalkan pindai.
  unawaited(
    getTemporaryDirectory()
        .then(sapuBerkasPindaiLama)
        .then<void>((_) {}, onError: (Object _) {}),
  );

  final File? berkas;
  try {
    berkas = await ambilFotoAtauPulihkan(
      ref.read(sumberFotoProvider),
      pakaiTertinggal: (f) => konfirmasiFotoTertinggal(context, f),
      // Sama dengan "Foto lembar kerja": batas sisi 4200 px, mutu JPEG 100
      // (artefak JPEG di tulisan kecil kaki formulir menurunkan bacaan kode).
      maxWidth: batasSisiFotoAsli,
      maxHeight: batasSisiFotoAsli,
      imageQuality: 100,
      // Jenis lembar belum diketahui, jadi bingkai panduan tidak bisa
      // mengikuti bentuk halamannya.
      rasioKertas: null,
    );
  } catch (e, st) {
    // Izin kamera ditolak, kamera tidak ada, dsb.
    catatGalatPindai('pindai-lembar-kamera', e, st);
    kabar(pesanGalatPindai(l10n, e, umum: l10n.lkAsliGagalUmum));
    return null;
  }
  if (berkas == null) return null; // Teknisi mundur dari kamera.

  final bita = await berkas.readAsBytes();
  try {
    await berkas.delete();
  } catch (_) {
    // Sampah yang tak terhapus bukan alasan menolak foto.
  }

  final img.Image? citra;
  try {
    citra = await decodeFotoDiIsolate(bita);
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-decode', e, st);
    kabar(pesanGalatPindai(l10n, e, umum: l10n.lkPindaiGagalFoto));
    return null;
  }
  if (citra == null) {
    kabar(l10n.lkPindaiGagalFoto);
    return null;
  }

  if (!context.mounted) return null;

  // Dialog progres: pembacaan berat, dan teknisi tidak boleh mengira layar
  // macet. Tidak bisa ditutup sendiri; ditutup di `finally` di bawah.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l10n.pindaiLembarMembaca)),
          ],
        ),
      ),
    ),
  );

  // Pembaca ML Kit memegang sumber daya native: dibuat di sini dan SELALU
  // ditutup, apa pun hasilnya.
  PembacaHalaman? halaman;
  HasilJenisLembar? petunjuk;
  var teks = const <TeksTerbaca>[];
  String? galat;

  try {
    halaman = ref.read(pabrikPembacaPindaiProvider).halaman();
    petunjuk = await kenaliJenisLembar(
      foto: citra,
      jpegAsli: bita,
      halaman: halaman,
      dikenal: kesiapan.dikenal,
      padaTeksHalaman: (t) => teks = t,
    );
  } on ModulPembacaTeksBelumSiap {
    // ML Kit unbundled: modul `ocr` belum terunduh. Tidak ada yang berubah.
    galat = l10n.lkModulPembacaTeksDiunduh;
  } catch (e, st) {
    catatGalatPindai('pindai-lembar-baca', e, st);
    galat = pesanGalatPindai(l10n, e, umum: l10n.lkAsliGagalUmum);
  } finally {
    try {
      await halaman?.tutup();
    } catch (e, st) {
      // Gagal menutup pembaca tidak boleh menghentikan alur diam-diam.
      catatGalatPindai('pindai-lembar-tutup', e, st);
    } finally {
      if (navigator.mounted) navigator.pop(); // tutup dialog progres
    }
  }

  if (galat != null) {
    kabar(galat);
    return null;
  }

  return (petunjuk: petunjuk, jpeg: bita, teks: teks);
}
