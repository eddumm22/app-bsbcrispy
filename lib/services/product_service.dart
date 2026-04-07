import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _productsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('products');
  }

  Stream<List<Product>> watchProducts(String uid) {
    return _productsCollection(uid)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    });
  }

  // Somente produtos com fornecedor obrigatório (supplierId).
  Stream<List<Product>> watchProductsBySupplier({
    required String uid,
    required String supplierId,
  }) {
    // Evita necessidade de índice composto (where + orderBy) no Firestore.
    return _productsCollection(uid)
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    });
  }

  Future<List<Product>> getProducts(String uid) async {
    final snapshot =
        await _productsCollection(uid).orderBy('name').get();
    return snapshot.docs
        .map((doc) => Product.fromDoc(doc.id, doc.data()))
        .toList();
  }

  Future<bool> hasAnyProducts(String uid) async {
    final snapshot = await _productsCollection(uid).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> addProduct(String uid, Product product) {
    return _productsCollection(uid).add(product.toMap());
  }

  Future<void> updateProduct(String uid, Product product) {
    return _productsCollection(uid)
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String uid, String productId) {
    return _productsCollection(uid).doc(productId).delete();
  }
}

