import 'package:flutter/material.dart';

enum AppSection {
  tripList,
  addTrip,
  tripSummary,
  editTrip,
  apiDemo,
}

extension AppSectionMeta on AppSection {
  String get title {
    switch (this) {
      case AppSection.tripList:
        return 'Home / Trip List';
      case AppSection.addTrip:
        return 'Add Trip';
      case AppSection.tripSummary:
        return 'Trip Summary';
      case AppSection.editTrip:
        return 'Edit Trip';
      case AppSection.apiDemo:
        return 'Testing / API Demo';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.tripList:
        return Icons.home_rounded;
      case AppSection.addTrip:
        return Icons.add_box_rounded;
      case AppSection.tripSummary:
        return Icons.dashboard_rounded;
      case AppSection.editTrip:
        return Icons.edit_rounded;
      case AppSection.apiDemo:
        return Icons.api_rounded;
    }
  }
}
