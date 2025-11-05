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
      throw AuthenticationException(error.message);
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();

    _currentUserNotifier.value = null;
    await _preferences?.remove(_sessionKey);
  }

  Future<AppUser> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    await _ensureInitialized();

    final AppUser? user = currentUser;
    if (user == null) {
      throw AuthenticationException('No hay una sesión activa.');
    }

    final Map<String, dynamic> updates = <String, dynamic>{};

    if (fullName != null) {
      final String trimmedFullName = fullName.trim();
      updates['full_name'] = trimmedFullName.isEmpty ? null : trimmedFullName;
    }

    String? normalizedEmail;
    if (email != null) {
      normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) {
        throw AuthenticationException('El correo electrónico no puede estar vacío.');
      }
    }

    final String trimmedNewPassword = newPassword?.trim() ?? '';
    if (trimmedNewPassword.isNotEmpty && trimmedNewPassword.length < 6) {
      throw AuthenticationException('La contraseña debe tener al menos 6 caracteres.');
    }

    final bool wantsEmailUpdate =
        normalizedEmail != null && normalizedEmail != user.email;
    if (wantsEmailUpdate) {
      updates['email'] = normalizedEmail;
    }

    final bool wantsPasswordUpdate = trimmedNewPassword.isNotEmpty;
    final bool requiresPassword = wantsPasswordUpdate || wantsEmailUpdate;

    String? oldHash;
    if (requiresPassword) {
      final String trimmedCurrentPassword = currentPassword?.trim() ?? '';
      if (trimmedCurrentPassword.isEmpty) {
        throw AuthenticationException('Debes ingresar tu contraseña actual.');
      }

      oldHash = _hashPassword(trimmedCurrentPassword, user.email);

      final String emailToPersist = wantsEmailUpdate ? normalizedEmail : user.email;
      final String passwordForHash =
          wantsPasswordUpdate ? trimmedNewPassword : trimmedCurrentPassword;

      updates['password_hash'] =
          _hashPassword(passwordForHash, emailToPersist);
    }

    if (updates.isEmpty) {
      return user;
    }

    try {
      final query = _supabaseClient
          .from('app_users')
          .update(updates)
          .eq('id', user.id);

      if (oldHash != null) {
        query.eq('password_hash', oldHash);
      }

      final Map<String, dynamic>? response = await query.select().maybeSingle();

      if (response == null) {
        if (oldHash != null) {
          throw AuthenticationException('La contraseña actual no es correcta.');
        }
        throw AuthenticationException('No se pudo actualizar el perfil.');
      }

      final AppUser updatedUser = _mapUser(response);
      await _persistUser(updatedUser);
      return updatedUser;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw AuthenticationException('El correo ya se encuentra registrado.');
      }
      throw AuthenticationException(
        error.message.isEmpty
            ? 'No se pudo actualizar el perfil.'
            : error.message,
      );
    }
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
