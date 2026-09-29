import 'package:flutter/material.dart';

/// Offline copy of the household waste segregation guide, so "Which Bin?"
/// works with no network. Mirrors backend/app/services/waste_guide.py
/// (four-stream segregation under the Solid Waste Management Rules, 2026) -
/// keep the two in sync.
class WasteStream {
  final String id;
  final String name;
  final String bin;
  final Color color;
  final IconData icon;
  final String summary;
  final String goesTo;
  final List<String> tips;

  const WasteStream({
    required this.id,
    required this.name,
    required this.bin,
    required this.color,
    required this.icon,
    required this.summary,
    required this.goesTo,
    required this.tips,
  });
}

class WasteItem {
  final String name;
  final String streamId;
  final String tip;

  const WasteItem(this.name, this.streamId, this.tip);
}

const String wasteGuideSource =
    'Solid Waste Management Rules, 2026 - four-stream segregation at source';

const List<WasteStream> wasteStreams = [
  WasteStream(
    id: 'wet',
    name: 'Wet Waste',
    bin: 'Green bin',
    color: Color(0xFF2E7D32),
    icon: Icons.eco_outlined,
    summary: 'Biodegradable kitchen and garden waste.',
    goesTo: 'Composted or processed through bio-methanation.',
    tips: [
      'Drain excess liquid before putting it in the bin.',
      'Never mix plastic or wrappers into wet waste.',
      'Home composting turns this into free manure for plants.',
    ],
  ),
  WasteStream(
    id: 'dry',
    name: 'Dry Waste',
    bin: 'Blue bin',
    color: Color(0xFF1565C0),
    icon: Icons.recycling_rounded,
    summary: 'Plastic, paper, metal, glass, wood, rubber and cloth.',
    goesTo: 'Material Recovery Facility (MRF) for sorting and recycling.',
    tips: [
      'Rinse milk packets and food containers so they can be recycled.',
      'Flatten cartons and bottles to save space.',
      "Wrap broken glass in paper and mark it 'sharp'.",
    ],
  ),
  WasteStream(
    id: 'sanitary',
    name: 'Sanitary Waste',
    bin: 'Wrapped & marked separately',
    color: Color(0xFFC62828),
    icon: Icons.clean_hands_outlined,
    summary: 'Diapers, sanitary pads, tampons, condoms and soiled dressings.',
    goesTo: 'Collected separately and sent for safe incineration.',
    tips: [
      'Wrap securely in newspaper or the pouch provided.',
      'Mark the packet with a red dot so collectors can handle it safely.',
      'Never flush it - it chokes drains and sewers.',
    ],
  ),
  WasteStream(
    id: 'special_care',
    name: 'Special Care Waste',
    bin: 'Separate bag - hand over on collection day',
    color: Color(0xFF6A1B9A),
    icon: Icons.warning_amber_rounded,
    summary: 'Household hazardous and e-waste: batteries, bulbs, medicines, paint, chemicals.',
    goesTo: 'Authorised hazardous-waste and e-waste handlers.',
    tips: [
      'Keep it in a separate bag or box, away from children.',
      'Hand it over only to the designated collector or drop-off point.',
      'Never burn it or throw it into drains or open plots.',
    ],
  ),
];

const List<WasteItem> wasteItems = [
  WasteItem('Vegetable & fruit peels', 'wet', 'Straight into the green bin or your compost pit.'),
  WasteItem('Leftover cooked food', 'wet', 'Drain gravies first; no plastic wrap.'),
  WasteItem('Tea leaves & coffee grounds', 'wet', 'Great for compost.'),
  WasteItem('Eggshells', 'wet', 'Crush them so they compost faster.'),
  WasteItem('Meat, fish & bones', 'wet', 'Wrap in newspaper to avoid smell.'),
  WasteItem('Flowers & pooja waste', 'wet', 'Remove plastic, thread and foil first.'),
  WasteItem('Garden leaves & grass', 'wet', 'Large volumes can go to ward garden-waste collection.'),
  WasteItem('Coconut shells', 'wet', 'Break into pieces; some wards collect them separately.'),
  WasteItem('Spoiled grains & flour', 'wet', 'Compost or green bin.'),
  WasteItem('Paper napkins & tissues (food-soiled)', 'wet', 'Compostable if not chemically treated.'),
  WasteItem('Plastic bottles', 'dry', 'Rinse, crush and cap.'),
  WasteItem('Milk & oil packets', 'dry', 'Cut open, rinse and dry before binning.'),
  WasteItem('Plastic carry bags', 'dry', 'Bundle together; better still, carry a cloth bag.'),
  WasteItem('Chips & biscuit wrappers', 'dry', 'Multi-layer plastic - keep clean and dry.'),
  WasteItem('Newspapers & magazines', 'dry', 'Keep dry; sell to the kabadiwala.'),
  WasteItem('Cardboard boxes', 'dry', 'Flatten before handing over.'),
  WasteItem('Tetra Pak cartons', 'dry', 'Rinse and flatten.'),
  WasteItem('Glass bottles & jars', 'dry', 'Rinse; keep separate from other dry waste if possible.'),
  WasteItem('Broken glass', 'dry', "Wrap in paper and label 'sharp'."),
  WasteItem('Metal cans & foil', 'dry', 'Rinse and flatten.'),
  WasteItem('Thermocol / styrofoam', 'dry', 'Break into pieces and keep dry.'),
  WasteItem('Old clothes & shoes', 'dry', 'Donate if usable, otherwise dry waste.'),
  WasteItem('Rubber & leather items', 'dry', 'Dry bin.'),
  WasteItem('Wood pieces & furniture scrap', 'dry', 'Large items: request bulky-waste pickup.'),
  WasteItem('Plastic toys & buckets', 'dry', 'Dry bin or recycler.'),
  WasteItem('Disposable plates & cups (plastic)', 'dry', 'Scrape off food, then dry bin.'),
  WasteItem('Diapers', 'sanitary', 'Wrap in newspaper and mark with a red dot.'),
  WasteItem('Sanitary pads & tampons', 'sanitary', 'Wrap securely and mark with a red dot.'),
  WasteItem('Condoms', 'sanitary', 'Wrap and mark before handing over.'),
  WasteItem('Used masks & gloves', 'sanitary', 'Cut the straps, wrap and keep separately.'),
  WasteItem('Blood-soiled cotton & bandages', 'sanitary', 'Wrap securely; never mix with wet waste.'),
  WasteItem('Batteries', 'special_care', 'Tape the terminals; hand over as special care waste.'),
  WasteItem('CFL & tube lights', 'special_care', 'Contain mercury - do not break; pack carefully.'),
  WasteItem('Mobile phones & chargers', 'special_care', 'E-waste - use an authorised e-waste collector.'),
  WasteItem('Old electronics & cables', 'special_care', 'E-waste - never burn cables for copper.'),
  WasteItem('Expired medicines', 'special_care', 'Keep in original strips; hand over as special care.'),
  WasteItem('Syringes & needles', 'special_care', 'Put in a hard container with a lid before handing over.'),
  WasteItem('Paint & varnish cans', 'special_care', 'Close tightly; hand over as special care waste.'),
  WasteItem('Pesticide & cleaning chemical containers', 'special_care', 'Do not rinse into drains.'),
  WasteItem('Aerosol spray cans', 'special_care', 'Do not puncture or burn.'),
  WasteItem('Mercury thermometers', 'special_care', 'Pack in a sealed container.'),
  WasteItem('Printer cartridges', 'special_care', 'Return to the brand take-back point or e-waste collector.'),
  WasteItem('Nail polish & remover', 'special_care', 'Keep tightly closed; special care bag.'),
];

WasteStream? wasteStreamById(String? id) {
  for (final stream in wasteStreams) {
    if (stream.id == id) return stream;
  }
  return null;
}

List<WasteItem> searchWasteItems(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return wasteItems;
  return wasteItems
      .where((item) =>
          item.name.toLowerCase().contains(needle) ||
          (wasteStreamById(item.streamId)?.name.toLowerCase().contains(needle) ?? false))
      .toList();
}
