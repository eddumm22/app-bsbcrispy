// Mantido apenas para compatibilidade eventual; a navegação principal
// agora usa AppShell em vez deste widget.
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('HomeScreen foi substituída pelo AppShell.'),
      ),
    );
  }
}

