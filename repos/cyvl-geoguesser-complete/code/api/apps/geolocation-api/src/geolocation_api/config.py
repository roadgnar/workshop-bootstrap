from pydantic_settings import BaseSettings, SettingsConfigDict, Field


class Settings(BaseSettings):
    """
    Application settings and configuration
    """
    # API Configuration
    api_title: str = "Geolocation Service"
    api_version: str = "0.1.0"
    debug: bool = False

    log_level: str = Field(default="INFO", description="Logging level")
    
    
    # Database Configuration (example)
    # database_url: str = "postgresql://user:pass@localhost/dbname"
    
    # Redis Configuration (example)
    # redis_url: str = "redis://localhost:6379/0"
    
    # API Keys (example)
    # google_maps_api_key: str = ""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


# Global settings instance
settings = Settings()

