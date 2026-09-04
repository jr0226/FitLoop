import re
import json
import base64
import asyncio
import logging
from typing import Any, Dict, List, Optional
import httpx
from fastapi import HTTPException

from config import GEMINI_API_KEY, GEMINI_MODEL

logger = logging.getLogger(__name__)

# Attempt importing official google-genai SDK
try:
    from google import genai
    from google.genai import types
    from google.genai import errors as genai_errors
    _HAS_GENAI_SDK = True
except ImportError:
    _HAS_GENAI_SDK = False
    genai_errors = None


def _check_api_key():
    if not GEMINI_API_KEY or GEMINI_API_KEY.strip() == "" or "your_gemini_api_key" in GEMINI_API_KEY:
        logger.error("GEMINI_API_KEY is not configured on the backend.")
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY environment variable is not configured on the backend server."
        )


def _is_transient_error(err: Exception) -> bool:
    err_str = str(err).lower()
    if any(non_retry in err_str for non_retry in ["401", "403", "api_key_invalid", "permission_denied", "invalid argument", "400"]):
        return False
    if "404" in err_str and "not found" in err_str:
        return False

    if any(transient in err_str for transient in [
        "503", "unavailable", "high demand", "overloaded", "temporarily",
        "500", "502", "504", "deadline_exceeded", "timeout", "connection reset", "econnreset"
    ]):
        return True

    if genai_errors and isinstance(err, (genai_errors.ServerError, genai_errors.APIError)):
        status_code = getattr(err, "code", None)
        if status_code in (503, 500, 502, 504, 429):
            return True

    return False


def build_food_analysis_prompt(
    user_goal: str = "Maintenance",
    calorie_target: Optional[int] = None,
    diet_preference: str = "Standard",
    allergies: Optional[List[str]] = None,
) -> str:
    """
    Constructs a highly deterministic, structured prompt for Gemini AI food nutrition analysis
    incorporating fitness goal, daily calorie target, dietary preferences, and allergies.
    """
    clean_goal = (user_goal or "Maintenance").strip()
    clean_diet = (diet_preference or "Standard").strip()
    clean_allergies = [a.strip() for a in (allergies or []) if a and a.strip()]

    prompt_lines = [
        "You are an elite AI sports nutritionist, dietary specialist, and expert culinary analyst.",
        "Analyze the food in this image with meticulous accuracy, consistency, and objective visual evidence.",
        "",
        "CRITICAL VISUAL RECOGNITION RULES:",
        "1. VISIBLE EVIDENCE ONLY: Identify ONLY foods and beverages visibly present in the image.",
        "2. NO INVISIBLE INGREDIENTS: Do NOT list hidden cooking oils, pinch of salt, raw spices, or standard invisible recipe ingredients as separate food items.",
        "3. MULTI-FOOD DISHES: For mixed plates (e.g. Nasi Lemak, Chicken Rice plate, mixed rice plate), break down the dish into its distinct visible items (e.g., Rice, Fried Chicken, Boiled Egg, Sambal, Cucumber) with their respective portion sizes.",
        "4. NO DUPLICATE ENTRIES: Never list the same food component more than once under different names.",
        "5. STANDARDIZED CONCISE NAMES: Use standardized, recognized food names (e.g. 'Nasi Lemak', 'Chicken Rice', 'Char Kuey Teow', 'Roti Canai', 'French Fries', 'Fried Chicken', 'White Rice').",
        "6. PORTION ESTIMATION: Estimate portion sizes conservatively in 'estimatedServingGrams' based on standard realistic human portions. Do NOT vary serving sizes arbitrarily when the visual food portion is unchanged.",
        "",
        "USER PROFILE & CONTEXT:",
        f"- Fitness Goal: {clean_goal}",
    ]

    if calorie_target and calorie_target > 0:
        prompt_lines.append(f"- Daily Calorie Target: {calorie_target} kcal")

    prompt_lines.append(f"- Dietary Preference: {clean_diet}")

    if clean_allergies:
        prompt_lines.append(f"- Allergies & Intolerances: {', '.join(clean_allergies)}")
    else:
        prompt_lines.append("- Allergies & Intolerances: None reported")

    prompt_lines.extend([
        "",
        "PERSONALIZATION GUIDELINES:",
        f"1. Score Reasoning: Evaluate nutritional balance and macro ratios specifically against the user's '{clean_goal}' goal (0-100 scale).",
    ])

    if clean_diet.lower() in ("vegetarian", "vegan", "pescatarian", "halal"):
        prompt_lines.append(
            f"2. Dietary Restrictions: User follows a '{clean_diet}' diet. NEVER recommend alternatives containing ingredients prohibited under this diet (e.g. no meat/poultry for vegetarians; no animal products for vegans; no pork/alcohol for halal)."
        )

    if clean_allergies:
        prompt_lines.append(
            f"3. Allergy Safety: User is allergic or intolerant to: {', '.join(clean_allergies)}. STRICTLY DO NOT suggest any meals, foods, or healthier alternatives containing these allergens."
        )
        prompt_lines.append(
            "4. Safety Disclaimer: Never claim a food in the image is 100% guaranteed allergen-safe based solely on visual inspection. Use allergy context to avoid recommending unsafe alternatives."
        )

    prompt_lines.extend([
        "",
        "Return ONLY a valid JSON object matching this exact structure (no markdown backticks, no explanatory text outside the JSON):",
        "{",
        '  "foods": [',
        '    {',
        '      "name": "Food Name",',
        '      "estimatedServingGrams": 200,',
        '      "calories": 250,',
        '      "proteins": 15,',
        '      "carbs": 30,',
        '      "fats": 8',
        '    }',
        "  ],",
        '  "totalCalories": 250,',
        '  "totalProteins": 15,',
        '  "totalCarbs": 30,',
        '  "totalFats": 8,',
        '  "score": 85,',
        '  "explanation": "Brief nutritional explanation tailored to the user\'s goal.",',
        '  "alternatives": ["Healthier recommendation 1", "Healthier recommendation 2"]',
        "}",
    ])

    return "\n".join(prompt_lines)


def build_workout_recommendation_prompt(
    user_goal: str = "Maintenance",
    difficulty: str = "Intermediate",
    equipment: Optional[List[str]] = None,
    preferred_workout_types: Optional[List[str]] = None,
    recent_workouts_summary: Optional[str] = None,
    target_category: Optional[str] = None,
) -> str:
    """
    Constructs a personalized prompt for Gemini AI workout generation tailored to
    fitness goal, fitness level, available equipment, preferred workout types, recent history,
    and explicit target category (Cardio, Core, Full Body, Strength, etc.).
    """
    clean_goal = (user_goal or "Maintenance").strip()
    clean_difficulty = (difficulty or "Intermediate").strip()
    clean_equipment = [e.strip() for e in (equipment or []) if e and e.strip()]
    clean_types = [t.strip() for t in (preferred_workout_types or []) if t and t.strip()]
    clean_target = (target_category or "").strip()

    prompt_lines = [
        "You are an elite AI personal trainer and strength & conditioning specialist.",
        "Generate 2 distinct, highly tailored workout routines for the user.",
        "Each routine MUST have between 3 and 6 exercises. NEVER return an empty exercises array.",
        "",
        "USER PROFILE & CONTEXT:",
        f"- Fitness Goal: {clean_goal}",
        f"- Experience / Fitness Level: {clean_difficulty}",
    ]

    # Explicit Target Category Mandate
    if clean_target and clean_target.lower() != "all":
        norm_target = clean_target.title()
        prompt_lines.append(f"- EXPLICIT TARGET CATEGORY: {norm_target}")

    # Equipment Handling
    has_equipment = len(clean_equipment) > 0 and not (
        len(clean_equipment) == 1 and clean_equipment[0].lower() in ("none", "bodyweight", "none / bodyweight")
    )
    if has_equipment:
        prompt_lines.append(f"- Available Equipment: {', '.join(clean_equipment)}")
    else:
        prompt_lines.append("- Available Equipment: Bodyweight only (No gym equipment)")

    # Preferred Workout Types
    if clean_types:
        prompt_lines.append(f"- Preferred Workout Styles: {', '.join(clean_types)}")

    # Recent Workout History
    if recent_workouts_summary and recent_workouts_summary.strip():
        prompt_lines.append(f"- Recent Training History: {recent_workouts_summary.strip()}")

    prompt_lines.extend([
        "",
        "TRAINING & PERSONALIZATION RULES:",
    ])

    # Rule 0: Target Category Enforcement
    if clean_target and clean_target.lower() != "all":
        norm_target = clean_target.title()
        prompt_lines.append(
            f"0. EXPLICIT CATEGORY MANDATE: The user explicitly requested a '{norm_target}' workout. "
            f"BOTH generated routines MUST belong to the '{norm_target}' category and have \"category\": \"{norm_target}\". "
            f"Do NOT classify as generic 'Strength' if the user requested '{norm_target}'. "
            f"Even if the user's primary goal is '{clean_goal}', adapt the routine specifically to the '{norm_target}' category."
        )

    # Equipment constraint rule
    if has_equipment:
        prompt_lines.append(
            f"1. STRICT EQUIPMENT CONSTRAINT: The user ONLY has access to: {', '.join(clean_equipment)} and bodyweight. DO NOT recommend any exercises requiring equipment outside this list (e.g. no barbell rack, cables, or specialized gym machines unless explicitly listed). If equipment is limited, substitute with bodyweight movements. NEVER omit exercises or return an empty array."
        )
    else:
        prompt_lines.append(
            "1. STRICT EQUIPMENT CONSTRAINT: The user has NO gym equipment. Prescribe ONLY bodyweight/calisthenics exercises (e.g. push-ups, squats, lunges, planks, burpees). NEVER return an empty array."
        )

    # Fitness Level rule
    diff_lower = clean_difficulty.lower()
    if "beg" in diff_lower:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Beginner): Prioritize foundational movements with clear form cues. Keep volume moderate (e.g. 2-3 sets of 8-12 reps or 30-45s timed). Avoid advanced high-risk or complex movements like Olympic lifts, extreme plyometrics, or high-skill calisthenics."
        )
    elif "adv" in diff_lower:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Advanced): Incorporate progressive overload intensity, higher volume (4-5 sets of 6-12 reps), drop sets, tempo variations, and advanced movement variations suited for experienced athletes."
        )
    else:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Intermediate): Provide balanced hypertrophy/strength stimulus with standard compound and isolation exercises (3-4 sets of 8-12 reps) and supersets where appropriate."
        )

    # Preferred Workout Types rule
    if clean_types:
        prompt_lines.append(
            f"3. WORKOUT STYLE PREFERENCE: Bias routine themes towards the user's preferred styles ({', '.join(clean_types)}). Note: This acts as prioritization for routine themes, not an exclusion filter."
        )

    # Fitness Goal programming rule
    goal_lower = clean_goal.lower()
    if "gain" in goal_lower or "muscle" in goal_lower or "hypertrophy" in goal_lower:
        prompt_lines.append(
            "3b. FITNESS GOAL PROGRAMMING (Muscle Gain): Emphasize hypertrophy-friendly repetition ranges (8-12 reps), direct muscular tension, controlled tempos, standard resistance movements, and adequate rest periods."
        )
    elif "loss" in goal_lower or "fat" in goal_lower:
        prompt_lines.append(
            "3b. FITNESS GOAL PROGRAMMING (Weight Loss): Emphasize metabolic conditioning density, balanced resistance movements with active intervals, and shorter recovery intervals."
        )
    else:
        prompt_lines.append(
            "3b. FITNESS GOAL PROGRAMMING (Maintenance): Provide balanced full-body conditioning, functional movements, and sustainable volume."
        )

    # Category composition rules
    prompt_lines.extend([
        "4. CATEGORY COMPOSITION REQUIREMENTS:",
        "   - Cardio: Focus on aerobic conditioning, stamina, or cardiovascular intervals. Prescribe 3-6 exercises (e.g. Jumping Jacks, High Knees, Mountain Climbers, Burpees, Jump Rope, Air Bike, Marching in place). Use duration for sets/reps (e.g. '3 sets x 45s' or '3 rounds x 60 seconds') and provide 'durationSeconds'.",
        "   - Core: Focus on core stability, abdominals, obliques, and lower back. Prescribe 3-6 exercises (e.g. Forearm Plank, Dead Bug, Bird Dog, Bicycle Crunches, Russian Twists, Leg Raises). Category MUST be 'Core' and target muscle 'Core' or 'Abs'.",
        "   - Full Body: Must NOT be an isolated muscle group. Combine a balanced compound sequence: 1) Lower body (squat/lunge), 2) Upper push (push-up/press), 3) Upper pull (row/pulldown), 4) Core (plank/dead bug), 5) Conditioning (burpee/jumping jacks). Prescribe 4-6 exercises. Category MUST be 'Full Body'.",
        "   - Strength / Upper Body / Lower Body / HIIT: Provide standard targeted compound & isolation exercises (3-6 exercises).",
        "",
        "5. EXERCISE COUNT MANDATE: Each routine MUST contain 3 to 6 exercises. NEVER return an empty exercises array (\"exercises\": []).",
    ])

    # Recent History rule
    if recent_workouts_summary and recent_workouts_summary.strip():
        prompt_lines.append(
            f"5. WORKOUT HISTORY BALANCE: Use the recent training history ({recent_workouts_summary.strip()}) to avoid redundant exercises."
        )

    example_cat = clean_target.title() if (clean_target and clean_target.lower() != "all") else "Full Body"

    prompt_lines.extend([
        "",
        "Return ONLY a valid JSON array of 2 routine objects matching this exact structure (no markdown backticks, no explanatory text outside the JSON):",
        "[",
        "  {",
        '    "routineName": "Descriptive Routine Name",',
        f'    "level": "{clean_difficulty}",',
        f'    "category": "{example_cat}",',
        '    "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",',
        '    "exercises": [',
        "      {",
        '        "name": "Exercise Name",',
        f'        "category": "{example_cat}",',
        '        "sets": "3 sets x 10 reps",',
        '        "reps": 10,',
        '        "durationSeconds": 0,',
        '        "equipment": "Bodyweight",',
        '        "image": "https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=400",',
        '        "desc": "Brief form instruction."',
        "      }",
        "    ]",
        "  }",
        "]",
    ])

    return "\n".join(prompt_lines)


async def analyze_food_image(
    image_bytes: Optional[bytes] = None,
    image_base64: Optional[str] = None,
    user_goal: str = "Maintenance",
    calorie_target: Optional[int] = None,
    diet_preference: str = "Standard",
    allergies: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """
    Analyzes food image using Gemini AI with exponential backoff retries for 503/transient errors.
    Accepts raw binary image_bytes or base64 encoded image string, along with personalized user profile context.
    """
    _check_api_key()

    prompt = build_food_analysis_prompt(
        user_goal=user_goal,
        calorie_target=calorie_target,
        diet_preference=diet_preference,
        allergies=allergies,
    )

    if image_bytes is None:
        if not image_base64:
            raise HTTPException(status_code=400, detail="No image data provided.")
        try:
            if "," in image_base64:
                image_base64 = image_base64.split(",", 1)[1]
            image_bytes = base64.b64decode(image_base64)
        except Exception as e:
            logger.error(f"Failed to decode base64 image: {e}")
            raise HTTPException(status_code=400, detail="Invalid base64 image data.")

    max_attempts = 3
    backoff_delays = [1.0, 2.0, 4.0]
    raw_text = ""
    last_error: Optional[Exception] = None

    for attempt in range(1, max_attempts + 1):
        try:
            logger.info(f"Gemini AI food analysis attempt {attempt}/{max_attempts} (model: {GEMINI_MODEL}, thinking_level: LOW)")

            if _HAS_GENAI_SDK:
                client = genai.Client(api_key=GEMINI_API_KEY)
                config = types.GenerateContentConfig(
                    temperature=0.2,
                    response_mime_type="application/json",
                    thinking_config=types.ThinkingConfig(
                        thinking_level=types.ThinkingLevel.LOW,
                    ),
                )
                response = client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=[
                        types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                        prompt,
                    ],
                    config=config,
                )
                raw_text = response.text or ""
            else:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
                payload = {
                    "contents": [
                        {
                            "parts": [
                                {"text": prompt},
                                {
                                    "inlineData": {
                                        "mimeType": "image/jpeg",
                                        "data": base64.b64encode(image_bytes).decode("utf-8")
                                    }
                                }
                            ]
                        }
                    ],
                    "generationConfig": {
                        "temperature": 0.2,
                        "responseMimeType": "application/json",
                        "thinkingConfig": {
                            "thinkingLevel": "LOW",
                        },
                    }
                }
                async with httpx.AsyncClient(timeout=35.0) as client:
                    res = await client.post(url, json=payload)
                    if res.status_code == 200:
                        data = res.json()
                        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                    elif res.status_code == 503:
                        raise HTTPException(status_code=503, detail="Gemini service 503 unavailable.")
                    else:
                        raise HTTPException(status_code=res.status_code, detail=f"Gemini API returned error code {res.status_code}.")

            if raw_text and raw_text.strip():
                break

        except HTTPException as http_exc:
            if http_exc.status_code in (400, 500):
                raise
            last_error = http_exc
        except Exception as err:
            last_error = err
            if not _is_transient_error(err):
                logger.error(f"Non-retryable Gemini error on attempt {attempt}: {err}")
                raise HTTPException(status_code=502, detail=f"Failed to communicate with Gemini AI: {str(err)}")

        if attempt < max_attempts:
            delay = backoff_delays[attempt - 1]
            logger.warning(f"Gemini AI temporary 503 error on attempt {attempt}/{max_attempts}. Retrying in {delay}s...")
            await asyncio.sleep(delay)
        else:
            logger.error(f"Gemini AI all {max_attempts} attempts failed: {last_error}")
            raise HTTPException(
                status_code=503,
                detail="AI service is temporarily busy. Please try again shortly."
            )

    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=503, detail="AI service is temporarily busy. Please try again shortly.")

    try:
        clean_text = raw_text.strip()
        start = clean_text.find("{")
        end = clean_text.rfind("}")
        if start == -1 or end == -1:
            raise ValueError("No JSON object found in AI response.")
        
        json_str = clean_text[start:end + 1]
        return json.loads(json_str)
    except Exception as e:
        logger.error(f"Failed to parse Gemini response as JSON: {e}. Raw text: {raw_text}")
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an invalid JSON response structure."
        )


def _is_equipment_compatible(ex_equipment: str, ex_name: str, allowed_equipment: Optional[List[str]]) -> bool:
    """
    Validates whether an exercise's required equipment is compatible with user's available equipment.
    """
    clean_allowed = [
        e.strip().lower() for e in (allowed_equipment or [])
        if e and e.strip() and e.strip().lower() not in ("none", "none / bodyweight", "bodyweight")
    ]

    # If user has full gym, barbell, or gym access, all exercises are compatible
    if any(full in clean_allowed for full in ("full gym", "gym", "barbell")):
        return True

    eq_low = (ex_equipment or "").lower()
    name_low = (ex_name or "").lower()

    # User has no gym equipment (Bodyweight only)
    if not clean_allowed:
        if any(tool in eq_low or tool in name_low for tool in ("barbell", "dumbbell", "cable", "machine", "smith", "kettlebell", "bench press", "leg press", "hack squat")):
            return False
        return True

    # User has limited equipment (e.g. Dumbbells, Bench)
    has_cables = any("cable" in e for e in clean_allowed)
    has_barbell = any("barbell" in e for e in clean_allowed)
    has_machines = any("machine" in e for e in clean_allowed)

    if not has_cables and ("cable" in eq_low or "cable" in name_low):
        return False
    if not has_barbell and ("barbell" in eq_low or "barbell" in name_low):
        return False
    if not has_machines and ("machine" in eq_low or "smith" in eq_low or "leg press" in name_low or "hack squat" in name_low):
        return False

    return True


def _repair_exercise_equipment(ex: Dict[str, Any], allowed_equipment: Optional[List[str]]) -> Dict[str, Any]:
    """
    Substitutes an exercise requiring unavailable equipment with an equivalent movement pattern
    using available equipment (Dumbbells/Bench or Bodyweight).
    """
    ex_copy = dict(ex)
    name = (ex_copy.get("name") or ex_copy.get("exerciseName") or "").strip()
    name_low = name.lower()

    clean_allowed = [
        e.strip().lower() for e in (allowed_equipment or [])
        if e and e.strip() and e.strip().lower() not in ("none", "none / bodyweight", "bodyweight")
    ]
    has_dumbbells = any("dumbbell" in e for e in clean_allowed)
    has_bench = any("bench" in e for e in clean_allowed)

    if has_dumbbells:
        if "squat" in name_low or "leg press" in name_low or "hack squat" in name_low:
            ex_copy["name"] = "Dumbbell Goblet Squat"
            ex_copy["equipment"] = "Dumbbells"
        elif "deadlift" in name_low:
            ex_copy["name"] = "Dumbbell Romanian Deadlift"
            ex_copy["equipment"] = "Dumbbells"
        elif "incline" in name_low and "press" in name_low:
            ex_copy["name"] = "Dumbbell Incline Press" if has_bench else "Dumbbell Floor Press"
            ex_copy["equipment"] = "Dumbbells"
        elif "bench press" in name_low or "chest press" in name_low or "chest fly" in name_low:
            ex_copy["name"] = "Dumbbell Bench Press" if has_bench else "Dumbbell Floor Press"
            ex_copy["equipment"] = "Dumbbells"
        elif "overhead press" in name_low or "shoulder press" in name_low or "military press" in name_low:
            ex_copy["name"] = "Dumbbell Shoulder Press"
            ex_copy["equipment"] = "Dumbbells"
        elif "pulldown" in name_low or "cable row" in name_low or "barbell row" in name_low or "seated row" in name_low:
            ex_copy["name"] = "Dumbbell Bent-Over Row"
            ex_copy["equipment"] = "Dumbbells"
        elif "curl" in name_low:
            ex_copy["name"] = "Dumbbell Bicep Curl"
            ex_copy["equipment"] = "Dumbbells"
        elif "pushdown" in name_low or "tricep" in name_low:
            ex_copy["name"] = "Dumbbell Overhead Tricep Extension"
            ex_copy["equipment"] = "Dumbbells"
        elif "lunge" in name_low:
            ex_copy["name"] = "Dumbbell Walking Lunges"
            ex_copy["equipment"] = "Dumbbells"
        else:
            clean_name = re.sub(r'(?i)\b(barbell|cable|machine|smith)\s*', '', name).strip()
            ex_copy["name"] = f"Dumbbell {clean_name}" if not clean_name.lower().startswith("dumbbell") else clean_name
            ex_copy["equipment"] = "Dumbbells"
    else:
        # Bodyweight only
        if "bench press" in name_low or "chest" in name_low or "push" in name_low or "fly" in name_low:
            ex_copy["name"] = "Standard Push-Ups"
            ex_copy["equipment"] = "Bodyweight"
        elif "squat" in name_low or "leg press" in name_low or "hack squat" in name_low:
            ex_copy["name"] = "Bodyweight Air Squats"
            ex_copy["equipment"] = "Bodyweight"
        elif "lunge" in name_low:
            ex_copy["name"] = "Bodyweight Reverse Lunges"
            ex_copy["equipment"] = "Bodyweight"
        elif "deadlift" in name_low:
            ex_copy["name"] = "Single-Leg Bodyweight Deadlift"
            ex_copy["equipment"] = "Bodyweight"
        elif "row" in name_low or "pulldown" in name_low or "pull" in name_low or "back" in name_low:
            ex_copy["name"] = "Prone Back Extensions (Superman)"
            ex_copy["equipment"] = "Bodyweight"
        elif "shoulder" in name_low or "overhead" in name_low:
            ex_copy["name"] = "Pike Push-Ups"
            ex_copy["equipment"] = "Bodyweight"
        elif "curl" in name_low or "bicep" in name_low:
            ex_copy["name"] = "Doorframe Isometric Bicep Curl"
            ex_copy["equipment"] = "Bodyweight"
        elif "tricep" in name_low:
            ex_copy["name"] = "Chair / Bench Dips"
            ex_copy["equipment"] = "Bodyweight"
        elif "plank" in name_low or "abs" in name_low or "core" in name_low:
            ex_copy["name"] = "Forearm Plank"
            ex_copy["equipment"] = "Bodyweight"
        else:
            clean_name = re.sub(r'(?i)\b(barbell|dumbbell|cable|machine|smith)\s*', '', name).strip()
            ex_copy["name"] = f"Bodyweight {clean_name}" if not clean_name.lower().startswith("bodyweight") else clean_name
            ex_copy["equipment"] = "Bodyweight"

    logger.info(f"Repaired incompatible equipment in '{name}' -> '{ex_copy['name']}' ({ex_copy['equipment']})")
    return ex_copy


async def generate_workout_recommendations(
    user_goal: str = "Maintenance",
    difficulty: str = "Intermediate",
    equipment: Optional[List[str]] = None,
    preferred_workout_types: Optional[List[str]] = None,
    recent_workouts_summary: Optional[str] = None,
    target_category: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Generates personalized workout routines using Gemini AI with exponential backoff retries.
    Uses Gemini 3.8 Flash with thinking_level = MEDIUM for balanced exercise progression reasoning.
    Validates that returned routines have non-empty exercises and match requested target categories.
    """
    _check_api_key()

    prompt = build_workout_recommendation_prompt(
        user_goal=user_goal,
        difficulty=difficulty,
        equipment=equipment,
        preferred_workout_types=preferred_workout_types,
        recent_workouts_summary=recent_workouts_summary,
        target_category=target_category,
    )

    max_attempts = 3
    backoff_delays = [1.0, 2.0, 4.0]
    raw_text = ""
    last_error: Optional[Exception] = None

    for attempt in range(1, max_attempts + 1):
        try:
            logger.info(f"Gemini AI workout generation attempt {attempt}/{max_attempts} (model: {GEMINI_MODEL}, thinking_level: MEDIUM)")

            if _HAS_GENAI_SDK:
                client = genai.Client(api_key=GEMINI_API_KEY)
                config = types.GenerateContentConfig(
                    temperature=0.7,
                    response_mime_type="application/json",
                    thinking_config=types.ThinkingConfig(
                        thinking_level=types.ThinkingLevel.MEDIUM,
                    ),
                )
                response = client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=[prompt],
                    config=config,
                )
                raw_text = response.text or ""
            else:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
                payload = {
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "temperature": 0.7,
                        "responseMimeType": "application/json",
                        "thinkingConfig": {
                            "thinkingLevel": "MEDIUM",
                        },
                    },
                }
                async with httpx.AsyncClient(timeout=30.0) as client:
                    res = await client.post(url, json=payload)
                    if res.status_code == 200:
                        data = res.json()
                        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                    elif res.status_code == 503:
                        raise HTTPException(status_code=503, detail="Gemini service 503 unavailable.")
                    else:
                        raise HTTPException(status_code=res.status_code, detail=f"Gemini API returned error code {res.status_code}.")

            if raw_text and raw_text.strip():
                break

        except HTTPException as http_exc:
            if http_exc.status_code in (400, 500):
                raise
            last_error = http_exc
        except Exception as err:
            last_error = err
            if not _is_transient_error(err):
                logger.error(f"Non-retryable workout generation error on attempt {attempt}: {err}")
                raise HTTPException(status_code=502, detail=f"Failed to communicate with Gemini AI: {str(err)}")

        if attempt < max_attempts:
            delay = backoff_delays[attempt - 1]
            logger.warning(f"Gemini workout generation 503/busy. Retrying in {delay}s (attempt {attempt}/{max_attempts})...")
            await asyncio.sleep(delay)
        else:
            logger.error(f"Gemini workout generation all {max_attempts} attempts failed: {last_error}")
            raise HTTPException(
                status_code=503,
                detail="AI service is temporarily busy. Please try again shortly."
            )

    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=503, detail="AI service is temporarily busy. Please try again shortly.")

    parsed_routines: List[Dict[str, Any]] = []
    try:
        clean_text = raw_text.strip()
        start = clean_text.find("[")
        end = clean_text.rfind("]")
        if start != -1 and end != -1:
            raw_parsed = json.loads(clean_text[start:end + 1])
            if isinstance(raw_parsed, list):
                parsed_routines = raw_parsed
    except Exception as e:
        logger.warning(f"Failed to parse Gemini workout response: {e}. Raw: {raw_text[:200]}")

    # Validation Gate: Sanitize and ensure exercises exist
    norm_req_cat = target_category.strip().title() if (target_category and target_category.lower() != "all") else None
    valid_routines: List[Dict[str, Any]] = []

    for r in parsed_routines:
        if not isinstance(r, dict):
            continue
        raw_exercises = r.get("exercises") or []
        clean_exercises = []
        for ex in raw_exercises:
            if isinstance(ex, dict) and (ex.get("name") or ex.get("exerciseName")):
                clean_exercises.append(ex)

        # Drop routines with 0 exercises
        if not clean_exercises:
            continue

        # Enforce target category if requested
        if norm_req_cat:
            r["category"] = norm_req_cat

        # Enforce difficulty and goal metadata snapshots
        r["level"] = difficulty.title()
        r["fitnessLevel"] = difficulty.title()
        r["fitnessGoal"] = user_goal.title()

        # Validate and repair equipment compatibility
        repaired_exercises = []
        for ex in clean_exercises:
            ex_eq = ex.get("equipment") or "Bodyweight"
            ex_name = ex.get("name") or ex.get("exerciseName") or ""
            if _is_equipment_compatible(ex_eq, ex_name, equipment):
                repaired_exercises.append(ex)
            else:
                repaired = _repair_exercise_equipment(ex, equipment)
                repaired_exercises.append(repaired)

        r["exercises"] = repaired_exercises
        valid_routines.append(r)

    # Safe Fallback: If Gemini generated zero valid routines with exercises, return guaranteed safe templates
    if not valid_routines:
        logger.warning(f"Gemini generated 0 valid exercises for target_category='{target_category}'. Applying safe fallback routines.")
        effective_cat = norm_req_cat or "Full Body"
        if effective_cat == "Cardio":
            fallback_exercises = [
                {"name": "Jumping Jacks", "category": "Cardio", "sets": "3 sets x 45s", "durationSeconds": 45, "reps": 0, "equipment": "Bodyweight", "desc": "Light on feet, rhythmic arm swings."},
                {"name": "High Knees", "category": "Cardio", "sets": "3 sets x 30s", "durationSeconds": 30, "reps": 0, "equipment": "Bodyweight", "desc": "Drive knees up to hip height."},
                {"name": "Mountain Climbers", "category": "Cardio", "sets": "3 sets x 40s", "durationSeconds": 40, "reps": 0, "equipment": "Bodyweight", "desc": "Hold strong plank, alternate knees to chest."},
            ]
        elif effective_cat == "Core":
            fallback_exercises = [
                {"name": "Forearm Plank", "category": "Core", "sets": "3 sets x 45s", "durationSeconds": 45, "reps": 0, "equipment": "Bodyweight", "desc": "Keep elbows under shoulders and glutes engaged."},
                {"name": "Dead Bug", "category": "Core", "sets": "3 sets x 12 reps", "durationSeconds": 0, "reps": 12, "equipment": "Bodyweight", "desc": "Lower opposite arm and leg while pressing lower back to floor."},
                {"name": "Bicycle Crunches", "category": "Core", "sets": "3 sets x 20 reps", "durationSeconds": 0, "reps": 20, "equipment": "Bodyweight", "desc": "Rotate torso to bring opposite elbow to knee."},
            ]
        else:
            fallback_exercises = [
                {"name": "Bodyweight Squats", "category": "Legs", "sets": "3 sets x 12 reps", "durationSeconds": 0, "reps": 12, "equipment": "Bodyweight", "desc": "Hips back, knees tracking toes, chest upright."},
                {"name": "Push-Ups", "category": "Chest", "sets": "3 sets x 10 reps", "durationSeconds": 0, "reps": 10, "equipment": "Bodyweight", "desc": "Elbows at 45 degrees, core tight throughout."},
                {"name": "Forearm Plank", "category": "Core", "sets": "3 sets x 40s", "durationSeconds": 40, "reps": 0, "equipment": "Bodyweight", "desc": "Maintain straight line from head to heels."},
            ]

        if parsed_routines:
            for r in parsed_routines:
                if isinstance(r, dict):
                    r_copy = dict(r)
                    r_copy["exercises"] = list(fallback_exercises)
                    if norm_req_cat:
                        r_copy["category"] = norm_req_cat
                    valid_routines.append(r_copy)
        else:
            default_title = (
                "Cardio Stamina & Conditioning" if effective_cat == "Cardio"
                else ("Core Stability & Midsection" if effective_cat == "Core"
                else f"{effective_cat} Total Conditioning")
            )
            valid_routines = [
                {
                    "routineName": default_title,
                    "level": difficulty,
                    "category": effective_cat,
                    "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",
                    "exercises": fallback_exercises,
                }
            ]

    return valid_routines


def build_faq_fallback_prompt(question: str, context: Optional[str] = None) -> str:
    """
    Constructs a structured prompt for Gemini AI FAQ / Help Chatbot fallback.
    """
    clean_q = (question or "").strip()
    prompt_lines = [
        "You are the official FitLoop In-App Help & Support Assistant.",
        "FitLoop is an all-in-one health and fitness tracker featuring:",
        "- AI Food Scanner with Malaysian Food DB integration and photo persistence",
        "- Personalized AI Workout routines tailored to goal, equipment, and history",
        "- Activity, meal, and hydration reminders",
        "- Android Health Connect integration",
        "- Comprehensive PDF Nutrition & Fitness reports",
        "",
        "CRITICAL ASSISTANCE GUIDELINES:",
        "1. DOMAIN FOCUS: Answer user questions politely, accurately, and strictly within the realm of FitLoop and general fitness/wellness.",
        "2. MEDICAL SAFETY GUARDRAILS: If the user describes acute severe symptoms (e.g. chest pain, heart palpitations, severe shortness of breath, dizziness) or asks for clinical diagnosis/prescription alteration, immediately instruct them to seek medical care or emergency services.",
        "3. CONCISE & PRACTICAL: Keep the explanation concise (2 to 4 sentences).",
        "4. STRUCTURED OUTPUT: Return ONLY a valid JSON object matching the schema below.",
        "",
        f"User Query: {clean_q}",
    ]

    if context and context.strip():
        prompt_lines.append(f"User App Context: {context.strip()}")

    prompt_lines.extend([
        "",
        "Return ONLY a valid JSON object (no markdown backticks, no text outside JSON):",
        "{",
        '  "answer": "Helpful, concise answer text here.",',
        '  "suggestedActions": ["Suggested Action 1", "Suggested Action 2"],',
        '  "isMedicalNotice": false',
        "}",
    ])

    return "\n".join(prompt_lines)


async def generate_faq_fallback(
    question: str,
    context: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Generates an intelligent answer for un-matched Help & FAQ questions using Gemini 3.8 Flash.
    Configured with thinking_level = LOW for minimal latency and cost.
    """
    _check_api_key()

    prompt = build_faq_fallback_prompt(question=question, context=context)

    max_attempts = 3
    backoff_delays = [1.0, 2.0, 4.0]
    raw_text = ""
    last_error: Optional[Exception] = None

    for attempt in range(1, max_attempts + 1):
        try:
            logger.info(f"Gemini AI FAQ fallback attempt {attempt}/{max_attempts} (model: {GEMINI_MODEL}, thinking_level: LOW)")

            if _HAS_GENAI_SDK:
                client = genai.Client(api_key=GEMINI_API_KEY)
                config = types.GenerateContentConfig(
                    temperature=0.3,
                    response_mime_type="application/json",
                    thinking_config=types.ThinkingConfig(
                        thinking_level=types.ThinkingLevel.LOW,
                    ),
                )
                response = client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=[prompt],
                    config=config,
                )
                raw_text = response.text or ""
            else:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
                payload = {
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "temperature": 0.3,
                        "responseMimeType": "application/json",
                        "thinkingConfig": {
                            "thinkingLevel": "LOW",
                        },
                    },
                }
                async with httpx.AsyncClient(timeout=25.0) as client:
                    res = await client.post(url, json=payload)
                    if res.status_code == 200:
                        data = res.json()
                        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                    elif res.status_code == 503:
                        raise HTTPException(status_code=503, detail="Gemini service 503 unavailable.")
                    else:
                        raise HTTPException(status_code=res.status_code, detail=f"Gemini API returned error code {res.status_code}.")

            if raw_text and raw_text.strip():
                break

        except HTTPException as http_exc:
            if http_exc.status_code in (400, 500):
                raise
            last_error = http_exc
        except Exception as err:
            last_error = err
            if not _is_transient_error(err):
                logger.error(f"Non-retryable FAQ fallback error on attempt {attempt}: {err}")
                raise HTTPException(status_code=502, detail=f"Failed to communicate with Gemini AI: {str(err)}")

        if attempt < max_attempts:
            delay = backoff_delays[attempt - 1]
            logger.warning(f"Gemini FAQ fallback 503/busy. Retrying in {delay}s (attempt {attempt}/{max_attempts})...")
            await asyncio.sleep(delay)
        else:
            logger.error(f"Gemini FAQ fallback all {max_attempts} attempts failed: {last_error}")
            raise HTTPException(
                status_code=503,
                detail="AI service is temporarily busy. Please try again shortly."
            )

    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=503, detail="AI service is temporarily busy. Please try again shortly.")

    try:
        clean_text = raw_text.strip()
        start = clean_text.find("{")
        end = clean_text.rfind("}")
        if start == -1 or end == -1:
            raise ValueError("No JSON object found in AI response.")

        json_str = clean_text[start:end + 1]
        return json.loads(json_str)
    except Exception as e:
        logger.error(f"Failed to parse Gemini FAQ fallback response as JSON: {e}. Raw text: {raw_text}")
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an invalid JSON response structure."
        )
