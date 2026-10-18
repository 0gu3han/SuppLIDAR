"""
SuppLIDAR Priority Sorting Engine
---------------------------------
Calculates an Impact & Urgency Priority Score for surplus items based on:
1. Urgency / Expiration Risk (e.g. food expiring soon)
2. Recipient Community Need Match (e.g. charity request priority)
3. Carbon Footprint / Diverted Waste Impact (kg CO2 offset)
4. Distance / Logistics Feasibility (km)
"""

from datetime import datetime

def calculate_priority_score(item: dict, recipient_profile: dict = None) -> float:
    """
    Computes a weighted Priority Score (0 to 100+) for a surplus item.
    Higher score = Higher priority in the feed.
    """
    # 1. Urgency / Expiry Weight (0 - 40 points)
    # Higher urgency score means item must be moved quickly (e.g. fresh produce)
    urgency_raw = item.get("urgency_score", 5)  # 1 to 10 scale
    urgency_points = urgency_raw * 4.0

    # 2. Environmental Impact Score (0 - 30 points)
    # Estimated kg CO2 avoided by diverting from landfill
    co2_saved = item.get("co2_offset_kg", 10.0)
    impact_points = min(co2_saved * 0.5, 30.0)

    # 3. Category Match Bonus (0 - 20 points)
    category_points = 0.0
    if recipient_profile and "needed_categories" in recipient_profile:
        if item.get("category") in recipient_profile["needed_categories"]:
            category_points = 20.0

    # 4. Proximity / Logistics Score (0 - 10 points)
    # Penalty for distance to minimize transport hurdles
    distance_km = item.get("distance_km", 5.0)
    distance_points = max(0.0, 10.0 - (distance_km * 0.5))

    total_score = urgency_points + impact_points + category_points + distance_points
    return round(total_score, 2)


def sort_surplus_feed(items: list, recipient_profile: dict = None, sort_mode: str = "priority") -> list:
    """
    Sorts a list of surplus items according to the selected mode:
    - 'priority': Weighted Impact & Urgency Priority Algorithm (Default)
    - 'urgency': Highest urgency first
    - 'co2': Highest carbon offset first
    - 'newest': Most recently added
    """
    if not items:
        return []

    # Calculate dynamic priority score for each item
    for item in items:
        item["calculated_score"] = calculate_priority_score(item, recipient_profile)

    if sort_mode == "priority":
        return sorted(items, key=lambda x: x["calculated_score"], reverse=True)
    elif sort_mode == "urgency":
        return sorted(items, key=lambda x: x.get("urgency_score", 0), reverse=True)
    elif sort_mode == "co2":
        return sorted(items, key=lambda x: x.get("co2_offset_kg", 0), reverse=True)
    elif sort_mode == "newest":
        return sorted(items, key=lambda x: x.get("created_at", datetime.now()), reverse=True)

    return items
