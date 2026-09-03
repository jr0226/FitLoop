import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.malaysian_food_service import MalaysianFoodService, CONFIDENCE_THRESHOLD


class TestMalaysianFoodService(unittest.TestCase):

    def setUp(self):
        # Force re-initialization to load the latest SQLite database file
        MalaysianFoodService._initialized = False
        MalaysianFoodService.initialize()

    def test_malaysian_food_service_initialization(self):
        foods = MalaysianFoodService.get_all_foods()
        self.assertGreaterEqual(len(foods), 100)
        names = [f.name for f in foods]
        self.assertIn("Nasi Lemak", names)
        self.assertIn("Roti Canai", names)
        self.assertIn("Char Kuey Teow", names)
        self.assertIn("Bak Kut Teh", names)
        self.assertIn("Yong Tau Foo", names)
        self.assertIn("Cendol", names)
        self.assertIn("Ais Kacang", names)

    def test_exact_malaysian_food_match(self):
        # Exact English name match
        matched, score = MalaysianFoodService.find_match("Nasi Lemak")
        self.assertIsNotNone(matched)
        self.assertEqual(matched.name, "Nasi Lemak")
        self.assertEqual(score, 100.0)

        # Exact Malay name match
        matched_ms, score_ms = MalaysianFoodService.find_match("Nasi Ayam")
        self.assertIsNotNone(matched_ms)
        self.assertEqual(matched_ms.name, "Chicken Rice")
        self.assertEqual(score_ms, 100.0)

    def test_fuzzy_malaysian_food_match(self):
        # Punctuation & casing variation
        matched, score = MalaysianFoodService.find_match("roti canai!")
        self.assertIsNotNone(matched)
        self.assertEqual(matched.name, "Roti Canai")
        self.assertGreaterEqual(score, CONFIDENCE_THRESHOLD)

        # Complex meal name containing dish
        matched2, score2 = MalaysianFoodService.find_match("Authentic Penang Char Kuey Teow")
        self.assertIsNotNone(matched2)
        self.assertEqual(matched2.name, "Char Kuey Teow")
        self.assertGreaterEqual(score2, CONFIDENCE_THRESHOLD)

        # Malay variant
        matched3, score3 = MalaysianFoodService.find_match("Mee Goreng Mamak")
        self.assertIsNotNone(matched3)
        self.assertEqual(matched3.name, "Mee Goreng Mamak")
        self.assertGreaterEqual(score3, CONFIDENCE_THRESHOLD)

        # Newly added dishes
        matched4, score4 = MalaysianFoodService.find_match("Herbal Bak Kut Teh Soup")
        self.assertIsNotNone(matched4)
        self.assertEqual(matched4.name, "Bak Kut Teh")
        self.assertGreaterEqual(score4, CONFIDENCE_THRESHOLD)

        matched5, score5 = MalaysianFoodService.find_match("Fresh Popiah Basah Roll")
        self.assertIsNotNone(matched5)
        self.assertEqual(matched5.name, "Popiah Basah")
        self.assertGreaterEqual(score5, CONFIDENCE_THRESHOLD)

        matched6, score6 = MalaysianFoodService.find_match("Onde-Onde Buah Melaka")
        self.assertIsNotNone(matched6)
        self.assertEqual(matched6.name, "Onde-Onde")
        self.assertGreaterEqual(score6, CONFIDENCE_THRESHOLD)

        matched7, score7 = MalaysianFoodService.find_match("Milo Dinosaur Iced")
        self.assertIsNotNone(matched7)
        self.assertEqual(matched7.name, "Milo Dinosaur")
        self.assertGreaterEqual(score7, CONFIDENCE_THRESHOLD)

    def test_no_match_fallback(self):
        # Western / non-Malaysian dish
        matched, score = MalaysianFoodService.find_match("Italian Pepperoni Pizza")
        self.assertLess(score, CONFIDENCE_THRESHOLD)

        matched_salad, score_salad = MalaysianFoodService.find_match("Mediterranean Greek Salad")
        self.assertLess(score_salad, CONFIDENCE_THRESHOLD)

    def test_portion_scaling_calculation(self):
        matched, score = MalaysianFoodService.find_match("Roti Canai")
        self.assertIsNotNone(matched)

        # Roti Canai per 100g: 300 kcal, 7g P, 35g C, 15g F. Serving size: 95g.
        # Scaled nutrition: 300 * 0.95 = 285 kcal
        nutrition = MalaysianFoodService.calculate_nutrition_for_serving(matched)
        self.assertEqual(nutrition["calories"], 285)
        self.assertEqual(nutrition["protein"], 7)
        self.assertEqual(nutrition["carbs"], 33)
        self.assertEqual(nutrition["fat"], 14)
        self.assertEqual(nutrition["servingGrams"], 95.0)

        # Custom grams scaling (e.g. 2 pieces = 190g)
        custom_nutrition = MalaysianFoodService.calculate_nutrition_for_serving(matched, custom_grams=190.0)
        self.assertEqual(custom_nutrition["calories"], 570)
        self.assertEqual(custom_nutrition["servingGrams"], 190.0)

    def test_multi_food_meal_enrichment(self):
        # Simulated Gemini response for a mixed meal
        simulated_gemini = {
            "foods": [
                {"name": "Nasi Lemak", "calories": 400, "proteins": 8, "carbs": 50, "fats": 15},
                {"name": "Crispy Fried Chicken Breast", "calories": 250, "proteins": 30, "carbs": 5, "fats": 12},
                {"name": "Teh Tarik", "calories": 150, "proteins": 2, "carbs": 20, "fats": 4}
            ],
            "totalCalories": 800,
            "totalProteins": 40,
            "totalCarbs": 75,
            "totalFats": 31,
            "score": 70,
            "explanation": "High energy traditional meal.",
            "alternatives": ["Switch to Teh C Kosong to reduce sugar."]
        }

        enriched = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)

        self.assertEqual(len(enriched["foods"]), 3)
        # Nasi Lemak matched from DB (180 kcal/100g * 2.5 = 450 kcal)
        self.assertEqual(enriched["foods"][0]["nutritionSource"], "malaysian_db")
        self.assertEqual(enriched["foods"][0]["calories"], 450)
        self.assertEqual(enriched["foods"][0]["matchedFoodName"], "Nasi Lemak")

        # Fried chicken (not in DB) keeps Gemini estimates
        self.assertEqual(enriched["foods"][1]["nutritionSource"], "gemini_ai")
        self.assertEqual(enriched["foods"][1]["calories"], 250)

        # Teh Tarik matched from DB (83 kcal/100g * 2.4 = 199 kcal)
        self.assertEqual(enriched["foods"][2]["nutritionSource"], "malaysian_db")
        self.assertEqual(enriched["foods"][2]["calories"], 199)

        # Recomputed total calories (450 + 250 + 199 = 899)
        self.assertEqual(enriched["totalCalories"], 899)
        # Gemini reasoning preserved
        self.assertEqual(enriched["score"], 70)
        self.assertEqual(enriched["explanation"], "High energy traditional meal.")
        self.assertEqual(len(enriched["alternatives"]), 1)


if __name__ == "__main__":
    unittest.main()
