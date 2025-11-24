import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ARService {
  ARService._();

  static final ARService instance = ARService._();

  static const String _tutorialSeenKey = 'ar_tutorial_seen';

  Future<bool> ensureCameraPermission(BuildContext context) async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    final bool? shouldRequest = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cámara necesaria'),
          content: const Text(
            'Necesitamos acceso a la cámara para mostrar las zonas de peligro en realidad aumentada. '
            'Puedes desactivar esta función cuando quieras en los permisos del dispositivo.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (shouldRequest != true) {
      return false;
    }

    status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Permiso requerido'),
            content: const Text(
              'Para usar la vista AR necesitamos que habilites la cámara. Abre la configuración '
              'del dispositivo y concede el permiso de cámara.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Ir a configuración'),
              ),
            ],
          );
        },
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Cámara no autorizada'),
            content: const Text(
              'La experiencia AR necesita acceso a la cámara. Puedes intentarlo nuevamente y '
              'permitir el acceso cuando el sistema te lo pida.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
    }

    return false;
  }

  Future<bool> shouldShowTutorial() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? seen = prefs.getBool(_tutorialSeenKey);
    return !(seen ?? false);
  }

  Future<void> markTutorialAsSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenKey, true);
  }
}
