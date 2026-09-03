import logging
from typing import List, Optional, Any, Dict
from fastapi import APIRouter, File, Form, UploadFile, HTTPException, Query
from pydantic import BaseModel, Field

from services.gemini_service import analyze_food_image
from services.malaysian_food_service import MalaysianFoodService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Food & Nutrition AI"])

# Allowed image MIME types for food scanning
ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "application/octet-stream",
}

MAX_IMAGE_SIZE_BYTES = 15 * 1024 * 1024  # 15 MB max upload


class FoodItem(BaseModel):
    name: str
    calories: int
    proteins: int
    carbs: int
    fats: int
    fibre: Optional[float] = None
    sugar: Optional[float] = None
    sodium: Optional[int] = None
    nutritionSource: Optional[str] = "gemini_ai"
    matchedFoodName: Optional[str] = None
    matchScore: Optional[float] = None
    servingInfo: Optional[str] = None


class FoodAnalysisResponse(BaseModel):
    foods: List[Dict[str, Any]] = Field(default_factory=list)
    totalCalories: int = 0
    totalProteins: int = 0
    totalCarbs: int = 0
    totalFats: int = 0
    score: int = 0
    explanation: str = ""
    alternatives: List[str] = Field(default_factory=list)


@router.post("/ai/analyze-food", response_model=FoodAnalysisResponse)
@router.post("/food/analyze", response_model=FoodAnalysisResponse)
async def analyze_food(
    file: UploadFile = File(..., description="Food image file (JPEG, PNG, WEBP)"),
    user_goal: Optional[str] = Form("Maintenance", description="User's current fitness goal (e.g. Muscle Gain, Fat Loss, Maintenance)"),
    calorie_target: Optional[int] = Form(None, description="User's daily calorie target in kcal (e.g. 2000)"),
    diet_preference: Optional[str] = Form("Standard", description="User's diet preference (e.g. Standard, Halal, Vegetarian, Vegan, Pescatarian)"),
    allergies: Optional[str] = Form(None, description="User's allergies (comma-separated or JSON list)"),
):
    """
    Analyzes an uploaded meal image using Gemini AI, cross-references detected foods
    against the Malaysian Food Database for authoritative nutritional values,
    and returns itemized macronutrients, health score, and personalized recommendations
    tailored to the user's fitness goal, calorie target, diet, and allergies.
    """
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="No image file provided.")

    # Validate image format
    content_type = (file.content_type or "").lower().strip()
    if content_type and content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image format '{content_type}'. Please upload a JPEG, PNG, or WEBP image.",
        )

    # Read binary bytes
    try:
        image_bytes = await file.read()
    except Exception as read_err:
        logger.error(f"Failed to read uploaded image file: {read_err}")
        raise HTTPException(status_code=400, detail="Failed to process uploaded image file.")

    if not image_bytes or len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded image file is empty.")

    if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="Image file exceeds maximum allowable size (15MB).")

    clean_goal = (user_goal or "Maintenance").strip()
    clean_diet = (diet_preference or "Standard").strip()
    
    # Parse allergies if provided
    parsed_allergies: List[str] = []
    if allergies and str(allergies).strip():
        raw_allergy_str = str(allergies).strip()
        if raw_allergy_str.startswith("[") and raw_allergy_str.endswith("]"):
            try:
                import json
                loaded = json.loads(raw_allergy_str)
                if isinstance(loaded, list):
                    parsed_allergies = [str(x).strip() for x in loaded if str(x).strip()]
            except Exception:
                parsed_allergies = [a.strip() for a in raw_allergy_str.strip("[]").replace('"', '').replace("'", "").split(",") if a.strip()]
        else:
            parsed_allergies = [a.strip() for a in raw_allergy_str.split(",") if a.strip()]

    logger.info(
        f"Received food analysis request: {file.filename} ({len(image_bytes)} bytes), "
        f"goal: '{clean_goal}', calorieTarget: {calorie_target}, diet: '{clean_diet}', allergies: {parsed_allergies}"
    )

    # 1. AI Multimodal Food Recognition via Gemini
    gemini_result = await analyze_food_image(
        image_bytes=image_bytes,
        user_goal=clean_goal,
        calorie_target=calorie_target,
        diet_preference=clean_diet,
        allergies=parsed_allergies,
    )

    # 2. Authoritative Malaysian Food Database Enrichment
    try:
        enriched_result = MalaysianFoodService.enrich_gemini_analysis(gemini_result)
        return enriched_result
    except Exception as enrich_err:
        logger.error(f"Error enriching food analysis with Malaysian DB: {enrich_err}", exc_info=True)
        # Fall back to raw Gemini result if database lookup encounters an unexpected failure
        return gemini_result


@router.get("/malaysian-foods", tags=["Malaysian Foods"])
async def list_malaysian_foods():
    """
    Lists all available Malaysian foods in the local database.
    """
    foods = MalaysianFoodService.get_all_foods()
    return [
        {
            "id": f.id,
            "sourceId": f.source_id,
            "name": f.name,
            "nameMs": f.name_ms,
            "category": f.category,
            "caloriesPer100g": f.calories_kcal,
            "proteinPer100g": f.protein_g,
            "carbsPer100g": f.carbs_g,
            "fatPer100g": f.fat_g,
            "fibrePer100g": f.fibre_g,
            "sugarPer100g": f.sugar_g,
            "sodiumPer100g": f.sodium_mg,
            "servingName": f.serving_name,
            "servingGrams": f.serving_grams,
        }
        for f in foods
    ]


@router.get("/malaysian-foods/match", tags=["Malaysian Foods"])
async def match_malaysian_food(query: str = Query(..., min_length=1, description="Food name query")):
    """
    Fuzzy matches a food query string against the Malaysian food database.
    """
    matched, score = MalaysianFoodService.find_match(query)
    if not matched:
        return {"matched": False, "query": query, "score": score}

    nutrition = MalaysianFoodService.calculate_nutrition_for_serving(matched)
    return {
        "matched": True,
        "query": query,
        "score": score,
        "food": {
            "name": matched.name,
            "nameMs": matched.name_ms,
            "category": matched.category,
            "servingName": matched.serving_name,
            "servingGrams": matched.serving_grams,
            "nutrition": nutrition,
        }
    }
