from contextlib import asynccontextmanager
from fastapi import FastAPI
import logging

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events
    """
    # Startup logic
    logger.info("🚀 Starting up Geolocation API...")
    
    # TODO: Initialize database connections, load models, etc.
    # Example:
    # app.state.db = await init_database()
    # app.state.redis = await init_redis()
    
    yield
    
    # Shutdown logic
    logger.info("🛑 Shutting down Geolocation API...")
    
    # TODO: Close connections, cleanup resources, etc.
    # Example:
    # await app.state.db.close()
    # await app.state.redis.close()

