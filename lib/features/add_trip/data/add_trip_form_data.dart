class AddTripFormData {
  const AddTripFormData._();

  static const List<String> preferenceOptions = [
    'food',
    'culture',
    'nature',
    'shopping',
    'family',
    'adventure',
    'history',
    'arts',
    'outdoors',
    'wellness',
    'nightlife',
  ];

  static String preferenceLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'food' => 'Food',
      'culture' => 'Culture',
      'nature' => 'Nature',
      'shopping' => 'Shopping',
      'family' => 'Family',
      'adventure' => 'Adventure',
      'history' => 'History',
      'arts' => 'Arts',
      'outdoors' => 'Outdoors',
      'wellness' => 'Wellness',
      'nightlife' => 'Nightlife',
      _ => _titleCase(value),
    };
  }

  static String _titleCase(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return value;
    }
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
