import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  Receipt({
    required this.id,
    required this.supplierId,
    required this.invoiceNumber,
    required this.date,
    required this.totalGeneral,
  });

  final String id;
  final String supplierId;
  final String? invoiceNumber;
  final DateTime date;
  final double totalGeneral;

  static Receipt fromDoc(String id, Map<String, dynamic> data) {
    final ts = data['date'] as Timestamp?;
    final total = (data['totalGeneral'] as num?)?.toDouble() ?? 0.0;
    final invoice = data['invoiceNumber'] as String?;

    return Receipt(
      id: id,
      supplierId: data['supplierId'] as String? ?? '',
      invoiceNumber: invoice,
      date: ts?.toDate() ?? DateTime.now(),
      totalGeneral: total,
    );
  }
}

