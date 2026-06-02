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
  bool _isLookingUpCountry = false;
  String? _countryLookupMessage;
  int _countryLookupRequestId = 0;

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
    final start = _startDate;
    final end = _endDate;
    return AddTripDraftModel(
      destinationName: _destinationController.text.trim(),
      destinationCountry: _countryController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      startDate: start ?? _minimumStartDate,
      endDate: end ?? start ?? _minimumStartDate,
      preferences: _selectedPreferences.toList(),
      travelNotes: _notesController.text.trim(),
    );
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  DateTime get _minimumStartDate => _today.add(const Duration(days: 1));

  DateTime get _maximumTripDate =>
      DateTime(_today.year + 100, _today.month, _today.day);

  DateTime? get _startDate => _parseDate(_startDateController.text);

  DateTime? get _endDate => _parseDate(_endDateController.text);

  String? get _dateValidationMessage {
    final start = _startDate;
    final end = _endDate;
    if (start == null) {
      return 'Select a start date later than today.';
    }
    if (!start.isAfter(_today)) {
      return 'Start date must be later than today.';
    }
    if (end == null) {
      return 'Select an end date.';
    }
    if (end.isBefore(start)) {
      return 'End date must not be earlier than start date.';
    }
    return null;
  }

  bool get _canCreateTrip => !_isSaving && _dateValidationMessage == null;

  double get _completionScore {
    var filled = 0;
    const total = 8;
    final start = _startDate;
    final end = _endDate;
    if (_destinationController.text.trim().isNotEmpty) filled++;
    if (_countryController.text.trim().isNotEmpty) filled++;
    if (_latitude >= -90 && _latitude <= 90) filled++;
    if (_longitude >= -180 && _longitude <= 180) filled++;
    if (start != null && start.isAfter(_today)) filled++;
    if (start != null && end != null && !end.isBefore(start)) filled++;
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
      _field('Destination Country', _countryController, readOnly: true),
      const SizedBox(height: 10),
      OsmCoordinatePicker(
        latitude: _latitude,
        longitude: _longitude,
        onCoordinateSelected: (latitude, longitude) {
          setState(() {
            _latitude = latitude;
            _longitude = longitude;
            _countryController.clear();
          });
          _lookupCountry(latitude, longitude);
        },
      ),
      if (_isLookingUpCountry || _countryLookupMessage != null) ...[
        const SizedBox(height: 6),
        Text(
          _isLookingUpCountry
              ? 'Looking up country from pinned location...'
              : _countryLookupMessage!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
        ),
      ],
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _dateField(
              'Start Date',
              _startDateController,
              onTap: _pickStartDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dateField(
              'End Date',
              _endDateController,
              onTap: _pickEndDate,
            ),
          ),
        ],
      ),
      if (_dateValidationMessage != null) ...[
        const SizedBox(height: 6),
        Text(
          _dateValidationMessage!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.coral),
        ),
      ],
      const SizedBox(height: 12),
      const Text('Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AddTripFormData.preferenceOptions.map((option) {
          final selected = _selectedPreferences.contains(option);
          return FilterChip(
            label: Text(AddTripFormData.preferenceLabel(option)),
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
            onPressed: _canCreateTrip ? _createTrip : null,
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

  Widget _dateField(
    String label,
    TextEditingController controller, {
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: IconButton(
          tooltip: 'Pick $label',
          onPressed: onTap,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: readOnly ? const Icon(Icons.lock_rounded) : null,
      ),
    );
  }

  DateTime? _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateUtils.dateOnly(parsed);
  }

  String _formatDate(DateTime date) => date.toIso8601String().split('T').first;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDateForPicker(
        firstDate: _minimumStartDate,
        lastDate: _maximumTripDate,
        selectedDate: _startDate,
      ),
      firstDate: _minimumStartDate,
      lastDate: _maximumTripDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    final selected = DateUtils.dateOnly(picked);
    setState(() {
      _startDateController.text = _formatDate(selected);
      final end = _endDate;
      if (end != null && end.isBefore(selected)) {
        _endDateController.clear();
      }
    });
  }

  Future<void> _pickEndDate() async {
    final start = _startDate;
    final firstDate = start != null && start.isAfter(_today)
        ? start
        : _minimumStartDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDateForPicker(
        firstDate: firstDate,
        lastDate: _maximumTripDate,
        selectedDate: _endDate,
      ),
      firstDate: firstDate,
      lastDate: _maximumTripDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _endDateController.text = _formatDate(DateUtils.dateOnly(picked));
    });
  }

  DateTime _initialDateForPicker({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime? selectedDate,
  }) {
    if (selectedDate != null &&
        !selectedDate.isBefore(firstDate) &&
        !selectedDate.isAfter(lastDate)) {
      return selectedDate;
    }
    return firstDate;
  }

  Future<void> _createTrip() async {
    final dateError = _dateValidationMessage;
    if (dateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(dateError)));
      return;
    }

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

  Future<void> _lookupCountry(double latitude, double longitude) async {
    final requestId = ++_countryLookupRequestId;
    setState(() {
      _isLookingUpCountry = true;
      _countryLookupMessage = null;
    });

    try {
      final result = await widget.dataSource.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) {
        return;
      }
      if (requestId != _countryLookupRequestId) {
        return;
      }
      setState(() {
        if (result.country.isNotEmpty) {
          _countryController.text = result.country;
          _countryLookupMessage = 'Country filled: ${result.country}';
        } else {
          _countryLookupMessage = 'No country found for this point.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (requestId != _countryLookupRequestId) {
        return;
      }
      setState(() {
        _countryLookupMessage = 'Could not look up country: $error';
      });
    } finally {
      if (mounted && requestId == _countryLookupRequestId) {
        setState(() {
          _isLookingUpCountry = false;
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
