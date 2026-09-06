from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from deps import get_current_user
from models.user import User
from services import report_generator

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])


@router.get("/weekly")
async def weekly(
    week_start: date | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if week_start is None:
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
    return await report_generator.weekly_report(db, user.id, week_start)


@router.get("/monthly")
async def monthly(
    month: str | None = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if month:
        month_start = datetime.strptime(month, "%Y-%m").date()
    else:
        month_start = date.today().replace(day=1)
    return await report_generator.monthly_report(db, user.id, month_start)


@router.get("/yearly-wrapped")
async def yearly_wrapped(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return await report_generator.yearly_wrapped(db, user.id)
