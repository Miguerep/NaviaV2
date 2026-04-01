from datetime import date, datetime, timezone
from enum import Enum

from sqlmodel import Field, SQLModel


class ChatRole(str, Enum):
    user = "user"
    assistant = "assistant"
    system = "system"


class Trip(SQLModel, table=True):
    id: str | None = Field(default=None, primary_key=True)
    destination: str
    start_date: date
    end_date: date
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class DayPlan(SQLModel, table=True):
    id: str | None = Field(default=None, primary_key=True)
    trip_id: str = Field(index=True)
    day: date = Field(index=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Stop(SQLModel, table=True):
    id: str | None = Field(default=None, primary_key=True)
    day_plan_id: str = Field(index=True)
    ordinal: int = Field(index=True)
    title: str
    subtitle: str | None = None
    start_time_local: str | None = None


class ChatMessage(SQLModel, table=True):
    id: str | None = Field(default=None, primary_key=True)
    trip_id: str = Field(index=True)
    role: ChatRole
    content: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

