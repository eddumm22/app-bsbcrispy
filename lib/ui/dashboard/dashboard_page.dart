import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dashboard_operational_summary.dart';
import '../../models/unit.dart';
import '../../services/dashboard_service.dart';
import '../../services/unit_service.dart';
import '../../state/auth_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenUnits});

  /// Abre a tela de Unidade no shell (drawer permanece disponível).
  final VoidCallback? onOpenUnits;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _selectedUnitId;

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(2);
    return 'R\$ ${s.replaceAll('.', ',')}';
  }

  String _monthNamePtBr(int month) {
    const monthNames = <String>[
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    if (month < 1 || month > 12) return '';
    return monthNames[month - 1];
  }

  String _friendlyDashboardError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('permission-denied')) {
      return 'Não foi possível carregar os indicadores. Verifique se você está logado e se possui uma unidade cadastrada.';
    }

    final likelyIndexError = lower.contains('requires an index') ||
        lower.contains('composite index') ||
        lower.contains('create_composite') ||
        lower.contains('index');

    if (likelyIndexError) {
      return 'Esse relatório exige um índice composto no Firestore.\n'
          'Quando o Firestore informar o link do índice, crie pelo link.';
    }

    return 'Não foi possível carregar os indicadores. Tente novamente em instantes.';
  }

  Widget _emptyUnitCard(ThemeData theme) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cadastre uma Unidade para visualizar os indicadores da dashboard.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onOpenUnits,
                icon: const Icon(Icons.store),
                label: const Text('Cadastre uma Unidade'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;
    final theme = Theme.of(context);

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado.')));
    }

    final unitService = context.read<UnitService>();
    final dashboardService = context.read<DashboardService>();

    final now = DateTime.now();
    final since = DateTime(now.year, now.month, 1);
    final until = now;
    final monthNamePtBr = _monthNamePtBr(now.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard operacional')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Por unidade',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<Unit>>(
                  stream: unitService.watchUnits(uid),
                  builder: (context, unitsSnapshot) {
                    if (unitsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (unitsSnapshot.hasError) {
                      return Center(
                        child: Text(_friendlyDashboardError(unitsSnapshot.error!)),
                      );
                    }

                    final units = unitsSnapshot.data ?? [];
                    if (units.isEmpty) {
                      return _emptyUnitCard(theme);
                    }

                    if (_selectedUnitId == null ||
                        !units.any((u) => u.id == _selectedUnitId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _selectedUnitId = units.first.id;
                        });
                      });
                      return const Center(child: CircularProgressIndicator());
                    }

                    final selectedUnitId = _selectedUnitId!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Unidade',
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: units
                              .map(
                                (u) => DropdownMenuItem<String>(
                                  value: u.id,
                                  child: Text(u.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedUnitId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: FutureBuilder<DashboardOperationalSummary>(
                            key: ValueKey<String>(
                              '$selectedUnitId-${since.toIso8601String()}-${until.toIso8601String()}',
                            ),
                            future: dashboardService.loadOperationalDashboardForUnit(
                              uid: uid,
                              unitId: selectedUnitId,
                              since: since,
                              until: until,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                final friendly = _friendlyDashboardError(snapshot.error!);
                                final showTechnical =
                                    !snapshot.error.toString().toLowerCase().contains(
                                          'permission-denied',
                                        );

                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Card(
                                    color: Colors.red.withOpacity(0.06),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              friendly,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (showTechnical) ...[
                                              const SizedBox(height: 8),
                                              SelectableText(
                                                snapshot.error.toString(),
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: Text('Nenhum dado suficiente para montar a dashboard.'),
                                );
                              }

                              final data = snapshot.data!;

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Itens recebidos',
                                                    style: TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    data.itemsReceivedMonthQuantity
                                                        .toStringAsFixed(
                                                      data.itemsReceivedMonthQuantity
                                                                  .truncateToDouble() ==
                                                              data.itemsReceivedMonthQuantity
                                                          ? 0
                                                          : 2,
                                                    ).replaceAll('.', ','),
                                                    style: theme.textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (data.itemsReceivedMonthQuantity == 0)
                                                    Text(
                                                      'Sem recebimentos no mês atual.',
                                                      style: theme.textTheme.bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Valor recebido',
                                                    style: TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatCurrency(data.itemsReceivedMonthValue),
                                                    style: theme.textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (data.itemsReceivedMonthValue == 0)
                                                    Text(
                                                      'Sem valor recebido no mês atual.',
                                                      style: theme.textTheme.bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (data.usedUnitFallback) ...[
                                      const SizedBox(height: 12),
                                      Card(
                                        color: Colors.orange.withOpacity(0.10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'Observação: seus registros atuais podem não estar vinculados à unidade. O filtro por unidade pode estar em modo “fallback”.',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Última contagem',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            if (data.lastStockCountDate == null)
                                              const Text('Sem contagem registrada ainda.')
                                            else
                                              Text(
                                                '${data.lastStockCountDate!.day.toString().padLeft(2, '0')}/${data.lastStockCountDate!.month.toString().padLeft(2, '0')}/${data.lastStockCountDate!.year}',
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Última entrega',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            if (data.lastDelivery == null)
                                              const Text('Sem recebimentos registrados ainda.')
                                            else
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data.lastDelivery!.supplierName,
                                                    style: theme.textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Data: ${data.lastDelivery!.receiptDate.day.toString().padLeft(2, '0')}/${data.lastDelivery!.receiptDate.month.toString().padLeft(2, '0')}/${data.lastDelivery!.receiptDate.year}',
                                                    style: theme.textTheme.bodyMedium,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    'Valor: ${_formatCurrency(data.lastDelivery!.totalGeneral)}',
                                                    style: theme.textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Qtd itens: ${data.lastDelivery!.totalItemsQuantity.toStringAsFixed(data.lastDelivery!.totalItemsQuantity.truncateToDouble() == data.lastDelivery!.totalItemsQuantity ? 0 : 2).replaceAll('.', ',')}',
                                                    style: theme.textTheme.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        'Informações do mês de $monthNamePtBr',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
