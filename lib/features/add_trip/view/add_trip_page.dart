import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/add_trip/model/add_trip_draft_model.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/shared/view/layer_badges.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/osm_coordinate_picker.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

class AddTripPage extends StatefulWidget {
  const AddTripPage({
    super.key,
    required this.dataSource,
    required this.onTripCreated,
  });

  final TripListDataSource dataSource;
  final ValueChanged<String> onTripCreated;

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController();
    _countryController = TextEditingController();
    _latitude = 0;
    _longitude = 0;
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _notesController = TextEditingController();
    _selectedPreferences = <String>{};
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
    final start = DateTime.tryParse(_startDateController.text);
    final end = DateTime.tryParse(_endDateController.text);
    return AddTripDraftModel(
      destinationName: _destinationController.text.trim(),
      destinationCountry: _countryController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      startDate: start ?? DateTime.now(),
      endDate: end ?? start ?? DateTime.now(),
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
              'Create a trip through POST /api/trips and open its live summary response.',
        ),
        const SizedBox(height: 12),
        const LayerBadges(
          dataLayer: 'TripListDataSource',
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
          Expanded(
            child: _field('Start Date (YYYY-MM-DD)', _startDateController),
          ),
          const SizedBox(width: 10),
          Expanded(child: _field('End Date (YYYY-MM-DD)', _endDateController)),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: _isSaving ? null : _createTrip,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(_isSaving ? 'Creating...' : 'Create Trip'),
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
          ? ListView(padding: const EdgeInsets.only(top: 4), children: children)
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.64)),
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

  Future<void> _createTrip() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final created = await widget.dataSource.createTrip(_draft);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${created.id}: ${created.destinationName}'),
        ),
      );
      widget.onTripCreated(created.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create trip: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppPalette.blue,
                  ),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.inkA(0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
