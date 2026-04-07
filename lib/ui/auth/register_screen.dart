import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _dataNascimento;
  String? _sexo;

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataNascimento() async {
    final hoje = DateTime.now();
    final dataInicial = DateTime(2000);
    final dataPrimeira = DateTime(1900);

    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? dataInicial,
      firstDate: dataPrimeira,
      lastDate: hoje,
      locale: const Locale('pt', 'BR'),
    );

    if (selecionada != null) {
      setState(() {
        _dataNascimento = selecionada;
      });
    }
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _nomeController.text.trim(),
      lastName: _sobrenomeController.text.trim(),
      birthDate: _dataNascimento!,
      gender: _sexo!,
    );

    if (!mounted) return;
    if (auth.errorMessage == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cadastro',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sobrenomeController,
                    decoration: const InputDecoration(
                      labelText: 'Sobrenome',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o sobrenome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: auth.isLoading ? null : _selecionarDataNascimento,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: _formatarData(_dataNascimento),
                        ),
                        validator: (_) {
                          if (_dataNascimento == null) {
                            return 'Selecione a data de nascimento';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _sexo,
                    decoration: const InputDecoration(
                      labelText: 'Sexo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Masculino',
                        child: Text('Masculino'),
                      ),
                      DropdownMenuItem(
                        value: 'Feminino',
                        child: Text('Feminino'),
                      ),
                      DropdownMenuItem(
                        value: 'Outro',
                        child: Text('Outro'),
                      ),
                    ],
                    onChanged: auth.isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _sexo = value;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione o sexo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o email';
                      }
                      if (!value.contains('@')) {
                        return 'Informe um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe a senha';
                      }
                      final hasMinLength = value.length >= 7;
                      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                      final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\];\\/]').hasMatch(value);
                      if (!hasMinLength || !hasLetter || !hasSpecial) {
                        return 'Use pelo menos 7 caracteres,\ncom letras e caractere especial.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (auth.errorMessage != null) ...[
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _onSubmit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cadastrar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text('Já tenho conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


