import logging
from typing import List, Any
import httpx
from fastapi import APIRouter, HTTPException, Query

from config import API_NINJAS_KEY

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Nutrition & Food Search"])


@router.get("/food", response_model=List[Any])
async def search_food(query: str = Query(..., min_length=1, description="Food item query")):
    """
    Proxies food nutrition searches to API Ninjas securely without exposing credentials to client applications.
    """
    if not API_NINJAS_KEY or API_NINJAS_KEY.strip() == "" or "your_api_ninjas_key" in API_NINJAS_KEY:
        logger.warning("API_NINJAS_KEY is not configured on the backend server.")
        return []

    url = f"https://api-ninjas.com/api/food?query={httpx.URL(query).raw_path.decode('utf-8') if hasattr(httpx.URL(query), 'raw_path') else query}"
    # Alternative direct endpoint
    url = f"https://api.api-ninjas.com/v1/nutrition?query={query}"
    headers = {
        "X-Api-Key": API_NINJAS_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.get(url, headers=headers)
            if res.status_code == 200:
                data = res.json()
                if isinstance(data, list):
                    return data
                return data.get("data", data.get("results", data.get("items", [])))
            else:
                logger.error(f"API-Ninjas error ({res.status_code}): {res.text}")
                raise HTTPException(status_code=res.status_code, detail="Failed to fetch food data from nutrition API.")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Food nutrition search timed out.")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Food search error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal nutrition search error: {str(e)}")
