import 'package:api_6005cmd/app/smart_travel_app.dart';
import 'package:api_6005cmd/core/config/mapbox_config.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MapboxConfig.load();
  runApp(const SmartTravelApp());
}
