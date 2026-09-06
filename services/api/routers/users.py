import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User, UserAllergy, UserGoal
from schemas.user import (
    AllergyCreate,
    AllergyOut,
    GoalOut,
    GoalUpsert,
    ProfileUpdate,
    UserOut,
)
from services.macro_calculator import calculate_age, calculate_tdee, recommend_macros

router = APIRouter(prefix="/api/v1/users", tags=["users"])


@router.put("/me", response_model=UserOut)
async def update_profile(
    body: ProfileUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(user, k, v)
    await db.flush()
    return UserOut.model_validate(user)


class MacroRecommendRequest(BaseModel):
    goal_type: str


@router.post("/me/recommend-macros")
async def recommend(
    body: MacroRecommendRequest, user: User = Depends(get_current_user)
):
    if not (user.weight_kg and user.height_cm):
        raise HTTPException(status_code=400, detail="Profile needs height and weight first")
    age = calculate_age(user.dob)
    tdee = calculate_tdee(user.weight_kg, user.height_cm, age, user.biological_sex or "female", user.activity_level)
    macros = recommend_macros(tdee, body.goal_type)
    return {"tdee_kcal": tdee, **macros, "goal_type": body.goal_type}


@router.put("/me/goals", response_model=GoalOut)
async def upsert_goal(
    body: GoalUpsert, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    res = await db.execute(
        select(UserGoal).where(UserGoal.user_id == user.id).order_by(UserGoal.updated_at.desc())
    )
    goal = res.scalars().first()
    tdee = None
    if user.weight_kg and user.height_cm:
        tdee = calculate_tdee(
            user.weight_kg, user.height_cm, calculate_age(user.dob), user.biological_sex or "female", user.activity_level
        )

    data = body.model_dump(exclude_none=True)
    if goal is None:
        goal = UserGoal(user_id=user.id, tdee_kcal=tdee, **data)
        db.add(goal)
    else:
        if tdee is not None:
            goal.tdee_kcal = tdee
        for k, v in data.items():
            setattr(goal, k, v)
    await db.flush()
    await db.refresh(goal)
    return GoalOut.model_validate(goal)


@router.get("/me/allergies", response_model=list[AllergyOut])
async def list_allergies(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(select(UserAllergy).where(UserAllergy.user_id == user.id))
    return [AllergyOut.model_validate(a) for a in res.scalars().all()]


@router.post("/me/allergies", response_model=AllergyOut, status_code=201)
async def add_allergy(
    body: AllergyCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    existing = await db.execute(
        select(UserAllergy).where(
            UserAllergy.user_id == user.id, UserAllergy.allergen_name == body.allergen_name
        )
    )
    allergy = existing.scalar_one_or_none()
    if allergy:
        for k, v in body.model_dump().items():
            setattr(allergy, k, v)
    else:
        allergy = UserAllergy(user_id=user.id, **body.model_dump())
        db.add(allergy)
    await db.flush()
    await db.refresh(allergy)
    return AllergyOut.model_validate(allergy)


@router.delete("/me/allergies/{allergy_id}", status_code=204)
async def delete_allergy(
    allergy_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    res = await db.execute(
        select(UserAllergy).where(UserAllergy.id == allergy_id, UserAllergy.user_id == user.id)
    )
    allergy = res.scalar_one_or_none()
    if allergy is None:
        raise HTTPException(status_code=404, detail="Allergy not found")
    await db.delete(allergy)
    return None
