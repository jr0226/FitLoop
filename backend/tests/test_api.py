import io
import os
import sys
import unittest
import httpx

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app


class TestBackendAPI(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        self.transport = httpx.ASGITransport(app=app)
        self.client = httpx.AsyncClient(transport=self.transport, base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_health_check(self):
        response = await self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "online")
        self.assertEqual(data["service"], "FitLoop Backend API")

    async def test_list_malaysian_foods(self):
        response = await self.client.get("/api/malaysian-foods")
        self.assertEqual(response.status_code, 200)
        foods = response.json()
        self.assertIsInstance(foods, list)
        self.assertGreaterEqual(len(foods), 10)

    async def test_match_malaysian_food_endpoint(self):
        response = await self.client.get("/api/malaysian-foods/match?query=nasi+lemak")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["matched"])
        self.assertEqual(data["food"]["name"], "Nasi Lemak")
        self.assertGreaterEqual(data["score"], 85.0)

    async def test_food_analyze_endpoint_missing_file(self):
        # Calling multipart endpoint without file should return 422 Unprocessable Entity
        response = await self.client.post("/api/ai/analyze-food", data={"user_goal": "Muscle Gain"})
        self.assertEqual(response.status_code, 422)

    async def test_food_analyze_endpoint_empty_file(self):
        # Calling with empty file should return 400 Bad Request
        empty_file = io.BytesIO(b"")
        response = await self.client.post(
            "/api/ai/analyze-food",
            data={"user_goal": "Muscle Gain"},
            files={"file": ("food_scan.jpg", empty_file, "image/jpeg")},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("empty", response.json().get("detail", "").lower())

    async def test_food_analyze_endpoint_invalid_file_type(self):
        # Calling with non-image file should return 400 Bad Request
        fake_file = io.BytesIO(b"fake text file content")
        response = await self.client.post(
            "/api/ai/analyze-food",
            data={"user_goal": "Muscle Gain"},
            files={"file": ("malicious.exe", fake_file, "application/x-msdownload")},
        )
        self.assertEqual(response.status_code, 400)

    async def test_workout_recommend_endpoint_structure(self):
        # Calling without configured GEMINI_API_KEY handles error cleanly
        response = await self.client.post("/api/workout/recommend", json={"userGoal": "Muscle Gain", "difficulty": "Intermediate"})
        self.assertIn(response.status_code, [200, 500, 502, 503])

    async def test_exercise_search_validation(self):
        # Missing query param should return 422 Unprocessable Entity
        response = await self.client.get("/api/exercises/search")
        self.assertEqual(response.status_code, 422)

        # Invalid characters in query should return 400 Bad Request
        response = await self.client.get("/api/exercises/search?query=@@@$$$")
        self.assertEqual(response.status_code, 400)

    async def test_exercise_body_part_validation(self):
        # Invalid body part should return 400 Bad Request
        response = await self.client.get("/api/exercises/body-part/invalid_part")
        self.assertEqual(response.status_code, 400)

        # Valid body part route exists
        response = await self.client.get("/api/exercises/body-part/chest")
        self.assertIn(response.status_code, [200, 502, 503])

    async def test_exercise_id_validation(self):
        # Invalid ID format
        response = await self.client.get("/api/exercises/exercise-id-with-invalid-chars!@#")
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()
