import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/stock_count_session_item.dart';
import '../../services/product_service.dart';
import '../../services/stock_count_service.dart';
import '../../state/auth_controller.dart';

class StockCountSessionDetailPage extends StatelessWidget {
  const StockCountSessionDetailPage({
    super.key,
    required this.sessionId,
    required this.sessionDate,
  });

  final String sessionId;
  final DateTime sessionDate;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatQty(double value) {
    final isInt = value.truncateToDouble() == value;
    return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    final stockService = context.read<StockCountService>();
    final productService = context.read<ProductService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe da Contagem'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<Product>>(
            stream: productService.watchProducts(uid),
            builder: (context, productsSnapshot) {
              final products = productsSnapshot.data ?? [];
              final productMap = {for (final p in products) p.id: p.name};

              if (productsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<StockCountSessionItem>>(
                stream: stockService.watchStockCountItemsInSession(
                  uid: uid,
                  sessionId: sessionId,
                ),
                builder: (context, itemsSnapshot) {
                  if (itemsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = itemsSnapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Data da contagem',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(sessionDate),
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Itens contados',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    items.length.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum item encontrado para esta contagem.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final productName =
                                      productMap[item.productId] ??
                                          'Produto não definido';

                                  return Card(
                                    elevation: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Quantidade',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                Text(
                                                  _formatQty(item.quantity),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w900,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

