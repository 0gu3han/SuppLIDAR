# SuppLIDAR

Spatial surplus management platform that helps organizations reduce waste by making surplus visible, matching it to community needs, and simplifying the handoff from donor to recipient.

Built on the MENTIS spatial memory architecture, extended with Oracle Cloud Infrastructure (OCI) for AI-powered matching, computer vision, and scalable storage.

## How It Works

1. **Donor** scans a room with LiDAR, places AR anchors on items, takes a photo
2. **OCI Vision** analyzes the photo — auto-fills item name, category, condition, reads asset/expiry labels via OCR
3. **OCI Gen AI** embeds the item description for semantic search
4. **Nonprofit** browses surplus spatially (3D room view) or searches by need description
5. **OCI Gen AI** matches the need against surplus embeddings, returns ranked results
6. **Nonprofit** claims an item → donor approves → transfer logged for impact reporting

## Tech Stack

| Layer | Technology |
|---|---|
| iOS App | Swift, ARKit, RoomPlan (LiDAR), SceneKit |
| Backend | Python 3.11, Flask, SQLAlchemy |
| Database | MySQL (OCI Database Service) |
| File Storage | OCI Object Storage |
| Computer Vision | OCI Vision (classification, object detection, OCR) |
| AI Matching | OCI Gen AI — Cohere Embed v3 + Command R |

## Project Structure

```
SuppLIDAR/
├── backend/
│   ├── app.py          Flask factory, MySQL config
│   ├── models.py       SQLAlchemy models
│   ├── routes.py       REST API endpoints
│   ├── oci_client.py   OCI Vision, Gen AI, Object Storage
│   ├── utils.py        Helpers, file validation, cosine similarity
│   ├── requirements.txt
│   └── .env.example
└── IOS_app/
    ├── project.yml     XcodeGen config
    └── SuppLIDAR/
        ├── Models/     Codable structs
        ├── Network/    URLSession API client
        ├── Views/      SwiftUI views (donor + nonprofit flows)
        └── AR/         ARKit scene coordinator + placement
```

## Setup

### Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# fill in OCI credentials and MySQL connection string
python app.py
```

### iOS App

```bash
brew install xcodegen
cd IOS_app && xcodegen generate
open SuppLIDAR.xcodeproj
```

Set the server URL in `LoginView.swift` — use your Mac's LAN IP when running on a real device.

## API Contract

| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/register` | Register user + org |
| POST | `/auth/login` | Login |
| GET/POST | `/rooms` | List / create rooms |
| GET/POST | `/anchors` | List / create anchors |
| GET/POST | `/items` | List / create items |
| PATCH | `/items/<id>` | Update item status or fields |
| POST | `/items/<id>/photo` | Upload photo → OCI Vision + Gen AI auto-fill |
| GET | `/items/search?q=` | Semantic search against surplus embeddings |
| POST | `/claims` | Nonprofit claims a surplus item |
| PATCH | `/claims/<id>` | Donor approves / fulfills claim |
| GET | `/impact/<org_id>` | OCI Gen AI impact report for org |
| GET | `/health` | Health check |

## OCI Services

| Service | Purpose |
|---|---|
| OCI Vision | Classify item photos, detect objects, OCR asset tags and expiry dates |
| OCI Gen AI Embed | Embed item descriptions (Cohere Embed v3) for semantic search |
| OCI Gen AI Text | Structure free-text descriptions into item fields; generate impact reports |
| OCI Object Storage | Store room scans (.usdz), item photos, AR world maps (.arworldmap) |
| MySQL (OCI MDS) | Orgs, users, rooms, anchors, items, claims, impact logs |

## Team

- Person 1: Backend + OCI integrations (`backend/`)
- Person 2: iOS app (`IOS_app/`)
