import 'package:flutter/material.dart';

import '../../widgets/empty_placeholder.dart';

class EquipmentListScreen extends StatelessWidget {
  const EquipmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alat')),
      body: const EmptyPlaceholder(
        icon: Icons.straighten_outlined,
        title: 'Daftar Alat',
        message:
            'Daftar alat ukur per kategori, plus form tambah/edit alat. '
            'Digarap minggu 3.',
      ),
    );
  }
}
