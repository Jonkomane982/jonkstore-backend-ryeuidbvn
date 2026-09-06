from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import PostgresDsn
from typing import Optional

class Settings(BaseSettings):
    # Database
    JONKAI_DATABASE_URL: PostgresDsn

    # OpenAI
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_MODEL: str = "gpt-4o" # gpt-4o is required for multimodal vision + tools

    # App
    ENV: str = "development"
    LOG_LEVEL: str = "INFO"

    # Model Management
    MODEL_DIR: str = "models"

    # Feature Configuration
    FEATURE_WINDOW_DAYS: int = 30

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
