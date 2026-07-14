import 'package:flutter/material.dart';

import '../../widgets/empty_placeholder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const EmptyPlaceholder(
        icon: Icons.space_dashboard_outlined,
        title: 'Dashboard',
        message:
            'Ringkasan alat, kalibrasi terbaru, dan alat yang mau jatuh tempo '
            'muncul di sini setelah API siap.',
      ),
    );
  }
}
