import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'supabase_service.dart';

class AuthenticationException implements Exception {
  AuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._({
    SupabaseClient? client,
  }) : _client = client;

  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'cached_auth_session';

  final SupabaseClient? _client;
  SharedPreferences? _preferences;

  final ValueNotifier<AppUser?> _currentUserNotifier =
      ValueNotifier<AppUser?>(null);

  bool _isInitialized = false;

  SupabaseClient get _supabaseClient => _client ?? SupabaseService.instance.client;

  ValueListenable<AppUser?> get currentUserListenable => _currentUserNotifier;

  AppUser? get currentUser => _currentUserNotifier.value;

  bool get isAuthenticated => currentUser != null;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _preferences = await SharedPreferences.getInstance();
    final String? raw = _preferences?.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          json.decode(raw) as Map<dynamic, dynamic>,
        );
        _currentUserNotifier.value = AppUser.fromJson(decoded);
      } on FormatException {
        await _preferences?.remove(_sessionKey);
      } on TypeError {
        await _preferences?.remove(_sessionKey);
      }
    }

    _isInitialized = true;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    final String normalizedEmail = email.trim().toLowerCase();
    final String passwordHash = _hashPassword(password, normalizedEmail);

    final Map<String, dynamic>? response = await _supabaseClient
        .from('app_users')
        .select()
        .eq('email', normalizedEmail)
        .eq('password_hash', passwordHash)
        .maybeSingle();

    if (response == null) {
      throw AuthenticationException('Credenciales inválidas.');
    }

    final AppUser user = _mapUser(response);
    await _persistUser(user);
    return user;
  }

  Future<AppUser> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _ensureInitialized();

    final String normalizedEmail = email.trim().toLowerCase();
    final String passwordHash = _hashPassword(password, normalizedEmail);

    try {
      final Map<String, dynamic>? response = await _supabaseClient
          .from('app_users')
          .insert(<String, dynamic>{
            'email': normalizedEmail,
            'password_hash': passwordHash,
            'full_name': fullName,
          })
          .select()
          .maybeSingle();

      if (response == null) {
        throw AuthenticationException('No se pudo completar el registro.');
      }

      final AppUser user = _mapUser(response);
      await _persistUser(user);
      return user;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw AuthenticationException('El correo ya se encuentra registrado.');
      }
      throw AuthenticationException(
        error.message ?? 'Ocurrió un error al registrar la cuenta.',
      );
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();

    _currentUserNotifier.value = null;
    await _preferences?.remove(_sessionKey);
  }

  Future<void> _persistUser(AppUser user) async {
    _currentUserNotifier.value = user;
    await _preferences?.setString(
      _sessionKey,
      json.encode(user.toJson()),
    );
  }

  AppUser _mapUser(Map<String, dynamic> data) {
    return AppUser(
      id: data['id'].toString(),
      email: (data['email'] as String?)?.toLowerCase() ?? '',
      fullName: data['full_name'] as String?,
    );
  }

  String _hashPassword(String password, String salt) {
    final List<int> bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
