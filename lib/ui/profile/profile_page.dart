import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_profile_service.dart';
import '../../state/auth_controller.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) {
      setState(() {
        _error = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    try {
      final profile =
          await context.read<UserProfileService>().getUserProfile(user.uid);
      if (!mounted) return;
      _firstNameController.text = (profile?['firstName'] as String?) ?? '';
      _lastNameController.text = (profile?['lastName'] as String?) ?? '';
      _emailController.text = user.email ?? '';
      final timestamp = profile?['birthDate'];
      if (timestamp is Timestamp) {
        _birthDate = timestamp.toDate();
      }
      _gender = profile?['gender'] as String?;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o perfil.';
        _loading = false;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(2000);
    final first = DateTime(1900);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
      locale: const Locale('pt', 'BR'),
    );
    if (selected != null) {
      setState(() {
        _birthDate = selected;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) {
      setState(() {
        _error = 'Usuário não autenticado.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<UserProfileService>().updateUserProfile(
            uid: user.uid,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            birthDate: _birthDate!,
            gender: _gender ?? 'Outro',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível salvar o perfil.';
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Perfil',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Sobrenome',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o sobrenome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _saving ? null : _pickBirthDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Data de nascimento',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _formatDate(_birthDate),
                    ),
                    validator: (_) {
                      if (_birthDate == null) {
                        return 'Selecione a data de nascimento';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
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
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _gender = value;
                        });
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione o sexo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
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
                  onPressed: _saving ? null : _onSave,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          );
                        },
                  child: const Text('Alterar senha'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

