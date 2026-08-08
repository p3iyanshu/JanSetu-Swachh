import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({Key? key, required this.category, this.size = 24.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (category) {
      case 'garbage_overflow':
        icon = Icons.delete_outline_rounded;
        break;
      case 'pothole':
        icon = Icons.add_road_rounded;
        break;
      case 'water_leakage':
        icon = Icons.water_drop_outlined;
        break;
      case 'sewage_overflow':
        icon = Icons.plumbing_rounded;
        break;
      case 'broken_streetlight':
        icon = Icons.lightbulb_outline_rounded;
        break;
      case 'illegal_dumping':
        icon = Icons.report_problem_outlined;
        break;
      default:
        icon = Icons.build_circle_outlined;
    }

    return Icon(icon, size: size);
  }
}
