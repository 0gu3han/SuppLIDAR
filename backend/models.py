from datetime import datetime
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


def utc_now():
    return datetime.utcnow()


# ---------------------------------------------------------------------------
# Organization  (replaces User — handles both donors and recipients)
# ---------------------------------------------------------------------------

class Organization(db.Model):
    __tablename__ = "organizations"

    id            = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name          = db.Column(db.String(255), nullable=False)
    email         = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False, default="")
    org_type      = db.Column(db.String(50), nullable=False, default="donor")  # "donor" | "recipient"
    created_at    = db.Column(db.DateTime, default=utc_now)

    items    = db.relationship("Item",   back_populates="owner",     cascade="all, delete-orphan")
    requests = db.relationship("Request", back_populates="requester", cascade="all, delete-orphan")
    rooms    = db.relationship("Room",   back_populates="org",       lazy=True)


# ---------------------------------------------------------------------------
# Room + Anchor + Object  (spatial layer for AR scanning)
# ---------------------------------------------------------------------------

class Room(db.Model):
    __tablename__ = "rooms"

    id         = db.Column(db.Integer, primary_key=True)
    org_id     = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    name       = db.Column(db.String(255), nullable=False)
    glb_path   = db.Column(db.String(512), nullable=False, default="")
    created_at = db.Column(db.DateTime, default=utc_now)

    org     = db.relationship("Organization", back_populates="rooms")
    anchors = db.relationship("Anchor", backref="room", lazy=True, cascade="all, delete-orphan")


class Anchor(db.Model):
    __tablename__ = "anchors"

    id         = db.Column(db.Integer, primary_key=True)
    room_id    = db.Column(db.Integer, db.ForeignKey("rooms.id"), nullable=False)
    label      = db.Column(db.String(255), default="")
    pos_x      = db.Column(db.Float, nullable=False)
    pos_y      = db.Column(db.Float, nullable=False)
    pos_z      = db.Column(db.Float, nullable=False)
    n_x        = db.Column(db.Float, nullable=False)
    n_y        = db.Column(db.Float, nullable=False)
    n_z        = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)

    objects = db.relationship("Object", backref="anchor", lazy=True, cascade="all, delete-orphan")


class Object(db.Model):
    __tablename__ = "objects"

    id         = db.Column(db.Integer, primary_key=True)
    anchor_id  = db.Column(db.Integer, db.ForeignKey("anchors.id"), nullable=False)
    title      = db.Column(db.String(255), nullable=False)
    kind       = db.Column(db.String(32), default="text")
    body       = db.Column(db.Text, default="")
    media_url  = db.Column(db.String(512), default="")
    created_at = db.Column(db.DateTime, default=utc_now)


# ---------------------------------------------------------------------------
# Item  (surplus inventory with OCI Vision metadata)
# ---------------------------------------------------------------------------

class Item(db.Model):
    __tablename__ = "items"

    id              = db.Column(db.Integer, primary_key=True, autoincrement=True)
    owner_org_id    = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    title           = db.Column(db.String(255), nullable=False)
    description     = db.Column(db.Text, nullable=True)
    category        = db.Column(db.String(100), nullable=False, index=True)
    # "available" | "requested" | "borrowed" | "gone"
    status          = db.Column(db.String(50), nullable=False, default="available")
    condition       = db.Column(db.String(50), nullable=False, default="good")
    # Stores OCI Vision labels, weight, photo_url, embedding, etc.
    custom_metadata = db.Column(db.JSON, nullable=True)
    created_at      = db.Column(db.DateTime, default=utc_now)

    owner    = db.relationship("Organization", back_populates="items")
    requests = db.relationship("Request", back_populates="item", cascade="all, delete-orphan")


# ---------------------------------------------------------------------------
# Request  (borrow or transfer requests from recipients)
# ---------------------------------------------------------------------------

class Request(db.Model):
    __tablename__ = "requests"

    id                  = db.Column(db.Integer, primary_key=True, autoincrement=True)
    item_id             = db.Column(db.Integer, db.ForeignKey("items.id"), nullable=False)
    requester_org_id    = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    # "permanent_transfer" | "borrow"
    request_type        = db.Column(db.String(50), nullable=False, default="permanent_transfer")
    borrow_duration_days = db.Column(db.Integer, nullable=True)
    # "pending" | "approved" | "rejected" | "completed"
    status              = db.Column(db.String(50), nullable=False, default="pending")
    created_at          = db.Column(db.DateTime, default=utc_now)

    item      = db.relationship("Item", back_populates="requests")
    requester = db.relationship("Organization", back_populates="requests")


# ---------------------------------------------------------------------------
# TransactionHistory  (audit log + carbon impact)
# ---------------------------------------------------------------------------

class TransactionHistory(db.Model):
    __tablename__ = "transaction_history"

    id               = db.Column(db.Integer, primary_key=True, autoincrement=True)
    item_id          = db.Column(db.Integer, nullable=False)
    item_title       = db.Column(db.String(255), nullable=False)
    donor_org_id     = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    recipient_org_id = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    # "transfer" | "borrow"
    transaction_type = db.Column(db.String(50), nullable=False, default="transfer")
    impact_co2_offset = db.Column(db.Float, default=0.0)
    completed_at     = db.Column(db.DateTime, default=utc_now)
