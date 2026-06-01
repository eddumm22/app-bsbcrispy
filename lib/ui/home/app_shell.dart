import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/product_service.dart';
import '../../services/supplier_service.dart';
import '../../services/unit_service.dart';
import '../../services/user_profile_service.dart';
import '../../state/auth_controller.dart';
import '../receipts/receipts_page.dart';
import '../products/products_list_page.dart';
import '../suppliers/suppliers_page.dart';
import '../units/units_page.dart';
import '../stock/stock_count_page.dart';
import '../profile/profile_page.dart';
import '../dashboard/dashboard_page.dart';
import '../rating/rating_page.dart';

enum AppPage {
  home,
  profile,
  rating,
  units,
  suppliers,
  products,
  receipts,
  stockCount,
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _currentPage = AppPage.home;
  bool? _hasUnit;
  bool? _hasSupplier;
  bool? _hasProduct;

  Future<bool> _safeHasAnyUnit(String uid) async {
    try {
      return await context.read<UnitService>().hasAnyUnit(uid);
    } on FirebaseException catch (e) {
      debugPrint('AppShell: hasAnyUnit failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppShell: hasAnyUnit failed: $e');
      return false;
    }
  }

  Future<bool> _safeHasAnySupplier(String uid) async {
    try {
      return await context.read<SupplierService>().hasAnySupplier(uid);
    } on FirebaseException catch (e) {
      debugPrint('AppShell: hasAnySupplier failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppShell: hasAnySupplier failed: $e');
      return false;
    }
  }

  Future<bool> _safeHasAnyProducts(String uid) async {
    try {
      return await context.read<ProductService>().hasAnyProducts(uid);
    } on FirebaseException catch (e) {
      debugPrint('AppShell: hasAnyProducts failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('AppShell: hasAnyProducts failed: $e');
      return false;
    }
  }

  Future<void> _loadPrereqsIfNeeded(String uid) async {
    final results = await Future.wait([
      _safeHasAnyUnit(uid),
      _safeHasAnySupplier(uid),
      _safeHasAnyProducts(uid),
    ]);

    if (!mounted) return;
    setState(() {
      _hasUnit = results[0];
      _hasSupplier = results[1];
      _hasProduct = results[2];
    });
  }

  Future<void> _attemptSelectPage(AppPage page) async {
    final uid = context.read<AuthController>().user?.uid;
    if (uid == null) return;

    // Páginas sem bloqueio por pré-requisito (Unidade deve abrir sempre).
    if (page == AppPage.home ||
        page == AppPage.profile ||
        page == AppPage.rating ||
        page == AppPage.units) {
      setState(() {
        _currentPage = page;
      });
      Navigator.of(context).maybePop();
      return;
    }

    await _loadPrereqsIfNeeded(uid);

    final hasUnit = _hasUnit ?? false;
    final hasSupplier = _hasSupplier ?? false;
    final hasProduct = _hasProduct ?? false;

    final blockedMessage = switch (page) {
      AppPage.units => null,
      AppPage.suppliers => hasUnit ? null : 'Cadastre uma Unidade antes de cadastrar Fornecedores.',
      AppPage.products => (!hasUnit) ? 'Cadastre uma Unidade antes de acessar Produtos.' : (!hasSupplier)
          ? 'Cadastre um Fornecedor antes de acessar Produtos.'
          : null,
      AppPage.receipts => (!hasUnit)
          ? 'Cadastre uma Unidade antes de acessar Recebimentos.'
          : (!hasSupplier)
              ? 'Cadastre um Fornecedor antes de acessar Recebimentos.'
              : (!hasProduct)
                  ? 'Cadastre pelo menos um Produto antes de acessar Recebimentos.'
                  : null,
      AppPage.stockCount => (!hasUnit)
          ? 'Cadastre uma Unidade antes de acessar Contagem de Estoque.'
          : (!hasSupplier)
              ? 'Cadastre um Fornecedor antes de acessar Contagem de Estoque.'
              : (!hasProduct)
                  ? 'Cadastre pelo menos um Produto antes de acessar Contagem de Estoque.'
                  : null,
      _ => null,
    };

    if (blockedMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockedMessage)),
      );
      return;
    }

    setState(() {
      _currentPage = page;
    });
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final userProfileService = context.read<UserProfileService>();

    Widget body;
    switch (_currentPage) {
      case AppPage.home:
        body = DashboardPage(
          onOpenUnits: () => _attemptSelectPage(AppPage.units),
        );
        break;
      case AppPage.profile:
        body = const ProfilePage();
        break;
      case AppPage.rating:
        body = const RatingPage();
        break;
      case AppPage.units:
        body = const UnitsPage();
        break;
      case AppPage.suppliers:
        body = const SuppliersPage();
        break;
      case AppPage.products:
        body = const ProductsListPage();
        break;
      case AppPage.receipts:
        body = const ReceiptsPage();
        break;
      case AppPage.stockCount:
        body = const StockCountPage();
        break;
    }

    final primaryBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BSB Crispy'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null)
                FutureBuilder<Map<String, dynamic>?>(
                  future: userProfileService.getUserProfile(user.uid),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final name = data?['firstName'] as String? ?? 'Usuário';
                    final email = user.email ?? '';
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: primaryBlue.withOpacity(0.15),
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: primaryBlue.withOpacity(0.15),
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'BSB Crispy',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: Icon(Icons.home, color: primaryBlue),
                title: const Text('Início'),
                selected: _currentPage == AppPage.home,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.home),
              ),
              ListTile(
                leading: Icon(Icons.person, color: primaryBlue),
                title: const Text('Perfil'),
                selected: _currentPage == AppPage.profile,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.profile),
              ),
              ListTile(
                leading: Icon(Icons.star_rate_rounded, color: primaryBlue),
                title: const Text('Avaliação'),
                selected: _currentPage == AppPage.rating,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.rating),
              ),
              ListTile(
                leading: Icon(Icons.store, color: primaryBlue),
                title: const Text('Unidade'),
                selected: _currentPage == AppPage.units,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.units),
              ),
              ListTile(
                leading: Icon(Icons.people, color: primaryBlue),
                title: const Text('Fornecedores'),
                selected: _currentPage == AppPage.suppliers,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.suppliers),
              ),
              ListTile(
                leading: Icon(Icons.inventory_2, color: primaryBlue),
                title: const Text('Produtos'),
                selected: _currentPage == AppPage.products,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.products),
              ),
              ListTile(
                leading: Icon(Icons.receipt_long, color: primaryBlue),
                title: const Text('Recebimentos'),
                selected: _currentPage == AppPage.receipts,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.receipts),
              ),
              ListTile(
                leading: Icon(Icons.inventory, color: primaryBlue),
                title: const Text('Contagem de Estoque'),
                selected: _currentPage == AppPage.stockCount,
                selectedColor: primaryBlue,
                onTap: () async => _attemptSelectPage(AppPage.stockCount),
              ),
              const Spacer(),
              ListTile(
                leading: Icon(Icons.logout, color: primaryBlue),
                title: const Text('Sair'),
                onTap: auth.isLoading
                    ? null
                    : () async {
                        Navigator.of(context).maybePop();
                        await context.read<AuthController>().signOut();
                      },
              ),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final userProfileService = context.read<UserProfileService>();

    if (user == null) {
      return const Center(
        child: Text('Bem-vindo ao BSB Crispy'),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: userProfileService.getUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        final name = data?['firstName'] as String? ?? 'Usuário';
        return Center(
          child: Text(
            'Bem-vindo, $name',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
      },
    );
  }
}

