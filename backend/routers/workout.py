from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional, Any, Dict

from services.gemini_service import generate_workout_recommendations

router = APIRouter(prefix="/api", tags=["Workout AI"])


class WorkoutRecommendRequest(BaseModel):
    userGoal: Optional[str] = Field("Maintenance", description="Target fitness goal (e.g. Muscle Gain, Fat Loss, Maintenance)")
    difficulty: Optional[str] = Field("Intermediate", description="Experience level (e.g. Beginner, Intermediate, Advanced)")
    fitnessGoal: Optional[str] = Field(None, description="Alias for userGoal")
    fitnessLevel: Optional[str] = Field(None, description="Alias for difficulty")
    equipment: Optional[List[str]] = Field(default_factory=list, description="Available workout equipment (e.g. ['Dumbbells', 'Bench'])")
    preferredWorkoutTypes: Optional[List[str]] = Field(default_factory=list, description="User's preferred workout categories (e.g. ['Strength', 'Full Body'])")
    recentWorkoutsSummary: Optional[str] = Field(None, description="Compact summary of recent workout history (e.g. 'Recent 7 days: Chest: 2, Back: 1')")


@router.post("/workout/recommend", response_model=List[Dict[str, Any]])
@router.post("/ai/generate-workout", response_model=List[Dict[str, Any]])
async def recommend_workouts(request: WorkoutRecommendRequest):
    """
    Generates AI-recommended workout routines tailored to the user's fitness goal,
    experience level, available equipment, preferred workout types, and recent history.
    """
    goal = request.fitnessGoal or request.userGoal or "Maintenance"
    diff = request.fitnessLevel or request.difficulty or "Intermediate"
    
    routines = await generate_workout_recommendations(
        user_goal=goal,
        difficulty=diff,
        equipment=request.equipment or [],
        preferred_workout_types=request.preferredWorkoutTypes or [],
        recent_workouts_summary=request.recentWorkoutsSummary,
    )
    return routines
