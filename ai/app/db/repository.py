from sqlalchemy.orm import Session
from sqlalchemy import select, and_
from typing import TypeVar, Generic, Type, List, Optional
from uuid import UUID
from app.db.session import Base

T = TypeVar("T", bound=Base)

class BaseRepository(Generic[T]):
    def __init__(self, model: Type[T], db: Session):
        self.model = model
        self.db = db

    def get_by_id(self, id: UUID, business_id: UUID) -> Optional[T]:
        # Enforce tenant isolation at the query level
        query = select(self.model).where(
            and_(
                self.model.id == id,
                self.model.business_id == business_id
            )
        )
        return self.db.execute(query).scalar_one_or_none()

    def get_all(self, business_id: UUID, skip: int = 0, limit: int = 100) -> List[T]:
        query = select(self.model).where(
            self.model.business_id == business_id
        ).offset(skip).limit(limit)
        return list(self.db.execute(query).scalars().all())

    def create(self, obj_in: T) -> T:
        self.db.add(obj_in)
        self.db.commit()
        self.db.refresh(obj_in)
        return obj_in
