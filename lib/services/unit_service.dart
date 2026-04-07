import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/unit.dart';

class UnitService {
  UnitService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _unitsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('units');
  }

  Stream<List<Unit>> watchUnits(String uid) {
    return _unitsCollection(uid)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Unit.fromDoc(doc.id, doc.data()))
          .toList();
    });
  }

  Future<bool> hasAnyUnit(String uid) async {
    final snapshot = await _unitsCollection(uid).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> addUnit({required String uid, required String name, required String cnpj}) {
    return _unitsCollection(uid).add(
      Unit(id: '', name: name, cnpj: cnpj).toMap(),
    ).then((ref) => ref.id);
  }

  Future<void> updateUnit({
    required String uid,
    required String unitId,
    required String name,
    required String cnpj,
  }) {
    return _unitsCollection(uid).doc(unitId).update({
      'name': name,
      'cnpj': cnpj,
    });
  }

  Future<void> deleteUnit({
    required String uid,
    required String unitId,
  }) {
    return _unitsCollection(uid).doc(unitId).delete();
  }
}

