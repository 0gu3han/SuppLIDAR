from datetime import datetime
from sqlalchemy import (
    create_engine, Column, Integer, String, Text, Float, DateTime, ForeignKey, JSON
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker

# 1. Base Class for Models
Base = declarative_base()


# 2. Organization Model (Donors & Recipient Charities)
class Organization(Base):
    __tablename__ = "organizations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    org_type = Column(String(50), nullable=False, default="donor")  # "donor" or "recipient"
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    items = relationship("Item", back_populates="owner", cascade="all, delete-orphan")
    requests = relationship("Request", back_populates="requester", cascade="all, delete-orphan")


# 3. Item Model (Surplus Inventory & LiDAR Scan Results)
class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    owner_org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=False, index=True)  # e.g., "Food", "Furniture", "Electronics"
    status = Column(String(50), nullable=False, default="available")  # "available", "requested", "borrowed", "gone"

    # Flexible JSON column to store LiDAR scan tags, urgency score, or special attributes
    custom_metadata = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    owner = relationship("Organization", back_populates="items")
    requests = relationship("Request", back_populates="item", cascade="all, delete-orphan")


# 4. Request Model (Borrowing & Transfer Requests)
class Request(Base):
    __tablename__ = "requests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    requester_org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    request_type = Column(String(50), nullable=False, default="permanent_transfer")  # "permanent_transfer" or "borrow"
    borrow_duration_days = Column(Integer, nullable=True)  # e.g., 7 for a 1-week loan
    status = Column(String(50), nullable=False, default="pending")  # "pending", "approved", "rejected", "completed"
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    item = relationship("Item", back_populates="requests")
    requester = relationship("Organization", back_populates="requests")


# 5. Transaction History Model (Audit log for "gone" items & carbon impact)
class TransactionHistory(Base):
    __tablename__ = "transaction_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    item_id = Column(Integer, nullable=False)  # Historical reference ID
    item_title = Column(String(255), nullable=False)
    donor_org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    recipient_org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    transaction_type = Column(String(50), nullable=False, default="transfer")  # "transfer" or "borrow"
    impact_co2_offset = Column(Float, default=0.0)  # Calculated carbon score
    completed_at = Column(DateTime, default=datetime.utcnow)


# ----------------------------------------------------
# OCI MySQL Connection Setup
# ----------------------------------------------------

# Replace values with your OCI MySQL DB IP, user, password, and database name.
DATABASE_URL = "mysql+pymysql://supplidar:SuppLIDAR123!@127.0.0.1:3306/supplidar"

engine = create_engine(
    DATABASE_URL,
    echo=True,           # Set to True if you want SQL queries printed in the terminal
    pool_pre_ping=True,  # Re-checks connection health automatically
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def init_db():
    """Call this function once at backend startup to create all tables in OCI MySQL."""
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables successfully created in OCI MySQL!")


if __name__ == "__main__":
    init_db()
