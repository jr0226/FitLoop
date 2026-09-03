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
) -> str:
    """
    Constructs a personalized prompt for Gemini AI workout generation tailored to
    fitness goal, fitness level, available equipment, preferred workout types, and recent history.
    """
    clean_goal = (user_goal or "Maintenance").strip()
    clean_difficulty = (difficulty or "Intermediate").strip()
    clean_equipment = [e.strip() for e in (equipment or []) if e and e.strip()]
    clean_types = [t.strip() for t in (preferred_workout_types or []) if t and t.strip()]

    prompt_lines = [
        "You are an elite AI personal trainer and strength & conditioning specialist.",
        "Generate 2 distinct, highly tailored workout routines for the user.",
        "Each routine should have exactly 3 exercises.",
        "",
        "USER PROFILE & CONTEXT:",
        f"- Fitness Goal: {clean_goal}",
        f"- Experience / Fitness Level: {clean_difficulty}",
    ]

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

    # Equipment constraint rule
    if has_equipment:
        prompt_lines.append(
            f"1. STRICT EQUIPMENT CONSTRAINT: The user ONLY has access to: {', '.join(clean_equipment)} and bodyweight. DO NOT recommend any exercises requiring equipment outside this list (e.g. no barbell rack, cables, or specialized gym machines unless explicitly listed)."
        )
    else:
        prompt_lines.append(
            "1. STRICT EQUIPMENT CONSTRAINT: The user has NO gym equipment. Prescribe ONLY bodyweight/calisthenics exercises (e.g. push-ups, squats, lunges, planks, burpees)."
        )

    # Fitness Level rule
    diff_lower = clean_difficulty.lower()
    if "beg" in diff_lower:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Beginner): Prioritize foundational movements with clear form cues. Keep volume moderate (e.g. 2-3 sets of 8-12 reps). Avoid advanced high-risk or complex movements."
        )
    elif "adv" in diff_lower:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Advanced): Incorporate progressive overload intensity, higher volume, and advanced movement variations suited for experienced athletes."
        )
    else:
        prompt_lines.append(
            "2. FITNESS LEVEL SCALING (Intermediate): Provide balanced hypertrophy/strength stimulus with standard compound and isolation exercises."
        )

    # Preferred Workout Types rule
    if clean_types:
        prompt_lines.append(
            f"3. WORKOUT STYLE PREFERENCE: Bias routine themes towards the user's preferred styles ({', '.join(clean_types)})."
        )

    # Recent History rule
    if recent_workouts_summary and recent_workouts_summary.strip():
        prompt_lines.append(
            "4. WORKOUT HISTORY BALANCE: Use the recent training history to ensure muscle balance and avoid redundant routines."
        )

    prompt_lines.extend([
        "",
        "Return ONLY a valid JSON array of objects matching this exact structure (no markdown backticks, no explanatory text outside the JSON):",
        "[",
        "  {",
        '    "routineName": "String",',
        f'    "level": "{clean_difficulty}",',
        '    "category": "Full Body",',
        '    "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",',
        '    "exercises": [',
        "      {",
        '        "name": "Exercise Name",',
        '        "category": "Target Muscle",',
        '        "sets": "3 sets x 10 reps",',
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


async def generate_workout_recommendations(
    user_goal: str = "Maintenance",
    difficulty: str = "Intermediate",
    equipment: Optional[List[str]] = None,
    preferred_workout_types: Optional[List[str]] = None,
    recent_workouts_summary: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Generates personalized workout routines using Gemini AI with exponential backoff retries.
    Uses Gemini 3.8 Flash with thinking_level = MEDIUM for balanced exercise progression reasoning.
    """
    _check_api_key()

    prompt = build_workout_recommendation_prompt(
        user_goal=user_goal,
        difficulty=difficulty,
        equipment=equipment,
        preferred_workout_types=preferred_workout_types,
        recent_workouts_summary=recent_workouts_summary,
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

    try:
        clean_text = raw_text.strip()
        start = clean_text.find("[")
        end = clean_text.rfind("]")
        if start == -1 or end == -1:
            raise ValueError("No JSON array found in AI response.")

        return json.loads(clean_text[start:end + 1])
    except Exception as e:
        logger.error(f"Failed to parse Gemini workout response as JSON: {e}. Raw text: {raw_text}")
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an invalid JSON array format."
        )


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
