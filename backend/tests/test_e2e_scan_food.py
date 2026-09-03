import unittest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.malaysian_food_service import MalaysianFoodService, CONFIDENCE_THRESHOLD


class TestE2EScanFoodValidation(unittest.TestCase):

    def setUp(self):
        MalaysianFoodService.initialize()

    def test_case_1_nasi_lemak(self):
        # 1. Nasi Lemak
        simulated_gemini = {
            "foods": [{"name": "Nasi Lemak", "calories": 400, "proteins": 8, "carbs": 50, "fats": 15}],
            "totalCalories": 400, "totalProteins": 8, "totalCarbs": 50, "totalFats": 15,
            "score": 80, "explanation": "Rich in energy.", "alternatives": ["Ask for less santan."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Nasi Lemak")
        self.assertEqual(item["matchScore"], 100.0)
        self.assertEqual(item["calories"], 450)  # 180 kcal/100g * 2.5
        self.assertEqual(item["proteins"], 10)
        self.assertEqual(item["carbs"], 62)     # round(25.0 * 2.5) = 62 or 63
        self.assertEqual(item["fats"], 20)
        self.assertEqual(res["totalCalories"], 450)

    def test_case_2_roti_canai(self):
        # 2. Roti Canai
        simulated_gemini = {
            "foods": [{"name": "Roti Canai with Dhal", "calories": 300, "proteins": 6, "carbs": 40, "fats": 12}],
            "totalCalories": 300, "totalProteins": 6, "totalCarbs": 40, "totalFats": 12,
            "score": 65, "explanation": "High in carbohydrates.", "alternatives": ["Opt for Capati."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Roti Canai")
        self.assertGreaterEqual(item["matchScore"], 85.0)
        self.assertEqual(item["calories"], 285)  # 300 kcal/100g * 0.95 = 285
        self.assertEqual(item["proteins"], 7)
        self.assertEqual(item["carbs"], 33)
        self.assertEqual(item["fats"], 14)
        self.assertEqual(res["totalCalories"], 285)

    def test_case_3_chicken_rice(self):
        # 3. Chicken Rice / Nasi Ayam
        simulated_gemini = {
            "foods": [{"name": "Hainanese Chicken Rice", "calories": 500, "proteins": 25, "carbs": 60, "fats": 14}],
            "totalCalories": 500, "totalProteins": 25, "totalCarbs": 60, "totalFats": 14,
            "score": 85, "explanation": "Good protein balance.", "alternatives": ["Choose steamed chicken."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Chicken Rice")
        self.assertGreaterEqual(item["matchScore"], 85.0)
        self.assertEqual(item["calories"], 532)  # 190 kcal/100g * 2.8 = 532
        self.assertEqual(item["proteins"], 28)
        self.assertEqual(item["carbs"], 67)
        self.assertEqual(item["fats"], 17)
        self.assertEqual(res["totalCalories"], 532)

    def test_case_4_char_kuey_teow(self):
        # 4. Char Kuey Teow
        simulated_gemini = {
            "foods": [{"name": "Penang Char Kuey Teow with Prawns", "calories": 600, "proteins": 18, "carbs": 70, "fats": 22}],
            "totalCalories": 600, "totalProteins": 18, "totalCarbs": 70, "totalFats": 22,
            "score": 60, "explanation": "High calorie hawker dish.", "alternatives": ["Ask for less oil."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Char Kuey Teow")
        self.assertGreaterEqual(item["matchScore"], 85.0)
        self.assertEqual(item["calories"], 660)  # 220 kcal/100g * 3.0 = 660
        self.assertEqual(item["proteins"], 24)
        self.assertEqual(item["carbs"], 84)
        self.assertEqual(item["fats"], 27)
        self.assertEqual(res["totalCalories"], 660)

    def test_case_5_mee_goreng_mamak(self):
        # 5. Mee Goreng Mamak
        simulated_gemini = {
            "foods": [{"name": "Mee Goreng Mamak", "calories": 550, "proteins": 15, "carbs": 75, "fats": 18}],
            "totalCalories": 550, "totalProteins": 15, "totalCarbs": 75, "totalFats": 18,
            "score": 65, "explanation": "Popular stir-fried yellow noodles.", "alternatives": ["Add extra taugeh."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Mee Goreng Mamak")
        self.assertEqual(item["matchScore"], 100.0)
        self.assertEqual(item["calories"], 630)  # 210 kcal/100g * 3.0 = 630
        self.assertEqual(item["proteins"], 21)
        self.assertEqual(item["carbs"], 90)
        self.assertEqual(item["fats"], 24)
        self.assertEqual(res["totalCalories"], 630)

    def test_case_6_curry_laksa(self):
        # 6. Curry Laksa
        simulated_gemini = {
            "foods": [{"name": "Curry Laksa Bowl", "calories": 500, "proteins": 16, "carbs": 55, "fats": 20}],
            "totalCalories": 500, "totalProteins": 16, "totalCarbs": 55, "totalFats": 20,
            "score": 70, "explanation": "Noodle soup in coconut curry broth.", "alternatives": ["Drink less broth."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Curry Laksa")
        self.assertGreaterEqual(item["matchScore"], 85.0)
        self.assertEqual(item["calories"], 560)  # 160 kcal/100g * 3.5 = 560
        self.assertEqual(item["proteins"], 21)
        self.assertEqual(item["carbs"], 63)
        self.assertEqual(item["fats"], 24)
        self.assertEqual(res["totalCalories"], 560)

    def test_case_7_teh_tarik(self):
        # 7. Teh Tarik
        simulated_gemini = {
            "foods": [{"name": "Teh Tarik", "calories": 180, "proteins": 3, "carbs": 25, "fats": 5}],
            "totalCalories": 180, "totalProteins": 3, "totalCarbs": 25, "totalFats": 5,
            "score": 50, "explanation": "Pulled tea with condensed milk.", "alternatives": ["Order Teh C Kosong."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Teh Tarik")
        self.assertEqual(item["matchScore"], 100.0)
        self.assertEqual(item["calories"], 199)  # 83 kcal/100g * 2.4 = 199.2 -> 199
        self.assertEqual(item["sugar"], 26.4)
        self.assertEqual(res["totalCalories"], 199)

    def test_case_8_satay_ayam(self):
        # 8. Satay Ayam
        simulated_gemini = {
            "foods": [{"name": "Chicken Satay Skewers", "calories": 300, "proteins": 22, "carbs": 10, "fats": 15}],
            "totalCalories": 300, "totalProteins": 22, "totalCarbs": 10, "totalFats": 15,
            "score": 85, "explanation": "Grilled marinated chicken skewers.", "alternatives": ["Moderate peanut sauce."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        self.assertEqual(item["nutritionSource"], "malaysian_db")
        self.assertEqual(item["matchedFoodName"], "Satay Ayam")
        self.assertGreaterEqual(item["matchScore"], 85.0)
        self.assertEqual(item["calories"], 322)  # 215 kcal/100g * 1.5 = 322.5 -> 322/323
        self.assertEqual(item["proteins"], 27)
        self.assertEqual(res["totalCalories"], 322)

    def test_case_9_non_malaysian_food_pizza(self):
        # 9. Non-Malaysian food (Pepperoni Pizza)
        simulated_gemini = {
            "foods": [{"name": "Pepperoni Pizza Slice", "calories": 290, "proteins": 12, "carbs": 32, "fats": 12}],
            "totalCalories": 290, "totalProteins": 12, "totalCarbs": 32, "totalFats": 12,
            "score": 55, "explanation": "Processed meat on baked dough.", "alternatives": ["Add a side salad."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)
        item = res["foods"][0]

        # Should NOT match Malaysian DB and keep Gemini AI estimates
        self.assertEqual(item["nutritionSource"], "gemini_ai")
        self.assertLess(item["matchScore"], CONFIDENCE_THRESHOLD)
        self.assertEqual(item["calories"], 290)
        self.assertEqual(item["proteins"], 12)
        self.assertEqual(item["carbs"], 32)
        self.assertEqual(item["fats"], 12)
        self.assertEqual(res["totalCalories"], 290)

    def test_case_10_mixed_plate(self):
        # 10. Mixed Plate (Nasi Lemak + Fried Chicken Breast + Cucumber Slices)
        simulated_gemini = {
            "foods": [
                {"name": "Nasi Lemak", "calories": 400, "proteins": 8, "carbs": 50, "fats": 15},
                {"name": "Crispy Fried Chicken Breast", "calories": 250, "proteins": 28, "carbs": 4, "fats": 12},
                {"name": "Fresh Cucumber Slices", "calories": 15, "proteins": 1, "carbs": 3, "fats": 0}
            ],
            "totalCalories": 665, "totalProteins": 37, "totalCarbs": 57, "totalFats": 27,
            "score": 75, "explanation": "Classic complete Malaysian lunch.",
            "alternatives": ["Eat all fresh cucumber slices for hydration."]
        }
        res = MalaysianFoodService.enrich_gemini_analysis(simulated_gemini)

        self.assertEqual(len(res["foods"]), 3)
        # 1st item (Nasi Lemak) -> Matched Malaysian DB
        self.assertEqual(res["foods"][0]["nutritionSource"], "malaysian_db")
        self.assertEqual(res["foods"][0]["calories"], 450)

        # 2nd item (Fried Chicken Breast) -> Gemini AI estimate
        self.assertEqual(res["foods"][1]["nutritionSource"], "gemini_ai")
        self.assertEqual(res["foods"][1]["calories"], 250)

        # 3rd item (Cucumber Slices) -> Gemini AI estimate
        self.assertEqual(res["foods"][2]["nutritionSource"], "gemini_ai")
        self.assertEqual(res["foods"][2]["calories"], 15)

        # Sum Check: 450 + 250 + 15 = 715 kcal
        self.assertEqual(res["totalCalories"], 715)
        self.assertEqual(res["totalProteins"], 10 + 28 + 1)
        self.assertEqual(res["totalCarbs"], 62 + 4 + 3)
        self.assertEqual(res["totalFats"], 20 + 12 + 0)

        # Gemini reasoning preserved
        self.assertEqual(res["score"], 75)
        self.assertEqual(res["explanation"], "Classic complete Malaysian lunch.")
        self.assertEqual(len(res["alternatives"]), 1)


if __name__ == "__main__":
    unittest.main()
