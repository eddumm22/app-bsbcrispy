import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../state/auth_controller.dart';
import '../auth/auth_gate.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _passwordController.text;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada com sucesso.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'requires-recent-login' ||
          e.code == 'user-not-logged-in') {
        const message =
            'Senha alterada. Por segurança, entre novamente no aplicativo.';

        await context.read<AuthController>().signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(message)),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
        return;
      }

      setState(() {
        _error = 'Não foi possível alterar a senha. Tente novamente.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível alterar a senha. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alterar senha'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Defina uma nova senha',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a nova senha';
                    }
                    final hasMinLength = value.length >= 7;
                    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                    final hasSpecial =
                        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\];\\/]')
                            .hasMatch(value);
                    if (!hasMinLength || !hasLetter || !hasSpecial) {
                      return 'Use pelo menos 7 caracteres,\ncom letras e caractere especial.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nova senha',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme a nova senha';
                    }
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar nova senha'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

