"""
OCI integrations for SuppLIDAR:
  - Object Storage  : upload scan files and item photos
  - Vision          : classify item photos, detect objects, OCR labels/expiry dates
  - Generative AI   : structure item descriptions, embed text, generate impact reports
"""
import os
import json
import base64
import uuid

# ---------------------------------------------------------------------------
# OCI client setup
# ---------------------------------------------------------------------------

def _get_oci_config():
    config_file = os.environ.get("OCI_CONFIG_FILE", "~/.oci/config")
    profile = os.environ.get("OCI_CONFIG_PROFILE", "DEFAULT")
    import oci
    return oci.config.from_file(os.path.expanduser(config_file), profile)


def _object_storage_client():
    import oci
    return oci.object_storage.ObjectStorageClient(_get_oci_config())


def _vision_client():
    import oci
    return oci.ai_vision.AIServiceVisionClient(_get_oci_config())


def _genai_client():
    import oci
    endpoint = os.environ.get(
        "OCI_GENAI_ENDPOINT",
        "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com"
    )
    return oci.generative_ai_inference.GenerativeAiInferenceClient(
        _get_oci_config(),
        service_endpoint=endpoint
    )


BUCKET_NAME = os.environ.get("OCI_BUCKET_NAME", "supplidar-files")
OCI_NAMESPACE = os.environ.get("OCI_NAMESPACE", "")
OCI_REGION = os.environ.get("OCI_REGION", "us-chicago-1")
COMPARTMENT_ID = os.environ.get("OCI_COMPARTMENT_ID", "")
USE_LOCAL = os.environ.get("USE_LOCAL_STORAGE", "true").lower() == "true"

# ---------------------------------------------------------------------------
# Object Storage
# ---------------------------------------------------------------------------

def upload_file(file_data: bytes, object_name: str, content_type: str = "application/octet-stream") -> str:
    """Upload bytes to OCI Object Storage. Returns the public object URL."""
    if USE_LOCAL:
        upload_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "uploads"))
        path = os.path.join(upload_dir, object_name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(file_data)
        return f"/uploads/{object_name}"

    client = _object_storage_client()
    namespace = OCI_NAMESPACE or client.get_namespace().data
    client.put_object(
        namespace_name=namespace,
        bucket_name=BUCKET_NAME,
        object_name=object_name,
        put_object_body=file_data,
        content_type=content_type,
    )
    return (
        f"https://objectstorage.{OCI_REGION}.oraclecloud.com"
        f"/n/{namespace}/b/{BUCKET_NAME}/o/{object_name}"
    )


def upload_scan(file_data: bytes, ext: str) -> str:
    object_name = f"scans/{uuid.uuid4().hex}.{ext}"
    mime = {
        "usdz": "model/vnd.usdz+zip",
        "glb": "model/gltf-binary",
        "gltf": "model/gltf+json",
        "obj": "model/obj",
    }.get(ext, "application/octet-stream")
    return upload_file(file_data, object_name, mime)


def upload_photo(file_data: bytes, ext: str = "jpg") -> str:
    object_name = f"photos/{uuid.uuid4().hex}.{ext}"
    return upload_file(file_data, object_name, f"image/{ext}")


# ---------------------------------------------------------------------------
# OCI Vision
# ---------------------------------------------------------------------------

def analyze_photo(image_data: bytes) -> dict:
    """
    Run OCI Vision on an item photo.
    Returns:
      labels    : list of {name, confidence} — image classification
      objects   : list of {name, confidence} — detected objects
      text      : list of str — OCR extracted text (asset tags, expiry dates, etc.)
    """
    if USE_LOCAL:
        # Return a plausible mock so structure_item produces useful output in dev
        import random
        mock_items = [
            {"labels": [{"name": "Office Chair", "confidence": 0.92}, {"name": "Furniture", "confidence": 0.88}],
             "objects": [{"name": "Chair", "confidence": 0.90}], "text": []},
            {"labels": [{"name": "Desk", "confidence": 0.89}, {"name": "Office Furniture", "confidence": 0.85}],
             "objects": [{"name": "Table", "confidence": 0.87}], "text": ["IKEA", "BEKANT"]},
            {"labels": [{"name": "Laptop", "confidence": 0.94}, {"name": "Electronics", "confidence": 0.91}],
             "objects": [{"name": "Laptop Computer", "confidence": 0.93}], "text": ["Dell", "Latitude"]},
            {"labels": [{"name": "Monitor", "confidence": 0.91}, {"name": "Display", "confidence": 0.88}],
             "objects": [{"name": "Computer Monitor", "confidence": 0.90}], "text": ["24\"", "1080p"]},
            {"labels": [{"name": "Bookshelf", "confidence": 0.87}, {"name": "Storage", "confidence": 0.83}],
             "objects": [{"name": "Shelving Unit", "confidence": 0.85}], "text": []},
            {"labels": [{"name": "Printer", "confidence": 0.90}, {"name": "Office Equipment", "confidence": 0.86}],
             "objects": [{"name": "Laser Printer", "confidence": 0.88}], "text": ["HP", "LaserJet"]},
        ]
        return random.choice(mock_items)

    import oci

    client = _vision_client()
    b64 = base64.b64encode(image_data).decode()

    response = client.analyze_image(
        analyze_image_details=oci.ai_vision.models.AnalyzeImageDetails(
            features=[
                oci.ai_vision.models.ImageClassificationFeature(max_results=10),
                oci.ai_vision.models.ImageObjectDetectionFeature(max_results=10),
                oci.ai_vision.models.ImageTextDetectionFeature(),
            ],
            image=oci.ai_vision.models.InlineImageDetails(
                source="INLINE",
                data=b64,
            ),
        )
    )

    result = response.data
    labels = [
        {"name": lbl.name, "confidence": round(lbl.confidence, 3)}
        for lbl in (result.labels or [])
    ]
    objects = [
        {"name": obj.name, "confidence": round(obj.confidence, 3)}
        for obj in (result.objects or [])
    ]
    text = [word.text for word in (result.image_text.words if result.image_text else [])]

    return {"labels": labels, "objects": objects, "text": text}


# ---------------------------------------------------------------------------
# OCI Generative AI — text generation
# ---------------------------------------------------------------------------

def _chat(prompt: str, max_tokens: int = 512) -> str:
    """Send a prompt to Cohere Command R via OCI Gen AI. Returns empty string in local mode."""
    if USE_LOCAL:
        return ""  # callers handle empty → use label-based fallback

    import oci

    client = _genai_client()
    response = client.chat(
        chat_details=oci.generative_ai_inference.models.ChatDetails(
            compartment_id=COMPARTMENT_ID,
            serving_mode=oci.generative_ai_inference.models.OnDemandServingMode(
                model_id="cohere.command-r-plus"
            ),
            chat_request=oci.generative_ai_inference.models.CohereChatRequest(
                message=prompt,
                max_tokens=max_tokens,
                temperature=0.3,
            ),
        )
    )
    return response.data.chat_response.text.strip()


def _guess_category(label: str) -> str:
    label = label.lower()
    if any(w in label for w in ["chair", "desk", "table", "shelf", "sofa", "cabinet", "furniture"]):
        return "furniture"
    if any(w in label for w in ["laptop", "monitor", "computer", "printer", "keyboard", "phone", "tablet", "electronics"]):
        return "electronics"
    if any(w in label for w in ["medical", "hospital", "wheelchair", "bed", "stretcher"]):
        return "medical_equipment"
    if any(w in label for w in ["shirt", "jacket", "clothing", "uniform"]):
        return "clothing"
    if any(w in label for w in ["tool", "drill", "wrench", "hammer"]):
        return "tools"
    return "office_supplies"


def structure_item(vision_result: dict) -> dict:
    """
    Use OCI Gen AI to convert Vision output into structured item fields.
    Returns: {name, category, condition, description}
    """
    labels = ", ".join(v["name"] for v in vision_result.get("labels", []))
    objects_detected = ", ".join(v["name"] for v in vision_result.get("objects", []))
    ocr_text = " | ".join(vision_result.get("text", []))

    prompt = f"""You are a warehouse inventory assistant. Based on the following computer vision analysis of a surplus item photo, extract structured item information.

Vision labels: {labels or "none"}
Detected objects: {objects_detected or "none"}
OCR text from image: {ocr_text or "none"}

Respond with ONLY a JSON object with these fields:
- name: short item name (e.g. "Adjustable Hospital Bed")
- category: one of [medical_equipment, furniture, electronics, food, clothing, office_supplies, tools, other]
- condition: one of [new, good, fair, poor]
- description: 1-2 sentence description of the item

JSON:"""

    raw = _chat(prompt, max_tokens=256)
    if not raw:
        # USE_LOCAL fallback: derive structured output directly from vision labels
        top_label = (vision_result.get("labels") or [{}])[0].get("name", "")
        top_object = (vision_result.get("objects") or [{}])[0].get("name", "")
        name = top_object or top_label or "Surplus Item"
        ocr_hint = " ".join(vision_result.get("text", []))
        if ocr_hint:
            name = f"{name} ({ocr_hint[:30].strip()})"
        category = _guess_category(top_label or top_object)
        return {
            "name": name,
            "category": category,
            "condition": "good",
            "description": f"Detected as: {top_label}. {('OCR: ' + ocr_hint) if ocr_hint else ''}".strip(". "),
        }

    try:
        start = raw.find("{")
        end = raw.rfind("}") + 1
        return json.loads(raw[start:end])
    except (json.JSONDecodeError, ValueError):
        return {"name": "", "category": "other", "condition": "good", "description": raw}


# ---------------------------------------------------------------------------
# OCI Generative AI — embeddings
# ---------------------------------------------------------------------------

def embed_text(text: str) -> list[float]:
    """Embed a text string using OCI Cohere Embed v3."""
    if USE_LOCAL or not text.strip():
        return []

    import oci

    client = _genai_client()
    response = client.embed_text(
        embed_text_details=oci.generative_ai_inference.models.EmbedTextDetails(
            inputs=[text],
            serving_mode=oci.generative_ai_inference.models.OnDemandServingMode(
                model_id="cohere.embed-english-v3.0"
            ),
            input_type="SEARCH_DOCUMENT",
        )
    )
    embeddings = response.data.embeddings
    return embeddings[0] if embeddings else []


def embed_query(query: str) -> list[float]:
    """Embed a nonprofit search query (different input_type for better retrieval)."""
    if USE_LOCAL or not query.strip():
        return []

    import oci

    client = _genai_client()
    response = client.embed_text(
        embed_text_details=oci.generative_ai_inference.models.EmbedTextDetails(
            inputs=[query],
            serving_mode=oci.generative_ai_inference.models.OnDemandServingMode(
                model_id="cohere.embed-english-v3.0"
            ),
            input_type="SEARCH_QUERY",
        )
    )
    embeddings = response.data.embeddings
    return embeddings[0] if embeddings else []


# ---------------------------------------------------------------------------
# OCI Generative AI — impact reports
# ---------------------------------------------------------------------------

def generate_impact_report(stats: dict) -> str:
    """
    Generate a human-readable impact report narrative.
    stats: {org_name, items_transferred, weight_kg, categories, recipient_orgs, period}
    """
    prompt = f"""You are a sustainability report writer. Generate a concise, compelling 2-paragraph impact summary for an organization's surplus donation activity.

Organization: {stats.get('org_name', 'the organization')}
Period: {stats.get('period', 'this month')}
Items transferred: {stats.get('items_transferred', 0)}
Total weight diverted from landfill: {stats.get('weight_kg', 0)} kg
Item categories: {', '.join(stats.get('categories', []))}
Recipient organizations: {', '.join(stats.get('recipient_orgs', []))}

Write the report in a professional but warm tone. Mention specific numbers. End with one sentence about the broader community impact."""

    result = _chat(prompt, max_tokens=400)
    if not result:
        return (
            f"This period, {stats.get('org_name', 'your organization')} transferred "
            f"{stats.get('items_transferred', 0)} items totaling {stats.get('weight_kg', 0)} kg, "
            f"supporting {len(stats.get('recipient_orgs', []))} community organizations."
        )
    return result
