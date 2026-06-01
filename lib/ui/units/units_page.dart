import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/unit.dart';
import '../../services/unit_service.dart';
import '../../state/auth_controller.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  Future<void> _addUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    setState(() {
      _saving = true;
    });
    try {
      await context.read<UnitService>().addUnit(
            uid: uid,
            name: _nameController.text.trim(),
            cnpj: _cnpjController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidade salva com sucesso.')),
      );
      _nameController.clear();
      _cnpjController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a unidade.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editUnit(Unit unit) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    final nameController = TextEditingController(text: unit.name);
    final cnpjController = TextEditingController(text: unit.cnpj);

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar unidade'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
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
                  controller: cnpjController,
                  decoration: const InputDecoration(
                    labelText: 'CNPJ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o CNPJ';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await context.read<UnitService>().updateUnit(
                      uid: uid,
                      unitId: unit.id,
                      name: nameController.text.trim(),
                      cnpj: cnpjController.text.trim(),
                    );
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unidade atualizada.')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().user?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    final unitService = context.read<UnitService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Unidade',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Unit>>(
                  stream: unitService.watchUnits(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      final message = snapshot.error.toString().toLowerCase().contains(
                            'permission-denied',
                          )
                          ? 'Sem permissão para listar unidades. Verifique as regras do Firestore para users/{seu uid}/units.'
                          : 'Não foi possível carregar as unidades.';
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final units = snapshot.data ?? [];
                    if (units.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma unidade cadastrada.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: units.length,
                      itemBuilder: (context, index) {
                        final unit = units[index];
                        return ListTile(
                          title: Text(unit.name),
                          subtitle: Text('CNPJ: ${unit.cnpj}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editUnit(unit),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cadastrar / Atualizar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
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
                          controller: _cnpjController,
                          decoration: const InputDecoration(
                            labelText: 'CNPJ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o CNPJ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _addUnit,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Salvar unidade'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

