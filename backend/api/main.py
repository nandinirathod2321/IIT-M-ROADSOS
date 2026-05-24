from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="RoadSOS API",
    description="Backend API for IIT-M RoadSOS - Road Emergency & Rescue Operating System",
    version="1.0.0"
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "RoadSOS Emergency API Gateway",
        "version": "1.0.0",
        "documentation": "/docs"
    }
