"""Household waste segregation guide.

Follows the four-stream segregation-at-source mandated by the Solid Waste
Management Rules, 2026 (in force from 1 April 2026): wet, dry, sanitary and
special care waste. The same data powers the citizen app's "Which Bin?"
screen (which also bundles an offline copy) and the AI item classifier's
label -> stream mapping.
"""

WASTE_STREAMS = [
    {
        "id": "wet",
        "name": "Wet Waste",
        "bin": "Green bin",
        "color": "#2E7D32",
        "summary": "Biodegradable kitchen and garden waste.",
        "goes_to": "Composted or processed through bio-methanation.",
        "tips": [
            "Drain excess liquid before putting it in the bin.",
            "Never mix plastic or wrappers into wet waste.",
            "Home composting turns this into free manure for plants.",
        ],
    },
    {
        "id": "dry",
        "name": "Dry Waste",
        "bin": "Blue bin",
        "color": "#1565C0",
        "summary": "Plastic, paper, metal, glass, wood, rubber and cloth.",
        "goes_to": "Material Recovery Facility (MRF) for sorting and recycling.",
        "tips": [
            "Rinse milk packets and food containers so they can be recycled.",
            "Flatten cartons and bottles to save space.",
            "Wrap broken glass in paper and mark it 'sharp'.",
        ],
    },
    {
        "id": "sanitary",
        "name": "Sanitary Waste",
        "bin": "Wrapped & marked separately",
        "color": "#C62828",
        "summary": "Diapers, sanitary pads, tampons, condoms and soiled dressings.",
        "goes_to": "Collected separately and sent for safe incineration.",
        "tips": [
            "Wrap securely in newspaper or the pouch provided.",
            "Mark the packet with a red dot so collectors can handle it safely.",
            "Never flush it - it chokes drains and sewers.",
        ],
    },
    {
        "id": "special_care",
        "name": "Special Care Waste",
        "bin": "Separate bag - hand over on collection day",
        "color": "#6A1B9A",
        "summary": "Household hazardous and e-waste: batteries, bulbs, medicines, paint, chemicals.",
        "goes_to": "Authorised hazardous-waste and e-waste handlers.",
        "tips": [
            "Keep it in a separate bag or box, away from children.",
            "Hand it over only to the designated collector or drop-off point.",
            "Never burn it or throw it into drains or open plots.",
        ],
    },
]

# (item name, stream id, disposal tip)
WASTE_ITEMS = [
    ("Vegetable & fruit peels", "wet", "Straight into the green bin or your compost pit."),
    ("Leftover cooked food", "wet", "Drain gravies first; no plastic wrap."),
    ("Tea leaves & coffee grounds", "wet", "Great for compost."),
    ("Eggshells", "wet", "Crush them so they compost faster."),
    ("Meat, fish & bones", "wet", "Wrap in newspaper to avoid smell."),
    ("Flowers & pooja waste", "wet", "Remove plastic, thread and foil first."),
    ("Garden leaves & grass", "wet", "Large volumes can go to ward garden-waste collection."),
    ("Coconut shells", "wet", "Break into pieces; some wards collect them separately."),
    ("Spoiled grains & flour", "wet", "Compost or green bin."),
    ("Paper napkins & tissues (food-soiled)", "wet", "Compostable if not chemically treated."),
    ("Plastic bottles", "dry", "Rinse, crush and cap."),
    ("Milk & oil packets", "dry", "Cut open, rinse and dry before binning."),
    ("Plastic carry bags", "dry", "Bundle together; better still, carry a cloth bag."),
    ("Chips & biscuit wrappers", "dry", "Multi-layer plastic - keep clean and dry."),
    ("Newspapers & magazines", "dry", "Keep dry; sell to the kabadiwala."),
    ("Cardboard boxes", "dry", "Flatten before handing over."),
    ("Tetra Pak cartons", "dry", "Rinse and flatten."),
    ("Glass bottles & jars", "dry", "Rinse; keep separate from other dry waste if possible."),
    ("Broken glass", "dry", "Wrap in paper and label 'sharp'."),
    ("Metal cans & foil", "dry", "Rinse and flatten."),
    ("Thermocol / styrofoam", "dry", "Break into pieces and keep dry."),
    ("Old clothes & shoes", "dry", "Donate if usable, otherwise dry waste."),
    ("Rubber & leather items", "dry", "Dry bin."),
    ("Wood pieces & furniture scrap", "dry", "Large items: request bulky-waste pickup."),
    ("Plastic toys & buckets", "dry", "Dry bin or recycler."),
    ("Disposable plates & cups (plastic)", "dry", "Scrape off food, then dry bin."),
    ("Diapers", "sanitary", "Wrap in newspaper and mark with a red dot."),
    ("Sanitary pads & tampons", "sanitary", "Wrap securely and mark with a red dot."),
    ("Condoms", "sanitary", "Wrap and mark before handing over."),
    ("Used masks & gloves", "sanitary", "Cut the straps, wrap and keep separately."),
    ("Blood-soiled cotton & bandages", "sanitary", "Wrap securely; never mix with wet waste."),
    ("Batteries", "special_care", "Tape the terminals; hand over as special care waste."),
    ("CFL & tube lights", "special_care", "Contain mercury - do not break; pack carefully."),
    ("Mobile phones & chargers", "special_care", "E-waste - use an authorised e-waste collector."),
    ("Old electronics & cables", "special_care", "E-waste - never burn cables for copper."),
    ("Expired medicines", "special_care", "Keep in original strips; hand over as special care."),
    ("Syringes & needles", "special_care", "Put in a hard container with a lid before handing over."),
    ("Paint & varnish cans", "special_care", "Close tightly; hand over as special care waste."),
    ("Pesticide & cleaning chemical containers", "special_care", "Do not rinse into drains."),
    ("Aerosol spray cans", "special_care", "Do not puncture or burn."),
    ("Mercury thermometers", "special_care", "Pack in a sealed container."),
    ("Printer cartridges", "special_care", "Return to the brand take-back point or e-waste collector."),
    ("Nail polish & remover", "special_care", "Keep tightly closed; special care bag."),
]

# Keyword -> stream fallback for free-text AI labels (e.g. "biodegradable",
# "cardboard", "battery") that don't exactly match an item name above.
LABEL_KEYWORDS = {
    "wet": ["food", "organic", "biodegradable", "vegetable", "fruit", "peel", "leaf", "leaves",
            "garden", "compost", "kitchen", "egg", "bone", "flower", "wet"],
    "dry": ["plastic", "paper", "cardboard", "carton", "metal", "glass", "bottle", "can",
            "tin", "wrapper", "packet", "cloth", "textile", "rubber", "wood", "thermocol",
            "styrofoam", "recyclable", "dry", "trash"],
    "sanitary": ["diaper", "pad", "sanitary", "tampon", "mask", "glove", "bandage", "cotton", "medical"],
    "special_care": ["battery", "batteries", "e-waste", "ewaste", "electronic", "bulb",
                     "cfl", "tube light", "tubelight", "medicine", "pill", "syringe", "needle", "paint",
                     "chemical", "pesticide", "hazard", "aerosol", "thermometer", "cartridge"],
}


def waste_guide_payload() -> dict:
    return {
        "source": "Solid Waste Management Rules, 2026 - four-stream segregation at source",
        "streams": WASTE_STREAMS,
        "items": [
            {"name": name, "stream": stream, "tip": tip}
            for name, stream, tip in WASTE_ITEMS
        ],
    }


def stream_for_label(label: str):
    """Map a free-text label (e.g. an AI model class name) to a stream id."""
    needle = (label or "").strip().lower().replace("_", " ").replace("-", " ")
    if not needle:
        return None
    for name, stream, _ in WASTE_ITEMS:
        if needle == name.lower():
            return stream
    # Sanitary / special-care keywords are checked first so a label like
    # "sanitary pad" or "battery pack" isn't swallowed by a generic dry-waste
    # keyword such as "pack".
    for stream in ("sanitary", "special_care", "wet", "dry"):
        if any(keyword in needle for keyword in LABEL_KEYWORDS[stream]):
            return stream
    return None
