import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/receipt.dart';
import '../models/receipt_item.dart';

class ReceiptService {
  ReceiptService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _receiptsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('receipts');
  }

  CollectionReference<Map<String, dynamic>> _receiptItemsCollection(
    String uid,
    String receiptId,
  ) {
    return _receiptsCollection(uid).doc(receiptId).collection('receipt_items');
  }

  Stream<List<Receipt>> watchReceipts(String uid) {
    return _receiptsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Receipt.fromDoc(doc.id, doc.data()))
          .toList();
    });
  }

  Future<Receipt?> getReceipt({
    required String uid,
    required String receiptId,
  }) async {
    final doc = await _receiptsCollection(uid).doc(receiptId).get();
    if (!doc.exists) return null;
    return Receipt.fromDoc(doc.id, doc.data() ?? {});
  }

  Stream<List<ReceiptItem>> watchReceiptItems({
    required String uid,
    required String receiptId,
  }) {
    return _receiptItemsCollection(uid, receiptId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReceiptItem.fromDoc(doc.id, doc.data()))
          .toList();
    });
  }

  Future<String> saveReceipt({
    required String uid,
    required String supplierId,
    String? invoiceNumber,
    required DateTime date,
    required double totalGeneral,
    required List<ReceiptItem> items,
  }) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.fromDate(date);

    final receiptRef = _receiptsCollection(uid).doc();
    final receiptId = receiptRef.id;

    batch.set(receiptRef, {
      'supplierId': supplierId,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty) 'invoiceNumber': invoiceNumber,
      'date': timestamp,
      'totalGeneral': totalGeneral,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final item in items) {
      final itemRef = _receiptItemsCollection(uid, receiptId).doc();
      batch.set(itemRef, {
        ...item.toMap(uid: uid),
        'receiptId': receiptId,
        'date': timestamp,
      });
    }

    await batch.commit();
    return receiptId;
  }

  Future<bool> invoiceNumberExistsForSupplier({
    required String uid,
    required String supplierId,
    required String invoiceNumber,
  }) async {
    if (invoiceNumber.isEmpty) return false;

    final snapshot = await _receiptsCollection(uid)
        .where('supplierId', isEqualTo: supplierId)
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}

