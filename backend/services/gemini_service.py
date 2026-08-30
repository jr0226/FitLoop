import json
import base64
import logging
from typing import Any, Dict, List
import httpx
from fastapi import HTTPException

from config import GEMINI_API_KEY, GEMINI_MODEL

logger = logging.getLogger(__name__)

# Attempt importing the official google-genai SDK if available
try:
    from google import genai
    from google.genai import types
    _HAS_GENAI_SDK = True
except ImportError:
    _HAS_GENAI_SDK = False


def _check_api_key():
    if not GEMINI_API_KEY or GEMINI_API_KEY.strip() == "" or "your_gemini_api_key" in GEMINI_API_KEY:
        logger.error("GEMINI_API_KEY is not configured on the backend.")
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY environment variable is not configured on the backend server."
        )


async def analyze_food_image(image_base64: str, user_goal: str) -> Dict[str, Any]:
    """
    Analyzes a base64-encoded food image using Gemini AI to return structured nutrition breakdown.
    """
    _check_api_key()

    prompt = f"""
You are an elite AI sports nutritionist. Analyze the food in this image.
The user's fitness goal is "{user_goal}".
Return ONLY a valid JSON object matching this exact structure (no markdown backticks, no explanatory text outside the JSON):
{{
  "foods": [
    {{"name": "Food Name", "calories": 200, "proteins": 20, "carbs": 10, "fats": 5}}
  ],
  "totalCalories": 200,
  "totalProteins": 20,
  "totalCarbs": 10,
  "totalFats": 5,
  "score": 85,
  "explanation": "Brief nutritional explanation tailored to the user's goal.",
  "alternatives": ["Healthier recommendation 1", "Healthier recommendation 2"]
}}
"""

    try:
        # Decode base64 image
        if "," in image_base64:
            image_base64 = image_base64.split(",", 1)[1]
        image_bytes = base64.b64decode(image_base64)
    except Exception as e:
        logger.error(f"Failed to decode base64 image: {e}")
        raise HTTPException(status_code=400, detail="Invalid base64 image data.")

    # Call Gemini via official SDK or REST API
    raw_text = ""
    try:
        if _HAS_GENAI_SDK:
            client = genai.Client(api_key=GEMINI_API_KEY)
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                    prompt,
                ],
            )
            raw_text = response.text or ""
        else:
            # Fallback to direct Gemini REST API
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
                ]
            }
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(url, json=payload)
                if res.status_code != 200:
                    logger.error(f"Gemini REST API error ({res.status_code}): {res.text}")
                    raise HTTPException(
                        status_code=502,
                        detail=f"Gemini API returned error code {res.status_code}."
                    )
                data = res.json()
                raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Gemini AI execution error: {e}", exc_info=True)
        raise HTTPException(
            status_code=502,
            detail=f"Failed to communicate with Gemini AI: {str(e)}"
        )

    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=502, detail="Gemini returned an empty response.")

    # Extract JSON object
    try:
        clean_text = raw_text.strip()
        start = clean_text.find("{")
        end = clean_text.rfind("}")
        if start == -1 or end == -1:
            raise ValueError("No JSON object found in AI response.")
        
        json_str = clean_text[start:end + 1]
        parsed_data = json.loads(json_str)
        return parsed_data
    except Exception as e:
        logger.error(f"Failed to parse Gemini food response as JSON: {e}. Raw text: {raw_text}")
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an invalid JSON response structure."
        )


async def generate_workout_recommendations(user_goal: str, difficulty: str) -> List[Dict[str, Any]]:
    """
    Generates personalized workout routines using Gemini AI based on user goal and difficulty.
    """
    _check_api_key()

    prompt = f"""
The user's fitness goal is "{user_goal}" and their experience level is "{difficulty}".
Create 2 distinct workout routines (e.g., Upper Body, Lower Body).
Each routine should have exactly 3 exercises.
Return ONLY a valid JSON array of objects matching this exact structure (no markdown formatting, backticks, or conversational text):
[
  {{
    "routineName": "String",
    "level": "{difficulty}",
    "category": "Full Body",
    "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",
    "exercises": [
      {{
        "name": "Exercise Name",
        "category": "Target Muscle",
        "sets": "3 sets x 10 reps",
        "image": "https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=400",
        "desc": "Brief form instruction."
      }}
    ]
  }}
]
"""

    raw_text = ""
    try:
        if _HAS_GENAI_SDK:
            client = genai.Client(api_key=GEMINI_API_KEY)
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=[prompt],
            )
            raw_text = response.text or ""
        else:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
            payload = {
                "contents": [
                    {"parts": [{"text": prompt}]}
                ]
            }
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(url, json=payload)
                if res.status_code != 200:
                    logger.error(f"Gemini REST API error ({res.status_code}): {res.text}")
                    raise HTTPException(
                        status_code=502,
                        detail=f"Gemini API returned error code {res.status_code}."
                    )
                data = res.json()
                raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Gemini AI workout generation error: {e}", exc_info=True)
        raise HTTPException(
            status_code=502,
            detail=f"Failed to communicate with Gemini AI: {str(e)}"
        )

    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=502, detail="Gemini returned an empty response.")

    # Extract JSON array
    try:
        clean_text = raw_text.strip()
        start = clean_text.find("[")
        end = clean_text.rfind("]")
        if start == -1 or end == -1:
            raise ValueError("No JSON array found in AI response.")

        json_str = clean_text[start:end + 1]
        parsed_data = json.loads(json_str)
        if not isinstance(parsed_data, list):
            raise ValueError("Expected a list of routines.")
        return parsed_data
    except Exception as e:
        logger.error(f"Failed to parse Gemini workout response as JSON: {e}. Raw text: {raw_text}")
        raise HTTPException(
            status_code=502,
            detail="Gemini returned an invalid JSON array format."
        )
