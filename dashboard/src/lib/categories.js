// Mirrors backend CategoryType. The Swachh (waste & sanitation) segment is
// what the Swachh Insights tab and the "All waste & sanitation" filter cover.
export const categoryLabel = {
  garbage_overflow: 'Garbage Pile',
  illegal_dumping: 'Dumping Spot',
  missed_pickup: 'Missed Pickup',
  unsegregated_waste: 'Mixed (Unsegregated) Waste',
  waste_burning: 'Waste Burning',
  public_toilet: 'Public Toilet',
  sewage_overflow: 'Sewage / Drain',
  water_leakage: 'Water Leakage',
  pothole: 'Pothole',
  broken_streetlight: 'Streetlight / Electricity',
  damaged_public_property: 'Public Property Damage',
  other: 'Other',
};

export const SWACHH_CATEGORIES = new Set([
  'garbage_overflow',
  'illegal_dumping',
  'missed_pickup',
  'unsegregated_waste',
  'waste_burning',
  'public_toilet',
]);

// Issue types a citizen can pick when reporting (same set as the mobile app).
export const CITIZEN_CATEGORIES = [
  { id: 'garbage_overflow', label: 'Garbage Pile', hint: 'Overflowing bin or garbage heap', group: 'swachh' },
  { id: 'illegal_dumping', label: 'Dumping Spot', hint: 'Waste dumped on road, lake or empty plot', group: 'swachh' },
  { id: 'missed_pickup', label: 'Missed Pickup', hint: "Door-to-door collection didn't come", group: 'swachh' },
  { id: 'unsegregated_waste', label: 'Mixed Waste', hint: 'Waste not segregated at source', group: 'swachh' },
  { id: 'waste_burning', label: 'Waste Burning', hint: 'Garbage or plastic being burnt', group: 'swachh' },
  { id: 'public_toilet', label: 'Public Toilet', hint: 'Dirty, locked or no water', group: 'swachh' },
  { id: 'sewage_overflow', label: 'Sewage / Drain', hint: 'Overflowing or blocked drain', group: 'civic' },
  { id: 'water_leakage', label: 'Water Leak', hint: 'Pipeline leak or wastage', group: 'civic' },
  { id: 'pothole', label: 'Pothole', hint: 'Damaged road surface', group: 'civic' },
];
