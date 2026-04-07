import 'dashboard_receipts_point.dart';

class DashboardReceiptsSummary {
  DashboardReceiptsSummary({
    required this.totalValue,
    required this.totalQuantity,
    required this.points,
    required this.usedUnitFallback,
  });

  final double totalValue;
  final double totalQuantity;
  final List<DashboardReceiptsPoint> points;

  // Indica que os dados não estavam vinculados à unidade (campos unitId ausentes),
  // então o cálculo caiu para “todos os recebimentos” para manter compatibilidade.
  final bool usedUnitFallback;
}

