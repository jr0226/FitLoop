import re
import time
import logging
from typing import List, Dict, Any, Optional, Tuple
import httpx
from fastapi import APIRouter, HTTPException, Query, Path

from config import RAPIDAPI_KEY, RAPIDAPI_HOST

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/exercises", tags=["Exercises"])

# Allowed ExerciseDB Body Parts for strict input validation
VALID_BODY_PARTS = {
    "back", "cardio", "chest", "lower arms", "lower legs",
    "neck", "shoulders", "upper arms", "upper legs", "waist", "all",
    "legs", "arms", "core", "full body"
}

BODY_PART_ALIASES = {
    "legs": "upper legs",
    "arms": "upper arms",
    "core": "waist",
    "full body": "all",
}

_EXERCISE_CACHE: Dict[str, Tuple[float, Any]] = {}
CACHE_TTL_SECONDS = 3600  # 1 hour caching to minimize RapidAPI quota usage


def _check_rapidapi_key():
    if not RAPIDAPI_KEY or RAPIDAPI_KEY.strip() == "" or "your_rapidapi_key" in RAPIDAPI_KEY:
        logger.warning("RAPIDAPI_KEY environment variable is not configured on the backend server.")
        raise HTTPException(
            status_code=503,
            detail="ExerciseDB service is currently unavailable (backend RAPIDAPI_KEY not configured)."
        )


def _sanitize_search_term(query: str) -> str:
    """Sanitizes user input string allowing only alphanumeric, spaces, and hyphens."""
    clean = re.sub(r"[^a-zA-Z0-9\s\-]", "", query).strip()
    if not clean:
        raise HTTPException(status_code=400, detail="Search query contains invalid characters.")
    return clean.lower()


async def _fetch_from_rapidapi(endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
    """Executes a validated, authenticated request to RapidAPI ExerciseDB with caching, timeout, and error handling."""
    cache_key = f"{endpoint}_{sorted((params or {}).items())}"
    now = time.time()
    if cache_key in _EXERCISE_CACHE:
        cached_time, cached_data = _EXERCISE_CACHE[cache_key]
        if now - cached_time < CACHE_TTL_SECONDS:
            logger.debug(f"Serving cached ExerciseDB response for {endpoint}")
            return cached_data

    _check_rapidapi_key()

    url = f"https://{RAPIDAPI_HOST}{endpoint}"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": RAPIDAPI_HOST,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.get(url, headers=headers, params=params)

            if res.status_code == 200:
                try:
                    data = res.json()
                    _EXERCISE_CACHE[cache_key] = (now, data)
                    return data
                except Exception as json_err:
                    logger.error(f"Failed to parse RapidAPI JSON response: {json_err}")
                    raise HTTPException(status_code=502, detail="Invalid JSON response from upstream ExerciseDB.")
            elif res.status_code == 404:
                return [] if endpoint != "/exercises/exercise" else None
            elif res.status_code == 401 or res.status_code == 403:
                logger.error(f"RapidAPI Authentication error ({res.status_code}): {res.text}")
                raise HTTPException(status_code=502, detail="Backend failed to authenticate with ExerciseDB.")
            elif res.status_code == 429:
                logger.warning("RapidAPI rate limit exceeded.")
                raise HTTPException(status_code=429, detail="ExerciseDB rate limit exceeded. Please try again shortly.")
            else:
                logger.error(f"RapidAPI upstream error ({res.status_code}): {res.text}")
                raise HTTPException(status_code=502, detail=f"Upstream ExerciseDB error: {res.status_code}")

    except httpx.TimeoutException:
        logger.error(f"RapidAPI request timed out for {endpoint}")
        raise HTTPException(status_code=504, detail="Upstream ExerciseDB request timed out.")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error communicating with RapidAPI: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal exercise service error: {str(e)}")


@router.get("/search", response_model=List[Dict[str, Any]])
@router.get("", response_model=List[Dict[str, Any]])
async def search_exercises(
    query: str = Query(..., min_length=1, max_length=50, description="Exercise name to search"),
    limit: int = Query(20, ge=1, le=50, description="Maximum number of exercises to return")
):
    """
    Search exercises by name from ExerciseDB with input sanitization and rate limits.
    """
    sanitized_query = _sanitize_search_term(query)
    data = await _fetch_from_rapidapi(
        f"/exercises/name/{sanitized_query}",
        params={"limit": limit}
    )
    return data if isinstance(data, list) else []


@router.get("/body-part/{bodyPart}", response_model=List[Dict[str, Any]])
async def get_exercises_by_body_part(
    bodyPart: str = Path(..., min_length=2, max_length=30, description="Target body part"),
    limit: int = Query(20, ge=1, le=50, description="Maximum number of exercises to return")
):
    """
    Fetch exercises for a specific body part (e.g. chest, back, upper arms, cardio).
    """
    clean_body_part = bodyPart.strip().lower()
    if clean_body_part not in VALID_BODY_PARTS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid body part. Allowed values: {', '.join(sorted(VALID_BODY_PARTS))}"
        )

    target_body_part = BODY_PART_ALIASES.get(clean_body_part, clean_body_part)

    if target_body_part == "all":
        data = await _fetch_from_rapidapi("/exercises", params={"limit": limit})
    else:
        data = await _fetch_from_rapidapi(f"/exercises/bodyPart/{target_body_part}", params={"limit": limit})

    return data if isinstance(data, list) else []


@router.get("/{exerciseId}", response_model=Dict[str, Any])
async def get_exercise_by_id(
    exerciseId: str = Path(..., pattern=r"^[a-zA-Z0-9_\-]+$", max_length=30, description="Exercise unique ID")
):
    """
    Fetch detailed information for a single exercise by ID.
    """
    data = await _fetch_from_rapidapi(f"/exercises/exercise/{exerciseId}")
    if not data:
        raise HTTPException(status_code=404, detail="Exercise not found.")
    return data
