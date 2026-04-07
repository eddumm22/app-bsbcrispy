import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../services/product_service.dart';
import '../../services/supplier_service.dart';
import '../../state/auth_controller.dart';
import 'product_form_page.dart';

class ProductsListPage extends StatelessWidget {
  const ProductsListPage({super.key});

  Future<void> _openCreateProduct(BuildContext context) async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => const ProductFormPage(),
      ),
    );
    if (product == null) return;

    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    await context.read<ProductService>().addProduct(uid, product);
    // Feedback visual será o próprio recarregamento da lista;
    // opcionalmente podemos mostrar um SnackBar aqui.
  }

  Future<void> _openEditProduct(
    BuildContext context,
    Product product,
  ) async {
    final edited = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(initialProduct: product),
      ),
    );
    if (edited == null) return;

    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    await context.read<ProductService>().updateProduct(
          uid,
          edited.copyWith(id: product.id),
        );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Product product,
  ) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir produto'),
          content: Text(
            'Tem certeza que deseja excluir o produto "${product.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await context.read<ProductService>().deleteProduct(uid, product.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;

    if (uid == null) {
      return const Center(
        child: Text('Usuário não autenticado.'),
      );
    }

    final productService = context.read<ProductService>();
    final supplierService = context.read<SupplierService>();

    return StreamBuilder<List<Supplier>>(
      stream: supplierService.watchSuppliers(uid),
      builder: (context, supplierSnapshot) {
        final suppliers = supplierSnapshot.data ?? [];
        final supplierMap = <String, String>{
          for (final s in suppliers) s.id: s.legalName,
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Produtos'),
          ),
          body: StreamBuilder<List<Product>>(
            stream: productService.watchProducts(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  supplierSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const Center(
                  child: Text('Nenhum produto cadastrado.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final perishableText = product.perishable ? 'Sim' : 'Não';
                  final typeText = product.type == 'insumo'
                      ? 'Insumo'
                      : 'Produção Própria';

                  final supplierName = product.supplierId == null
                      ? 'Fornecedor não definido'
                      : (supplierMap[product.supplierId!] ??
                          'Fornecedor não definido');

                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'Fornecedor: $supplierName • Unidade: ${product.unit} • Perecível: $perishableText • Tipo: $typeText',
                    ),
                    onTap: () => _openEditProduct(context, product),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(context, product),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: products.length,
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreateProduct(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

