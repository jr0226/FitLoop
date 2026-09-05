import unittest
import sys
import os
from unittest.mock import patch, AsyncMock
from fastapi.testclient import TestClient

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from services.gemini_service import (
    build_food_recalculation_prompt,
    recalculate_food_nutrition,
)
from services.malaysian_food_service import MalaysianFoodService


class TestFoodCorrectionFlowBackend(unittest.IsolatedAsyncioTestCase):

    def setUp(self):
        MalaysianFoodService.initialize()
        self.client = TestClient(app)

    def test_build_food_recalculation_prompt_authoritative(self):
        prompt = build_food_recalculation_prompt(
            corrected_food_name="Fish Rice",
            previous_serving_grams=350,
            user_goal="Fat Loss",
            calorie_target=1800,
            diet_preference="Standard",
            allergies=["peanuts"],
        )

        self.assertIn("AUTHORITATIVE FOOD IDENTITY: The user has corrected the food identity to: 'Fish Rice'", prompt)
        self.assertIn("Treat the corrected food name 'Fish Rice' as absolute, authoritative truth", prompt)
        self.assertIn("Do NOT re-identify the food from scratch", prompt)
        self.assertIn("350g", prompt)
        self.assertIn("Fat Loss", prompt)
        self.assertIn("peanuts", prompt)

    @patch("services.gemini_service.GEMINI_API_KEY", "test_mock_gemini_key_12345")
    @patch("services.gemini_service._HAS_GENAI_SDK", False)
    @patch("services.gemini_service.httpx.AsyncClient")
    async def test_recalculate_food_nutrition_preserves_corrected_identity(self, mock_client_cls):
        # Simulated Gemini recalculation response for Fish Rice
        from unittest.mock import MagicMock
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "candidates": [{
                "content": {
                    "parts": [{
                        "text": '''{
                            "foods": [
                                {
                                    "name": "Grilled Fish Rice",
                                    "estimatedServingGrams": 300,
                                    "calories": 420,
                                    "proteins": 28,
                                    "carbs": 48,
                                    "fats": 10
                                }
                            ],
                            "totalCalories": 420,
                            "totalProteins": 28,
                            "totalCarbs": 48,
                            "totalFats": 10,
                            "score": 88,
                            "explanation": "High protein meal supporting fat loss.",
                            "alternatives": ["Brown rice option"]
                        }'''
                    }]
                }
            }]
        }

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response
        mock_client.__aenter__.return_value = mock_client
        mock_client_cls.return_value = mock_client

        result = await recalculate_food_nutrition(
            image_bytes=b"dummy_image_bytes",
            corrected_food_name="Fish Rice",
            previous_serving_grams=350,
            user_goal="Fat Loss",
            calorie_target=1800,
            diet_preference="Standard",
            allergies=[],
        )

        # CASE A & CASE B: Authoritative name is preserved as primary food name
        self.assertEqual(result["foods"][0]["name"], "Fish Rice")
        self.assertEqual(result["totalCalories"], 420)
        self.assertEqual(result["totalProteins"], 28)

    def test_recalculate_endpoint_success(self):
        # Test endpoint with mocked recalculate_food_nutrition
        mock_ai_result = {
            "foods": [
                {
                    "name": "Fish Rice",
                    "estimatedServingGrams": 320,
                    "calories": 430,
                    "proteins": 26,
                    "carbs": 50,
                    "fats": 11,
                }
            ],
            "totalCalories": 430,
            "totalProteins": 26,
            "totalCarbs": 50,
            "totalFats": 11,
            "score": 86,
            "explanation": "Nutritious meal with good lean protein.",
            "alternatives": ["Steamed fish alternative"],
            "dietCompatibility": "compatible",
            "dietNotice": None,
            "allergyNotice": None,
        }

        with patch("routers.food.recalculate_food_nutrition", new_callable=AsyncMock) as mock_fn:
            mock_fn.return_value = mock_ai_result

            response = self.client.post(
                "/api/ai/recalculate-food",
                files={"file": ("test.jpg", b"dummy_bytes", "image/jpeg")},
                data={
                    "corrected_food_name": "Fish Rice",
                    "previous_serving_grams": "300",
                    "user_goal": "Maintenance",
                    "diet_preference": "Standard",
                },
            )

            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["foods"][0]["name"], "Fish Rice")
            self.assertEqual(data["totalCalories"], 430)

    def test_case_c_vegan_incompatible_correction(self):
        # Vegan user corrects Chicken Rice to Fish Rice -> Still incompatible because fish is not vegan
        mock_ai_result = {
            "foods": [
                {
                    "name": "Fish Rice",
                    "estimatedServingGrams": 300,
                    "calories": 420,
                    "proteins": 28,
                    "carbs": 48,
                    "fats": 10,
                }
            ],
            "totalCalories": 420,
            "totalProteins": 28,
            "totalCarbs": 48,
            "totalFats": 10,
            "score": 80,
            "explanation": "High protein.",
            "alternatives": ["Stir-Fried Vegan Mee Hoon with Tofu and Bok Choy"],
            "dietCompatibility": "incompatible",
            "dietNotice": "This meal does not match your Vegan preference.",
            "allergyNotice": None,
        }

        with patch("routers.food.recalculate_food_nutrition", new_callable=AsyncMock) as mock_fn:
            mock_fn.return_value = mock_ai_result

            response = self.client.post(
                "/api/ai/recalculate-food",
                files={"file": ("test.jpg", b"dummy_bytes", "image/jpeg")},
                data={
                    "corrected_food_name": "Fish Rice",
                    "user_goal": "Maintenance",
                    "diet_preference": "Vegan",
                },
            )

            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["foods"][0]["name"], "Fish Rice")
            self.assertEqual(data["dietCompatibility"], "incompatible")
            self.assertIn("Vegan", data["dietNotice"])


if __name__ == "__main__":
    unittest.main()
