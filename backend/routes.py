import os
import uuid
from flask import Blueprint, request, send_from_directory, current_app, redirect
from models import db, Organization, Room, Anchor, Object, Item, Request, TransactionHistory
from utils import allowed_scan, allowed_image
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
    email    = data.get("email", "").strip()
    name     = data.get("name", data.get("org_name", "")).strip()
    org_type = data.get("org_type", "donor")
    if not email or not name:
        return {"error": "email and name required"}, 400
    if Organization.query.filter_by(email=email).first():
        return {"error": "An account with that email already exists."}, 409
    org = Organization(name=name, email=email, org_type=org_type)
    db.session.add(org)
    db.session.commit()
    return {"user_id": org.id, "org_id": org.id, "org_type": org.org_type,
            "org_name": org.name, "email": org.email}, 201


@bp.route("/auth/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email", "").strip()
    if not email:
        return {"error": "email required"}, 400
    org = Organization.query.filter_by(email=email).first()
    if not org:
        return {"error": "No account found for that email."}, 404
    return {"user_id": org.id, "org_id": org.id, "org_type": org.org_type,
            "org_name": org.name, "email": org.email}


# ---------------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------------

@bp.route("/rooms", methods=["GET"])
def list_rooms():
    org_id  = request.args.get("org_id",  type=int)
    user_id = request.args.get("user_id", type=int)
    q = Room.query
    if org_id:
        q = q.filter_by(org_id=org_id)
    elif user_id:
        q = q.filter_by(org_id=user_id)
    rooms = [
        {"id": r.id, "name": r.name, "scan_url": r.glb_path, "created_at": r.created_at.isoformat()}
        for r in q.order_by(Room.created_at.desc()).all()
    ]
    return {"rooms": rooms}


@bp.route("/rooms", methods=["POST"])
def create_room():
    org_id  = request.form.get("org_id") or request.form.get("user_id")
    name    = request.form.get("name", "My Room")
    f       = request.files.get("file")

    if not (org_id and f and allowed_scan(f.filename)):
        return {"error": "org_id and scan file (glb/gltf/obj/usdz) required"}, 400

    try:
        ext       = f.filename.rsplit(".", 1)[1].lower()
        file_data = f.read()
        scan_url  = oci_client.upload_scan(file_data, ext)

        room = Room(org_id=int(org_id), name=name, glb_path=scan_url)
        db.session.add(room)
        db.session.commit()
        return {"room_id": room.id, "name": room.name, "scan_url": scan_url}, 201
    except Exception as e:
        db.session.rollback()
        return {"error": str(e)}, 500


@bp.route("/rooms/<int:room_id>/glb")
def room_glb(room_id):
    room = Room.query.get_or_404(room_id)
    return redirect(room.glb_path)


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
            "objects": [_obj_dict(obj) for obj in a.objects],
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
# Objects  (stores detected items until Item model is ready)
# ---------------------------------------------------------------------------

def _obj_dict(obj: Object) -> dict:
    return {
        "id": obj.id,
        "anchor_id": obj.anchor_id,
        "title": obj.title,
        "kind": obj.kind,
        "body": obj.body,
        "media_url": obj.media_url,
    }


@bp.route("/objects", methods=["POST"])
def create_object():
    data = request.json or {}
    if any(k not in data for k in ["anchor_id", "title"]):
        return {"error": "anchor_id and title required"}, 400
    obj = Object(
        anchor_id=int(data["anchor_id"]),
        title=data["title"],
        kind=data.get("kind", "text"),
        body=data.get("body", ""),
        media_url=data.get("media_url", ""),
    )
    db.session.add(obj)
    db.session.commit()
    return {"object_id": obj.id}, 201


# ---------------------------------------------------------------------------
# OCI Detection  — stateless, no model dependencies
# ---------------------------------------------------------------------------

@bp.route("/detect/photo", methods=["POST"])
def detect_photo():
    """
    Run OCI Vision + Gen AI on an uploaded photo.
    Returns structured item info (name, category, condition, description).
    No DB writes — caller creates anchor + object separately.
    """
    f = request.files.get("photo")
    if not f or not allowed_image(f.filename):
        return {"error": "photo (jpg/jpeg/png/heic) required"}, 400

    image_data = f.read()

    # Upload photo to OCI Object Storage (or local in dev)
    ext = f.filename.rsplit(".", 1)[1].lower()
    photo_url = oci_client.upload_photo(image_data, ext)

    # OCI Vision — classify, detect objects, OCR
    vision_result = oci_client.analyze_photo(image_data)

    # OCI Gen AI — structure into item fields
    structured = oci_client.structure_item(vision_result)

    return {
        "name": structured.get("name", ""),
        "category": structured.get("category", "other"),
        "condition": structured.get("condition", "good"),
        "description": structured.get("description", ""),
        "photo_url": photo_url,
        "vision_labels": [l["name"] for l in vision_result.get("labels", [])],
        "ocr_text": vision_result.get("text", []),
    }


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

def _item_dict(item):
    meta = item.custom_metadata or {}
    return {
        "id":           item.id,
        "anchor_id":    meta.get("anchor_id"),
        "owner_org_id": item.owner_org_id,
        "name":         item.title,
        "title":        item.title,
        "description":  item.description or "",
        "category":     item.category,
        "status":       item.status,
        "condition":    item.condition,
        "quantity":     item.quantity,
        "weight_kg":    item.weight_kg,
        "photo_url":    item.photo_url or "",
        "custom_metadata": meta,
        "created_at":   item.created_at.isoformat(),
        "updated_at":   None,
    }


@bp.route("/items", methods=["GET"])
def list_items():
    org_id   = request.args.get("org_id",   type=int)
    status   = request.args.get("status")
    category = request.args.get("category")
    q = Item.query
    if org_id:
        q = q.filter_by(owner_org_id=org_id)
    if status:
        q = q.filter_by(status=status)
    if category:
        q = q.filter_by(category=category)
    return {"items": [_item_dict(i) for i in q.order_by(Item.created_at.desc()).all()]}


@bp.route("/items", methods=["POST"])
def create_item():
    data = request.json or {}
    title        = data.get("title") or data.get("name", "")
    owner_org_id = data.get("owner_org_id")
    anchor_id    = data.get("anchor_id")

    # Derive owner from anchor when owner_org_id is not supplied
    if not owner_org_id and anchor_id:
        anchor = Anchor.query.get(int(anchor_id))
        if anchor:
            room = Room.query.get(anchor.room_id)
            if room:
                owner_org_id = room.org_id

    if not owner_org_id:
        return {"error": "owner_org_id (or anchor_id) required"}, 400

    item = Item(
        owner_org_id=int(owner_org_id),
        title=title or "Untitled",
        description=data.get("description", ""),
        category=data.get("category", "other"),
        status=data.get("status", "in_use"),
        condition=data.get("condition", "good"),
        quantity=int(data.get("quantity", 1)),
        weight_kg=float(data.get("weight_kg", 0.0)),
        photo_url="",
        custom_metadata={"anchor_id": anchor_id},
    )
    db.session.add(item)
    db.session.commit()
    return {"item_id": item.id}, 201


@bp.route("/items/<int:item_id>/photo", methods=["POST"])
def item_photo(item_id):
    item = Item.query.get_or_404(item_id)
    f = request.files.get("photo")
    if not f or not allowed_image(f.filename):
        return {"error": "photo (jpg/jpeg/png/heic) required"}, 400

    image_data = f.read()
    ext = f.filename.rsplit(".", 1)[1].lower()

    photo_url      = oci_client.upload_photo(image_data, ext)
    vision_result  = oci_client.analyze_photo(image_data)
    structured     = oci_client.structure_item(vision_result)

    if structured.get("name"):
        item.title = structured["name"]
    if structured.get("description"):
        item.description = structured["description"]
    if structured.get("category"):
        item.category = structured["category"]

    item.photo_url = photo_url
    if structured.get("condition"):
        item.condition = structured["condition"]
    db.session.commit()

    return {
        "item": _item_dict(item),
        "vision": {
            "labels":  [{"name": l["name"], "confidence": l.get("confidence", 1.0)} for l in vision_result.get("labels", [])],
            "objects": [{"name": o["name"], "confidence": o.get("confidence", 1.0)} for o in vision_result.get("objects", [])],
            "text":    vision_result.get("text", []),
        },
        "structured": structured,
    }


@bp.route("/items/<int:item_id>", methods=["PATCH"])
def update_item(item_id):
    item = Item.query.get_or_404(item_id)
    data = request.json or {}
    for field in ["title", "description", "category", "status", "custom_metadata"]:
        if field in data:
            setattr(item, field, data[field])
    db.session.commit()
    return _item_dict(item)


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

def _request_dict(req):
    return {
        "id":                   req.id,
        "item_id":              req.item_id,
        "requester_org_id":     req.requester_org_id,
        "request_type":         req.request_type,
        "borrow_duration_days": req.borrow_duration_days,
        "status":               req.status,
        "created_at":           req.created_at.isoformat(),
    }


@bp.route("/requests", methods=["POST"])
def create_request():
    data = request.json or {}
    required = ["item_id", "requester_org_id"]
    if any(k not in data for k in required):
        return {"error": f"{', '.join(required)} required"}, 400
    item = Item.query.get_or_404(int(data["item_id"]))
    if item.status not in ("available",):
        return {"error": "Item is not available."}, 409
    req = Request(
        item_id=item.id,
        requester_org_id=int(data["requester_org_id"]),
        request_type=data.get("request_type", "permanent_transfer"),
        borrow_duration_days=data.get("borrow_duration_days"),
    )
    item.status = "requested"
    db.session.add(req)
    db.session.commit()
    return {"request_id": req.id}, 201


@bp.route("/requests", methods=["GET"])
def list_requests():
    org_id = request.args.get("org_id", type=int)
    role   = request.args.get("role", "donor")
    q = Request.query
    if org_id and role == "recipient":
        q = q.filter_by(requester_org_id=org_id)
    elif org_id and role == "donor":
        q = q.join(Item).filter(Item.owner_org_id == org_id)
    return {"requests": [_request_dict(r) for r in q.order_by(Request.created_at.desc()).all()]}


@bp.route("/requests/<int:req_id>", methods=["PATCH"])
def update_request(req_id):
    req  = Request.query.get_or_404(req_id)
    data = request.json or {}
    new_status = data.get("status")
    if new_status not in {"approved", "rejected", "completed"}:
        return {"error": "status must be approved, rejected, or completed"}, 400
    req.status = new_status
    item = Item.query.get(req.item_id)
    if item:
        if new_status == "completed":
            item.status = "gone"
            history = TransactionHistory(
                item_id=item.id,
                item_title=item.title,
                donor_org_id=item.owner_org_id,
                recipient_org_id=req.requester_org_id,
                transaction_type=req.request_type,
            )
            db.session.add(history)
        elif new_status == "rejected":
            item.status = "available"
    db.session.commit()
    return {"ok": True, "status": req.status}
