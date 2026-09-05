import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer_lookup.dart';
import '../../models/perusahaan_direktori.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart'
    show customerLookupProvider, customerLookupServiceProvider;
import '../../services/customer_lookup_service.dart';

/// Teknisi mendaftarkan PT yang belum ada di master lab, dari lapangan.
///
/// ## Kenapa layar ini ada
///
/// `pelanggan_id` itu **wajib** waktu alat disimpan. Sebelum ini, pelanggan yang
/// belum kedaftar bikin kerjaan teknisi berhenti total: dia nggak bisa milih
/// pelanggan, nggak bisa nyimpen alat, dan nggak ada jalan keluar dari layar itu
/// sampai ada admin yang buka laptop. Keputusan pemilik proyek — sejalan dengan
/// yang sudah berlaku buat nama alat baru — pelanggan dari teknisi **langsung
/// kepakai**, tanpa antrean persetujuan.
///
/// ## Dua jalan masuk, dan kenapa dua-duanya perlu
///
///  1. **Direktori perusahaan.** Nama & alamat datang dari direktori tempat
///     usaha, bukan dari ingatan orang yang lagi berdiri di gerbang pabrik.
///     Alamat yang salah ketik di sini mendarat di blok OWNER sertifikat.
///  2. **Ketik tangan.** Pabrik yang nggak pernah didaftarkan ke peta nggak
///     akan ketemu di direktori, dan itu bukan kerusakan. Jalur ini yang bikin
///     teknisi tetap bisa lanjut.
///
/// ## Harga yang dibayar, dan penebusnya
///
/// Yang ditukar: kembar. Folder arsip, sertifikat, dan daftar alat semuanya
/// nempel ke baris pelanggan, jadi satu perusahaan yang kedaftar dua kali punya
/// riwayat kalibrasi yang terbelah — dan yang kelihatan di layar cuma
/// separuhnya. Penebusnya: server menunjukkan yang MIRIP sebelum barisnya lahir,
/// dan layar ini memajangnya sebagai pilihan yang tinggal diketuk. Kembar tetap
/// mungkin, tapi jadi tindakan sadar.
class PelangganBaruScreen extends ConsumerStatefulWidget {
  const PelangganBaruScreen({
    super.key,
    this.kataKunci = '',
    this.alamatAwal,
    this.refAwal,
    this.tabrakanAwal,
  });

  /// Kata kunci yang sudah diketik teknisi di sheet pencarian. Diisikan duluan
  /// ke kolom nama supaya dia nggak mengetik hal yang sama dua kali.
  ///
  /// Juga dipakai waktu barisnya datang dari direktori: yang dikirim ke sini
  /// nama persis dari direktori, berpasangan dengan [alamatAwal] & [refAwal].
  final String kataKunci;

  /// Alamat dari direktori, kalau layar ini dibuka membawa satu baris utuh.
  final String? alamatAwal;

  /// Id tempat dari direktori. Dibawa masuk supaya pendaftaran dari layar ini
  /// tetap tercatat sebagai berasal dari direktori — bukan turun jadi ketikan
  /// tangan cuma karena sempat mampir ke sini buat menyelesaikan tabrakan nama.
  final String? refAwal;

  /// Tabrakan nama yang SUDAH ketahuan sebelum layar ini dibuka.
  ///
  /// Dipakai waktu teknisi mengetuk baris direktori dari sheet pencarian dan
  /// servernya menemukan PT mirip. Tanpa ini, dia mendarat di layar asing tanpa
  /// satu pun keterangan kenapa — lalu menekan "Daftarkan" cuma buat
  /// memunculkan penolakan yang sebenarnya SUDAH diketahui satu langkah
  /// sebelumnya.
  final PelangganMiripException? tabrakanAwal;

  @override
  ConsumerState<PelangganBaruScreen> createState() =>
      _PelangganBaruScreenState();
}

class _PelangganBaruScreenState extends ConsumerState<PelangganBaruScreen> {
  late final _nama = TextEditingController(text: widget.kataKunci);
  late final _alamat = TextEditingController(text: widget.alamatAwal ?? '');

  /// Id tempat dari direktori, kalau barisnya dipilih dari sana.
  String? _ref;

  /// Nama persis yang dipilih dari direktori. Dipakai buat tahu kapan [_ref]
  /// berhenti berlaku — lihat [_namaBerubah].
  String? _namaDariDirektori;

  HasilDirektori? _hasilDirektori;

  /// Sebab direktorinya nggak bisa dipakai, apa adanya dari server.
  ///
  /// Sengaja dipajang sebagai kalimat, BUKAN diratakan jadi daftar kosong.
  /// Daftar kosong kebaca "PT-nya nggak ada di direktori", dan teknisi yang
  /// percaya itu mendaftarkan ulang perusahaan yang sebenarnya ada di sana.
  String? _pesanDirektori;

  /// Direktorinya memang nggak dipasang di lab ini → tombolnya disembunyikan.
  ///
  /// "Key belum disetel" itu urusan ADMIN, dan teknisi di gerbang pabrik nggak
  /// bisa berbuat apa-apa soal itu. Dipajang apa adanya, yang dia lihat cuma
  /// aplikasi yang kelihatan rusak di tengah kerjaan — lalu dia berhenti dan
  /// menelepon, padahal jalur ketik tangan di bawahnya jalan sempurna.
  ///
  /// Jadi buat dia, keadaan ini bukan error: fiturnya sekadar nggak ada di sini.
  /// Yang butuh tahu bedanya (admin) melihatnya di `GET /api/health`, bukan di
  /// layar ini.
  bool _direktoriTiada = false;

  bool _mencari = false;
  bool _menyimpan = false;

  /// Kandidat mirip dari server. Kosong = belum ada tabrakan.
  List<CustomerLookup> _kandidat = const [];
  bool _bolehTetapBuat = false;
  String? _pesanGagal;

  /// Nama yang bikin server memulangkan [_kandidat]. Dipakai buat tahu kapan
  /// kandidatnya jadi basi — lihat [_namaBerubah].
  String? _namaSaatTabrakan;

  @override
  void initState() {
    super.initState();

    // Dipasang SEBELUM listener-nya, dan dua-duanya dari nilai yang sudah
    // ter-trim.
    //
    // [_namaBerubah] mengadu `_nama.text.trim()` ke [_namaDariDirektori] dan
    // melepas `_ref` kalau nggak sama. Kalau `_ref` diisi tanpa
    // `_namaDariDirektori`, listener pertama yang nyala — dan dia nyala bahkan
    // cuma karena kursor pindah — langsung membuangnya, jadi asal-usul
    // direktorinya hilang tanpa ada yang kelihatan berubah di layar.
    if (widget.refAwal != null) {
      _ref = widget.refAwal;
      _namaDariDirektori = widget.kataKunci.trim();
    }

    // Tabrakan yang sudah ketahuan dipajang SEKETIKA, bukan menunggu teknisi
    // menekan "Daftarkan" dulu buat memunculkan penolakan yang sama.
    final tabrakan = widget.tabrakanAwal;
    if (tabrakan != null) {
      _kandidat = tabrakan.kandidat;
      _bolehTetapBuat = !tabrakan.namaPersisSudahAda;
      _pesanGagal = tabrakan.pesan;
      _namaSaatTabrakan = widget.kataKunci.trim();
    }

    _nama.addListener(_namaBerubah);
    _alamat.addListener(_gambarUlang);
  }

  @override
  void dispose() {
    _nama.removeListener(_namaBerubah);
    _alamat.removeListener(_gambarUlang);
    _nama.dispose();
    _alamat.dispose();
    super.dispose();
  }

  void _gambarUlang() => setState(() {});

  /// Namanya disunting sesudah dipilih dari direktori → [_ref] dilepas.
  ///
  /// Alamat boleh dibetulkan tanpa melepas ref: yang dituju ref itu PERUSAHAAN
  /// mana, dan alamat cuma keterangannya. Nama beda urusan — dia identitasnya.
  /// Kalau ref-nya nempel terus, teknisi yang menimpa hasil direktori dengan
  /// perusahaan lain mengirim id tempat yang nunjuk ke perusahaan yang salah,
  /// dan penjaga kembar di server jadi mencocokkan hal yang keliru.
  void _namaBerubah() {
    final sekarang = _nama.text.trim();

    if (_ref != null && sekarang != _namaDariDirektori) {
      _ref = null;
      _namaDariDirektori = null;
    }

    // Kandidat itu jawaban server buat nama YANG ITU. Begitu namanya berubah,
    // dia jawaban buat pertanyaan yang sudah nggak ditanyakan lagi — tapi
    // tile-nya masih kepajang dan masih bisa diketuk, memulangkan PT yang sama
    // sekali beda dari yang lagi diketik. Alatnya mendarat di pelanggan yang
    // salah, tanpa satu pun error muncul di sepanjang jalur.
    //
    // `_bolehTetapBuat` bahaya lewat jalan lain: dia mengirim `tetap_buat:
    // true` buat nama yang BELUM pernah diperiksa server, jadi kembar bisa
    // lahir tanpa kandidatnya pernah ditunjukkan sekali pun — persis penjagaan
    // yang bikin tombol itu ada.
    //
    // Diadu ke nama saat tabrakan, bukan "ada perubahan apa pun": listener
    // controller juga nyala waktu kursor pindah, dan membersihkan di situ bikin
    // kandidatnya kedip hilang tanpa teknisi mengetik apa-apa.
    if (_namaSaatTabrakan != null && sekarang != _namaSaatTabrakan) {
      _lupakanTabrakan();
    }

    setState(() {});
  }

  /// Buang keadaan tabrakan. Ketiganya sekaligus — ketinggalan satu bikin
  /// separuh keadaan lama nempel ke nama baru.
  void _lupakanTabrakan() {
    _kandidat = const [];
    _bolehTetapBuat = false;
    _pesanGagal = null;
    _namaSaatTabrakan = null;
  }

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw Exception('token hilang');
    return token;
  }

  Future<void> _cariDirektori() async {
    final kata = _nama.text.trim();
    if (kata.length < 3 || _mencari) return;

    setState(() {
      _mencari = true;
      _pesanDirektori = null;
      _hasilDirektori = null;
    });

    try {
      final hasil = await ref
          .read(customerLookupServiceProvider)
          .cariDirektori(await _token(), search: kata);
      if (!mounted) return;
      setState(() => _hasilDirektori = hasil);
    } on DirektoriTidakSiapException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        // Pesan servernya SENGAJA nggak diteruskan apa adanya. Dia ditulis buat
        // yang memasang server, bukan buat yang lagi berdiri di depan pelanggan.
        _direktoriTiada = e.belumDisetel;
        _pesanDirektori = e.belumDisetel
            ? l10n.pelangganBaruDirektoriTiadaLab
            : l10n.pelangganBaruDirektoriMati;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _pesanDirektori = AppLocalizations.of(context).equipPelangganGagal,
      );
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  void _pakaiDariDirektori(PerusahaanDirektori perusahaan) {
    // Di-trim SEBELUM dipakai, dan dua-duanya dari nilai yang sama.
    //
    // Menyetel `_nama.text` memicu [_namaBerubah] seketika, dan listener itu
    // mengadu `_nama.text.trim()` ke [_namaDariDirektori]. Disimpan mentah
    // sementara yang diadu sudah ter-trim, nama direktori yang punya spasi di
    // ujung bikin adunya gagal di detik itu juga — `_ref` lepas persis sesudah
    // teknisi memilihnya, dan server kehilangan pencocokan tempat yang persis
    // tanpa ada yang kelihatan berubah di layar.
    //
    // Spasi ekor bukan hal langka: nama tempat di direktori diketik manusia.
    final nama = perusahaan.nama.trim();

    setState(() {
      _ref = perusahaan.ref;
      _namaDariDirektori = nama;
      _nama.text = nama;
      _alamat.text = perusahaan.alamat?.trim() ?? '';
      _hasilDirektori = null;
      // Tabrakan dari percobaan sebelumnya nggak boleh nempel ke pilihan baru —
      // kandidat yang tertinggal di layar bikin teknisi mengira PT yang baru
      // dia pilih ini yang kembar.
      _lupakanTabrakan();
    });
  }

  Future<void> _daftarkan({bool tetapBuat = false}) async {
    if (_nama.text.trim().isEmpty || _menyimpan) return;

    setState(() {
      _menyimpan = true;
      _pesanGagal = null;
      // Percobaan BARU mulai dari bersih. Yang tembus sengaja nggak: dia
      // lanjutan dari tabrakan yang lagi dipajang, dan membuangnya di sini
      // bikin tombolnya hilang persis waktu ditekan.
      if (!tetapBuat) _lupakanTabrakan();
    });

    try {
      final pelanggan = await ref
          .read(customerLookupServiceProvider)
          .daftarkan(
            await _token(),
            nama: _nama.text.trim(),
            alamat: _alamat.text.trim(),
            direktoriRef: _ref,
            tetapBuat: tetapBuat,
          );

      // Daftar pelanggan di sheet pencarian sudah basi begitu baris ini lahir.
      ref.invalidate(customerLookupProvider);

      if (!mounted) return;
      Navigator.of(context).pop<CustomerLookup>(pelanggan);
    } on PelangganMiripException catch (e) {
      if (!mounted) return;
      setState(() {
        _kandidat = e.kandidat;
        _bolehTetapBuat = !e.namaPersisSudahAda;
        _pesanGagal = e.pesan;
        _namaSaatTabrakan = _nama.text.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _pesanGagal = AppLocalizations.of(context).pelangganBaruGagal,
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final namaKosong = _nama.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pelangganBaruJudul)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.pelangganBaruPengantar, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _nama,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.pelangganBaruNama,
              border: const OutlineInputBorder(),
              errorText: namaKosong ? l10n.pelangganBaruNamaWajib : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Dicari pakai isi kolom nama, bukan kolom pencarian sendiri: yang mau
          // dicocokkan teknisi ke direktori itu nama yang bakal dia simpan.
          // Hilang sama sekali kalau direktorinya nggak dipasang di lab ini.
          // Tombol yang tiap ditekan memulangkan hal yang sama itu bukan
          // pilihan — dia cuma jebakan yang bikin teknisi mengira ada yang rusak.
          if (!_direktoriTiada)
            OutlinedButton.icon(
              onPressed: _nama.text.trim().length < 3 || _mencari
                  ? null
                  : _cariDirektori,
              icon: const Icon(Icons.travel_explore),
              label: Text(l10n.pelangganBaruCariDirektori),
            ),

          if (_mencari)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Warnanya netral, bukan merah: buat teknisi ini bukan kegagalan —
          // jalur ketik tangan di bawahnya jalan penuh, dan itu yang ditunjuk
          // kalimatnya.
          if (_pesanDirektori != null)
            _catatan(
              Icons.info_outline,
              _pesanDirektori!,
              theme,
              theme.colorScheme.onSurfaceVariant,
            ),

          if (_hasilDirektori != null) ..._bagianDirektori(l10n, theme),

          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _alamat,
            textCapitalization: TextCapitalization.words,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.pelangganBaruAlamat,
              helperText: l10n.pelangganBaruAlamatBantu,
              border: const OutlineInputBorder(),
            ),
          ),

          if (_kandidat.isNotEmpty) ..._bagianKandidat(l10n, theme),

          if (_pesanGagal != null && _kandidat.isEmpty)
            _catatan(
              Icons.error_outline,
              _pesanGagal!,
              theme,
              theme.colorScheme.error,
            ),

          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: namaKosong || _menyimpan ? null : () => _daftarkan(),
            child: Text(l10n.pelangganBaruDaftarkan),
          ),
        ],
      ),
    );
  }

  List<Widget> _bagianDirektori(AppLocalizations l10n, ThemeData theme) {
    final hasil = _hasilDirektori!;

    if (hasil.daftar.isEmpty) {
      return [
        _catatan(
          Icons.search_off,
          l10n.pelangganBaruDirektoriKosong,
          theme,
          theme.colorScheme.onSurfaceVariant,
        ),
      ];
    }

    return [
      const SizedBox(height: AppSpacing.md),
      Text(l10n.pelangganBaruDirektoriJudul, style: theme.textTheme.labelLarge),
      // Batas sumbernya ditulis DI LAYAR, bukan cuma di dokumen: yang dipilih
      // di sini mendarat di blok OWNER sertifikat, dan direktori tempat usaha
      // bukan salinan akta.
      _catatan(
        Icons.info_outline,
        l10n.pelangganBaruDirektoriCatatan,
        theme,
        theme.colorScheme.onSurfaceVariant,
      ),
      for (final perusahaan in hasil.daftar)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(perusahaan.nama, style: theme.textTheme.titleMedium),
          subtitle: perusahaan.alamat == null
              ? null
              : Text(perusahaan.alamat!, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => _pakaiDariDirektori(perusahaan),
        ),
      // Atribusi sumbernya, DI BAWAH daftarnya dan apa adanya dari server.
      //
      // Bukan hiasan: sumber bawaannya OpenStreetMap dan ODbL mewajibkan
      // sumbernya disebut di tempat hasilnya dipajang. Kalimatnya nggak
      // diterjemahkan dan nggak dikarang di sini — lihat [HasilDirektori].
      if (hasil.atribusi != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            hasil.atribusi!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }

  List<Widget> _bagianKandidat(AppLocalizations l10n, ThemeData theme) => [
    const SizedBox(height: AppSpacing.md),
    _catatan(
      Icons.copy_all_outlined,
      l10n.pelangganBaruMiripJudul,
      theme,
      theme.colorScheme.error,
    ),
    Text(l10n.pelangganBaruMiripPilih, style: theme.textTheme.bodySmall),
    for (final ada in _kandidat)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(ada.nama, style: theme.textTheme.titleMedium),
        subtitle: ada.alamat == null || ada.alamat!.isEmpty
            ? null
            : Text(ada.alamat!, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.arrow_forward),
        // Memilih yang sudah ada itu jalan keluar yang DIHARAPKAN dari layar
        // ini, jadi dia satu ketukan — bukan disembunyikan di balik "batal"
        // lalu mencari ulang.
        onTap: () => Navigator.of(context).pop<CustomerLookup>(ada),
      ),
    // Cuma muncul kalau kemiripannya beneran bisa ditembus. Nama yang PERSIS
    // sama ditahan unique index di database, dan tombol di situ cuma bikin
    // teknisi menabrak penolakan yang sama berkali-kali.
    if (_bolehTetapBuat)
      TextButton(
        onPressed: _menyimpan ? null : () => _daftarkan(tetapBuat: true),
        child: Text(l10n.pelangganBaruTetapBuat),
      ),
  ];

  Widget _catatan(IconData ikon, String teks, ThemeData theme, Color warna) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon, size: 18, color: warna),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                teks,
                style: theme.textTheme.bodySmall?.copyWith(color: warna),
              ),
            ),
          ],
        ),
      );
}
