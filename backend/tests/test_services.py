from datetime import datetime, timedelta
from app.models import CategoryType
from app.services.sla import calculate_sla_deadline
from app.services.scoring import calculate_priority_score
from app.services.dedup import haversine_distance_meters

def test_sla_calculation():
    now = datetime(2026, 1, 1, 12, 0, 0)
    # Garbage overflow has 24h SLA
    garbage_deadline = calculate_sla_deadline(CategoryType.GARBAGE, created_at=now)
    assert garbage_deadline == now + timedelta(hours=24)

    # Pothole has 72h SLA
    pothole_deadline = calculate_sla_deadline(CategoryType.POTHOLE, created_at=now)
    assert pothole_deadline == now + timedelta(hours=72)

def test_priority_scoring():
    # Base sewage score (severity 5.0 * 20 = 100) + upvotes (1 * 10 = 10) = 110
    score = calculate_priority_score(CategoryType.SEWAGE, upvote_count=1)
    assert score == 110.0

    # With 3 upvotes and escalation level 1: 100 + 30 + 25 = 155
    score_esc = calculate_priority_score(CategoryType.SEWAGE, upvote_count=3, escalation_level=1)
    assert score_esc == 155.0

def test_haversine_distance():
    # Two points close to each other in Bangalore (~50m apart)
    lat1, lon1 = 13.0827, 77.5877
    lat2, lon2 = 13.0830, 77.5879
    dist = haversine_distance_meters(lat1, lon1, lat2, lon2)
    assert 30 <= dist <= 70
