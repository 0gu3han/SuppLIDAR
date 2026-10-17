# SuppLIDAR

Spatial surplus management platform that helps organizations reduce waste by making surplus visible, matching it to community needs, and simplifying the handoff from donor to recipient.

Built on the MENTIS spatial memory architecture, extended with Oracle Cloud Infrastructure (OCI) for AI-powered matching, computer vision, and scalable storage.

---

## How It Works

1. **Spatial Room Scanning:** Donors use mobile LiDAR scanning (Apple RoomPlan / ARKit) to rapidly capture 3D room layouts and item inventories without tedious manual data entry.
2. **AI Enrichment & Parsing:** The scanning payload (2D snapshots & object JSON) is sent to OCI Generative AI and Vision services to automatically categorize items, rate urgency/condition, and estimate diverted carbon impact.
3. **Smart Matching & Feed:** Recipient charities browse an emergency-sorted feed where OCI-driven algorithms prioritize expiring food and high-need equipment for local non-profits.
4. **Handoff & Audit Log:** Requisitions and transfers are tracked in an immutable transaction history to verify waste reduction metrics.

---

## Tech Stack

* **Backend Framework:** Python (Flask / FastAPI)
* **Database & ORM:** MySQL / MariaDB via SQLAlchemy
* **AI & Cloud Infrastructure:** Oracle Cloud Infrastructure (OCI Generative AI & OCI Vision)
* **Spatial Scanning:** Mobile LiDAR (ARKit / RoomPlan 3D JSON export)
* **Frontend:** HTML5, CSS3, JavaScript (Flask Templates)

---

## Project Structure

```text
SuppLIDAR/
├── app.py                   # Main backend application server & routing
├── database.py              # SQLAlchemy database connection & schema models
├── README.md                # Project documentation
├── templates/               # HTML Page Skeletons
│   ├── index.html           # Page 1: Landing page & core mission statement
│   ├── sorting.html         # Page 2: Surplus inventory feed, filters & AI assistant
│   └── profile.html         # Page 3: Dashboard, user inventory & scanned rooms
├── static/                  # CSS styles, JavaScript, and media assets
├── modules/                 # Modular backend logic
│   ├── __init__.py
│   ├── sorting.py           # Feed sorting & priority matching algorithms
│   └── oci_ai.py            # OCI AI integration scripts
└── lidar/                   # LiDAR spatial processing
    ├── __init__.py
    └── parser.py            # LiDAR JSON payload parser & spatial metadata extraction
```

---

## Setup & Installation

<!-- Placeholder: Add local installation, python environment setup, and database config instructions here -->

---

## API Endpoints

<!-- Placeholder: Document REST API endpoints (e.g., /items, /scan, /profile) here -->

---

## LiDAR Processing Pipeline

<!-- Placeholder: Add details on raw 3D depth map & JSON room plan processing -->

---

## HackTN 2026 Challenge Alignment

<!-- Placeholder: Document alignment with #HackTN 2026 Prompt #1 (From Surplus to Social Good) -->

---

## Team & Acknowledgments

<!-- Placeholder: Team member roles, mentors, and credits -->
