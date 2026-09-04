import os
import re
import sqlite3
import logging
from difflib import SequenceMatcher
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Optional, Tuple

logger = logging.getLogger(__name__)

# Primary SQLite database location for bundled dataset
DB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
DB_PATH = os.path.join(DB_DIR, "malaysian_food.db")

# Confidence thresholds for food matching
CONFIDENCE_EXACT = 100.0
CONFIDENCE_THRESHOLD = 85.0  # >= 85: confident match; < 85: fallback to Gemini


@dataclass
class MalaysianFoodRecord:
    id: int
    source_id: str
    name: str
    name_ms: str
    category: str
    calories_kcal: float  # per 100g
    protein_g: float      # per 100g
    fat_g: float          # per 100g
    carbs_g: float        # per 100g
    fibre_g: float        # per 100g
    sugar_g: float        # per 100g
    sodium_mg: float      # per 100g
    serving_name: str
    serving_grams: float
    source_name: str = "MyFCD / FitLoop Malaysian Food DB"


# Seed dataset with authoritative Malaysian nutritional entries
SEEDED_MALAYSIAN_FOODS = [
    MalaysianFoodRecord(
        id=1,
        source_id="MY001",
        name="Nasi Lemak",
        name_ms="Nasi Lemak",
        category="Rice & Dishes",
        calories_kcal=180.0,
        protein_g=4.0,
        fat_g=8.0,
        carbs_g=25.0,
        fibre_g=1.5,
        sugar_g=2.0,
        sodium_mg=300.0,
        serving_name="1 plate",
        serving_grams=250.0,
    ),
    MalaysianFoodRecord(
        id=2,
        source_id="MY002",
        name="Roti Canai",
        name_ms="Roti Canai",
        category="Breads & Flour Foods",
        calories_kcal=300.0,
        protein_g=7.0,
        fat_g=15.0,
        carbs_g=35.0,
        fibre_g=2.0,
        sugar_g=3.0,
        sodium_mg=450.0,
        serving_name="1 piece",
        serving_grams=95.0,
    ),
    MalaysianFoodRecord(
        id=3,
        source_id="MY003",
        name="Char Kuey Teow",
        name_ms="Char Kuey Teow",
        category="Noodles & Rice Noodles",
        calories_kcal=220.0,
        protein_g=8.0,
        fat_g=9.0,
        carbs_g=28.0,
        fibre_g=1.8,
        sugar_g=4.0,
        sodium_mg=550.0,
        serving_name="1 plate",
        serving_grams=300.0,
    ),
    MalaysianFoodRecord(
        id=4,
        source_id="MY004",
        name="Chicken Rice",
        name_ms="Nasi Ayam",
        category="Rice & Dishes",
        calories_kcal=190.0,
        protein_g=10.0,
        fat_g=6.0,
        carbs_g=24.0,
        fibre_g=1.0,
        sugar_g=1.5,
        sodium_mg=400.0,
        serving_name="1 plate",
        serving_grams=280.0,
    ),
    MalaysianFoodRecord(
        id=5,
        source_id="MY005",
        name="Mee Goreng",
        name_ms="Mee Goreng",
        category="Noodles & Rice Noodles",
        calories_kcal=210.0,
        protein_g=7.0,
        fat_g=8.0,
        carbs_g=30.0,
        fibre_g=2.0,
        sugar_g=3.5,
        sodium_mg=500.0,
        serving_name="1 plate",
        serving_grams=300.0,
    ),
    MalaysianFoodRecord(
        id=6,
        source_id="MY006",
        name="Kuih Bom",
        name_ms="Kuih Bom",
        category="Traditional Malaysian Kuih",
        calories_kcal=335.0,
        protein_g=6.54,
        fat_g=11.59,
        carbs_g=51.21,
        fibre_g=7.4,
        sugar_g=8.93,
        sodium_mg=0.0,
        serving_name="1 piece",
        serving_grams=33.5,
    ),
    MalaysianFoodRecord(
        id=7,
        source_id="MY007",
        name="Teh Tarik",
        name_ms="Teh Tarik",
        category="Beverages",
        calories_kcal=83.0,
        protein_g=2.0,
        fat_g=3.0,
        carbs_g=12.0,
        fibre_g=0.0,
        sugar_g=11.0,
        sodium_mg=40.0,
        serving_name="1 glass",
        serving_grams=250.0,
    ),
    MalaysianFoodRecord(
        id=101,
        source_id="W001",
        name="French Fries",
        name_ms="Kentang Goreng",
        category="Snacks & Fast Food",
        calories_kcal=312.0,
        protein_g=3.4,
        fat_g=15.0,
        carbs_g=41.0,
        fibre_g=3.8,
        sugar_g=0.3,
        sodium_mg=210.0,
        serving_name="1 medium serving",
        serving_grams=117.0,
        source_name="Standard Food Reference",
    ),
    MalaysianFoodRecord(
        id=8,
        source_id="MY008",
        name="Curry Laksa",
        name_ms="Laksa Kari",
        category="Noodles & Rice Noodles",
        calories_kcal=160.0,
        protein_g=6.0,
        fat_g=7.0,
        carbs_g=18.0,
        fibre_g=1.2,
        sugar_g=2.5,
        sodium_mg=600.0,
        serving_name="1 bowl",
        serving_grams=350.0,
    ),
    MalaysianFoodRecord(
        id=9,
        source_id="MY009",
        name="Satay Ayam",
        name_ms="Sate Ayam",
        category="Poultry & Meat Dishes",
        calories_kcal=215.0,
        protein_g=18.0,
        fat_g=12.0,
        carbs_g=8.0,
        fibre_g=0.8,
        sugar_g=6.0,
        sodium_mg=380.0,
        serving_name="5 skewers",
        serving_grams=150.0,
    ),
    MalaysianFoodRecord(
        id=10,
        source_id="MY010",
        name="Nasi Goreng Kampung",
        name_ms="Nasi Goreng Kampung",
        category="Rice & Dishes",
        calories_kcal=200.0,
        protein_g=6.5,
        fat_g=7.0,
        carbs_g=28.0,
        fibre_g=1.5,
        sugar_g=2.0,
        sodium_mg=450.0,
        serving_name="1 plate",
        serving_grams=300.0,
    ),
]


class MalaysianFoodService:
    _foods: List[MalaysianFoodRecord] = []
    _initialized: bool = False

    @classmethod
    def initialize(cls):
        """
        Initializes the Malaysian food dataset. Seeds SQLite if missing and loads
        all records into memory for high-performance zero-latency lookups.
        """
        if cls._initialized and cls._foods:
            return

        os.makedirs(DB_DIR, exist_ok=True)

        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS food (
                    id INTEGER PRIMARY KEY,
                    source_id TEXT UNIQUE,
                    name TEXT NOT NULL,
                    name_ms TEXT,
                    category TEXT,
                    calories_kcal REAL,
                    protein_g REAL,
                    fat_g REAL,
                    carbs_g REAL,
                    fibre_g REAL,
                    sugar_g REAL,
                    sodium_mg REAL,
                    serving_name TEXT,
                    serving_grams REAL,
                    source_name TEXT
                )
            """)

            # Ensure all seeded records are present in database
            for f in SEEDED_MALAYSIAN_FOODS:
                cursor.execute("""
                    INSERT OR IGNORE INTO food (
                        id, source_id, name, name_ms, category,
                        calories_kcal, protein_g, fat_g, carbs_g,
                        fibre_g, sugar_g, sodium_mg,
                        serving_name, serving_grams, source_name
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    f.id, f.source_id, f.name, f.name_ms, f.category,
                    f.calories_kcal, f.protein_g, f.fat_g, f.carbs_g,
                    f.fibre_g, f.sugar_g, f.sodium_mg,
                    f.serving_name, f.serving_grams, f.source_name
                ))
            conn.commit()

            # Read all foods into memory
            cursor.execute("SELECT id, source_id, name, name_ms, category, calories_kcal, protein_g, fat_g, carbs_g, fibre_g, sugar_g, sodium_mg, serving_name, serving_grams, source_name FROM food")
            rows = cursor.fetchall()
            cls._foods = [
                MalaysianFoodRecord(
                    id=r[0], source_id=r[1], name=r[2], name_ms=r[3] or r[2], category=r[4] or "General",
                    calories_kcal=r[5] or 0.0, protein_g=r[6] or 0.0, fat_g=r[7] or 0.0, carbs_g=r[8] or 0.0,
                    fibre_g=r[9] or 0.0, sugar_g=r[10] or 0.0, sodium_mg=r[11] or 0.0,
                    serving_name=r[12] or "1 serving", serving_grams=r[13] or 100.0, source_name=r[14] or "FitLoop DB"
                )
                for r in rows
            ]
            conn.close()
            cls._initialized = True
            logger.info(f"Malaysian Food Service initialized with {len(cls._foods)} records from {DB_PATH}")
        except Exception as e:
            logger.warning(f"Could not load SQLite DB at {DB_PATH}, using in-memory dataset fallback: {e}")
            cls._foods = list(SEEDED_MALAYSIAN_FOODS)
            cls._initialized = True

    @classmethod
    def get_all_foods(cls) -> List[MalaysianFoodRecord]:
        if not cls._initialized:
            cls.initialize()
        return cls._foods

    ALIASES = {
        "hainanese chicken rice": "chicken rice",
        "steamed chicken rice": "chicken rice",
        "roasted chicken rice": "chicken rice",
        "roast chicken rice": "chicken rice",
        "nasi ayam": "chicken rice",
        "nasi ayam hainan": "chicken rice",
        "nasi ayam roasted": "chicken rice",
        
        "satay ayam": "satay ayam",
        "chicken satay": "satay ayam",
        "chicken satay skewers": "satay ayam",
        "satay skewers": "satay ayam",
        "sate ayam": "satay ayam",
        "beef satay": "satay daging",
        "satay daging": "satay daging",
        
        "char kway teow": "char kuey teow",
        "char kuey teow": "char kuey teow",
        "penang char kway teow": "char kuey teow",
        "penang char kuey teow": "char kuey teow",
        "kuey teow goreng": "char kuey teow",
        "fried flat noodles": "char kuey teow",
        
        "french fries": "french fries",
        "fries": "french fries",
        "mcdonalds french fries": "french fries",
        "mcdonald s french fries": "french fries",
        "potato fries": "french fries",
        "chips": "french fries",
        
        "roti prata": "roti canai",
        "prata": "roti canai",
    }

    @staticmethod
    def normalize_text(text: str) -> str:
        """Normalizes a food name for comparison: removes parentheses, lowercase, remove punctuation, collapse whitespace."""
        if not text:
            return ""
        text_without_paren = re.sub(r"\([^)]*\)", " ", text)
        clean = re.sub(r"[^a-zA-Z0-9\s]", " ", text_without_paren.lower())
        return " ".join(clean.split())

    SYNONYMS = {
        "chicken": "ayam",
        "beef": "daging",
        "mutton": "kambing",
        "lamb": "kambing",
        "fish": "ikan",
        "prawn": "udang",
        "prawns": "udang",
        "shrimp": "udang",
        "squid": "sotong",
        "egg": "telur",
        "eggs": "telur",
        "fried": "goreng",
        "rice": "nasi",
        "noodles": "mee",
        "noodle": "mee",
        "soup": "sup",
        "water": "air",
        "tea": "teh",
        "coffee": "kopi",
        "bread": "roti",
        "curry": "kari",
        "curried": "kari",
        "iced": "ais",
        "ice": "ais",
    }

    @classmethod
    def _translate_query(cls, norm_text: str) -> str:
        """Replaces common English culinary words with Malay equivalents to improve cross-lingual matching."""
        tokens = norm_text.split()
        translated = [cls.SYNONYMS.get(t, t) for t in tokens]
        return " ".join(translated)

    @classmethod
    def find_match(cls, query: str) -> Tuple[Optional[MalaysianFoodRecord], float]:
        """
        Attempts to match a detected food query string against Malaysian food items.
        Returns (MatchedRecord, match_score_0_to_100).
        """
        if not cls._initialized:
            cls.initialize()

        norm_query = cls.normalize_text(query)
        if not norm_query:
            return None, 0.0

        trans_query = cls._translate_query(norm_query)
        query_variants = {norm_query, trans_query}

        # Check curated aliases for common food variations
        alias_mapped = cls.ALIASES.get(norm_query)
        if alias_mapped:
            query_variants.add(alias_mapped)
            query_variants.add(cls._translate_query(alias_mapped))

        best_record: Optional[MalaysianFoodRecord] = None
        best_score: float = 0.0
        best_match_len: int = 0

        for food in cls._foods:
            norm_en = cls.normalize_text(food.name)
            norm_ms = cls.normalize_text(food.name_ms)
            target_variants = {norm_en, norm_ms}

            for q in query_variants:
                for target in target_variants:
                    if not target:
                        continue

                    # 1. Exact match check (100%)
                    if q == target:
                        return food, CONFIDENCE_EXACT

                    # 2. Direct containment check
                    if target in q:
                        coverage = len(target) / max(len(q), 1)
                        containment_score = 92.0 + (coverage * 7.0)  # 92.0 - 99.0
                        if containment_score > best_score or (containment_score == best_score and len(target) > best_match_len):
                            best_score = containment_score
                            best_record = food
                            best_match_len = len(target)
                        continue

                    if q in target:
                        coverage = len(q) / max(len(target), 1)
                        containment_score = 88.0 + (coverage * 6.0)  # 88.0 - 94.0
                        if containment_score > best_score or (containment_score == best_score and len(target) > best_match_len):
                            best_score = containment_score
                            best_record = food
                            best_match_len = len(target)
                        continue

                    # 3. Token set match (e.g. 'satay ayam' vs 'ayam satay skewers')
                    q_tokens = set(q.split())
                    target_tokens = set(target.split())
                    if target_tokens and target_tokens.issubset(q_tokens):
                        coverage = len(target_tokens) / max(len(q_tokens), 1)
                        token_score = 90.0 + (coverage * 8.0)
                        if token_score > best_score or (token_score == best_score and len(target) > best_match_len):
                            best_score = token_score
                            best_record = food
                            best_match_len = len(target)
                        continue

                    # 4. Fuzzy SequenceMatcher similarity
                    score = SequenceMatcher(None, q, target).ratio() * 100.0
                    if score > best_score or (score == best_score and len(target) > best_match_len):
                        best_score = score
                        best_record = food
                        best_match_len = len(target)

        return best_record, round(best_score, 1)

    @classmethod
    def calculate_nutrition_for_serving(
        cls,
        food: MalaysianFoodRecord,
        custom_grams: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Scales per-100g database nutritional values to the item's standard serving size or custom grams.
        """
        grams = custom_grams if (custom_grams and custom_grams > 0) else food.serving_grams
        multiplier = grams / 100.0

        return {
            "calories": int(round(food.calories_kcal * multiplier)),
            "protein": int(round(food.protein_g * multiplier)),
            "carbs": int(round(food.carbs_g * multiplier)),
            "fat": int(round(food.fat_g * multiplier)),
            "fibre": round(food.fibre_g * multiplier, 1),
            "sugar": round(food.sugar_g * multiplier, 1),
            "sodium": int(round(food.sodium_mg * multiplier)),
            "servingGrams": round(grams, 1),
            "servingName": food.serving_name,
        }

    @classmethod
    def enrich_gemini_analysis(cls, gemini_result: Dict[str, Any]) -> Dict[str, Any]:
        """
        Post-processes Gemini AI food recognition results.
        For each detected food item:
          - If a confident Malaysian DB match (score >= 85) is found:
              Overrides item nutrients with Malaysian DB authoritative values.
              Adds metadata (nutritionSource='malaysian_db', matchedFoodName, matchScore).
          - Otherwise:
              Preserves Gemini estimates with metadata (nutritionSource='gemini_ai').
        Recomputes meal totals from normalized individual items while preserving Gemini reasoning.
        """
        raw_foods = gemini_result.get("foods", [])
        enriched_foods: List[Dict[str, Any]] = []

        total_calories = 0
        total_proteins = 0
        total_carbs = 0
        total_fats = 0

        for item in raw_foods:
            item_dict = dict(item) if isinstance(item, dict) else {"name": str(item)}
            food_name = item_dict.get("name", "Unknown Food")

            matched_food, match_score = cls.find_match(food_name)

            if matched_food and match_score >= CONFIDENCE_THRESHOLD:
                # Confident Malaysian DB Match
                # Portion estimation stability: prefer DB standard serving unless AI estimate is within credible bounds (0.5x - 2.5x)
                standard_grams = matched_food.serving_grams
                ai_grams = item_dict.get("estimatedServingGrams") or item_dict.get("servingGrams")

                selected_grams: Optional[float] = None
                if ai_grams and isinstance(ai_grams, (int, float)) and ai_grams > 0:
                    if 0.5 * standard_grams <= ai_grams <= 2.5 * standard_grams:
                        selected_grams = float(ai_grams)
                    else:
                        logger.info(f"AI portion ({ai_grams}g) outside realistic range (0.5x-2.5x of {standard_grams}g) for '{food_name}'. Using standard {standard_grams}g.")

                db_nutrition = cls.calculate_nutrition_for_serving(matched_food, custom_grams=selected_grams)

                enriched_item = {
                    "name": item_dict.get("name", matched_food.name),
                    "calories": db_nutrition["calories"],
                    "proteins": db_nutrition["protein"],
                    "carbs": db_nutrition["carbs"],
                    "fats": db_nutrition["fat"],
                    "fibre": db_nutrition["fibre"],
                    "sugar": db_nutrition["sugar"],
                    "sodium": db_nutrition["sodium"],
                    "servingGrams": db_nutrition["servingGrams"],
                    "nutritionSource": "malaysian_db",
                    "matchedFoodName": matched_food.name,
                    "matchScore": match_score,
                    "servingInfo": f"{db_nutrition['servingName']} ({db_nutrition['servingGrams']}g)",
                }
                logger.info(f"Matched '{food_name}' -> Malaysian DB '{matched_food.name}' (Score: {match_score}%, {db_nutrition['calories']} kcal, {db_nutrition['servingGrams']}g)")
            else:
                # Fallback to Gemini Estimates
                cals = int((item_dict.get("calories") or 0))
                pro = int((item_dict.get("proteins") or item_dict.get("protein") or 0))
                carbs = int((item_dict.get("carbs") or 0))
                fats = int((item_dict.get("fats") or item_dict.get("fat") or 0))
                ai_grams = item_dict.get("estimatedServingGrams") or item_dict.get("servingGrams")

                enriched_item = {
                    "name": food_name,
                    "calories": cals,
                    "proteins": pro,
                    "carbs": carbs,
                    "fats": fats,
                    "nutritionSource": "gemini_ai",
                    "matchScore": match_score,
                }
                if ai_grams and isinstance(ai_grams, (int, float)) and ai_grams > 0:
                    enriched_item["servingGrams"] = float(ai_grams)
                logger.info(f"No confident Malaysian DB match for '{food_name}' (Score: {match_score}%). Using Gemini AI nutrition.")

            enriched_foods.append(enriched_item)
            total_calories += enriched_item["calories"]
            total_proteins += enriched_item["proteins"]
            total_carbs += enriched_item["carbs"]
            total_fats += enriched_item["fats"]

        # Build final backward-compatible response preserving Gemini reasoning fields
        return {
            "foods": enriched_foods,
            "totalCalories": total_calories if enriched_foods else gemini_result.get("totalCalories", 0),
            "totalProteins": total_proteins if enriched_foods else gemini_result.get("totalProteins", 0),
            "totalCarbs": total_carbs if enriched_foods else gemini_result.get("totalCarbs", 0),
            "totalFats": total_fats if enriched_foods else gemini_result.get("totalFats", 0),
            "score": gemini_result.get("score", 75),
            "explanation": gemini_result.get("explanation", ""),
            "alternatives": gemini_result.get("alternatives", []),
            "dietCompatibility": gemini_result.get("dietCompatibility", "compatible"),
            "dietNotice": gemini_result.get("dietNotice"),
            "allergyNotice": gemini_result.get("allergyNotice"),
        }
