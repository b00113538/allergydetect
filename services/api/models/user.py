import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    dob: Mapped[date | None] = mapped_column(Date)
    biological_sex: Mapped[str | None] = mapped_column(String(10))
    height_cm: Mapped[float | None] = mapped_column(Float)
    weight_kg: Mapped[float | None] = mapped_column(Float)
    activity_level: Mapped[str] = mapped_column(String(20), default="moderate")
    timezone: Mapped[str] = mapped_column(String(50), default="UTC")
    locale: Mapped[str] = mapped_column(String(10), default="en")
    avatar_url: Mapped[str | None] = mapped_column(String)
    onboarding_complete: Mapped[bool] = mapped_column(Boolean, default=False)

    # Push notifications
    expo_push_token: Mapped[str | None] = mapped_column(String(255))
    push_platform: Mapped[str | None] = mapped_column(String(10))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    goals: Mapped[list["UserGoal"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    allergies: Mapped[list["UserAllergy"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class UserGoal(Base):
    __tablename__ = "user_goals"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    goal_type: Mapped[str] = mapped_column(String(30), nullable=False)
    tdee_kcal: Mapped[int | None] = mapped_column(Integer)
    calories_target: Mapped[int | None] = mapped_column(Integer)
    protein_g: Mapped[float | None] = mapped_column(Float)
    carbs_g: Mapped[float | None] = mapped_column(Float)
    fat_g: Mapped[float | None] = mapped_column(Float)
    fiber_g: Mapped[float | None] = mapped_column(Float)
    water_ml: Mapped[int] = mapped_column(Integer, default=2000)
    sodium_mg: Mapped[float | None] = mapped_column(Float)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="goals")


class UserAllergy(Base):
    __tablename__ = "user_allergies"
    __table_args__ = (UniqueConstraint("user_id", "allergen_name", name="uq_user_allergen"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    allergen_name: Mapped[str] = mapped_column(String(100), nullable=False)
    allergen_category: Mapped[str | None] = mapped_column(String(50))
    severity: Mapped[str] = mapped_column(String(20), nullable=False, default="moderate")
    confirmed_by_doctor: Mapped[bool] = mapped_column(Boolean, default=False)
    added_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="allergies")
