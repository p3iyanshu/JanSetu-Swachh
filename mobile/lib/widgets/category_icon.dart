import 'package:flutter/material.dart';

IconData categoryIconData(String? category) {
  switch (category) {
    case 'garbage_overflow':
      return Icons.delete_outline_rounded;
    case 'illegal_dumping':
      return Icons.report_problem_outlined;
    case 'missed_pickup':
      return Icons.local_shipping_outlined;
    case 'unsegregated_waste':
      return Icons.recycling_rounded;
    case 'waste_burning':
      return Icons.local_fire_department_outlined;
    case 'public_toilet':
      return Icons.wc_rounded;
    case 'pothole':
      return Icons.add_road_rounded;
    case 'water_leakage':
      return Icons.water_drop_outlined;
    case 'sewage_overflow':
      return Icons.plumbing_rounded;
    case 'broken_streetlight':
      return Icons.lightbulb_outline_rounded;
    default:
      return Icons.build_circle_outlined;
  }
}

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;
  final Color? color;

  const CategoryIcon({super.key, required this.category, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(categoryIconData(category), size: size, color: color);
  }
}
