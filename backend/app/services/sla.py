from datetime import datetime, timedelta
from app.models import CategoryType

# Default SLA hours per category
SLA_HOURS = {
    CategoryType.GARBAGE: 24,
    CategoryType.SEWAGE: 24,
    CategoryType.WATER_LEAKAGE: 24,
    CategoryType.STREETLIGHT: 48,
    CategoryType.POTHOLE: 72,
    CategoryType.ILLEGAL_DUMPING: 48,
    CategoryType.DAMAGED_PROPERTY: 96,
    CategoryType.OTHER: 48,
    # Swachh segment - open burning is a health hazard, so it's cleared fastest
    CategoryType.WASTE_BURNING: 12,
    CategoryType.MISSED_PICKUP: 24,
    CategoryType.PUBLIC_TOILET: 24,
    CategoryType.UNSEGREGATED_WASTE: 48,
}

def calculate_sla_deadline(category: CategoryType, created_at: datetime = None) -> datetime:
    if created_at is None:
        created_at = datetime.utcnow()
    hours = SLA_HOURS.get(category, 48)
    return created_at + timedelta(hours=hours)
