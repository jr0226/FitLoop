import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging

from config import HOST, PORT, ENVIRONMENT
from routers import food, workout, exercises, nutrition, faq

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("fitloop-backend")

app = FastAPI(
    title="FitLoop AI & Backend Services API",
    description="Secure Backend API proxying Gemini AI, ExerciseDB, and Nutrition APIs for FitLoop Flutter Client",
    version="1.0.0",
)

# Enable CORS for Flutter web, mobile, and emulator access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Exception Handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled server error on {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error occurred. Check backend server logs."},
    )

# Register API Routers
app.include_router(food.router)
app.include_router(workout.router)
app.include_router(exercises.router)
app.include_router(nutrition.router)
app.include_router(faq.router)


@app.get("/api/health", tags=["Health"])
@app.get("/", tags=["Health"])
async def health_check():
    """
    Health check endpoint to verify backend service connectivity.
    """
    return {
        "status": "online",
        "service": "FitLoop Backend API",
        "version": "1.0.0",
        "environment": ENVIRONMENT,
    }


if __name__ == "__main__":
    logger.info(f"Starting FitLoop FastAPI backend on http://{HOST}:{PORT}")
    uvicorn.run("main:app", host=HOST, port=PORT, reload=True)
