# Geolocation API

FastAPI application for geolocation functionality.

## Structure

```
geolocation-api/
├── app.py          # Main FastAPI application entry point
├── routes.py       # API route definitions
├── lifespan.py     # Startup/shutdown lifecycle management
├── config.py       # Configuration and settings
└── pyproject.toml  # Project dependencies
```

## Running the Application

### Development Mode

```bash
# Install dependencies
uv sync

# Run with uvicorn
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

### Using Task

If you have a Taskfile configured:

```bash
task run
```

## API Documentation

Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health Check: http://localhost:8000/health

## Available Endpoints

### Core Routes (prefix: `/api/v1`)

- `GET /api/v1/` - Root endpoint
- `POST /api/v1/location` - Create/validate a location
- `GET /api/v1/location/{location_id}` - Get location by ID
- `POST /api/v1/round` - Generate a new game round

### Health Check

- `GET /health` - Health check endpoint

## Configuration

Configuration is managed via `config.py` using Pydantic Settings. You can override settings using environment variables or a `.env` file.

## Next Steps

1. Implement actual business logic in `routes.py`
2. Integrate with the `round-generator` and `state-management` packages
3. Add authentication/authorization middleware if needed
4. Set up database models and connections in `lifespan.py`
5. Configure CORS origins for production in `app.py`

