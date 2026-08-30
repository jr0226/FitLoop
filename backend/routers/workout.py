from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional, Any, Dict

from services.gemini_service import generate_workout_recommendations

router = APIRouter(prefix="/api", tags=["Workout AI"])


class WorkoutRecommendRequest(BaseModel):
    userGoal: Optional[str] = Field("Maintenance", description="Target fitness goal (e.g. Muscle Gain, Fat Loss, Endurance)")
    difficulty: Optional[str] = Field("Intermediate", description="Experience level (e.g. Beginner, Intermediate, Advanced)")


@router.post("/workout/recommend", response_model=List[Dict[str, Any]])
@router.post("/ai/generate-workout", response_model=List[Dict[str, Any]])
async def recommend_workouts(request: WorkoutRecommendRequest):
    """
    Generates AI-recommended workout routines tailored to the user's fitness goal and experience level.
    """
    routines = await generate_workout_recommendations(
        user_goal=request.userGoal or "Maintenance",
        difficulty=request.difficulty or "Intermediate",
    )
    return routines
