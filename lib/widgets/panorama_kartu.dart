import 'package:flutter/material.dart';

/// Latar kepala kartu akun — ilustrasi lab (`assets/background-card.jpg`).
///
/// ## Kenapa gambarnya dipotong, dan bagian mana yang dipertahankan
///
/// Gambarnya nyaris persegi (735x686), sementara kepala kartu itu pita
/// lebar-pendek. Dipaksa muat utuh (`contain`), ilustrasinya nyempil kecil di
/// tengah dengan dua bidang kosong di kiri-kanan. Jadi dipakai [BoxFit.cover]
/// — terisi penuh, sebagian gambar keluar bingkai.
///
/// Yang dipilih bertahan di bingkai itu bagian ATAS ([Alignment.topCenter]):
/// di situ letak molekul, atom, dan pipet — bentuk renggang yang masih kebaca
/// walau cuma kelihatan sepotong. Bagian bawah gambarnya justru yang paling
/// padat (labu, mikroskop, kacamata); dipotong setinggi pita ini dia jadi
/// deretan potongan benda yang nggak kebaca sebagai apa pun.
///
/// ## Kenapa tema gelap diperlakukan beda, bukan dikasih gambar kedua
///
/// Ilustrasinya cuma satu dan warnanya biru terang. Ditempel apa adanya di
/// tema gelap, dia jadi satu-satunya bidang menyala di layar yang seluruhnya
/// redup — mata ketarik ke hiasan, bukan ke datanya.
///
/// Jadi di tema gelap dia diredupkan dan ditarik ke rona nila lewat satu
/// lapisan warna. Bukan dua berkas gambar: satu berkas 45 KB yang diperlakukan
/// beda jauh lebih murah, dan nggak ada risiko dua gambar yang lama-lama beda
/// sendiri.
class PanoramaKartu extends StatelessWidget {
  const PanoramaKartu({
    super.key,
    required this.benih,
    this.tinggi = 118,
    this.anak,
  });

  /// Nggak lagi dipakai sejak latarnya jadi gambar.
  ///
  /// Dipertahankan supaya pemanggilnya nggak perlu diubah, dan supaya jelas
  /// buat yang membaca: dulu ini pengacak posisi bintang & pohon waktu
  /// latarnya masih dilukis `CustomPainter`.
  final int benih;

  final double tinggi;
  final Widget? anak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gelap = theme.brightness == Brightness.dark;

    return SizedBox(
      height: tinggi,
      width: double.infinity,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/background-card.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              // TANPA `cacheWidth`/`cacheHeight`, dan itu disengaja.
              //
              // Sempat dipasang `cacheHeight` setinggi pita ini, dengan alasan
              // "jangan simpan bitmap 735x686 buat pita setinggi 76 dp". Dua
              // hal salah di situ:
              //
              // 1. Dengan `BoxFit.cover` di kotak lebar-pendek, yang nentuin
              //    skala itu LEBAR, bukan tinggi. Membatasi tinggi decode bikin
              //    gambarnya cuma selebar ~111 px lalu diperbesar paksa ke
              //    lebar kartu — dan hasilnya buram, kelihatan jelas di render.
              // 2. Pemborosan yang mau dihindari itu nggak ada. `ImageCache`
              //    Flutter berbagi SATU salinan ter-decode per (aset, ukuran),
              //    jadi 30 kartu yang memuat aset yang sama nggak bikin 30
              //    bitmap — bikin satu.
            ),

            // Tema gelap: diredupkan dan ditarik ke rona nila.
            if (gelap)
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xCC141B3D)),
              ),

            // Pudar tipis di kaki gambar, biar dia nyambung ke bidang teks di
            // bawahnya dan nggak berhenti dengan garis potong.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0, 0.55],
                  colors: [
                    theme.colorScheme.surface.withValues(
                      alpha: gelap ? 0.55 : 0.40,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            ?anak,
          ],
        ),
      ),
    );
  }
}
