import unittest
from unittest.mock import patch, MagicMock
from services.gemini_service import generate_workout_recommendations

class TestWorkoutCategoryEnforcement(unittest.IsolatedAsyncioTestCase):
    @patch("services.gemini_service.GEMINI_API_KEY", "test_mock_key")
    @patch("services.gemini_service.genai.Client")
    async def test_cardio_generation_replaces_hallucinated_resistance_exercises(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_response = MagicMock()
        # Simulate Gemini returning resistance exercises for Cardio (the exact reported bug!)
        mock_response.text = '''[
            {
                "name": "Cardio Blast",
                "category": "Cardio",
                "level": "Beginner",
                "exercises": [
                    {"name": "Incline Push-Ups", "category": "Chest", "sets": "3 sets x 10 reps"},
                    {"name": "One-Arm Dumbbell Row", "category": "Back", "sets": "3 sets x 10 reps"},
                    {"name": "Dumbbell Shoulder Press", "category": "Shoulders", "sets": "3 sets x 10 reps"}
                ]
            }
        ]'''
        mock_client.models.generate_content.return_value = mock_response

        routines = await generate_workout_recommendations(
            user_goal="Muscle Gain",
            difficulty="Beginner",
            equipment=["Bodyweight"],
            target_category="Cardio"
        )

        self.assertEqual(len(routines), 1)
        r = routines[0]
        self.assertEqual(r["category"], "Cardio")
        exercises = r["exercises"]
        self.assertGreaterEqual(len(exercises), 3)

        # Confirm ZERO resistance exercises remained!
        for ex in exercises:
            name = ex["name"].lower()
            self.assertNotIn("push-up", name)
            self.assertNotIn("row", name)
            self.assertNotIn("press", name)
            self.assertNotIn("curl", name)
            self.assertNotIn("squat", name)
            self.assertEqual(ex.get("equipment"), "Bodyweight")

    @patch("services.gemini_service.GEMINI_API_KEY", "test_mock_key")
    @patch("services.gemini_service.genai.Client")
    async def test_core_generation_enforces_core_exercises(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client_cls.return_value = mock_client
        mock_response = MagicMock()
        mock_response.text = '''[
            {
                "name": "Core Burner",
                "category": "Core",
                "level": "Intermediate",
                "exercises": [
                    {"name": "Barbell Bench Press", "category": "Chest", "sets": "3 sets x 10 reps"},
                    {"name": "Forearm Plank", "category": "Core", "sets": "3 sets x 45s"},
                    {"name": "Bicep Curls", "category": "Arms", "sets": "3 sets x 12 reps"}
                ]
            }
        ]'''
        mock_client.models.generate_content.return_value = mock_response

        routines = await generate_workout_recommendations(
            user_goal="Maintenance",
            difficulty="Intermediate",
            equipment=["Bodyweight"],
            target_category="Core"
        )

        r = routines[0]
        self.assertEqual(r["category"], "Core")
        exercises = r["exercises"]
        for ex in exercises:
            name = ex["name"].lower()
            self.assertNotIn("bench press", name)
            self.assertNotIn("bicep", name)

if __name__ == "__main__":
    unittest.main()
