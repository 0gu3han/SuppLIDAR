import os
import uuid
import json
from datetime import datetime, timezone
from flask import Blueprint, request, jsonify, send_from_directory, current_app
from models import db, Organization, User, Room, Anchor, Item, Claim, ImpactLog
from utils import allowed_scan, allowed_image, cosine_similarity, parse_embedding
import oci_client

bp = Blueprint("api", __name__)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@bp.route("/health")
def health():
    return {"ok": True}


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

@bp.route("/auth/register", methods=["POST"])
def register():
    data = request.json or {}
    email = data.get("email", "").strip()
    org_name = data.get("org_name", "").strip()
    org_type = data.get("org_type", "donor")

    if not email or not org_name:
        return {"error": "email and org_name required"}, 400
    if org_type not in ("donor", "nonprofit"):
        return {"error": "org_type must be donor or nonprofit"}, 400
    if User.query.filter_by(email=email).first():
        return {"error": "An account with that email already exists."}, 409

    org = Organization(name=org_name, org_type=org_type)
    db.session.add(org)
    db.session.flush()
    user = User(org_id=org.id, email=email)
    db.session.add(user)
    db.session.commit()

    return {
        "user_id": user.id,
        "org_id": org.id,
        "org_type": org.org_type,
        "org_name": org.name,
        "email": user.email,
    }, 201


@bp.route("/auth/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email", "").strip()
    if not email:
        return {"error": "email required"}, 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return {"error": "No account found for that email."}, 404
    org = user.org
    return {
        "user_id": user.id,
        "org_id": org.id,
        "org_type": org.org_type,
        "org_name": org.name,
        "email": user.email,
    }


# ---------------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------------

@bp.route("/rooms", methods=["GET"])
def list_rooms():
    org_id = request.args.get("org_id", type=int)
    q = Room.query
    if org_id:
        q = q.filter_by(org_id=org_id)
    rooms = [
        {"id": r.id, "name": r.name, "scan_url": r.scan_url, "created_at": r.created_at.isoformat()}
        for r in q.order_by(Room.created_at.desc()).all()
    ]
    return {"rooms": rooms}


@bp.route("/rooms", methods=["POST"])
def create_room():
    org_id = request.form.get("org_id")
    name = request.form.get("name", "My Room")
    f = request.files.get("file")

    if not (org_id and f and allowed_scan(f.filename)):
        return {"error": "org_id and scan file (glb/gltf/obj/usdz) required"}, 400

    ext = f.filename.rsplit(".", 1)[1].lower()
    file_data = f.read()
    scan_url = oci_client.upload_scan(file_data, ext)

    room = Room(org_id=int(org_id), name=name, scan_url=scan_url)
    db.session.add(room)
    db.session.commit()
    return {"room_id": room.id, "name": room.name, "scan_url": scan_url}, 201


@bp.route("/rooms/<int:room_id>", methods=["DELETE"])
def delete_room(room_id):
    room = Room.query.get_or_404(room_id)
    db.session.delete(room)
    db.session.commit()
    return {"ok": True}


@bp.route("/uploads/<path:filename>")
def serve_upload(filename):
    upload_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "uploads"))
    return send_from_directory(upload_dir, filename)


# ---------------------------------------------------------------------------
# Anchors
# ---------------------------------------------------------------------------

@bp.route("/anchors", methods=["GET"])
def list_anchors():
    room_id = request.args.get("room_id", type=int)
    q = Anchor.query
    if room_id:
        q = q.filter_by(room_id=room_id)
    anchors = [
        {
            "id": a.id,
            "room_id": a.room_id,
            "label": a.label,
            "pos": [a.pos_x, a.pos_y, a.pos_z],
            "normal": [a.n_x, a.n_y, a.n_z],
            "items": [_item_dict(item) for item in a.items],
        }
        for a in q.order_by(Anchor.created_at.asc()).all()
    ]
    return {"anchors": anchors}


@bp.route("/anchors", methods=["POST"])
def create_anchor():
    data = request.json or {}
    if any(k not in data for k in ["room_id", "pos", "normal"]):
        return {"error": "room_id, pos[x,y,z], normal[x,y,z] required"}, 400
    pos = data["pos"]
    nrm = data["normal"]
    a = Anchor(
        room_id=int(data["room_id"]),
        label=data.get("label", ""),
        pos_x=float(pos[0]), pos_y=float(pos[1]), pos_z=float(pos[2]),
        n_x=float(nrm[0]), n_y=float(nrm[1]), n_z=float(nrm[2]),
    )
    db.session.add(a)
    db.session.commit()
    return {"anchor_id": a.id}, 201


@bp.route("/anchors/<int:anchor_id>", methods=["DELETE"])
def delete_anchor(anchor_id):
    a = Anchor.query.get_or_404(anchor_id)
    db.session.delete(a)
    db.session.commit()
    return {"ok": True}


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

def _item_dict(item: Item) -> dict:
    return {
        "id": item.id,
        "anchor_id": item.anchor_id,
        "name": item.name,
        "description": item.description,
        "category": item.category,
        "status": item.status,
        "condition": item.condition,
        "quantity": item.quantity,
        "weight_kg": item.weight_kg,
        "photo_url": item.photo_url,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat() if item.updated_at else None,
    }


@bp.route("/items", methods=["GET"])
def list_items():
    anchor_id = request.args.get("anchor_id", type=int)
    room_id = request.args.get("room_id", type=int)
    org_id = request.args.get("org_id", type=int)
    status = request.args.get("status")

    q = db.session.query(Item).join(Anchor)
    if anchor_id:
        q = q.filter(Item.anchor_id == anchor_id)
    if room_id:
        q = q.filter(Anchor.room_id == room_id)
    if org_id:
        q = q.join(Room).filter(Room.org_id == org_id)
    if status:
        q = q.filter(Item.status == status)

    return {"items": [_item_dict(i) for i in q.order_by(Item.created_at.desc()).all()]}


@bp.route("/items", methods=["POST"])
def create_item():
    data = request.json or {}
    if "anchor_id" not in data:
        return {"error": "anchor_id required"}, 400

    item = Item(
        anchor_id=int(data["anchor_id"]),
        name=data.get("name", ""),
        description=data.get("description", ""),
        category=data.get("category", ""),
        status=data.get("status", "in_use"),
        condition=data.get("condition", ""),
        quantity=int(data.get("quantity", 1)),
        weight_kg=float(data.get("weight_kg", 0.0)),
    )
    db.session.add(item)
    db.session.commit()

    # Generate and store embedding in background if description is available
    if item.description or item.name:
        _embed_and_save(item)

    return {"item_id": item.id}, 201


@bp.route("/items/<int:item_id>", methods=["PATCH"])
def update_item(item_id):
    item = Item.query.get_or_404(item_id)
    data = request.json or {}
    allowed_fields = {"name", "description", "category", "status", "condition", "quantity", "weight_kg"}
    for field in allowed_fields:
        if field in data:
            setattr(item, field, data[field])
    db.session.commit()

    # Re-embed if text fields changed
    if "description" in data or "name" in data:
        _embed_and_save(item)

    return _item_dict(item)


@bp.route("/items/<int:item_id>/photo", methods=["POST"])
def upload_item_photo(item_id):
    """
    Upload a photo for an item.
    Triggers OCI Vision analysis → OCI Gen AI structuring → updates item fields.
    """
    item = Item.query.get_or_404(item_id)
    f = request.files.get("photo")
    if not f or not allowed_image(f.filename):
        return {"error": "photo (jpg/jpeg/png/heic) required"}, 400

    ext = f.filename.rsplit(".", 1)[1].lower()
    image_data = f.read()

    # Upload to OCI Object Storage
    photo_url = oci_client.upload_photo(image_data, ext)
    item.photo_url = photo_url

    # OCI Vision analysis
    vision_result = oci_client.analyze_photo(image_data)

    # OCI Gen AI structuring
    structured = oci_client.structure_item(vision_result)
    if structured.get("name") and not item.name:
        item.name = structured["name"]
    if structured.get("category") and not item.category:
        item.category = structured["category"]
    if structured.get("condition") and not item.condition:
        item.condition = structured["condition"]
    if structured.get("description") and not item.description:
        item.description = structured["description"]

    db.session.commit()
    _embed_and_save(item)

    return {
        "item": _item_dict(item),
        "vision": vision_result,
        "structured": structured,
    }


@bp.route("/items/<int:item_id>/analyze", methods=["POST"])
def analyze_item(item_id):
    """Re-run OCI Vision + Gen AI on the item's existing photo URL."""
    item = Item.query.get_or_404(item_id)
    if not item.photo_url:
        return {"error": "No photo uploaded for this item yet."}, 400

    # For local dev, photo is on disk
    if item.photo_url.startswith("/uploads/"):
        upload_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "uploads"))
        photo_path = os.path.join(upload_dir, item.photo_url.lstrip("/uploads/"))
        try:
            with open(photo_path, "rb") as fh:
                image_data = fh.read()
        except OSError:
            return {"error": "Photo file not found on server."}, 404
    else:
        import urllib.request
        with urllib.request.urlopen(item.photo_url) as resp:
            image_data = resp.read()

    vision_result = oci_client.analyze_photo(image_data)
    structured = oci_client.structure_item(vision_result)

    return {"vision": vision_result, "structured": structured}


@bp.route("/items/search", methods=["GET"])
def search_surplus():
    """
    Semantic search over surplus items using OCI Gen AI embeddings.
    ?q=we need wheelchairs and hospital beds
    &org_id=2   (optional: restrict to a donor org's surplus)
    """
    query = request.args.get("q", "").strip()
    org_id = request.args.get("org_id", type=int)

    if not query:
        return {"error": "q (search query) required"}, 400

    # Embed the query
    query_embedding = oci_client.embed_query(query)

    # Fetch all surplus items that have embeddings
    q = db.session.query(Item).join(Anchor).join(Room).filter(Item.status == "surplus")
    if org_id:
        q = q.filter(Room.org_id == org_id)
    items = q.all()

    if not query_embedding:
        # Fallback: simple text search when OCI is not available
        lower_q = query.lower()
        results = [
            {"item": _item_dict(i), "score": 1.0}
            for i in items
            if lower_q in i.name.lower() or lower_q in i.description.lower()
        ]
        return {"results": results[:20]}

    # Score each item by cosine similarity
    scored = []
    for item in items:
        emb = parse_embedding(item.embedding)
        if emb:
            score = cosine_similarity(query_embedding, emb)
            scored.append((score, item))

    scored.sort(key=lambda x: x[0], reverse=True)
    results = [
        {"item": _item_dict(item), "score": round(score, 4)}
        for score, item in scored[:20]
        if score > 0.3
    ]
    return {"results": results}


# ---------------------------------------------------------------------------
# Claims
# ---------------------------------------------------------------------------

@bp.route("/claims", methods=["POST"])
def create_claim():
    data = request.json or {}
    required = ["item_id", "nonprofit_org_id", "user_id"]
    if any(k not in data for k in required):
        return {"error": f"{', '.join(required)} required"}, 400

    item = Item.query.get_or_404(int(data["item_id"]))
    if item.status != "surplus":
        return {"error": "Item is not marked as surplus."}, 409

    claim = Claim(
        item_id=item.id,
        nonprofit_org_id=int(data["nonprofit_org_id"]),
        user_id=int(data["user_id"]),
        notes=data.get("notes", ""),
    )
    item.status = "claimed"
    db.session.add(claim)
    db.session.commit()
    return {"claim_id": claim.id}, 201


@bp.route("/claims", methods=["GET"])
def list_claims():
    org_id = request.args.get("org_id", type=int)
    role = request.args.get("role", "donor")

    q = Claim.query
    if org_id and role == "nonprofit":
        q = q.filter_by(nonprofit_org_id=org_id)
    elif org_id and role == "donor":
        q = q.join(Item).join(Anchor).join(Room).filter(Room.org_id == org_id)

    claims = [
        {
            "id": c.id,
            "item_id": c.item_id,
            "nonprofit_org_id": c.nonprofit_org_id,
            "status": c.status,
            "notes": c.notes,
            "requested_at": c.requested_at.isoformat(),
            "fulfilled_at": c.fulfilled_at.isoformat() if c.fulfilled_at else None,
        }
        for c in q.order_by(Claim.requested_at.desc()).all()
    ]
    return {"claims": claims}


@bp.route("/claims/<int:claim_id>", methods=["PATCH"])
def update_claim(claim_id):
    claim = Claim.query.get_or_404(claim_id)
    data = request.json or {}
    new_status = data.get("status")

    valid = {"approved", "fulfilled", "rejected"}
    if new_status not in valid:
        return {"error": f"status must be one of {valid}"}, 400

    claim.status = new_status
    item = Item.query.get(claim.item_id)

    if new_status == "fulfilled":
        claim.fulfilled_at = datetime.now(timezone.utc)
        if item:
            item.status = "transferred"
    elif new_status == "rejected":
        if item and item.status == "claimed":
            item.status = "surplus"

    db.session.commit()
    return {"ok": True, "claim_status": claim.status}


# ---------------------------------------------------------------------------
# Impact Reports
# ---------------------------------------------------------------------------

@bp.route("/impact/<int:org_id>", methods=["GET"])
def get_impact(org_id):
    org = Organization.query.get_or_404(org_id)

    fulfilled = (
        db.session.query(Claim)
        .join(Item)
        .join(Anchor)
        .join(Room)
        .filter(Room.org_id == org_id, Claim.status == "fulfilled")
        .all()
    )

    items_transferred = len(fulfilled)
    weight_kg = sum(
        Item.query.get(c.item_id).weight_kg
        for c in fulfilled
        if Item.query.get(c.item_id)
    )
    categories = list({
        Item.query.get(c.item_id).category
        for c in fulfilled
        if Item.query.get(c.item_id) and Item.query.get(c.item_id).category
    })
    recipient_org_ids = list({c.nonprofit_org_id for c in fulfilled})
    recipient_orgs = [
        org.name for org in Organization.query.filter(Organization.id.in_(recipient_org_ids)).all()
    ]

    stats = {
        "org_name": org.name,
        "period": "to date",
        "items_transferred": items_transferred,
        "weight_kg": round(weight_kg, 2),
        "categories": categories,
        "recipient_orgs": recipient_orgs,
    }

    report_text = oci_client.generate_impact_report(stats)

    log = ImpactLog(
        org_id=org_id,
        items_transferred=items_transferred,
        weight_kg=weight_kg,
        report_text=report_text,
    )
    db.session.add(log)
    db.session.commit()

    return {**stats, "report": report_text}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _embed_and_save(item: Item):
    """Embed item text and store in DB. Silently skips if OCI is unavailable."""
    try:
        text = f"{item.name} {item.description} {item.category} {item.condition}".strip()
        embedding = oci_client.embed_text(text)
        if embedding:
            item.embedding = json.dumps(embedding)
            db.session.commit()
    except Exception:
        pass
