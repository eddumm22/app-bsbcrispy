import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
import '../../state/auth_controller.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _cnpjController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _legalNameController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  Future<void> _addSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    setState(() {
      _saving = true;
    });
    try {
      await context.read<SupplierService>().addSupplier(
            uid: uid,
            legalName: _legalNameController.text.trim(),
            cnpj: _cnpjController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fornecedor salvo com sucesso.')),
      );
      _legalNameController.clear();
      _cnpjController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o fornecedor.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    final legalController = TextEditingController(text: supplier.legalName);
    final cnpjController = TextEditingController(text: supplier.cnpj);

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar fornecedor'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: legalController,
                  decoration: const InputDecoration(
                    labelText: 'Razão Social',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a razão social';
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
                await context.read<SupplierService>().updateSupplier(
                      uid: uid,
                      supplierId: supplier.id,
                      legalName: legalController.text.trim(),
                      cnpj: cnpjController.text.trim(),
                    );
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fornecedor atualizado.')),
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

    final supplierService = context.read<SupplierService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fornecedores',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Supplier>>(
                  stream: supplierService.watchSuppliers(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final suppliers = snapshot.data ?? [];
                    if (suppliers.isEmpty) {
                      return const Center(
                        child: Text('Nenhum fornecedor cadastrado.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = suppliers[index];
                        return ListTile(
                          title: Text(supplier.legalName),
                          subtitle: Text('CNPJ: ${supplier.cnpj}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editSupplier(supplier),
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
                          'Cadastrar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _legalNameController,
                          decoration: const InputDecoration(
                            labelText: 'Razão Social',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe a razão social';
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
                            onPressed: _saving ? null : _addSupplier,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Salvar fornecedor'),
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

