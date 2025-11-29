import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  AppUser? _currentUser;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _applyUser(_authService.currentUser);
    _authService.currentUserListenable.addListener(_handleUserChanged);
  }

  @override
  void dispose() {
    _authService.currentUserListenable.removeListener(_handleUserChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleUserChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _applyUser(_authService.currentUser);
    });
  }

  void _applyUser(AppUser? user) {
    _currentUser = user;
    final String newName = user?.fullName ?? '';
    if (_fullNameController.text != newName) {
      _fullNameController.value = TextEditingValue(
        text: newName,
        selection: TextSelection.collapsed(offset: newName.length),
      );
    }
    final String newEmail = user?.email ?? '';
    if (_emailController.text != newEmail) {
      _emailController.value = TextEditingValue(
        text: newEmail,
        selection: TextSelection.collapsed(offset: newEmail.length),
      );
    }
  }

  Future<void> _saveProfile() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String rawFullName = _fullNameController.text.trim();
    final String normalizedEmail = _emailController.text.trim().toLowerCase();
    final String trimmedCurrentPassword = _currentPasswordController.text.trim();
    final String trimmedNewPassword = _newPasswordController.text.trim();
    final bool wantsEmailUpdate =
        normalizedEmail.isNotEmpty &&
        normalizedEmail != (_currentUser?.email ?? '').toLowerCase();
    final bool wantsPasswordUpdate = trimmedNewPassword.isNotEmpty;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _authService.updateProfile(
        fullName: rawFullName.isEmpty ? null : rawFullName,
        email: wantsEmailUpdate ? normalizedEmail : null,
        currentPassword: wantsEmailUpdate || wantsPasswordUpdate
            ? (trimmedCurrentPassword.isEmpty ? null : trimmedCurrentPassword)
            : null,
        newPassword:
            wantsPasswordUpdate ? trimmedNewPassword : null,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente.'),
        ),
      );
    } on AuthenticationException catch (error) {
      _handleError(error.message);
    } catch (error) {
      _handleError('Ocurrió un error inesperado. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = _currentUser;

    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay información de perfil disponible.'),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tu perfil',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Actualiza tu información personal para que podamos brindarte una experiencia más personalizada.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Ingresa tu nombre',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (String? value) {
                  final String normalizedEmail =
                      (value ?? '').trim().toLowerCase();
                  if (_emailController.text != normalizedEmail) {
                    _emailController.value = _emailController.value.copyWith(
                      text: normalizedEmail,
                      selection: TextSelection.collapsed(
                        offset: normalizedEmail.length,
                      ),
                      composing: TextRange.empty,
                    );
                  }
                  if (normalizedEmail.isEmpty) {
                    return 'Ingresa tu correo electrónico.';
                  }
                  final RegExp emailRegex =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(normalizedEmail)) {
                    return 'Ingresa un correo electrónico válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  final String trimmedCurrentPassword = (value ?? '').trim();
                  final bool wantsPasswordUpdate =
                      _newPasswordController.text.trim().isNotEmpty ||
                          _confirmPasswordController.text.trim().isNotEmpty;
                  final bool wantsEmailUpdate =
                      _emailController.text.trim().toLowerCase() !=
                          user.email.toLowerCase();
                  if (wantsPasswordUpdate || wantsEmailUpdate) {
                    if (trimmedCurrentPassword.isEmpty) {
                      return 'Ingresa tu contraseña actual.';
                    }
                    if (trimmedCurrentPassword.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                  } else if (trimmedCurrentPassword.isNotEmpty &&
                      trimmedCurrentPassword.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  final String trimmedNewPassword = (value ?? '').trim();
                  final bool hasConfirmation =
                      _confirmPasswordController.text.trim().isNotEmpty;
                  if (trimmedNewPassword.isEmpty) {
                    if (hasConfirmation) {
                      return 'Ingresa una nueva contraseña.';
                    }
                    return null;
                  }
                  if (trimmedNewPassword.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveProfile(),
                validator: (String? value) {
                  final String trimmedConfirmation = (value ?? '').trim();
                  final String trimmedNewPassword =
                      _newPasswordController.text.trim();
                  if (trimmedNewPassword.isEmpty &&
                      trimmedConfirmation.isEmpty) {
                    return null;
                  }
                  if (trimmedNewPassword.isEmpty) {
                    return 'Ingresa una nueva contraseña.';
                  }
                  if (trimmedNewPassword.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres.';
                  }
                  if (trimmedConfirmation != trimmedNewPassword) {
                    return 'Las contraseñas no coinciden.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...<Widget>[
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
