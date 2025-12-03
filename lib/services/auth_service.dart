import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Custom exception class for auth errors (since FirebaseAuthException can't be instantiated)
class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException: [$code] $message';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword(String email, String password, String fullName) async {
    User? user;
    try {
      // Step 1: Create Firebase Auth user
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = result.user;
      
      // Reload user to ensure fresh data
      await user?.reload();
      user = _auth.currentUser;

      if (user != null) {
        print('✅ Firebase Auth user created: ${user.uid}');

        // Step 2: Update display name
        try {
          await user.updateDisplayName(fullName);
          print('✅ Display name updated');
        } catch (e) {
          print('⚠️ Display name update failed: $e');
          // Continue anyway, this is not critical
        }

        // Step 3: Save to Firestore (non-blocking)
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'name': fullName,
            'email': email,
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ User data saved to Firestore');
        } catch (firestoreError) {
          print('⚠️ Firestore save failed: $firestoreError');
          // Don't throw error here - user is already created in Auth
          // We can retry Firestore save later or handle it gracefully
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      // If user was created but Firestore failed, we still have a valid user
      if (user != null) {
        print('✅ Returning user despite Firestore issues');
        return user;
      }
      // Rethrow the original exception - don't try to create a new one
      rethrow;
    } catch (e) {
      print('❌ General signup error: $e');
      // If user was created but other operations failed, still return user
      if (user != null) {
        print('✅ Returning user despite other issues');
        return user;
      }
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      // Rethrow the original exception - don't try to create a new one
      rethrow;
    } catch (e) {
      print('General error: $e');
      throw Exception('Login failed: Please try again');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Retry Firestore user data save (can be called later if initial save fails)
  Future<bool> retryUserDataSave(String uid, String fullName, String email) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': fullName,
        'email': email,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileComplete': false,
      }, SetOptions(merge: true));
      print('✅ Retry: User data saved to Firestore');
      return true;
    } catch (e) {
      print('❌ Retry failed: $e');
      return false;
    }
  }
  
  // Check if user document exists in Firestore
  Future<bool> userDocumentExists(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user document: $e');
      return false;
    }
  }

  // Save user data to Firestore
  Future<void> saveUserData(String uid, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }
}