import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';
import 'package:api_6005cmd/shared/view/free_vector_map.dart';
import 'package:api_6005cmd/shared/view/layer_badges.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';

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
      _summaryFuture = _fetchSummary();
    }
  }

  Future<TripSummaryModel?> _fetchSummary() {
    return widget.dataSource.fetchSummary(
      widget.tripId,
      recommendationLimits: Map.unmodifiable(_recommendationLimits),
    );
  }

  void _refreshMock() {
    setState(() {
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
            onRetry: _refreshMock,
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
              subtitle:
                  'One linked story from one trip record. Switch views to inspect the overview or raw payload.',
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
                    _SummaryTab.overview => _OverviewTab(
                      summary: summary,
                      onEditTrip: widget.onEditTrip,
                      routeLoader: widget.dataSource.fetchWalkingRoute,
                      recommendationLimits: _recommendationLimits,
                      onRecommendationLimitChanged: _setRecommendationLimit,
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
  });

  final TripSummaryModel summary;
  final VoidCallback onEditTrip;
  final _WalkingRouteLoader routeLoader;
  final Map<String, int> recommendationLimits;
  final void Function(String preference, int limit)
  onRecommendationLimitChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _TripDetailsCard(summary: summary),
        const SizedBox(height: 12),
        _MiniForecastPattern(forecast: summary.dailyWeatherForecast),
        const SizedBox(height: 12),
        _TripAgendaCard(agenda: summary.tripAgenda),
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
  const _TripAgendaCard({required this.agenda});

  final TripAgendaModel agenda;

  @override
  Widget build(BuildContext context) {
    if (agenda.days.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Text(
                '${agenda.tripDays} days',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                _TripAgendaDayTile(day: agenda.days[index]),
                if (index != agenda.days.length - 1)
                  Divider(color: AppPalette.inkA(0.1), height: 18),
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
  const _TripAgendaDayTile({required this.day});

  final TripAgendaDayModel day;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                _shortDateLabel(day.date),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.theme,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (day.weatherNote.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  day.weatherNote,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.66)),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: day.items
                    .map((item) => _AgendaItemChip(item: item))
                    .toList(),
              ),
              const SizedBox(height: 10),
              _AgendaDayRouteMap(routeMap: day.routeMap),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgendaDayRouteMap extends StatelessWidget {
  const _AgendaDayRouteMap({required this.routeMap});

  final AgendaRouteMapModel routeMap;

  @override
  Widget build(BuildContext context) {
    final markerPoints = routeMap.markers
        .where((marker) => marker.latitude != null && marker.longitude != null)
        .map(
          (marker) => FreeVectorMapPoint(
            latitude: marker.latitude!,
            longitude: marker.longitude!,
            color: _colorFromHex(marker.color, fallback: AppPalette.blue),
            radius: marker.kind == 'start' ? 8 : 6.8,
          ),
        )
        .toList();
    final routeLines = routeMap.legs
        .where((leg) => leg.path.length > 1)
        .map(
          (leg) => FreeVectorMapRoute(
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
            width: leg.routeAvailable ? 5 : 3.2,
            opacity: leg.routeAvailable ? 0.94 : 0.54,
          ),
        )
        .toList();

    if (markerPoints.length < 2 && routeLines.isEmpty) {
      return _AgendaRouteUnavailable(message: routeMap.message);
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
                routeMap.modeLabel,
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
                label: _formatRouteDistance(routeMap.totalDistanceMeters),
              ),
              _AgendaRouteStatChip(
                icon: Icons.schedule_rounded,
                label: _formatRouteDuration(routeMap.totalDurationSeconds),
              ),
              _AgendaRouteStatChip(
                icon: Icons.timeline_rounded,
                label: '${routeMap.legCount} legs',
              ),
            ],
          ),
          if (routeMap.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              routeMap.message,
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
              child: FreeVectorMap(
                centerLatitude: center.latitude,
                centerLongitude: center.longitude,
                initialZoom: 13,
                fitToBounds: true,
                routes: routeLines,
                markers: markerPoints,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final leg in routeMap.legs) ...[
                  _AgendaRouteLegendChip(leg: leg),
                  const SizedBox(width: 8),
                ],
              ],
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

class _AgendaRouteLegendChip extends StatelessWidget {
  const _AgendaRouteLegendChip({required this.leg});

  final AgendaRouteLegModel leg;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(leg.color, fallback: AppPalette.blue);
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.inkA(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '${leg.legNumber}. ${leg.toTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.inkA(0.74),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _formatRouteDistance(leg.distanceMeters),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.inkA(0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaItemChip extends StatelessWidget {
  const _AgendaItemChip({required this.item});

  final TripAgendaItemModel item;

  @override
  Widget build(BuildContext context) {
    final isVerified = item.availability.verifiedForVisitTime;
    return Container(
      width: 286,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.whiteA(0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.mintA(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _agendaKindIcon(item.kind),
                color: item.kind == 'food' ? AppPalette.coral : AppPalette.mint,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.timeOfDay,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.inkA(0.68),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                item.visitWindow,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkA(0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: isVerified
                  ? AppPalette.mintA(0.12)
                  : AppPalette.coralA(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isVerified
                    ? AppPalette.mintA(0.28)
                    : AppPalette.coralA(0.28),
              ),
            ),
            child: Text(
              isVerified ? 'Open at visit time' : 'Flexible backup',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isVerified ? AppPalette.mint : AppPalette.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.66)),
            ),
          ],
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.58)),
            ),
          ],
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
