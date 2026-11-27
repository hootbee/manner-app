const wardrobeCategories = ['모자', '의상', '액세서리', '가구', '소품', '배경'];
const _categoryPrefixes = {
  'hat-': 0,
  'acc-': 2,
  'furniture-': 3,
  'prop-': 4,
  'bg-': 5,
};
int wardrobeCategory(String id) {
  for (final entry in _categoryPrefixes.entries) {
    if (id.startsWith(entry.key)) return entry.value;
  }
  return 1;
}

String equipmentKey(String partner, int category) =>
    category == 1 ? partner : '$partner:$category';
const wardrobeDefaults = [
  'hat-none',
  'suit',
  'acc-none',
  'furniture-none',
  'prop-none',
  'bg-room',
];
