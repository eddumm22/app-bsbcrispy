class ReceiptItem {
  ReceiptItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalCost,
  });

  final String productId;
  final double quantity;
  final double unitPrice;
  final double totalCost;

  static ReceiptItem fromDoc(String docId, Map<String, dynamic> data) {
    return ReceiptItem(
      productId: data['productId'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap({
    required String uid,
  }) {
    return {
      'uid': uid,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalCost': totalCost,
    };
  }
}

