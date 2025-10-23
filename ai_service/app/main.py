"""Servicio de recomendaciones de actividades turísticas.

El objetivo de este servicio es recibir las respuestas del cuestionario de la
aplicación Flutter y generar recomendaciones personalizadas con base en un
conjunto curado de actividades disponibles en Villavicencio y sus alrededores.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, Field

app = FastAPI(
    title="Tourism Activity Recommendation Service",
    version="1.0.0",
    description=(
        "API independiente que procesa los cuestionarios de preferencias de "
        "App Turismo y devuelve sugerencias personalizadas basadas en reglas "
        "heurísticas."
    ),
)


class SurveyPayload(BaseModel):
    """Estructura de las respuestas del cuestionario enviado por Flutter."""

    travel_style: str = Field(alias="travelStyle")
    interests: List[str]
    activity_level: str = Field(alias="activityLevel")
    travel_companions: str = Field(alias="travelCompanions")
    budget_level: str = Field(alias="budgetLevel")
    preferred_time_of_day: str = Field(alias="preferredTimeOfDay")
    additional_notes: str | None = Field(default=None, alias="additionalNotes")

    model_config = ConfigDict(populate_by_name=True)


class RecommendationRequest(BaseModel):
    """Petición para generar recomendaciones de actividades."""

    user_id: str
    survey: SurveyPayload

    model_config = ConfigDict(populate_by_name=True)


class RecommendationOut(BaseModel):
    """Actividad sugerida."""

    activity_name: str = Field(alias="activityName")
    summary: str
    location: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)
    tags: List[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), alias="createdAt")

    model_config = ConfigDict(populate_by_name=True)


class RecommendationResponse(BaseModel):
    user_id: str
    recommendations: List[RecommendationOut]
    generated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), alias="generatedAt")

    model_config = ConfigDict(populate_by_name=True)


class _ActivityTemplate(BaseModel):
    """Plantilla interna para evaluar coincidencias."""

    name: str
    summary: str
    location: str
    tags: List[str]
    travel_styles: List[str]
    activity_levels: List[str]
    companions: List[str]
    budgets: List[str]
    times_of_day: List[str]


class _RecommendationEngine:
    def __init__(self) -> None:
        self._activities: List[_ActivityTemplate] = [
            _ActivityTemplate(
                name="Caminata guiada en el Parque Las Malocas",
                summary="Recorrido cultural por las tradiciones llaneras, con talleres de artesanía y show folclórico.",
                location="Parque Las Malocas, Villavicencio",
                tags=["cultura", "naturaleza", "familia"],
                travel_styles=["relajado", "equilibrado"],
                activity_levels=["baja", "media"],
                companions=["familia", "pareja", "amigos", "solo"],
                budgets=["economico", "moderado"],
                times_of_day=["manana", "tarde"],
            ),
            _ActivityTemplate(
                name="Rafting en el Río Güejar",
                summary="Descenso por aguas cristalinas, rodeado de cañones y cascadas ideales para los amantes de la adrenalina.",
                location="Río Güejar, Mesetas",
                tags=["aventura", "naturaleza", "adrenalina"],
                travel_styles=["aventurero"],
                activity_levels=["media", "alta"],
                companions=["amigos", "pareja"],
                budgets=["moderado", "premium"],
                times_of_day=["manana", "tarde"],
            ),
            _ActivityTemplate(
                name="Cabalgata al Mirador Cristo Rey",
                summary="Cabalgata al atardecer con vista panorámica de la ciudad y fotografía profesional opcional.",
                location="Mirador Cristo Rey, Villavicencio",
                tags=["naturaleza", "aventura", "panorama"],
                travel_styles=["equilibrado", "aventurero"],
                activity_levels=["media"],
                companions=["pareja", "amigos"],
                budgets=["moderado"],
                times_of_day=["tarde"],
            ),
            _ActivityTemplate(
                name="Tour gastronómico por la Ruta Llanera",
                summary="Degustación de mamona, pan de arroz, café de origen y cocteles locales en restaurantes seleccionados.",
                location="Centro gastronómico de Villavicencio",
                tags=["gastronomia", "cultura", "nocturna"],
                travel_styles=["equilibrado", "relajado"],
                activity_levels=["baja"],
                companions=["pareja", "amigos"],
                budgets=["moderado", "premium"],
                times_of_day=["tarde", "noche"],
            ),
            _ActivityTemplate(
                name="Jornada de bienestar en termales",
                summary="Circuito relajante con spa, masajes y meditación guiada en aguas termales naturales.",
                location="Termales de Santa Helena",
                tags=["bienestar", "relajacion"],
                travel_styles=["relajado"],
                activity_levels=["baja"],
                companions=["pareja", "amigos"],
                budgets=["premium"],
                times_of_day=["manana", "tarde"],
            ),
            _ActivityTemplate(
                name="Senderismo al Caño Cristales",
                summary='Exploración guiada del "río de los cinco colores" con fotografía y picnic local.',
                location="Parque Nacional Natural Sierra de la Macarena",
                tags=["naturaleza", "fotografia", "aventura"],
                travel_styles=["aventurero", "equilibrado"],
                activity_levels=["media", "alta"],
                companions=["amigos", "pareja", "solo"],
                budgets=["premium"],
                times_of_day=["manana"],
            ),
            _ActivityTemplate(
                name="Experiencia astronómica en los Llanos",
                summary="Observación de estrellas y astrofotografía con guía experto y fogata tradicional.",
                location="Finca agro turística a las afueras de Villavicencio",
                tags=["naturaleza", "ciencia", "nocturna"],
                travel_styles=["relajado", "equilibrado"],
                activity_levels=["baja"],
                companions=["pareja", "amigos", "familia"],
                budgets=["economico", "moderado"],
                times_of_day=["noche"],
            ),
            _ActivityTemplate(
                name="Circuito de parques urbanos y muralismo",
                summary="Ruta guiada en bicicleta eléctrica por murales urbanos, cafés de especialidad y parques emblemáticos.",
                location="Centro de Villavicencio",
                tags=["cultura", "aventura", "urbano"],
                travel_styles=["equilibrado"],
                activity_levels=["media"],
                companions=["amigos", "solo"],
                budgets=["economico", "moderado"],
                times_of_day=["manana", "tarde"],
            ),
            _ActivityTemplate(
                name="Safari fotográfico por los llanos",
                summary="Recorrido en camioneta 4x4 para avistar fauna llanera y aprender técnicas de fotografía de naturaleza.",
                location="Reserva Natural Lagos de Menegua",
                tags=["naturaleza", "fotografia", "aventura"],
                travel_styles=["aventurero", "equilibrado"],
                activity_levels=["media"],
                companions=["familia", "amigos", "pareja"],
                budgets=["premium"],
                times_of_day=["manana"],
            ),
        ]

    def recommend(self, survey: SurveyPayload, limit: int = 5) -> List[RecommendationOut]:
        scored = [
            (self._score_activity(activity, survey), activity)
            for activity in self._activities
        ]
        scored.sort(key=lambda item: item[0], reverse=True)

        recommendations: List[RecommendationOut] = []
        for score, activity in scored[:limit]:
            confidence = min(1.0, 0.25 + score / 10)
            recommendations.append(
                RecommendationOut(
                    activity_name=activity.name,
                    summary=activity.summary,
                    location=activity.location,
                    confidence=round(confidence, 2),
                    tags=activity.tags,
                    created_at=datetime.now(timezone.utc),
                )
            )
        return recommendations

    def _score_activity(self, activity: _ActivityTemplate, survey: SurveyPayload) -> float:
        score = 0.0
        interests = set(survey.interests)
        score += 1.5 * len(interests.intersection(activity.tags))

        if survey.travel_style in activity.travel_styles:
            score += 1.2
        if survey.activity_level in activity.activity_levels:
            score += 1.0
        if survey.travel_companions in activity.companions:
            score += 0.8
        if survey.budget_level in activity.budgets:
            score += 0.6
        if survey.preferred_time_of_day in activity.times_of_day:
            score += 0.4

        if survey.additional_notes:
            lowered = survey.additional_notes.lower()
            keywords = {
                "veg": 0.3,
                "fot": 0.3,
                "niñ": 0.4,
                "adult": 0.2,
                "avent": 0.4,
            }
            for token, boost in keywords.items():
                if token in lowered:
                    score += boost
                    break

        return score


def _get_engine() -> _RecommendationEngine:
    # En un despliegue real se utilizaría inyección de dependencias o un
    # singleton thread-safe. Para este ejemplo sencillo basta con instanciarlo
    # una sola vez y reutilizarlo.
    if not hasattr(_get_engine, "_instance"):
        setattr(_get_engine, "_instance", _RecommendationEngine())
    return getattr(_get_engine, "_instance")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/recommendations", response_model=RecommendationResponse)
def create_recommendations(payload: RecommendationRequest) -> RecommendationResponse:
    if not payload.survey.interests:
        raise HTTPException(status_code=400, detail="Debe indicar al menos un interés")

    engine = _get_engine()
    recommendations = engine.recommend(payload.survey)

    if not recommendations:
        raise HTTPException(status_code=500, detail="No se pudieron generar recomendaciones")

    return RecommendationResponse(user_id=payload.user_id, recommendations=recommendations)
