import 'package:cloud_firestore/cloud_firestore.dart';

class AppRating {
  AppRating({
    required this.uid,
    required this.userName,
    required this.stars,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String userName;
  final int stars;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static AppRating fromDoc(String docId, Map<String, dynamic> data) {
    final raw = (data['stars'] as num?)?.toInt() ?? 0;
    final stars = raw.clamp(1, 5);
    return AppRating(
      uid: data['uid'] as String? ?? docId,
      userName: (data['userName'] as String?)?.trim().isNotEmpty == true
          ? (data['userName'] as String).trim()
          : 'Usuário',
      stars: stars,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Média arredondada a [fractionDigits] casas; retorna null se não houver avaliações válidas.
  static double? averageFor(List<AppRating> ratings, {int fractionDigits = 1}) {
    if (ratings.isEmpty) return null;
    final sum = ratings.fold<int>(0, (a, r) => a + r.stars);
    final avg = sum / ratings.length;
    return double.parse(avg.toStringAsFixed(fractionDigits));
  }
}
