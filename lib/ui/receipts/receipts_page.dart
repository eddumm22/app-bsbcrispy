import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/receipt_item.dart';
import '../../models/supplier.dart';
import '../../services/product_service.dart';
import '../../services/receipt_service.dart';
import '../../services/supplier_service.dart';
import '../../state/auth_controller.dart';
import 'receipts_history_page.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptItemRowDraft {
  _ReceiptItemRowDraft()
      : quantityController = TextEditingController(),
        unitPriceController = TextEditingController();

  String? productId;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

class _ReceiptItemRow extends StatefulWidget {
  const _ReceiptItemRow({
    super.key,
    required this.draft,
    required this.products,
    required this.onAnyChanged,
    required this.canRemove,
    required this.onRemove,
  });

  final _ReceiptItemRowDraft draft;
  final List<Product> products;
  final VoidCallback onAnyChanged;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<_ReceiptItemRow> createState() => _ReceiptItemRowState();
}

class _ReceiptItemRowState extends State<_ReceiptItemRow> {
  @override
  void initState() {
    super.initState();
    widget.draft.quantityController.addListener(_handleChanged);
    widget.draft.unitPriceController.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.draft.quantityController.removeListener(_handleChanged);
    widget.draft.unitPriceController.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onAnyChanged();
  }

  double? _tryParseDoubleOrNull(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(2);
    return 'R\$ ${s.replaceAll('.', ',')}';
  }

  double? _computeTotalCost() {
    final productId = widget.draft.productId;
    final qty = _tryParseDoubleOrNull(widget.draft.quantityController.text);
    final unitPrice =
        _tryParseDoubleOrNull(widget.draft.unitPriceController.text);

    if (productId == null || productId.isEmpty) return null;
    if (qty == null || unitPrice == null) return null;
    if (qty <= 0 || unitPrice <= 0) return null;
    return qty * unitPrice;
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    final draftProductId = widget.draft.productId;
    final hasValidProduct = draftProductId != null &&
        draftProductId.isNotEmpty &&
        products.any((p) => p.id == draftProductId);

    final productValue = hasValidProduct ? draftProductId : null;
    final totalCost = _computeTotalCost();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: productValue,
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: products
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      widget.draft.productId = value;
                      _handleChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Remover item',
                  onPressed: widget.canRemove ? widget.onRemove : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.draft.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.draft.unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço unitário',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              totalCost == null ? 'Total do item: -' : 'Total do item: ${_formatCurrency(totalCost)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  String? _supplierId;
  bool _didInitSupplier = false;
  bool _saving = false;

  final ValueNotifier<double> _totalGeneralNotifier = ValueNotifier<double>(0);

  final _invoiceNumberController = TextEditingController();

  final List<_ReceiptItemRowDraft> _items = [
    _ReceiptItemRowDraft(),
  ];

  @override
  void initState() {
    super.initState();
    _totalGeneralNotifier.value = _computeDraftTotalGeneral();
  }

  @override
  void dispose() {
    _totalGeneralNotifier.dispose();
    _invoiceNumberController.dispose();
    for (final draft in _items) {
      draft.dispose();
    }
    super.dispose();
  }

  void _recomputeTotalGeneral() {
    _totalGeneralNotifier.value = _computeDraftTotalGeneral();
  }

  String _normalizeInvoiceNumber(String raw) {
    // Remove espaços e padronize para maiúsculas para consistência.
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '');
    return cleaned.toUpperCase();
  }

  void _resetToSingleEmptyRow() {
    if (_items.isEmpty) {
      _items.add(_ReceiptItemRowDraft());
      return;
    }

    for (final draft in _items.skip(1)) {
      draft.dispose();
    }
    _items.removeRange(1, _items.length);

    final first = _items.first;
    first.productId = null;
    first.quantityController.clear();
    first.unitPriceController.clear();
  }

  double? _tryParseDoubleOrNull(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  bool _isPositiveNumber(double? value) => value != null && value > 0;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(2);
    return 'R\$ ${s.replaceAll('.', ',')}';
  }

  double _computeDraftTotalGeneral() {
    double total = 0;
    for (final draft in _items) {
      final qty = _tryParseDoubleOrNull(draft.quantityController.text);
      final unitPrice = _tryParseDoubleOrNull(draft.unitPriceController.text);
      if (draft.productId == null || qty == null || unitPrice == null) continue;
      if (qty <= 0 || unitPrice <= 0) continue;
      total += qty * unitPrice;
    }
    return total;
  }

  Widget _buildReceiptItemRows({
    required List<Product> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _items.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _ReceiptItemRow(
            key: ValueKey(_items[index]),
            draft: _items[index],
            products: products,
            onAnyChanged: _recomputeTotalGeneral,
            canRemove: _items.length > 1,
            onRemove: () {
              setState(() {
                _items[index].dispose();
                _items.removeAt(index);
              });
            },
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _items.add(_ReceiptItemRowDraft());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar item'),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAndActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total geral',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<double>(
                  valueListenable: _totalGeneralNotifier,
                  builder: (context, total, _) {
                    return Text(
                      _formatCurrency(total),
                      style: Theme.of(context).textTheme.headlineSmall,
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Salvar recebimento'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReceiptsHistoryPage(),
              ),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text('Ver histórico de recebimentos'),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    if (_saving) return;

    final auth = context.read<AuthController>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    if (_supplierId == null || _supplierId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um fornecedor antes de salvar o recebimento.'),
        ),
      );
      return;
    }

    // Monta itens válidos e impede inconsistência (partial preenchido).
    final receiptItems = <ReceiptItem>[];

    for (final draft in _items) {
      final productId = draft.productId;
      final qtyRaw = draft.quantityController.text;
      final unitPriceRaw = draft.unitPriceController.text;

      final qty = _tryParseDoubleOrNull(qtyRaw);
      final unitPrice = _tryParseDoubleOrNull(unitPriceRaw);

      final hasAnyField = productId != null ||
          qtyRaw.trim().isNotEmpty ||
          unitPriceRaw.trim().isNotEmpty;

      if (!hasAnyField) continue; // linha vazia -> ignora

      if (productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um produto para cada item informado.'),
          ),
        );
        return;
      }

      if (!_isPositiveNumber(qty) || !_isPositiveNumber(unitPrice)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe quantidade e preço unitário válidos (maior que zero) para todos os itens.'),
          ),
        );
        return;
      }

      final totalCost = qty! * unitPrice!;
      receiptItems.add(
        ReceiptItem(
          productId: productId,
          quantity: qty,
          unitPrice: unitPrice,
          totalCost: totalCost,
        ),
      );
    }

    if (receiptItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item válido para salvar o recebimento.'),
        ),
      );
      return;
    }

    final totalGeneral =
        receiptItems.fold<double>(0, (sum, item) => sum + item.totalCost);

    final invoiceNumber = _normalizeInvoiceNumber(_invoiceNumberController.text);
    if (invoiceNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o número da nota para este recebimento.'),
        ),
      );
      return;
    }

    final now = DateTime.now();

    setState(() {
      _saving = true;
    });

    try {
      final receiptService = context.read<ReceiptService>();

      final isDuplicate = await receiptService.invoiceNumberExistsForSupplier(
        uid: uid,
        supplierId: _supplierId!,
        invoiceNumber: invoiceNumber,
      );
      if (isDuplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Já existe uma nota com esse número para este fornecedor'),
          ),
        );
        return;
      }

      final receiptId = await receiptService.saveReceipt(
        uid: uid,
        supplierId: _supplierId!,
        invoiceNumber: invoiceNumber,
        date: now,
        totalGeneral: totalGeneral,
        items: receiptItems,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recebimento salvo com sucesso! ID: $receiptId'),
        ),
      );

      if (!mounted) return;
      setState(() {
        _resetToSingleEmptyRow();
      });
      _invoiceNumberController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o recebimento. Tente novamente.'),
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
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    final receiptDate = DateTime.now();
    final supplierService = context.read<SupplierService>();
    final productService = context.read<ProductService>();

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Recebimentos'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset + 16),
          child: StreamBuilder<List<Supplier>>(
            stream: supplierService.watchSuppliers(uid),
            builder: (context, suppliersSnapshot) {
              if (suppliersSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final suppliers = suppliersSnapshot.data ?? [];

              if (suppliers.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cadastre um fornecedor',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você precisa de pelo menos um fornecedor para registrar recebimentos.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }

              if (!_didInitSupplier && _supplierId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _supplierId = suppliers.first.id;
                    _didInitSupplier = true;
                  });
                });
              }

              final selectedSupplierId = _supplierId;
              final selectedSupplierName = suppliers
                  .firstWhere(
                    (s) => s.id == selectedSupplierId,
                    orElse: () => suppliers.first,
                  )
                  .legalName;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Novo recebimento',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Data: ${_formatDate(receiptDate)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _invoiceNumberController,
                            enabled: !_saving,
                            decoration: const InputDecoration(
                              labelText: 'Número da nota',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedSupplierId,
                            decoration: const InputDecoration(
                              labelText: 'Fornecedor',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: suppliers
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(s.legalName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _supplierId = value;
                                _resetToSingleEmptyRow();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          if (selectedSupplierId != null)
                            Text(
                              'Produtos serão filtrados para: $selectedSupplierName',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedSupplierId == null)
                    const Text('Selecione um fornecedor para continuar.')
                  else
                    StreamBuilder<List<Product>>(
                      stream: productService.watchProductsBySupplier(
                        uid: uid,
                        supplierId: selectedSupplierId,
                      ),
                      builder: (context, productsSnapshot) {
                        if (productsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final products = productsSnapshot.data ?? [];

                        if (products.isEmpty) {
                          return Text(
                            'Nenhum produto cadastrado para este fornecedor. Cadastre produtos antes de registrar recebimentos.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Itens do recebimento',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildReceiptItemRows(products: products),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _buildTotalAndActions(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


