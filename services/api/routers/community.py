import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.community import CommunityPost
from models.food_log import CustomMeal
from models.user import User
from schemas.community import PostCreate, PostOut, PostUpdate, RecipeCreate, RecipeOut

router = APIRouter(prefix="/api/v1/community", tags=["community"])


@router.get("/feed", response_model=list[PostOut])
async def feed(
    allergen_tag: str | None = None,
    post_type: str | None = None,
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(CommunityPost)
    if post_type:
        q = q.where(CommunityPost.post_type == post_type)
    if allergen_tag:
        q = q.where(CommunityPost.allergen_tags.any(allergen_tag))
    q = q.order_by(CommunityPost.created_at.desc()).limit(limit).offset(offset)
    res = await db.execute(q)
    return [PostOut.model_validate(p) for p in res.scalars().all()]


@router.post("/posts", response_model=PostOut, status_code=201)
async def create_post(body: PostCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    post = CommunityPost(user_id=user.id, **body.model_dump())
    db.add(post)
    await db.flush()
    await db.refresh(post)
    return PostOut.model_validate(post)


async def _owned_post(db, post_id, user_id) -> CommunityPost:
    res = await db.execute(select(CommunityPost).where(CommunityPost.id == post_id))
    post = res.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    return post


@router.post("/posts/{post_id}/upvote", response_model=PostOut)
async def upvote(post_id: uuid.UUID, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    post = await _owned_post(db, post_id, None)
    post.upvotes += 1
    await db.flush()
    return PostOut.model_validate(post)


@router.put("/posts/{post_id}", response_model=PostOut)
async def update_post(
    post_id: uuid.UUID, body: PostUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    post = await _owned_post(db, post_id, user.id)
    if post.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your post")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(post, k, v)
    await db.flush()
    return PostOut.model_validate(post)


@router.delete("/posts/{post_id}", status_code=204)
async def delete_post(post_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    post = await _owned_post(db, post_id, user.id)
    if post.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your post")
    await db.delete(post)
    return None


def _recipe_macros(ingredients: list) -> dict:
    return {
        "calories": sum((i.calories or 0) for i in ingredients),
        "protein_g": sum((i.protein_g or 0) for i in ingredients),
        "carbs_g": sum((i.carbs_g or 0) for i in ingredients),
        "fat_g": sum((i.fat_g or 0) for i in ingredients),
    }


@router.get("/recipes", response_model=list[RecipeOut])
async def recipes(
    allergen_safe_for: str | None = None,
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = select(CustomMeal).where(CustomMeal.is_public.is_(True))
    if allergen_safe_for:
        # Exclude recipes tagged with the allergen the user must avoid.
        q = q.where(~CustomMeal.allergen_tags.any(allergen_safe_for))
    q = q.order_by(CustomMeal.use_count.desc()).limit(limit).offset(offset)
    res = await db.execute(q)
    return [RecipeOut.model_validate(r) for r in res.scalars().all()]


@router.post("/recipes", response_model=RecipeOut, status_code=201)
async def create_recipe(body: RecipeCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    macros = _recipe_macros(body.ingredients)
    recipe = CustomMeal(
        user_id=user.id,
        name=body.name,
        ingredients=[i.model_dump() for i in body.ingredients],
        macros=macros,
        allergen_tags=body.allergen_tags,
        is_public=body.is_public,
    )
    db.add(recipe)
    await db.flush()
    await db.refresh(recipe)
    return RecipeOut.model_validate(recipe)
