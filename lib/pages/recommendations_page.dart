import 'package:flutter/material.dart';

import '../models/activity_recommendation.dart';
import '../models/activity_survey.dart';
import '../services/activity_survey_service.dart';
import '../services/recommendation_api_service.dart';
import 'activity_survey_page.dart';


class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final ActivitySurveyService _surveyService = ActivitySurveyService.instance;
  bool _isRefreshing = false;
  String? _errorMessage;

  Future<void> _openSurveyEditor() async {
    final bool? surveyUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ActivitySurveyPage(
          onCompleted: () {
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    if (surveyUpdated == true && mounted) {
      await _refreshRecommendations();
    }
  }

  Future<void> _refreshRecommendations() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      await _surveyService.refreshRecommendations();
      if (!mounted) {
        return;
      }
    } on RecommendationApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'No pudimos actualizar las recomendaciones en este momento.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ValueListenableBuilder<ActivitySurvey?>(
      valueListenable: _surveyService.surveyListenable,
      builder: (BuildContext context, ActivitySurvey? survey, _) {
        if (survey == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Completa el cuestionario inicial para recibir recomendaciones personalizadas.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openSurveyEditor,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Responder cuestionario'),
                  ),
                ],
              ),
            ),
          );
        }

        return ValueListenableBuilder<List<ActivityRecommendation>>(
          valueListenable: _surveyService.recommendationsListenable,
          builder: (
            BuildContext context,
            List<ActivityRecommendation> recommendations,
            _,
          ) {
            if (recommendations.isEmpty && !_isRefreshing) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.explore_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no hay recomendaciones disponibles.',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pulsa el botón para generar nuevas sugerencias basadas en tu perfil.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isRefreshing ? null : _refreshRecommendations,
                        icon: _isRefreshing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Obtener recomendaciones'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openSurveyEditor,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar cuestionario'),
                      ),
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshRecommendations,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Recomendaciones para ti',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _openSurveyEditor,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar cuestionario'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Basadas en tu perfil ${survey.travelStyle.toLowerCase()} con intereses en ${survey.interests.join(', ')}.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildRecommendationCard(recommendations.first),
                      ],
                    );
                  }

                  final ActivityRecommendation recommendation =
                      recommendations[index];
                  return _buildRecommendationCard(recommendation);
                },
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 16),
                itemCount: recommendations.length,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendationCard(ActivityRecommendation recommendation) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              recommendation.activityName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.summary,
              style: theme.textTheme.bodyMedium,
            ),
            if (recommendation.location != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      recommendation.location!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (recommendation.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recommendation.tags
                    .map(
                      (String tag) => Chip(
                        label: Text(tag),
                        backgroundColor:
                            theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.2),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Confianza: ${(recommendation.confidence ?? 0.6).clamp(0, 1).toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _formatRelativeDate(recommendation.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 1) {
      return 'Hace ${difference.inDays} día${difference.inDays == 1 ? '' : 's'}';
    }
    if (difference.inHours >= 1) {
      return 'Hace ${difference.inHours} hora${difference.inHours == 1 ? '' : 's'}';
    }
    if (difference.inMinutes >= 1) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes == 1 ? '' : 's'}';
    }
    return 'Hace instantes';
  }
}
