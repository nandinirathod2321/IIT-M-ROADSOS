import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Secure lightweight manager for persistent user sessions.
class SessionManager {
  static const String _keyIsLoggedIn = 'auth_is_logged_in';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserFullName = 'auth_user_fullname';
  static const String _keyUserPhone = 'auth_user_phone';

  static bool _isLoggedIn = false;
  static String? _userId;
  static String? _userEmail;
  static String? _userFullName;
  static String? _userPhone;

  static bool get isLoggedIn => _isLoggedIn;
  static String? get userId => _userId;
  static String? get userEmail => _userEmail;
  static String? get userFullName => _userFullName;
  static String? get userPhone => _userPhone;

  static Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      _userId = prefs.getString(_keyUserId);
      _userEmail = prefs.getString(_keyUserEmail);
      _userFullName = prefs.getString(_keyUserFullName);
      _userPhone = prefs.getString(_keyUserPhone);
      print("[SessionManager] Loaded local session: isLoggedIn=$_isLoggedIn, user=$_userEmail");
    } catch (e) {
      print("[SessionManager] Error loading local session: $e");
    }
  }

  static Future<void> saveSession({
    required String userId,
    required String email,
    required String fullName,
    required String phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = true;
      _userId = userId;
      _userEmail = email;
      _userFullName = fullName;
      _userPhone = phone;

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyUserEmail, email);
      await prefs.setString(_keyUserFullName, fullName);
      await prefs.setString(_keyUserPhone, phone);
      print("[SessionManager] Saved local session for: $email");
    } catch (e) {
      print("[SessionManager] Error saving local session: $e");
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userFullName = null;
      _userPhone = null;

      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserFullName);
      await prefs.remove(_keyUserPhone);
      print("[SessionManager] Cleared local session");
    } catch (e) {
      print("[SessionManager] Error clearing local session: $e");
    }
  }
}

/// Central authentication and session management service.
/// Automatically falls back to SharedPreferences if Firebase is uninitialized.
abstract class AuthService {
  static AuthService? _instance;
  static bool useFirebase = false;

  static AuthService get instance {
    if (_instance == null) {
      print("AuthService.instance accessed before initialize completes. Returning temporary LocalAuthService.");
      _instance = LocalAuthService();
    }
    return _instance!;
  }

  static set instance(AuthService service) {
    _instance = service;
  }

  static Future<void> initialize() async {
    await SessionManager.loadSession();
    try {
      // Try to initialize Firebase
      await Firebase.initializeApp();
      _instance = FirebaseAuthService();
      useFirebase = true;
      print("Firebase Auth successfully initialized.");
    } catch (e) {
      print("Firebase initialization skipped/failed: $e. Falling back to SharedPreferences local auth.");
      final localAuth = LocalAuthService();
      await localAuth.loadSession();
      _instance = localAuth;
      useFirebase = false;
    }
    print("AUTH_READY");
    print("SERVICE_INITIALIZED");
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
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _fetchUserProfile(user.uid);
        await SessionManager.saveSession(
          userId: user.uid,
          email: user.email ?? '',
          fullName: _cachedName ?? user.displayName ?? 'User',
          phone: _cachedPhone ?? '',
        );
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
      await SessionManager.saveSession(
        userId: _auth.currentUser!.uid,
        email: _auth.currentUser!.email ?? email,
        fullName: _cachedName ?? 'User',
        phone: _cachedPhone ?? '',
      );
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
      await SessionManager.saveSession(
        userId: uid,
        email: email,
        fullName: name,
        phone: phone,
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await SessionManager.clearSession();
  }

  @override
  bool get isLoggedIn => SessionManager.isLoggedIn || _auth.currentUser != null;

  @override
  String? get currentUserId => _auth.currentUser?.uid ?? SessionManager.userId;

  @override
  String? get currentUserEmail => _auth.currentUser?.email ?? SessionManager.userEmail;

  @override
  String? get currentUserFullName => _cachedName ?? _auth.currentUser?.displayName ?? SessionManager.userFullName ?? 'User';

  @override
  String? get currentUserPhone => _cachedPhone ?? SessionManager.userPhone ?? '';
}

class LocalAuthService implements AuthService {
  Map<String, dynamic>? _currentUser;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString('local_session_user');
    if (session != null) {
      final user = json.decode(session) as Map<String, dynamic>;
      // Securely strip any raw password if it exists
      user.remove('password');
      _currentUser = user;
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

    final sessionUser = Map<String, dynamic>.from(user as Map);
    sessionUser.remove('password'); // DO NOT store raw passwords directly in session
    _currentUser = sessionUser;
    await prefs.setString('local_session_user', json.encode(_currentUser));

    // Save session in lightweight SessionManager
    await SessionManager.saveSession(
      userId: _currentUser!['userId'] as String,
      email: _currentUser!['email'] as String,
      fullName: _currentUser!['fullName'] as String? ?? 'User',
      phone: _currentUser!['phone'] as String? ?? '',
    );
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

    final sessionUser = Map<String, dynamic>.from(newUser);
    sessionUser.remove('password'); // DO NOT store raw passwords directly in session
    _currentUser = sessionUser;
    await prefs.setString('local_session_user', json.encode(_currentUser));

    // Save session in lightweight SessionManager
    await SessionManager.saveSession(
      userId: _currentUser!['userId'] as String,
      email: _currentUser!['email'] as String,
      fullName: _currentUser!['fullName'] as String? ?? 'User',
      phone: _currentUser!['phone'] as String? ?? '',
    );
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
    await SessionManager.clearSession();
  }

  @override
  bool get isLoggedIn => SessionManager.isLoggedIn || _currentUser != null;

  @override
  String? get currentUserId => SessionManager.userId ?? _currentUser?['userId'] as String?;

  @override
  String? get currentUserEmail => SessionManager.userEmail ?? _currentUser?['email'] as String?;

  @override
  String? get currentUserFullName => SessionManager.userFullName ?? _currentUser?['fullName'] as String? ?? 'User';

  @override
  String? get currentUserPhone => SessionManager.userPhone ?? _currentUser?['phone'] as String? ?? '';
}
