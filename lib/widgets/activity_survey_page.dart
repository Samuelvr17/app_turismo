import 'package:flutter/material.dart';

import '../models/activity_survey.dart';
import '../services/activity_survey_service.dart';
import '../services/recommendation_api_service.dart';

class ActivitySurveyPage extends StatefulWidget {
  const ActivitySurveyPage({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  @override
  State<ActivitySurveyPage> createState() => _ActivitySurveyPageState();
}

class _ActivitySurveyPageState extends State<ActivitySurveyPage> {
  final ActivitySurveyService _surveyService = ActivitySurveyService.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  final List<_Option<String>> _travelStyles = const <_Option<String>>[
    _Option<String>('relajado', 'Relajado',
        description: 'Prefiero actividades tranquilas y sin prisas.'),
    _Option<String>('equilibrado', 'Equilibrado',
        description: 'Me gusta combinar descanso con algunas aventuras.'),
    _Option<String>('aventurero', 'Aventurero',
        description: 'Busco experiencias intensas y llenas de adrenalina.'),
  ];

  final List<_Option<String>> _activityLevels = const <_Option<String>>[
    _Option<String>('baja', 'Suave',
        description: 'Actividades ligeras o paseos cortos.'),
    _Option<String>('media', 'Moderada',
        description: 'Puedo caminar y estar activo varias horas.'),
    _Option<String>('alta', 'Intensa',
        description: 'Disfruto retos físicos exigentes.'),
  ];

  final List<_Option<String>> _travelCompanions = const <_Option<String>>[
    _Option<String>('solo', 'Viajo solo/a'),
    _Option<String>('pareja', 'Con mi pareja'),
    _Option<String>('familia', 'En familia'),
    _Option<String>('amigos', 'Con amigos'),
  ];

  final List<_Option<String>> _budgetLevels = const <_Option<String>>[
    _Option<String>('economico', 'Económico'),
    _Option<String>('moderado', 'Moderado'),
    _Option<String>('premium', 'Premium'),
  ];

  final List<_Option<String>> _timeOfDay = const <_Option<String>>[
    _Option<String>('manana', 'Mañana'),
    _Option<String>('tarde', 'Tarde'),
    _Option<String>('noche', 'Noche'),
  ];

  final List<_Option<String>> _interestOptions = const <_Option<String>>[
    _Option<String>('naturaleza', 'Naturaleza'),
    _Option<String>('aventura', 'Aventura'),
    _Option<String>('gastronomia', 'Gastronomía'),
    _Option<String>('cultura', 'Cultura'),
    _Option<String>('bienestar', 'Bienestar y relajación'),
    _Option<String>('nocturna', 'Vida nocturna'),
  ];

  String _travelStyle = 'equilibrado';
  String _activityLevel = 'media';
  String _travelCompanion = 'solo';
  String _budgetLevel = 'moderado';
  String _preferredTime = 'manana';
  final Set<String> _selectedInterests = <String>{'naturaleza', 'cultura'};

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_selectedInterests.isEmpty) {
      setState(() {
        _errorMessage = 'Selecciona al menos un interés principal.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final ActivitySurvey survey = ActivitySurvey(
      travelStyle: _travelStyle,
      interests: _selectedInterests.toList(),
      activityLevel: _activityLevel,
      travelCompanions: _travelCompanion,
      budgetLevel: _budgetLevel,
      preferredTimeOfDay: _preferredTime,
      additionalNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await _surveyService.submitSurvey(survey);
      if (!mounted) return;
      widget.onCompleted?.call();
    } on RecommendationApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No pudimos guardar tus respuestas. Intenta nuevamente en unos minutos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleInterest(String value) {
    setState(() {
      if (_selectedInterests.contains(value)) {
        _selectedInterests.remove(value);
      } else {
        _selectedInterests.add(value);
      }
      if (_selectedInterests.isNotEmpty) {
        _errorMessage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conócete mejor'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                'Personaliza tus recomendaciones',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Responde estas preguntas para adaptar las actividades a tu estilo de viaje.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿Cómo describirías tu estilo de viaje?',
                child: Column(
                  children: _travelStyles
                      .map(
                        (_Option<String> option) => RadioListTile<String>(
                          title: Text(option.label),
                          subtitle: option.description != null
                              ? Text(option.description!)
                              : null,
                          value: option.value,
                          groupValue: _travelStyle,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _travelStyle = value;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿Qué tipos de actividades disfrutas?',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _interestOptions
                      .map(
                        (_Option<String> option) => FilterChip(
                          label: Text(option.label),
                          selected: _selectedInterests.contains(option.value),
                          onSelected: (_) => _toggleInterest(option.value),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Nivel de actividad física preferido',
                child: Column(
                  children: _activityLevels
                      .map(
                        (_Option<String> option) => RadioListTile<String>(
                          title: Text(option.label),
                          subtitle: option.description != null
                              ? Text(option.description!)
                              : null,
                          value: option.value,
                          groupValue: _activityLevel,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _activityLevel = value;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿Con quién viajas principalmente?',
                child: Column(
                  children: _travelCompanions
                      .map(
                        (_Option<String> option) => RadioListTile<String>(
                          title: Text(option.label),
                          value: option.value,
                          groupValue: _travelCompanion,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _travelCompanion = value;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿Cuál es tu presupuesto aproximado?',
                child: Column(
                  children: _budgetLevels
                      .map(
                        (_Option<String> option) => RadioListTile<String>(
                          title: Text(option.label),
                          value: option.value,
                          groupValue: _budgetLevel,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _budgetLevel = value;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿En qué momento del día prefieres realizar actividades?',
                child: Wrap(
                  spacing: 12,
                  children: _timeOfDay
                      .map(
                        (_Option<String> option) => ChoiceChip(
                          label: Text(option.label),
                          selected: _preferredTime == option.value,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() {
                                _preferredTime = option.value;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '¿Algo más que debamos saber?',
                child: TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Restricciones alimenticias, limitaciones físicas u otros detalles importantes.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar y generar recomendaciones'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Option<T> {
  const _Option(this.value, this.label, {this.description});

  final T value;
  final String label;
  final String? description;
}
