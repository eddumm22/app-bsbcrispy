import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_count_session.dart';
import '../models/stock_count_session_item.dart';

class StockCountEntry {
  StockCountEntry({
    required this.date,
    required this.quantity,
  });

  final DateTime date;
  final double quantity;
}

class StockCountService {
  StockCountService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Modelo antigo: users/{uid}/products/{productId}/counts/{countId}
  CollectionReference<Map<String, dynamic>> _legacyCountsCollection(
    String uid,
    String productId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('products')
        .doc(productId)
        .collection('counts');
  }

  // Modelo novo (sessão + itens):
  // desejado:
  // - users/{uid}/stock_count_sessions/{sessionId} (date)
  // - users/{uid}/stock_count_sessions/{sessionId}/count_items/{itemId}
  //   (productId, quantity, date)
  //
  // compatibilidade:
  // - users/{uid}/stock_count_items/{itemId} (modelo novo antigo já gravado anteriormente)
  CollectionReference<Map<String, dynamic>> _stockCountSessionsCollection(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('stock_count_sessions');
  }

  CollectionReference<Map<String, dynamic>> _countItemsCollection(
    String uid,
    String sessionId,
  ) {
    return _stockCountSessionsCollection(uid)
        .doc(sessionId)
        .collection('count_items');
  }

  // Modelo novo antigo (já utilizado anteriormente)
  CollectionReference<Map<String, dynamic>> _stockCountItemsCollection(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('stock_count_items');
  }

  Future<void> saveStockCount({
    required String uid,
    required Map<String, double> quantitiesByProductId,
    required DateTime date,
  }) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.fromDate(date);

    // Modelo novo (sessão + itens)
    final sessionRef = _stockCountSessionsCollection(uid).doc();
    batch.set(sessionRef, {
      'date': timestamp,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final sessionId = sessionRef.id;

    // Modelo antigo (legacy) + novo
    quantitiesByProductId.forEach((productId, quantity) {
      // Legado
      final legacyDocRef = _legacyCountsCollection(uid, productId).doc();
      batch.set(legacyDocRef, {
        'quantity': quantity,
        'date': timestamp,
      });

      // Novo desejado (count_items dentro da session)
      final nestedItemDocRef = _countItemsCollection(uid, sessionId).doc();
      batch.set(nestedItemDocRef, {
        'uid': uid,
        'productId': productId,
        'quantity': quantity,
        'date': timestamp,
      });

      // Novo antigo (compatibilidade com versões anteriores)
      final itemDocRef = _stockCountItemsCollection(uid).doc();
      batch.set(itemDocRef, {
        'sessionId': sessionId,
        'productId': productId,
        'uid': uid,
        'quantity': quantity,
        'date': timestamp,
      });
    });

    await batch.commit();
  }

  // ===== Histórico operacional: sessões (modelo novo) =====

  // Prioriza `users/{uid}/stock_count_sessions` e cai no fallback
  // `users/{uid}/stock_count_items` (modelo novo antigo) quando não houver sessões.
  Stream<List<StockCountSession>> watchStockCountSessions({
    required String uid,
    int limit = 50,
  }) {
    final sessionsStream = _stockCountSessionsCollection(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final ts = doc.data()['date'] as Timestamp?;
        return StockCountSession(
          id: doc.id,
          date: ts?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });

    // Fallback: agrupa `stock_count_items` por sessionId.
    final fallbackSessionsStream = _stockCountItemsCollection(uid)
        .orderBy('date', descending: true)
        .limit(limit * 20)
        .snapshots()
        .map((snapshot) {
      final bySession = <String, DateTime>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sessionId = data['sessionId'] as String?;
        if (sessionId == null || sessionId.isEmpty) continue;

        final ts = data['date'] as Timestamp?;
        final itemDate = ts?.toDate() ?? DateTime.now();

        final current = bySession[sessionId];
        if (current == null || itemDate.isAfter(current)) {
          bySession[sessionId] = itemDate;
        }
      }

      final sessions = bySession.entries
          .map(
            (e) => StockCountSession(
              id: e.key,
              date: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      return sessions.take(limit).toList();
    });

    final controller = StreamController<List<StockCountSession>>();
    List<StockCountSession>? latestSessions;
    List<StockCountSession>? latestFallback;
    var sessionsReady = false;
    var fallbackReady = false;

    void emit() {
      if (!sessionsReady || !fallbackReady) return;

      final sessions = latestSessions ?? [];
      if (sessions.isNotEmpty) {
        controller.add(sessions);
        return;
      }
      controller.add(latestFallback ?? []);
    }

    final sessionsSub = sessionsStream.listen(
      (data) {
        latestSessions = data;
        sessionsReady = true;
        emit();
      },
      onError: (error) {
        latestSessions = <StockCountSession>[];
        sessionsReady = true;
        emit();
      },
    );

    final fallbackSub = fallbackSessionsStream.listen(
      (data) {
        latestFallback = data;
        fallbackReady = true;
        emit();
      },
      onError: (error) {
        latestFallback = <StockCountSession>[];
        fallbackReady = true;
        emit();
      },
    );

    controller.onCancel = () async {
      await sessionsSub.cancel();
      await fallbackSub.cancel();
    };

    return controller.stream;
  }

  // Prioriza `stock_count_sessions/{sessionId}/count_items` e cai no fallback
  // `stock_count_items` (modelo novo antigo) quando não houver dados aninhados.
  Stream<List<StockCountSessionItem>> watchStockCountItemsInSession({
    required String uid,
    required String sessionId,
  }) {
    final nestedStream = _countItemsCollection(uid, sessionId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StockCountSessionItem(
          productId: data['productId'] as String? ?? '',
          quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    });

    final fallbackStream = _stockCountItemsCollection(uid)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StockCountSessionItem(
          productId: data['productId'] as String? ?? '',
          quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    });

    final controller = StreamController<List<StockCountSessionItem>>();

    List<StockCountSessionItem>? latestNested;
    List<StockCountSessionItem>? latestFallback;
    var nestedReady = false;
    var fallbackReady = false;

    void emitIfReady() {
      if (!nestedReady || !fallbackReady) return;

      final nested = latestNested ?? [];
      if (nested.isNotEmpty) {
        controller.add(nested);
        return;
      }
      controller.add(latestFallback ?? []);
    }

    final nestedSub = nestedStream.listen(
      (entries) {
        latestNested = entries;
        nestedReady = true;
        emitIfReady();
      },
      onError: (error) {
        latestNested = <StockCountSessionItem>[];
        nestedReady = true;
        emitIfReady();
      },
    );

    final fallbackSub = fallbackStream.listen(
      (entries) {
        latestFallback = entries;
        fallbackReady = true;
        emitIfReady();
      },
      onError: (error) {
        latestFallback = <StockCountSessionItem>[];
        fallbackReady = true;
        emitIfReady();
      },
    );

    controller.onCancel = () async {
      await nestedSub.cancel();
      await fallbackSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<StockCountEntry>> watchProductHistory({
    required String uid,
    required String productId,
    required DateTime since,
  }) {
    // Prioriza o modelo novo. Se ele não tiver dados, faz fallback para o legado.
    final controller = StreamController<List<StockCountEntry>>();

    final nestedNewStream = watchProductHistoryNewNested(
      uid: uid,
      productId: productId,
      since: since,
    );
    final newLegacyStream = watchProductHistoryNewLegacy(
      uid: uid,
      productId: productId,
      since: since,
    );
    final legacyStream = watchProductHistoryLegacy(
      uid: uid,
      productId: productId,
      since: since,
    );

    List<StockCountEntry>? latestNestedNew;
    List<StockCountEntry>? latestNewLegacy;
    List<StockCountEntry>? latestLegacy;
    var nestedNewReady = false;
    var newLegacyReady = false;
    var legacyReady = false;

    late StreamSubscription<List<StockCountEntry>> nestedNewSub;
    late StreamSubscription<List<StockCountEntry>> newLegacySub;
    late StreamSubscription<List<StockCountEntry>> legacySub;

    void emitIfReady() {
      if (!nestedNewReady || !newLegacyReady || !legacyReady) return;
      final nestedNewEntries = latestNestedNew ?? [];
      if (nestedNewEntries.isNotEmpty) {
        controller.add(nestedNewEntries);
        return;
      }
      final newLegacyEntries = latestNewLegacy ?? [];
      if (newLegacyEntries.isNotEmpty) {
        controller.add(newLegacyEntries);
        return;
      }
      controller.add(latestLegacy ?? []);
    }

    nestedNewSub = nestedNewStream.listen(
      (entries) {
        latestNestedNew = entries;
        nestedNewReady = true;
        emitIfReady();
      },
      onError: (error) {
        // Se o query do novo modelo falhar (ex: índice), não quebrar o histórico.
        latestNestedNew = <StockCountEntry>[];
        nestedNewReady = true;
        emitIfReady();
      },
    );

    newLegacySub = newLegacyStream.listen(
      (entries) {
        latestNewLegacy = entries;
        newLegacyReady = true;
        emitIfReady();
      },
      onError: (error) {
        latestNewLegacy = <StockCountEntry>[];
        newLegacyReady = true;
        emitIfReady();
      },
    );

    legacySub = legacyStream.listen(
      (entries) {
        latestLegacy = entries;
        legacyReady = true;
        emitIfReady();
      },
      onError: (error) {
        latestLegacy = <StockCountEntry>[];
        legacyReady = true;
        emitIfReady();
      },
    );

    controller.onCancel = () async {
      await nestedNewSub.cancel();
      await newLegacySub.cancel();
      await legacySub.cancel();
    };

    return controller.stream;
  }

  // Modelo novo desejado: collectionGroup('count_items')
  // (fica fácil consultar todos os itens de todas as sessions de um usuário)
  Stream<List<StockCountEntry>> watchProductHistoryNewNested({
    required String uid,
    required String productId,
    required DateTime since,
  }) {
    return _firestore
        .collectionGroup('count_items')
        .where('uid', isEqualTo: uid)
        .where('productId', isEqualTo: productId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        return StockCountEntry(
          date: ts?.toDate() ?? DateTime.now(),
          quantity: qty,
        );
      }).toList();
    });
  }

  // Modelo novo antigo já persistido em versões anteriores:
  // users/{uid}/stock_count_items/{itemId}
  Stream<List<StockCountEntry>> watchProductHistoryNewLegacy({
    required String uid,
    required String productId,
    required DateTime since,
  }) {
    return _stockCountItemsCollection(uid)
        .where('productId', isEqualTo: productId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        return StockCountEntry(
          date: ts?.toDate() ?? DateTime.now(),
          quantity: qty,
        );
      }).toList();
    });
  }

  Stream<List<StockCountEntry>> watchProductHistoryLegacy({
    required String uid,
    required String productId,
    required DateTime since,
  }) {
    return _legacyCountsCollection(uid, productId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
        return StockCountEntry(
          date: ts?.toDate() ?? DateTime.now(),
          quantity: qty,
        );
      }).toList();
    });
  }
}

