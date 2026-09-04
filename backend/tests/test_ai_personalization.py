import os
import sys
import unittest
from unittest.mock import patch, AsyncMock
import httpx

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from services.gemini_service import (
    build_food_analysis_prompt,
    build_workout_recommendation_prompt,
)


class TestAIPersonalization(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.transport = httpx.ASGITransport(app=app)
        self.client = httpx.AsyncClient(transport=self.transport, base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()

    # ==========================================
    # FOOD AI PERSONALIZATION PROMPT TESTS
    # ==========================================

    def test_food_prompt_muscle_gain_standard_diet(self):
        prompt = build_food_analysis_prompt(
            user_goal="Muscle Gain",
            calorie_target=2500,
            diet_preference="Standard",
            allergies=[],
        )
        self.assertIn("Muscle Gain", prompt)
        self.assertIn("2500 kcal", prompt)
        self.assertIn("Dietary Preference: Standard", prompt)
        self.assertIn("None reported", prompt)
        self.assertIn("Evaluate nutritional balance and macro ratios specifically against the user's 'Muscle Gain' goal", prompt)

    def test_food_prompt_vegetarian(self):
        prompt = build_food_analysis_prompt(
            user_goal="Weight Loss",
            calorie_target=1800,
            diet_preference="Vegetarian",
            allergies=[],
        )
        self.assertIn("Vegetarian", prompt)
        self.assertIn("NEVER recommend alternatives containing ingredients prohibited under this diet", prompt)
        self.assertIn("no meat/poultry for vegetarians", prompt)

    def test_food_prompt_vegan(self):
        prompt = build_food_analysis_prompt(
            user_goal="Maintenance",
            calorie_target=2000,
            diet_preference="Vegan",
            allergies=[],
        )
        self.assertIn("Vegan", prompt)
        self.assertIn("no animal products for vegans", prompt)

    def test_food_prompt_peanut_and_shellfish_allergies(self):
        prompt = build_food_analysis_prompt(
            user_goal="Muscle Gain",
            calorie_target=2400,
            diet_preference="Standard",
            allergies=["Peanuts", "Shellfish"],
        )
        self.assertIn("Peanuts, Shellfish", prompt)
        self.assertIn("STRICTLY DO NOT suggest any meals, foods, or healthier alternatives containing these allergens", prompt)
        # Verify allergy safety disclaimer
        self.assertIn("Never claim a food in the image is 100% guaranteed allergen-safe based solely on visual inspection", prompt)

    def test_food_prompt_missing_preference_fields_defaults(self):
        prompt = build_food_analysis_prompt(
            user_goal=None,  # type: ignore
            calorie_target=None,
            diet_preference=None,  # type: ignore
            allergies=None,
        )
        self.assertIn("Fitness Goal: Maintenance", prompt)
        self.assertIn("Dietary Preference: Standard", prompt)
        self.assertIn("Allergies & Intolerances: None reported", prompt)
        self.assertNotIn("Daily Calorie Target:", prompt)

    # ==========================================
    # WORKOUT AI PERSONALIZATION PROMPT TESTS
    # ==========================================

    def test_workout_prompt_beginner_bodyweight(self):
        prompt = build_workout_recommendation_prompt(
            user_goal="Weight Loss",
            difficulty="Beginner",
            equipment=["None / Bodyweight"],
            preferred_workout_types=["Full Body"],
            recent_workouts_summary="Recent 7 days: Full Body: 1 session",
        )
        self.assertIn("Fitness Goal: Weight Loss", prompt)
        self.assertIn("Experience / Fitness Level: Beginner", prompt)
        self.assertIn("Bodyweight only (No gym equipment)", prompt)
        self.assertIn("Prescribe ONLY bodyweight/calisthenics exercises", prompt)
        self.assertIn("FITNESS LEVEL SCALING (Beginner)", prompt)
        self.assertIn("Preferred Workout Styles: Full Body", prompt)
        self.assertIn("Recent Training History: Recent 7 days: Full Body: 1 session", prompt)

    def test_workout_prompt_intermediate_dumbbells_and_bench(self):
        prompt = build_workout_recommendation_prompt(
            user_goal="Muscle Gain",
            difficulty="Intermediate",
            equipment=["Dumbbells", "Bench"],
            preferred_workout_types=["Strength", "Upper Body"],
        )
        self.assertIn("Available Equipment: Dumbbells, Bench", prompt)
        self.assertIn("STRICT EQUIPMENT CONSTRAINT: The user ONLY has access to: Dumbbells, Bench and bodyweight", prompt)
        self.assertIn("DO NOT recommend any exercises requiring equipment outside this list", prompt)
        self.assertIn("FITNESS LEVEL SCALING (Intermediate)", prompt)
        self.assertIn("Strength, Upper Body", prompt)

    def test_workout_prompt_advanced_gym_equipment(self):
        prompt = build_workout_recommendation_prompt(
            user_goal="Strength",
            difficulty="Advanced",
            equipment=["Barbell", "Bench", "Cable Machine", "Gym Machines"],
            preferred_workout_types=["Strength"],
        )
        self.assertIn("Barbell, Bench, Cable Machine, Gym Machines", prompt)
        self.assertIn("FITNESS LEVEL SCALING (Advanced)", prompt)
        self.assertIn("progressive overload intensity", prompt)

    def test_workout_prompt_hiit_preference(self):
        prompt = build_workout_recommendation_prompt(
            user_goal="Weight Loss",
            difficulty="Intermediate",
            equipment=["Dumbbells", "Kettlebell"],
            preferred_workout_types=["HIIT", "Cardio"],
        )
        self.assertIn("HIIT, Cardio", prompt)
        self.assertIn("Bias routine themes towards the user's preferred styles (HIIT, Cardio)", prompt)

    def test_workout_prompt_missing_preference_fields_defaults(self):
        prompt = build_workout_recommendation_prompt(
            user_goal=None,  # type: ignore
            difficulty=None,  # type: ignore
            equipment=None,
            preferred_workout_types=None,
            recent_workouts_summary=None,
        )
        self.assertIn("Fitness Goal: Maintenance", prompt)
        self.assertIn("Experience / Fitness Level: Intermediate", prompt)
        self.assertIn("Bodyweight only (No gym equipment)", prompt)
        self.assertNotIn("Preferred Workout Styles:", prompt)
        self.assertNotIn("Recent Training History:", prompt)

    # ==========================================
    # API ENDPOINT BEHAVIOR & BACKWARD COMPATIBILITY
    # ==========================================

    @patch("routers.food.analyze_food_image")
    async def test_food_analyze_endpoint_with_all_context(self, mock_analyze):
        mock_analyze.return_value = {
            "foods": [{"name": "Tofu Salad", "calories": 250, "proteins": 15, "carbs": 10, "fats": 8}],
            "totalCalories": 250,
            "totalProteins": 15,
            "totalCarbs": 10,
            "totalFats": 8,
            "score": 90,
            "explanation": "Great vegetarian option with high protein.",
            "alternatives": ["Quinoa Bowl", "Edamame Salad"],
        }

        fake_img = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 20
        response = await self.client.post(
            "/api/ai/analyze-food",
            data={
                "user_goal": "Weight Loss",
                "calorie_target": 1800,
                "diet_preference": "Vegetarian",
                "allergies": '["Peanuts"]',
            },
            files={"file": ("meal.jpg", fake_img, "image/jpeg")},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["totalCalories"], 250)
        self.assertEqual(data["score"], 90)

        # Check that analyze_food_image was called with the parsed arguments
        mock_analyze.assert_called_once()
        kwargs = mock_analyze.call_args.kwargs
        self.assertEqual(kwargs["user_goal"], "Weight Loss")
        self.assertEqual(kwargs["calorie_target"], 1800)
        self.assertEqual(kwargs["diet_preference"], "Vegetarian")
        self.assertEqual(kwargs["allergies"], ["Peanuts"])

    @patch("routers.workout.generate_workout_recommendations")
    async def test_workout_recommend_endpoint_with_all_context(self, mock_generate):
        mock_generate.return_value = [
            {
                "routineName": "Dumbbell Upper Body",
                "level": "Intermediate",
                "category": "Upper Body",
                "image": "https://example.com/img.jpg",
                "exercises": [
                    {
                        "name": "Dumbbell Bench Press",
                        "category": "Chest",
                        "sets": "3 sets x 10 reps",
                        "image": "https://example.com/ex.jpg",
                        "desc": "Press dumbbells up.",
                    }
                ],
            }
        ]

        payload = {
            "userGoal": "Muscle Gain",
            "difficulty": "Intermediate",
            "equipment": ["Dumbbells", "Bench"],
            "preferredWorkoutTypes": ["Strength", "Upper Body"],
            "recentWorkoutsSummary": "Recent 7 days: Chest: 1 session, Back: 2 sessions",
        }
        response = await self.client.post("/api/workout/recommend", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIsInstance(data, list)
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["routineName"], "Dumbbell Upper Body")

        mock_generate.assert_called_once_with(
            user_goal="Muscle Gain",
            difficulty="Intermediate",
            equipment=["Dumbbells", "Bench"],
            preferred_workout_types=["Strength", "Upper Body"],
            recent_workouts_summary="Recent 7 days: Chest: 1 session, Back: 2 sessions",
        )

    @patch("routers.workout.generate_workout_recommendations")
    async def test_workout_recommend_endpoint_legacy_payload_backward_compatibility(self, mock_generate):
        mock_generate.return_value = [
            {
                "routineName": "Bodyweight Full Body",
                "level": "Beginner",
                "category": "Full Body",
                "image": "https://example.com/img.jpg",
                "exercises": [],
            }
        ]

        # Old client payload without any new fields
        payload = {
            "userGoal": "Weight Loss",
            "difficulty": "Beginner",
        }
        response = await self.client.post("/api/ai/generate-workout", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)

        mock_generate.assert_called_once_with(
            user_goal="Weight Loss",
            difficulty="Beginner",
            equipment=[],
            preferred_workout_types=[],
            recent_workouts_summary=None,
        )

    @patch("routers.workout.generate_workout_recommendations")
    async def test_workout_recommend_endpoint_with_target_category(self, mock_generate):
        mock_generate.return_value = [
            {
                "routineName": "Core Stability Essentials",
                "level": "Beginner",
                "category": "Core",
                "image": "https://example.com/img.jpg",
                "exercises": [{"name": "Plank", "category": "Core", "sets": "3 sets x 30s"}],
            }
        ]

        payload = {
            "userGoal": "Muscle Gain",
            "difficulty": "Beginner",
            "category": "Core",
        }
        response = await self.client.post("/api/ai/generate-workout", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data[0]["category"], "Core")

        mock_generate.assert_called_once_with(
            user_goal="Muscle Gain",
            difficulty="Beginner",
            equipment=[],
            preferred_workout_types=[],
            recent_workouts_summary=None,
            target_category="Core",
        )

    def test_workout_prompt_explicit_target_category_mandate(self):
        for cat in ["Cardio", "Core", "Full Body"]:
            prompt = build_workout_recommendation_prompt(
                user_goal="Muscle Gain",
                difficulty="Beginner",
                target_category=cat,
            )
            self.assertIn(f"EXPLICIT TARGET CATEGORY: {cat}", prompt)
            self.assertIn(f"EXPLICIT CATEGORY MANDATE: The user explicitly requested a '{cat}' workout", prompt)
            self.assertIn(f'BOTH generated routines MUST belong to the \'{cat}\' category and have "category": "{cat}"', prompt)

    def test_profile_a_bodyweight_equipment_repair(self):
        from services.gemini_service import _is_equipment_compatible, _repair_exercise_equipment

        # Barbell Bench Press is incompatible with bodyweight-only
        self.assertFalse(_is_equipment_compatible("Barbell", "Barbell Bench Press", []))
        repaired = _repair_exercise_equipment({"name": "Barbell Bench Press", "equipment": "Barbell", "category": "Chest"}, [])
        self.assertEqual(repaired["name"], "Standard Push-Ups")
        self.assertEqual(repaired["equipment"], "Bodyweight")

        # Cable Crossover is incompatible with bodyweight-only
        self.assertFalse(_is_equipment_compatible("Cable", "Cable Crossover", ["Bodyweight"]))
        repaired_cable = _repair_exercise_equipment({"name": "Cable Crossover", "equipment": "Cable", "category": "Chest"}, ["Bodyweight"])
        self.assertEqual(repaired_cable["equipment"], "Bodyweight")

    def test_profile_b_dumbbells_equipment_repair(self):
        from services.gemini_service import _is_equipment_compatible, _repair_exercise_equipment

        allowed = ["Dumbbells", "Bench"]
        # Dumbbell Bench Press is compatible
        self.assertTrue(_is_equipment_compatible("Dumbbells", "Dumbbell Bench Press", allowed))

        # Barbell Squat is incompatible, repairs to Dumbbell Goblet Squat
        self.assertFalse(_is_equipment_compatible("Barbell", "Barbell Back Squat", allowed))
        repaired_squat = _repair_exercise_equipment({"name": "Barbell Back Squat", "equipment": "Barbell", "category": "Legs"}, allowed)
        self.assertEqual(repaired_squat["name"], "Dumbbell Goblet Squat")
        self.assertEqual(repaired_squat["equipment"], "Dumbbells")

        # Cable Lat Pulldown is incompatible, repairs to Dumbbell Bent-Over Row
        self.assertFalse(_is_equipment_compatible("Cable", "Cable Lat Pulldown", allowed))
        repaired_pull = _repair_exercise_equipment({"name": "Cable Lat Pulldown", "equipment": "Cable", "category": "Back"}, allowed)
        self.assertEqual(repaired_pull["name"], "Dumbbell Bent-Over Row")
        self.assertEqual(repaired_pull["equipment"], "Dumbbells")

    def test_profile_c_full_gym_compatibility(self):
        from services.gemini_service import _is_equipment_compatible

        allowed = ["Full Gym"]
        self.assertTrue(_is_equipment_compatible("Barbell", "Barbell Bench Press", allowed))
        self.assertTrue(_is_equipment_compatible("Cable", "Cable Tricep Pushdown", allowed))
        self.assertTrue(_is_equipment_compatible("Machine", "Leg Press Machine", allowed))


if __name__ == "__main__":
    unittest.main()

