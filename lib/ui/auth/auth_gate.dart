import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../home/app_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.isLoading && auth.user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const AppShell();
    }

    return const LoginScreen();
  }
}


