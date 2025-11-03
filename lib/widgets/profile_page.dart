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

  AppUser? _currentUser;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _applyUser(_authService.currentUser);
    _authService.currentUserListenable.addListener(_handleUserChanged);
  }

  @override
  void dispose() {
    _authService.currentUserListenable.removeListener(_handleUserChanged);
    _fullNameController.dispose();
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
  }

  Future<void> _saveProfile() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String rawFullName = _fullNameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _authService.updateProfile(
        fullName: rawFullName.isEmpty ? null : rawFullName,
      );
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveProfile(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey<String>('email_${user.email}'),
                initialValue: user.email,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                readOnly: true,
                enabled: false,
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
