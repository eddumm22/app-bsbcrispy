import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/dashboard_operational_summary.dart';
import '../models/receipt.dart';

class DashboardService {
  DashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DashboardOperationalSummary> loadOperationalDashboardForUnit({
    required String uid,
    required String? unitId,
    required DateTime since,
    required DateTime until,
  }) async {
    try {
      debugPrint(
        'DashboardService: loadOperationalDashboardForUnit(uid=$uid, unitId=$unitId, since=$since, until=$until)',
      );
      late final QuerySnapshot<Map<String, dynamic>> monthReceipts;
      try {
        debugPrint(
          'DashboardService: QUERY receipts (users/$uid/receipts) '
          'filters: date>=since and date<=until; orderBy: date',
        );
        monthReceipts = await _firestore
            .collection('users')
            .doc(uid)
            .collection('receipts')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(until))
            .orderBy('date')
            .get();
      } catch (e, st) {
        debugPrint('DashboardService: monthReceipts query failed: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }

      final hasAnyUnitField = monthReceipts.docs.any((d) => d.data()['unitId'] != null);

      // Se os registros não têm unitId, fazemos fallback seguro e não filtramos.
      final usedUnitFallback = !hasAnyUnitField || unitId == null || unitId.isEmpty;

      final eligibleReceiptIds = <String>{};
      if (!usedUnitFallback) {
        for (final doc in monthReceipts.docs) {
          final data = doc.data();
          final docUnitId = data['unitId'] as String?;
          if (docUnitId == unitId) {
            eligibleReceiptIds.add(doc.id);
          }
        }
      }

      // Itens (agregação) - collectionGroup e filtro por período.
      // Suspeita de índice composto: `uid` (==) + `date` (range) + orderBy('date').
      // Se o Firestore pedir índice, o índice composto normalmente usa os campos:
      // - uid (asc)
      // - date (asc)
      debugPrint(
        'DashboardService: QUERY receipt_items aggregation (collectionGroup="receipt_items") '
        'filters: uid==, date in [since, until], orderBy: date',
      );
      late final QuerySnapshot<Map<String, dynamic>> itemsSnap;
      try {
        debugPrint(
          'DashboardService: QUERY receipt_items aggregation (collectionGroup="receipt_items") '
          'filters: uid==, date in [since, until], orderBy: date',
        );
        itemsSnap = await _firestore
            .collectionGroup('receipt_items')
            .where('uid', isEqualTo: uid)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(until))
            .orderBy('date')
            .get();
      } catch (e, st) {
        debugPrint('DashboardService: receipt_items aggregation query failed: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }

      double totalItemsQty = 0.0;
      double totalItemsValue = 0.0;
      for (final doc in itemsSnap.docs) {
        final data = doc.data();
        final receiptId = data['receiptId'] as String? ?? '';

        if (!usedUnitFallback && !eligibleReceiptIds.contains(receiptId)) {
          continue;
        }

        totalItemsQty += (data['quantity'] as num?)?.toDouble() ?? 0.0;
        totalItemsValue += (data['totalCost'] as num?)?.toDouble() ?? 0.0;
      }

      // Última contagem de estoque (modelo novo).
      DateTime? lastStockCountDate;
      late final QuerySnapshot<Map<String, dynamic>> stockSessionsSnap;
      try {
        debugPrint(
          'DashboardService: QUERY stock_count_sessions latest (orderBy date desc)',
        );
        stockSessionsSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('stock_count_sessions')
            .orderBy('date', descending: true)
            .limit(5)
            .get();
      } catch (e, st) {
        debugPrint('DashboardService: stockSessions query failed: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }

      for (final doc in stockSessionsSnap.docs) {
        final ts = doc.data()['date'] as Timestamp?;
        if (ts == null) continue;
        // Compatibilidade: se houver unitId no documento, tentamos casar; senão, aceitamos o primeiro.
        final docUnitId = doc.data()['unitId'] as String?;
        if (unitId != null && unitId.isNotEmpty && docUnitId != null && docUnitId != unitId) {
          continue;
        }
        lastStockCountDate = ts.toDate();
        break;
      }

      // Última entrega do último fornecedor que entregou.
      // Para unidade, novamente fazemos fallback se não existir unitId.
      late final QuerySnapshot<Map<String, dynamic>> receiptsLatestSnap;
      try {
        debugPrint(
          'DashboardService: QUERY receipts latest (orderBy date desc)',
        );
        receiptsLatestSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('receipts')
            .orderBy('date', descending: true)
            .limit(50)
            .get();
      } catch (e, st) {
        debugPrint('DashboardService: receiptsLatest query failed: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }

      Receipt? latestReceipt;
      for (final doc in receiptsLatestSnap.docs) {
        final data = doc.data();
        final docUnitId = data['unitId'] as String?;
        if (!hasAnyUnitField) {
          latestReceipt = Receipt.fromDoc(doc.id, data);
          break;
        }
        if (unitId != null && unitId.isNotEmpty) {
          if (docUnitId == unitId) {
            latestReceipt = Receipt.fromDoc(doc.id, data);
            break;
          }
          continue;
        }
        // unitId sem filtro
        latestReceipt = Receipt.fromDoc(doc.id, data);
        break;
      }

      DashboardLastDelivery? lastDelivery;
      if (latestReceipt != null) {
        final receiptId = latestReceipt.id;

        // supplier name
        final supplierId = latestReceipt.supplierId;
        String supplierName = 'Fornecedor não definido';
        if (supplierId.isNotEmpty) {
          final supplierDoc = await _firestore
              .collection('users')
              .doc(uid)
              .collection('suppliers')
              .doc(supplierId)
              .get();
          if (supplierDoc.exists) {
            supplierName = (supplierDoc.data()?['legalName'] as String?) ?? supplierName;
          }
        }

        // itens total (quantidade) da entrega
        late final QuerySnapshot<Map<String, dynamic>> receiptItemsSnap;
        try {
          debugPrint(
            'DashboardService: QUERY receipt_items for latest receipt (receiptId=$receiptId, orderBy date)',
          );
          receiptItemsSnap = await _firestore
              .collection('users')
              .doc(uid)
              .collection('receipts')
              .doc(receiptId)
              .collection('receipt_items')
              .orderBy('date')
              .get();
        } catch (e, st) {
          debugPrint('DashboardService: receiptItems query failed: $e');
          debugPrintStack(stackTrace: st);
          rethrow;
        }

        double itemsQty = 0.0;
        for (final doc in receiptItemsSnap.docs) {
          final data = doc.data();
          itemsQty += (data['quantity'] as num?)?.toDouble() ?? 0.0;
        }

        lastDelivery = DashboardLastDelivery(
          supplierId: supplierId,
          supplierName: supplierName,
          receiptDate: latestReceipt.date,
          totalGeneral: latestReceipt.totalGeneral,
          totalItemsQuantity: itemsQty,
        );
      }

      return DashboardOperationalSummary(
        itemsReceivedMonthQuantity: totalItemsQty,
        itemsReceivedMonthValue: totalItemsValue,
        lastStockCountDate: lastStockCountDate,
        lastDelivery: lastDelivery,
        usedUnitFallback: usedUnitFallback,
      );
    } catch (e, st) {
      debugPrint('DashboardService.loadOperationalDashboardForUnit failed: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}

