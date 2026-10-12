from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="ALMANAC_", env_file=".env")

    host: str = "0.0.0.0"
    port: int = 8080
    public_origin: str = "http://localhost:8080"

    # sqlite | ydb
    db_backend: str = "sqlite"
    sqlite_path: str = "./data/almanac.db"

    ydb_endpoint: str = "grpc://localhost:2136"
    ydb_database: str = "/local"
    ydb_service_account_key_file: str = ""

    fcm_server_key: str = ""

    # Deep link verification (Android App Links + iOS Universal Links)
    android_package: str = "com.example.almanac"
    android_sha256_cert: str = ""
    ios_team_id: str = "TEAMID"
    ios_bundle_id: str = "com.example.almanac"

    cors_origins: str = "*"

    # Local PC helper: /lab UI + WireGuard scripts for MikroTik.
    home_lab: bool = False


settings = Settings()
