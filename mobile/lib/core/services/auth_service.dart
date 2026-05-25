import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Central authentication and session management service.
/// Automatically falls back to SharedPreferences if Firebase is uninitialized.
abstract class AuthService {
  static late final AuthService instance;
  static bool useFirebase = false;

  static Future<void> initialize() async {
    try {
      // Try to initialize Firebase
      await Firebase.initializeApp();
      instance = FirebaseAuthService();
      useFirebase = true;
      print("Firebase Auth successfully initialized.");
    } catch (e) {
      print("Firebase initialization skipped/failed: $e. Falling back to SharedPreferences local auth.");
      final localAuth = LocalAuthService();
      await localAuth.loadSession();
      instance = localAuth;
      useFirebase = false;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signUpWithEmailAndPassword(String email, String password, String name, String phone);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();

  bool get isLoggedIn;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserFullName;
  String? get currentUserPhone;
}

class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedName;
  String? _cachedPhone;

  FirebaseAuthService() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _fetchUserProfile(user.uid);
      } else {
        _cachedName = null;
        _cachedPhone = null;
      }
    });
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        _cachedName = data?['fullName'] as String?;
        _cachedPhone = data?['phone'] as String?;
      }
    } catch (_) {}
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (_auth.currentUser != null) {
      await _fetchUserProfile(_auth.currentUser!.uid);
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword(String email, String password, String name, String phone) async {
    final creds = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (creds.user != null) {
      final uid = creds.user!.uid;
      // Store user profile in Firestore
      await _firestore.collection('users').doc(uid).set({
        'userId': uid,
        'fullName': name,
        'email': email,
        'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _cachedName = name;
      _cachedPhone = phone;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  bool get isLoggedIn => _auth.currentUser != null;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  String? get currentUserFullName => _cachedName ?? _auth.currentUser?.displayName ?? 'User';

  @override
  String? get currentUserPhone => _cachedPhone ?? '';
}

class LocalAuthService implements AuthService {
  Map<String, dynamic>? _currentUser;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString('local_session_user');
    if (session != null) {
      _currentUser = json.decode(session) as Map<String, dynamic>;
    }
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString('local_users_db');
    final users = rawUsers != null ? json.decode(rawUsers) as List : [];
    
    final user = users.firstWhere(
      (u) => u['email'].toLowerCase() == email.trim().toLowerCase() && u['password'] == password,
      orElse: () => null,
    );

    if (user == null) {
      throw Exception("Invalid email or password.");
    }

    _currentUser = Map<String, dynamic>.from(user as Map);
    await prefs.setString('local_session_user', json.encode(_currentUser));
  }

  @override
  Future<void> signUpWithEmailAndPassword(String email, String password, String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString('local_users_db');
    final List users = rawUsers != null ? json.decode(rawUsers) as List : [];

    final exists = users.any((u) => u['email'].toLowerCase() == email.trim().toLowerCase());
    if (exists) {
      throw Exception("Email already registered.");
    }

    final newUser = {
      'userId': 'usr-${DateTime.now().millisecondsSinceEpoch}',
      'fullName': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
    };

    users.add(newUser);
    await prefs.setString('local_users_db', json.encode(users));

    // Sign in automatically
    _currentUser = newUser;
    await prefs.setString('local_session_user', json.encode(_currentUser));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString('local_users_db');
    final List users = rawUsers != null ? json.decode(rawUsers) as List : [];

    final exists = users.any((u) => u['email'].toLowerCase() == email.trim().toLowerCase());
    if (!exists) {
      throw Exception("Email not found.");
    }
    // Simulated reset email
    print("Simulated password reset email sent to: $email");
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_session_user');
    _currentUser = null;
  }

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  String? get currentUserId => _currentUser?['userId'] as String?;

  @override
  String? get currentUserEmail => _currentUser?['email'] as String?;

  @override
  String? get currentUserFullName => _currentUser?['fullName'] as String? ?? 'User';

  @override
  String? get currentUserPhone => _currentUser?['phone'] as String? ?? '';
}
