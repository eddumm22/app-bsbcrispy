import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_rating.dart';

class RatingService {
  RatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection('ratings');

  Stream<List<AppRating>> watchRatings() {
    return _ratings.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => AppRating.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<AppRating?> getRatingForUser(String uid) async {
    final doc = await _ratings.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppRating.fromDoc(doc.id, doc.data()!);
  }

  Future<void> saveRating({
    required String uid,
    required String userName,
    required int stars,
  }) async {
    final value = stars.clamp(1, 5);
    final ref = _ratings.doc(uid);
    final snap = await ref.get();

    final name = userName.trim().isEmpty ? 'Usuário' : userName.trim();

    if (snap.exists) {
      await ref.update({
        'uid': uid,
        'userName': name,
        'stars': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'uid': uid,
        'userName': name,
        'stars': value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
