import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/edit_trip/data/edit_trip_data_source.dart';
import 'package:api_6005cmd/features/edit_trip/model/edit_trip_model.dart';
import 'package:api_6005cmd/features/trip_list/data/trip_list_data_source.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/osm_coordinate_picker.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

class EditTripPage extends StatefulWidget {
  const EditTripPage({
    super.key,
    required this.dataSource,
    required this.tripId,
  });

  final EditTripDataSource dataSource;
  final String tripId;

  @override
  State<EditTripPage> createState() => _EditTripPageState();
}

class _EditTripPageState extends State<EditTripPage> {
  late Future<EditTripModel?> _tripFuture;

  @override
  void initState() {
    super.initState();
    _tripFuture = widget.dataSource.fetchEditableTrip(widget.tripId);
  }

  @override
  void didUpdateWidget(covariant EditTripPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tripId != oldWidget.tripId) {
      _tripFuture = widget.dataSource.fetchEditableTrip(widget.tripId);
    }
  }

  void _refresh() {
    setState(() {
      _tripFuture = widget.dataSource.fetchEditableTrip(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EditTripModel?>(
      future: _tripFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EditLoadError(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final trip = snapshot.data;
        if (trip == null) {
          return const Center(
            child: Text(
              'No trip found. Choose a record from Home / Trip List.',
            ),
          );
        }
        return _EditTripForm(
          key: ValueKey(trip.id),
          model: trip,
          onRefresh: _refresh,
          onSave: widget.dataSource.updateTrip,
          onReverseGeocode: widget.dataSource.reverseGeocode,
        );
      },
    );
  }
}

class _EditTripForm extends StatefulWidget {
  const _EditTripForm({
    super.key,
    required this.model,
    required this.onRefresh,
    required this.onSave,
    required this.onReverseGeocode,
  });

  final EditTripModel model;
  final VoidCallback onRefresh;
  final Future<EditTripModel> Function(EditTripModel trip) onSave;
  final Future<ReverseGeocodeResult> Function({
    required double latitude,
    required double longitude,
  })
  onReverseGeocode;

  @override
  State<_EditTripForm> createState() => _EditTripFormState();
}

class _EditTripFormState extends State<_EditTripForm> {
  late final TextEditingController _destinationController;
  late final TextEditingController _countryController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _notesController;
  late final Set<String> _preferences;
  late double _latitude;
  late double _longitude;
  bool _isSaving = false;
  bool _isLookingUpCountry = false;
  String? _countryLookupMessage;
  int _countryLookupRequestId = 0;

  @override
  void initState() {
    super.initState();
    final trip = widget.model;
    _destinationController = TextEditingController(text: trip.destinationName);
    _countryController = TextEditingController(text: trip.destinationCountry);
    _latitude = trip.latitude;
    _longitude = trip.longitude;
    _startDateController = TextEditingController(
      text: trip.startDate.toIso8601String().split('T').first,
    );
    _endDateController = TextEditingController(
      text: trip.endDate.toIso8601String().split('T').first,
    );
    _notesController = TextEditingController(text: trip.travelNotes);
    _preferences = trip.preferences.toSet();
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

  EditTripModel get _current {
    final start = _startDate;
    final end = _endDate;
    return EditTripModel(
      id: widget.model.id,
      destinationName: _destinationController.text.trim(),
      destinationCountry: _countryController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      startDate: start ?? widget.model.startDate,
      endDate: end ?? widget.model.endDate,
      preferences: _preferences.toList(),
      travelNotes: _notesController.text.trim(),
      updatedAt: widget.model.updatedAt,
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

  bool get _canSaveChanges => !_isSaving && _dateValidationMessage == null;

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
    if (_preferences.isNotEmpty) filled++;
    if (_notesController.text.trim().isNotEmpty) filled++;
    return filled / total;
  }

  @override
  Widget build(BuildContext context) {
    final preview = const JsonEncoder.withIndent(
      '  ',
    ).convert(_current.toJson());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Edit Trip',
          trailing: FilledButton.tonalIcon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload Record'),
          ),
        ),
        const SizedBox(height: 12),
        _EditReadiness(
          score: _completionScore,
          updatedAt: widget.model.updatedAt,
        ),
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
          final selected = _preferences.contains(option);
          return FilterChip(
            label: Text(AddTripFormData.preferenceLabel(option)),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _preferences.add(option);
                } else {
                  _preferences.remove(option);
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
            onPressed: _canSaveChanges ? _saveChanges : null,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _destinationController.text = widget.model.destinationName;
                _countryController.text = widget.model.destinationCountry;
                _latitude = widget.model.latitude;
                _longitude = widget.model.longitude;
                _startDateController.text = widget.model.startDate
                    .toIso8601String()
                    .split('T')
                    .first;
                _endDateController.text = widget.model.endDate
                    .toIso8601String()
                    .split('T')
                    .first;
                _notesController.text = widget.model.travelNotes;
                _preferences
                  ..clear()
                  ..addAll(widget.model.preferences);
              });
            },
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Reset Changes'),
          ),
        ],
      ),
    ];

    return MacPanel(
      color: AppPalette.coralA(0.06),
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
            'PUT Payload Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'This body is ready for PUT /api/trips/${widget.model.id}.',
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
                color: AppPalette.mintA(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.mintA(0.25)),
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

  Future<void> _saveChanges() async {
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
      final saved = await widget.onSave(_current);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${saved.id}: ${saved.destinationName}')),
      );
      widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save trip: $error')));
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
      final result = await widget.onReverseGeocode(
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

class _EditLoadError extends StatelessWidget {
  const _EditLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MacPanel(
        color: AppPalette.coralA(0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppPalette.coral),
            const SizedBox(height: 8),
            Text(
              'Could not load the selected trip',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditReadiness extends StatelessWidget {
  const _EditReadiness({required this.score, required this.updatedAt});

  final double score;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();
    return MacPanel(
      padding: const EdgeInsets.all(14),
      color: AppPalette.coralA(0.08),
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
                    AppPalette.coral,
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
                  'Edit Readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Last synced: ${updatedAt.toIso8601String()}',
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
