import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
import '../../state/auth_controller.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    super.key,
    this.initialProduct,
  });

  final Product? initialProduct;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _unit = 'UND';
  bool _perishable = false;
  String _type = 'insumo';
  String? _supplierId;

  bool _saving = false;

  bool get isEditing => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    if (product != null) {
      _nameController.text = product.name;
      _unit = product.unit;
      _perishable = product.perishable;
      _type = product.type;
      _supplierId = product.supplierId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final product = (widget.initialProduct ??
            Product(
              id: '',
              name: '',
              unit: _unit,
              perishable: _perishable,
              type: _type,
              supplierId: _supplierId,
            ))
        .copyWith(
      name: _nameController.text.trim(),
      unit: _unit,
      perishable: _perishable,
      type: _type,
      supplierId: _supplierId,
    );

    Navigator.of(context).pop<Product>(product);
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditing ? 'Editar produto' : 'Novo produto';
    final uid = context.read<AuthController>().user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: uid == null
              ? const Center(child: Text('Usuário não autenticado.'))
              : StreamBuilder<List<Supplier>>(
                  stream: context
                      .read<SupplierService>()
                      .watchSuppliers(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final suppliers = snapshot.data ?? [];
                    final hasSuppliers = suppliers.isNotEmpty;

                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do produto',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe o nome do produto';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unidade de medida',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'UND',
                                child: Text('UND'),
                              ),
                              DropdownMenuItem(
                                value: 'KG',
                                child: Text('KG'),
                              ),
                              DropdownMenuItem(
                                value: 'LT',
                                child: Text('LT'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _unit = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<bool>(
                            value: _perishable,
                            decoration: const InputDecoration(
                              labelText: 'Perecível',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text('Sim'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('Não'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _perishable = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _type,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'insumo',
                                child: Text('Insumo'),
                              ),
                              DropdownMenuItem(
                                value: 'producao_propria',
                                child: Text('Produção Própria'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _type = value;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          if (!hasSuppliers)
                            Card(
                              color: Colors.orange.withOpacity(0.12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Cadastre um fornecedor antes de criar ou editar produtos.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _supplierId,
                              decoration: const InputDecoration(
                                labelText: 'Fornecedor',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Selecione um fornecedor'),
                              items: suppliers.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.legalName),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _supplierId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecione o fornecedor';
                                }
                                return null;
                              },
                            ),

                          const SizedBox(height: 16),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  (_saving || !hasSuppliers) ? null : _onSave,
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Salvar'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

