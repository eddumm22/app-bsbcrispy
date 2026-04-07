import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier.dart';

class SupplierService {
  SupplierService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _suppliersCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('suppliers');
  }

  Stream<List<Supplier>> watchSuppliers(String uid) {
    return _suppliersCollection(uid)
        .orderBy('legalName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Supplier.fromDoc(doc.id, doc.data()))
          .toList();
    });
  }

  Future<bool> hasAnySupplier(String uid) async {
    final snapshot = await _suppliersCollection(uid).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> addSupplier({
    required String uid,
    required String legalName,
    required String cnpj,
  }) {
    return _suppliersCollection(uid).add(
      Supplier(id: '', legalName: legalName, cnpj: cnpj).toMap(),
    ).then((ref) => ref.id);
  }

  Future<void> updateSupplier({
    required String uid,
    required String supplierId,
    required String legalName,
    required String cnpj,
  }) {
    return _suppliersCollection(uid).doc(supplierId).update({
      'legalName': legalName,
      'cnpj': cnpj,
    });
  }

  Future<void> deleteSupplier({
    required String uid,
    required String supplierId,
  }) {
    return _suppliersCollection(uid).doc(supplierId).delete();
  }
}

