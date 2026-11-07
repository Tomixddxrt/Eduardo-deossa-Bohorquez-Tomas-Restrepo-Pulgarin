import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine


load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def create_database_engine():
    return create_engine(
        URL.create(
            "postgresql+psycopg2",
            username=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            host=os.getenv("POSTGRES_HOST", "localhost"),
            port=int(os.getenv("POSTGRES_PORT", "5432")),
            database=os.getenv("POSTGRES_DB", "bi_envasado"),
        )
    )
