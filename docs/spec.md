# JanSetu Technical & Architectural Specification

Smart India Hackathon 2026 — Problem Statement SIH25031
Team JanSetu, Presidency University, Bengaluru

## Core Architectural Guarantees

1. **Accessibility First**:
   - Zero ward/zone dropdowns — automatic GPS reverse-geocoding.
   - Voice-to-text input available anywhere text descriptions are requested.
   - Minimum 48x48dp touch targets and 16sp font sizes.
   - OTP-only auth flow.

2. **Deduplication Engine**:
   - Geospatial distance calculation using PostGIS ST_DWithin / Haversine.
   - CLIP visual embedding cosine similarity matching.
   - Automatic upvote aggregation when nearby duplicates occur.

3. **Computer Vision Verified Closure**:
   - Before & After photo similarity validation.
   - Self-certification by municipal departments is prohibited by system design.

4. **Automated SLA & Escalation**:
   - Dynamic SLA deadlines based on category severity.
   - Background periodic worker triggers escalation levels and logs EscalationLog entries on breach.
