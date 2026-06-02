import 'dart:convert';

import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:api_6005cmd/features/add_trip/data/add_trip_form_data.dart';
import 'package:api_6005cmd/features/trip_summary/data/trip_summary_data_source.dart';
import 'package:api_6005cmd/features/trip_summary/model/trip_summary_model.dart';
import 'package:api_6005cmd/shared/view/layer_badges.dart';
import 'package:api_6005cmd/shared/view/mac_panel.dart';
import 'package:api_6005cmd/shared/view/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum _SummaryTab {
  overview('Overview', Icons.space_dashboard_rounded),
  modules('Modules', Icons.widgets_rounded),
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
  car('car', 'Car', Icons.directions_car_rounded),
  bus('bus', 'Bus', Icons.directions_bus_rounded),
  rail('rail', 'Train / LRT / MRT', Icons.train_rounded);

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
                    _SummaryTab.overview => _OverviewTab(
                      summary: summary,
                      onEditTrip: widget.onEditTrip,
                      routeLoader: widget.dataSource.fetchWalkingRoute,
                      recommendationLimits: _recommendationLimits,
                      onRecommendationLimitChanged: _setRecommendationLimit,
                    ),
                    _SummaryTab.modules => _ModulesTab(
                      summary: summary,
                      routeLoader: widget.dataSource.fetchWalkingRoute,
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
        _OverviewMetrics(summary: summary),
        const SizedBox(height: 12),
        _TripDetailsCard(summary: summary),
        const SizedBox(height: 12),
        _MiniForecastPattern(forecast: summary.dailyWeatherForecast),
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
          label: 'Nearby Places',
          value: '${summary.googlePlaces.length}',
          hint: 'Google Places',
          tone: AppPalette.mintA(0.1),
          icon: Icons.place_rounded,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkA(0.65),
                    ),
                  ),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkA(0.65),
                    ),
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
  const _ModulesTab({required this.summary, required this.routeLoader});

  final TripSummaryModel summary;
  final _WalkingRouteLoader routeLoader;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        MacPanel(
          color: AppPalette.whiteA(0.88),
          child: Text(
            'Flow: Trip Record → Weather / Nearby Places / Recommendations / Country Info',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.82)),
          ),
        ),
        const SizedBox(height: 12),
        _DataCards(summary: summary, routeLoader: routeLoader),
      ],
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
    return MacPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                color: AppPalette.coral,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Trip Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _detail(
                'Destination',
                '${trip.destinationName}, ${trip.destinationCountry}',
              ),
              _detail('Date', trip.dateRangeLabel),
              _detail('Preferences', _preferenceListLabel(trip.preferences)),
              _coordinateDetail(
                context,
                label: 'Coordinates',
                latitude: trip.latitude,
                longitude: trip.longitude,
                title: trip.destinationName,
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

  Widget _coordinateDetail(
    BuildContext context, {
    required String label,
    required double latitude,
    required double longitude,
    required String title,
  }) {
    return SizedBox(
      width: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                  TextSpan(
                    text:
                        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _MapIconButton(
            tooltip: 'Open pinned trip location',
            onPressed: () => _showPinnedMapDialog(
              context,
              title: title,
              latitude: latitude,
              longitude: longitude,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCards extends StatelessWidget {
  const _DataCards({required this.summary, required this.routeLoader});

  final TripSummaryModel summary;
  final _WalkingRouteLoader routeLoader;

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
          width: 692,
          child: MacPanel(
            color: AppPalette.blueA(0.06),
            child: _DailyForecastView(forecast: summary.dailyWeatherForecast),
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
          child: _RecommendationGroupsView(
            groups: summary.foursquareRecommendationGroups,
            startLatitude: summary.trip.latitude,
            startLongitude: summary.trip.longitude,
            routeLoader: routeLoader,
            recommendationLimits: summary.recommendationLimits,
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
            const Icon(
              Icons.wb_twilight_rounded,
              color: AppPalette.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('Weather', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        _item('Temperature', _temperatureLabel(weather)),
        if (weather.feelsLike != null)
          _item(
            'Feels Like',
            '${_formatNumber(weather.feelsLike!)}${_temperatureUnit(weather.units)}',
          ),
        _item('Condition', weather.condition),
        _item('Humidity', '${weather.humidity}%'),
        _item('Wind', '${_formatNumber(weather.windSpeed)} m/s'),
        if (weather.pressure != null)
          _item('Pressure', '${weather.pressure} hPa'),
        if (_weatherLocationLabel(weather).isNotEmpty)
          _item('Observed Location', _weatherLocationLabel(weather)),
        if (weather.observedAt.isNotEmpty)
          _item('Observed At', weather.observedAt),
      ],
    );
  }
}

class _DailyForecastView extends StatelessWidget {
  const _DailyForecastView({required this.forecast});

  final DailyWeatherForecastModel forecast;

  @override
  Widget build(BuildContext context) {
    final days = forecast.daily;
    return Column(
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
              'Daily Weather Forecast (${days.length} days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        if (forecast.startDate.isNotEmpty && forecast.endDate.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${forecast.startDate} to ${forecast.endDate}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.62)),
          ),
        ],
        const SizedBox(height: 10),
        if (days.isEmpty)
          Text(
            forecast.message.isEmpty
                ? 'Daily forecast unavailable for this trip date range.'
                : forecast.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkA(0.72)),
          )
        else
          Column(
            children: [
              for (final day in days)
                _ForecastDayRow(day: day, units: forecast.units),
            ],
          ),
      ],
    );
  }
}

class _ForecastDayRow extends StatelessWidget {
  const _ForecastDayRow({required this.day, required this.units});

  final DailyWeatherForecastDayModel day;
  final String units;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(day.date)),
          Icon(_forecastIcon(day.iconCode), color: AppPalette.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.condition,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    _forecastTemperatureRange(day, units),
                    _forecastRainLabel(day),
                    _forecastWindLabel(day),
                  ].where((part) => part.isNotEmpty).join('  |  '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.68)),
                ),
              ],
            ),
          ),
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
            Text(
              'Google Places Nearby',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
  final point = LatLng(latitude, longitude);
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
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 14,
                        minZoom: 2,
                        maxZoom: 18,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.api_6005cmd.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 44,
                              height: 44,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppPalette.coral,
                                size: 38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Map data © OpenStreetMap contributors © CARTO',
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
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final start = LatLng(fromLatitude, fromLongitude);
    final end = LatLng(toLatitude, toLongitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 380,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _midpoint(start, end),
                initialZoom: _initialRouteZoom(start, end),
                minZoom: 2,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.api_6005cmd.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: AppPalette.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: start,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.trip_origin_rounded,
                        color: AppPalette.blue,
                        size: 26,
                      ),
                    ),
                    Marker(
                      point: end,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppPalette.coral,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Map data © OpenStreetMap contributors © CARTO',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.inkA(0.55)),
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
                const Icon(
                  Icons.public_rounded,
                  color: AppPalette.ink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Country Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (hasFlagUrl)
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.flag),
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
      style: const TextStyle(color: AppPalette.ink, fontSize: 14, height: 1.4),
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

String _preferenceListLabel(List<String> preferences) {
  if (preferences.isEmpty) {
    return 'None selected';
  }
  return preferences.map(AddTripFormData.preferenceLabel).join(', ');
}

String _temperatureLabel(WeatherModel weather) {
  return '${_formatNumber(weather.temperature)}${_temperatureUnit(weather.units)}';
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

String _weatherLocationLabel(WeatherModel weather) {
  final parts = [
    weather.cityName.trim(),
    weather.countryCode.trim(),
  ].where((part) => part.isNotEmpty).toList();
  return parts.join(', ');
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

String _forecastTemperatureRange(
  DailyWeatherForecastDayModel day,
  String units,
) {
  final unit = _temperatureUnit(units);
  return '${_formatNumber(day.temperatureMin)}$unit - ${_formatNumber(day.temperatureMax)}$unit';
}

String _forecastRainLabel(DailyWeatherForecastDayModel day) {
  final parts = <String>[];
  if (day.precipitationProbabilityMax != null) {
    parts.add('${_formatNumber(day.precipitationProbabilityMax!)}% rain');
  }
  if (day.precipitationSum != null) {
    parts.add('${_formatNumber(day.precipitationSum!)} mm');
  }
  return parts.join(', ');
}

String _forecastWindLabel(DailyWeatherForecastDayModel day) {
  if (day.windSpeedMax == 0) {
    return '';
  }
  return 'Wind ${_formatNumber(day.windSpeedMax)} m/s';
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

LatLng _midpoint(LatLng start, LatLng end) {
  return LatLng(
    (start.latitude + end.latitude) / 2,
    (start.longitude + end.longitude) / 2,
  );
}

double _initialRouteZoom(LatLng start, LatLng end) {
  final latDelta = (start.latitude - end.latitude).abs();
  final lngDelta = (start.longitude - end.longitude).abs();
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
