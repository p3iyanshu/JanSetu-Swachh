from datetime import datetime
from app.models import CategoryType

SEVERITY_WEIGHTS = {
    CategoryType.SEWAGE: 5.0,
    CategoryType.GARBAGE: 4.0,
    CategoryType.WATER_LEAKAGE: 4.0,
    CategoryType.POTHOLE: 3.5,
    CategoryType.STREETLIGHT: 3.0,
    CategoryType.DAMAGED_PROPERTY: 2.5,
    CategoryType.ILLEGAL_DUMPING: 3.5,
    CategoryType.OTHER: 2.0,
    CategoryType.WASTE_BURNING: 5.0,
    CategoryType.PUBLIC_TOILET: 4.0,
    CategoryType.MISSED_PICKUP: 3.5,
    CategoryType.UNSEGREGATED_WASTE: 3.0,
}

def calculate_priority_score(
    category: CategoryType,
    upvote_count: int = 1,
    escalation_level: int = 0,
    created_at: datetime = None,
    sla_deadline: datetime = None
) -> float:
    base_severity = SEVERITY_WEIGHTS.get(category, 2.0)
    
    # Category severity score (0 to 100)
    category_component = base_severity * 20.0
    
    # Community upvote / duplicates weight
    upvote_component = min(upvote_count * 10.0, 50.0)
    
    # Escalation multiplier bonus
    escalation_component = escalation_level * 25.0
    
    total_score = category_component + upvote_component + escalation_component
    return round(total_score, 2)
