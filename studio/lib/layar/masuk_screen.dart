import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../inti/lingkungan_studio.dart';
import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';
import '../widget/merek_studio.dart';

/// Layar masuk Studio — UI sendiri, auth BERSAMA (`authProvider` paket
/// sidik_calibration: endpoint, penyimpanan token, dan aturan akun pending
/// sama persis dengan app lapangan).
///
/// Tanpa "Daftar" (akun lahir dari admin) dan tanpa "Lupa sandi" di S1: layar
/// lupa sandi paket bersama bergaya app lapangan, dan versi Studio-nya belum
/// dibangun — lebih jujur tidak menawarkannya daripada tombol yang membuka
/// layar dari aplikasi lain.
class MasukStudioScreen extends ConsumerStatefulWidget {
  const MasukStudioScreen({super.key});

  @override
  ConsumerState<MasukStudioScreen> createState() => _MasukStudioScreenState();
}

class _MasukStudioScreenState extends ConsumerState<MasukStudioScreen> {
  final _identitas = TextEditingController();
  final _sandi = TextEditingController();
  String? _galatIdentitas;
  String? _galatSandi;
  bool _sandiTerlihat = false;

  @override
  void dispose() {
    _identitas.dispose();
    _sandi.dispose();
    super.dispose();
  }

  bool _validasi(StudioL10n l10n) {
    setState(() {
      _galatIdentitas = _identitas.text.trim().isEmpty
          ? l10n.isianIdentitasWajib
          : null;
      _galatSandi = _sandi.text.isEmpty ? l10n.isianSandiWajib : null;
    });
    return _galatIdentitas == null && _galatSandi == null;
  }

  Future<void> _kirim() async {
    final l10n = StudioL10n.of(context);
    if (!_validasi(l10n)) return;
    await ref
        .read(authProvider.notifier)
        .login(identifier: _identitas.text, password: _sandi.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final auth = ref.watch(authProvider);
    final memuat = auth.isLoading;

    final galatMasuk = switch (auth) {
      // ST-01: akun pelanggan ditolak server (`403 bukan_akun_internal`).
      // Pesan server menyuruh pindah ke aplikasi pelanggan; di Studio yang
      // perlu dikatakan: ini memang bukan pintunya.
      AsyncError(:final ApiException error)
          when error.body['kode'] == 'bukan_akun_internal' =>
        l10n.bukanAkunLab,
      // Satu akun Studio (K-50-12): akun lab lain ditolak `403 bukan_akun_studio`.
      AsyncError(:final ApiException error)
          when error.body['kode'] == 'bukan_akun_studio' =>
        l10n.bukanAkunStudio,
      AsyncError(:final AuthException error) => error.message,
      AsyncError(:final error) => _pesanGagal(error, l10n),
      _ => null,
    };

    final formulir = _Formulir(
      identitas: _identitas,
      sandi: _sandi,
      galatIdentitas: _galatIdentitas,
      galatSandi: _galatSandi,
      galatMasuk: galatMasuk,
      memuat: memuat,
      sandiTerlihat: _sandiTerlihat,
      onBalikSandi: () => setState(() => _sandiTerlihat = !_sandiTerlihat),
      onKirim: _kirim,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, batas) {
          final lebar = batas.maxWidth >= 840;
          if (lebar) {
            return Row(
              children: [
                const SizedBox(width: 360, child: _PanelMerek()),
                Expanded(child: _Tengah(child: formulir)),
              ],
            );
          }
          return Column(
            children: [
              const _PanelMerek(ringkas: true),
              Expanded(child: _Tengah(child: formulir)),
            ],
          );
        },
      ),
    );
  }
}

/// Sebut server HANYA kalau galatnya memang galat jaringan; selain itu
/// tampilkan penyebab aslinya (pelajaran `login_screen.dart` app lapangan:
/// pesan "server bermasalah" untuk kegagalan lokal menghabiskan sehari).
String _pesanGagal(Object galat, StudioL10n l10n) {
  final teknis = galat.toString();
  const penandaJaringan = [
    'SocketException',
    'TimeoutException',
    'ClientException',
    'HandshakeException',
    'Connection refused',
    'Failed host lookup',
  ];
  if (penandaJaringan.any(teknis.contains)) return l10n.gagalJaringan;
  return l10n.gagalDiPerangkat(teknis);
}

class _Tengah extends StatelessWidget {
  const _Tengah({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(UkuranStudio.j6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: child,
      ),
    ),
  );
}

/// Panel merek navy — warna sisi yang sama dengan sidebar, jadi masuk dan
/// bekerja terasa satu aplikasi.
class _PanelMerek extends StatelessWidget {
  const _PanelMerek({this.ringkas = false});

  final bool ringkas;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Material(
      color: w.sisi,
      child: SafeArea(
        bottom: !ringkas,
        right: false,
        child: Padding(
          padding: EdgeInsets.all(ringkas ? UkuranStudio.j4 : UkuranStudio.j8),
          child: Align(
            alignment: ringkas ? Alignment.centerLeft : Alignment.bottomLeft,
            child: MerekStudio(ukuranIkon: ringkas ? 36 : 56),
          ),
        ),
      ),
    );
  }
}

class _Formulir extends StatelessWidget {
  const _Formulir({
    required this.identitas,
    required this.sandi,
    required this.galatIdentitas,
    required this.galatSandi,
    required this.galatMasuk,
    required this.memuat,
    required this.sandiTerlihat,
    required this.onBalikSandi,
    required this.onKirim,
  });

  final TextEditingController identitas;
  final TextEditingController sandi;
  final String? galatIdentitas;
  final String? galatSandi;
  final String? galatMasuk;
  final bool memuat;
  final bool sandiTerlihat;
  final VoidCallback onBalikSandi;
  final VoidCallback onKirim;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.masukJudul, style: teks.headlineSmall),
          const SizedBox(height: UkuranStudio.j1),
          Text(l10n.masukKet, style: teks.bodyMedium?.copyWith(color: w.teks2)),
          const SizedBox(height: UkuranStudio.j6),
          if (galatMasuk != null) ...[
            _BannerGalat(pesan: galatMasuk!),
            const SizedBox(height: UkuranStudio.j4),
          ],
          TextField(
            controller: identitas,
            enabled: !memuat,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: l10n.isianIdentitas,
              errorText: galatIdentitas,
              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
            ),
          ),
          const SizedBox(height: UkuranStudio.j3),
          TextField(
            controller: sandi,
            enabled: !memuat,
            obscureText: !sandiTerlihat,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => onKirim(),
            decoration: InputDecoration(
              labelText: l10n.isianSandi,
              errorText: galatSandi,
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                tooltip: sandiTerlihat
                    ? l10n.sembunyikanSandi
                    : l10n.tampilkanSandi,
                icon: Icon(
                  sandiTerlihat
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: onBalikSandi,
              ),
            ),
          ),
          const SizedBox(height: UkuranStudio.j4),
          FilledButton(
            onPressed: memuat ? null : onKirim,
            child: memuat
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.memuat,
                    ),
                  )
                : Text(l10n.tombolMasuk),
          ),
          const SizedBox(height: UkuranStudio.j4),
          const _ServerDanVersi(),
          const _PetunjukDev(),
          const _IsianServerDev(),
        ],
      ),
    );
  }
}

/// ST-01: server yang dituju + versi Studio, teks kecil di bawah tombol —
/// supaya "masuk ke server yang mana, dengan versi berapa" terjawab sebelum
/// masuk, bukan sesudah ada yang salah.
class _ServerDanVersi extends ConsumerWidget {
  const _ServerDanVersi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = WarnaStudio.of(context);
    final alamat = ref.watch(alamatServerStudioProvider);
    return Tooltip(
      message: alamat,
      child: Text(
        StudioL10n.of(
          context,
        ).masukServerVersi(hostServer(alamat), versiStudio),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: w.teksRedup),
      ),
    );
  }
}

class _BannerGalat extends StatelessWidget {
  const _BannerGalat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(UkuranStudio.j3),
        decoration: BoxDecoration(
          color: w.gagalTipis,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
          border: Border(left: BorderSide(color: w.gagal, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: w.gagal),
            const SizedBox(width: UkuranStudio.j2),
            Expanded(
              child: Text(
                pesan,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: w.teks),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Akun uji — HANYA di build `APP_ENV=dev` (lihat [petunjukDevStudioProvider]).
///
/// Kredensialnya fixture lokal seeder API (`SDK-000x` / `rahasia123`, cuma
/// berlaku di lingkungan local/testing), sama dengan petunjuk app lapangan.
class _PetunjukDev extends ConsumerWidget {
  const _PetunjukDev();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(petunjukDevStudioProvider)) return const SizedBox.shrink();

    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: UkuranStudio.j6),
      child: Container(
        padding: const EdgeInsets.all(UkuranStudio.j3),
        decoration: BoxDecoration(
          color: w.permukaanRendah,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
          border: Border.all(color: w.garis),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.devJudul, style: teks.labelSmall),
            const SizedBox(height: UkuranStudio.j1),
            SelectableText(
              'SDK-0001 admin · SDK-0002 teknisi · SDK-0003 viewer\n'
              'rahasia123',
              style: TipografiStudio.angka(ukuran: 12, warna: w.teks),
            ),
            const SizedBox(height: UkuranStudio.j1),
            Text(
              l10n.devServer(ref.watch(alamatServerStudioProvider)),
              style: teks.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Alamat server" — HANYA build `APP_ENV=dev` ([isianServerDevStudioProvider]).
///
/// Untuk tablet di lab yang menembak laptop pengembang lewat Wi-Fi tanpa
/// `adb reverse`: alamat disimpan di perangkat dan dipakai SEKARANG (ApiClient
/// dibangun ulang) serta tiap Studio dibuka (`main` membacanya sebelum frame
/// pertama). Di layar masuk, bukan di Pengaturan, karena server harus benar
/// SEBELUM bisa masuk. Build rilis tidak menampilkan isian ini dan tidak
/// membaca nilai tersimpannya.
class _IsianServerDev extends ConsumerStatefulWidget {
  const _IsianServerDev();

  @override
  ConsumerState<_IsianServerDev> createState() => _IsianServerDevState();
}

class _IsianServerDevState extends ConsumerState<_IsianServerDev> {
  final _alamat = TextEditingController();
  String? _galat;
  bool _tersimpan = false;

  @override
  void initState() {
    super.initState();
    _alamat.text = ref.read(alamatServerStudioProvider);
  }

  @override
  void dispose() {
    _alamat.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final l10n = StudioL10n.of(context);
    final mentah = _alamat.text;
    if (normalisasiAlamatServer(mentah) == null) {
      setState(() {
        _galat = l10n.devAlamatServerTidakSah;
        _tersimpan = false;
      });
      return;
    }
    try {
      await ref.read(alamatServerDevProvider.notifier).simpan(mentah);
    } catch (e) {
      if (mounted) {
        setState(() {
          _galat = l10n.devAlamatServerGagalSimpan('$e');
          _tersimpan = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _galat = null;
      _tersimpan = true;
      _alamat.text = ref.read(alamatServerStudioProvider);
    });
  }

  Future<void> _bawaan() async {
    await ref.read(alamatServerDevProvider.notifier).pakaiBawaan();
    if (!mounted) return;
    setState(() {
      _galat = null;
      _tersimpan = false;
      _alamat.text = ref.read(alamatServerStudioProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isianServerDevStudioProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final ditimpa = ref.watch(alamatServerDevProvider) != null;

    return Padding(
      padding: const EdgeInsets.only(top: UkuranStudio.j3),
      child: Container(
        key: const ValueKey('isian-server-dev'),
        padding: const EdgeInsets.all(UkuranStudio.j3),
        decoration: BoxDecoration(
          color: w.permukaanRendah,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
          border: Border.all(color: w.garis),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _alamat,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _simpan(),
              style: TipografiStudio.angka(ukuran: 12, warna: w.teks),
              decoration: InputDecoration(
                labelText: l10n.devAlamatServer,
                hintText: l10n.devAlamatServerContoh,
                errorText: _galat,
                helperText: _tersimpan ? l10n.devAlamatServerTersimpan : null,
                prefixIcon: const Icon(Icons.dns_outlined, size: 18),
              ),
            ),
            const SizedBox(height: UkuranStudio.j2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.devAlamatServerKet(alamatBawaanStudio()),
                    style: teks.bodySmall?.copyWith(color: w.teksRedup),
                  ),
                ),
                if (ditimpa)
                  TextButton(
                    onPressed: _bawaan,
                    child: Text(l10n.devAlamatServerBawaan),
                  ),
                OutlinedButton(
                  onPressed: _simpan,
                  child: Text(l10n.devAlamatServerSimpan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
