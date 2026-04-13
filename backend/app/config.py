from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Navia Backend"
    app_env: str = "development"
    app_port: int = 8787

    database_url: str = "sqlite:///./backend.db"
    mapbox_token: str | None = None
    gemini_api_key: str = ""
    allowed_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:8787",
    ]


settings = Settings()

