import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../services/receipt_service.dart';
import '../../services/supplier_service.dart';
import '../../state/auth_controller.dart';
import 'receipt_detail_page.dart';

class ReceiptsHistoryPage extends StatelessWidget {
  const ReceiptsHistoryPage({super.key});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(2);
    return 'R\$ ${s.replaceAll('.', ',')}';
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

    final receiptService = context.read<ReceiptService>();
    final supplierService = context.read<SupplierService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Recebimentos'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<Supplier>>(
            stream: supplierService.watchSuppliers(uid),
            builder: (context, suppliersSnapshot) {
              final suppliers = suppliersSnapshot.data ?? [];
              final supplierMap = {
                for (final s in suppliers) s.id: s.legalName,
              };

              if (suppliersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<Receipt>>(
                stream: receiptService.watchReceipts(uid),
                builder: (context, receiptSnapshot) {
                  if (receiptSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final receipts = receiptSnapshot.data ?? [];

                  if (receipts.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum recebimento registrado ainda.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: receipts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      final supplierName =
                          supplierMap[receipt.supplierId] ??
                              'Fornecedor não definido';
                      final dateStr = _formatDate(receipt.date);
                      final totalStr = _formatCurrency(receipt.totalGeneral);

                      return Card(
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReceiptDetailPage(
                                  receiptId: receipt.id,
                                  receiptDate: receipt.date,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Data: $dateStr',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        supplierName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      totalStr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

