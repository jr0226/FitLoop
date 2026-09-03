import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import httpx
from main import app
from config import GEMINI_MODEL
from services.gemini_service import (
    build_food_analysis_prompt,
    build_workout_recommendation_prompt,
    build_faq_fallback_prompt,
    generate_faq_fallback,
    analyze_food_image,
    generate_workout_recommendations,
)
from google.genai import types


class TestGemini38Migration(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.transport = httpx.ASGITransport(app=app)
        self.client = httpx.AsyncClient(transport=self.transport, base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()

    def test_default_model_is_gemini_38_flash(self):
        self.assertEqual(GEMINI_MODEL, "gemini-3.8-flash")

    def test_faq_prompt_construction(self):
        prompt = build_faq_fallback_prompt("How do I connect Health Connect?", context="SettingsScreen")
        self.assertIn("FitLoop In-App Help & Support Assistant", prompt)
        self.assertIn("How do I connect Health Connect?", prompt)
        self.assertIn("SettingsScreen", prompt)
        self.assertIn("MEDICAL SAFETY GUARDRAILS", prompt)

    @patch("services.gemini_service.GEMINI_API_KEY", "test_key_123")
    @patch("services.gemini_service.genai.Client")
    async def test_food_analysis_uses_gemini_38_with_low_thinking(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.text = '{"foods": [{"name": "Roti Canai", "calories": 300, "proteins": 6, "carbs": 40, "fats": 12}], "totalCalories": 300, "totalProteins": 6, "totalCarbs": 40, "totalFats": 12, "score": 80, "explanation": "Rich in carbs", "alternatives": []}'
        mock_client.models.generate_content.return_value = mock_response

        result = await analyze_food_image(image_bytes=b"fake_jpeg")
        self.assertEqual(result["totalCalories"], 300)

        mock_client.models.generate_content.assert_called_once()
        call_kwargs = mock_client.models.generate_content.call_args.kwargs
        self.assertEqual(call_kwargs["model"], "gemini-3.8-flash")
        config = call_kwargs["config"]
        self.assertEqual(config.response_mime_type, "application/json")
        self.assertEqual(config.thinking_config.thinking_level, types.ThinkingLevel.LOW)

    @patch("services.gemini_service.GEMINI_API_KEY", "test_key_123")
    @patch("services.gemini_service.genai.Client")
    async def test_workout_generation_uses_gemini_38_with_medium_thinking(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.text = '[{"routineName": "Upper Power", "level": "Intermediate", "category": "Strength", "exercises": []}]'
        mock_client.models.generate_content.return_value = mock_response

        result = await generate_workout_recommendations(user_goal="Muscle Gain")
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["routineName"], "Upper Power")

        mock_client.models.generate_content.assert_called_once()
        call_kwargs = mock_client.models.generate_content.call_args.kwargs
        self.assertEqual(call_kwargs["model"], "gemini-3.8-flash")
        config = call_kwargs["config"]
        self.assertEqual(config.response_mime_type, "application/json")
        self.assertEqual(config.thinking_config.thinking_level, types.ThinkingLevel.MEDIUM)

    @patch("services.gemini_service.GEMINI_API_KEY", "test_key_123")
    @patch("services.gemini_service.genai.Client")
    async def test_faq_fallback_uses_gemini_38_with_low_thinking(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.text = '{"answer": "To sync your watch, navigate to Settings > Connected Health.", "suggestedActions": ["Open Settings"], "isMedicalNotice": false}'
        mock_client.models.generate_content.return_value = mock_response

        result = await generate_faq_fallback(question="How do I sync my smart watch?")
        self.assertIn("Settings > Connected Health", result["answer"])
        self.assertEqual(result["suggestedActions"], ["Open Settings"])

        mock_client.models.generate_content.assert_called_once()
        call_kwargs = mock_client.models.generate_content.call_args.kwargs
        self.assertEqual(call_kwargs["model"], "gemini-3.8-flash")
        config = call_kwargs["config"]
        self.assertEqual(config.response_mime_type, "application/json")
        self.assertEqual(config.thinking_config.thinking_level, types.ThinkingLevel.LOW)

    @patch("routers.faq.generate_faq_fallback")
    async def test_faq_endpoint_routing(self, mock_generate):
        mock_generate.return_value = {
            "answer": "FitLoop stores your food images locally on your device.",
            "suggestedActions": ["Check Privacy Policy"],
            "isMedicalNotice": False,
        }

        res = await self.client.post("/api/ai/faq-fallback", json={"question": "Where are my photos stored?"})
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("locally on your device", data["answer"])
