import os
import uuid
from flask import Blueprint, request, send_from_directory
from models import db, User, Room, Anchor, Object
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
    email = data.get("email", "").strip()
    if not email:
        return {"error": "email required"}, 400
    if User.query.filter_by(email=email).first():
        return {"error": "An account with that email already exists."}, 409
    user = User(email=email)
    db.session.add(user)
    db.session.commit()
    return {"user_id": user.id, "email": user.email}, 201


@bp.route("/auth/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email", "").strip()
    if not email:
        return {"error": "email required"}, 400
    user = User.query.filter_by(email=email).first()
    if not user:
        return {"error": "No account found for that email."}, 404
    return {"user_id": user.id, "email": user.email}


# ---------------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------------

@bp.route("/rooms", methods=["GET"])
def list_rooms():
    user_id = request.args.get("user_id", type=int)
    q = Room.query
    if user_id:
        q = q.filter_by(user_id=user_id)
    rooms = [
        {
            "id": r.id,
            "name": r.name,
            "scan_url": r.glb_path,
            "created_at": r.created_at.isoformat(),
        }
        for r in q.order_by(Room.created_at.desc()).all()
    ]
    return {"rooms": rooms}


@bp.route("/rooms", methods=["POST"])
def create_room():
    user_id = request.form.get("user_id")
    name = request.form.get("name", "My Room")
    f = request.files.get("file")

    if not (user_id and f and allowed_scan(f.filename)):
        return {"error": "user_id and scan file (glb/gltf/obj/usdz) required"}, 400

    ext = f.filename.rsplit(".", 1)[1].lower()
    file_data = f.read()
    scan_url = oci_client.upload_scan(file_data, ext)

    room = Room(user_id=int(user_id), name=name, glb_path=scan_url)
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
# TODO (friend's models needed): /items, /claims, /impact
# ---------------------------------------------------------------------------
