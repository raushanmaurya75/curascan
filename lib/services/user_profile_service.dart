import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _getDefaultProfile();
      }

      // Try to get from medical profile first
      final profileDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicalProfile')
          .doc('current')
          .get();
      
      if (profileDoc.exists) {
        final data = profileDoc.data() as Map<String, dynamic>;
        return {
          'age': data['age'] ?? 25,
          'conditions': List<String>.from(data['diseases'] ?? []),
          'allergies': List<String>.from(data['allergies'] ?? []),
          'dietaryRestrictions': [data['dietType'] ?? 'No restrictions'],
          'healthGoals': List<String>.from(data['healthGoals'] ?? []),
        };
      }
      
      // Fallback to main user document
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'age': data['age'] ?? 25,
          'conditions': List<String>.from(data['medicalConditions'] ?? []),
          'allergies': List<String>.from(data['allergies'] ?? []),
          'dietaryRestrictions': List<String>.from(data['dietaryRestrictions'] ?? []),
          'healthGoals': List<String>.from(data['healthGoals'] ?? []),
        };
      }
      
      return _getDefaultProfile();
    } catch (e) {
      print('Error getting user profile: $e');
      return _getDefaultProfile();
    }
  }

  static Map<String, dynamic> _getDefaultProfile() {
    return {
      'age': 25,
      'conditions': <String>[],
      'allergies': <String>[],
      'dietaryRestrictions': <String>[],
      'healthGoals': ['General Health'],
    };
  }
}