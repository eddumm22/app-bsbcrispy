class DashboardLastDelivery {
  DashboardLastDelivery({
    required this.supplierId,
    required this.supplierName,
    required this.receiptDate,
    required this.totalGeneral,
    required this.totalItemsQuantity,
  });

  final String supplierId;
  final String supplierName;
  final DateTime receiptDate;
  final double totalGeneral;
  final double totalItemsQuantity;
}

class DashboardOperationalSummary {
  DashboardOperationalSummary({
    required this.itemsReceivedMonthQuantity,
    required this.itemsReceivedMonthValue,
    required this.lastStockCountDate,
    required this.lastDelivery,
    required this.usedUnitFallback,
  });

  final double itemsReceivedMonthQuantity;
  final double itemsReceivedMonthValue;
  final DateTime? lastStockCountDate;
  final DashboardLastDelivery? lastDelivery;

  // Recebimentos: indica que os dados não têm unitId em muitos registros,
  // então o filtro por unidade caiu em fallback seguro.
  final bool usedUnitFallback;
}

