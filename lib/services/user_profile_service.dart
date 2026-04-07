import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
    required String email,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
  }) {
    return _firestore.collection('users').doc(uid).update({
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

