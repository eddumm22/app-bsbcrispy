import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/stock_count_service.dart';
import '../../state/auth_controller.dart';
import 'product_stock_history_page.dart';
import 'stock_count_sessions_history_page.dart';

class StockCountPage extends StatefulWidget {
  const StockCountPage({super.key});

  @override
  State<StockCountPage> createState() => _StockCountPageState();
}

class _StockCountPageState extends State<StockCountPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  late final DateTime _countDate;

  @override
  void initState() {
    super.initState();
    // Data automática e fixa para esta sessão de contagem.
    _countDate = DateTime.now();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String productId) {
    return _controllers.putIfAbsent(
      productId,
      () => TextEditingController(),
    );
  }

  Future<void> _onSave(List<Product> products) async {
    if (_saving) return;

    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    final Map<String, double> quantities = {};

    for (final product in products) {
      final text = _controllers[product.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null || value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quantidade inválida para o produto "${product.name}".',
            ),
          ),
        );
        return;
      }
      quantities[product.id] = value;
    }

    if (quantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe ao menos uma quantidade para salvar.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await context.read<StockCountService>().saveStockCount(
            uid: uid,
            quantitiesByProductId: quantities,
            date: _countDate,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contagem salva com sucesso.')),
      );
      for (final c in _controllers.values) {
        c.clear();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a contagem. Tente novamente.'),
        ),
      );
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
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;
    if (uid == null) {
      return const Center(child: Text('Usuário não autenticado.'));
    }

    final productService = context.read<ProductService>();
    final dateString =
        '${_countDate.day.toString().padLeft(2, '0')}/${_countDate.month.toString().padLeft(2, '0')}/${_countDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contagem de Estoque'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: productService.watchProducts(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const Center(
                child: Text('Nenhum produto cadastrado para contagem.'),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Data da contagem: $dateString',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final controller = _getController(product.id);
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductStockHistoryPage(
                                productId: product.id,
                                productName: product.name,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Unidade: ${product.unit}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: controller,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Qtd',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: products.length,
                  ),
                ),

                // Área de ações dedicada para não “comprimir” o rodapé visual.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _saving ? null : () => _onSave(products),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Salvar contagem'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StockCountSessionsHistoryPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('Ver histórico de contagens'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

