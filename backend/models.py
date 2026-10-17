from datetime import datetime, timezone
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


def utc_now():
    return datetime.now(timezone.utc)


class Organization(db.Model):
    __tablename__ = "organizations"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    # "donor" = organization with surplus | "nonprofit" = recipient org
    org_type = db.Column(db.String(16), nullable=False, default="donor")
    verified = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=utc_now)
    users = db.relationship("User", backref="org", lazy=True)
    rooms = db.relationship("Room", backref="org", lazy=True)


class User(db.Model):
    __tablename__ = "users"
    id = db.Column(db.Integer, primary_key=True)
    org_id = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)


class Room(db.Model):
    __tablename__ = "rooms"
    id = db.Column(db.Integer, primary_key=True)
    org_id = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    name = db.Column(db.String(255), nullable=False)
    # URL in OCI Object Storage (or local path during dev)
    scan_url = db.Column(db.String(512), nullable=False, default="")
    created_at = db.Column(db.DateTime, default=utc_now)
    anchors = db.relationship("Anchor", backref="room", lazy=True, cascade="all, delete-orphan")


class Anchor(db.Model):
    __tablename__ = "anchors"
    id = db.Column(db.Integer, primary_key=True)
    room_id = db.Column(db.Integer, db.ForeignKey("rooms.id"), nullable=False)
    label = db.Column(db.String(255), default="")
    pos_x = db.Column(db.Float, nullable=False)
    pos_y = db.Column(db.Float, nullable=False)
    pos_z = db.Column(db.Float, nullable=False)
    n_x = db.Column(db.Float, nullable=False)
    n_y = db.Column(db.Float, nullable=False)
    n_z = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now)
    items = db.relationship("Item", backref="anchor", lazy=True, cascade="all, delete-orphan")


class Item(db.Model):
    __tablename__ = "items"
    id = db.Column(db.Integer, primary_key=True)
    anchor_id = db.Column(db.Integer, db.ForeignKey("anchors.id"), nullable=False)
    name = db.Column(db.String(255), nullable=False, default="")
    description = db.Column(db.Text, default="")
    category = db.Column(db.String(128), default="")
    # in_use | not_in_use | surplus | claimed | transferred
    status = db.Column(db.String(16), nullable=False, default="in_use")
    condition = db.Column(db.String(32), default="")   # new | good | fair | poor
    quantity = db.Column(db.Integer, default=1)
    weight_kg = db.Column(db.Float, default=0.0)
    photo_url = db.Column(db.String(512), default="")
    # OCI Gen AI embedding stored as JSON array string
    embedding = db.Column(db.Text, default="")
    created_at = db.Column(db.DateTime, default=utc_now)
    updated_at = db.Column(db.DateTime, default=utc_now, onupdate=utc_now)
    claims = db.relationship("Claim", backref="item", lazy=True)


class Claim(db.Model):
    __tablename__ = "claims"
    id = db.Column(db.Integer, primary_key=True)
    item_id = db.Column(db.Integer, db.ForeignKey("items.id"), nullable=False)
    nonprofit_org_id = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    # pending | approved | fulfilled | rejected
    status = db.Column(db.String(16), nullable=False, default="pending")
    notes = db.Column(db.Text, default="")
    requested_at = db.Column(db.DateTime, default=utc_now)
    fulfilled_at = db.Column(db.DateTime, nullable=True)


class ImpactLog(db.Model):
    __tablename__ = "impact_logs"
    id = db.Column(db.Integer, primary_key=True)
    org_id = db.Column(db.Integer, db.ForeignKey("organizations.id"), nullable=False)
    items_transferred = db.Column(db.Integer, default=0)
    weight_kg = db.Column(db.Float, default=0.0)
    # OCI Gen AI generated narrative
    report_text = db.Column(db.Text, default="")
    created_at = db.Column(db.DateTime, default=utc_now)
