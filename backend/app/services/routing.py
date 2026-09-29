from app.models import CategoryType, Department


CATEGORY_DEPARTMENT_KEYWORDS = {
    CategoryType.POTHOLE: ["pwd", "public works"],
    CategoryType.DAMAGED_PROPERTY: ["pwd", "public works"],
    CategoryType.STREETLIGHT: ["bescom", "electric", "power"],
    CategoryType.WATER_LEAKAGE: ["bwssb", "water"],
    CategoryType.SEWAGE: ["bwssb", "sewage"],
    CategoryType.GARBAGE: ["solid waste", "sanitation", "garbage"],
    CategoryType.ILLEGAL_DUMPING: ["solid waste", "sanitation", "garbage"],
    CategoryType.UNSEGREGATED_WASTE: ["solid waste", "sanitation", "garbage"],
    CategoryType.MISSED_PICKUP: ["solid waste", "sanitation", "garbage"],
    CategoryType.WASTE_BURNING: ["solid waste", "sanitation", "garbage"],
    CategoryType.PUBLIC_TOILET: ["sanitation", "solid waste"],
}


def find_department_for_category(db, category):
    keywords = CATEGORY_DEPARTMENT_KEYWORDS.get(category, [])
    departments = db.query(Department).all()
    for keyword in keywords:
        for department in departments:
            haystack = f"{department.name} {department.jurisdiction or ''}".lower()
            if keyword in haystack:
                return department
    return None
