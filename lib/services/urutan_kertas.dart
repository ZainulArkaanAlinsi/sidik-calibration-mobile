import '../models/worksheet_template.dart' show KotakSel, SelTemplateAsli;

/// Urutan baca sel di KERTAS: per tabel (urutan tabel di templat), dari atas ke
/// bawah baris demi baris, di dalam satu baris dari kiri ke kanan.
///
/// Dipakai layar review supaya teknisi memeriksa sel dalam urutan yang sama
/// dengan matanya menelusuri lembar. Urutan diambil dari kotak sel (geometri
/// formulir), bukan dari nomor baris/Repeat templat: dua tata letak yang
/// berbeda (Repeat melintang atau menurun) tetap terbaca benar.
///
/// Dua sel sebaris bila selisih titik tengah vertikalnya kurang dari separuh
/// tinggi sel yang lebih rendah. Sel tanpa kotak ditaruh paling akhir tabelnya,
/// menurut urutan masuk.
///
/// Hasil: kunci sel → peringkat 0, 1, 2, … (tidak ada dua sel bernilai sama).
Map<String, int> urutanKertas(
  List<SelTemplateAsli> sel,
  List<String> urutTabel,
) {
  final peringkat = <String, int>{};
  var berikutnya = 0;

  final tabelDikenal = [
    ...urutTabel,
    ...{
      for (final s in sel)
        if (!urutTabel.contains(s.tabelId)) s.tabelId,
    },
  ];

  for (final tabel in tabelDikenal) {
    final milikTabel = [
      for (final s in sel)
        if (s.tabelId == tabel) s,
    ];
    final berkotak = [
      for (final s in milikTabel)
        if (s.kotak != null) s,
    ];
    final tanpaKotak = [
      for (final s in milikTabel)
        if (s.kotak == null) s,
    ];

    berkotak.sort((a, b) => _tengahY(a.kotak!).compareTo(_tengahY(b.kotak!)));

    // Kelompokkan jadi baris, lalu urutkan tiap baris dari kiri ke kanan.
    final baris = <List<SelTemplateAsli>>[];
    for (final s in berkotak) {
      final k = s.kotak!;
      if (baris.isNotEmpty) {
        final acuan = baris.last.first.kotak!;
        final tinggi = k.h < acuan.h ? k.h : acuan.h;
        if ((_tengahY(k) - _tengahY(acuan)).abs() < tinggi / 2) {
          baris.last.add(s);
          continue;
        }
      }
      baris.add([s]);
    }

    for (final b in baris) {
      b.sort((a, c) => a.kotak!.x.compareTo(c.kotak!.x));
      for (final s in b) {
        peringkat[s.kunci] = berikutnya++;
      }
    }
    for (final s in tanpaKotak) {
      peringkat[s.kunci] = berikutnya++;
    }
  }

  return peringkat;
}

double _tengahY(KotakSel k) => k.y + k.h / 2;
