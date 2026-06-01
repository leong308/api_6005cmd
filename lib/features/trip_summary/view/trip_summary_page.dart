import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';
import 'package:api_6005cmd/shared/view/layer_badges.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

enum _SummaryTab {
  overview('Overview', Icons.space_dashboard_rounded),
  modules('Modules', Icons.widgets_rounded),
  json('JSON', Icons.code_rounded);

  const _SummaryTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class TripSummaryPage extends StatefulWidget {
  const TripSummaryPage({
    super.key,
    required this.dataSource,
    required this.tripId,
  });

  final TripSummaryDataSource dataSource;
  final String tripId;

  @override
  State<TripSummaryPage> createState() => _TripSummaryPageState();
}

class _TripSummaryPageState extends State<TripSummaryPage> {
  late Future<TripSummaryModel?> _summaryFuture;
  _SummaryTab _tab = _SummaryTab.overview;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.dataSource.fetchSummary(widget.tripId);
  }

  @override
  void didUpdateWidget(covariant TripSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _summaryFuture = widget.dataSource.fetchSummary(widget.tripId);
    }
  }

  void _refreshMock() {
    setState(() {
      _summaryFuture = widget.dataSource.fetchSummary(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TripSummaryModel?>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const Center(
            child: Text('No trip found. Select a trip from Home / Trip List.'),
          );
        }

        final json = const JsonEncoder.withIndent('  ').convert(summary.toJson());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Trip Details / Smart Travel Summary',
              subtitle:
                  'One linked story from one trip record. Switch views to inspect by narrative, module, or raw payload.',
              trailing: FilledButton.tonalIcon(
                onPressed: _refreshMock,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Refresh External Data'),
              ),
            ),
            const SizedBox(height: 12),
            const LayerBadges(
              dataLayer: 'TripSummaryDataSource',
              modelLayer: 'TripSummaryModel',
              viewLayer: 'TripSummaryPage',
            ),
            const SizedBox(height: 12),
            _TabSwitcher(
              value: _tab,
              onChanged: (next) => setState(() => _tab = next),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    _SummaryTab.overview => _OverviewTab(summary: summary),
                    _SummaryTab.modules => _ModulesTab(summary: summary),
                    _SummaryTab.json => _JsonTab(json: json),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.value,
    required this.onChanged,
  });

  final _SummaryTab value;
  final ValueChanged<_SummaryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      padding: const EdgeInsets.all(8),
      color: AppPalette.whiteA(0.78),
      child: SegmentedButton<_SummaryTab>(
        segments: _SummaryTab.values
            .map(
              (tab) => ButtonSegment<_SummaryTab>(
                value: tab,
                icon: Icon(tab.icon),
                label: Text(tab.label),
              ),
            )
            .toList(),
        selected: {value},
        onSelectionChanged: (selected) => onChanged(selected.first),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _OverviewMetrics(summary: summary),
        const SizedBox(height: 12),
        _TripDetailsCard(summary: summary),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: null,
              child: const Text('Edit Trip (PUT Pending)'),
            ),
            OutlinedButton(
              onPressed: null,
              child: const Text('Delete Trip (DELETE Pending)'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricPanel(
          label: 'Temperature',
          value: '${summary.weather.temperature}°C',
          hint: summary.weather.condition,
          tone: AppPalette.blueA(0.1),
          icon: Icons.wb_sunny_rounded,
        ),
        _MetricPanel(
          label: 'Nearby Places',
          value: '${summary.googlePlaces.length}',
          hint: 'Google Places',
          tone: AppPalette.mintA(0.1),
          icon: Icons.place_rounded,
        ),
        _MetricPanel(
          label: 'Recommendations',
          value: '${summary.foursquareRecommendations.length}',
          hint: 'Foursquare',
          tone: AppPalette.coralA(0.1),
          icon: Icons.recommend_rounded,
        ),
        _MetricPanel(
          label: 'Country',
          value: summary.countryInfo.country,
          hint: summary.countryInfo.region,
          tone: AppPalette.inkA(0.08),
          icon: Icons.public_rounded,
        ),
      ],
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    required this.hint,
    required this.tone,
    required this.icon,
  });

  final String label;
  final String value;
  final String hint;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: MacPanel(
        color: tone,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppPalette.inkA(0.88)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppPalette.inkA(0.65)),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    hint,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppPalette.inkA(0.65)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulesTab extends StatelessWidget {
  const _ModulesTab({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        MacPanel(
          color: AppPalette.whiteA(0.88),
          child: Text(
            'Flow: Trip Record → Weather / Nearby Places / Recommendations / Country Info',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppPalette.inkA(0.82)),
          ),
        ),
        const SizedBox(height: 12),
        _DataCards(summary: summary),
      ],
    );
  }
}

class _JsonTab extends StatelessWidget {
  const _JsonTab({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SummaryJsonCard(json: json),
      ],
    );
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final trip = summary.trip;
    return MacPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_takeoff_rounded, color: AppPalette.coral, size: 22),
              const SizedBox(width: 8),
              Text(
                'Trip Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _detail('Destination', '${trip.destinationName}, ${trip.destinationCountry}'),
              _detail('Date', trip.dateRangeLabel),
              _detail('Preferences', trip.preferences.join(', ')),
              _detail(
                'Coordinates',
                '${trip.latitude.toStringAsFixed(4)}, ${trip.longitude.toStringAsFixed(4)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Notes: ${trip.travelNotes}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return SizedBox(
      width: 260,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 14,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppPalette.inkA(0.66),
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DataCards extends StatelessWidget {
  const _DataCards({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 340,
          child: MacPanel(
            color: AppPalette.blueA(0.08),
            child: _WeatherView(weather: summary.weather),
          ),
        ),
        SizedBox(
          width: 340,
          child: MacPanel(
            color: AppPalette.mintA(0.08),
            child: _PlaceView(places: summary.googlePlaces),
          ),
        ),
        SizedBox(
          width: 340,
          child: MacPanel(
            color: AppPalette.coralA(0.08),
            child: _RecommendationView(
              recommendations: summary.foursquareRecommendations,
            ),
          ),
        ),
        SizedBox(
          width: 340,
          child: MacPanel(
            color: AppPalette.inkA(0.06),
            child: _CountryView(info: summary.countryInfo),
          ),
        ),
      ],
    );
  }
}

class _WeatherView extends StatelessWidget {
  const _WeatherView({required this.weather});

  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_twilight_rounded, color: AppPalette.blue, size: 20),
            const SizedBox(width: 8),
            Text('Weather', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        _item('Temperature', '${weather.temperature}°C'),
        _item('Condition', weather.condition),
        _item('Humidity', '${weather.humidity}%'),
        _item('Wind', '${weather.windSpeed} m/s'),
      ],
    );
  }
}

class _PlaceView extends StatelessWidget {
  const _PlaceView({required this.places});

  final List<PlaceModel> places;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.place_rounded, color: AppPalette.mint, size: 20),
            const SizedBox(width: 8),
            Text('Google Places Nearby', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        for (final place in places)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _item(
              place.name,
              '${place.type} • ${place.rating} ★\n${place.address}',
            ),
          ),
      ],
    );
  }
}

class _RecommendationView extends StatelessWidget {
  const _RecommendationView({required this.recommendations});

  final List<RecommendationModel> recommendations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.recommend_rounded, color: AppPalette.coral, size: 20),
            const SizedBox(width: 8),
            Text(
              'Foursquare Recommendations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final rec in recommendations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _item(
              rec.name,
              '${rec.category} • ${rec.distanceMeters} m\n${rec.address}',
            ),
          ),
      ],
    );
  }
}

class _CountryView extends StatelessWidget {
  const _CountryView({required this.info});

  final CountryInfoModel info;

  @override
  Widget build(BuildContext context) {
    final hasFlagUrl = info.flag.startsWith('http');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, color: AppPalette.ink, size: 20),
                const SizedBox(width: 8),
                Text('Country Information', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (hasFlagUrl)
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    info.flag,
                    height: 24,
                    width: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _item('Country', info.country),
        _item('Capital', info.capital),
        _item('Currency', info.currency),
        _item('Language', info.languages.join(', ')),
        _item('Region', info.region),
        if (!hasFlagUrl) _item('Flag', info.flag),
      ],
    );
  }
}

class _SummaryJsonCard extends StatelessWidget {
  const _SummaryJsonCard({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combined Response Preview (GET /api/trips/:id/summary)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.coralA(0.06),
              border: Border.all(color: AppPalette.coralA(0.26)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.8,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _item(String label, String value) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(
        color: AppPalette.ink,
        fontSize: 14,
        height: 1.4,
      ),
      children: [
        TextSpan(
          text: '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppPalette.inkA(0.66),
          ),
        ),
        TextSpan(text: value),
      ],
    ),
  );
}
