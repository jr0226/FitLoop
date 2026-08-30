from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional, Any, Dict

from services.gemini_service import analyze_food_image

router = APIRouter(prefix="/api", tags=["Food & Nutrition AI"])


class FoodItem(BaseModel):
    name: str
    calories: int
    proteins: int
    carbs: int
    fats: int


class FoodAnalysisResponse(BaseModel):
    foods: List[Dict[str, Any]] = Field(default_factory=list)
    totalCalories: int = 0
    totalProteins: int = 0
    totalCarbs: int = 0
    totalFats: int = 0
    score: int = 0
    explanation: str = ""
    alternatives: List[str] = Field(default_factory=list)


class AnalyzeFoodRequest(BaseModel):
    imageBase64: str = Field(..., description="Base64-encoded image data")
    userGoal: Optional[str] = Field("Maintenance", description="User's current fitness goal (e.g. Muscle Gain, Fat Loss, Maintenance)")


@router.post("/food/analyze", response_model=FoodAnalysisResponse)
@router.post("/ai/analyze-food", response_model=FoodAnalysisResponse)
async def analyze_food(request: AnalyzeFoodRequest):
    """
    Analyzes an uploaded meal image using Gemini AI to return itemized foods,
    macronutrients, health score, and personalized nutritional alternatives.
    """
    result = await analyze_food_image(
        image_base64=request.imageBase64,
        user_goal=request.userGoal or "Maintenance",
    )
    return result
