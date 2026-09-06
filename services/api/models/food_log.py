import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class FoodLog(Base):
    __tablename__ = "food_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    logged_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    meal_type: Mapped[str] = mapped_column(String(20), nullable=False)
    source: Mapped[str] = mapped_column(String(20), nullable=False)
    food_image_url: Mapped[str | None] = mapped_column(Text)
    notes: Mapped[str | None] = mapped_column(Text)
    # NOTE: the spec's `GENERATED ALWAYS AS (0)` is a placeholder bug; we store
    # an app-computed total derived from the meal's items instead.
    total_calories: Mapped[float] = mapped_column(Float, default=0.0)
    meal_grade: Mapped[str | None] = mapped_column(String(2))
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    items: Mapped[list["FoodLogItem"]] = relationship(
        back_populates="food_log", cascade="all, delete-orphan", lazy="selectin"
    )


class FoodLogItem(Base):
    __tablename__ = "food_log_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    food_log_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("food_logs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    ingredient_name: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity_g: Mapped[float] = mapped_column(Float, nullable=False, default=100)
    calories: Mapped[float | None] = mapped_column(Float)
    protein_g: Mapped[float | None] = mapped_column(Float)
    carbs_g: Mapped[float | None] = mapped_column(Float)
    fat_g: Mapped[float | None] = mapped_column(Float)
    fiber_g: Mapped[float | None] = mapped_column(Float)
    sugar_g: Mapped[float | None] = mapped_column(Float)
    sodium_mg: Mapped[float | None] = mapped_column(Float)
    saturated_fat_g: Mapped[float | None] = mapped_column(Float)
    food_grade: Mapped[str | None] = mapped_column(String(2))
    allergen_flags: Mapped[list] = mapped_column(JSONB, default=list)
    confidence_score: Mapped[float] = mapped_column(Float, default=1.0)
    nova_group: Mapped[int | None] = mapped_column(Integer)
    nutriscore: Mapped[str | None] = mapped_column(String(1))
    usda_fdc_id: Mapped[int | None] = mapped_column(Integer)
    open_food_facts_id: Mapped[str | None] = mapped_column(String(50))

    food_log: Mapped["FoodLog"] = relationship(back_populates="items")


class CustomMeal(Base):
    __tablename__ = "custom_meals"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    ingredients: Mapped[list] = mapped_column(JSONB, default=list)
    macros: Mapped[dict] = mapped_column(JSONB, default=dict)
    allergen_tags: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    is_public: Mapped[bool] = mapped_column(Boolean, default=False)
    use_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
