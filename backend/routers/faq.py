from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

from services.gemini_service import generate_faq_fallback

router = APIRouter(prefix="/api/ai", tags=["FAQ Chatbot AI"])


class FaqFallbackRequest(BaseModel):
    question: str = Field(..., min_length=1, description="The user's query or help question")
    context: Optional[str] = Field(None, description="Optional user app context or screen location")


@router.post("/faq-fallback", response_model=Dict[str, Any])
async def faq_fallback_endpoint(request: FaqFallbackRequest):
    """
    Provides an intelligent AI fallback for user help/FAQ questions using Gemini 3.8 Flash
    when local keyword/FAQ matches are unavailable.
    """
    result = await generate_faq_fallback(
        question=request.question,
        context=request.context,
    )
    return result
