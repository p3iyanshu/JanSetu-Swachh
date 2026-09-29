import 'package:flutter_test/flutter_test.dart';
import 'package:jansetu_mobile/core/constants/app_constants.dart';
import 'package:jansetu_mobile/data/waste_guide_data.dart';

void main() {
  test('every waste guide item belongs to a known stream', () {
    expect(wasteStreams.map((stream) => stream.id), ['wet', 'dry', 'sanitary', 'special_care']);
    for (final item in wasteItems) {
      expect(wasteStreamById(item.streamId), isNotNull, reason: item.name);
    }
  });

  test('waste guide search matches item and stream names', () {
    expect(searchWasteItems('battery').map((item) => item.streamId), everyElement('special_care'));
    expect(searchWasteItems('dry waste'), isNotEmpty);
    expect(searchWasteItems(''), hasLength(wasteItems.length));
  });

  test('swachh categories are selectable and labelled', () {
    for (final id in AppConstants.swachhCategoryIds) {
      expect(AppConstants.isSelectableCategory(id), isTrue, reason: id);
    }
    expect(AppConstants.categoryLabel('public_toilet'), 'Public Toilet');
    expect(AppConstants.categoryLabel('broken_streetlight'), 'Streetlight');
    expect(AppConstants.isSelectableCategory('broken_streetlight'), isFalse);
  });
}
