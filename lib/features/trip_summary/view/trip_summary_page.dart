import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';
import 'package:api_6005cmd/shared/view/free_vector_map.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:api_6005cmd/shared/util/external_url_launcher_stub.dart'
    if (dart.library.io) 'package:api_6005cmd/shared/util/external_url_launcher_io.dart'
    if (dart.library.html) 'package:api_6005cmd/shared/util/external_url_launcher_web.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _SummaryTab {
  overview('Overview', Icons.space_dashboard_rounded),
  json('JSON', Icons.code_rounded);

  const _SummaryTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

typedef _WalkingRouteLoader =
    Future<WalkingRouteModel> Function({
      required double fromLatitude,
      required double fromLongitude,
      required double toLatitude,
      required double toLongitude,
      String mode,
    });

enum _RouteMode {
  walk('walk', 'Walk', Icons.directions_walk_rounded),
  vehicle('car', 'Vehicle', Icons.directions_car_rounded);

  const _RouteMode(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class TripSummaryPage extends StatefulWidget {
  const TripSummaryPage({
    super.key,
    required this.dataSource,
    required this.tripId,
    required this.onEditTrip,
  });

  final TripSummaryDataSource dataSource;
  final String tripId;
  final VoidCallback onEditTrip;

  @override
  State<TripSummaryPage> createState() => _TripSummaryPageState();
}

class _TripSummaryPageState extends State<TripSummaryPage> {
  late Future<TripSummaryModel?> _summaryFuture;
  _SummaryTab _tab = _SummaryTab.overview;
  final Map<String, int> _recommendationLimits = {};
  final Set<int> _routeMapDayIndexes = {};

  @override
  void initState() {
    super.initState();
    _summaryFuture = _fetchSummary();
  }

  @override
  void didUpdateWidget(covariant TripSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _recommendationLimits.clear();
      _routeMapDayIndexes.clear();
      _summaryFuture = _fetchSummary();
    }
  }

  Future<TripSummaryModel?> _fetchSummary({bool forceRefresh = false}) {
    return widget.dataSource.fetchSummary(
      widget.tripId,
      recommendationLimits: Map.unmodifiable(_recommendationLimits),
      routeMapDayIndexes: Set.unmodifiable(_routeMapDayIndexes),
      forceRefresh: forceRefresh,
    );
  }

  void _retrySummary() {
    setState(() {
      _summaryFuture = _fetchSummary();
    });
  }

  void _refreshExternalData() {
    setState(() {
      _summaryFuture = _fetchSummary(forceRefresh: true);
    });
  }

  void _loadAgendaRouteForDay(int dayIndex) {
    if (_routeMapDayIndexes.contains(dayIndex)) {
      return;
    }
    setState(() {
      _routeMapDayIndexes.add(dayIndex);
      _summaryFuture = _fetchSummary();
    });
  }

  void _setRecommendationLimit(String preference, int limit) {
    final key = preference.trim().toLowerCase();
    if (key.isEmpty || _recommendationLimits[key] == limit) {
      return;
    }
    setState(() {
      _recommendationLimits[key] = limit;
      _summaryFuture = _fetchSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TripSummaryModel?>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SummaryError(
            message: snapshot.error.toString(),
            onRetry: _retrySummary,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const Center(
            child: Text('No trip found. Select a trip from Home / Trip List.'),
          );
        }

        final json = const JsonEncoder.withIndent(
          '  ',
        ).convert(summary.toJson());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Trip Details / Smart Travel Summary',
              trailing: FilledButton.tonalIcon(
                onPressed: _refreshExternalData,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Refresh External Data'),
              ),
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
                    _SummaryTab.overview => _OverviewTab(
                      summary: summary,
                      onEditTrip: widget.onEditTrip,
                      routeLoader: widget.dataSource.fetchWalkingRoute,
                      recommendationLimits: _recommendationLimits,
                      onRecommendationLimitChanged: _setRecommendationLimit,
                      requestedAgendaRouteDays: _routeMapDayIndexes,
                      onLoadAgendaRouteDay: _loadAgendaRouteForDay,
                    ),
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

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

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
              'Could not load live trip summary',
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

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.value, required this.onChanged});

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
  const _OverviewTab({
    required this.summary,
    required this.onEditTrip,
    required this.routeLoader,
    required this.recommendationLimits,
    required this.onRecommendationLimitChanged,
    required this.requestedAgendaRouteDays,
    required this.onLoadAgendaRouteDay,
  });

  final TripSummaryModel summary;
  final VoidCallback onEditTrip;
  final _WalkingRouteLoader routeLoader;
  final Map<String, int> recommendationLimits;
  final void Function(String preference, int limit)
  onRecommendationLimitChanged;
  final Set<int> requestedAgendaRouteDays;
  final ValueChanged<int> onLoadAgendaRouteDay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TripDetailsCard(summary: summary),
        const SizedBox(height: 12),
        _MiniForecastPattern(forecast: summary.dailyWeatherForecast),
        const SizedBox(height: 12),
        _TripAgendaCard(
          agenda: summary.tripAgenda,
          requestedRouteDays: requestedAgendaRouteDays,
          onLoadRouteDay: onLoadAgendaRouteDay,
        ),
        const SizedBox(height: 12),
        _OverviewRecommendationCard(
          summary: summary,
          routeLoader: routeLoader,
          recommendationLimits: recommendationLimits,
          onRecommendationLimitChanged: onRecommendationLimitChanged,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: onEditTrip, child: const Text('Edit Trip')),
          ],
        ),
      ],
    );
  }
}

class _OverviewRecommendationCard extends StatelessWidget {
  const _OverviewRecommendationCard({
    required this.summary,
    required this.routeLoader,
    required this.recommendationLimits,
    required this.onRecommendationLimitChanged,
  });

  final TripSummaryModel summary;
  final _WalkingRouteLoader routeLoader;
  final Map<String, int> recommendationLimits;
  final void Function(String preference, int limit)
  onRecommendationLimitChanged;

  @override
  Widget build(BuildContext context) {
    return _RecommendationGroupsView(
      groups: summary.foursquareRecommendationGroups,
      startLatitude: summary.trip.latitude,
      startLongitude: summary.trip.longitude,
      routeLoader: routeLoader,
      recommendationLimits: recommendationLimits,
      onRecommendationLimitChanged: onRecommendationLimitChanged,
    );
  }
}

class _JsonTab extends StatelessWidget {
  const _JsonTab({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [_SummaryJsonCard(json: json)]);
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({required this.summary});

  final TripSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final trip = summary.trip;
    final destination = trip.destinationName.trim().isEmpty
        ? 'Untitled destination'
        : trip.destinationName.trim();
    final country = trip.destinationCountry.trim().isEmpty
        ? 'Country unavailable'
        : trip.destinationCountry.trim();
    final coordinateLabel =
        '${trip.latitude.toStringAsFixed(4)}, ${trip.longitude.toStringAsFixed(4)}';
    final notes = trip.travelNotes.trim();

    return MacPanel(
      color: AppPalette.whiteA(0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.coralA(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.coralA(0.26)),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: AppPalette.coral,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      country,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.inkA(0.68),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TripDetailTile(
                icon: Icons.event_rounded,
                label: 'Date Range',
                value: trip.dateRangeLabel,
                supporting: '${trip.totalDays} days',
                tone: AppPalette.blueA(0.08),
              ),
              _TripDetailTile(
                icon: Icons.tune_rounded,
                label: 'Preferences',
                value: _preferenceListLabel(trip.preferences),
                supporting: '${trip.preferences.length} selected',
                tone: AppPalette.mintA(0.08),
                width: 340,
              ),
              _TripDetailTile(
                icon: Icons.location_on_rounded,
                label: 'Coordinates',
                value: coordinateLabel,
                supporting: 'Pinned trip location',
                tone: AppPalette.coralA(0.08),
                width: 300,
                trailing: _MapIconButton(
                  tooltip: 'Open pinned trip location',
                  onPressed: () => _showPinnedMapDialog(
                    context,
                    title: destination,
                    latitude: trip.latitude,
                    longitude: trip.longitude,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.inkA(0.035),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppPalette.inkA(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_rounded,
                  color: AppPalette.inkA(0.62),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Travel Notes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.inkA(0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notes.isEmpty ? 'No travel notes added.' : notes,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ],
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

class _TripDetailTile extends StatelessWidget {
  const _TripDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.supporting,
    this.trailing,
    this.width = 260,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? supporting;
  final Widget? trailing;
  final Color tone;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 230, maxWidth: width),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppPalette.inkA(0.08)),
            ),
            child: Icon(icon, size: 20, color: AppPalette.inkA(0.78)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.inkA(0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (supporting != null && supporting!.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    supporting!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkA(0.58),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _MiniForecastPattern extends StatefulWidget {
  const _MiniForecastPattern({required this.forecast});

  final DailyWeatherForecastModel forecast;

  @override
  State<_MiniForecastPattern> createState() => _MiniForecastPatternState();
}

class _MiniForecastPatternState extends State<_MiniForecastPattern> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forecast = widget.forecast;
    final days = forecast.daily;
    if (days.isEmpty) {
      if (forecast.message.isEmpty) {
        return const SizedBox.shrink();
      }
      return MacPanel(
        color: AppPalette.blueA(0.06),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_busy_rounded, color: AppPalette.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Weather Forecast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    forecast.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkA(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MacPanel(
      color: AppPalette.blueA(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppPalette.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Daily Weather Forecast',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 32, bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < days.length; index++) ...[
                    _MiniForecastNode(day: days[index], units: forecast.units),
                    if (index != days.length - 1) const _ForecastConnector(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniForecastNode extends StatelessWidget {
  const _MiniForecastNode({required this.day, required this.units});

  final DailyWeatherForecastDayModel day;
  final String units;

  @override
  Widget build(BuildContext context) {
    final unit = _temperatureUnit(units);
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_forecastIcon(day.iconCode), color: AppPalette.blue),
              const SizedBox(width: 6),
              Text(
                _shortDateLabel(day.date),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatNumber(day.temperatureMin)}$unit / ${_formatNumber(day.temperatureMax)}$unit',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            day.condition,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.66)),
          ),
          if (day.precipitationProbabilityMax != null) ...[
            const SizedBox(height: 2),
            Text(
              '${_formatNumber(day.precipitationProbabilityMax!)}% rain',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.66)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastConnector extends StatelessWidget {
  const _ForecastConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 18),
      child: SizedBox(
        width: 44,
        height: 26,
        child: Center(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppPalette.blueA(0.36),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripAgendaCard extends StatelessWidget {
  const _TripAgendaCard({
    required this.agenda,
    required this.requestedRouteDays,
    required this.onLoadRouteDay,
  });

  final TripAgendaModel agenda;
  final Set<int> requestedRouteDays;
  final ValueChanged<int> onLoadRouteDay;

  @override
  Widget build(BuildContext context) {
    if (agenda.days.isEmpty) {
      return MacPanel(
        color: AppPalette.mintA(0.07),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.route_rounded, color: AppPalette.mint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Agenda / Tour Guide',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    agenda.title.toLowerCase().contains('insufficient')
                        ? agenda.title
                        : 'Insufficient data to plan an agenda',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkA(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final totalStops = agenda.days.fold<int>(
      0,
      (total, day) => total + day.items.length,
    );

    return MacPanel(
      color: AppPalette.mintA(0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppPalette.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trip Agenda / Tour Guide',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgendaSummaryChip(
                icon: Icons.calendar_month_rounded,
                label: '${agenda.tripDays} days',
              ),
              _AgendaSummaryChip(
                icon: Icons.place_rounded,
                label: '$totalStops stops',
              ),
              if (agenda.pattern.isNotEmpty)
                _AgendaSummaryChip(
                  icon: Icons.auto_awesome_rounded,
                  label: agenda.pattern,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            agenda.pattern.isEmpty
                ? agenda.title
                : '${agenda.title} • ${agenda.pattern}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.66)),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var index = 0; index < agenda.days.length; index++) ...[
                _TripAgendaDayTile(
                  day: agenda.days[index],
                  dayIndex: index,
                  routeRequested: requestedRouteDays.contains(index),
                  onLoadRoute: () => onLoadRouteDay(index),
                ),
                if (index != agenda.days.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
          if (agenda.checklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: agenda.checklist
                  .map((item) => _AgendaChecklistChip(label: item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripAgendaDayTile extends StatelessWidget {
  const _TripAgendaDayTile({
    required this.day,
    required this.dayIndex,
    required this.routeRequested,
    required this.onLoadRoute,
  });

  final TripAgendaDayModel day;
  final int dayIndex;
  final bool routeRequested;
  final VoidCallback onLoadRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.mintA(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.mintA(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.mintA(0.24)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DAY',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppPalette.mint,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${dayIndex + 1}',
                      style: const TextStyle(
                        color: AppPalette.mint,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.label} • ${_shortDateLabel(day.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.inkA(0.62),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.theme,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: routeRequested ? null : onLoadRoute,
                icon: Icon(
                  routeRequested
                      ? Icons.route_rounded
                      : Icons.alt_route_rounded,
                  size: 16,
                ),
                label: Text(routeRequested ? 'Loaded' : 'Get route'),
              ),
            ],
          ),
          if (day.weatherNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _AgendaInlineNotice(
              icon: Icons.thunderstorm_rounded,
              text: day.weatherNote,
            ),
          ],
          const SizedBox(height: 10),
          Column(
            children: [
              for (
                var itemIndex = 0;
                itemIndex < day.items.length;
                itemIndex++
              ) ...[
                _AgendaItemTile(
                  item: day.items[itemIndex],
                  stopNumber: itemIndex + 1,
                ),
                if (itemIndex != day.items.length - 1)
                  const SizedBox(height: 6),
              ],
            ],
          ),
          if (routeRequested) ...[
            const SizedBox(height: 10),
            _AgendaDayRouteMap(routeMap: day.routeMap),
          ],
        ],
      ),
    );
  }
}

class _AgendaSummaryChip extends StatelessWidget {
  const _AgendaSummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.mintA(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppPalette.mint),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.inkA(0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaInlineNotice extends StatelessWidget {
  const _AgendaInlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.blueA(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.blueA(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppPalette.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaDayRouteMap extends StatefulWidget {
  const _AgendaDayRouteMap({required this.routeMap});

  final AgendaRouteMapModel routeMap;

  @override
  State<_AgendaDayRouteMap> createState() => _AgendaDayRouteMapState();
}

class _AgendaDayRouteMapState extends State<_AgendaDayRouteMap> {
  final ScrollController _routePillScrollController = ScrollController();
  Set<int> _visibleLegNumbers = {};
  int? _selectedLegNumber;

  @override
  void initState() {
    super.initState();
    _resetVisibleLegs();
  }

  @override
  void didUpdateWidget(covariant _AgendaDayRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeMap != widget.routeMap) {
      _resetVisibleLegs();
    }
  }

  @override
  void dispose() {
    _routePillScrollController.dispose();
    super.dispose();
  }

  void _resetVisibleLegs() {
    final drawableLegs = _drawableLegs(widget.routeMap);
    if (drawableLegs.isEmpty) {
      _visibleLegNumbers = {};
      _selectedLegNumber = null;
      return;
    }

    final firstLegNumber = drawableLegs.first.legNumber;
    _visibleLegNumbers = drawableLegs.length > 3
        ? {firstLegNumber}
        : drawableLegs.map((leg) => leg.legNumber).toSet();
    _selectedLegNumber = firstLegNumber;
  }

  void _toggleLeg(AgendaRouteLegModel leg) {
    setState(() {
      if (_visibleLegNumbers.contains(leg.legNumber)) {
        _visibleLegNumbers.remove(leg.legNumber);
      } else {
        _visibleLegNumbers.add(leg.legNumber);
      }

      final visibleLegs = _drawableLegs(
        widget.routeMap,
      ).where((item) => _visibleLegNumbers.contains(item.legNumber)).toList();
      _selectedLegNumber = visibleLegs.isEmpty
          ? null
          : _visibleLegNumbers.contains(leg.legNumber)
          ? leg.legNumber
          : visibleLegs.first.legNumber;
    });
  }

  void _showAllLegs() {
    final drawableLegs = _drawableLegs(widget.routeMap);
    setState(() {
      _visibleLegNumbers = drawableLegs.map((leg) => leg.legNumber).toSet();
      _selectedLegNumber = drawableLegs.isEmpty
          ? null
          : drawableLegs.first.legNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawableLegs = _drawableLegs(widget.routeMap);
    final visibleLegs = drawableLegs
        .where((leg) => _visibleLegNumbers.contains(leg.legNumber))
        .toList();
    final selectedLeg = _selectedRouteLeg(visibleLegs, _selectedLegNumber);
    final activeTitles = selectedLeg == null
        ? const <String>{}
        : {selectedLeg.fromTitle, selectedLeg.toTitle};
    final selectedColor = selectedLeg == null
        ? AppPalette.blue
        : _colorFromHex(selectedLeg.color, fallback: AppPalette.blue);
    final markerPoints = widget.routeMap.markers
        .where((marker) => marker.latitude != null && marker.longitude != null)
        .map((marker) {
          final isActive = activeTitles.contains(marker.title);
          return FreeVectorMapPoint(
            latitude: marker.latitude!,
            longitude: marker.longitude!,
            color: isActive
                ? selectedColor
                : _colorFromHex(marker.color, fallback: AppPalette.blue),
            radius: isActive
                ? 9.2
                : marker.kind == 'start'
                ? 8
                : 6.8,
          );
        })
        .toList();
    final routeLines = visibleLegs.map((leg) {
      final isSelected = selectedLeg?.legNumber == leg.legNumber;
      return FreeVectorMapRoute(
        points: leg.path
            .map(
              (point) => FreeVectorMapPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                color: _colorFromHex(leg.color, fallback: AppPalette.blue),
                radius: 0,
              ),
            )
            .toList(),
        color: _colorFromHex(leg.color, fallback: AppPalette.blue),
        width: isSelected
            ? 6
            : leg.routeAvailable
            ? 4.4
            : 3,
        opacity: isSelected
            ? 0.98
            : leg.routeAvailable
            ? 0.58
            : 0.38,
      );
    }).toList();

    if (markerPoints.length < 2 && routeLines.isEmpty) {
      return _AgendaRouteUnavailable(message: widget.routeMap.message);
    }

    final center = markerPoints.isNotEmpty
        ? markerPoints.first
        : routeLines.first.points.first;

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.blueA(0.16)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppPalette.blue, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Day Route Overview',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                widget.routeMap.modeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(0.62),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgendaRouteStatChip(
                icon: Icons.route_rounded,
                label: _formatRouteDistance(
                  widget.routeMap.totalDistanceMeters,
                ),
              ),
              _AgendaRouteStatChip(
                icon: Icons.schedule_rounded,
                label: _formatRouteDuration(
                  widget.routeMap.totalDurationSeconds,
                ),
              ),
              _AgendaRouteStatChip(
                icon: Icons.timeline_rounded,
                label: '${widget.routeMap.legCount} legs',
              ),
              if (visibleLegs.length != drawableLegs.length)
                _AgendaRouteActionChip(
                  icon: Icons.visibility_rounded,
                  label: 'Show all',
                  onTap: _showAllLegs,
                ),
            ],
          ),
          if (widget.routeMap.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.routeMap.message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.58)),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 260,
              child: Stack(
                children: [
                  FreeVectorMap(
                    centerLatitude: center.latitude,
                    centerLongitude: center.longitude,
                    initialZoom: 13,
                    fitToBounds: true,
                    routes: routeLines,
                    markers: markerPoints,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _AgendaRouteDetailOverlay(
                      leg: selectedLeg,
                      visibleCount: visibleLegs.length,
                      totalCount: drawableLegs.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a route pill to hide or display that path on the map.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.58)),
          ),
          const SizedBox(height: 6),
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            child: Scrollbar(
              controller: _routePillScrollController,
              thumbVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _routePillScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (final leg in widget.routeMap.legs) ...[
                      _AgendaRouteLegendChip(
                        leg: leg,
                        visible: _visibleLegNumbers.contains(leg.legNumber),
                        selected: selectedLeg?.legNumber == leg.legNumber,
                        onTap: () => _toggleLeg(leg),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRouteUnavailable extends StatelessWidget {
  const _AgendaRouteUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.inkA(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: AppPalette.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.isEmpty
                  ? 'Route overview appears when recommendation coordinates are available.'
                  : message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRouteStatChip extends StatelessWidget {
  const _AgendaRouteStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.blueA(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.blueA(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppPalette.blue),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.inkA(0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRouteActionChip extends StatelessWidget {
  const _AgendaRouteActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.mintA(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.mintA(0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppPalette.mint),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaRouteDetailOverlay extends StatelessWidget {
  const _AgendaRouteDetailOverlay({
    required this.leg,
    required this.visibleCount,
    required this.totalCount,
  });

  final AgendaRouteLegModel? leg;
  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final currentLeg = leg;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.whiteA(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.inkA(0.14)),
          boxShadow: [
            BoxShadow(
              color: AppPalette.inkA(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: currentLeg == null
              ? Text(
                  totalCount == 0
                      ? 'No route legs available.'
                      : 'All route paths hidden. Tap a pill below to display one.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.inkA(0.7),
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _colorFromHex(
                              currentLeg.color,
                              fallback: AppPalette.blue,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Route ${currentLeg.legNumber}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.inkA(0.8),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$visibleCount/$totalCount shown',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.inkA(0.52)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _AgendaRouteOverlayRow(
                      label: 'Depart',
                      value: currentLeg.fromTitle,
                    ),
                    _AgendaRouteOverlayRow(
                      label: 'Arrive',
                      value: currentLeg.toTitle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_formatRouteDistance(currentLeg.distanceMeters)} • ${_formatRouteDuration(currentLeg.durationSeconds)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.inkA(0.62),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AgendaRouteOverlayRow extends StatelessWidget {
  const _AgendaRouteOverlayRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.52),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.78),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRouteLegendChip extends StatelessWidget {
  const _AgendaRouteLegendChip({
    required this.leg,
    required this.visible,
    required this.selected,
    required this.onTap,
  });

  final AgendaRouteLegModel leg;
  final bool visible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(leg.color, fallback: AppPalette.blue);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: visible ? AppPalette.whiteA(0.82) : AppPalette.inkA(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.7)
                : AppPalette.inkA(visible ? 0.12 : 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: visible ? 1 : 0.24),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Icon(
              visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 13,
              color: AppPalette.inkA(visible ? 0.62 : 0.32),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${leg.legNumber}. ${leg.toTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(visible ? 0.74 : 0.4),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _formatRouteDistance(leg.distanceMeters),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(visible ? 0.54 : 0.34),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<AgendaRouteLegModel> _drawableLegs(AgendaRouteMapModel routeMap) {
  return routeMap.legs.where((leg) => leg.path.length > 1).toList();
}

AgendaRouteLegModel? _selectedRouteLeg(
  List<AgendaRouteLegModel> visibleLegs,
  int? selectedLegNumber,
) {
  if (visibleLegs.isEmpty) {
    return null;
  }
  for (final leg in visibleLegs) {
    if (leg.legNumber == selectedLegNumber) {
      return leg;
    }
  }
  return visibleLegs.first;
}

class _AgendaItemTile extends StatefulWidget {
  const _AgendaItemTile({required this.item, required this.stopNumber});

  final TripAgendaItemModel item;
  final int stopNumber;

  @override
  State<_AgendaItemTile> createState() => _AgendaItemTileState();
}

class _AgendaItemTileState extends State<_AgendaItemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final stopNumber = widget.stopNumber;
    final isVerified = item.availability.verifiedForVisitTime;
    final hasCoordinates = item.latitude != null && item.longitude != null;
    final accentColor = item.kind == 'food'
        ? AppPalette.coral
        : AppPalette.mint;
    final categoryLabel = item.category.trim().isEmpty
        ? item.kind
        : item.category.trim();
    final preferenceLabel = item.preference.trim().isEmpty
        ? ''
        : AddTripFormData.preferenceLabel(item.preference);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey(
          '${item.startTime}-${item.endTime}-${item.title}-${item.address}',
        ),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        backgroundColor: AppPalette.whiteA(0.78),
        collapsedBackgroundColor: AppPalette.whiteA(0.72),
        onExpansionChanged: (expanded) {
          setState(() {
            _expanded = expanded;
          });
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppPalette.mintA(0.22)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppPalette.mintA(0.18)),
        ),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              _agendaKindIcon(item.kind),
              color: accentColor,
              size: 18,
            ),
          ),
        ),
        title: Text(
          '$stopNumber. ${item.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgendaPlaceActionButton(
              icon: Icons.map_rounded,
              tooltip: hasCoordinates
                  ? 'View pinned location'
                  : 'Location pin unavailable',
              enabled: hasCoordinates,
              color: AppPalette.mint,
              onPressed: () => _showPinnedMapDialog(
                context,
                title: item.title,
                latitude: item.latitude!,
                longitude: item.longitude!,
              ),
            ),
            const SizedBox(width: 4),
            _AgendaPlaceActionButton(
              icon: Icons.open_in_new_rounded,
              tooltip: 'Open in Google Maps',
              enabled: true,
              color: AppPalette.blue,
              onPressed: () => _openAgendaPlaceInGoogleMaps(context, item),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.expand_more_rounded,
                color: AppPalette.inkA(0.56),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _AgendaTinyBadge(
                icon: Icons.schedule_rounded,
                label: _agendaTimeLabel(item),
                color: AppPalette.blue,
              ),
              _AgendaTinyBadge(
                icon: isVerified
                    ? Icons.check_circle_rounded
                    : Icons.event_available_rounded,
                label: isVerified ? 'Open' : 'Flexible',
                color: isVerified ? AppPalette.mint : AppPalette.coral,
              ),
              if (item.distanceMeters > 0)
                _AgendaTinyBadge(
                  icon: Icons.social_distance_rounded,
                  label: _formatRouteDistance(item.distanceMeters),
                  color: AppPalette.ink,
                ),
            ],
          ),
        ),
        children: [
          const Divider(height: 10),
          _AgendaDetailRow(
            icon: Icons.category_rounded,
            label: 'Category',
            value: [
              categoryLabel,
              if (preferenceLabel.isNotEmpty) preferenceLabel,
            ].join(' • '),
          ),
          _AgendaDetailRow(
            icon: Icons.access_time_filled_rounded,
            label: 'Visit window',
            value: item.visitWindow.isEmpty
                ? _agendaTimeLabel(item)
                : item.visitWindow,
          ),
          _AgendaDetailRow(
            icon: Icons.fact_check_rounded,
            label: 'Availability',
            value: item.availability.label,
          ),
          if (item.description.isNotEmpty)
            _AgendaDetailRow(
              icon: Icons.notes_rounded,
              label: 'Why this place',
              value: item.description,
            ),
          if (item.address.isNotEmpty)
            _AgendaDetailRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: item.address,
            ),
          if (item.latitude != null && item.longitude != null)
            _AgendaDetailRow(
              icon: Icons.map_rounded,
              label: 'Coordinates',
              value:
                  '${_formatNumber(item.latitude!)} / ${_formatNumber(item.longitude!)}',
            ),
        ],
      ),
    );
  }
}

class _AgendaPlaceActionButton extends StatelessWidget {
  const _AgendaPlaceActionButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppPalette.inkA(0.34);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : AppPalette.inkA(0.04),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.2)
                : AppPalette.inkA(0.08),
          ),
        ),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          iconSize: 16,
          color: effectiveColor,
          disabledColor: AppPalette.inkA(0.3),
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _AgendaTinyBadge extends StatelessWidget {
  const _AgendaTinyBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaDetailRow extends StatelessWidget {
  const _AgendaDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppPalette.inkA(0.48)),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.58),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.76)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaChecklistChip extends StatelessWidget {
  const _AgendaChecklistChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_rounded, size: 16),
      label: Text(label),
      side: BorderSide(color: AppPalette.mintA(0.22)),
      backgroundColor: AppPalette.whiteA(0.72),
      labelStyle: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.74)),
    );
  }
}

class _RecommendationGroupsView extends StatelessWidget {
  const _RecommendationGroupsView({
    required this.groups,
    required this.startLatitude,
    required this.startLongitude,
    required this.routeLoader,
    required this.recommendationLimits,
    this.onRecommendationLimitChanged,
  });

  final List<RecommendationGroupModel> groups;
  final double startLatitude;
  final double startLongitude;
  final _WalkingRouteLoader routeLoader;
  final Map<String, int> recommendationLimits;
  final void Function(String preference, int limit)?
  onRecommendationLimitChanged;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return MacPanel(
        color: AppPalette.coralA(0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.recommend_rounded,
                  color: AppPalette.coral,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommendations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _RecommendationLimitDropdown(value: 5, onChanged: null),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No Foursquare recommendations available for this trip yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.72)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          MacPanel(
            color: AppPalette.coralA(0.08),
            child: _RecommendationView(
              group: groups[index],
              startLatitude: startLatitude,
              startLongitude: startLongitude,
              routeLoader: routeLoader,
              recommendationLimit: _limitForGroup(groups[index]),
              onRecommendationLimitChanged: onRecommendationLimitChanged,
            ),
          ),
          if (index != groups.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  int _limitForGroup(RecommendationGroupModel group) {
    final key = group.preference.trim().toLowerCase();
    return recommendationLimits[key] ?? group.limit;
  }
}

class _RecommendationView extends StatelessWidget {
  const _RecommendationView({
    required this.group,
    required this.startLatitude,
    required this.startLongitude,
    required this.routeLoader,
    required this.recommendationLimit,
    required this.onRecommendationLimitChanged,
  });

  final RecommendationGroupModel group;
  final double startLatitude;
  final double startLongitude;
  final _WalkingRouteLoader routeLoader;
  final int recommendationLimit;
  final void Function(String preference, int limit)?
  onRecommendationLimitChanged;

  @override
  Widget build(BuildContext context) {
    final recommendations = group.recommendations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _recommendationIconForPreference(group.preference),
              color: AppPalette.coral,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _recommendationTitleForPreference(group.preference),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _RecommendationLimitDropdown(
              value: recommendationLimit,
              onChanged: onRecommendationLimitChanged == null
                  ? null
                  : (limit) =>
                        onRecommendationLimitChanged!(group.preference, limit),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recommendations.isEmpty)
          Text(
            'No places returned for this preference.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.72)),
          )
        else
          Column(
            children: [
              for (var index = 0; index < recommendations.length; index++) ...[
                _RecommendationRow(
                  recommendation: recommendations[index],
                  preference: group.preference,
                  startLatitude: startLatitude,
                  startLongitude: startLongitude,
                  routeLoader: routeLoader,
                ),
                if (index != recommendations.length - 1)
                  Divider(color: AppPalette.inkA(0.1), height: 18),
              ],
            ],
          ),
      ],
    );
  }
}

class _RecommendationLimitDropdown extends StatelessWidget {
  const _RecommendationLimitDropdown({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppPalette.inkA(onChanged == null ? 0.48 : 0.82),
      fontWeight: FontWeight.w700,
    );

    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(onChanged == null ? 0.42 : 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.coralA(0.24)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: AppPalette.inkA(onChanged == null ? 0.42 : 0.72),
          ),
          selectedItemBuilder: (context) => const [3, 5, 10]
              .map(
                (limit) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Show $limit'),
                ),
              )
              .toList(),
          items: const [3, 5, 10]
              .map(
                (limit) => DropdownMenuItem<int>(
                  value: limit,
                  child: Text('$limit results'),
                ),
              )
              .toList(),
          style: textStyle,
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null) {
                    onChanged!(value);
                  }
                },
        ),
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({
    required this.recommendation,
    required this.preference,
    required this.startLatitude,
    required this.startLongitude,
    required this.routeLoader,
  });

  final RecommendationModel recommendation;
  final String preference;
  final double startLatitude;
  final double startLongitude;
  final _WalkingRouteLoader routeLoader;

  @override
  Widget build(BuildContext context) {
    final address = recommendation.address.trim();
    final latitude = recommendation.latitude;
    final longitude = recommendation.longitude;
    final hasCoordinates = latitude != null && longitude != null;
    final details = [
      recommendation.category,
      '${recommendation.distanceMeters} m away',
      if (address.isNotEmpty) address,
    ].where((part) => part.trim().isNotEmpty).join('\n');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.whiteA(0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppPalette.coralA(0.24)),
          ),
          child: Icon(
            _recommendationIconForPreference(preference),
            color: AppPalette.coral,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                details,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.68)),
              ),
            ],
          ),
        ),
        if (hasCoordinates) ...[
          const SizedBox(width: 8),
          _MapIconButton(
            tooltip: 'Open walking route',
            onPressed: () => _showWalkingRouteDialog(
              context,
              title: recommendation.name,
              fromLatitude: startLatitude,
              fromLongitude: startLongitude,
              toLatitude: latitude,
              toLongitude: longitude,
              routeLoader: routeLoader,
            ),
          ),
        ],
      ],
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.whiteA(0.74),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.blueA(0.24)),
        ),
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: AppPalette.blue,
          onPressed: onPressed,
          icon: const Icon(Icons.map_rounded),
        ),
      ),
    );
  }
}

Future<void> _showPinnedMapDialog(
  BuildContext context, {
  required String title,
  required double latitude,
  required double longitude,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppPalette.coral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close map',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 360,
                    child: FreeVectorMap(
                      centerLatitude: latitude,
                      centerLongitude: longitude,
                      initialZoom: 17,
                      markers: [
                        FreeVectorMapPoint(
                          latitude: latitude,
                          longitude: longitude,
                          color: AppPalette.coral,
                          radius: 9,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    FreeVectorMap.attribution,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkA(0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _openAgendaPlaceInGoogleMaps(
  BuildContext context,
  TripAgendaItemModel item,
) async {
  final url = _googleMapsUrlForAgendaItem(item);
  try {
    final opened = await openExternalUrl(url);
    if (opened) {
      return;
    }
  } catch (error) {
    debugPrint('Could not open Google Maps link: $error');
  }

  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Google Maps link copied. Open it in your browser.'),
    ),
  );
}

Future<void> _showWalkingRouteDialog(
  BuildContext context, {
  required String title,
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
  required _WalkingRouteLoader routeLoader,
}) {
  var selectedMode = _RouteMode.walk;
  Future<WalkingRouteModel> loadRoute(_RouteMode mode) {
    return routeLoader(
      fromLatitude: fromLatitude,
      fromLongitude: fromLongitude,
      toLatitude: toLatitude,
      toLongitude: toLongitude,
      mode: mode.value,
    );
  }

  var routeFuture = loadRoute(selectedMode);

  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return FutureBuilder<WalkingRouteModel>(
                  future: routeFuture,
                  builder: (context, snapshot) {
                    final route = snapshot.data;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(selectedMode.icon, color: AppPalette.coral),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close route',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _RouteModeTabBar(
                          selectedMode: selectedMode,
                          onChanged: (mode) {
                            setDialogState(() {
                              selectedMode = mode;
                              routeFuture = loadRoute(mode);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (snapshot.connectionState != ConnectionState.done)
                          const SizedBox(
                            height: 420,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (snapshot.hasError)
                          SizedBox(
                            height: 240,
                            child: Center(
                              child: Text(
                                snapshot.error.toString(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppPalette.coral),
                              ),
                            ),
                          )
                        else if (route == null || route.path.isEmpty)
                          SizedBox(
                            height: 240,
                            child: Center(
                              child: Text(
                                '${selectedMode.label} route unavailable for this location.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          )
                        else ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _RouteStatChip(
                                icon: Icons.route_rounded,
                                label: '${route.modeLabel} Distance',
                                value: _formatRouteDistance(
                                  route.distanceMeters,
                                ),
                              ),
                              _RouteStatChip(
                                icon: Icons.schedule_rounded,
                                label: '${route.modeLabel} Time',
                                value: _formatRouteDuration(
                                  route.estimatedWalkingSeconds,
                                ),
                              ),
                              _RouteStatChip(
                                icon: Icons.map_rounded,
                                label: 'Route Source',
                                value: _routeSourceLabel(route),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _WalkingRouteMap(
                            route: route,
                            fromLatitude: fromLatitude,
                            fromLongitude: fromLongitude,
                            toLatitude: toLatitude,
                            toLongitude: toLongitude,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _RouteStatChip extends StatelessWidget {
  const _RouteStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.blueA(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppPalette.blue, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
              ),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteModeTabBar extends StatelessWidget {
  const _RouteModeTabBar({required this.selectedMode, required this.onChanged});

  final _RouteMode selectedMode;
  final ValueChanged<_RouteMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return MacPanel(
      padding: const EdgeInsets.all(6),
      color: AppPalette.whiteA(0.68),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final mode in _RouteMode.values) ...[
              _RouteModeTab(
                mode: mode,
                selected: selectedMode == mode,
                onTap: () => onChanged(mode),
              ),
              if (mode != _RouteMode.values.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteModeTab extends StatelessWidget {
  const _RouteModeTab({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _RouteMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppPalette.inkA(0.76);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppPalette.coral : AppPalette.whiteA(0.56),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppPalette.coral : AppPalette.inkA(0.12),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.coralA(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, size: 18, color: foreground),
            const SizedBox(width: 7),
            Text(
              mode.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkingRouteMap extends StatelessWidget {
  const _WalkingRouteMap({
    required this.route,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
  });

  final WalkingRouteModel route;
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;

  @override
  Widget build(BuildContext context) {
    final routePoints = route.path
        .map(
          (point) => FreeVectorMapPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            color: AppPalette.blue,
            radius: 0,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 380,
            child: FreeVectorMap(
              centerLatitude: (fromLatitude + toLatitude) / 2,
              centerLongitude: (fromLongitude + toLongitude) / 2,
              initialZoom: _initialRouteZoom(
                fromLatitude,
                fromLongitude,
                toLatitude,
                toLongitude,
              ),
              fitToBounds: true,
              route: routePoints,
              markers: [
                FreeVectorMapPoint(
                  latitude: fromLatitude,
                  longitude: fromLongitude,
                  color: AppPalette.blue,
                  radius: 7,
                ),
                FreeVectorMapPoint(
                  latitude: toLatitude,
                  longitude: toLongitude,
                  color: AppPalette.coral,
                  radius: 9,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          FreeVectorMap.attribution,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.55)),
        ),
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

String _recommendationTitleForPreference(String preference) {
  return '${AddTripFormData.preferenceLabel(preference)} Recommendations';
}

IconData _recommendationIconForPreference(String preference) {
  return switch (preference.trim().toLowerCase()) {
    'food' => Icons.restaurant_menu_rounded,
    'culture' => Icons.museum_rounded,
    'nature' => Icons.park_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'family' => Icons.family_restroom_rounded,
    'adventure' => Icons.explore_rounded,
    'history' => Icons.account_balance_rounded,
    'arts' => Icons.palette_rounded,
    'outdoors' => Icons.terrain_rounded,
    'wellness' => Icons.spa_rounded,
    'nightlife' => Icons.nightlife_rounded,
    _ => Icons.recommend_rounded,
  };
}

IconData _agendaKindIcon(String kind) {
  return kind == 'food' ? Icons.restaurant_menu_rounded : Icons.place_rounded;
}

String _preferenceListLabel(List<String> preferences) {
  if (preferences.isEmpty) {
    return 'None selected';
  }
  return preferences.map(AddTripFormData.preferenceLabel).join(', ');
}

String _temperatureUnit(String units) {
  return switch (units) {
    'imperial' => '°F',
    'standard' => 'K',
    _ => '°C',
  };
}

String _formatNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.toStringAsFixed(0);
  }
  return asDouble.toStringAsFixed(1);
}

IconData _forecastIcon(String iconCode) {
  return switch (iconCode) {
    'clear' => Icons.wb_sunny_rounded,
    'cloudy' || 'fog' => Icons.cloud_rounded,
    'rain' => Icons.water_drop_rounded,
    'snow' => Icons.ac_unit_rounded,
    'storm' => Icons.flash_on_rounded,
    _ => Icons.wb_twilight_rounded,
  };
}

String _formatRouteDistance(num meters) {
  if (meters >= 1000) {
    return '${_formatNumber(meters / 1000)} km';
  }
  return '${meters.round()} m';
}

String _formatRouteDuration(int seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return '$hours hr';
  }
  return '$hours hr $remainingMinutes min';
}

String _agendaTimeLabel(TripAgendaItemModel item) {
  final start = item.startTime.trim();
  final end = item.endTime.trim();
  if (start.isNotEmpty && end.isNotEmpty) {
    return '$start - $end';
  }
  if (item.visitWindow.trim().isNotEmpty) {
    return item.visitWindow.trim();
  }
  if (item.timeOfDay.trim().isNotEmpty) {
    return item.timeOfDay.trim();
  }
  return 'Time flexible';
}

String _googleMapsUrlForAgendaItem(TripAgendaItemModel item) {
  final latitude = item.latitude;
  final longitude = item.longitude;
  final queryParts = [
    if (item.title.trim().isNotEmpty) item.title.trim(),
    if (item.address.trim().isNotEmpty) item.address.trim(),
    if (latitude != null && longitude != null)
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
  ];
  final query = queryParts.isEmpty ? 'Google Maps' : queryParts.join(' ');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  }).toString();
}

String _routeSourceLabel(WalkingRouteModel route) {
  final provider = route.provider == 'google-routes'
      ? 'Google Routes'
      : route.provider;
  final mode = route.transitModes.isEmpty
      ? route.travelMode
      : '${route.travelMode} ${route.transitModes.join('/')}';
  return '$provider $mode';
}

Color _colorFromHex(String hex, {required Color fallback}) {
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length != 6) {
    return fallback;
  }
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) {
    return fallback;
  }
  return Color(0xff000000 | value);
}

double _initialRouteZoom(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  final latDelta = (startLatitude - endLatitude).abs();
  final lngDelta = (startLongitude - endLongitude).abs();
  final span = latDelta > lngDelta ? latDelta : lngDelta;
  if (span > 1) {
    return 7;
  }
  if (span > 0.2) {
    return 10;
  }
  if (span > 0.05) {
    return 12;
  }
  if (span > 0.01) {
    return 14;
  }
  return 16;
}

String _shortDateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]}';
}
