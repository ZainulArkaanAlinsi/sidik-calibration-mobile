/// Isian layar untuk lembar kerja berbentuk GRID SENSOR (Enclosure).
///
/// Bedanya dari [LembarKerjaState] yang biasa bukan cuma jumlah kotaknya. Di
/// sepuluh alat lain, baris tabel itu TITIK UKUR yang daftarnya dipatok
/// backend — teknisi cuma mengisi kolom pembacaan. Di sini yang dipatok cuma
/// jumlah KOLOM (pengulangan); barisnya sendiri — berapa termokopel dipasang
/// dan nomor berapa saja — baru ketahuan waktu teknisi menaruh sensornya di
/// chamber. Jadi barisnya bisa ditambah, dikurangi, dan dinomori bebas.
library;

import 'package:flutter/material.dart';

import '../../models/lembar_kerja.dart';

/// Satu baris termokopel di dalam satu set point.
class BarisSensorState {
  BarisSensorState({required this.jumlahPengulangan, int? no, int? channel})
    : pembacaan = List<double?>.filled(jumlahPengulangan, null),
      noCtl = TextEditingController(text: no?.toString() ?? ''),
      channelCtl = TextEditingController(text: channel?.toString() ?? ''),
      pembacaanCtl = List.generate(
        jumlahPengulangan,
        (_) => TextEditingController(),
        growable: false,
      );

  final int jumlahPengulangan;

  /// Nomor termokopel yang TERCETAK di sertifikat sensor lab — Type N mulai
  /// no. 3 (TCN3…TCN12), Type K mulai no. 1.
  ///
  /// Bukan nomor urut baris di layar. Nomor inilah yang menentukan koreksi
  /// mana yang dipakai, dan yang menentukan sensor mana jadi Sensor Acuan.
  final TextEditingController noCtl;

  /// Nomor kanal recorder (CH1..CH20). Cuma dipakai kalau kalibratornya
  /// Recorder — koreksi GL840 dibaca per kanal, bukan per tipe sensor.
  final TextEditingController channelCtl;

  final List<TextEditingController> pembacaanCtl;

  /// Nilai terurai dari [pembacaanCtl]. Sel kosong tetap `null` di posisinya,
  /// **nggak dibuang** — kalau Repeat 2 kosong lalu dibuang, Repeat 3 naik jadi
  /// Repeat 2 dan seluruh nomor pengulangan geser.
  final List<double?> pembacaan;

  int? get no => int.tryParse(noCtl.text.trim());
  int? get channel => int.tryParse(channelCtl.text.trim());

  /// Berapa sel pembacaan yang benar-benar terisi.
  int get jumlahTerisi => pembacaan.where((n) => n != null).length;

  bool get kosongSemua =>
      no == null && channel == null && jumlahTerisi == 0;

  /// Baris ini bakal ditolak hitung backend karena pembacaannya kurang dari 4.
  ///
  /// Master memetakan kolom `[1,2,3,3,4]`; di bawah 4 kolom yang hilang harus
  /// ditebak, dan tebakan itu mendarat di kolom Sebaran Suhu yang TERCETAK.
  /// Ditandai di layar supaya teknisi melengkapinya sekarang — bukan menerima
  /// set point-nya balik sebagai `belum_dihitung` sesudah submit.
  bool get pembacaanKurang => jumlahTerisi > 0 && jumlahTerisi < 4;

  void bacaUlang() {
    for (var i = 0; i < pembacaan.length; i++) {
      final teks = pembacaanCtl[i].text.trim().replaceAll(',', '.');
      pembacaan[i] = teks.isEmpty ? null : double.tryParse(teks);
    }
  }

  void dispose() {
    noCtl.dispose();
    channelCtl.dispose();
    for (final c in pembacaanCtl) {
      c.dispose();
    }
  }
}

/// Satu baris non-termokopel di dalam set point (Indikator enclosure / Suhu
/// Ruang). Nggak punya nomor sensor maupun kanal.
class BarisDeretState {
  BarisDeretState({required this.jumlahPengulangan})
    : nilai = List<double?>.filled(jumlahPengulangan, null),
      ctl = List.generate(
        jumlahPengulangan,
        (_) => TextEditingController(),
        growable: false,
      );

  final int jumlahPengulangan;
  final List<double?> nilai;
  final List<TextEditingController> ctl;

  int get jumlahTerisi => nilai.where((n) => n != null).length;
  bool get kosongSemua => jumlahTerisi == 0;

  void bacaUlang() {
    for (var i = 0; i < nilai.length; i++) {
      final teks = ctl[i].text.trim().replaceAll(',', '.');
      nilai[i] = teks.isEmpty ? null : double.tryParse(teks);
    }
  }

  void dispose() {
    for (final c in ctl) {
      c.dispose();
    }
  }
}

/// Satu SET POINT: suhu yang dituju, grid termokopelnya, baris Indikator, dan
/// baris Suhu Ruang.
class SetPointGridState {
  SetPointGridState({
    required this.bentuk,
    double? titikUkur,
    int? jumlahSensorAwal,
  }) : titikCtl = TextEditingController(
         text: titikUkur == null ? '' : _angka(titikUkur),
       ),
       indikator = BarisDeretState(
         jumlahPengulangan: bentuk.pengulangan.length,
       ),
       suhuRuang = BarisDeretState(
         jumlahPengulangan: bentuk.pengulangan.length,
       ) {
    final n = jumlahSensorAwal ?? bentuk.jumlahSensorSaran;
    for (var i = 0; i < n; i++) {
      sensor.add(BarisSensorState(jumlahPengulangan: bentuk.pengulangan.length));
    }
  }

  final GridSensorBentuk bentuk;

  /// Set point dalam °C — `titik_ukur` di payload.
  final TextEditingController titikCtl;

  final List<BarisSensorState> sensor = [];
  final BarisDeretState indikator;

  /// Digambar karena ada di kertas, TAPI nggak ikut dikirim — backend belum
  /// punya tempat menampungnya. Lihat [GridSensorBentuk.barisSuhuRuang].
  final BarisDeretState suhuRuang;

  double? get titikUkur {
    final teks = titikCtl.text.trim().replaceAll(',', '.');
    return teks.isEmpty ? null : double.tryParse(teks);
  }

  /// Baris termokopel yang benar-benar terisi — yang dikirim ke backend.
  List<BarisSensorState> get sensorTerisi =>
      sensor.where((s) => s.no != null && s.jumlahTerisi > 0).toList();

  /// Set point yang sama sekali belum disentuh: nggak ada pembacaan termokopel
  /// MAUPUN Indikator. Backend mengabaikannya; layar juga nggak mengirimnya.
  bool get kosongSemua =>
      sensorTerisi.isEmpty &&
      indikator.kosongSemua &&
      suhuRuang.kosongSemua &&
      titikUkur == null;

  /// Nomor termokopel yang KEMBAR di set point ini — ditolak backend 422.
  ///
  /// Nomor yang sama di set point LAIN normal dan diterima; memang begitu cara
  /// alat ini dipakai (sembilan termokopel yang sama dipindah ke set point
  /// berikutnya). Jadi pengecekannya per set point, bukan sesi.
  List<int> get nomorKembar {
    final hitung = <int, int>{};
    for (final s in sensorTerisi) {
      hitung[s.no!] = (hitung[s.no!] ?? 0) + 1;
    }
    final kembar = [
      for (final e in hitung.entries)
        if (e.value > 1) e.key,
    ]..sort();
    return kembar;
  }

  /// Nomor termokopel yang jadi **Sensor Acuan** — yang TERKECIL di antara
  /// yang terisi. Keseragaman diukur relatif ke sensor ini.
  ///
  /// Dihitung ulang tiap kali, bukan disimpan: sensor yang kolomnya dikosongkan
  /// keluar dari hitungan, dan kalau nomor terkecil yang keluar, acuannya
  /// memang pindah ke nomor berikutnya. Layar harus menunjukkan yang berlaku
  /// SEKARANG, bukan yang berlaku waktu barisnya pertama diketik.
  int? get nomorAcuan {
    final nomor = sensorTerisi.map((s) => s.no!).toList()..sort();
    return nomor.isEmpty ? null : nomor.first;
  }

  /// Baris termokopel yang pembacaannya masih di bawah 4.
  List<BarisSensorState> get sensorPembacaanKurang =>
      sensorTerisi.where((s) => s.pembacaanKurang).toList();

  /// Alasan set point ini bakal masuk `belum_dihitung` kalau dikirim apa
  /// adanya. Kosong = aman.
  ///
  /// Sengaja memakai kalimat yang sama dengan `alasan` dari backend, supaya
  /// teknisi nggak ketemu dua penjelasan berbeda untuk satu kondisi yang sama.
  List<String> peringatan(String? merkKalibrator) {
    if (kosongSemua) return const [];
    final pesan = <String>[];

    final terisi = sensorTerisi;
    if (terisi.isEmpty) {
      pesan.add('Belum ada termokopel yang diisi — set point ini nggak dihitung.');
    } else if (terisi.length < 2) {
      pesan.add(
        'Baru 1 termokopel. Keseragaman & Variasi itu selisih antar-posisi — '
        'dengan satu sensor keduanya keluar 0,0 seolah sudah terbukti seragam. '
        'Minimal 2.',
      );
    }

    if (terisi.isNotEmpty && indikator.kosongSemua) {
      pesan.add('Baris Indikator masih kosong — nggak ada bahan buat budget.');
    }

    final kurang = sensorPembacaanKurang;
    if (kurang.isNotEmpty) {
      final daftar = kurang.map((s) => 'no. ${s.no} (${s.jumlahTerisi}×)').join(', ');
      pesan.add('Pembacaan kurang dari 4: $daftar.');
    }

    final kembar = nomorKembar;
    if (kembar.isNotEmpty) {
      pesan.add('Nomor termokopel kembar: ${kembar.join(", ")}. Ditolak server.');
    }

    if (bentuk.butuhChannel(merkKalibrator)) {
      final tanpaKanal = terisi.where((s) => s.channel == null).toList();
      if (tanpaKanal.isNotEmpty) {
        final daftar = tanpaKanal.map((s) => 'no. ${s.no}').join(', ');
        pesan.add(
          'Kalibrator Recorder: Channel wajib diisi. Belum ada di $daftar.',
        );
      }
    }

    return pesan;
  }

  void bacaUlang() {
    for (final s in sensor) {
      s.bacaUlang();
    }
    indikator.bacaUlang();
    suhuRuang.bacaUlang();
  }

  void tambahSensor() =>
      sensor.add(BarisSensorState(jumlahPengulangan: bentuk.pengulangan.length));

  void hapusSensor(int index) {
    if (index < 0 || index >= sensor.length) return;
    sensor.removeAt(index).dispose();
  }

  void dispose() {
    titikCtl.dispose();
    for (final s in sensor) {
      s.dispose();
    }
    indikator.dispose();
    suhuRuang.dispose();
  }

  static String _angka(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// Seluruh isian grid satu sesi — daftar set point.
class GridSensorState {
  GridSensorState({required this.bentuk, int jumlahSetPointAwal = 1}) {
    for (var i = 0; i < jumlahSetPointAwal; i++) {
      setPoint.add(SetPointGridState(bentuk: bentuk));
    }
  }

  final GridSensorBentuk bentuk;
  final List<SetPointGridState> setPoint = [];

  /// Set point yang layak dikirim. Yang benar-benar kosong dibuang di sini —
  /// backend mengabaikannya juga, tapi mengirimnya cuma bikin payload gemuk
  /// dan bikin daftar `belum_dihitung` penuh baris yang teknisi memang nggak
  /// berniat isi.
  List<SetPointGridState> get setPointTerisi =>
      setPoint.where((sp) => !sp.kosongSemua).toList();

  /// Semua peringatan pra-kirim, sudah berlabel set point-nya.
  List<String> peringatan(String? merkKalibrator) {
    final pesan = <String>[];
    for (var i = 0; i < setPoint.length; i++) {
      final sp = setPoint[i];
      if (sp.kosongSemua) continue;
      final label = sp.titikUkur == null
          ? 'Set Point ${i + 1}'
          : 'Set Point ${SetPointGridState._angka(sp.titikUkur!)} °C';
      for (final p in sp.peringatan(merkKalibrator)) {
        pesan.add('$label: $p');
      }
    }
    return pesan;
  }

  void bacaUlang() {
    for (final sp in setPoint) {
      sp.bacaUlang();
    }
  }

  void tambahSetPoint() => setPoint.add(SetPointGridState(bentuk: bentuk));

  void hapusSetPoint(int index) {
    if (index < 0 || index >= setPoint.length) return;
    setPoint.removeAt(index).dispose();
  }

  /// `measurements[]` siap kirim.
  ///
  /// Baris **Suhu Ruang sekarang ikut dikirim**. Dulu nggak, karena backend
  /// belum punya tempat menampungnya — dan mengirim ke tempat yang nggak ada
  /// berarti angkanya hilang tanpa satu pun pesan. Sekarang tempatnya ada:
  /// `raw_measurements.peran_sensor = 'suhu_ruang'`.
  ///
  /// Yang TETAP berlaku: angkanya cuma DICATAT, nggak ikut ngitung apa pun.
  /// Di master dia nol konsumen — nol rumus membacanya — jadi membuatnya
  /// berpengaruh justru bikin hasil aplikasi beda dari hitungan lab di kertas.
  /// Yang kecetak di sertifikat itu Suhu Ruangan awal/akhir di blok Kondisi
  /// Lingkungan; nama mirip, hal beda.
  List<Map<String, dynamic>> payload({
    required String satuan,
    required bool pakaiChannel,
  }) {
    final hasil = <Map<String, dynamic>>[];

    for (final sp in setPointTerisi) {
      final grid = <Map<String, dynamic>>[];
      for (final s in sp.sensorTerisi) {
        grid.add({
          'no': s.no,
          if (pakaiChannel && s.channel != null) 'channel': s.channel,
          // Dikirim penuh sepanjang kolom, termasuk null-nya. Backend yang
          // menyaring; layar nggak boleh menggeser nomor pengulangan.
          'pembacaan': s.pembacaan,
        });
      }

      hasil.add({
        'titik_ukur': sp.titikUkur,
        'satuan': satuan,
        if (grid.isNotEmpty) 'sensor_grid': grid,
        if (!sp.indikator.kosongSemua) 'indikator': sp.indikator.nilai,
        if (!sp.suhuRuang.kosongSemua) 'suhu_ruang': sp.suhuRuang.nilai,
      });
    }

    return hasil;
  }

  void dispose() {
    for (final sp in setPoint) {
      sp.dispose();
    }
  }
}
