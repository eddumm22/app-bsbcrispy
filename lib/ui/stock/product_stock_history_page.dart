import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/stock_count_service.dart';
import '../../state/auth_controller.dart';

class ProductStockHistoryPage extends StatelessWidget {
  const ProductStockHistoryPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.user?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado.')),
      );
    }

    final since = DateTime.now().subtract(const Duration(days: 30));
    final stockService = context.read<StockCountService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico - $productName'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<StockCountEntry>>(
            stream: stockService.watchProductHistory(
              uid: uid,
              productId: productId,
              since: since,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data ?? [];
              if (entries.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma contagem registrada nos últimos 30 dias.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // Ordena por data crescente para cálculo de variação.
              final sorted = [...entries]
                ..sort((a, b) => a.date.compareTo(b.date));
              final latest = sorted.last;
              final first = sorted.first;

              final latestQty = latest.quantity;
              final firstQty = first.quantity;
              final diff = latestQty - firstQty;
              final diffPercent =
                  firstQty == 0 ? null : (diff / firstQty) * 100;

              Color variationColor;
              if (diff > 0) {
                variationColor = Colors.green;
              } else if (diff < 0) {
                variationColor = Colors.red;
              } else {
                variationColor = Colors.grey;
              }

              String formatQty(double value) =>
                  value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

              final spots = <BarChartGroupData>[];
              final labels = <int, String>{};

              double maxY = 0;
              for (var i = 0; i < sorted.length; i++) {
                final e = sorted[i];
                maxY = e.quantity > maxY ? e.quantity : maxY;
                spots.add(
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.quantity,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                );
                labels[i] =
                    '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}';
              }

              final yMax = maxY == 0 ? 1.0 : maxY * 1.2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quantidade atual',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatQty(latestQty),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Variação 30 dias',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${diff > 0 ? '+' : ''}${formatQty(diff)}'
                                  '${diffPercent != null ? ' (${diffPercent > 0 ? '+' : ''}${diffPercent!.toStringAsFixed(1)}%)' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: variationColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Contagens dos últimos 30 dias',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, left: 4),
                      child: BarChart(
                        BarChartData(
                          maxY: yMax,
                          barGroups: spots,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final entry = sorted[group.x.toInt()];
                                final label = labels[group.x.toInt()] ?? '';
                                return BarTooltipItem(
                                  '$label\nQtd: ${formatQty(entry.quantity)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  if (value < 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    formatQty(value),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final label = labels[value.toInt()];
                                  if (label == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

