import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/add_trip/model/add_trip_draft_model.dart';
import 'package:api_6005cmd/shared/view/layer_badges.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/osm_coordinate_picker.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

class AddTripPage extends StatefulWidget {
  const AddTripPage({super.key});

  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  late final TextEditingController _destinationController;
  late final TextEditingController _countryController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _notesController;
  late final Set<String> _selectedPreferences;
  late double _latitude;
  late double _longitude;

  @override
  void initState() {
    super.initState();
    final seed = AddTripFormData.seedDraft();
    _destinationController = TextEditingController(text: seed.destinationName);
    _countryController = TextEditingController(text: seed.destinationCountry);
    _latitude = seed.latitude;
    _longitude = seed.longitude;
    _startDateController = TextEditingController(
      text: seed.startDate.toIso8601String().split('T').first,
    );
    _endDateController = TextEditingController(
      text: seed.endDate.toIso8601String().split('T').first,
    );
    _notesController = TextEditingController(text: seed.travelNotes);
    _selectedPreferences = seed.preferences.toSet();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _countryController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  AddTripDraftModel get _draft {
    final start =
        DateTime.tryParse(_startDateController.text) ?? DateTime(2026, 7, 12);
    final end =
        DateTime.tryParse(_endDateController.text) ?? DateTime(2026, 7, 18);
    return AddTripDraftModel(
      destinationName: _destinationController.text.trim(),
      destinationCountry: _countryController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      startDate: start,
      endDate: end,
      preferences: _selectedPreferences.toList(),
      travelNotes: _notesController.text.trim(),
    );
  }

  double get _completionScore {
    var filled = 0;
    const total = 8;
    if (_destinationController.text.trim().isNotEmpty) filled++;
    if (_countryController.text.trim().isNotEmpty) filled++;
    if (_latitude >= -90 && _latitude <= 90) filled++;
    if (_longitude >= -180 && _longitude <= 180) filled++;
    if (DateTime.tryParse(_startDateController.text) != null) filled++;
    if (DateTime.tryParse(_endDateController.text) != null) filled++;
    if (_selectedPreferences.isNotEmpty) filled++;
    if (_notesController.text.trim().isNotEmpty) filled++;
    return filled / total;
  }

  @override
  Widget build(BuildContext context) {
    final preview = const JsonEncoder.withIndent('  ').convert(_draft.toJson());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Add Trip',
          subtitle:
              'Pure UI form for POST /api/trips. Inputs are local-only and API-binding ready.',
        ),
        const SizedBox(height: 12),
        const LayerBadges(
          dataLayer: 'AddTripFormData',
          modelLayer: 'AddTripDraftModel',
          viewLayer: 'AddTripPage',
        ),
        const SizedBox(height: 12),
        _FormReadiness(score: _completionScore),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildForm(scrollable: true)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildPreview(preview)),
                  ],
                );
              }
              return ListView(
                children: [
                  _buildForm(scrollable: false),
                  const SizedBox(height: 12),
                  SizedBox(height: 300, child: _buildPreview(preview)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForm({required bool scrollable}) {
    final children = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _quickFillButton(
            label: 'Tokyo',
            onTap: () => _applyQuickFill(
              destination: 'Tokyo',
              country: 'Japan',
              lat: '35.6762',
              lng: '139.6503',
            ),
          ),
          _quickFillButton(
            label: 'Bangkok',
            onTap: () => _applyQuickFill(
              destination: 'Bangkok',
              country: 'Thailand',
              lat: '13.7563',
              lng: '100.5018',
            ),
          ),
          _quickFillButton(
            label: 'Seoul',
            onTap: () => _applyQuickFill(
              destination: 'Seoul',
              country: 'South Korea',
              lat: '37.5665',
              lng: '126.9780',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field('Destination Name', _destinationController),
      const SizedBox(height: 10),
      _field('Destination Country', _countryController),
      const SizedBox(height: 10),
      OsmCoordinatePicker(
        latitude: _latitude,
        longitude: _longitude,
        onCoordinateSelected: (latitude, longitude) {
          setState(() {
            _latitude = latitude;
            _longitude = longitude;
          });
        },
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _field('Start Date (YYYY-MM-DD)', _startDateController)),
          const SizedBox(width: 10),
          Expanded(child: _field('End Date (YYYY-MM-DD)', _endDateController)),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Preferences',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AddTripFormData.preferenceOptions.map((option) {
          final selected = _selectedPreferences.contains(option);
          return FilterChip(
            label: Text(option),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedPreferences.add(option);
                } else {
                  _selectedPreferences.remove(option);
                }
              });
            },
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      _field('Travel Notes', _notesController, maxLines: 4),
      const SizedBox(height: 16),
      Row(
        children: [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Create Trip (API Pending)'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text('Refresh JSON Preview'),
          ),
        ],
      ),
    ];

    return MacPanel(
      color: AppPalette.mintA(0.06),
      child: scrollable
          ? ListView(
              padding: const EdgeInsets.only(top: 4),
              children: children,
            )
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
    );
  }

  Widget _buildPreview(String preview) {
    return MacPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Body Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'This payload shape matches the assignment trip model for POST /api/trips.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkA(0.64),
                ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.blueA(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.blueA(0.24)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  void _applyQuickFill({
    required String destination,
    required String country,
    required String lat,
    required String lng,
  }) {
    setState(() {
      _destinationController.text = destination;
      _countryController.text = country;
      _latitude = double.tryParse(lat) ?? _latitude;
      _longitude = double.tryParse(lng) ?? _longitude;
    });
  }

  Widget _quickFillButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: const Icon(Icons.auto_fix_high_rounded, size: 16),
      label: Text('Quick Fill: $label'),
      onPressed: onTap,
    );
  }
}

class _FormReadiness extends StatelessWidget {
  const _FormReadiness({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();
    return MacPanel(
      padding: const EdgeInsets.all(14),
      color: AppPalette.blueA(0.08),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score,
                  strokeWidth: 6,
                  backgroundColor: AppPalette.inkA(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.blue),
                ),
                Text('$percent%'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Input completion for POST /api/trips payload.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppPalette.inkA(0.64)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
