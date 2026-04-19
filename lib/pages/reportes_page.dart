import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/report.dart';
import '../models/safe_route.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final StorageService _storageService = StorageService.instance;
  final LocationService _locationService = LocationService.instance;

  late final VoidCallback _preferencesListener;
  late final VoidCallback _locationListener;

  ReportType? _selectedType;
  String? _selectedVereda;
  bool _shareLocation = true;
  bool _isSubmitting = false;
  LocationState _locationState = const LocationState();

  // Vereda dropdown options
  List<String> _veredaNames = <String>[];
  bool _loadingVeredas = true;

  // Public reports
  List<Report> _publicReports = <Report>[];
  bool _loadingPublicReports = true;
  String? _publicFilter; // null means "Todas"

  @override
  void initState() {
    super.initState();

    final UserPreferences initialPreferences = _storageService.preferences;
    final String? preferredTypeId = initialPreferences.preferredReportTypeId;
    if (preferredTypeId != null && preferredTypeId.isNotEmpty) {
      _selectedType = ReportType.fromId(preferredTypeId);
    }
    _shareLocation = initialPreferences.shareLocation;
    _locationState = _locationService.state;

    _preferencesListener = () {
      if (!mounted) {
        return;
      }

      final UserPreferences prefs = _storageService.preferences;
      setState(() {
        _shareLocation = prefs.shareLocation;
        final String? storedTypeId = prefs.preferredReportTypeId;
        if (storedTypeId != null && storedTypeId.isNotEmpty) {
          _selectedType = ReportType.fromId(storedTypeId);
        }
      });
    };

    _locationListener = () {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationState = _locationService.state;
      });
    };

    _storageService.preferencesListenable.addListener(_preferencesListener);
    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
    unawaited(_loadVeredas());
    unawaited(_loadPublicReports());
  }

  @override
  void dispose() {
    _storageService.preferencesListenable.removeListener(_preferencesListener);
    _locationService.stateListenable.removeListener(_locationListener);
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadVeredas() async {
    try {
      final List<SafeRoute> routes = await _storageService.loadSafeRoutes();
      if (mounted) {
        setState(() {
          _veredaNames = routes.map((SafeRoute r) => r.name).toList();
          _loadingVeredas = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar veredas: $e');
      if (mounted) {
        setState(() {
          _loadingVeredas = false;
        });
      }
    }
  }

  Future<void> _loadPublicReports() async {
    if (mounted) {
      setState(() {
        _loadingPublicReports = true;
      });
    }

    try {
      final List<Report> reports = await _storageService.getPublicReports(
        veredaName: _publicFilter,
      );
      if (mounted) {
        setState(() {
          _publicReports = reports;
          _loadingPublicReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar reportes públicos: $e');
      if (mounted) {
        setState(() {
          _loadingPublicReports = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildForm(context),
          const SizedBox(height: 24),
          ValueListenableBuilder<List<Report>>(
            valueListenable: _storageService.reportsListenable,
            builder: (BuildContext context, List<Report> reports, _) {
              return _buildReportsSection(context, reports);
            },
          ),
          const SizedBox(height: 24),
          _buildPublicReportsSection(context),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nuevo reporte',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo de reporte',
              border: OutlineInputBorder(),
            ),
            validator: (ReportType? value) {
              if (value == null) {
                return 'Selecciona el tipo de reporte';
              }
              return null;
            },
            items: ReportType.values
                .map(
                  (ReportType type) => DropdownMenuItem<ReportType>(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (ReportType? value) {
              setState(() {
                _selectedType = value;
              });

              if (value != null) {
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final UserPreferences currentPreferences =
                    _storageService.preferences.copyWith(
                  preferredReportTypeId: value.id,
                );
                unawaited(
                  _storageService.saveUserPreferences(currentPreferences).catchError(
                    (Object error) {
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudieron sincronizar las preferencias: $error',
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          _buildVeredaDropdown(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Describe lo ocurrido',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'La descripción es obligatoria';
              }

              if (value.trim().length < 10) {
                return 'Describe lo sucedido con al menos 10 caracteres';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildLocationIndicator(context),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compartir ubicación en mis reportes'),
            subtitle: Text(
              _shareLocation
                  ? 'La latitud y longitud se guardarán junto al reporte.'
                  : 'Solo se almacenará el texto del reporte.',
            ),
            value: _shareLocation,
            onChanged: (bool value) {
              setState(() {
                _shareLocation = value;
              });

              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              final UserPreferences currentPreferences =
                  _storageService.preferences.copyWith(
                shareLocation: value,
              );
              unawaited(
                _storageService.saveUserPreferences(currentPreferences).catchError(
                  (Object error) {
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'No se pudieron sincronizar las preferencias: $error',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar Reporte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVeredaDropdown() {
    if (_loadingVeredas) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Vereda',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Cargando veredas...'),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedVereda,
      decoration: const InputDecoration(
        labelText: 'Vereda',
        border: OutlineInputBorder(),
      ),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'Selecciona la vereda del reporte';
        }
        return null;
      },
      items: _veredaNames
          .map(
            (String name) => DropdownMenuItem<String>(
              value: name,
              child: Text(name),
            ),
          )
          .toList(growable: false),
      onChanged: (String? value) {
        setState(() {
          _selectedVereda = value;
        });
      },
    );
  }

  Widget _buildLocationIndicator(BuildContext context) {
    final LocationState state = _locationState;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color iconColor;
    Widget message;
    Widget? trailing;

    if (state.isLoading) {
      icon = Icons.my_location;
      iconColor = colorScheme.primary;
      message = const Text('Obteniendo ubicación actual...');
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (state.errorMessage != null) {
      icon = Icons.location_off_outlined;
      iconColor = colorScheme.error;
      message = Text(state.errorMessage!);
    } else if (state.position != null) {
      final Position position = state.position!;
      icon = Icons.place_outlined;
      iconColor = colorScheme.primary;
      final String coordinates =
          'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
      message = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(coordinates),
          const SizedBox(height: 4),
          Text(
            _shareLocation
                ? 'La ubicación se incluirá en el reporte.'
                : 'Has elegido no compartir la ubicación en este reporte.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else {
      icon = Icons.location_searching;
      iconColor = colorScheme.secondary;
      message = const Text('Ubicación no disponible en este momento.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: message),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildReportsSection(BuildContext context, List<Report> reports) {
    final ThemeData theme = Theme.of(context);

    final List<Report> pendingReports =
        reports.where((Report r) => !r.isSynced).toList();
    final List<Report> syncedReports =
        reports.where((Report r) => r.isSynced).toList();

    if (reports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Mis reportes',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no has registrado reportes. Completa el formulario para crear el primero (funciona incluso sin internet).',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (pendingReports.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Text(
                'Reportes pendientes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.cloud_off, size: 18, color: Colors.orange),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    unawaited(_storageService.syncPendingReports()),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sincronizar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pendingReports.map((Report report) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReportCard(context, report, showDelete: true),
              )),
          const Divider(height: 32),
        ],
        if (syncedReports.isNotEmpty) ...<Widget>[
          Text(
            'Mis reportes sincronizados',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...syncedReports.map((Report report) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReportCard(context, report, showDelete: true),
              )),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Public reports section
  // -----------------------------------------------------------------------

  Widget _buildPublicReportsSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 32),
        Text(
          'Reportes públicos',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildPublicFilter(context),
        const SizedBox(height: 12),
        if (_loadingPublicReports)
          const Center(child: CircularProgressIndicator())
        else if (_publicReports.isEmpty)
          Text(
            'No hay reportes públicos para mostrar.',
            style: theme.textTheme.bodyMedium,
          )
        else
          ..._publicReports.map((Report report) {
            final String? currentUserId =
                AuthService.instance.currentUser?.id;
            final bool isOwner =
                currentUserId != null && report.userId == currentUserId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildReportCard(
                context,
                report,
                showDelete: isOwner,
                showVereda: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPublicFilter(BuildContext context) {
    final List<String> filterOptions = <String>[
      'Todas',
      ..._veredaNames,
    ];

    return DropdownButtonFormField<String>(
      value: _publicFilter ?? 'Todas',
      decoration: const InputDecoration(
        labelText: 'Filtrar por vereda',
        border: OutlineInputBorder(),
      ),
      items: filterOptions
          .map(
            (String name) => DropdownMenuItem<String>(
              value: name,
              child: Text(name),
            ),
          )
          .toList(growable: false),
      onChanged: (String? value) {
        setState(() {
          _publicFilter = (value == null || value == 'Todas') ? null : value;
        });
        unawaited(_loadPublicReports());
      },
    );
  }

  // -----------------------------------------------------------------------
  // Report card (shared between my reports and public reports)
  // -----------------------------------------------------------------------

  Widget _buildReportCard(
    BuildContext context,
    Report report, {
    bool showDelete = false,
    bool showVereda = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final ReportType type = ReportType.fromId(report.typeId);
    final String formattedDate = _formatDate(report.createdAt);
    final bool hasLocation =
        report.latitude != null && report.longitude != null;
    final String locationText = hasLocation
        ? 'Lat: ${report.latitude!.toStringAsFixed(4)}, Lng: ${report.longitude!.toStringAsFixed(4)}'
        : 'Este reporte se guardó sin coordenadas.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              type.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!report.isSynced) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PENDIENTE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: report.isSynced ? 'Eliminar reporte' : 'Descartar pendiente',
                    onPressed: () => unawaited(_removeReport(report)),
                  ),
              ],
            ),
            if (showVereda) ...[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    report.veredaName ?? 'Sin vereda',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              report.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: hasLocation
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_isSubmitting) {
      return;
    }
    unawaited(_submitReport());
  }

  Future<void> _submitReport() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final ReportType? selectedType = _selectedType;
    if (selectedType == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();

    final Position? position = _locationState.position;
    final double? latitude =
        _shareLocation && position != null ? position.latitude : null;
    final double? longitude =
        _shareLocation && position != null ? position.longitude : null;

    try {
      final Report report = await _storageService.saveReport(
        type: selectedType,
        description: _descriptionController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        veredaName: _selectedVereda,
      );

      final UserPreferences updatedPreferences =
          _storageService.preferences.copyWith(
        preferredReportTypeId: selectedType.id,
        shareLocation: _shareLocation,
      );
      await _storageService.saveUserPreferences(updatedPreferences);

      if (!mounted) {
        return;
      }

      _descriptionController.clear();
      setState(() {
        _selectedVereda = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(report.isSynced
              ? 'Reporte sincronizado en la nube.'
              : 'Sin internet. Reporte guardado localmente para sincronizar luego.'),
          backgroundColor: report.isSynced ? null : Colors.orange.shade800,
        ),
      );

      // Refresh public reports after creating a new one
      unawaited(_loadPublicReports());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo sincronizar el reporte: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _removeReport(Report report) async {
    try {
      await _storageService.deleteReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte eliminado de la nube.')),
        );
        // Refresh public reports after deletion
        unawaited(_loadPublicReports());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar el reporte remoto: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
