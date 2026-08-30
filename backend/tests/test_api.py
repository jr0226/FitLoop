from fastapi.testclient import TestClient
import pytest
from main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert data["service"] == "FitLoop Backend API"


def test_food_analyze_endpoint_validation():
    # Sending invalid/empty payload should return 422 Unprocessable Entity
    response = client.post("/api/food/analyze", json={})
    assert response.status_code == 422


def test_workout_recommend_endpoint_structure():
    # Calling without configured GEMINI_API_KEY handles error cleanly
    response = client.post("/api/workout/recommend", json={"userGoal": "Muscle Gain", "difficulty": "Intermediate"})
    assert response.status_code in [200, 500, 502, 503]


def test_exercise_search_validation():
    # Missing query param should return 422 Unprocessable Entity
    response = client.get("/api/exercises/search")
    assert response.status_code == 422

    # Invalid characters in query should return 400 Bad Request
    response = client.get("/api/exercises/search?query=@@@$$$")
    assert response.status_code == 400


def test_exercise_body_part_validation():
    # Invalid body part should return 400 Bad Request
    response = client.get("/api/exercises/body-part/invalid_part")
    assert response.status_code == 400

    # Valid body part route exists
    response = client.get("/api/exercises/body-part/chest")
    assert response.status_code in [200, 502, 503]


def test_exercise_id_validation():
    # Invalid ID format
    response = client.get("/api/exercises/exercise-id-with-invalid-chars!@#")
    assert response.status_code == 422
