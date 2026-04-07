import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dashboard_operational_summary.dart';
import '../../models/unit.dart';
import '../../services/dashboard_service.dart';
import '../../services/unit_service.dart';
import '../../state/auth_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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
              StreamBuilder<List<Unit>>(
                stream: unitService.watchUnits(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final units = snapshot.data ?? [];
                  if (units.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Cadastre uma Unidade para visualizar os indicadores.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  // Inicializa seleção.
                  if (_selectedUnitId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        _selectedUnitId = units.first.id;
                      });
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedUnitId,
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
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<DashboardOperationalSummary>(
                  future: dashboardService.loadOperationalDashboardForUnit(
                    uid: uid,
                    unitId: _selectedUnitId,
                    since: since,
                    until: until,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final rawError = snapshot.error.toString();
                      final lower = rawError.toLowerCase();
                      final likelyIndexError =
                          lower.contains('requires an index') ||
                          lower.contains('composite index') ||
                          lower.contains('create_composite') ||
                          lower.contains('index');

                      final friendly = likelyIndexError
                          ? 'Esse relatório exige um índice composto no Firestore.'
                              '\nCampos que provavelmente entram no índice: `uid` + `date` no `receipt_items`.'
                              '\nQuando o Firestore informa o link do índice, crie pelo link.'
                          : 'Erro ao carregar a dashboard.';

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          color: Colors.red.withOpacity(0.06),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    friendly,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    rawError,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Dica: o Firestore geralmente inclui um link para criar o índice necessário.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text('Nenhum dado suficiente para montar a dashboard.'));
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
                                          data.itemsReceivedMonthQuantity.toStringAsFixed(
                                            data.itemsReceivedMonthQuantity.truncateToDouble() == data.itemsReceivedMonthQuantity ? 0 : 2,
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
          ),
        ),
      ),
    );
  }
}

