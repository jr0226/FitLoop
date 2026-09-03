import pytest
from services.malaysian_food_service import MalaysianFoodService
from services.gemini_service import build_food_analysis_prompt

@pytest.fixture(autouse=True)
def setup_db():
    MalaysianFoodService._initialized = False
    MalaysianFoodService._foods = []
    MalaysianFoodService.initialize()

class TestFoodNameNormalizationAndAliases:
    def test_chicken_rice_variations(self):
        variations = [
            "Chicken Rice",
            "Hainanese Chicken Rice",
            "Nasi Ayam",
            "Steamed Chicken Rice",
            "Roasted Chicken Rice",
            "Chicken Rice (1 plate)",
        ]
        for v in variations:
            match, score = MalaysianFoodService.find_match(v)
            assert match is not None, f"Failed to match variation: {v}"
            assert match.name == "Chicken Rice", f"Expected 'Chicken Rice' for '{v}', got '{match.name}'"
            assert score >= 85.0

    def test_satay_variations(self):
        variations = [
            "Satay Ayam",
            "Chicken Satay",
            "Chicken Satay Skewers",
            "Sate Ayam",
        ]
        for v in variations:
            match, score = MalaysianFoodService.find_match(v)
            assert match is not None, f"Failed to match: {v}"
            assert match.name == "Satay Ayam", f"Expected 'Satay Ayam' for '{v}', got '{match.name}'"
            assert score >= 85.0

    def test_char_kuey_teow_variations(self):
        variations = [
            "Char Kuey Teow",
            "Char Kway Teow",
            "Penang Char Kway Teow",
        ]
        for v in variations:
            match, score = MalaysianFoodService.find_match(v)
            assert match is not None, f"Failed to match: {v}"
            assert match.name == "Char Kuey Teow", f"Expected 'Char Kuey Teow' for '{v}', got '{match.name}'"
            assert score >= 85.0

    def test_french_fries_variations(self):
        variations = [
            "French Fries",
            "Fries",
            "McDonald's French Fries",
            "McDonald's French Fries (Large)",
            "McDonalds French Fries",
        ]
        for v in variations:
            match, score = MalaysianFoodService.find_match(v)
            assert match is not None, f"Failed to match: {v}"
            assert match.name == "French Fries", f"Expected 'French Fries' for '{v}', got '{match.name}'"
            assert score >= 85.0

    def test_roti_canai_variations(self):
        variations = [
            "Roti Canai",
            "Roti Prata",
        ]
        for v in variations:
            match, score = MalaysianFoodService.find_match(v)
            assert match is not None, f"Failed to match: {v}"
            assert match.name == "Roti Canai", f"Expected 'Roti Canai' for '{v}', got '{match.name}'"
            assert score >= 85.0


class TestPortionEstimationStability:
    def test_standard_portion_fallback_when_missing(self):
        gemini_result = {
            "foods": [
                {"name": "Nasi Lemak", "calories": 500, "proteins": 15, "carbs": 60, "fats": 20}
            ],
            "totalCalories": 500,
            "totalProteins": 15,
            "totalCarbs": 60,
            "totalFats": 20,
            "score": 80,
            "explanation": "Balanced meal.",
            "alternatives": []
        }
        enriched = MalaysianFoodService.enrich_gemini_analysis(gemini_result)
        item = enriched["foods"][0]
        assert item["nutritionSource"] == "malaysian_db"
        assert item["servingGrams"] == 250.0  # Standard Nasi Lemak serving
        assert item["calories"] == 450  # 180 kcal/100g * 2.5 = 450 kcal

    def test_credible_portion_scaling(self):
        # AI reports 300g (within 0.5x - 2.5x of 250g)
        gemini_result = {
            "foods": [
                {"name": "Nasi Lemak", "estimatedServingGrams": 300, "calories": 550, "proteins": 18, "carbs": 70, "fats": 22}
            ],
            "totalCalories": 550,
            "totalProteins": 18,
            "totalCarbs": 70,
            "totalFats": 22,
            "score": 80,
        }
        enriched = MalaysianFoodService.enrich_gemini_analysis(gemini_result)
        item = enriched["foods"][0]
        assert item["servingGrams"] == 300.0
        # 180 kcal/100g * 3.0 = 540 kcal
        assert item["calories"] == 540

    def test_unrealistic_portion_reverts_to_standard(self):
        # AI reports 15g (absurdly small, < 0.5x of 250g)
        gemini_result = {
            "foods": [
                {"name": "Nasi Lemak", "estimatedServingGrams": 15, "calories": 30, "proteins": 1, "carbs": 5, "fats": 1}
            ],
            "totalCalories": 30,
        }
        enriched = MalaysianFoodService.enrich_gemini_analysis(gemini_result)
        item = enriched["foods"][0]
        assert item["servingGrams"] == 250.0  # Reverts safely to standard 250g
        assert item["calories"] == 450


class TestSameImageRepeatability:
    def test_enrichment_deterministic_five_iterations(self):
        """Simulates 5 identical runs of the same image detection result."""
        input_data = {
            "foods": [
                {"name": "McDonald's French Fries (Large)", "estimatedServingGrams": 150, "calories": 450, "proteins": 5, "carbs": 60, "fats": 22},
                {"name": "Hainanese Chicken Rice", "estimatedServingGrams": 280, "calories": 520, "proteins": 28, "carbs": 65, "fats": 17},
            ],
            "totalCalories": 970,
            "totalProteins": 33,
            "totalCarbs": 125,
            "totalFats": 39,
            "score": 78,
            "explanation": "Combination of chicken rice and fries.",
            "alternatives": ["Choose grilled chicken without skin", "Opt for side salad instead of fries"]
        }

        results = [MalaysianFoodService.enrich_gemini_analysis(input_data) for _ in range(5)]

        # Verify all 5 runs are 100% identical
        for i in range(1, 5):
            assert results[i]["totalCalories"] == results[0]["totalCalories"]
            assert results[i]["totalProteins"] == results[0]["totalProteins"]
            assert results[i]["totalCarbs"] == results[0]["totalCarbs"]
            assert results[i]["totalFats"] == results[0]["totalFats"]
            assert len(results[i]["foods"]) == len(results[0]["foods"])
            for f_idx in range(len(results[0]["foods"])):
                assert results[i]["foods"][f_idx]["calories"] == results[0]["foods"][f_idx]["calories"]
                assert results[i]["foods"][f_idx]["servingGrams"] == results[0]["foods"][f_idx]["servingGrams"]
                assert results[i]["foods"][f_idx]["nutritionSource"] == results[0]["foods"][f_idx]["nutritionSource"]

    def test_prompt_generation_deterministic(self):
        p1 = build_food_analysis_prompt("Fat Loss", 1800, "Halal", ["Peanuts"])
        p2 = build_food_analysis_prompt("Fat Loss", 1800, "Halal", ["Peanuts"])
        assert p1 == p2
        assert "CRITICAL VISUAL RECOGNITION RULES" in p1
        assert "estimatedServingGrams" in p1
